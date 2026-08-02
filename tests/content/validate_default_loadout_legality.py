#!/usr/bin/env python3
"""Validate registered character default loadouts without launching Godot."""
from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

CATALOGUE = "infrastructure/content/sandbox_content_catalogue_factory.gd"
BELT_SIZE = (7, 2)
BACKPACK_SIZE = (10, 4)


@dataclass(frozen=True)
class ItemFacts:
    item_id: str
    footprint: tuple[int, int]
    handedness: str
    belt_allowed: bool
    backpack_allowed: bool
    stackable: bool
    maximum_stack_size: int
    equipment_slots: tuple[str, ...]
    fixed_inventory_fixture: bool
    internal_container_kind: str
    internal_container_size: tuple[int, int]
    internal_single_entity_only: bool


def _first(text: str, pattern: str, default: str | None = None) -> str | None:
    match = re.search(pattern, text, re.MULTILINE)
    return match.group(1) if match else default


def _registered_paths(catalogue_text: str, folder: str) -> list[str]:
    pattern = rf'preload\("res://({re.escape(folder)}/[^"\n]+)"\)'
    return re.findall(pattern, catalogue_text)


def _load_item(project: Path, relative: str, errors: list[str]) -> ItemFacts | None:
    path = project / relative
    if not path.is_file():
        errors.append(f"Registered item file is missing: {relative}")
        return None
    text = path.read_text(encoding="utf-8", errors="replace")
    item_id = _first(text, r'^id = &"([^"]+)"')
    if not item_id:
        errors.append(f"Registered item has no ID: {relative}")
        return None
    footprint_match = re.search(
        r"inventory_footprint = Vector2i\((\d+),\s*(\d+)\)", text
    )
    footprint = (
        (int(footprint_match.group(1)), int(footprint_match.group(2)))
        if footprint_match
        else (1, 1)
    )
    return ItemFacts(
        item_id=item_id,
        footprint=footprint,
        handedness=_first(text, r'handedness = &"([^"]+)"', "not_equippable") or "not_equippable",
        belt_allowed=_first(text, r"belt_allowed = (true|false)", "true") == "true",
        backpack_allowed=_first(text, r"backpack_allowed = (true|false)", "true") == "true",
        stackable=_first(text, r"stackable = (true|false)", "false") == "true",
        maximum_stack_size=int(_first(text, r"maximum_stack_size = (\d+)", "1") or "1"),
        equipment_slots=tuple(re.findall(r'&"(armour|worn_utility)"', _first(text, r'equipment_slot_ids = Array\[StringName\]\((\[[^\n]+\])\)', "") or "")),
        fixed_inventory_fixture=_first(text, r"fixed_inventory_fixture = (true|false)", "false") == "true",
        internal_container_kind=_first(text, r'internal_container_kind = &"([^"]+)"', "") or "",
        internal_container_size=(
            (int(m.group(1)), int(m.group(2)))
            if (m := re.search(r"internal_container_size = Vector2i\((\d+),\s*(\d+)\)", text))
            else (0, 0)
        ),
        internal_single_entity_only=_first(text, r"internal_single_entity_only = (true|false)", "false") == "true",
    )


def _entry_dicts(template_text: str) -> list[str]:
    loadout_line = next(
        (line for line in template_text.splitlines() if line.startswith("default_loadout_entries = ")),
        "",
    )
    return re.findall(r"\{([^{}]+)\}", loadout_line)


