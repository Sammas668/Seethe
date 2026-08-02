#!/usr/bin/env python3
"""Compatibility entry point for the current Marauder fidelity gate.

Hotfix 5 deliberately changes the Hotfix 4 equipment contract by replacing the
separate ration, empty sack and carrying-belt entries with one fixed Raider's
Sack. Historical validation therefore delegates to the current authoritative
Hotfix 5 validator rather than rejecting the approved migration.
"""
from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=".")
    args = parser.parse_args()
    project = Path(args.project).resolve()
    target = project / "tests/content/validate_stage_4_7_hotfix_5_marauder_mechanics.py"
    spec = importlib.util.spec_from_file_location("stage47_hf5", target)
    if spec is None or spec.loader is None:
        print("Could not load Stage 4.7 Hotfix 5 validator.")
        return 1
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    errors = module.validate(project)
    if errors:
        print("Stage 4.7 current Marauder validation FAILED:")
        for error in errors:
            print(f" - {error}")
        return 1
    print("Stage 4.7 current Marauder validation PASSED (Hotfix 5 contract).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
