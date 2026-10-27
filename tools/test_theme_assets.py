"""Regression contracts for the original, player-packaged texture set."""

import io
import unittest
from pathlib import Path
from PIL import Image
from build_theme_assets import build


class ThemeAssetsTests(unittest.TestCase):
    def test_run_photo_framing_preserves_geometry_and_has_no_source_cuts(self):
        from build_run_images import recipe, framing

        data = recipe()
        for entry in data["zones"].values():
            left, right, top, bottom = framing(
                entry["size"], entry["focus"], data["viewport"]
            )
            self.assertTrue(0 <= left < right <= 1 and 0 <= top < bottom <= 1)
            width, height = entry["size"]
            self.assertAlmostEqual(
                (right - left) * width / ((bottom - top) * height), 178 / 66, places=4
            )

    def test_native_components_stay_small_and_preserve_alpha(self):
        from encode_painted_assets import ASSETS, images
        from package_policy import MEDIA

        media = Path(__file__).resolve().parent.parent / "AzerothStats/media"
        self.assertEqual(set(ASSETS), {name for name, _ in images()})
        self.assertTrue(set(ASSETS) <= set(MEDIA))
        for name in MEDIA:
            if not name.endswith(".tga"):
                continue
            with self.subTest(name=name), Image.open(media / name) as image:
                self.assertLessEqual(max(image.size), 256)
                self.assertEqual(image.mode, "RGBA")
                self.assertIn(image.width, {32, 128, 256})
                self.assertIn(image.height, {32, 128, 256})
                if name.startswith("ChronicleGlyph"):
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
