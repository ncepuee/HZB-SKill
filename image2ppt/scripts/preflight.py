#!/usr/bin/env python3
"""Inspect inputs and local capabilities before an image-to-PPT reconstruction."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import platform
import shutil
import sys
from pathlib import Path


IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff", ".heic"}


def image_info(path: Path) -> dict:
    from PIL import Image, ImageOps

    with Image.open(path) as im:
        oriented = ImageOps.exif_transpose(im)
        return {
            "kind": "image",
            "width": oriented.width,
            "height": oriented.height,
            "aspect_ratio": round(oriented.width / oriented.height, 6),
            "mode": oriented.mode,
            "format": im.format,
            "frames": int(getattr(im, "n_frames", 1)),
        }


def pptx_info(path: Path) -> dict:
    from pptx import Presentation

    prs = Presentation(path)
    return {
        "kind": "pptx",
        "slides": len(prs.slides),
        "slide_width_emu": prs.slide_width,
        "slide_height_emu": prs.slide_height,
        "aspect_ratio": round(prs.slide_width / prs.slide_height, 6),
    }


def powerpoint_registered() -> bool:
    if os.name != "nt":
        return False
    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_CLASSES_ROOT, r"PowerPoint.Application\CLSID"):
            return True
    except OSError:
        return False


def find_font(name: str) -> list[str]:
    candidates: list[Path] = []
    hits: list[str] = []
    needle = name.casefold().replace(" ", "")
    if os.name == "nt":
        windows_fonts = Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts"
        candidates.extend([windows_fonts])
        local = os.environ.get("LOCALAPPDATA")
        if local:
            candidates.append(Path(local) / "Microsoft" / "Windows" / "Fonts")
        try:
            import winreg

            registry_keys = [
                (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"),
                (winreg.HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"),
            ]
            for hive, key_name in registry_keys:
                try:
                    with winreg.OpenKey(hive, key_name) as key:
                        index = 0
                        while True:
                            try:
                                display, filename, _ = winreg.EnumValue(key, index)
                            except OSError:
                                break
                            index += 1
                            if needle in display.casefold().replace(" ", ""):
                                path = Path(os.path.expandvars(str(filename)))
                                if not path.is_absolute():
                                    path = windows_fonts / path
                                hits.append(str(path))
                except OSError:
                    continue
        except OSError:
            pass
    else:
        candidates.extend([Path("/usr/share/fonts"), Path.home() / ".local" / "share" / "fonts"])
    for root in candidates:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.is_file() and needle in path.stem.casefold().replace(" ", ""):
                hits.append(str(path))
    return list(dict.fromkeys(hits))[:20]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", nargs="+")
    ap.add_argument("--fonts", default="", help="comma-separated font names to check")
    ap.add_argument("--json-out", default="")
    args = ap.parse_args()

    report = {
        "python": sys.version.split()[0],
        "platform": platform.platform(),
        "dependencies": {
            "Pillow": importlib.util.find_spec("PIL") is not None,
            "python-pptx": importlib.util.find_spec("pptx") is not None,
        },
        "renderers": {
            "powerpoint": powerpoint_registered(),
            "libreoffice": bool(shutil.which("soffice") or shutil.which("libreoffice")),
            "pdftoppm": bool(shutil.which("pdftoppm")),
        },
        "inputs": [],
        "fonts": {},
        "errors": [],
    }

    for raw in args.inputs:
        path = Path(raw).expanduser().resolve()
        item = {"path": str(path), "exists": path.exists(), "size": path.stat().st_size if path.exists() else 0}
        if not path.exists():
            report["errors"].append(f"missing input: {path}")
        elif path.suffix.lower() in IMAGE_EXTS:
            try:
                item.update(image_info(path))
            except Exception as exc:
                report["errors"].append(f"cannot decode image {path}: {exc}")
        elif path.suffix.lower() == ".pptx":
            try:
                item.update(pptx_info(path))
            except Exception as exc:
                report["errors"].append(f"cannot read pptx {path}: {exc}")
        else:
            item["kind"] = "other"
        report["inputs"].append(item)

    for font in [x.strip() for x in args.fonts.split(",") if x.strip()]:
        report["fonts"][font] = find_font(font)

    if args.json_out:
        out = Path(args.json_out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
