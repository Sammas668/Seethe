#!/usr/bin/env python3
"""Static packaging checks for Seethe Stage 3.9.2."""

from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def resource_references() -> None:
    pattern = re.compile(r"res://[^\"')\s]+")
    for path in ROOT.rglob("*"):
        if path.suffix not in {".gd", ".tscn", ".tres", ".godot"}:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for reference in pattern.findall(text):
            target = ROOT / reference.removeprefix("res://")
            if not target.exists():
                fail(f"Missing resource {reference} referenced by {path}")


def class_names() -> None:
    names: dict[str, Path] = {}
    for path in ROOT.rglob("*.gd"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        match = re.search(r"^class_name\s+(\w+)", text, re.M)
        if not match:
            continue
        name = match.group(1)
        if name in names:
            fail(f"Duplicate class_name {name}: {names[name]} and {path}")
        names[name] = path


def scene_nodes(scene_path: Path) -> set[str]:
    result: set[str] = set()
    for line in scene_path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("[node "):
            continue
        name_match = re.search(r'name="([^"]+)"', line)
        parent_match = re.search(r'parent="([^"]+)"', line)
        if not name_match:
            continue
        name = name_match.group(1)
        parent = parent_match.group(1) if parent_match else ""
        result.add(name if not parent or parent == "." else f"{parent}/{name}")
    return result


def node_paths(script: str, scene: str) -> int:
    script_text = (ROOT / script).read_text(encoding="utf-8")
    paths = set(re.findall(r"\$([A-Za-z0-9_/]+)", script_text))
    missing = paths - scene_nodes(ROOT / scene)
    if missing:
        fail(f"{script} has missing scene paths: {sorted(missing)}")
    return len(paths)


def duplicate_functions() -> None:
    for path in ROOT.rglob("*.gd"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        functions = re.findall(r"^func\s+(\w+)\s*\(", text, re.M)
        duplicate = sorted(
            {name for name in functions if functions.count(name) > 1}
        )
        if duplicate:
            fail(f"Duplicate functions in {path}: {duplicate}")


def event_architecture() -> None:
    required = [
        "domain/tactical/events/tactical_event_type.gd",
        "domain/tactical/events/tactical_event_record.gd",
        "domain/tactical/events/tactical_roll_record.gd",
        "domain/tactical/events/tactical_modifier_record.gd",
        "domain/tactical/events/tactical_effect_record.gd",
        "application/tactical/events/tactical_event_journal.gd",
        "presentation/tactical/combat_log/tactical_combat_log.gd",
        "presentation/tactical/combat_log/tactical_combat_log.tscn",
        "presentation/tactical/combat_log/tactical_event_formatter.gd",
        "tests/tactical/stage_3_9_2_event_journal_tests.gd",
        "tests/tactical/run_stage_3_9_2_tests.gd",
    ]
    for relative in required:
        if not (ROOT / relative).exists():
            fail(f"Missing Stage 3.9.2 file: {relative}")

    session_text = (
        ROOT / "application/tactical/tactical_session.gd"
    ).read_text(encoding="utf-8")
    if "var event_journal: RefCounted" not in session_text:
        fail("TacticalSession does not own the event journal.")
    if "EVENT_JOURNAL_SCRIPT.new()" not in session_text:
        fail("TacticalSession does not construct the event journal.")

    screen_text = (
        ROOT / "presentation/tactical/tactical_screen.gd"
    ).read_text(encoding="utf-8")
    for required_fragment in [
        "TACTICAL_COMBAT_LOG_SCENE",
        'key_event.keycode == KEY_L',
        '_combat_log.call("configure", _facade.event_journal())',
        '_combat_log.call("collapse")',
    ]:
        if required_fragment not in screen_text:
            fail(f"TacticalScreen is missing: {required_fragment}")

    scene_text = (
        ROOT
        / "presentation/tactical/combat_log/tactical_combat_log.tscn"
    ).read_text(encoding="utf-8")
    for required_fragment in [
        'offset_left = -350.0',
        'offset_top = -260.0',
        'offset_right = -10.0',
        'offset_bottom = -158.0',
        'text = "ALL"',
        'text = "ROLLS"',
        'text = "COMBAT"',
        'text = "EVENTS"',
    ]:
        if required_fragment not in scene_text:
            fail(f"Combat-log placement/filter fragment missing: {required_fragment}")


def content_ids() -> None:
    item_ids: set[str] = set()
    granted: set[str] = set()
    for path in (ROOT / "content/items").glob("*.tres"):
        text = path.read_text(encoding="utf-8")
        if "res://domain/inventory/definitions/item_definition.gd" not in text:
            fail(f"{path} does not use the shared ItemDefinition path")
        match = re.search(r'^id = &"([^"]+)"', text, re.M)
        if not match or match.group(1) in item_ids:
            fail(f"Missing or duplicate item ID in {path}")
        item_ids.add(match.group(1))
        granted.update(re.findall(r'&"(action\.[^"]+)"', text))

    action_ids: set[str] = set()
    for path in (ROOT / "content/actions").glob("*.tres"):
        text = path.read_text(encoding="utf-8")
        match = re.search(r'^id = &"([^"]+)"', text, re.M)
        if not match or match.group(1) in action_ids:
            fail(f"Missing or duplicate action ID in {path}")
        action_ids.add(match.group(1))

    unknown = granted - action_ids
    if unknown:
        fail(f"Unknown granted action IDs: {sorted(unknown)}")


def removed_files() -> None:
    forbidden = [
        "domain/tactical/item_definition.gd",
        "domain/tactical/end_phase_command.gd",
        "domain/tactical/move_command.gd",
        "domain/tactical/spend_action_command.gd",
        "domain/tactical/sprint_move_command.gd",
        "domain/tactical/tactical_inventory_transfer_command.gd",
        "domain/tactical/tactical_inventory_transfer_plan.gd",
        "domain/tactical/tactical_inventory_transfer_preview.gd",
        "tests/tactical/run_stage_3_8_tests.gd",
        "tests/tactical/stage_3_8_invariant_tests.gd",
    ]
    for relative in forbidden:
        if (ROOT / relative).exists():
            fail(f"Obsolete file remains: {relative}")


def main() -> None:
    resource_references()
    class_names()
    duplicate_functions()
    tactical_paths = node_paths(
        "presentation/tactical/tactical_screen.gd",
        "presentation/tactical/tactical_screen.tscn",
    )
    unit_management_paths = node_paths(
        "presentation/tactical/unit_management_window.gd",
        "presentation/tactical/unit_management_window.tscn",
    )
    log_paths = node_paths(
        "presentation/tactical/combat_log/tactical_combat_log.gd",
        "presentation/tactical/combat_log/tactical_combat_log.tscn",
    )
    event_architecture()
    content_ids()
    removed_files()
    print(
        "Stage 3.9.2 static validation passed "
        f"({tactical_paths} TacticalScreen paths, "
        f"{unit_management_paths} UnitManagement paths, "
        f"{log_paths} TacticalLog paths)."
    )


if __name__ == "__main__":
    main()
