#!/usr/bin/env python3
"""Compare a reference image and rendered slide, including critical regions."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageStat


def mae(a: Image.Image, b: Image.Image) -> float:
    stat = ImageStat.Stat(ImageChops.difference(a, b))
    return round(sum(stat.mean) / len(stat.mean), 6)


def load_regions(path: str) -> list[dict]:
    if not path:
        return []
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if isinstance(data, list):
        return data
    if "critical_regions" in data:
        return data["critical_regions"]
    slides = data.get("slides", [])
    return slides[0].get("critical_regions", []) if slides else []


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("reference")
    ap.add_argument("rendered")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--regions", default="", help="JSON list, scene, or object with critical_regions")
    ap.add_argument("--blur-radius", type=float, default=4.0)
    ap.add_argument("--diff-gain", type=float, default=4.0)
    args = ap.parse_args()

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    ref = Image.open(args.reference).convert("RGB")
    rendered = Image.open(args.rendered).convert("RGB").resize(ref.size, Image.Resampling.LANCZOS)
    ref.save(out / "reference-normalized.png")
    rendered.save(out / "render-normalized.png")

    overlay = Image.blend(ref, rendered, 0.5)
    overlay.save(out / "overlay-50.png")
    diff = ImageChops.difference(ref, rendered)
    ImageEnhance.Brightness(diff).enhance(args.diff_gain).save(out / "diff-amplified.png")

    metrics = {
        "reference": str(Path(args.reference).resolve()),
        "rendered": str(Path(args.rendered).resolve()),
        "width": ref.width,
        "height": ref.height,
        "rgb_mae": mae(ref, rendered),
        "blurred_layout_mae": mae(
            ref.filter(ImageFilter.GaussianBlur(args.blur_radius)),
            rendered.filter(ImageFilter.GaussianBlur(args.blur_radius)),
        ),
        "regions": [],
    }

    for region in load_regions(args.regions):
        x, y, w, h = [int(region[k]) for k in ("x", "y", "w", "h")]
        x, y = max(0, x), max(0, y)
        w, h = max(1, min(w, ref.width - x)), max(1, min(h, ref.height - y))
        box = (x, y, x + w, y + h)
        rc, oc = ref.crop(box), rendered.crop(box)
        rid = str(region.get("id", f"region-{len(metrics['regions']) + 1}"))
        safe = "".join(ch if ch.isalnum() or ch in "-_" else "_" for ch in rid)
        rc.save(out / f"{safe}-reference.png")
        oc.save(out / f"{safe}-render.png")
        ImageEnhance.Brightness(ImageChops.difference(rc, oc)).enhance(args.diff_gain).save(out / f"{safe}-diff.png")
        metrics["regions"].append({"id": rid, "bbox": [x, y, w, h], "rgb_mae": mae(rc, oc)})

    (out / "comparison.json").write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(metrics, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

