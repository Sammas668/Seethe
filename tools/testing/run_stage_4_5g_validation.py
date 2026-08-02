#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(label: str, command: list[str]) -> bool:
    print(f"\n== {label} ==")
    return subprocess.run(command, cwd=ROOT).returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot")
    parser.add_argument("--skip-runtime", action="store_true")
    parser.add_argument("--full-package")
    parser.add_argument("--patch-package")
    args = parser.parse_args()
    results = []
    results.append(run("Architecture", [sys.executable, "tests/architecture/validate_stage_4_5g_architecture.py"]))
    if not args.skip_runtime:
        if not args.godot:
            print("Runtime validation requested but --godot was not supplied.")
            results.append(False)
        else:
            results.append(run("Runtime", [sys.executable, "tools/testing/run_stage_4_5g_runtime_suite.py", "--godot", args.godot, "--project", str(ROOT)]))
    results.append(run("Documentation", [sys.executable, "tests/documentation/validate_stage_4_5g_documentation.py"]))
    if args.full_package or args.patch_package:
        if not args.full_package or not args.patch_package:
            print("Package validation requires both --full-package and --patch-package.")
            results.append(False)
        else:
            results.append(run(
                "Packages",
                [
                    sys.executable,
                    "tests/release/validate_stage_4_5g_packages.py",
                    "--full",
                    args.full_package,
                    "--patch",
                    args.patch_package,
                ],
            ))
    return 0 if all(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
