#!/usr/bin/env python3
"""GeneralsX @build Codex 20/11/2026 Reproducible, selectable source-only iOS collection build."""
from pathlib import Path
import argparse,json,os,plistlib,re,shutil,subprocess,sys
from content import ROOT,catalog,checksum_warnings,stage,clone_file

def run(command,**kwargs):
 print('+ '+' '.join(map(str,command)),flush=True);subprocess.run(list(map(str,command)),check=True,**kwargs)

def interactive(path,profiles):
 print('Choose games to include (comma-separated numbers):')
 for i,p in enumerate(profiles,1):print(f"  {i}. {p['title']} — {p['subtitle']}")
 values=input('Include: ').strip().split(',');chosen=[]
 for value in values:
  try:
   index=int(value.strip());assert 1<=index<=len(profiles);p=profiles[index-1]
  except (ValueError,IndexError,AssertionError):raise ValueError('Choose profile numbers from the list.')
  if p in chosen:continue
  chosen.append(p)
 entries=[]
 for p in chosen:
  raw=input(f"Full installed {p['title']} folder (drag it here or paste its path): ").strip()
  # Dragged macOS paths can be shell-escaped or wrapped in quotes.
  import shlex
  parts=shlex.split(raw);folder=parts[0] if len(parts)==1 else raw
  entries.append({'id':p['id'],'source':folder})
 team=input('Apple Team ID from Xcode (leave blank to build an unsigned IPA): ').strip()
 bundle=input('Unique bundle identifier [org.example.generalsx]: ').strip() or 'org.example.generalsx'
 data={'profiles':entries,'teamId':team,'bundleId':bundle}
 path.write_text(json.dumps(data,indent=2)+'\n');print('Saved local-only configuration to',path);return data

def selected(config,profiles):
 byid={p['id']:p for p in profiles};out=[];seen=set()
 for entry in config.get('profiles',[]):
  identifier=entry['id']
  if identifier not in byid or identifier in seen:raise ValueError('Unknown/duplicate selected profile: '+identifier)
  seen.add(identifier);out.append((byid[identifier],Path(entry['source']).expanduser().resolve()))
 if not out:raise ValueError('Select at least one profile in the local configuration.')
 return out

def prepare(config,profiles,output,fonts=None):
 selection=selected(config,profiles);output=Path(output).resolve();warnings={}
 for profile,source in selection:
  if output==source or output in source.parents:raise ValueError('Choose an original installation outside the staging output.')
 output.mkdir(parents=True,exist_ok=True)
 # The complete advisory checksum pass happens before staging or compilation.
 for profile,source in selection:
  reference=profile.get('checksum');manifest_path=ROOT/'ios/profiles/checksums'/reference if reference else None
  if manifest_path and manifest_path.exists():
   print('\nChecking',profile['title'],source,flush=True);warnings[profile['id']]=checksum_warnings(source,json.loads(manifest_path.read_text()))
  else:print('WARNING: No reference checksum manifest for '+profile['id']+'; continuing without checksum verification.');warnings[profile['id']]=['No reference manifest']
 if (output/'Games').exists():shutil.rmtree(output/'Games')
 for profile,source in selection:
  target=output/'Games'/profile['id']/'GameData';stage(source,target,profile)
  shutil.copy2(ROOT/'ios/config/dxvk.conf',target/'dxvk.conf');shutil.copy2(ROOT/'ios/config/Options.ini',target/'DefaultOptions.ini')
  if fonts:
   (target/'fonts').mkdir(exist_ok=True)
   for p in Path(fonts).iterdir():
    if p.suffix.lower() in ['.ttf','.txt'] or p.name.upper().startswith('LICENSE'):clone_file(p,target/'fonts'/p.name)
 records=[{k:p[k] for k in ['id','title','subtitle','engine','icon']} for p,s in selection]
 with (output/'GameProfiles.plist').open('wb') as f:plistlib.dump(records,f)
 (output/'checksum-report.json').write_text(json.dumps(warnings,indent=2)+'\n')
 return selection

