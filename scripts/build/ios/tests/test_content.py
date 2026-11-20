import importlib.util,json,sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from content import checksum_warnings,digest,stage,catalog
from build_collection import selected,prepare

class ContentTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name);self.source=self.root/'Installed Game';self.source.mkdir();(self.source/'INIZH.big').write_bytes(b'reference asset');self.out=self.root/'output'
 def tearDown(self):self.tmp.cleanup()
 def profile(self):return {'id':'GeneralsZH','title':'ZERO HOUR','subtitle':'ZH','engine':'ZeroHourEngine','recipe':'retail','icon':'ZeroHourIcon'}
 def test_checksums_warn_and_continue(self):
  messages=[];manifest={'sha256':{'INIZH.big':'0'*64,'MapsZH.big':'1'*64}}
  self.assertEqual(len(checksum_warnings(self.source,manifest,messages.append)),2)
  self.assertTrue(any('Continuing' in m for m in messages))
  self.assertEqual(len(checksum_warnings(self.source,{'sha256':{'inizh.BIG':digest(self.source/'INIZH.big')}},messages.append)),0)
 def test_account_files_not_hashed_or_staged(self):
  for name in ['Game.dat','steam_api.dll','installScript.vdf','gensecZH.big','profile.sav']:(self.source/name).write_bytes(b'account-specific')
  checksum_warnings(self.source,{'sha256':{'INIZH.big':digest(self.source/'INIZH.big')}},lambda x:None)
  stage(self.source,self.out,self.profile());self.assertEqual([p.name for p in self.out.iterdir()],['INIZH.big'])
  with self.assertRaises(ValueError):checksum_warnings(self.source,{'sha256':{'Game.dat':'0'*64}},lambda x:None)
 def test_mod_activations_do_not_change_installation(self):
  (self.source/'!mod.gib').write_bytes(b'mod');scripts=self.source/'Data/Scripts';scripts.mkdir(parents=True);(scripts/'Scripts.ini').write_text('stock')
  p=self.profile();p.update(activateArchives={'!mod.gib':'!mod.big'},disableScripts=['Data/Scripts/Scripts.ini'])
  stage(self.source,self.out,p);self.assertEqual((self.out/'!mod.big').read_bytes(),b'mod');self.assertTrue((scripts/'Scripts.ini').exists());self.assertTrue((self.out/'Data/Scripts/Scripts.bcs').exists())
 def test_path_escape_rejected(self):
  p=self.profile();p['activateArchives']={'!mod.gib':'../escape.big'}
  (self.source/'!mod.gib').write_bytes(b'mod')
  with self.assertRaises(ValueError):stage(self.source,self.out,p)
  with self.assertRaises(ValueError):stage(self.source,self.source/'output',self.profile())
 def test_optional_profiles_and_manifest(self):
  p=self.profile();config={'profiles':[{'id':p['id'],'source':str(self.source)}]};self.assertEqual(len(selected(config,[p])),1)
  prepare(config,[p],self.out)
  import plistlib
  records=plistlib.loads((self.out/'GameProfiles.plist').read_bytes());self.assertEqual([r['id'] for r in records],['GeneralsZH']);self.assertFalse((self.out/'Games/Generals').exists())
  with self.assertRaises(ValueError):selected({'profiles':[]},[p])
 def test_symlinks_not_followed(self):
  secret=self.root/'outside';secret.mkdir();(secret/'secret.ini').write_text('private');(self.source/'Data').symlink_to(secret,target_is_directory=True)
  stage(self.source,self.out,self.profile());self.assertFalse((self.out/'Data').exists())
 def test_deselected_profiles_are_removed(self):
  p=self.profile();other=dict(p,id='OtherMod',title='MOD')
  prepare({'profiles':[{'id':p['id'],'source':str(self.source)},{'id':other['id'],'source':str(self.source)}]},[p,other],self.out)
  self.assertTrue((self.out/'Games/OtherMod/GameData/INIZH.big').exists())
  prepare({'profiles':[{'id':p['id'],'source':str(self.source)}]},[p,other],self.out)
  self.assertFalse((self.out/'Games/OtherMod').exists())
 def test_duplicate_selection_rejected(self):
  p=self.profile();entry={'id':p['id'],'source':str(self.source)}
  with self.assertRaises(ValueError):selected({'profiles':[entry,entry]},[p])
 def test_builtin_catalog(self):
  self.assertEqual({p['id'] for p in catalog()},{'Generals','GeneralsZH','ShockWaveSPE'})

if __name__=='__main__':unittest.main()
