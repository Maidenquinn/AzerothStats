"""Rename a maintainer-supplied, hash-pinned OFL Noto Serif Bold input.

No network access. The original copyright/license records remain embedded. The
existing runtime filename is retained; only the heading face becomes bold.
"""

import argparse
import hashlib
import io
import json
from pathlib import Path
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent


def build(source, check=False):
    recipe = json.loads(
        (ROOT / "data/title-font-source.json").read_text(encoding="utf-8")
    )
    assert hashlib.sha256(source.read_bytes()).hexdigest() == recipe["sha256"]
    font = TTFont(source, recalcTimestamp=False)
    for record in font["name"].names:
        if record.nameID in {1, 3, 4, 6, 16}:
            record.string = recipe["family"].encode(record.getEncoding())
    output = io.BytesIO()
    font.save(output)
    target = ROOT / "AzerothStats/media" / recipe["output"]
    if check:
        assert target.read_bytes() == output.getvalue(), "title font encoding drift"
    else:
        target.write_bytes(output.getvalue())
    print(
        "Hash-pinned OFL heading font: embedded notices preserved, derivative renamed"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    build(args.input, args.check)
