#!/usr/bin/env python3
"""Compatibility entry point for the Stage 4.7 content gate.

The original broad role-based validator accepted substitute sheets. Stage 4.7
Hotfix 1 intentionally delegates to the exact approved-sheet conformance gate.
"""
from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path


def _load_validator(project: Path):
    target = project / "tests/content/validate_stage_4_7_sheet_conformance.py"
    spec = importlib.util.spec_from_file_location("stage47_sheet_conformance", target)
    if spec is None or spec.loader is None:
        raise RuntimeError("Could not load Stage 4.7 sheet-conformance validator.")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=".")
    args = parser.parse_args()
    project = Path(args.project).resolve()
    module = _load_validator(project)
    errors = module.validate(project)
    if errors:
        print("Stage 4.7 character-content validation FAILED:")
        for error in errors:
            print(f" - {error}")
        return 1
    print("Stage 4.7 character-content validation PASSED via exact sheet conformance.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
