"""Metadata-only SavedVariables measurement regression tests."""
import tempfile
import unittest
from pathlib import Path

from measure_savedvariables import measure


class StorageMeasurementTests(unittest.TestCase):
    def test_missing_files_and_exact_sizes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "AzerothStats.lua").write_bytes(b"data" * 3)
            (root / "AzerothStatsBackup.lua").write_bytes(b"x")
            report = measure(root)
            self.assertEqual(report["AzerothStats.lua"], {"status": "ok", "bytes": 12})
            self.assertEqual(
                report["AzerothStatsBackup.lua"], {"status": "ok", "bytes": 1}
            )
            self.assertEqual(
                report["AzerothStatsAutoBackup.lua"], {"status": "missing"}
            )
            self.assertEqual(report["total_bytes"], 13)

    def test_does_not_open_or_modify_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "AzerothStats.lua"
            original = b"secret character data that must never be printed"
            target.write_bytes(original)
            before = target.stat().st_mtime_ns
            self.assertEqual(measure(root)["total_bytes"], len(original))
            self.assertEqual(target.read_bytes(), original)
            self.assertEqual(target.stat().st_mtime_ns, before)
            self.assertNotIn("secret", repr(measure(root)))

    def test_refuses_directory_and_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "AzerothStatsBackup.lua").mkdir()
            (root / "outside").write_bytes(b"x")
            (root / "AzerothStats.lua").symlink_to(root / "outside")
            report = measure(root)
            self.assertEqual(
                report["AzerothStats.lua"]["status"], "symlink-refused"
            )
            self.assertEqual(
                report["AzerothStatsBackup.lua"]["status"], "not-a-file"
            )
            self.assertEqual(report["total_bytes"], 0)

    def test_missing_directory_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                measure(Path(directory) / "missing")


if __name__ == "__main__":
    unittest.main()
