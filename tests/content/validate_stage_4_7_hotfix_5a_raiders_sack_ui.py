#!/usr/bin/env python3
"""Validate the Stage 4.7 Hotfix 5a Raider's Sack inventory UI correction."""
from __future__ import annotations

import argparse
from pathlib import Path


def read(root: Path, relative: str, errors: list[str]) -> str:
    path = root / relative
    if not path.is_file():
        errors.append(f"Missing {relative}.")
        return ""
    return path.read_text(encoding="utf-8")


def require(text: str, fragments: list[str], label: str, errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in text:
            errors.append(f"{label} is missing required contract: {fragment}")


def forbid(text: str, fragments: list[str], label: str, errors: list[str]) -> None:
    for fragment in fragments:
        if fragment in text:
            errors.append(f"{label} still contains obsolete contract: {fragment}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path("."))
    args = parser.parse_args()
    root = args.project.resolve()
    errors: list[str] = []

    window = read(root, "presentation/tactical/unit_management_window.gd", errors)
    item_control = read(root, "presentation/tactical/spatial_inventory_item_control.gd", errors)
    sack = read(root, "content/items/raiders_sack.tres", errors)
    runtime = read(root, "tests/integration/stage_4_7_hotfix_5_marauder_mechanics_tests.gd", errors)

    require(window, [
        'var _raider_sack_popup: PanelContainer',
        '_raider_sack_popup = PanelContainer.new()',
        '_raider_sack_close_button.text = "X"',
        'close_style.bg_color = Color(0.63, 0.08, 0.08, 1.0)',
        'func _open_raider_sack_popup()',
        'if mouse_button == MOUSE_BUTTON_LEFT:',
        'TacticalInventoryState.RAIDER_SACK_WIDTH',
        '_raider_sack_popup.visible = true',
    ], "Raider's Sack popup", errors)
    forbid(window, [
        'var _raider_sack_panel: PanelContainer',
        '_raider_sack_open',
        'lower.add_child(_raider_sack_panel)',
    ], "Old inline Raider's Sack UI", errors)
    require(item_control, [
        'Permanent Belt item — left-click to open.',
        'if fixed_fixture:',
        '&"container":',
    ], "Raider's Sack Belt item presentation", errors)
    require(sack, [
        'id = &"item.raiders_sack"',
        'inventory_footprint = Vector2i(2, 2)',
        'fixed_inventory_fixture = true',
        'internal_container_size = Vector2i(4, 3)',
        'tactical_visual_category = &"container"',
    ], "Raider's Sack definition", errors)
    require(runtime, [
        'Deployed Marauder %s does not contain Raider\'s Sack.',
        'session.state_store.state.raider_sack_item_for_unit(marauder_id)',
        'MARAUDER_TWO_ID',
        'Vector2i(5, 0)',
    ], "Raider's Sack deployed-inventory runtime coverage", errors)

    if errors:
        print("Stage 4.7 Hotfix 5a Raider's Sack UI validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Stage 4.7 Hotfix 5a Raider's Sack UI validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
