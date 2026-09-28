#!/usr/bin/env python3
"""Check the iPhone 17 Pro @3x capture of ios-style-bounds/index.json."""

import argparse
from pathlib import Path

from PIL import Image


def color_region(image: Image.Image, color: tuple[int, int, int]):
    pixels = image.load()
    points = [
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if pixels[x, y] == color
    ]
    if not points:
        raise AssertionError(f"Expected color {color} was absent")
    xs, ys = zip(*points)
    return len(points), (min(xs), min(ys), max(xs) + 1, max(ys) + 1)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("screenshot", type=Path)
    args = parser.parse_args()
    image = Image.open(args.screenshot).convert("RGB")
    assert image.width == 1206, f"Expected iPhone 17 Pro @3x capture, got {image.size}"

    red_count, red = color_region(image, (221, 51, 51))
    blue_count, blue = color_region(image, (36, 69, 217))
    green_count, green = color_region(image, (0, 170, 0))
    green_width = green[2] - green[0]
    green_height = green[3] - green[1]
    blue_width = blue[2] - blue[0]
    blue_height = blue[3] - blue[1]

    # The authored 150x100-point tile must paint across its frame and padding.
    assert red_count > 100_000, f"Fixed-size fill is too small: {red_count} pixels"
    assert abs(green_width - 450) <= 6 and abs(green_height - 300) <= 6, (
        f"Rounded border misses the 150x100-point bounds: {green}"
    )
    assert green[0] < red[0] < red[2] < green[2] and green[1] < red[1] < red[3] < green[3]
    assert green_count > 10_000, f"Border is incomplete: {green_count} pixels"

    # The second label has padding but no explicit size. Its painted area must
    # exceed the intrinsic PAD glyphs by roughly 20 points on every side.
    assert blue_count > 25_000, f"Padding-only fill is too small: {blue_count} pixels"
    assert blue_width >= 180 and blue_height >= 150, f"Padding bounds are too small: {blue}"
    assert blue[1] >= green[3], "The padding-only label overlapped the fixed tile"

    print(
        f"PASS: fixed fill {red_count} px; padding fill {blue_count} px; "
        f"rounded border {green_width}x{green_height} px ({green_count} green px)"
    )


if __name__ == "__main__":
    main()
