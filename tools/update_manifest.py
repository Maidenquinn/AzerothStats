"""Refresh hashes only for the exact player-package allowlist after reviewed edits."""

from pathlib import Path
import hashlib
from package_policy import public_files

root = Path(__file__).resolve().parent.parent / "AzerothStats"
names = public_files(root)
(root / "SHA256SUMS.txt").write_text(
    "".join(
        hashlib.sha256((root / name).read_bytes()).hexdigest() + "  " + name + "\n"
        for name in names
    ),
    encoding="utf-8",
    newline="\n",
)
print("Manifest:", len(names), "allowlisted player files")
