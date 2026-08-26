#!/usr/bin/env python3
"""Lint legacy or v2 image2ppt scene specifications."""

from __future__ import annotations

import argparse
import json
import math
import unicodedata
from pathlib import Path


def slides_from_scene(scene: dict) -> list[dict]:
    if "slides" in scene:
        return scene["slides"]
    return [{"id": "s01", "background": scene.get("background", "#FFFFFF"), "elements": scene.get("elements", [])}]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("scene")
    ap.add_argument("--json-out", default="")
    args = ap.parse_args()
    scene_path = Path(args.scene).resolve()
    scene = json.loads(scene_path.read_text(encoding="utf-8"))
    styles = scene.get("styles", {})
    units = scene.get("units", "in")
    errors: list[str] = []
    warnings: list[str] = []

    if units not in {"px", "in"}:
        errors.append(f"unsupported units: {units}")

    for slide_index, slide in enumerate(slides_from_scene(scene), 1):
        elements = slide.get("elements", [])
        ids = [e.get("id") for e in elements if e.get("id")]
        duplicates = sorted({x for x in ids if ids.count(x) > 1})
        if duplicates:
            errors.append(f"slide {slide_index}: duplicate ids {duplicates}")
        id_set = set(ids)
        parent_map = {}
        native_text = []
        for idx, e in enumerate(elements, 1):
            prefix = f"slide {slide_index} element {idx}"
            if "type" not in e:
                errors.append(f"{prefix}: missing type")
                continue
            if e.get("style_ref") and e["style_ref"] not in styles:
                errors.append(f"{prefix}: unknown style_ref {e['style_ref']}")
            if e.get("parent"):
                parent_map[e.get("id", f"#{idx}")] = e["parent"]
                if e["parent"] not in id_set:
                    errors.append(f"{prefix}: unknown parent {e['parent']}")
            for key in ("x", "y", "w", "h", "cx", "cy", "r", "x1", "y1", "x2", "y2"):
                if key in e and (not isinstance(e[key], (int, float)) or not math.isfinite(e[key])):
                    errors.append(f"{prefix}: {key} must be finite")
            if "w" in e and e["w"] <= 0 or "h" in e and e["h"] <= 0 or "r" in e and e["r"] <= 0:
                errors.append(f"{prefix}: non-positive geometry")
            if e["type"].lower() == "text":
                native_text.append(unicodedata.normalize("NFC", str(e.get("text", ""))))
            if e["type"].lower() == "picture":
                if "asset" not in e:
                    errors.append(f"{prefix}: picture missing asset")
                if e.get("contains_readable_text") is None:
                    warnings.append(f"{prefix}: picture should declare contains_readable_text")
            if e.get("visual_invariants") and not e.get("audit_mapping"):
                warnings.append(f"{prefix}: visual_invariants lack audit_mapping")

        for child in parent_map:
            seen = set()
            node = child
            while node in parent_map:
                if node in seen:
                    errors.append(f"slide {slide_index}: parent cycle involving {child}")
                    break
                seen.add(node)
                node = parent_map[node]

        corpus = "\n".join(native_text)
        for expected in slide.get("expected_text", []):
            normalized = unicodedata.normalize("NFC", str(expected))
            if normalized not in corpus:
                errors.append(f"slide {slide_index}: expected native text missing: {expected}")

    report = {"scene": str(scene_path), "version": scene.get("version", "legacy"), "errors": errors, "warnings": warnings}
    if args.json_out:
        out = Path(args.json_out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())

