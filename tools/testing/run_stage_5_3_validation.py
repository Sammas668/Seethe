#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMMANDS = [
    [sys.executable, "tests/content/validate_stage_5_3_roster_storage_screen_update.py"],
    [sys.executable, "tools/testing/run_stage_5_2a_validation.py"],
]

for command in COMMANDS:
    print("+", " ".join(command), flush=True)
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode != 0:
        raise SystemExit(result.returncode)
print("Stage 5.3 validation bundle PASSED")
