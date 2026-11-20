#!/usr/bin/env python3
# GeneralsX @build Codex 20/11/2026 Stage a mod profile from a verified installed Windows copy.
from pathlib import Path
import argparse,subprocess,shutil,struct,hashlib,json
parser=argparse.ArgumentParser();parser.add_argument('installation',type=Path);args=parser.parse_args()
root=Path(__file__).resolve().parents[3];source=args.installation.resolve();base=root/'build/ios-package/GeneralsXZH.app/GameData';output=root/'build/ios-shockwave-content';target=output/'GameData'
assert base.is_dir() and source.is_dir()
# Only the eleven archives activated by the standard launcher; classic cameos remain off.
archives=[]
for line in (source/'Shockwave_Lnchr.dat').read_text().splitlines():
 if '>' in line:
  old,new=map(str.strip,line.split('>',1))
  if old.lower().endswith('.gib'):archives.append((source/old,new))
assert len(archives)==11
manifest=[]
for p,name in archives:
 with p.open('rb') as f:
  header=f.read(16);assert header[:4] in (b'BIGF',b'BIG4'),p
  _,count,indexEnd=struct.unpack('>III',header[4:]);size=p.stat().st_size
  assert 16<=indexEnd<=size and count<100000
  for i in range(count):
   offset,length=struct.unpack('>II',f.read(8));assert offset+length<=size
   filename=bytearray()
   while True:
    c=f.read(1);assert c
    if c==b'\0':break
    filename+=c;assert len(filename)<4096
  assert f.tell()<=indexEnd
 manifest.append({'source':p.name,'activated':name,'bytes':size,'sha256':hashlib.file_digest(p.open('rb'),'sha256').hexdigest()})
# Clone the validated iOS tree, then overlay only this profile. Original retail bundles are never changed.
if target.exists():shutil.rmtree(target)
output.mkdir(parents=True,exist_ok=True)
subprocess.run(['cp','-cR',str(base),str(target)],check=True)
for p,name in archives:subprocess.run(['cp','-c',str(p),str(target/name)],check=True)
# The Windows launcher's script deactivation is also required: loose files override archives.
for name in ['MultiplayerScripts.scb','Scripts.ini','SkirmishScripts.scb']:
 p=target/'Data/Scripts'/name
 if p.exists():p.rename(p.with_suffix('.bcs'))
movies=source/'Data/Movies'
for p in movies.rglob('*'):
 if p.is_file():
  dest=target/'Data/Movies'/p.relative_to(movies);dest.parent.mkdir(parents=True,exist_ok=True)
  subprocess.run(['cp','-c',str(p),str(dest)],check=True)
(output/'manifest.json').write_text(json.dumps({'profile':'ShockWave 1.201 + SPE 2.1.3','archives':manifest,'movies':sum(p.is_file() for p in movies.rglob('*'))},indent=2))
print('Staged',len(archives),'validated archives and',sum(p.is_file() for p in movies.rglob('*')),'movies at',target)
