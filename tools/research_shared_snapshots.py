"""EXPERIMENT ONLY: content-addressed snapshot model for sizing and round-trip tests.

This module is deliberately NOT loaded by the addon and must not process
player SavedVariables. Python JSON is a synthetic surrogate, not the WoW
client's Lua serializer or a production migration format.
"""

from __future__ import annotations

from copy import deepcopy
from hashlib import sha256
import json


def encode(value: object) -> bytes:
    """Deterministic surrogate encoding; never use as a Lua save format."""
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


class SharedSnapshotModel:
    def __init__(self) -> None:
        self.pool: dict[str, dict] = {}
        self.manifests: dict[str, dict] = {}
        self._serial = 0

    def save(self, database: dict, kind: str) -> str:
        """Take a logically atomic, independent snapshot of every DB field."""
        if kind not in {"manual", "auto"}:
            raise ValueError("unknown snapshot kind")
        if not isinstance(database.get("runs"), list):
            raise ValueError("runs must be a list")
        manifest = {
            "kind": kind,
            "run_refs": [],
            "rest": deepcopy({k: v for k, v in database.items() if k != "runs"}),
        }
        pending: dict[str, dict] = {}
        for run in database["runs"]:
            frozen = deepcopy(run)
            key = sha256(encode(frozen)).hexdigest()
            # Cryptographic keys are only a model; exact comparison still guards
            # the improbable collision and a corrupted pre-existing pool entry.
            existing = self.pool.get(key, pending.get(key))
            if existing is not None and existing != frozen:
                raise ValueError("conflicting run payload")
            pending[key] = frozen
            manifest["run_refs"].append(key)
        self._serial += 1
        snapshot_id = f"{kind}-{self._serial}"
        # Commit only after every run and the rest of the DB are captured.
        self.pool.update(pending)
        self.manifests[snapshot_id] = manifest
        return snapshot_id

    def restore(self, snapshot_id: str) -> dict:
        manifest = self.manifests[snapshot_id]
        result = deepcopy(manifest["rest"])
        # Missing payload aborts before any returned DB can become live.
        result["runs"] = [deepcopy(self.pool[key]) for key in manifest["run_refs"]]
        return result

    def remove(self, snapshot_id: str) -> None:
        del self.manifests[snapshot_id]

    def gc(self) -> int:
        """Only remove versions unreferenced by ANY remaining snapshot."""
        live = {
            ref
            for m in self.manifests.values()
            for ref in m["run_refs"]
        }
        stale = [key for key in self.pool if key not in live]
        for key in stale:
            del self.pool[key]
        return len(stale)

    def surrogate_bytes(self) -> int:
        return len(encode({"pool": self.pool, "manifests": self.manifests}))


def full_copy_bytes(databases: list[dict]) -> int:
    """Synthetic equivalent to full backup copies, NOT actual disk bytes."""
    return len(encode(databases))


def example(count: int, snapshots: int) -> tuple[int, int]:
    """Stable fixtures with a few edits, never real player data."""
    data = {
        "schema": 1,
        "sequence": count,
        "runs": [
            {
                "id": f"run-{i}",
                "values": {"damage": i * 9, "duration": i + 30},
                "journal": [{"event": "start", "at": i}] * 3,
            }
            for i in range(count)
        ],
        "totals": {"runs": count, "wins": count // 2},
        "records": {"damage": count * 9},
        "settings": {"language": "en"},
    }
    model = SharedSnapshotModel()
    full = []
    for i in range(snapshots):
        data["sequence"] = count + i
        data["totals"]["runs"] = count + i
        if i:
            data["runs"][0]["note"] = f"edited note {i}"
        frozen = deepcopy(data)
        full.append(frozen)
        identity = model.save(data, "manual" if i == 0 else "auto")
        assert model.restore(identity) == frozen
    return full_copy_bytes(full), model.surrogate_bytes()


if __name__ == "__main__":
    for count in (100, 500, 1000):
        before, after = example(count, 3)
        print(
            f"synthetic_runs={count} snapshots=3 "
            f"full_bytes={before} shared_bytes={after} "
            f"proxy_reduction_pct={(1 - after / before) * 100:.1f}"
        )
