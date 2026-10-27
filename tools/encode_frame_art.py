"""Encode original generated frame artwork to a native power-of-two RGBA TGA.

No semantic edits: the committed PNG is resized and encoded for the game texture
loader. Native borders are explicit textures, never a custom backdrop strip.
"""

from pathlib import Path
import argparse
import io
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def build(check=False):
    source = ROOT / "design/chroniques-v1/window-frame-source.png"
    image = Image.open(source)
    assert (
        image.mode == "RGBA"
        and image.getpixel((image.width // 2, image.height // 2))[3] == 0
    )
    image = image.resize((1024, 1024), Image.Resampling.LANCZOS)
    data = io.BytesIO()
    image.save(data, format="TGA")
    target = ROOT / "AzerothStats/media/ChronicleWindow.tga"
    if check:
        assert target.read_bytes() == data.getvalue(), "window artwork encoding drift"
    else:
        target.write_bytes(data.getvalue())
    print("Original frame: transparent center, deterministic native TGA encoding")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    build(parser.parse_args().check)
