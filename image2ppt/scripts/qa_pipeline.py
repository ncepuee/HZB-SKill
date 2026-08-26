#!/usr/bin/env python3
"""Orchestrate render, structural validation, and reference comparison."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pptx")
    ap.add_argument("--reference", default="")
    ap.add_argument("--scene", default="")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--mode", choices=["economy", "standard", "strict"], default="standard")
    ap.add_argument("--engine", choices=["auto", "powerpoint", "libreoffice"], default="auto")
    ap.add_argument("--width", type=int, default=1600)
    args = ap.parse_args()

    out = Path(args.out_dir).resolve()
    render_dir, qa_dir, compare_dir = out / "render", out / "qa", out / "compare"
    qa_dir.mkdir(parents=True, exist_ok=True)

    validate_cmd = [sys.executable, str(HERE / "validate_ppt.py"), args.pptx, "--json-out", str(qa_dir / "editability-report.json")]
    if args.scene:
        validate_cmd += ["--scene", args.scene]
        run([sys.executable, str(HERE / "scene_lint.py"), args.scene, "--json-out", str(qa_dir / "scene-lint.json")])
    run(validate_cmd)
    run([sys.executable, str(HERE / "render_ppt.py"), args.pptx, "--out-dir", str(render_dir), "--width", str(args.width), "--engine", args.engine])

    comparison = None
    if args.reference:
        rendered = render_dir / "slide-001.png"
        compare_cmd = [sys.executable, str(HERE / "compare_renders.py"), args.reference, str(rendered), "--out-dir", str(compare_dir)]
        if args.scene and args.mode in {"standard", "strict"}:
            compare_cmd += ["--regions", args.scene]
        run(compare_cmd)
        comparison = json.loads((compare_dir / "comparison.json").read_text(encoding="utf-8"))

    editability = json.loads((qa_dir / "editability-report.json").read_text(encoding="utf-8"))
    summary = {
        "mode": args.mode,
        "pptx": str(Path(args.pptx).resolve()),
        "renderer": args.engine,
        "editability_passed": editability["passed"],
        "error_count": len(editability["errors"]),
        "warning_count": len(editability["warnings"]),
        "comparison": comparison,
        "repair_limit": {"economy": 1, "standard": 2, "strict": 3}[args.mode],
    }
    (qa_dir / "qa-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if editability["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

