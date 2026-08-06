#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
errors: list[str] = []

service_path = ROOT / "application/characters/character_resolution_service.gd"
service_text = service_path.read_text(encoding="utf-8")
if "func _init() -> void:" not in service_text:
    errors.append("CharacterResolutionService must retain a parameterless constructor.")
if "func configure(" not in service_text:
    errors.append("CharacterResolutionService must receive its catalogue through configure().")

# Match any non-empty argument list on the same line. The obsolete tests used
# CharacterResolutionService.new(catalogue), which Godot 4.7 rejects at parse time.
pattern = re.compile(r"CharacterResolutionService\.new\(\s*[^\s)]")
for path in (ROOT / "tests").rglob("*.gd"):
    text = path.read_text(encoding="utf-8")
    for match in pattern.finditer(text):
        line = text.count("\\n", 0, match.start()) + 1
        errors.append(
            f"Obsolete CharacterResolutionService constructor argument in "
            f"{path.relative_to(ROOT)}:{line}"
        )

required = ROOT / "tests/characters/stage_3_12_character_system_tests.gd"
required_text = required.read_text(encoding="utf-8")
for token in [
    "_resolution_service(catalogue).resolve_character(",
    "CharacterResolutionService.new()",
    "service.configure(catalogue)",
]:
    if token not in required_text:
        errors.append(f"Stage 3.12 character tests missing corrected token: {token}")

if errors:
    print("Stage 4.2.1 static validation FAILED:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print("Stage 4.2.1 static validation passed.")
print(" - Legacy character tests use parameterless service construction.")
print(" - Catalogue dependencies are supplied through configure().")
print(" - No GDScript test passes arguments to CharacterResolutionService.new().")
