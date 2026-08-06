#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATIC_SUITES = [
    "tests/content/validate_stage_5_2a_stronghold_grid.py",
    "tests/content/validate_stage_5_4a_storage_shop.py",
    "tests/content/validate_stage_5_4b_manufacturing_personnel_repair.py",
    "tests/content/validate_stage_5_4c_research_organisational_unlocks.py",
    "tests/content/validate_stage_5_4bc_queue_screen_reflow.py",
    "tests/content/validate_enemy_turn_pipeline.py",
    "tests/content/validate_stage_5_4_stabilisation.py",
]


def run(command: list[str]) -> bool:
    print("+", " ".join(command), flush=True)
    return subprocess.run(command, cwd=ROOT, check=False).returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", help="Path to Godot 4.7.1 executable")
    parser.add_argument("--skip-runtime", action="store_true")
    args = parser.parse_args()

    ok = True
    for suite in STATIC_SUITES:
        ok = run([sys.executable, suite]) and ok

    if args.skip_runtime:
        print("Godot runtime suite: NOT RUN (--skip-runtime).")
    elif not args.godot:
        print("Godot runtime suite: NOT RUN (no --godot executable supplied).")
    else:
        ok = run([
            args.godot,
            "--headless",
            "--path",
            str(ROOT),
            "--script",
            "res://tests/integration/run_stage_5_4_stabilisation_tests.gd",
        ]) and ok
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
