"""The optional compatibility reader must only read explicitly selected inputs."""

from pathlib import Path
import hashlib
import tempfile
import unittest

from client_fixture import read_fixture


class FixtureTests(unittest.TestCase):
    def test_trusted_utf8_fixture_is_read_without_evaluation(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "api.lua"
            raw = b'\xef\xbb\xbferror("must not execute while reading")'
            path.write_bytes(raw)
            source, metadata = read_fixture(api=path)
            self.assertTrue(source.startswith("error("))
            self.assertEqual(path.read_bytes(), raw)
            self.assertEqual(metadata["apiSha256"], hashlib.sha256(raw).hexdigest())

    def test_missing_binary_marker_fails_without_modification(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "client.bin"
            path.write_bytes(b"not a game client")
            with self.assertRaisesRegex(AssertionError, "marker changed"):
                read_fixture(client=path)
            self.assertEqual(path.read_bytes(), b"not a game client")

    def test_known_binary_span_is_read_only(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "client.bin"
            source = b'-- Azeroth Survivors: the run for addons\nAZSApiFrame:SetScript("OnEvent", AZS_ApiOnEvent);'
            raw = b"prefix" + source + b"suffix"
            path.write_bytes(raw)
            actual, metadata = read_fixture(client=path)
            self.assertEqual(actual.encode("utf-8"), source)
            self.assertEqual(metadata["apiOffset"], 6)
            self.assertEqual(path.read_bytes(), raw)

    def test_oversized_fixture_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "api.lua"
            path.write_bytes(b" " * 2000001)
            with self.assertRaisesRegex(AssertionError, "large"):
                read_fixture(api=path)