def ensure_dependencies(env):
 for name in ['cmake','ninja','meson','pkg-config','xcodegen','xcodebuild','swift','sips','git']:
  if not shutil.which(name):raise ValueError('Missing '+name+'. See docs/HOWTO/IOS-COLLECTION-BUILD.md for the one-time prerequisites.')
 if not env.get('VULKAN_SDK'):
  options=[p for p in (Path.home()/'VulkanSDK').glob('*/macOS') if (p/'include/vulkan/vulkan.h').exists()]
  if options:env['VULKAN_SDK']=str(max(options,key=lambda p:p.stat().st_mtime))
 sdk=Path(env.get('VULKAN_SDK',''))
 if not (sdk/'include/vulkan/vulkan.h').is_file():raise ValueError('Install the LunarG Vulkan SDK and set VULKAN_SDK to its macOS folder.')
 env['CPATH']=str(sdk/'include')+(os.pathsep+env['CPATH'] if env.get('CPATH') else '')
 env['PATH']=str(sdk/'bin')+os.pathsep+env['PATH']
 lock=json.loads((ROOT/'ios/profiles/dependency-lock.json').read_text())
 if not env.get('VCPKG_ROOT'):
  checkout=ROOT/'.cache/vcpkg'
  if not (checkout/'.git').exists():run(['git','clone','https://github.com/microsoft/vcpkg',checkout])
  run(['git','-C',checkout,'checkout',lock['vcpkgCommit']]);env['VCPKG_ROOT']=str(checkout)
 if not (Path(env['VCPKG_ROOT'])/'vcpkg').exists():run([Path(env['VCPKG_ROOT'])/'bootstrap-vcpkg.sh','-disableMetrics'])
 run(['git','submodule','update','--init','references/fbraz3-dxvk'],cwd=ROOT)


