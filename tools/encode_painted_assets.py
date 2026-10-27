"""Encode original artwork into small native textures; no runtime image processing.

The four 1024-square dev.3 images did not render in the installed native client.
Their exact rejection mechanism is unknown. Use individual 256-pixel components,
matching the size/depth of existing textures that rendered in that client. This
conservative packaging change does not establish a universal native size limit.
Only component slicing/resampling/encoding occurs here; no game assets ship.
"""

import argparse
import io
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = tuple(
    [f"ChronicleGlyph{i:02d}.tga" for i in range(1, 17)]
    + [f"ChronicleZone{i}.tga" for i in range(1, 5)]
    + [f"ChroniclePlate{i}.tga" for i in range(1, 5)]
)


def images():
    """Return fixed source components with no runtime dependency on source PNGs."""
    folder = ROOT / "design/chroniques-v1"
    glyphs = (
        Image.open(folder / "glyphs-source.png")
        .convert("RGBA")
        .resize((1024, 1024), Image.Resampling.LANCZOS)
    )
    assert glyphs.getextrema()[3][0] == 0
    for i in range(16):
        x, y = (i % 4) * 256, (i // 4) * 256
        yield f"ChronicleGlyph{i + 1:02d}.tga", glyphs.crop((x, y, x + 256, y + 256))
    landscapes = Image.open(folder / "landscapes-source.png").convert("RGBA")
    for i in range(4):
        w, h = landscapes.width // 2, landscapes.height // 2
        x, y = (i % 2) * w, (i // 2) * h
        crop_height = round(w * 66 / 178)
        top = y + (h - crop_height) // 2
        yield f"ChronicleZone{i + 1}.tga", landscapes.crop(
            (x, top, x + w, top + crop_height)
        ).resize((256, 128), Image.Resampling.LANCZOS)
    surfaces = Image.open(folder / "surfaces-source.png").convert("RGBA")
    middle = round(surfaces.height * 0.466)
    for i in range(4):
        x = (i % 2) * (surfaces.width // 2)
        top, bottom = (0, middle) if i < 2 else (middle, surfaces.height)
        yield f"ChroniclePlate{i + 1}.tga", surfaces.crop(
            (x, top, x + surfaces.width // 2, bottom)
        ).resize((256, 256), Image.Resampling.LANCZOS)


def build(check=False):
    for name, image in images():
        data = io.BytesIO()
        image.save(data, format="TGA")
        path = ROOT / "AzerothStats/media" / name
        if check:
            assert path.read_bytes() == data.getvalue(), f"{name} encoding drift"
        else:
            path.write_bytes(data.getvalue())
    print("24 original components: deterministic RGBA TGA encoding, maximum edge 256")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    build(parser.parse_args().check)
