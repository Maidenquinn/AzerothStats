"""Safety contracts for the isolated shared-backup model (not shipped Lua)."""

from copy import deepcopy
import unittest

from research_shared_snapshots import SharedSnapshotModel, example, full_copy_bytes


def fixture():
    return {
        "schema": 1,
        "sequence": 3,
        "runs": [
            {
                "id": "r1",
                "status": "ended",
                "note": "original",
                "values": {"damage": 4},
            },
            {"id": "r2", "status": "ended", "values": {"damage": 9}},
        ],
        "totals": {"runs": 4, "wins": 2},
        "records": {"damage": {"value": 9, "id": "r2"}},
        "classes": {"warrior": {"runs": 3}},
        "favorites": {"r1": True},
        "settings": {"autoBackupEveryRuns": 2},
    }


class SharedSnapshotResearchTests(unittest.TestCase):
    def test_roundtrip_and_later_changes(self):
        db = fixture()
        original = deepcopy(db)
        model = SharedSnapshotModel()
        old = model.save(db, "manual")
        db["runs"][0]["note"] = "edited"
        db["runs"].append({"id": "r3", "values": {"damage": 15}})
        db["totals"]["runs"] = 5
        db["records"]["damage"] = {"value": 15, "id": "r3"}
        new = model.save(db, "auto")
        self.assertEqual(model.restore(old), original)
        self.assertEqual(model.restore(new), db)
        self.assertEqual(model.restore(old)["runs"][0]["note"], "original")

    def test_deleted_snapshot_never_drops_referenced_versions(self):
        model = SharedSnapshotModel()
        db = fixture()
        first = model.save(db, "manual")
        db["runs"][0]["note"] = "changed"
        second = model.save(db, "auto")
        model.remove(first)
        model.gc()
        self.assertEqual(model.restore(second), db)
        self.assertEqual(len(model.pool), 2)
        self.assertEqual(len(model.manifests), 1)

    def test_missing_payload_fails_without_partial_live_database(self):
        model = SharedSnapshotModel()
        db = fixture()
        snapshot = model.save(db, "manual")
        key = model.manifests[snapshot]["run_refs"][0]
        model.pool.pop(key)
        original = deepcopy(db)
        with self.assertRaises(KeyError):
            model.restore(snapshot)
        self.assertEqual(db, original)

    def test_rejects_unknown_kind_and_malformed_run_collection(self):
        model = SharedSnapshotModel()
        db = fixture()
        with self.assertRaises(ValueError):
            model.save(db, "other")
        db["runs"] = None
        with self.assertRaises(ValueError):
            model.save(db, "manual")
        self.assertEqual(model.manifests, {})
        self.assertEqual(model.pool, {})

    def test_exact_other_state_not_only_timestamp_or_runs(self):
        model = SharedSnapshotModel()
        db = fixture()
        old = model.save(db, "manual")
        db["favorites"]["r2"] = True
        db["settings"]["autoBackupEveryRuns"] = 4
        db["totals"]["wins"] = 3
        updated = model.save(db, "manual")
        self.assertEqual(model.restore(old)["favorites"], {"r1": True})
        self.assertEqual(model.restore(old)["settings"], {"autoBackupEveryRuns": 2})
        self.assertEqual(model.restore(old)["totals"]["wins"], 2)
        self.assertEqual(model.restore(updated), db)

    def test_no_shared_mutable_references_between_restores(self):
        model = SharedSnapshotModel()
        db = fixture()
        saved = model.save(db, "manual")
        restored = model.restore(saved)
        restored["runs"][0]["values"]["damage"] = 999
        restored["totals"]["runs"] = 999
        self.assertEqual(model.restore(saved), fixture())

    def test_synthetic_shared_store_saves_bytes(self):
        for count in (100, 500, 1000):
            full_bytes, shared_bytes = example(count, 3)
            self.assertLess(shared_bytes, full_bytes)
            self.assertGreater(shared_bytes, 0)
            self.assertGreater(full_bytes, 0)

    def test_full_copy_formula_is_not_deduplicated(self):
        data = fixture()
        self.assertGreater(full_copy_bytes([data, data]), full_copy_bytes([data]))


if __name__ == "__main__":
    unittest.main()
