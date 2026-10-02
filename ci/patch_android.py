"""Adjusts the generated Android project: app name, internet permission, link handling."""
import re, pathlib

m = pathlib.Path('build_app/android/app/src/main/AndroidManifest.xml')
s = m.read_text()
s = re.sub(r'android:label="[^"]*"', 'android:label="Nexa Tap"', s, count=1)
extra = [
    '<uses-permission android:name="android.permission.INTERNET"/>',
    '<uses-permission android:name="android.permission.NFC"/>',
    '<uses-feature android:name="android.hardware.nfc" android:required="false"/>',
    '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>',
]
for line in extra:
    key = line.split('"')[1]
    if key not in s:
        s = s.replace('<application', line + '\n    <application', 1)
queries = '''
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="sms"/></intent>
        <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>
        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>'''
if '<queries>' in s:
    s = s.replace('<queries>', '<queries>' + queries, 1)
else:
    s = s.replace('</manifest>', '    <queries>' + queries + '\n    </queries>\n</manifest>', 1)
m.write_text(s)
print(s)

# ---- Bundle the app fonts (Syne for headings, Outfit for text) ----
pub = pathlib.Path('build_app/pubspec.yaml')
y = pub.read_text()
if 'family: Syne' not in y:
    fonts = '''  uses-material-design: true
  fonts:
    - family: Syne
      fonts:
        - asset: assets/fonts/Syne-600.ttf
          weight: 600
        - asset: assets/fonts/Syne-700.ttf
          weight: 700
        - asset: assets/fonts/Syne-800.ttf
          weight: 800
    - family: Outfit
      fonts:
        - asset: assets/fonts/Outfit-300.ttf
          weight: 300
        - asset: assets/fonts/Outfit-400.ttf
          weight: 400
        - asset: assets/fonts/Outfit-500.ttf
          weight: 500
        - asset: assets/fonts/Outfit-600.ttf
          weight: 600
        - asset: assets/fonts/Outfit-700.ttf
          weight: 700
'''
    assert 'uses-material-design: true' in y, 'pubspec format changed'
    y = y.replace('  uses-material-design: true\n', fonts, 1)
    pub.write_text(y)
print('fonts added to pubspec')

# ---- Icon font (Lucide) and texture assets ----
y = pub.read_text()
if 'family: Lucide' not in y:
    y = y.replace('  fonts:\n', '''  assets:
    - assets/textures/
  fonts:
    - family: Lucide
      fonts:
        - asset: assets/fonts/Lucide.ttf
''', 1)
    pub.write_text(y)
print('icons + textures added to pubspec')

# ---- Use the same signing key for every build, so new APKs install over old ones ----
import shutil, os
ks_dir = os.path.expanduser('~/.android')
os.makedirs(ks_dir, exist_ok=True)
shutil.copy('ci/debug.keystore', os.path.join(ks_dir, 'debug.keystore'))
print('fixed signing key installed')

# ---- Older plugins (e.g. nfc_manager) target an old Android SDK; raise it to 35 ----
import glob, re as _re
_cache = os.environ.get('PUB_CACHE') or os.path.expanduser('~/.pub-cache')
for gradle in glob.glob(os.path.join(_cache, 'hosted', '*', '*', 'android', 'build.gradle*')):
    txt = open(gradle).read()
    def bump(m):
        n = int(m.group(2))
        return m.group(1) + ('35' if n < 34 else str(n))
    new = _re.sub(r'(compileSdk(?:Version)?\s*=?\s*)(\d+)', bump, txt)
    if new != txt:
        open(gradle, 'w').write(new)
        print('raised compileSdk in', gradle)