def package(config,selection,staging,build,env,unsigned,no_ipa):
 from icons import prepare_icons
 prepare_icons(selection,staging/'icon-work')
 run(['xcodegen','generate','--spec','collection-project.yml','--quiet'],cwd=ROOT/'ios',env=env)
 command=['xcodebuild','-project',ROOT/'ios/GeneralsCollection.xcodeproj','-scheme','GeneralsCollection','-configuration','Release','-destination',('platform=iOS,id='+config['deviceId']) if config.get('deviceId') else 'generic/platform=iOS','-derivedDataPath',ROOT/'ios/build-collection','GX_ROOT='+str(ROOT),'GX_BUILD_DIR='+str(build),'PRODUCT_BUNDLE_IDENTIFIER='+config.get('bundleId','org.example.generalsx')]
 if unsigned:command+=['CODE_SIGNING_ALLOWED=NO']
 else:
  team=config.get('teamId') or env.get('GX_TEAM_ID')
  if not team:raise ValueError('Set teamId in your local config, or use --unsigned.')
  command+=['DEVELOPMENT_TEAM='+team,'-allowProvisioningUpdates']
  if config.get('deviceId'):command+=['-allowProvisioningDeviceRegistration']
 command+=['build'];run(command,env=env)
 source=ROOT/'ios/build-collection/Build/Products/Release-iphoneos/GeneralsCollection.app';output=ROOT/'build/ios-package-collection';app=output/'GeneralsCollection.app'
 if output.exists():shutil.rmtree(output)
 output.mkdir(parents=True);run(['cp','-cR',source,app]);(app/'Frameworks').mkdir(exist_ok=True)
 for engine in sorted({p['engine'] for p,s in selection}):
  framework=build/'ios-engines'/(engine+'.framework')
  if not framework.is_dir():raise ValueError('Missing engine framework: '+str(framework))
  run(['cp','-cR',framework,app/'Frameworks'])
 libs=[build/'_deps/dxvk-build-macos/src/d3d8/libdxvk_d3d8.0.dylib',build/'_deps/dxvk-build-macos/src/d3d9/libdxvk_d3d9.0.dylib',build/'_deps/sdl3-build/libSDL3.0.dylib',build/'_deps/sdl3_image-build/libSDL3_image.0.dylib']
 openal=sorted((build/'_deps/openal_soft-build').glob('libopenal.*.dylib'))
 if not openal:raise ValueError('OpenAL runtime was not built.')
 for p in libs:clone_file(p,app/'Frameworks'/p.name)
 clone_file(openal[0],app/'Frameworks/libopenal.1.dylib')
 if (build/'libgamespy.dylib').exists():clone_file(build/'libgamespy.dylib',app/'Frameworks/libgamespy.dylib')
 mvk=Path(env.get('GX_MOLTENVK',str(ROOT/'.cache/MoltenVK/MoltenVK/MoltenVK/dynamic/MoltenVK.xcframework/ios-arm64/MoltenVK.framework')))
 if not mvk.is_dir():raise ValueError('Missing dynamic MoltenVK framework: '+str(mvk))
 run(['cp','-cR',mvk,app/'Frameworks']);run(['cp','-cR',staging/'Games',app]);shutil.copy2(staging/'GameProfiles.plist',app/'GameProfiles.plist')
 info={'SessionPolicy':'One engine per process','SigningExpires':'Unsigned — sign with your own account'}
 profile=app/'embedded.mobileprovision'
 if profile.exists() and not unsigned:
  raw=subprocess.check_output(['security','cms','-D','-i',str(profile)]);decoded=plistlib.loads(raw);info['SigningExpires']=decoded['ExpirationDate'].isoformat()+' UTC'
 for key,engine in [('GeneralsUUID','GeneralsEngine'),('ZeroHourUUID','ZeroHourEngine')]:
  binary=app/'Frameworks'/(engine+'.framework')/engine
  if binary.exists():info[key]=subprocess.check_output(['dwarfdump','--uuid',str(binary)],text=True).split()[1]
 with (app/'BuildInfo.plist').open('wb') as f:plistlib.dump(info,f)
 if unsigned:
  if profile.exists():profile.unlink()
  for binary in [*list((app/'Frameworks').glob('*.dylib')),*list((app/'Frameworks').glob('*.framework')),app]:run(['codesign','--force','--sign','-','--timestamp=none',binary])
 else:
  entitlements=output/'entitlements.plist';result=subprocess.run(['codesign','-d','--entitlements','-','--xml',str(source)],capture_output=True,check=True);entitlements.write_bytes(result.stdout)
  identity=config.get('signingIdentity','Apple Development')
  for binary in [*list((app/'Frameworks').glob('*.dylib')),*list((app/'Frameworks').glob('*.framework'))]:run(['codesign','--force','--sign',identity,'--timestamp=none',binary])
  run(['codesign','--force','--sign',identity,'--timestamp=none','--entitlements',entitlements,app])
 run(['codesign','--verify','--deep','--strict',app])
 if not no_ipa:
  payload=output/'Payload';payload.mkdir();run(['cp','-cR',app,payload]);run(['ditto','-c','-k','--keepParent',payload,output/'GeneralsX.ipa']);shutil.rmtree(payload)
 print('Packaged selected profiles:',', '.join(p['id'] for p,s in selection));return app

def choose_device(config):
 if config.get('deviceId'):return
 inventory=ROOT/'build/device-inventory.json';inventory.parent.mkdir(exist_ok=True)
 run(['xcrun','devicectl','list','devices','--json-output',inventory],stdout=subprocess.DEVNULL)
 devices=[d for d in json.loads(inventory.read_text()).get('result',{}).get('devices',[]) if d.get('hardwareProperties',{}).get('platform')=='iOS' and d.get('connectionProperties',{}).get('tunnelState')=='connected']
 if not devices:raise ValueError('Connect and unlock your iPhone/iPad, trust this Mac and enable Developer Mode, then retry --install.')
 if len(devices)==1:device=devices[0]
 elif sys.stdin.isatty():
  for i,d in enumerate(devices,1):print(i,d.get('deviceProperties',{}).get('name',d['identifier']))
  choice=int(input('Install to device number: '));device=devices[choice-1]
 else:raise ValueError('Multiple connected devices: set deviceId in your local config.')
 config['deviceId']=device['identifier']

