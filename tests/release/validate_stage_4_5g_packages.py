#!/usr/bin/env python3
"""Validate Seethe Stage 4.5g full-project and patch-only ZIP archives."""
from __future__ import annotations

import argparse
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

PROJECT_ROOT = "seethe"
REQUIRED_FULL = {
    f"{PROJECT_ROOT}/project.godot",
    f"{PROJECT_ROOT}/README_FIRST.txt",
    f"{PROJECT_ROOT}/STAGE_4_5G_RELEASE_NOTES.txt",
    f"{PROJECT_ROOT}/STAGE_4_5G_VALIDATION_RESULTS.txt",
    f"{PROJECT_ROOT}/STAGE_4_5G_RUNTIME_VALIDATION_RESULTS.txt",
    f"{PROJECT_ROOT}/STAGE_4_5G_PATCH_README.txt",
    f"{PROJECT_ROOT}/STAGE_4_5G_PATCH_FILE_MANIFEST.txt",
    f"{PROJECT_ROOT}/docs/architecture/STAGE_4_5G_TACTICAL_FOUNDATION_LOCK.md",
    f"{PROJECT_ROOT}/domain/tactical/invalidation/tactical_invalidation_contract.gd",
    f"{PROJECT_ROOT}/application/tactical/transactions/tactical_transaction_snapshot.gd",
    f"{PROJECT_ROOT}/domain/missions/mission_authority_snapshot.gd",
    f"{PROJECT_ROOT}/domain/missions/mission_commit_envelope.gd",
    f"{PROJECT_ROOT}/domain/tactical/items/tactical_generated_item_provenance.gd",
    f"{PROJECT_ROOT}/tests/integration/run_stage_4_5g_tests.gd",
    f"{PROJECT_ROOT}/tests/performance/run_stage_4_5g_benchmark.gd",
    f"{PROJECT_ROOT}/tools/testing/run_stage_4_5g_validation.py",
}
REQUIRED_PATCH = {
    f"{PROJECT_ROOT}/STAGE_4_5G_PATCH_README.txt",
    f"{PROJECT_ROOT}/STAGE_4_5G_PATCH_FILE_MANIFEST.txt",
    f"{PROJECT_ROOT}/STAGE_4_5G_RELEASE_NOTES.txt",
    f"{PROJECT_ROOT}/STAGE_4_5G_VALIDATION_RESULTS.txt",
}
FORBIDDEN_PARTS = {".git", ".godot", "__pycache__", ".idea", ".vscode"}
FORBIDDEN_SUFFIXES = {".pyc", ".pyo", ".log", ".tmp", ".bak", ".zip", ".rar"}


def archive_names(path: Path, failures: list[str]) -> set[str]:
    try:
        with zipfile.ZipFile(path) as archive:
            corrupt = archive.testzip()
            if corrupt:
                failures.append(f"{path.name}: corrupt member {corrupt}")
            names = {name.rstrip("/") for name in archive.namelist() if name.rstrip("/")}
            with tempfile.TemporaryDirectory(prefix="seethe_45g_package_") as temp_dir:
                archive.extractall(temp_dir)
                root = Path(temp_dir) / PROJECT_ROOT
                if not root.is_dir():
                    failures.append(f"{path.name}: archive does not extract to {PROJECT_ROOT}/")
    except (OSError, zipfile.BadZipFile) as exc:
        failures.append(f"{path.name}: cannot read ZIP: {exc}")
        return set()
    return names


def validate_names(label: str, names: set[str], failures: list[str]) -> None:
    for name in names:
        pure = PurePosixPath(name)
        if not pure.parts or pure.parts[0] != PROJECT_ROOT:
            failures.append(f"{label}: entry outside {PROJECT_ROOT}/: {name}")
        if any(part in FORBIDDEN_PARTS for part in pure.parts):
            failures.append(f"{label}: forbidden directory in package: {name}")
        if pure.suffix.lower() in FORBIDDEN_SUFFIXES:
            failures.append(f"{label}: forbidden generated/archive file: {name}")
        if len(pure.parts) >= 2 and pure.parts[1] == PROJECT_ROOT:
            failures.append(f"{label}: duplicate nested project root: {name}")


def manifest_paths(patch: Path, failures: list[str]) -> set[str]:
    try:
        with zipfile.ZipFile(patch) as archive:
            raw = archive.read(
                f"{PROJECT_ROOT}/STAGE_4_5G_PATCH_FILE_MANIFEST.txt"
            ).decode("utf-8")
    except (KeyError, OSError, UnicodeDecodeError, zipfile.BadZipFile) as exc:
        failures.append(f"Patch manifest could not be read: {exc}")
        return set()
    result: set[str] = set()
    for line in raw.splitlines():
        if line.startswith("NEW | ") or line.startswith("MODIFIED | "):
            result.add(f"{PROJECT_ROOT}/{line.split(' | ', 1)[1].strip()}")
    if not result:
        failures.append("Patch manifest contains no NEW/MODIFIED file entries")
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--full", required=True, type=Path)
    parser.add_argument("--patch", required=True, type=Path)
    args = parser.parse_args()

    failures: list[str] = []
    for path in (args.full, args.patch):
        if not path.is_file():
            failures.append(f"Missing package: {path}")
    if failures:
        for failure in failures:
            print(" -", failure)
        return 1

    full_names = archive_names(args.full, failures)
    patch_names = archive_names(args.patch, failures)
    validate_names("full", full_names, failures)
    validate_names("patch", patch_names, failures)

    for missing in sorted(REQUIRED_FULL - full_names):
        failures.append(f"Full package missing required file: {missing}")
    for missing in sorted(REQUIRED_PATCH - patch_names):
        failures.append(f"Patch package missing required file: {missing}")

    manifest = manifest_paths(args.patch, failures)
    patch_files = {
        name for name in patch_names
        if not name.endswith("/")
    }
    for missing in sorted(manifest - patch_files):
        failures.append(f"Patch manifest lists missing archive member: {missing}")
    unlisted = patch_files - manifest
    if unlisted:
        failures.append(
            "Patch contains files absent from its manifest: " + ", ".join(sorted(unlisted))
        )

    if failures:
        print("Stage 4.5g package validation FAILED")
        for failure in failures:
            print(" -", failure)
        return 1
    print(
        "Stage 4.5g package validation PASSED "
        f"({len(full_names)} full entries; {len(patch_names)} patch entries)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
