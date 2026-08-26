#!/usr/bin/env python3
"""
Install the image2ppt skill folder to a target Skills directory.

Examples:
    python scripts/install_skill.py --target ~/.codex/skills
    python scripts/install_skill.py --target /home/oai/skills

The script installs:
    <target>/image2ppt/
"""

from __future__ import annotations
import argparse
from pathlib import Path
import shutil


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", required=True, help="Parent skills directory")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    package_root = Path(__file__).resolve().parents[1]
    target_parent = Path(args.target).expanduser().resolve()
    target = target_parent / "image2ppt"

    if target.exists():
        if not args.force:
            raise SystemExit(
                f"{target} already exists. Use --force to replace it."
            )
        shutil.rmtree(target)

    target_parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(package_root, target, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    print(f"Installed image2ppt to: {target}")


if __name__ == "__main__":
    main()
