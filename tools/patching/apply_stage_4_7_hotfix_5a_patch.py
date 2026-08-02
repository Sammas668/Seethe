#!/usr/bin/env python3
"""Apply Stage 4.7 Hotfix 5a to an extracted Stage 4.7 Hotfix 5 project."""
from pathlib import Path
import shutil
import sys

MANIFEST = "STAGE_4_7_HOTFIX_5A_PATCH_FILE_MANIFEST.txt"


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: apply_stage_4_7_hotfix_5a_patch.py <path-to-existing-seethe-project>")
        return 2
    source = Path(__file__).resolve().parents[2]
    target = Path(sys.argv[1]).resolve()
    manifest = source / MANIFEST
    if not target.joinpath("project.godot").is_file():
        print(f"Target is not a Seethe project: {target}")
        return 1
    if not manifest.is_file():
        print(f"Patch manifest is missing: {manifest}")
        return 1
    for raw in manifest.read_text(encoding="utf-8").splitlines():
        rel = raw.strip()
        if not rel or rel.startswith("#"):
            continue
        if rel.startswith("DELETE "):
            target.joinpath(rel.removeprefix("DELETE ")).unlink(missing_ok=True)
            continue
        src = source / rel
        dst = target / rel
        if not src.is_file():
            print(f"Patch file is missing: {src}")
            return 1
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    print("Stage 4.7 Hotfix 5a applied successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
