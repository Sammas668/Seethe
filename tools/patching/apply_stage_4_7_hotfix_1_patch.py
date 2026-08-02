#!/usr/bin/env python3
"""Apply Stage 4.7 Hotfix 1 to an extracted Stage 4.7 project."""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

MANIFEST = "STAGE_4_7_HOTFIX_1_PATCH_FILE_MANIFEST.txt"


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: apply_stage_4_7_hotfix_1_patch.py <path-to-existing-seethe-project>")
        return 2
    source_root = Path(__file__).resolve().parents[2]
    target_root = Path(sys.argv[1]).resolve()
    if not (target_root / "project.godot").is_file():
        print(f"Target is not a Seethe project root: {target_root}")
        return 2
    manifest_path = source_root / MANIFEST
    if not manifest_path.is_file():
        print(f"Patch manifest is missing: {manifest_path}")
        return 2
    copied = 0
    deleted = 0
    for raw in manifest_path.read_text(encoding="utf-8").splitlines():
        relative = raw.strip()
        if not relative or relative.startswith("#"):
            continue
        if relative.startswith("DELETE "):
            victim = target_root / relative.removeprefix("DELETE ").strip()
            if victim.exists():
                victim.unlink()
                deleted += 1
            continue
        source = source_root / relative
        destination = target_root / relative
        if not source.is_file():
            print(f"Patch file is missing: {relative}")
            return 1
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        copied += 1
    print(
        f"Stage 4.7 Hotfix 1 applied successfully: "
        f"{copied} files copied, {deleted} obsolete files removed."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
