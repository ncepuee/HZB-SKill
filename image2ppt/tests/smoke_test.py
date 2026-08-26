#!/usr/bin/env python3
"""Dependency-light smoke test for scene lint, build and structural validation."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(*args: str) -> None:
    subprocess.run([sys.executable, *args], check=True)


def main() -> int:
    scene = ROOT / "templates" / "spec_template.json"
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        pptx = td_path / "smoke.pptx"
        lint = td_path / "scene-lint.json"
        audit = td_path / "editability.json"
        run(str(ROOT / "scripts" / "scene_lint.py"), str(scene), "--json-out", str(lint))
        run(str(ROOT / "scripts" / "build_from_spec.py"), str(scene), str(pptx))
        run(str(ROOT / "scripts" / "validate_ppt.py"), str(pptx), "--scene", str(scene), "--json-out", str(audit))
        report = json.loads(audit.read_text(encoding="utf-8"))
        assert report["passed"]
        assert report["slides"][0]["native_text_shapes"] >= 2
        assert report["slides"][0]["table_count"] == 1
        assert report["slides"][0]["picture_count"] == 0
    print("image2ppt smoke test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

