"""Refresh bundletool and signing evidence for the configured release bundle."""
from pathlib import Path
import configparser, hashlib, ssl, subprocess
ROOT = Path(__file__).resolve().parents[1]
JAVA = Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin')
OUT = ROOT/'builds/google-play'
VERIFY = OUT/'verification'
VERIFY.mkdir(parents=True, exist_ok=True)
presets = configparser.ConfigParser(interpolation=None)
presets.read(ROOT/'export_presets.cfg')
version = int(presets['preset.1.options']['version/code'])
bundle = OUT/f'bundle/com.frutylabs.pocketparty-v{version}.aab'
tool = ROOT/'builds/tooling/bundletool-all-1.18.3.jar'
if not tool.is_file():
    raise SystemExit('Install the official bundletool-all-1.18.3.jar in builds/tooling first.')
commands = [
    ('AndroidManifest.xml', [str(JAVA/'java'), '-jar', str(tool), 'dump', 'manifest', '--bundle='+str(bundle), '--module=base']),
    ('BundleConfig.json', [str(JAVA/'java'), '-jar', str(tool), 'dump', 'config', '--bundle='+str(bundle)]),
    ('bundle-validation.txt', [str(JAVA/'java'), '-jar', str(tool), 'validate', '--bundle='+str(bundle)]),
    ('signature-verification.txt', [str(JAVA/'jarsigner'), '-verify', '-verbose', '-certs', str(bundle)]),
]
for name, command in commands:
    result = subprocess.run(command, capture_output=True, text=True, cwd=ROOT)
    (VERIFY/name).write_text(result.stdout+result.stderr)
    if result.returncode:
        raise SystemExit(f'{name} failed: see verification evidence')
    print(name, 'OK')
# Compare the actual bundle signer with the backed-up public upload certificate.
result = subprocess.run([str(JAVA/'keytool'), '-printcert', '-rfc', '-jarfile', str(bundle)], capture_output=True, text=True, check=True)
def certificate(text):
    start = text.index('-----BEGIN CERTIFICATE-----')
    end = text.index('-----END CERTIFICATE-----', start)+len('-----END CERTIFICATE-----')
    return ssl.PEM_cert_to_DER_cert(text[start:end])
expected = certificate((OUT/'bundle/upload-certificate.pem').read_text())
actual = certificate(result.stdout)
assert hashlib.sha256(actual).digest() == hashlib.sha256(expected).digest(), 'Bundle signing certificate differs from upload certificate'
(VERIFY/'release-summary.txt').write_text(f'Bundle: {bundle.name}\nVersion code: {version}\nSHA-256: {hashlib.sha256(bundle.read_bytes()).hexdigest()}\nUpload certificate SHA-256: {hashlib.sha256(actual).hexdigest()}\nBundletool validation and release signature verified.\n')
print('Upload signing certificate matches; bundle SHA-256 recorded.')
