"""Check the offline prototype's local asset boundary and JavaScript syntax.

This does not replace the browser smoke test or prove native addon behavior.
"""

from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "prototype"
html = (APP / "index.html").read_text(encoding="utf-8")
assert "connect-src 'none'" in html
assert "script-src 'self'" in html
checked = 0
for name in ("index.html", "app.css", "app.js", "data.js"):
    text = (APP / name).read_text(encoding="utf-8")
    assert not re.search(r"https?://", text), (name, "external reference")
    for asset in re.findall(r"assets/[\w.\-/]+\.(?:png|jpg|woff2|ttf)", text):
        assert (APP / asset).is_file(), (name, asset)
        checked += 1
    if name.endswith(".js"):
        subprocess.run(["node", "--check", str(APP / name)], check=True)

manifest = json.loads((APP / "assets/provenance.json").read_text(encoding="utf-8"))
entries = manifest if isinstance(manifest, list) else manifest["assets"]
for entry in entries:
    assert (APP / "assets" / entry["output"]).is_file(), entry
    source = ROOT.parents[1] / entry["source"]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == entry["sourceSha256"], entry
assert (APP / "assets/OFL-NotoSans.txt").is_file()
assert (APP / "assets/OFL-NotoCJK.txt").is_file()
print(f"PASS: offline boundary; {checked} static asset references; JS syntax; {len(entries)} provenance entries")

