"""Build a reproducible, manifest-verified installable ZIP; no client or user data needed."""

from pathlib import Path
import argparse, hashlib, re, zipfile
from package_policy import public_files
from security_review import inspect

p = argparse.ArgumentParser()
p.add_argument("--output", type=Path, default=Path("release-assets"))
args = p.parse_args()
root = Path(__file__).resolve().parent.parent
addon = root / "AzerothStats"
version = re.search(
    r"^## Version: ([0-9A-Za-z.-]+)$",
    (addon / "AzerothStats.toc").read_text(encoding="utf-8"),
    re.M,
)[1]
inspect(root)
manifest = (addon / "SHA256SUMS.txt").read_text(encoding="utf-8")
files = {}
for line in manifest.splitlines():
    digest, name = line.split("  ", 1)
    source = addon / name
    assert not Path(name).is_absolute() and addon.resolve() in source.resolve().parents
    assert name not in files and source.is_file(), name
    data = source.read_bytes()
    assert hashlib.sha256(data).hexdigest() == digest, name
    assert source.suffix in {
        ".lua",
        ".toc",
        ".md",
        ".ttf",
        ".otf",
        ".tga",
        ".txt",
    }, name
    files[name] = data
assert set(files) == set(
    public_files(addon)
), "manifest does not match player allowlist"
files["SHA256SUMS.txt"] = (addon / "SHA256SUMS.txt").read_bytes()
args.output.mkdir(parents=True, exist_ok=True)
archive = args.output / ("AzerothStats-" + version + ".zip")
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for name, data in sorted(files.items()):
        item = zipfile.ZipInfo("AzerothStats/" + name, (1980, 1, 1, 0, 0, 0))
        item.compress_type = zipfile.ZIP_DEFLATED
        item.external_attr = 0o100644 << 16
        z.writestr(item, data)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert len(z.namelist()) == len(files)
    for name, data in files.items():
        assert z.read("AzerothStats/" + name) == data
    assert "AzerothStats/AzerothStats.toc" in z.namelist()
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix(".zip.sha256").write_text(
    digest + "  " + archive.name + "\n", encoding="utf-8"
)
print(archive.resolve())
print(digest)
print(len(files), "verified installable files")
