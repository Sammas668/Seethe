#!/usr/bin/env python3
"""Apply Stage 4.7 Hotfix 5f8 to the supplied Hotfix 5f7 project."""
from __future__ import annotations

from pathlib import Path
import shutil
import sys
from typing import NoReturn


def _fail(message: str) -> NoReturn:
    raise SystemExit(message)


def main() -> int:
    patch_root = Path(__file__).resolve().parents[2]
    target = (
        Path(sys.argv[1]).expanduser().resolve()
        if len(sys.argv) > 1
        else Path.cwd().resolve()
    )
    manifest = patch_root / "STAGE_4_7_HOTFIX_5F8_PATCH_FILE_MANIFEST.txt"

    if not manifest.is_file():
        _fail("Patch manifest is missing.")
    if not (target / "project.godot").is_file():
        _fail(f"Target is not a Seethe Godot project: {target}")

    baseline_markers = [
        target / "docs/architecture/STAGE_4_7_HOTFIX_5F7_FIRST_ENEMY_ACTIVATION_GATE_REMOVAL.md",
        target / "STAGE_4_7_HOTFIX_5F7_RELEASE_NOTES.txt",
    ]
    if not any(marker.is_file() for marker in baseline_markers):
        _fail(
            "Stage 4.7 Hotfix 5f7 baseline was not detected. "
            "Apply this patch only to the supplied Hotfix 5f7 project."
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

    print(f"Applied Stage 4.7 Hotfix 5f8 ({len(files)} files) to {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
