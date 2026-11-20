"""Build-time extraction of optional artwork from supplied installations."""
from pathlib import Path
import json,re,subprocess,shutil
from content import ROOT,files,big_entry

def prepare_icons(selected,work):
 work=Path(work);work.mkdir(parents=True,exist_ok=True);recipes=[];sources={p['id']:Path(source) for p,source in selected}
 def icon_file(source,name):
  if not source:return None
  p=files(source).get(name.lower())
  if not p:return None
  target=work/(name+'.png');r=subprocess.run(['sips','-s','format','png',str(p),'--out',str(target)],capture_output=True)
  return str(target) if r.returncode==0 else None
 zero=next((Path(source) for p,source in selected if p['engine']=='ZeroHourEngine'),None)
 gen=sources.get('Generals',zero)
 primary=icon_file(gen,'Generals.ico');zh=icon_file(zero,'GeneralsZH.ico') or icon_file(zero,'Generals.ico');shock=icon_file(sources.get('ShockWaveSPE'),'Shockwave.ico')
 images={'GeneralsIcon':(primary,'GX',25),'ZeroHourIcon':(zh,'ZH',25),'ShockWaveIcon':(shock,'SW',80),'HomeIconGLA':(None,'GLA',80),'HomeIconChina':(None,'CN',80)}
 # Read mapped-image coordinates from the same installation as the texture; base and ZH atlas layouts differ.
 for title,label in [('HomeIconGLA','SUFactionLogoLg_GLA'),('HomeIconChina','SNFactionLogoLg_China')]:
  for source in [s for s in [zero,gen] if s]:
   ini=big_entry(source,'INIZH.big','Data/INI/MappedImages/TextureSize_512/SCShellUserInterface512.INI') or big_entry(source,'INI.big','Data/INI/MappedImages/TextureSize_512/SCShellUserInterface512.INI')
   if not ini:continue
   match=re.search(r'(?ims)^MappedImage\s+'+label+r'\s*\n(.*?)^End',ini.decode(errors='replace'))
   if not match:continue
   block=match.group(1);texture=re.search(r'Texture\s*=\s*(\S+)',block);coords=re.search(r'Left:(\d+)\s+Top:(\d+)\s+Right:(\d+)\s+Bottom:(\d+)',block)
   if not texture or not coords:continue
   raw=None
   for archive in ['EnglishZH.big','TexturesZH.big','Textures.big','ZH_Generals/Textures.big']:
    raw=big_entry(source,archive,'Art/Textures/'+texture.group(1))
    if raw:break
   if not raw:continue
   tga=work/(title+'.tga');tga.write_bytes(raw);png=work/(title+'.png');subprocess.run(['sips','-s','format','png',str(tga),'--out',str(png)],check=True,stdout=subprocess.DEVNULL)
   l,t,r,b=map(int,coords.groups());images[title]=(str(png),images[title][1],80,[l,t,r-l,b-t]);break
 generated=ROOT/'ios/Launcher/AlternateIcons.xcassets';generated.mkdir(parents=True,exist_ok=True)
 (generated/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}))
 definitions=[('AppIcon',ROOT/'ios/Generals/Assets.xcassets/AppIcon.appiconset','GeneralsIcon'),('AppIconZeroHour',generated/'AppIconZeroHour.appiconset','ZeroHourIcon'),('AppIconShockWave',generated/'AppIconShockWave.appiconset','ShockWaveIcon'),('AppIconGLA',generated/'AppIconGLA.appiconset','HomeIconGLA'),('AppIconChina',generated/'AppIconChina.appiconset','HomeIconChina')]
 for name,folder,image in definitions:
  folder.mkdir(parents=True,exist_ok=True);src,fallback,pad,*crop=images[image];row={'output':str(folder/'icon.png'),'fallback':fallback,'padding':pad}
  if src:row['source']=src
  if crop:row['crop']=crop[0]
  recipes.append(row);(folder/'Contents.json').write_text(json.dumps({'images':[{'filename':'icon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}}))
 request=work/'recipes.json';request.write_text(json.dumps(recipes));subprocess.run(['swift',str(ROOT/'scripts/build/ios/render-icons.swift'),str(request)],check=True)
 for name,folder,image in definitions:
  shutil.copy2(folder/'icon.png',ROOT/'ios/Launcher'/(image+'.png'))
  if name!='AppIcon':shutil.copy2(folder/'icon.png',ROOT/'ios/Launcher'/({'AppIconZeroHour':'HomeIconZeroHour','AppIconShockWave':'HomeIconShockWave'}.get(name,image)+'.png'))
 # Windows installations often omit icon files; the generated neutral tile keeps such builds functional.
