#!/usr/bin/env python3
"""Render PPTX slides to deterministic PNG filenames."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from pptx import Presentation


def ps_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def render_powerpoint(pptx: Path, out_dir: Path, width: int, height: int) -> list[Path]:
    script = f"""
$ErrorActionPreference = 'Stop'
$app = New-Object -ComObject PowerPoint.Application
try {{
  $presentation = $app.Presentations.Open({ps_literal(str(pptx))}, $true, $false, $false)
  try {{
    foreach ($slide in $presentation.Slides) {{
      $name = 'slide-' + $slide.SlideIndex.ToString('000') + '.png'
      $path = Join-Path {ps_literal(str(out_dir))} $name
      $slide.Export($path, 'PNG', {width}, {height})
    }}
  }} finally {{ $presentation.Close() }}
}} finally {{ $app.Quit() }}
"""
    fd, ps1 = tempfile.mkstemp(suffix=".ps1")
    os.close(fd)
    Path(ps1).write_text(script, encoding="utf-8-sig")
    try:
        subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps1], check=True)
    finally:
        Path(ps1).unlink(missing_ok=True)
    return sorted(out_dir.glob("slide-*.png"))


def render_libreoffice(pptx: Path, out_dir: Path, width: int) -> list[Path]:
    soffice = shutil.which("soffice") or shutil.which("libreoffice")
    pdftoppm = shutil.which("pdftoppm")
    if not soffice or not pdftoppm:
        raise RuntimeError("LibreOffice fallback requires soffice/libreoffice and pdftoppm")
    with tempfile.TemporaryDirectory() as td:
        subprocess.run([soffice, "--headless", "--convert-to", "pdf", "--outdir", td, str(pptx)], check=True)
        pdf = Path(td) / (pptx.stem + ".pdf")
        prefix = Path(td) / "slide"
        subprocess.run([pdftoppm, "-png", "-scale-to-x", str(width), "-scale-to-y", "-1", str(pdf), str(prefix)], check=True)
        results = []
        for idx, source in enumerate(sorted(Path(td).glob("slide-*.png")), 1):
            target = out_dir / f"slide-{idx:03d}.png"
            shutil.copy2(source, target)
            results.append(target)
        return results


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pptx")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--width", type=int, default=1600)
    ap.add_argument("--engine", choices=["auto", "powerpoint", "libreoffice"], default="auto")
    args = ap.parse_args()

    pptx = Path(args.pptx).resolve()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    prs = Presentation(pptx)
    height = max(1, round(args.width * prs.slide_height / prs.slide_width))

    errors = []
    files: list[Path] = []
    if args.engine in ("auto", "powerpoint") and os.name == "nt":
        try:
            files = render_powerpoint(pptx, out_dir, args.width, height)
        except Exception as exc:
            errors.append(f"PowerPoint: {exc}")
            if args.engine == "powerpoint":
                raise
    if not files and args.engine in ("auto", "libreoffice"):
        try:
            files = render_libreoffice(pptx, out_dir, args.width)
        except Exception as exc:
            errors.append(f"LibreOffice: {exc}")
            if args.engine == "libreoffice":
                raise
    if not files:
        raise SystemExit("No renderer succeeded: " + " | ".join(errors))
    for file in files:
        print(file)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

