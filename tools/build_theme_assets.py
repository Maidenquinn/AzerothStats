"""Generate original geometric Chroniques UI artwork; no game assets or image inputs.

Pillow is a developer-only encoder/rasterizer. Fixed seeds and geometry make this
small texture set reproducible. The edge follows the native 8-tile backdrop layout.
"""

from pathlib import Path
import argparse
import io
import math
import random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent / "AzerothStats" / "media"
GOLD = (214, 179, 105, 255)
LIGHT = (243, 220, 158, 255)
DARK = (83, 60, 29, 255)
SCALE = 4


def art(width, height):
    image = Image.new("RGBA", (width * SCALE, height * SCALE))
    return image, ImageDraw.Draw(image)


def line(draw, points, color=GOLD, width=2):
    draw.line(
        [(int(x * SCALE), int(y * SCALE)) for x, y in points],
        fill=color,
        width=width * SCALE,
    )


def polygon(draw, points, fill=GOLD):
    draw.polygon([(int(x * SCALE), int(y * SCALE)) for x, y in points], fill=fill)


def circle(draw, box, color=GOLD, width=2, fill=None):
    draw.ellipse(
        tuple(int(v * SCALE) for v in box),
        outline=color,
        width=width * SCALE,
        fill=fill,
    )


def build():
    assets = {}
    seal, draw = art(128, 128)
    for inset, color, width in [
        (6, DARK, 5),
        (9, GOLD, 3),
        (14, LIGHT, 1),
        (23, DARK, 3),
        (25, GOLD, 1),
    ]:
        circle(
            draw,
            (inset, inset, 128 - inset, 128 - inset),
            color,
            width,
            (17, 27, 34, 255) if inset == 6 else None,
        )
    for angle in range(0, 360, 45):
        radians = math.radians(angle)
        length = 53 if angle % 90 == 0 else 34
        x, y = math.sin(radians), -math.cos(radians)
        points = [
            (64 + x * length, 64 + y * length),
            (64 - y * 9, 64 + x * 9),
            (64, 64),
            (64 + y * 9, 64 - x * 9),
        ]
        polygon(draw, points, LIGHT if angle % 90 == 0 else GOLD)
        polygon(draw, [points[0], points[1], points[2]], DARK)
    circle(draw, (58, 58, 70, 70), LIGHT, 2, GOLD)
    assets["ChronicleSeal.tga"] = seal.resize((128, 128), Image.Resampling.LANCZOS)

    edge = Image.new("RGBA", (256, 32))
    for tile in range(8):
        piece, draw = art(32, 32)
        if tile < 2:
            x = 4 if tile == 0 else 27
            line(draw, [(x, 0), (x, 32)], DARK, 5)
            line(draw, [(x, 0), (x, 32)], GOLD, 2)
            line(
                draw,
                [(x + (2 if tile == 0 else -2), 0), (x + (2 if tile == 0 else -2), 32)],
                LIGHT,
                1,
            )
        elif tile < 4:
            y = 4 if tile == 2 else 27
            line(draw, [(0, y), (32, y)], DARK, 5)
            line(draw, [(0, y), (32, y)], GOLD, 2)
            line(
                draw,
                [(0, y + (2 if tile == 2 else -2)), (32, y + (2 if tile == 2 else -2))],
                LIGHT,
                1,
            )
        else:
            # Design top-left once, then reflect into the remaining native corners.
            line(draw, [(4, 32), (4, 4), (32, 4)], DARK, 5)
            line(draw, [(4, 32), (4, 4), (32, 4)], GOLD, 2)
            polygon(draw, [(4, 4), (23, 7), (7, 23), (10, 10)], DARK)
            line(draw, [(4, 4), (23, 7), (7, 23)], GOLD, 2)
            line(draw, [(4, 4), (10, 10), (7, 23)], LIGHT, 1)
            if tile in (5, 7):
                piece = piece.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if tile in (6, 7):
                piece = piece.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        edge.paste(piece.resize((32, 32), Image.Resampling.LANCZOS), (tile * 32, 0))
    assets["ChronicleEdge.tga"] = edge

    rng = random.Random(1671)
    grain = Image.new("RGBA", (128, 128))
    grain.putdata(
        [(v, v, v, 75) for v in (rng.randint(70, 175) for _ in range(128 * 128))]
    )
    assets["ChronicleGrain.tga"] = grain

    atlas = Image.new("RGBA", (256, 256))
    for index in range(12):
        glyph, draw = art(64, 64)
        if index in (0, 1, 8):
            for x, height in [(16, 18), (29, 30), (42, 40)]:
                polygon(
                    draw,
                    [(x, 52), (x, 52 - height), (x + 7, 52 - height), (x + 7, 52)],
                    GOLD,
                )
        elif index == 2:
            circle(draw, (10, 10, 54, 54), GOLD, 3)
            line(draw, [(32, 18), (32, 32), (44, 38)], LIGHT, 3)
        elif index == 3:
            for flip in (False, True):
                points = [(14, 10), (20, 10), (47, 43), (43, 47)]
                polygon(draw, [(64 - x if flip else x, y) for x, y in points], LIGHT)
                line(
                    draw,
                    [(64 - x if flip else x, y) for x, y in [(35, 47), (48, 35)]],
                    GOLD,
                    4,
                )
        elif index == 4:
            polygon(
                draw,
                [
                    (16, 17),
                    (32, 8),
                    (48, 17),
                    (50, 44),
                    (37, 55),
                    (32, 30),
                    (27, 55),
                    (14, 44),
                ],
                GOLD,
            )
            line(draw, [(22, 24), (42, 24)], DARK, 3)
        elif index == 5:
            polygon(draw, [(18, 13), (46, 13), (42, 35), (32, 41), (22, 35)], GOLD)
            line(draw, [(18, 17), (10, 17), (12, 30), (22, 32)], LIGHT, 2)
            line(draw, [(46, 17), (54, 17), (52, 30), (42, 32)], LIGHT, 2)
            line(draw, [(32, 40), (32, 51), (20, 51), (44, 51)], GOLD, 4)
        elif index in (6, 7):
            for angle in range(0, 360, 45):
                radians = math.radians(angle)
                line(
                    draw,
                    [
                        (32 + math.cos(radians) * 18, 32 + math.sin(radians) * 18),
                        (32 + math.cos(radians) * 25, 32 + math.sin(radians) * 25),
                    ],
                    GOLD,
                    7,
                )
            circle(draw, (15, 15, 49, 49), GOLD, 6)
            circle(draw, (25, 25, 39, 39), LIGHT, 2)
        elif index == 9:
            polygon(
                draw,
                [
                    (32, 55),
                    (9, 29),
                    (9, 18),
                    (18, 12),
                    (26, 13),
                    (32, 21),
                    (38, 13),
                    (46, 12),
                    (55, 18),
                    (55, 29),
                ],
                (207, 99, 111, 255),
            )
        elif index == 10:
            circle(draw, (13, 9, 51, 46), GOLD, 2, GOLD)
            circle(draw, (20, 23, 29, 34), DARK, 2, DARK)
            circle(draw, (35, 23, 44, 34), DARK, 2, DARK)
            line(draw, [(23, 44), (23, 54), (41, 54), (41, 44)], GOLD, 4)
        else:
            line(
                draw,
                [(9, 37), (19, 37), (25, 19), (33, 48), (42, 28), (48, 37), (55, 37)],
                LIGHT,
                3,
            )
        atlas.paste(
            glyph.resize((64, 64), Image.Resampling.LANCZOS),
            (index % 4 * 64, index // 4 * 64),
        )
    assets["ChronicleIcons.tga"] = atlas
    return assets


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for name, image in build().items():
        buffer = io.BytesIO()
        image.save(buffer, format="TGA")
        if args.check:
            assert (ROOT / name).read_bytes() == buffer.getvalue(), name
        else:
            (ROOT / name).write_bytes(buffer.getvalue())
    print("Four original, reproducible theme textures")
