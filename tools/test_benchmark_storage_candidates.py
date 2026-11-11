"""Synthetic storage study regression tests (no user data)."""

import unittest
import zlib

from benchmark_storage_candidates import benchmark, make_runs, serialized_bytes


class StorageStudyTests(unittest.TestCase):
    def test_deterministic_reversible_payload(self):
        first = serialized_bytes(make_runs(100))
        second = serialized_bytes(make_runs(100))
        self.assertEqual(first, second)
        self.assertEqual(zlib.decompress(zlib.compress(first)), first)
        self.assertIn(b"unknownExtension", first)

    def test_snapshot_amplification(self):
        result = benchmark(100, 1, 2)
        self.assertEqual(
            result["json_proxy_total_bytes"],
            result["json_proxy_active_bytes"]
            + 3 * result["json_proxy_snapshot_bytes"],
        )
        self.assertEqual(
            result["json_proxy_manual_bytes"], result["json_proxy_snapshot_bytes"]
        )
        self.assertFalse(result["compression_usable_in_addon"])

    def test_zero_backups_and_empty_runs(self):
        result = benchmark(0, 0, 0)
        self.assertEqual(
            result["json_proxy_total_bytes"], result["json_proxy_active_bytes"]
        )
        self.assertEqual(result["manual_snapshots"], 0)
        self.assertEqual(result["automatic_snapshots"], 0)

    def test_reject_invalid_parameters(self):
        for count, manual, automatic in (
            (-1, 0, 0),
            (1001, 0, 0),
            (1, -1, 0),
            (1, 0, 16),
        ):
            with self.assertRaises(ValueError):
                benchmark(count, manual, automatic)

    def test_monotonic_size_and_nonzero_ratio(self):
        measurements = [benchmark(n, 0, 0) for n in (100, 500, 1000)]
        sizes = [m["json_proxy_active_bytes"] for m in measurements]
        self.assertEqual(sizes, sorted(sizes))
        for measurement in measurements:
            self.assertGreater(measurement["zlib_theoretical_ratio"], 0)
            self.assertTrue(measurement["format"].startswith("synthetic JSON"))


if __name__ == "__main__":
    unittest.main()
