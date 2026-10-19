"""Build a release AAB using a private upload key; never prints signing passwords."""
from pathlib import Path
import configparser, json, os, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
private=ROOT/'builds/play-console-private'
if not (private/'signing.json').exists():
 raise SystemExit('Restore your private upload key and signing.json into builds/play-console-private before building. Never create a replacement key for an existing Play app without following Google upload-key reset procedures.')
config=json.loads((private/'signing.json').read_text())
presets=configparser.ConfigParser(interpolation=None)
presets.read(ROOT/'export_presets.cfg')
version=presets['preset.1.options']['version/code']
bundle=ROOT/f'builds/google-play/bundle/com.frutylabs.pocketparty-v{version}.aab'
java=Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')
env=os.environ.copy()
env.update({'JAVA_HOME':str(java),'GRADLE_USER_HOME':str(ROOT/'builds/gradle-cache'),'ANDROID_USER_HOME':str(ROOT/'builds/android-user'),'GODOT_ANDROID_KEYSTORE_RELEASE_PATH':config['keystore'],'GODOT_ANDROID_KEYSTORE_RELEASE_USER':config['alias'],'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD':config['password'],'PLAY_KEY_PASSWORD':config['password']})
key=Path(config['keystore'])
if not key.exists():
 raise SystemExit('Upload keystore is missing. Restore your backed-up .jks; do not generate a replacement key for an existing Play app.')
cert=ROOT/'builds/google-play/bundle/upload-certificate.pem'
subprocess.run([str(java/'bin/keytool'),'-exportcert','-rfc','-keystore',str(key),'-alias',config['alias'],'-storepass:env','PLAY_KEY_PASSWORD','-file',str(cert)],env=env,check=True,cwd=ROOT)
command=['godot','--headless','--path',str(ROOT)]
if not (ROOT/'android/build/build.gradle').exists():
 command+=['--install-android-build-template']
command+=['--export-release','Google Play',str(bundle)]
with (ROOT/'builds/google-play-build.log').open('w') as output:
 result=subprocess.run(command,cwd=ROOT,env=env,stdout=output,stderr=subprocess.STDOUT)
print('Google Play export finished:',result.returncode,'(see builds/google-play-build.log)')
sys.exit(result.returncode)
