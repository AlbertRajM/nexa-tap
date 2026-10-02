"""Adjusts the generated Android project: app name, internet permission, link handling."""
import re, pathlib

m = pathlib.Path('build_app/android/app/src/main/AndroidManifest.xml')
s = m.read_text()
s = re.sub(r'android:label="[^"]*"', 'android:label="Nexa Tap"', s, count=1)
if 'android.permission.INTERNET' not in s:
    s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
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
