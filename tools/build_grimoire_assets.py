"""Encode original detailed leather/parchment art into bounded native components.

No generation/network access occurs here. Fixed crops of committed source art
are reproducible. Only the small RGBA TGA components ship to players.
"""

import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parent.parent
ROOT = PROJECT / "AzerothStats/media"


def build():
    source = PROJECT / "design/themes-v1/artwork/grimoire-frame-source.png"
    provenance = json.loads((source.parent / "provenance.json").read_text())
    assert (
        hashlib.sha256(source.read_bytes()).hexdigest()
        == provenance[source.name]["sha256"]
    )
    frame = (
        Image.open(source).convert("RGBA").resize((256, 256), Image.Resampling.LANCZOS)
    )
    paper = Image.open(source).convert("RGBA")
    width, height = paper.size
    paper = paper.crop(
        (int(width * 0.20), int(height * 0.20), int(width * 0.80), int(height * 0.80))
    )
    paper = paper.resize((256, 256), Image.Resampling.LANCZOS)
    assets = {"GrimoirePlate4.tga": frame, "GrimoirePaper.tga": paper}
    for index in range(1, 4):
        image = paper.copy()
        if index == 2:
            image = Image.blend(
                image, Image.new("RGBA", image.size, (184, 139, 83, 255)), 0.25
            )
        draw = ImageDraw.Draw(image)
        draw.rectangle((0, 0, 255, 255), outline=(105, 72, 40, 255), width=2)
        draw.rectangle((3, 3, 252, 252), outline=(232, 209, 165, 255), width=1)
        for x, y, sx, sy in (
            (0, 0, 1, 1),
            (255, 0, -1, 1),
            (0, 255, 1, -1),
            (255, 255, -1, -1),
        ):
            draw.line(
                ((x + sx * 4, y + sy * 12), (x + sx * 12, y + sy * 4)),
                fill=(150, 110, 56, 255),
                width=1,
            )
        assets[f"GrimoirePlate{index}.tga"] = image
    return assets


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for name, image in build().items():
        buffer = io.BytesIO()
        image.save(buffer, format="TGA")
        if args.check:
            assert (ROOT / name).read_bytes() == buffer.getvalue(), name
        else:
            (ROOT / name).write_bytes(buffer.getvalue())
    print("Five original leather/parchment components verified")
