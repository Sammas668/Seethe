#!/usr/bin/env python3
"""Static Stage 4.6 authored-mission and packaging-facing validation."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "content/missions/farm_storehouse/life_farm_storehouse_raid_01.tres"
MAP = ROOT / "content/missions/farm_storehouse/life_farm_storehouse_map_01.tres"

REQUIRED_FILES = [
    MISSION,
    MAP,
    ROOT / "domain/missions/mission_definition.gd",
    ROOT / "domain/missions/mission_objective_definition.gd",
    ROOT / "domain/missions/mission_objective_state.gd",
    ROOT / "domain/missions/mission_runtime_state.gd",
    ROOT / "application/missions/mission_objective_service.gd",
    ROOT / "bootstrap/debug/authored_mission_factory.gd",
    ROOT / "presentation/debug/debug_mission_selector.tscn",
    ROOT / "tests/integration/run_stage_4_6_tests.gd",
]


def require_text(path: Path, tokens: list[str], errors: list[str]) -> None:
    if not path.is_file():
        errors.append(f"Missing required file: {path.relative_to(ROOT)}")
        return
    text = path.read_text(encoding="utf-8")
    for token in tokens:
        if token not in text:
            errors.append(f"{path.relative_to(ROOT)} is missing token: {token}")


def main() -> int:
    errors: list[str] = []
    for path in REQUIRED_FILES:
        if not path.is_file():
            errors.append(f"Missing required file: {path.relative_to(ROOT)}")

    require_text(MISSION, [
        'mission_definition_id = &"mission_definition.life.farm_storehouse_raid_01"',
        'objective_id = &"objective.farm.extract_supplies"',
        'required_quantity = 2',
        'objective_id = &"objective.farm.capture_guard"',
        'objective_id = &"objective.farm.extract_furniture"',
        'objective_id = &"objective.farm.avoid_civilian_deaths"',
        'objective_id = &"objective.farm.leave_before_reinforcements"',
        'definition_id = &"item.grain_crate"',
        'definition_id = &"item.grain_sack"',
        'definition_id = &"item.storehouse_table"',
    ], errors)
    require_text(MAP, [
        'definition_id = &"map.life.farm_storehouse_raid_01"',
        'grid_size = Vector2i(40, 40)',
        'deployment_zones =',
        'extraction_zones =',
        'patrol_paths =',
        'recoverable_prop_anchors =',
        'reinforcement_anchors =',
        'civilian_work_anchors =',
        'lighting_regions =',
    ], errors)

    registry = ROOT / "application/missions/mission_definition_registry.gd"
    require_text(registry, ['life_farm_storehouse_raid_01.tres'], errors)
    boot = ROOT / "bootstrap/boot/boot.gd"
    if not boot.is_file():
        errors.append(f"Missing required file: {boot.relative_to(ROOT)}")
    else:
        boot_text = boot.read_text(encoding="utf-8")
        legacy_debug_boot = all(
            token in boot_text
            for token in ['debug_mission_selector.tscn', 'AUTHORED_MISSION_FACTORY_SCRIPT', 'Stage 4.6']
        )
        stage_5_production_boot = 'extends GameApp' in boot_text
        if not legacy_debug_boot and not stage_5_production_boot:
            errors.append(
                "bootstrap/boot/boot.gd must retain the Stage 4.6 debug launcher or enter the Stage 5 GameApp."
            )
        if stage_5_production_boot:
            require_text(
                ROOT / "bootstrap/app/game_app.gd",
                ['MAIN_MENU_SCENE', 'CAMPAIGN_SHELL_SCENE', 'register_mission_and_create_session'],
                errors,
            )
            require_text(
                ROOT / "presentation/debug/debug_mission_selector.tscn",
                ['DebugMissionSelector'],
                errors,
            )

    authored_factory = ROOT / "bootstrap/debug/authored_mission_factory.gd"
    require_text(authored_factory, [
        '_configure_deployed_unit_control(unit, placement)',
        'receives_enemy_turn = true',
        'TacticalUnitState.CONTROLLER_WORLD',
        'return null',
    ], errors)

    objective_service = ROOT / "application/missions/mission_objective_service.gd"
    require_text(objective_service, [
        'TacticalInvalidationContract.mission_state()',
        'commit_after_notifications',
        'MissionObjectiveDefinition.KIND_EXTRACT_ITEMS',
        'MissionObjectiveDefinition.KIND_EXTRACT_CAPTIVE',
    ], errors)

    tactical_screen = (ROOT / "presentation/tactical/tactical_screen.gd").read_text(encoding="utf-8")
    for token in [
        'TextServer.AUTOWRAP_OFF',
        'TextServer.OVERRUN_TRIM_ELLIPSIS',
        '_objective_label.tooltip_text = objective_hud_text',
    ]:
        if token not in tactical_screen:
            errors.append(f"Tactical HUD regression guard is missing: {token}")
    forbidden = [
        'objective.farm.extract_supplies',
        'life_farm_storehouse_raid_01',
        'instance.mission.farm.supply_crate_a',
    ]
    for token in forbidden:
        if token in tactical_screen:
            errors.append(f"Farm-specific mission logic leaked into tactical_screen.gd: {token}")

    ids: dict[str, str] = {}
    patterns_by_file = {
        MISSION: re.compile(r'^(?:mission_definition_id|objective_id|placement_id|instance_id) = &"([^"]+)"', re.MULTILINE),
        MAP: re.compile(r'^(?:anchor_id|zone_id|patrol_path_id|region_id) = &"([^"]+)"', re.MULTILINE),
    }
    for path, id_pattern in patterns_by_file.items():
        if not path.exists():
            continue
        for value in id_pattern.findall(path.read_text(encoding="utf-8")):
            previous = ids.get(value)
            if previous:
                errors.append(f"Duplicate authored ID {value} in {previous} and {path.name}")
            ids[value] = path.name

    if errors:
        print("Stage 4.6 authored mission validation FAILED:")
        for error in errors:
            print(f" - {error}")
        return 1
    print(f"Stage 4.6 authored mission validation PASSED ({len(ids)} authored IDs checked)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
