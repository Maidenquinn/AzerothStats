"""Reproducible original parchment nine-slice plates, without external artwork.

The runtime uses the same 7% corner cuts as Chroniques. Fixed pixel geometry and
seed keep packaging reproducible. Pillow is a development dependency only.
"""

import argparse
import io
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent / "AzerothStats/media"


def build():
    assets = {}
    for index, base in enumerate(
        ((220, 202, 162), (192, 157, 109), (232, 216, 178), (219, 199, 158)), 1
    ):
        randomizer = random.Random(419 + index)
        image = Image.new("RGBA", (256, 256))
        pixels = image.load()
        for y in range(256):
            for x in range(256):
                edge = min(x, y, 255 - x, 255 - y)
                shade = -13 * math.exp(-edge / 12)
                noise = randomizer.uniform(-2.5, 2.5) + math.sin(x / 31 + y / 47) * 1.3
                pixels[x, y] = tuple(
                    int(max(0, min(255, channel + shade + noise))) for channel in base
                ) + (255,)
        draw = ImageDraw.Draw(image)
        draw.rectangle((0, 0, 255, 255), outline=(75, 48, 25, 255), width=3)
        draw.rectangle((4, 4, 251, 251), outline=(158, 115, 57, 255), width=2)
        draw.rectangle((7, 7, 248, 248), outline=(243, 224, 181, 255), width=1)
        for x, y, sx, sy in (
            (0, 0, 1, 1),
            (255, 0, -1, 1),
            (0, 255, 1, -1),
            (255, 255, -1, -1),
        ):
            draw.line(
                ((x + sx * 3, y + sy * 16), (x + sx * 16, y + sy * 3)),
                fill=(107, 66, 31, 255),
                width=2,
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
    print("Four original reproducible Grimoire plates verified")
