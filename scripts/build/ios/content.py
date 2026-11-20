#!/usr/bin/env python3
"""GeneralsX @build Codex 20/11/2026 Local-only content staging and advisory SHA-256 checks."""
from pathlib import Path, PurePosixPath
import hashlib,json,os,re,shutil,struct,subprocess,sys
ROOT=Path(__file__).resolve().parents[3]
EXCLUDED_DIRS={'steamapps','_commonredist','redistinstallers','mss','manuals','save','saves','replays','.git','shwlnchr'}
ASSET_EXTENSIONS={'.big','.gib','.bik','.ini','.str','.csf','.scb','.wnd','.tga','.dds','.w3d','.map','.wav','.mp3','.ogg','.fnt','.ani','.xml','.mtd','.dat'}
# Never checksum or package account/DRM/launcher binaries. Only explicit reference-manifest assets are checked.
UNVERIFIED_NAMES={'gensec.big','genseczh.big','game.dat','generals.dat','langdata.dat','steam_appid.txt','installscript.vdf'}

def digest(path):
 h=hashlib.sha256()
 with Path(path).open('rb') as f:
  for part in iter(lambda:f.read(4*1024*1024),b''):h.update(part)
 return h.hexdigest()

def safe_relative(value):
 value=value.replace('\\','/');p=PurePosixPath(value)
 if p.is_absolute() or not p.parts or any(x in ('..','.') for x in p.parts) or ':' in value:raise ValueError('Unsafe content path: '+value)
 return Path(*p.parts)

def files(root):
 """Case-insensitive lookup, without following symlinks out of the supplied installation."""
 root=Path(root).resolve();out={}
 for parent,dirs,names in os.walk(root,followlinks=False):
  dirs[:]=[d for d in dirs if d.lower() not in EXCLUDED_DIRS and not d.startswith('.') and not (Path(parent)/d).is_symlink()]
  for name in names:
   p=Path(parent)/name
   if p.is_symlink() or name.startswith('.'):continue
   relative=p.relative_to(root).as_posix();key=relative.lower()
   if key in out:raise ValueError('Case-colliding installation files: '+relative)
   out[key]=p
 return out

def checksum_warnings(source,manifest,emit=print):
 lookup=files(source);warnings=[]
 for relative,expected in manifest.get('sha256',{}).items():
  p=safe_relative(relative)
  if p.name.lower() in UNVERIFIED_NAMES or p.suffix.lower() not in ASSET_EXTENSIONS:
   raise ValueError('Reference manifest attempts to checksum a non-content/account-sensitive file: '+relative)
  actual=lookup.get(p.as_posix().lower())
  if actual is None:message='missing reference asset: '+relative
  elif digest(actual).lower()!=expected.lower():message='SHA-256 differs: '+relative
  else:continue
  warnings.append(message);emit('WARNING: '+message)
 emit(f'Checksum check finished: {len(warnings)} advisory warning(s). Different releases/languages/mods may legitimately differ. Continuing.')
 return warnings

def clone_file(source,dest):
 dest=Path(dest);dest.parent.mkdir(parents=True,exist_ok=True)
 if sys.platform=='darwin':
  result=subprocess.run(['cp','-c',str(source),str(dest)],capture_output=True)
  if result.returncode==0:return
 shutil.copy2(source,dest)

def stage(source,target,profile):
 source=Path(source).resolve();target=Path(target).resolve()
 if not source.is_dir():raise ValueError('Installation folder does not exist: '+str(source))
 if target==source or target in source.parents or source in target.parents:raise ValueError('Staging output must be separate from the installation folder.')
 lookup=files(source)
 if not any('/' not in n and Path(n).suffix=='.big' for n in lookup):raise ValueError('No .big archives found. Select the full installed game folder, not its shortcut or installer.')
 if target.exists():shutil.rmtree(target)
 target.mkdir(parents=True)
 for relative,p in lookup.items():
  parts=Path(relative).parts
  if p.name.lower() in UNVERIFIED_NAMES:continue
  # Full known game content trees, plus root BIG files; never Windows executables, saves or Steam metadata.
  if p.suffix.lower() not in ASSET_EXTENSIONS:continue
  if len(parts)>1 and parts[0] not in {'data','art','maps','window','zh_generals','fonts'}:continue
  if len(parts)==1 and p.suffix.lower()!='.big':continue
  clone_file(p,target/safe_relative(p.relative_to(source).as_posix()))
 if profile.get('recipe')=='shockwave-spe':
  map_name=profile.get('activationMap','Shockwave_Lnchr.dat');mapping=lookup.get(map_name.lower())
  if mapping is None:raise ValueError('ShockWave installation is missing '+map_name+'. Supply an installed ShockWave + SPE folder.')
  activated=0
  for line in mapping.read_text(errors='replace').splitlines():
   if '>' not in line:continue
   old,new=map(str.strip,line.split('>',1))
   if not old.lower().endswith('.gib'):continue
   oldpath=safe_relative(old);newpath=safe_relative(new);asset=lookup.get(oldpath.as_posix().lower()) or lookup.get(newpath.as_posix().lower())
   if asset is None:raise ValueError('Required active ShockWave archive is missing: '+old)
   clone_file(asset,target/newpath);activated+=1
  if not activated:raise ValueError('No active mod archives found in '+map_name)
 # Declarative optional rename-activation supports other BIG-based mods without native engine changes.
 for old,new in profile.get('activateArchives',{}).items():
  p=lookup.get(safe_relative(old).as_posix().lower())
  if p is None:raise ValueError('Required mod archive is missing: '+old)
  clone_file(p,target/safe_relative(new))
 for relative in profile.get('disableScripts',[]):
  key=safe_relative(relative).as_posix().lower()
  for p in list(target.rglob('*')):
   if p.is_file() and p.relative_to(target).as_posix().lower()==key:p.rename(p.with_suffix('.bcs'));break
 return target

def big_entry(installation,archive_name,entry_name):
 lookup=files(installation);archive=lookup.get(archive_name.lower())
 if not archive:return None
 with archive.open('rb') as f:
  header=f.read(16)
  if len(header)!=16 or header[:4] not in (b'BIGF',b'BIG4'):return None
  for i in range(struct.unpack_from('>I',header,8)[0]):
   raw=f.read(8)
   if len(raw)!=8:return None
   offset,size=struct.unpack('>II',raw);name=bytearray()
   while True:
    c=f.read(1)
    if not c:return None
    if c==b'\0':break
    name+=c
    if len(name)>4096:raise ValueError('Invalid BIG filename')
   if name.decode(errors='replace').replace('\\','/').lower()==entry_name.lower():f.seek(offset);return f.read(size)
 return None

def catalog(path=None):
 entries=json.loads(Path(path or ROOT/'ios/profiles/catalog.json').read_text())['profiles'];seen=set()
 for p in entries:
  if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,47}',p['id']) or p['id'] in seen:raise ValueError('Invalid/duplicate profile id')
  seen.add(p['id'])
  if p['engine'] not in ['GeneralsEngine','ZeroHourEngine']:raise ValueError('Unknown engine')
  if p['engine']=='GeneralsEngine' and p['id']!='Generals':raise ValueError('Custom profiles currently use ZeroHourEngine; original Generals has a fixed legacy data identity.')
  if p.get('recipe','retail') not in ['retail','shockwave-spe']:raise ValueError('Unknown staging recipe')
 return entries
