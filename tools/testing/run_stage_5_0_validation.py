#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

STATIC_SUITES = [
    "tests/static/validate_stage_5_0.py",
    "tests/architecture/validate_stage_4_5g_architecture.py",
    "tests/content/validate_default_loadout_legality.py",
    "tests/content/validate_stage_4_6_missions.py",
    "tests/content/validate_stage_4_7_character_content.py",
    "tests/content/validate_stage_4_7_sheet_conformance.py",
    "tests/content/validate_enemy_turn_pipeline.py",
]


def run(command: list[str]) -> int:
    print("+", " ".join(command), flush=True)
    return subprocess.run(command, cwd=ROOT, check=False).returncode


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", help="Path to a Godot 4.7.1 executable")
    parser.add_argument("--skip-runtime", action="store_true")
    args = parser.parse_args()

    failed = False
    for suite in STATIC_SUITES:
        failed = run([sys.executable, suite]) != 0 or failed
    if args.skip_runtime or not args.godot:
        if not args.skip_runtime and not args.godot:
            print("Runtime suite skipped: no --godot executable supplied.")
        return 1 if failed else 0
    runtime = [
        args.godot,
        "--headless",
        "--path",
        str(ROOT),
        "--script",
        "res://tests/integration/run_stage_5_0_tests.gd",
    ]
    failed = run(runtime) != 0 or failed
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
