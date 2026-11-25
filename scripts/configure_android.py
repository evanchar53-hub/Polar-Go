import re
from pathlib import Path

manifest_path = Path("android/app/src/main/AndroidManifest.xml")
if not manifest_path.exists():
    raise FileNotFoundError("AndroidManifest.xml not found. Run 'flutter create .' first.")

text = manifest_path.read_text(encoding="utf-8")
text = re.sub(r'android:label="[^"]*"', 'android:label="Polar Go"', text, count=1)

perm = '    <uses-permission android:name="android.permission.INTERNET" />'
if perm.strip() not in text:
    text = text.replace("<application", f"{perm}\n    <application", 1)

manifest_path.write_text(text, encoding="utf-8")
print("Updated AndroidManifest.xml with Polar Go name and Internet permission.")
