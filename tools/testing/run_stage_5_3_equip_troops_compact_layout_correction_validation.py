#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMMANDS = [
    [sys.executable, "tests/content/validate_stage_5_3_equip_troops_compact_layout_correction.py"],
    [sys.executable, "tools/testing/run_stage_5_3_equip_layout_tightening_validation.py"],
    [sys.executable, "tests/architecture/validate_stage_4_5g_architecture.py"],
    [sys.executable, "tests/static/validate_stage_5_0.py"],
]

for command in COMMANDS:
    print("+", " ".join(command), flush=True)
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode != 0:
        raise SystemExit(result.returncode)

print("Stage 5.3 Equip Troops Compact Layout Correction validation bundle PASSED")
