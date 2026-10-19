"""Build a release AAB using a private upload key; never prints signing passwords."""
from pathlib import Path
import json, os, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
private=ROOT/'builds/play-console-private'
config=json.loads((private/'signing.json').read_text())
java=Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')
env=os.environ.copy()
env.update({'JAVA_HOME':str(java),'GRADLE_USER_HOME':str(ROOT/'builds/gradle-cache'),'ANDROID_USER_HOME':str(ROOT/'builds/android-user'),'GODOT_ANDROID_KEYSTORE_RELEASE_PATH':config['keystore'],'GODOT_ANDROID_KEYSTORE_RELEASE_USER':config['alias'],'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD':config['password'],'PLAY_KEY_PASSWORD':config['password']})
key=Path(config['keystore'])
if not key.exists():
 subprocess.run([str(java/'bin/keytool'),'-genkeypair','-keystore',str(key),'-storetype','JKS','-alias',config['alias'],'-storepass:env','PLAY_KEY_PASSWORD','-keypass:env','PLAY_KEY_PASSWORD','-keyalg','RSA','-keysize','4096','-validity','10000','-dname','CN=Pocket Party Upload, OU=Android Upload'],env=env,check=True,cwd=ROOT)
 key.chmod(0o600)
cert=ROOT/'builds/google-play/bundle/upload-certificate.pem'
subprocess.run([str(java/'bin/keytool'),'-exportcert','-rfc','-keystore',str(key),'-alias',config['alias'],'-storepass:env','PLAY_KEY_PASSWORD','-file',str(cert)],env=env,check=True,cwd=ROOT)
command=['godot','--headless','--path',str(ROOT)]
if not (ROOT/'android/build/build.gradle').exists():
 command+=['--install-android-build-template']
command+=['--export-release','Google Play',str(ROOT/'builds/google-play/bundle/com.frutylabs.pocketparty.aab')]
with (ROOT/'builds/google-play-build.log').open('w') as output:
 result=subprocess.run(command,cwd=ROOT,env=env,stdout=output,stderr=subprocess.STDOUT)
print('Google Play export finished:',result.returncode,'(see builds/google-play-build.log)')
sys.exit(result.returncode)
