"""Single allowlist for the player package: runtime, user docs and fixed assets."""

from pathlib import Path
import re

PLAYER_DOCS = ("README.md", "CHANGELOG.md", "CREDITS.md")
MEDIA = (
    "AzerothSans.ttf",
    "AzerothSerif.ttf",
    "AzerothSans-zh.otf",
    "AzerothSans-ja.otf",
    "AzerothSans-ko.otf",
    "ChronicleEdge.tga",
    "ChronicleGrain.tga",
    "GrimoirePaper.tga",
    "ChronicleSeal.tga",
    "ChronicleIcons.tga",
    "FavoriteHeartEmpty.tga",
    "FavoriteHeartFilled.tga",
    "OFL-NotoSans.txt",
    "OFL-NotoCJK.txt",
) + tuple(
    [f"ChronicleGlyph{i:02d}.tga" for i in range(1, 17)]
    + [f"ChroniclePlate{i}.tga" for i in range(1, 5)]
    + [f"GrimoirePlate{i}.tga" for i in range(1, 5)]
    + [
        "RunZone-" + zone + ".tga"
        for zone in (
            "ab",
            "aq",
            "arena",
            "av",
            "brm",
            "duskwood",
            "elwynn",
            "feralas",
            "naxx",
            "sm",
            "ungoro",
            "wsg",
        )
    ]
)


def public_files(addon: Path):
    """Return reviewed relative filenames; test/development files never qualify."""
    modules = [
        line.strip()
        for line in (addon / "AzerothStats.toc")
        .read_text(encoding="utf-8")
        .splitlines()
        if line.strip() and not line.startswith("#")
    ]
    assert len(modules) == len(set(modules))
    assert all(re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*\.lua", name) for name in modules)
    assert set(modules) == {path.name for path in addon.glob("*.lua")}
    names = (
        modules
        + ["AzerothStats.toc"]
        + list(PLAYER_DOCS)
        + ["media/" + name for name in MEDIA]
    )
    assert all((addon / name).is_file() for name in names)
    return sorted(names)
