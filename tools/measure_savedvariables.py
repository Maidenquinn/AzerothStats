"""Read-only, metadata-only sizing of Azeroth Stats SavedVariables.

No file is opened or parsed; contents, character names and paths never appear
in stdout. Run after a normal client exit, not while the game is writing saves.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

NAMES = (
    "AzerothStats.lua",
    "AzerothStatsBackup.lua",
    "AzerothStatsAutoBackup.lua",
)


def measure(directory: Path) -> dict:
    if not directory.is_dir():
        raise ValueError("SavedVariables directory does not exist")
    result = {}
    for name in NAMES:
        path = directory / name
        # Reject symlinks to avoid reading metadata outside the supplied folder.
        if path.is_symlink():
            result[name] = {"status": "symlink-refused"}
        elif not path.exists():
            result[name] = {"status": "missing"}
        elif not path.is_file():
            result[name] = {"status": "not-a-file"}
        else:
            result[name] = {"status": "ok", "bytes": path.stat().st_size}
    result["total_bytes"] = sum(
        item.get("bytes", 0) for item in result.values() if isinstance(item, dict)
    )
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("savedvariables_directory", type=Path)
    args = parser.parse_args()
    print(json.dumps(measure(args.savedvariables_directory), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
