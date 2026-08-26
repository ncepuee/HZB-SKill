#!/usr/bin/env python3
"""
Inspect a reference image before rebuilding it in PowerPoint.

Usage:
    python scripts/inspect_reference.py reference.png
    python scripts/inspect_reference.py reference.png --grid 100 --out reference_grid.png

Outputs:
- image pixel dimensions
- aspect ratio
- recommended slide size
- optional coordinate grid overlay for manual element measurement
"""

from __future__ import annotations
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


def recommend_slide_size(width: int, height: int):
    ratio = width / height
    # Keep common PowerPoint formats when close.
    if abs(ratio - 16/9) < 0.04:
        return 13.333333, 7.5, "16:9"
    if abs(ratio - 4/3) < 0.04:
        return 10.0, 7.5, "4:3"
    # Preserve arbitrary reference aspect ratio with a 13.333-inch width.
    slide_w = 13.333333
    slide_h = slide_w / ratio
    return slide_w, slide_h, f"{ratio:.4f}:1"


def make_grid(image: Image.Image, step: int, out: Path):
    im = image.convert("RGB").copy()
    d = ImageDraw.Draw(im)
    w, h = im.size
    for x in range(0, w, step):
        d.line((x, 0, x, h), fill=(220, 50, 50), width=1)
        d.text((x + 3, 3), str(x), fill=(180, 0, 0))
    for y in range(0, h, step):
        d.line((0, y, w, y), fill=(50, 100, 220), width=1)
        d.text((3, y + 3), str(y), fill=(0, 60, 180))
    im.save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--grid", type=int, default=0, help="grid spacing in pixels")
    ap.add_argument("--out", default="", help="grid output path")
    args = ap.parse_args()

    path = Path(args.image)
    im = Image.open(path)
    w, h = im.size
    sw, sh, label = recommend_slide_size(w, h)

    print(f"Reference: {path}")
    print(f"Pixels: {w} x {h}")
    print(f"Aspect ratio: {w/h:.6f}")
    print(f"Recommended slide: {sw:.4f} x {sh:.4f} in ({label})")
    print()
    print("Coordinate mapping:")
    print("  x_ppt = x_img / image_width  * slide_width")
    print("  y_ppt = y_img / image_height * slide_height")

    if args.grid:
        out = Path(args.out) if args.out else path.with_name(path.stem + "_grid.png")
        make_grid(im, args.grid, out)
        print(f"Grid overlay written to: {out}")


if __name__ == "__main__":
    main()
