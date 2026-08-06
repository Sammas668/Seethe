#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REQUIRED = [
    "README_FIRST.txt",
    "PROJECT_TREE.txt",
    "docs/architecture/STAGE_4_5G_TACTICAL_FOUNDATION_LOCK.md",
    "STAGE_4_5G_RELEASE_NOTES.txt",
    "STAGE_4_5G_VALIDATION_RESULTS.txt",
    "STAGE_4_5G_RUNTIME_VALIDATION_RESULTS.txt",
    "STAGE_4_5G_PATCH_README.txt",
    "STAGE_4_5G_PATCH_FILE_MANIFEST.txt",
    "tests/runtime/stage_4_5g_runtime_suite.json",
    "tests/release/validate_stage_4_5g_packages.py",
]


def main() -> int:
    failures = []
    for rel in REQUIRED:
        path = ROOT / rel
        if not path.exists() or not path.read_text(encoding="utf-8", errors="ignore").strip():
            failures.append(f"Missing or empty: {rel}")
    readme = (ROOT / "README_FIRST.txt").read_text(encoding="utf-8", errors="ignore")
    if "Stage 4.5g" not in readme or "Godot 4.7.1" not in readme:
        failures.append("README does not identify Stage 4.5g and Godot 4.7.1")
    validation = (ROOT / "STAGE_4_5G_VALIDATION_RESULTS.txt").read_text(encoding="utf-8", errors="ignore")
    if "NOT RUN" not in validation and "Runtime gameplay suites: PASS" not in validation:
        failures.append("Validation report does not honestly record runtime status")
    if failures:
        print("Stage 4.5g documentation validation FAILED")
        for item in failures:
            print(" -", item)
        return 1
    print("Stage 4.5g documentation validation PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
