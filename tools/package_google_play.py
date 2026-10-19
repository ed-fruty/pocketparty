"""Validate generated Play files and assemble an upload ZIP without private keys."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import configparser, hashlib, json, shutil, struct, xml.etree.ElementTree as ET
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'builds/google-play'
source=ROOT/'publishing/google-play'
presets=configparser.ConfigParser(interpolation=None)
presets.read(ROOT/'export_presets.cfg')
version=int(presets['preset.1.options']['version/code'])
bundle=OUT/f'bundle/com.frutylabs.pocketparty-v{version}.aab'
assert bundle.is_file()
shutil.copytree(source/'en-US',OUT/'listing/en-US',dirs_exist_ok=True)
for name in ['UPLOAD_NOTES.md','DATA_SAFETY.md','store-settings.json','asset-alt-text.json','GODOT_LICENSES.txt']:
 shutil.copy2(source/name,OUT/name)
shutil.copy2(ROOT/'PRIVACY_POLICY.md',OUT/'PRIVACY_POLICY.md')
shutil.copy2(source/'UPLOAD_NOTES.md',OUT/'README.md')
ns={'android':'http://schemas.android.com/apk/res/android'}
a='{'+ns['android']+'}'
manifest=ET.parse(OUT/'verification/AndroidManifest.xml').getroot()
assert manifest.get('package')=='com.frutylabs.pocketparty'
assert int(manifest.get(a+'versionCode'))==version
assert int(manifest.find('uses-sdk').get(a+'targetSdkVersion'))>=36
assert manifest.find('application').get(a+'debuggable','false')=='false'
assert {p.get(a+'name') for p in manifest.findall('uses-permission')} == {'android.permission.INTERNET'}
assert 'PAGE_ALIGNMENT_16K' in (OUT/'verification/BundleConfig.json').read_text()
assert 'jar verified.' in (OUT/'verification/signature-verification.txt').read_text()
assert 'Error' not in (OUT/'verification/bundle-validation.txt').read_text()
elf=[]
with ZipFile(bundle) as z:
 names=z.namelist()
 assert 'BundleConfig.pb' in names and 'base/manifest/AndroidManifest.xml' in names
 policy_name=next(n for n in names if n.endswith('/PRIVACY_POLICY.md'))
 assert z.read(policy_name)==(ROOT/'PRIVACY_POLICY.md').read_bytes()
 assert any(n.endswith('/GODOT_LICENSES.txt') for n in names)
 assert not any(any(v in n for v in ['signing.json','laptop_party_save','play-console-private','.jks','tests/','tools/']) for n in names)
 for name in names:
  if name.startswith('base/lib/arm64-v8a/') and name.endswith('.so'):
   data=z.read(name)
   phoff=struct.unpack_from('<Q',data,32)[0]
   entry_size,count=struct.unpack_from('<HH',data,54)
   align=[]
   for i in range(count):
    at=phoff+i*entry_size
    if struct.unpack_from('<I',data,at)[0]==1:
     offset,vaddr=struct.unpack_from('<QQ',data,at+8)
     alignment=struct.unpack_from('<Q',data,at+48)[0]
     assert alignment>=16384 and offset%16384==vaddr%16384
     align.append(alignment)
   elf.append({'library':name,'load_segment_alignments':align,'supports_16k_elf_alignment':True})
assert len(elf)>=2
(OUT/'verification/native-16k-alignment.json').write_text(json.dumps(elf,indent=2))
images=[]
for p in sorted((OUT/'screenshots').rglob('*.png')):
 with Image.open(p) as im:
  w,h=im.size
  assert im.mode=='RGB' and min(w,h)>=1080 and max(w,h)<=3840 and max(w,h)/min(w,h)<=2
  assert p.stat().st_size<8*1024*1024
  images.append({'file':p.relative_to(OUT).as_posix(),'width':w,'height':h,'mode':im.mode,'bytes':p.stat().st_size})
assert len(images)==16
for name,expected,mode in [('app-icon-512.png',(512,512),'RGBA'),('feature-graphic-1024x500.png',(1024,500),'RGB')]:
 with Image.open(OUT/'graphics'/name) as im:
  assert im.size==expected and im.mode==mode
for name,limit in [('title',30),('short-description',80),('full-description',4000),('release-notes',500)]:
 assert len((OUT/f'listing/en-US/{name}.txt').read_text().strip())<=limit
(OUT/'verification/image-validation.json').write_text(json.dumps(images,indent=2))
files=[p for p in OUT.rglob('*') if p.is_file() and p.name!='SHA256SUMS.txt' and (p.suffix!='.aab' or p==bundle)]
assert not any(p.suffix in ['.jks','.keystore'] or p.name=='signing.json' for p in files)
checksums=''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(OUT).as_posix()+'\n' for p in sorted(files))
(OUT/'SHA256SUMS.txt').write_text(checksums)
files.append(OUT/'SHA256SUMS.txt')
archive=ROOT/'builds/google-play-console.zip'
with ZipFile(archive,'w',ZIP_DEFLATED,compresslevel=6) as z:
 for p in files:
  z.write(p,'google-play/'+p.relative_to(OUT).as_posix())
print(f'Packaged version {version}: {archive.name}, {archive.stat().st_size/1024/1024:.1f} MiB, {len(files)} files. No private signing material.')
