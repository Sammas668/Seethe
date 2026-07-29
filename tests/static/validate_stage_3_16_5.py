#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
errors: list[str] = []


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        errors.append(f"Missing required file: {relative}")
        return ""
    return path.read_text(encoding="utf-8")


service = read("application/characters/character_resolution_service.gd")

resolver = read("domain/characters/resolution/character_resolver.gd")
resolved_stat = read("domain/characters/resolution/resolved_stat.gd")
modifier_line = read("domain/characters/resolution/stat_modifier_line.gd")

for token in [
    "RESOLVED_CHARACTER_SNAPSHOT_SCRIPT",
    "RESOLVED_STAT_SCRIPT",
    "var result = RESOLVED_CHARACTER_SNAPSHOT_SCRIPT.new()",
    "stat.configure(stat_id, display_name)",
]:
    if token not in resolver:
        errors.append(f"CharacterResolver missing parser-safe token: {token}")

for token in [
    "func _init() -> void:",
    "func configure(",
    "STAT_MODIFIER_LINE_SCRIPT.new() as RefCounted",
    'line.call("configure"',
]:
    if token not in resolved_stat:
        errors.append(f"ResolvedStat missing parser-safe token: {token}")

for token in ["func _init() -> void:", "func configure("]:
    if token not in modifier_line:
        errors.append(f"StatModifierLine missing parser-safe token: {token}")
required = [
    'const CHARACTER_RESOLVER_SCRIPT: Script = preload(',
    '"res://domain/characters/resolution/character_resolver.gd"',
    'var _resolver: RefCounted',
    'resolver: RefCounted = null',
    'CHARACTER_RESOLVER_SCRIPT.new() as RefCounted',
    'var resolved_value: Variant = _resolver.call(',
    '"resolve"',
    'resolved_value as ResolvedCharacterSnapshot',
]
for token in required:
    if token not in service:
        errors.append(f"CharacterResolutionService missing parser-safe token: {token}")

for forbidden in [
    'var _resolver: CharacterResolver',
    'resolver: CharacterResolver',
    'CharacterResolver.new()',
]:
    if forbidden in service:
        errors.append(f"CharacterResolutionService still relies on global CharacterResolver type: {forbidden}")

for line_number, line in enumerate(service.splitlines(), start=1):
    if line.startswith(" "):
        errors.append(
            f"Leading-space indentation in character_resolution_service.gd:{line_number}"
        )

if errors:
    print("Stage 3.16.5 static validation FAILED:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print("Stage 3.16.5 static validation passed.")
print(" - CharacterResolutionService no longer requires CharacterResolver global type registration.")
print(" - The mandatory resolver is instantiated through an explicit preloaded script.")
print(" - Dynamic return values are explicitly cast before use.")