def validate(project: Path) -> list[str]:
    errors: list[str] = []
    catalogue_path = project / CATALOGUE
    if not catalogue_path.is_file():
        return [f"Missing content catalogue: {CATALOGUE}"]
    catalogue_text = catalogue_path.read_text(encoding="utf-8", errors="replace")

    item_paths = _registered_paths(catalogue_text, "content/items")
    template_paths = _registered_paths(catalogue_text, "content/characters")
    items: dict[str, ItemFacts] = {}
    for relative in item_paths:
        facts = _load_item(project, relative, errors)
        if facts is None:
            continue
        if facts.item_id in items:
            errors.append(f"Duplicate registered item ID: {facts.item_id}")
        items[facts.item_id] = facts

    for relative in template_paths:
        path = project / relative
        if not path.is_file():
            errors.append(f"Registered character template is missing: {relative}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        template_id = _first(text, r'^id = &"([^"]+)"', relative) or relative
        occupied: dict[tuple[str, int, int], str] = {}
        hands: dict[str, str] = {}

        for index, raw_entry in enumerate(_entry_dicts(text), start=1):
            item_id = _first(raw_entry, r'"definition_id"\s*:\s*&"([^"]+)"')
            container = _first(raw_entry, r'"container_kind"\s*:\s*&"([^"]+)"')
            position_match = re.search(
                r'"grid_position"\s*:\s*Vector2i\((\d+),\s*(\d+)\)', raw_entry
            )
            position = (
                (int(position_match.group(1)), int(position_match.group(2)))
                if position_match
                else (0, 0)
            )
            quantity = int(
                _first(raw_entry, r'"quantity"\s*:\s*(\d+)', "1") or "1"
            )
            if not item_id or not container:
                errors.append(f"{template_id} loadout entry {index} is incomplete.")
                continue
            definition = items.get(item_id)
            if definition is None:
                errors.append(f"{template_id} references unregistered item {item_id}.")
                continue
            if quantity > definition.maximum_stack_size:
                errors.append(
                    f"{template_id} gives {item_id} quantity {quantity}, exceeding "
                    f"maximum {definition.maximum_stack_size}."
                )
            if not definition.stackable and quantity != 1:
                errors.append(
                    f"{template_id} gives non-stackable item {item_id} quantity {quantity}."
                )

            if container in {"main_hand", "off_hand"}:
                if definition.handedness == "not_equippable":
                    errors.append(f"{template_id} equips non-hand item {item_id} in {container}.")
                if container in hands:
                    errors.append(
                        f"{template_id} assigns {hands[container]} and {item_id} to {container}."
                    )
                hands[container] = item_id
                if container == "off_hand" and definition.handedness == "two_handed":
                    errors.append(f"{template_id} equips two-handed item {item_id} in off_hand.")
                continue

            if container in {"armour", "worn_utility"}:
                if container not in definition.equipment_slots:
                    errors.append(f"{template_id} equips {item_id} in unsupported fixed slot {container}.")
                if quantity != 1:
                    errors.append(f"{template_id} equips fixed-slot item {item_id} with quantity {quantity}.")
                continue
            if container not in {"belt", "backpack"}:
                errors.append(f"{template_id} uses unknown loadout container {container}.")
                continue
            if container == "belt" and not definition.belt_allowed:
                errors.append(f"{template_id} puts non-Belt item {item_id} on the Belt.")
            if container == "backpack" and not definition.backpack_allowed:
                errors.append(f"{template_id} puts non-Backpack item {item_id} in the Backpack.")

            width, height = BELT_SIZE if container == "belt" else BACKPACK_SIZE
            x, y = position
            item_width, item_height = definition.footprint
            if x < 0 or y < 0 or x + item_width > width or y + item_height > height:
                errors.append(
                    f"{template_id} places {item_id} outside the {container} grid: "
                    f"position={position}, footprint={definition.footprint}."
                )
            for cell_y in range(y, y + item_height):
                for cell_x in range(x, x + item_width):
                    key = (container, cell_x, cell_y)
                    if key in occupied:
                        errors.append(
                            f"{template_id} loadout overlap in {container} at "
                            f"({cell_x}, {cell_y}): {occupied[key]} and {item_id}."
                        )
                    else:
                        occupied[key] = item_id

            if definition.fixed_inventory_fixture:
                if item_id != "item.raiders_sack":
                    errors.append(f"{template_id} uses unsupported fixed fixture {item_id}.")
                if container != "belt" or position != (5, 0) or definition.footprint != (2, 2):
                    errors.append(
                        f"{template_id} Raider's Sack must occupy Belt position (5, 0) as 2x2."
                    )
                if definition.internal_container_kind != "raider_sack":
                    errors.append("Raider's Sack does not expose the raider_sack container kind.")
                if definition.internal_container_size != (4, 3):
                    errors.append("Raider's Sack internal grid is not exactly 4x3.")
                if not definition.internal_single_entity_only:
                    errors.append("Raider's Sack does not enforce one contained entity.")

        primary_id = hands.get("main_hand")
        secondary_id = hands.get("off_hand")
        if primary_id and secondary_id:
            primary = items.get(primary_id)
            if primary is not None and primary.handedness == "two_handed":
                errors.append(
                    f"{template_id} equips two-handed item {primary_id} with off-hand item {secondary_id}."
                )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=".")
    args = parser.parse_args()
    errors = validate(Path(args.project).resolve())
    if errors:
        print("Default-loadout legality validation FAILED:")
        for error in errors:
            print(f" - {error}")
        return 1
    print("Default-loadout legality validation PASSED (all registered character templates checked).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
