#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL_PATH = ROOT / "presentation/campaign/campaign_shell.gd"
QUERY_PATH = ROOT / "application/inventory/strategic_storage_query_service.gd"
ROSTER_DOC_PATH = ROOT / "docs/architecture/STAGE_5_3_ROSTER_STORAGE_SCREEN_UPDATE.md"
DISPLAY_DOC_PATH = ROOT / "docs/architecture/STAGE_5_3_XENONAUTS_ROSTER_STORAGE_DISPLAY_UPDATE.md"
ROADMAP_PATH = ROOT / "Master Roadmap.txt"

SHELL = SHELL_PATH.read_text(encoding="utf-8")
QUERY = QUERY_PATH.read_text(encoding="utf-8")
ROSTER_DOC = ROSTER_DOC_PATH.read_text(encoding="utf-8")
DISPLAY_DOC = DISPLAY_DOC_PATH.read_text(encoding="utf-8")
ROADMAP = ROADMAP_PATH.read_text(encoding="utf-8")

errors: list[str] = []

required_shell_tokens = [
    'func _is_furniture_definition(definition: ItemDefinition) -> bool:',
    'definition.has_tag(&"furniture")',
    'or definition.has_tag(&"installation")',
    'or (definition.has_tag(&"bulky") and definition.has_tag(&"loot"))',
    'if _is_furniture_definition(definition) or definition.has_tag(&"salvage"):',
    'if _storage_category_filter == &"installations":',
    '_storage_category_filter = &"furniture"',
    'if _is_furniture_definition(definition):\n\t\treturn "res://presentation/campaign/icons/item_categories/furniture.svg"',
    'if _is_furniture_definition(definition):\n\t\treturn &"furniture"',
]
for token in required_shell_tokens:
    if token not in SHELL:
        errors.append(f"campaign_shell.gd missing merged-Furniture token: {token}")

required_query_tokens = [
    'definition.has_tag(&"furniture") or definition.has_tag(&"installation") or (',
    'return &"furniture"',
]
for token in required_query_tokens:
    if token not in QUERY:
        errors.append(f"strategic_storage_query_service.gd missing merged-Furniture token: {token}")

for forbidden in [
    '[&"installations", "INSTALLATIONS"]',
    'return &"installations"',
    'return "Installations"',
]:
    if forbidden in SHELL or forbidden in QUERY:
        errors.append(f"obsolete player-facing Installations category remains: {forbidden}")

if 'Storage has no separate Installations category.' not in DISPLAY_DOC:
    errors.append("Xenonauts Storage architecture note does not remove the Installations category.")
if 'Installable objects remain Furniture rather than becoming a separate item category.' not in ROSTER_DOC:
    errors.append("Roster/Storage architecture note does not define installable objects as Furniture.")
if 'rare installations.' in ROADMAP:
    errors.append("Master Roadmap still lists rare installations as a separate recoverable category.")
if 'rare installable furniture or arcane devices.' not in ROADMAP:
    errors.append("Master Roadmap does not use the merged installable-Furniture terminology.")

if errors:
    print("Stage 5.3 installations-merged-into-Furniture update validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — Storage no longer exposes an Installations category or label.")
print("PASS — legacy installation-tagged objects resolve to Furniture in both query and presentation paths.")
print("PASS — installable facility objects use the Furniture icon and remain excluded from troop equipment pools.")
print("PASS — stale runtime/debug Installations filters redirect safely to Furniture.")
print("PASS — architecture notes and the roadmap use the merged Furniture classification.")
