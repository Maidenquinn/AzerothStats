"""Negative tests for the review scanner: useful checks must reject bad samples."""

from pathlib import Path
import tempfile
import unittest
from security_review import LiteralCatalog, inspect, tokens


class CatalogPolicyTests(unittest.TestCase):
    def check_catalog(self, source):
        LiteralCatalog(tokens(source), {"gameText"}).check()

    def test_strings_are_data(self):
        self.check_catalog(
            'AzerothStats.gameText = { ["label"] = "os.execute is text here", ["rows"] = {true, 2} }'
        )

    def test_literal_catalog_rejects_expressions(self):
        for value in ['os.execute("x")', "(function() return {} end)()", '"x" .. "y"']:
            with self.subTest(value=value), self.assertRaises(AssertionError):
                self.check_catalog("AzerothStats.gameText = " + value)

    def test_computed_key_is_rejected(self):
        with self.assertRaises(AssertionError):
            self.check_catalog('AzerothStats.gameText = { [getglobal("x")] = 1 }')

    def test_unexpected_global_is_rejected(self):
        with self.assertRaises(AssertionError):
            self.check_catalog("OtherAddon.gameText = {}")
        with self.assertRaises(AssertionError):
            self.check_catalog("AzerothStats.RunScript = {}")

    def test_only_own_direct_alias_is_allowed(self):
        self.check_catalog("local A=AzerothStats;A.gameText={}")
        with self.assertRaises(AssertionError):
            self.check_catalog('local A=getglobal("AzerothStats");A.gameText={}')

    def test_comments_and_quoted_api_names_do_not_execute(self):
        stream = tokens(
            '-- os.execute("not code")\nAzerothStats.gameText={ ["x"]="function() end" }'
        )
        self.assertNotIn(
            "execute", [token.text for token in stream if token.kind == "identifier"]
        )
        LiteralCatalog(stream, {"gameText"}).check()

    def test_runtime_forbidden_call_is_detected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            addon = root / "AzerothStats"
            addon.mkdir()
            (addon / "AzerothStats.toc").write_text(
                "## Interface: 11200\n## SavedVariables: AzerothStatsDB\nCore.lua\n",
                encoding="utf-8",
            )
            (addon / "Core.lua").write_text(
                'SendAddonMessage("x","payload","PARTY")', encoding="utf-8"
            )
            with self.assertRaises(AssertionError):
                inspect(root)


if __name__ == "__main__":
    unittest.main()
