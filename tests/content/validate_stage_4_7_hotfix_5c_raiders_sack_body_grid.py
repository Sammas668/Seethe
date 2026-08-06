#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
checks = {
    "content/items/raiders_sack.tres": [
        "inventory_footprint = Vector2i(2, 2)",
        "internal_container_size = Vector2i(4, 3)",
        "internal_single_entity_only = true",
    ],
    "domain/tactical/tactical_inventory_state.gd": [
        "const RAIDER_SACK_WIDTH: int = 4",
        "const RAIDER_SACK_HEIGHT: int = 3",
    ],
    "domain/tactical/tactical_item_instance_state.gd": [
        "body_definition.inventory_footprint = Vector2i(4, 3)",
    ],
    "presentation/tactical/unit_management_window.gd": [
        "TacticalInventoryState.RAIDER_SACK_WIDTH",
        "TacticalInventoryState.RAIDER_SACK_HEIGHT",
        "Medium bodies occupy the full 4×3 grid.",
    ],
}
errors = []
for rel, needles in checks.items():
    path = ROOT / rel
    if not path.exists():
        errors.append(f"Missing {rel}")
        continue
    text = path.read_text(encoding="utf-8")
    for needle in needles:
        if needle not in text:
            errors.append(f"{rel} missing: {needle}")
if errors:
    print("Stage 4.7 Hotfix 5c Raider's Sack body-grid validation FAILED:")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)
print("Stage 4.7 Hotfix 5c Raider's Sack 4x3 body-grid validation PASSED.")
