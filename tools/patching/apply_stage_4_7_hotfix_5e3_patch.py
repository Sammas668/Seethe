#!/usr/bin/env python3
"""Apply the Stage 4.7 Hotfix 5e3 cadence patch to a Hotfix 5e2 project."""
from __future__ import annotations

from pathlib import Path
import shutil
import sys

patch_root = Path(__file__).resolve().parents[2]
target = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd().resolve()
manifest = patch_root / "STAGE_4_7_HOTFIX_5E3_PATCH_FILE_MANIFEST.txt"
if not manifest.exists():
    raise SystemExit("Patch manifest is missing.")

files: list[str] = []
for raw_line in manifest.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("SEETHE ") or line.startswith("Files in patch:"):
        continue
    files.append(line)

for rel in files:
    source = patch_root / rel
    if not source.is_file():
        raise SystemExit(f"Patch file is missing: {rel}")
    destination = target / rel
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)

print(f"Applied Stage 4.7 Hotfix 5e3 ({len(files)} files) to {target}")
