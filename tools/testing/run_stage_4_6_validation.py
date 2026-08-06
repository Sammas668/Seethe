#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(command: list[str], label: str) -> bool:
    print(f"\n== {label} ==")
    completed = subprocess.run(command, cwd=ROOT, check=False)
    return completed.returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--skip-runtime", action="store_true")
    args = parser.parse_args()

    checks = [
        ([sys.executable, "tests/architecture/validate_stage_4_5g_architecture.py"], "Architecture"),
        ([sys.executable, "tests/content/validate_stage_4_6_missions.py"], "Authored mission content"),
    ]
    ok = all(run(command, label) for command, label in checks)
    if args.skip_runtime:
        print("\nRuntime validation intentionally skipped.")
        return 0 if ok else 1
    if args.godot is None or not args.godot.is_file():
        print("\nA runnable --godot path is required unless --skip-runtime is used.")
        return 2
    runtime = [str(args.godot), "--headless", "--path", str(ROOT), "--script", "res://tests/integration/run_stage_4_6_tests.gd"]
    ok = run(runtime, "Stage 4.6 Godot runtime") and ok
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
