"""Copy/convert only existing project-owned artwork for the offline V2 prototype.

No game files, player saves or runtime addon folders are written. Pillow is a
development dependency only. Original provenance stays in the source design docs.
"""

from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image

HERE = Path(__file__).resolve().parent
MEDIA = HERE.parent.parent / "AzerothStats/media"
OUT = HERE / "prototype/assets"
OUT.mkdir(parents=True, exist_ok=True)
names = [f"ChronicleGlyph{i:02}.tga" for i in range(1, 17)]
names += [
    "ChronicleGrain.tga",
    "ChroniclePlate4.tga",
    "GrimoirePaper.tga",
    "GrimoirePlate4.tga",
]
names += [p.name for p in MEDIA.glob("RunZone-*.tga")]
manifest = []
for name in names:
    source = MEDIA / name
    target = OUT / (source.stem + ".png")
    Image.open(source).convert("RGBA").save(target, optimize=True)
    manifest.append(
        {
            "source": "AzerothStats/media/" + name,
            "output": target.name,
            "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        }
    )
for name in ("AzerothSans.ttf", "AzerothSerif.ttf"):
    shutil.copy2(MEDIA / name, OUT / name)
    manifest.append(
        {
            "source": "AzerothStats/media/" + name,
            "output": name,
            "sourceSha256": hashlib.sha256((MEDIA / name).read_bytes()).hexdigest(),
        }
    )
for name in ("OFL-NotoSans.txt", "OFL-NotoCJK.txt"):
    shutil.copy2(MEDIA / name, OUT / name)
(OUT / "provenance.json").write_text(
    json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
)
print(
    f"Prepared {len(manifest)} existing artwork/font assets; no Blizzard assets copied"
)
