#!/usr/bin/env python3
"""Static contract gate for Stage 4.7 Hotfix 5 Marauder mechanics."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def _read(root: Path, rel: str, errors: list[str]) -> str:
    path = root / rel
    if not path.is_file():
        errors.append(f"Missing required file: {rel}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def _require(text: str, fragments: list[str], label: str, errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in text:
            errors.append(f"{label} is missing: {fragment}")


def _forbid(text: str, fragments: list[str], label: str, errors: list[str]) -> None:
    for fragment in fragments:
        if fragment in text:
            errors.append(f"{label} still contains deferred/obsolete contract: {fragment}")


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    template_rel = "content/characters/reaver/marauder_tier_1.tres"
    template = _read(root, template_rel, errors)
    sack = _read(root, "content/items/raiders_sack.tres", errors)
    fatigue = _read(root, "content/character_effects/fatigued.tres", errors)
    inventory = _read(root, "domain/tactical/tactical_inventory_state.gd", errors)
    state = _read(root, "domain/tactical/tactical_state.gd", errors)
    unit = _read(root, "domain/tactical/tactical_unit_state.gd", errors)
    session = _read(root, "application/tactical/tactical_session.gd", errors)
    transfer = _read(root, "application/tactical/tactical_inventory_transfer_handler.gd", errors)
    body = _read(root, "application/tactical/body/tactical_body_action_handler.gd", errors)
    attack = _read(root, "application/tactical/combat/attack_handler.gd", errors)
    attack_preview = _read(root, "application/tactical/combat/attack_preview_query.gd", errors)
    grapple = _read(root, "application/tactical/combat/grapple_handler.gd", errors)
    availability = _read(root, "application/tactical/queries/action_availability_query.gd", errors)
    detection = _read(root, "application/tactical/awareness/tactical_detection_service.gd", errors)
    status = _read(root, "presentation/tactical/tactical_status_badge_provider.gd", errors)
    token = _read(root, "presentation/tactical/tactical_unit_view.gd", errors)
    window = _read(root, "presentation/tactical/unit_management_window.gd", errors)
    screen = _read(root, "presentation/tactical/tactical_screen.gd", errors)
    resolver = _read(root, "domain/characters/resolution/character_resolver.gd", errors)
    definition = _read(root, "domain/inventory/definitions/item_definition.gd", errors)
    runtime_runner = _read(root, "tests/integration/run_stage_4_7_hotfix_5_tests.gd", errors)
    runtime_tests = _read(root, "tests/integration/stage_4_7_hotfix_5_marauder_mechanics_tests.gd", errors)
    runtime_manifest = _read(root, "tests/runtime/stage_4_5g_runtime_suite.json", errors)

    _require(template, [
        '&"item.raiders_sack"',
        '"maximum_value_source": &"bab"',
        'grid_position": Vector2i(5, 0)',
        'quantity": 2',
        'base_turn_capacity_feet = 80',
        '"base_full_turn_capacity_feet": 60',
        '"duration_rounds": 7',
        '"uses_per_mission": 1',
    ], template_rel, errors)
    _forbid(template, [
        '&"item.rations"',
        '&"item.empty_sack"',
        '&"item.reinforced_captive_carrying_belt"',
        '"maximum_value": 3',
    ], template_rel, errors)

    _require(sack, [
        'id = &"item.raiders_sack"',
        'inventory_footprint = Vector2i(2, 2)',
        'fixed_inventory_fixture = true',
        'internal_container_kind = &"raider_sack"',
        'internal_container_size = Vector2i(4, 3)',
        'internal_single_entity_only = true',
        'internal_allowed_instance_kinds = Array[StringName]([&"body", &"item"])',
    ], "Raider's Sack", errors)
    _require(fatigue, [
        'id = &"effect.fatigued"',
        'ability_modifiers = {"DEX": -2, "STR": -2}',
    ], "Fatigued effect", errors)
    _require(inventory, [
        'const BELT_WIDTH: int = 7',
        'const BELT_HEIGHT: int = 2',
        'const KIND_RAIDER_SACK: StringName = TacticalItemLocationState.CONTAINER_RAIDER_SACK',
        'const RAIDER_SACK_WIDTH: int = 4',
        'const RAIDER_SACK_HEIGHT: int = 3',
    ], "Tactical inventory", errors)
    _require(state, [
        'func raider_sack_item_for_unit',
        'func raider_sack_body_for_unit',
        'func raider_sack_content_for_unit',
        'func item_is_raider_sack_compatible',
        'func refresh_unit_encumbrance',
        'func body_release_cell_for_carrier',
        'TacticalUnitState.LOAD_OVER_CAPACITY',
        'rebuild_unit_occupancy()',
    ], "Tactical state", errors)
    _require(unit, [
        'func is_raging()',
        'func is_fatigued()',
        'func armour_class_for_context',
        'func reflex_bonus_for_context',
        'func apply_encumbrance',
        'func qualifies_for_take_them_alive',
        'func apply_grapple',
        'active_character_modifier_ids.append(&"effect.fatigued")',
        'return Vector2i(4, 3)',
    ], "Tactical unit", errors)
    _require(session, [
        'state_store.state.refresh_unit_encumbrance(unit.unit_id)',
        'grapple_handler.configure(',
        'grapple_handler',
    ], "Tactical session", errors)
    _require(transfer, [
        'KIND_RAIDER_SACK',
        '&"raider_sack_body_only"',
        '&"raider_sack_requires_restraint"',
        'return ActionCost.half_action()',
        'return ActionCost.minor_interaction()',
        'body_release_cell_for_carrier',
        '&"raider_sack_release_blocked"',
    ], "Inventory transfer", errors)
    _require(body, [
        'target.qualifies_for_take_them_alive(actor.unit_id)',
        'ActionCost.quick_action()',
        'attached_restraint_id',
        'source_item.quantity -= 1',
    ], "Body restraint", errors)
    _require(attack, [
        'action.reaver_thrown_dagger_attack',
        'func _land_thrown_item',
        'TacticalItemLocationState.ground(',
        'record_nonlethal_incapacitation',
    ], "Attack handler", errors)
    _require(attack_preview, [
        'feature_parameter(',
        '&"feat.power_attack", &"maximum_value", 99',
        'has_proficiency',
        'nonproficiency_penalty',
        'armour_class_for_context',
    ], "Attack preview", errors)
    _require(grapple, [
        'class_name GrappleHandler',
        'func initiate(',
        'func release(',
        'func break_hold(',
        'TacticalMeleeReachRules.can_reach',
        'TacticalTeamRelations.are_hostile(actor.team_id, target.team_id)',
    ], "Grapple handler", errors)
    _require(availability, [
        'unit.is_raging()',
        'requires_concentration',
        'definition is TacticalAbilityDefinition',
        'unit.is_fatigued()',
    ], "Action availability", errors)
    _require(detection, [
        'func prepare_hidden_trap_perception_check',
        'perception_tiles_for_observer(observer_id)',
        '"perception_modifier": observer.passive_perception() - 10',
    ], "Trap perception hook", errors)
    _require(status, [
        'CONDITION_KIND_RAGE', 'CONDITION_KIND_FATIGUED',
    ], "Status badge provider", errors)
    _require(token, [
        'func _draw_condition_badge()',
        'CONDITION_KIND_RAGE',
    ], "Token condition badges", errors)
    _require(window, [
        'func _initialize_raider_sack_ui()',
        '_raider_sack_popup = PanelContainer.new()',
        'TacticalInventoryState.RAIDER_SACK_WIDTH',
        'func _open_raider_sack_popup()',
        '_raider_sack_close_button.text = "X"',
        'close_style.bg_color = Color(0.63, 0.08, 0.08, 1.0)',
        'if mouse_button == MOUSE_BUTTON_LEFT:',
        'Load: %s',
    ], "Unit management window", errors)
    _forbid(window, [
        '_raider_sack_open',
        'lower.add_child(_raider_sack_panel)',
    ], "Obsolete inline Raider's Sack panel", errors)
    _forbid(screen, [
        '_power_attack_value = (_power_attack_value + 1) % 4',
        '_power_attack_value >= 3',
    ], "Tactical screen Power Attack", errors)
    _require(screen, [
        'func _maximum_power_attack_value()',
        'func _begin_or_resolve_grapple()',
        'func _execute_grapple_at_tile(',
    ], "Tactical screen", errors)
    _require(resolver, [
        'func _equipped_maximum_dexterity_bonus',
        'func _equipped_armour_check_penalty',
        '&"trap_armour_class_bonus"',
        '&"trap_reflex_bonus"',
    ], "Character resolver", errors)
    _require(runtime_runner, [
        'stage_4_7_hotfix_5_marauder_mechanics_tests.gd',
        'Stage 4.7 Hotfix 5 Marauder mechanics tests passed.',
    ], "Hotfix 5 runtime runner", errors)
    _require(runtime_tests, [
        'class_name Stage47Hotfix5MarauderMechanicsTests',
        '_test_rage_fatigue_and_badges',
        '_test_restraint_and_raiders_sack_transfer',
        '_test_minimum_grapple_pipeline',
    ], "Hotfix 5 runtime tests", errors)
    _require(runtime_manifest, [
        '"stage": "4.7-hotfix-5"',
        'run_stage_4_7_hotfix_5_tests.gd',
    ], "Runtime suite manifest", errors)
    _require(definition, [
        '@export var maximum_dexterity_bonus',
        '@export var armour_check_penalty',
        '@export var required_proficiency_id',
        '@export var fixed_inventory_fixture',
        '@export var internal_container_size',
    ], "Item definition", errors)

    spec_path = root / "content/characters/specifications/stage_4_7_approved_sheets.json"
    try:
        data = json.loads(spec_path.read_text(encoding="utf-8"))
        marauder = data["sheets"]["character_template.reaver.marauder_tier_1"]
        if marauder["required_items"] != [
            "item.raiders_axe", "item.patchwork_raider_armour", "item.mace",
            "item.reaver_dagger", "item.manacles", "item.marauder_keys",
            "item.bandage", "item.rope", "item.raiders_sack",
        ]:
            errors.append("Approved Marauder specification does not use the Hotfix 5 loadout.")
        if marauder["feature_parameters"]["feat.power_attack"].get("maximum_value_source") != "bab":
            errors.append("Power Attack specification is not BAB-derived.")
    except (OSError, KeyError, TypeError, json.JSONDecodeError) as exc:
        errors.append(f"Could not validate Hotfix 5 Marauder specification: {exc}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=".")
    args = parser.parse_args()
    errors = validate(Path(args.project).resolve())
    if errors:
        print("Stage 4.7 Hotfix 5 Marauder mechanics validation FAILED:")
        for error in errors:
            print(f" - {error}")
        return 1
    print("Stage 4.7 Hotfix 5 Marauder mechanics validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
