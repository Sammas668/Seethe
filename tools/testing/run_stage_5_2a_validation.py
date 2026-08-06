#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMMANDS = [
    [sys.executable, "tests/content/validate_stage_5_2a_hotfix1_stronghold_type_resolution.py"],
    [sys.executable, "tests/content/validate_stage_5_2a_stronghold_grid.py"],
    [sys.executable, "tests/content/validate_stage_5_2a_update_1_unified_facilities.py"],
    [sys.executable, "tests/content/validate_stage_5_2_interactive_construction.py"],
    [sys.executable, "tests/content/validate_stage_5_2_ui_timed_construction_update.py"],
    [sys.executable, "tests/content/validate_stage_5_2_construction_tile_overlay_update.py"],
    [sys.executable, "tools/testing/run_stage_5_1d_validation.py"],
]

for command in COMMANDS:
    print("+", " ".join(command), flush=True)
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode != 0:
        raise SystemExit(result.returncode)
print("Stage 5.2a validation bundle PASSED")
