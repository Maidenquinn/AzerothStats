"""Prepare maintainer-supplied zone photos and their native UV framing.

Original JPEG bytes are kept unchanged under design/run-images. Encoding only
resamples the complete image to a small native texture. The actual framing uses
SetTexCoord in Lua, with bounds calculated from original image proportions and
reviewed focal points. No generated scenery or runtime image processing is used.
"""

import argparse
import hashlib
import io
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
START = "-- BEGIN GENERATED RUN IMAGE MAP"
END = "-- END GENERATED RUN IMAGE MAP"


def recipe():
    return json.loads(
        (ROOT / "data/run-image-sources.json").read_text(encoding="utf-8")
    )


def framing(size, focus, viewport):
    """Return cover UVs preserving source geometry in the fixed native viewport."""
    width, height = size
    target = viewport[0] / viewport[1]
    assert width > 0 and height > 0 and all(0 <= value <= 1 for value in focus)
    u, v = min(1, target * height / width), min(1, width / (target * height))
    left = max(0, min(1 - u, focus[0] - u / 2))
    top = max(0, min(1 - v, focus[1] - v / 2))
    return tuple(round(value, 6) for value in (left, left + u, top, top + v))


def build(check=False):
    data = recipe()
    catalog = json.loads(
        (ROOT / "data/catalogs/gameText.json").read_text(encoding="utf-8")
    )
    known = {
        key.split(".")[1]
        for key in catalog["en"]
        if key.startswith("zone.") and key.endswith(".name")
    }
    assert (
        set(data["zones"]) == known
    ), "zone photos must cover the exact supported map IDs"
    lines = [START, "local runImages = {"]
    for zone, entry in sorted(data["zones"].items()):
        assert entry["texture"] == "RunZone-" + zone + ".tga"
        source = ROOT / entry["source"]
        assert source.resolve().is_relative_to((ROOT / "design/run-images").resolve())
        assert hashlib.sha256(source.read_bytes()).hexdigest() == entry["sha256"]
        image = Image.open(source)
        assert list(image.size) == entry["size"]
        output = image.convert("RGBA").resize((256, 256), Image.Resampling.LANCZOS)
        buffer = io.BytesIO()
        output.save(buffer, format="TGA")
        target = ROOT / "AzerothStats/media" / entry["texture"]
        if check:
            assert target.read_bytes() == buffer.getvalue(), entry["texture"]
        else:
            target.write_bytes(buffer.getvalue())
        uv = ", ".join(
            format(value, ".6f").rstrip("0").rstrip(".")
            for value in framing(image.size, entry["focus"], data["viewport"])
        )
        lines.append(f'    {zone} = {{ "{entry["texture"]}", {uv} }},')
    lines += ["}", END]
    theme = ROOT / "AzerothStats/Theme.lua"
    text = theme.read_text(encoding="utf-8")
    a, b = text.index(START), text.index(END) + len(END)
    replacement = text[:a] + "\n".join(lines) + text[b:]
    if check:
        assert text == replacement, "native zone framing map drift"
    else:
        theme.write_text(replacement, encoding="utf-8", newline="\n")
    print(
        "12 supplied zone photos: source hashes, 256-pixel encoding and native framing verified"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    build(parser.parse_args().check)
