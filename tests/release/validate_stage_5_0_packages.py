#!/usr/bin/env python3
"""Validate Stage 5.0 full and overlay ZIPs against the working tree."""
from __future__ import annotations

import argparse
import hashlib
import shutil
import tempfile
import zipfile
from pathlib import Path

EXCLUDED_PARTS = {".git", ".godot", "__pycache__"}
EXCLUDED_SUFFIXES = {".pyc", ".pyo"}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def file_map(root: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if any(part in EXCLUDED_PARTS for part in relative.parts):
            continue
        if path.suffix in EXCLUDED_SUFFIXES:
            continue
        result[relative.as_posix()] = digest(path)
    return result


def archive_safety(archive: Path) -> list[str]:
    errors: list[str] = []
    with zipfile.ZipFile(archive) as handle:
        names = handle.namelist()
    for name in names:
        path = Path(name)
        if path.is_absolute() or ".." in path.parts:
            errors.append(f"Unsafe archive entry: {name}")
        if any(part in EXCLUDED_PARTS for part in path.parts):
            errors.append(f"Excluded cache/source-control entry: {name}")
        if path.suffix in EXCLUDED_SUFFIXES:
            errors.append(f"Excluded Python cache entry: {name}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--full", required=True, type=Path)
    parser.add_argument("--patch", required=True, type=Path)
    args = parser.parse_args()

    errors: list[str] = []
    for archive in (args.full, args.patch):
        if not archive.is_file():
            errors.append(f"Missing archive: {archive}")
        else:
            errors.extend(archive_safety(archive))
    if errors:
        for error in errors:
            print(f" - {error}")
        return 1

    expected = file_map(args.work)
    with tempfile.TemporaryDirectory(prefix="seethe_stage50_packages_") as temp:
        temp_root = Path(temp)

        full_root = temp_root / "full"
        full_root.mkdir()
        with zipfile.ZipFile(args.full) as handle:
            handle.extractall(full_root)
        candidates = [path for path in full_root.iterdir() if path.is_dir()]
        extracted_project = candidates[0] if len(candidates) == 1 else full_root
        actual_full = file_map(extracted_project)
        if actual_full != expected:
            missing = sorted(set(expected) - set(actual_full))
            extra = sorted(set(actual_full) - set(expected))
            changed = sorted(
                key for key in set(expected) & set(actual_full)
                if expected[key] != actual_full[key]
            )
            errors.append(
                "Full archive mismatch: "
                f"missing={len(missing)} extra={len(extra)} changed={len(changed)}"
            )

        patched_root = temp_root / "patched"
        shutil.copytree(
            args.base,
            patched_root,
            ignore=shutil.ignore_patterns(".git", ".godot", "__pycache__", "*.pyc", "*.pyo"),
        )
        with zipfile.ZipFile(args.patch) as handle:
            handle.extractall(patched_root)
        actual_patch = file_map(patched_root)
        if actual_patch != expected:
            missing = sorted(set(expected) - set(actual_patch))
            extra = sorted(set(actual_patch) - set(expected))
            changed = sorted(
                key for key in set(expected) & set(actual_patch)
                if expected[key] != actual_patch[key]
            )
            errors.append(
                "Patch reproduction mismatch: "
                f"missing={len(missing)} extra={len(extra)} changed={len(changed)}"
            )

    if errors:
        print("Stage 5.0 package validation FAILED:")
        for error in errors:
            print(f" - {error}")
        return 1
    print(f"Stage 5.0 package validation PASSED ({len(expected)} project files reproduced).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
