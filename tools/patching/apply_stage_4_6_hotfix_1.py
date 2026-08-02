#!/usr/bin/env python3
"""Apply the Stage 4.6 Hotfix 1 overlay to a Seethe Stage 4.6 project."""
from __future__ import annotations
import shutil
import sys
from pathlib import Path

FILES = [
    "bootstrap/boot/boot.gd",
    "bootstrap/debug/authored_mission_factory.gd",
    "presentation/debug/debug_mission_selector.gd",
    "presentation/tactical/tactical_screen.gd",
    "tests/content/validate_stage_4_6_missions.py",
    "tests/integration/stage_4_6_authored_mission_tests.gd",
    "STAGE_4_6_HOTFIX_1_RELEASE_NOTES.txt",
    "STAGE_4_6_HOTFIX_1_VALIDATION_RESULTS.txt",
    "STAGE_4_6_HOTFIX_1_PATCH_README.txt",
    "STAGE_4_6_HOTFIX_1_PATCH_FILE_MANIFEST.txt",
    "tools/patching/apply_stage_4_6_hotfix_1.py",
]

def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: apply_stage_4_6_hotfix_1.py <path-to-existing-seethe-project>")
        return 2
    source_root = Path(__file__).resolve().parents[2]
    target_root = Path(sys.argv[1]).resolve()
    if not (target_root / "project.godot").is_file():
        print(f"Not a Seethe project root: {target_root}")
        return 1
    for relative in FILES:
        source = source_root / relative
        if not source.is_file():
            print(f"Missing patch file: {relative}")
            return 1
        destination = target_root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if source.resolve() != destination.resolve():
            shutil.copy2(source, destination)
    print("Stage 4.6 Hotfix 1 applied successfully.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