def main(argv=None):
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--config',type=Path,default=ROOT/'build.local.json');ap.add_argument('--catalog',type=Path);ap.add_argument('--prepare-only',action='store_true');ap.add_argument('--skip-engine-build',action='store_true');ap.add_argument('--engine-build-dir',type=Path,default=ROOT/'build/ios-vulkan');ap.add_argument('--unsigned',action='store_true');ap.add_argument('--install',action='store_true');ap.add_argument('--no-ipa',action='store_true');args=ap.parse_args(argv)
 profiles=catalog(args.catalog)
 if args.config.exists():config=json.loads(args.config.read_text())
 elif sys.stdin.isatty():config=interactive(args.config,profiles)
 else:raise ValueError('Create build.local.json from build.example.json or run ./build.command interactively.')
 unsigned=args.unsigned or not(config.get('teamId') or os.environ.get('GX_TEAM_ID'))
 if args.install and unsigned:raise ValueError('--install requires your own teamId. Use an unsigned IPA with your sideloading tool instead.')
 if args.install:choose_device(config)
 selection=selected(config,profiles);staging=ROOT/'build/ios-content';env=dict(os.environ)
 if args.prepare_only:prepare(config,profiles,staging);print('Prepared:',staging);return
 if sys.platform!='darwin':raise ValueError('iOS compilation/signing requires macOS and Xcode. --prepare-only is portable.')
 if args.skip_engine_build:
  for name in ['xcodegen','xcodebuild','swift','sips']:
   if not shutil.which(name):raise ValueError('Missing tool: '+name)
 else:ensure_dependencies(env)
 fonts=Path(env.get('GX_FONTS',str(ROOT/'.cache/fonts')))
 if not list(fonts.glob('*.ttf')) or not (fonts/'LICENSE.txt').exists():env['GX_FONTS']=str(fonts);run([ROOT/'scripts/build/ios/stage-fonts.sh'],env=env)
 mvk=ROOT/'.cache/MoltenVK'
 if not env.get('GX_MOLTENVK'):env['GX_MOLTENVK_ROOT']=str(mvk);run([ROOT/'scripts/build/ios/fetch-moltenvk.sh'],env=env)
 # Advisory checks still precede the compiler, even when dependencies need setup first.
 prepare(config,profiles,staging,fonts)
 build=args.engine_build_dir.resolve()
 if not args.skip_engine_build:
  if build!=ROOT/'build/ios-vulkan':raise ValueError('Custom --engine-build-dir requires --skip-engine-build; default source build uses the ios-vulkan preset.')
  run(['cmake','--preset','ios-vulkan'],cwd=ROOT,env=env)
  targets=sorted({'g_generals_engine' if p['engine']=='GeneralsEngine' else 'z_generals_engine' for p,s in selection})
  run(['cmake','--build',build,'--target',*targets,'-j',str(config.get('jobs',3))],env=env)
 unsigned=args.unsigned or not(config.get('teamId') or env.get('GX_TEAM_ID'))
 if args.install and unsigned:raise ValueError('--install requires your own teamId and a signed build. An unsigned IPA can be signed separately.')
 app=package(config,selection,staging,build,env,unsigned,args.no_ipa)
 if args.install:
  command=['xcrun','devicectl','device','install','app']
  if not config.get('deviceId'):raise ValueError('Set deviceId in your local config to use --install.')
  run(command+['--device',config['deviceId'],app,'--timeout','300'])

if __name__=='__main__':
 try:main()
 except (ValueError,KeyError,OSError,subprocess.CalledProcessError) as error:print('ERROR:',error,file=sys.stderr);sys.exit(1)
