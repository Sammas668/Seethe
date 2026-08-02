#!/usr/bin/env python3
"""Apply the Stage 4.7 Hotfix 5f patch to a Hotfix 5e3 project."""
from __future__ import annotations

from pathlib import Path
import shutil
import sys
from typing import NoReturn


def _fail(message: str) -> NoReturn:
    raise SystemExit(message)


def main() -> int:
    patch_root = Path(__file__).resolve().parents[2]
    target = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else Path.cwd().resolve()
    manifest = patch_root / "STAGE_4_7_HOTFIX_5F_PATCH_FILE_MANIFEST.txt"

    if not manifest.is_file():
        _fail("Patch manifest is missing.")
    if not (target / "project.godot").is_file():
        _fail(f"Target is not a Seethe Godot project: {target}")

    release_marker = target / "STAGE_4_7_HOTFIX_5E3_RELEASE_NOTES.txt"
    readme = target / "README_FIRST.txt"
    readme_text = readme.read_text(encoding="utf-8") if readme.is_file() else ""
    if not release_marker.is_file() and "HOTFIX 5e3" not in readme_text:
        _fail(
            "Stage 4.7 Hotfix 5e3 baseline was not detected. "
            "Apply this patch only to the complete Hotfix 5e3 project."
        )

    files: list[str] = []
    for raw_line in manifest.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("SEETHE ") or line.startswith("Files in patch:"):
            continue
        files.append(line)

    if not files:
        _fail("Patch manifest contains no files.")

    for relative_path in files:
        source = patch_root / relative_path
        if not source.is_file():
            _fail(f"Patch file is missing: {relative_path}")
        destination = target / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)

    print(f"Applied Stage 4.7 Hotfix 5f ({len(files)} files) to {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
