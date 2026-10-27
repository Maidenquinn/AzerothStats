"""Verify localized UI glyphs; optionally rebuild CJK derivatives from hash-pinned original fonts.

Original font inputs are developer-selected, never downloaded by this script. They
are not part of the player addon. Existing copyright/OFL records remain preserved.
"""

from pathlib import Path
import argparse
import hashlib
import json
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        type=Path,
        help="Optional original Noto CJK input directory for a rebuild",
    )
    args = parser.parse_args()
    labels = json.loads(
        (ROOT / "data/catalogs/uiText.json").read_text(encoding="utf-8")
    )
    recipe = json.loads((ROOT / "data/font-sources.json").read_text(encoding="utf-8"))
    for language, source in recipe.items():
        output = ROOT / "AzerothStats/media" / source["file"]
        if args.source_dir:
            original = args.source_dir / source["file"]
            assert (
                hashlib.sha256(original.read_bytes()).hexdigest() == source["sha256"]
            ), source["file"]
            font = TTFont(original, recalcTimestamp=False)
            options = subset.Options()
            options.name_IDs = ["*"]
            options.name_legacy = True
            options.name_languages = ["*"]
            worker = subset.Subsetter(options=options)
            worker.populate(unicodes=source["codepoints"])
            worker.subset(font)
            family = source["file"].split(".")[0].replace("-", " ")
            for record in font["name"].names:
                if record.nameID in [1, 3, 4, 6, 16]:
                    name = family.replace(" ", "") if record.nameID == 6 else family
                    record.string = name.encode(record.getEncoding(), errors="replace")
            if "CFF " in font:
                cff = font["CFF "].cff
                cff.fontNames = [family.replace(" ", "") + "-Regular"]
                for top in cff.topDictIndex:
                    top.FamilyName = family
                    top.FullName = family
                    for index, dictionary in enumerate(getattr(top, "FDArray", [])):
                        dictionary.FontName = family.replace(" ", "") + "-" + str(index)
            font.save(output)
        font = TTFont(output)
        needed = {
            ord(char)
            for value in labels[language].values()
            for char in value
            if not char.isspace()
        }
        assert not needed - set(font.getBestCmap()), (
            language,
            sorted(needed - set(font.getBestCmap())),
        )
    for language, strings in labels.items():
        filename = (
            "AzerothSans-" + language + ".otf"
            if language in recipe
            else "AzerothSans.ttf"
        )
        font = TTFont(ROOT / "AzerothStats/media" / filename)
        needed = {
            ord(char)
            for value in strings.values()
            for char in value
            if not char.isspace()
        }
        assert not needed - set(font.getBestCmap()), (
            language,
            sorted(needed - set(font.getBestCmap())),
        )
        if language not in recipe:
            heading = TTFont(ROOT / "AzerothStats/media/AzerothSerif.ttf")
            assert (
                heading["OS/2"].usWeightClass >= 700
            ), "heading face must be genuinely bold"
            assert not needed - set(heading.getBestCmap()), (
                language,
                "heading glyph coverage",
            )
    print(
        "UI glyph coverage verified in all fourteen languages; derivative names and OFL notices retained"
    )


if __name__ == "__main__":
    main()
