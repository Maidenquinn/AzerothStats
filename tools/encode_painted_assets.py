"""Encode original art atlases for the native client; no runtime image processing.

The sources are original generated artwork. Grid coordinates are fixed in Theme.lua.
Only resampling and format conversion happen here; no downloaded game assets ship.
"""

import argparse
import io
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = {
    "glyphs": "ChronicleGlyphs",
    "landscapes": "ChronicleLandscapes",
    "surfaces": "ChronicleSurfaces",
}


def build(check=False):
    for source, target in ASSETS.items():
        image = Image.open(ROOT / f"design/chroniques-v1/{source}-source.png").convert(
            "RGBA"
        )
        if source == "glyphs":
            assert image.getextrema()[3][0] == 0, "glyph background must be transparent"
        image = image.resize((1024, 1024), Image.Resampling.LANCZOS)
        data = io.BytesIO()
        image.save(data, format="TGA")
        path = ROOT / f"AzerothStats/media/{target}.tga"
        if check:
            assert path.read_bytes() == data.getvalue(), f"{target} encoding drift"
        else:
            path.write_bytes(data.getvalue())
    print("Original painted atlases: deterministic power-of-two RGBA TGA encoding")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    build(parser.parse_args().check)
