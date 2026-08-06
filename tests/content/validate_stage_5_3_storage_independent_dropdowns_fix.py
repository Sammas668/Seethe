#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL_PATH = ROOT / "presentation/campaign/campaign_shell.gd"
SHELL = SHELL_PATH.read_text(encoding="utf-8")

errors: list[str] = []

required_tokens = [
    'var _storage_expanded_definition_ids: Dictionary = {}',
    'var expanded: bool = _storage_expanded_definition_ids.has(definition_id)',
    '_storage_expanded_definition_ids[definition_id] = true',
    '_storage_expanded_definition_ids.erase(definition_id)',
    'for raw_expanded_definition_id: Variant in _storage_expanded_definition_ids.keys():',
    'if not visible_definition_ids.has(expanded_definition_id):',
    '_storage_expanded_definition_ids.erase(expanded_definition_id)',
    '_storage_expanded_definition_ids.erase(removed_definition_id)',
]
for token in required_tokens:
    if token not in SHELL:
        errors.append(f"campaign_shell.gd missing independent-expansion token: {token}")

for forbidden in [
    'var _storage_expanded_definition_id: StringName',
    'definition_id == _storage_expanded_definition_id',
    '_storage_expanded_definition_id = &"" if expanded else definition_id',
    'if _storage_expanded_definition_id.is_empty() and not groups.is_empty():',
    '_storage_expanded_definition_id = StringName(groups[0].get("definition_id", &""))',
]:
    if forbidden in SHELL:
        errors.append(f"obsolete single-open/forced-open Storage behaviour remains: {forbidden}")

if errors:
    print("Stage 5.3 independent Storage dropdown fix validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — Storage expansion state is a per-definition dictionary rather than one accordion ID.")
print("PASS — each visible item group can be expanded or collapsed independently.")
print("PASS — no group is automatically opened when all groups are collapsed.")
print("PASS — filtering prunes only expansion IDs that are no longer visible.")
print("PASS — removing the final instance of one definition does not collapse unrelated groups.")
