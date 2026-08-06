#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys
from validation_common import *

def main() -> int:
    failures: list[str] = []
    validate_tab_indentation(failures)
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_balanced_delimiters(failures)
    for validator in sorted((ROOT / "tests/static").glob("validate_stage_*.py")):
        if validator.name in {Path(__file__).name, "validate_stage_3_16.py"}:
            continue
        result = subprocess.run([sys.executable, str(validator)], cwd=ROOT, capture_output=True, text=True)
        if result.returncode != 0:
            failures.append(f"{validator.name} failed:\n{result.stdout}{result.stderr}")
    return finish("Stage 3.15.1", failures, ["All legacy validators remain green after parser-safe indentation normalization."])

if __name__ == "__main__":
    sys.exit(main())
