"""Synthetic storage baseline, backup amplification and compression upper bound.

This does not parse real SavedVariables or imply Lua 5.0/zlib compatibility.
JSON is a reproducible proxy, NOT Blizzard's disk serialization format.
"""

from __future__ import annotations

import argparse
import json
import zlib


def make_runs(count: int) -> list[dict]:
    if not 0 <= count <= 1000:
        raise ValueError("Synthetic run count must be between 0 and 1000")
    result = []
    for i in range(count):
        result.append(
            {
                "id": f"synthetic-{i + 1}",
                "class": "warrior",
                "zone": "feralas",
                "status": "ended",
                "result": "victory",
                "values": {"duration": 180, "damage": (i + 1) * 10},
                "events": [
                    {"kind": "level", "name": "Synthetic level up", "at": 60},
                    {"kind": "spell", "name": "Synthetic damage source", "at": 90},
                ],
                "unknownExtension": {"preserveMe": f"value-{i + 1}"},
            }
        )
    return result


def serialized_bytes(value: object) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")


def benchmark(count: int, manual: int, automatic: int) -> dict:
    if not 0 <= manual <= 15 or not 0 <= automatic <= 15:
        raise ValueError("Snapshot counts must each be between 0 and 15")
    runs = make_runs(count)
    data = {"schema": 1, "runs": runs, "settings": {"language": "fr"}}
    raw = serialized_bytes(data)
    compressed = zlib.compress(raw, level=6)
    if zlib.decompress(compressed) != raw:
        raise AssertionError("Lossless synthetic round trip failed")
    # Each snapshot is a *full* JSON proxy copy plus a small metadata wrapper.
    # Real snapshot contents and native game serialization can differ.
    snapshot = serialized_bytes({"id": 1, "at": 0, "data": data, "legacy": False})
    manual_bytes = len(snapshot) * manual
    automatic_bytes = len(snapshot) * automatic
    return {
        "synthetic_runs": count,
        "manual_snapshots": manual,
        "automatic_snapshots": automatic,
        "json_proxy_active_bytes": len(raw),
        "json_proxy_snapshot_bytes": len(snapshot),
        "json_proxy_manual_bytes": manual_bytes,
        "json_proxy_auto_bytes": automatic_bytes,
        "json_proxy_total_bytes": len(raw) + manual_bytes + automatic_bytes,
        "zlib_theoretical_bytes": len(compressed),
        "zlib_theoretical_ratio": round(len(compressed) / max(1, len(raw)), 4),
        "format": "synthetic JSON proxy; NOT native SavedVariables",
        "compression_usable_in_addon": False,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manual", type=int, default=1)
    parser.add_argument("--automatic", type=int, default=2)
    args = parser.parse_args()
    results = [
        benchmark(count, args.manual, args.automatic) for count in (100, 500, 1000)
    ]
    print(json.dumps(results, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
