"""Native portrait catalog and fixed-package regression checks."""

import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class Portraits(unittest.TestCase):
    def test_exact_catalog_and_asset_hashes(self):
        catalog = json.loads(
            (ROOT / "data/catalogs/creaturePortraits.json").read_text(encoding="utf-8")
        )
        source = json.loads(
            (ROOT / "data/nemesis-portrait-sources.json").read_text(encoding="utf-8")
        )
        for name, asset in catalog.items():
            self.assertTrue(name)
            self.assertRegex(asset, r"^d[0-9]+$")
            self.assertIn("Nemesis-" + asset + ".tga", source["assets"])
        for name, expected in source["assets"].items():
            self.assertEqual(
                hashlib.sha256(
                    (ROOT / "AzerothStats/media" / name).read_bytes()
                ).hexdigest(),
                expected,
            )
        for name in source["ambiguousNamesExcluded"]:
            self.assertNotIn(name, catalog)
