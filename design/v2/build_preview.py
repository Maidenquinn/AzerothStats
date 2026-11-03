"""Package the offline design prototype, never the installed player addon."""

from pathlib import Path
import argparse
import hashlib
import zipfile

HERE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
args = parser.parse_args()
args.output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(args.output, "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted((HERE / "prototype").rglob("*")):
        if path.is_file():
            archive.write(path, Path("AzerothStats-V2-Maquette") / path.relative_to(HERE / "prototype"))
    archive.write(HERE / "README.md", "LIRE-AVANT.md")
digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
args.output.with_suffix(".zip.sha256").write_text(digest + "  " + args.output.name + "\n", encoding="ascii")
with zipfile.ZipFile(args.output) as archive:
    assert archive.testzip() is None
    assert "AzerothStats-V2-Maquette/index.html" in archive.namelist()
print(f"PASS: {args.output}\nSHA-256: {digest}")
