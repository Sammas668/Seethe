#!/usr/bin/env python3
"""Apply the Stage 4.6 patch to an extracted Stage 4.5g Hotfix 1 project."""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

PATCH_PROJECT_ROOT = Path(__file__).resolve().parents[2]
MANIFEST = PATCH_PROJECT_ROOT / "STAGE_4_6_PATCH_FILE_MANIFEST.txt"


def read_manifest() -> tuple[list[str], list[str]]:
    additions: list[str] = []
    deletions: list[str] = []
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        if line.startswith("NEW | ") or line.startswith("MODIFIED | "):
            additions.append(line.split(" | ", 1)[1].strip())
        elif line.startswith("DELETED | "):
            deletions.append(line.split(" | ", 1)[1].strip())
    return additions, deletions


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("target", type=Path, help="Extracted Stage 4.5g Hotfix 1 seethe project root")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    target = args.target.resolve()
    if target == PATCH_PROJECT_ROOT.resolve():
        print("Refusing to apply the patch onto its own patch directory.", file=sys.stderr)
        return 2
    if not (target / "project.godot").is_file():
        print(f"Target is not a Seethe project root: {target}", file=sys.stderr)
        return 2
    if not MANIFEST.is_file():
        print(f"Patch manifest is missing: {MANIFEST}", file=sys.stderr)
        return 2

    additions, deletions = read_manifest()
    missing = [rel for rel in additions if not (PATCH_PROJECT_ROOT / rel).is_file()]
    if missing:
        print("Patch archive is incomplete:", file=sys.stderr)
        for rel in missing:
            print(f" - {rel}", file=sys.stderr)
        return 3

    for rel in additions:
        source = PATCH_PROJECT_ROOT / rel
        destination = target / rel
        print(f"COPY {rel}")
        if not args.dry_run:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)

    for rel in deletions:
        destination = target / rel
        print(f"DELETE {rel}")
        if args.dry_run:
            continue
        if destination.is_file() or destination.is_symlink():
            destination.unlink()
        elif destination.is_dir():
            shutil.rmtree(destination)

    print(f"Stage 4.6 patch applied: {len(additions)} files copied, {len(deletions)} obsolete paths removed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
