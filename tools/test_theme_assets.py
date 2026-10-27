"""Regression contracts for the original, player-packaged texture set."""

import io
import unittest
from pathlib import Path
from PIL import Image
from build_theme_assets import build


class ThemeAssetsTests(unittest.TestCase):
    def test_painted_atlases_have_native_size_and_real_alpha(self):
        media = Path(__file__).resolve().parent.parent / "AzerothStats/media"
        for name in [
            "ChronicleGlyphs",
            "ChronicleLandscapes",
            "ChronicleSurfaces",
            "ChronicleWindow",
        ]:
            with self.subTest(name=name):
                with Image.open(media / (name + ".tga")) as image:
                    self.assertEqual(image.size, (1024, 1024))
                    self.assertEqual(image.mode, "RGBA")
                    if name in {"ChronicleGlyphs", "ChronicleWindow"}:
                        self.assertEqual(image.getchannel("A").getextrema(), (0, 255))

    def test_original_assets_have_native_dimensions_and_alpha(self):
        assets = build()
        dimensions = {
            "ChronicleSeal.tga": (128, 128),
            "ChronicleEdge.tga": (256, 32),
            "ChronicleIcons.tga": (256, 256),
            "ChronicleGrain.tga": (128, 128),
        }
        self.assertEqual(set(assets), set(dimensions))
        for name, image in assets.items():
            with self.subTest(name=name):
                self.assertEqual(image.size, dimensions[name])
                self.assertEqual(image.mode, "RGBA")
                stream = io.BytesIO()
                image.save(stream, format="TGA")
                raw = stream.getvalue()
                self.assertEqual(raw[2], 2)
                self.assertEqual(raw[16], 32)
                self.assertEqual(raw[17] & 15, 8)
                self.assertLess(image.getchannel("A").getextrema()[0], 255)

    def test_seeded_vector_recipe_is_deterministic(self):
        first, second = build(), build()
        for name in first:
            self.assertEqual(first[name].tobytes(), second[name].tobytes(), name)
