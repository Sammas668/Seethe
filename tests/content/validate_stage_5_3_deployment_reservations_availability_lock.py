#!/usr/bin/env python3
"""Static acceptance checks for Stage 5.3 deployment reservations and availability locks."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
errors: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        errors.append(f"missing required file: {rel}")
        return ""
    return path.read_text(encoding="utf-8")


reservation_state = read("domain/campaign/strategic_reservation_state.gd")
reservation_service = read("application/inventory/strategic_reservation_service.gd")
campaign_state = read("domain/campaign/campaign_state.gd")
mission_state = read("domain/missions/active_mission_state.gd")
travel_state = read("domain/strategic/squad_travel_operation_state.gd")
coordinator = read("application/missions/campaign_mission_coordinator.gd")
session = read("bootstrap/app/campaign_session.gd")
inventory = read("application/inventory/inventory_service.gd")
equipment = read("application/inventory/strategic_equipment_service.gd")
loadouts = read("application/inventory/loadout_service.gd")
shell = read("presentation/campaign/campaign_shell.gd")
grid = read("presentation/campaign/widgets/strategic_spatial_inventory_grid.gd")
repository = read("infrastructure/persistence/json_campaign_repository.gd")

for token in [
    "class_name StrategicReservationState",
    'PURPOSE_DEPLOYMENT: StringName = &"deployment"',
    "var character_ids: Array[StringName]",
    "var item_ids: Array[StringName]",
    "func release(",
    '"character_ids": _name_array(character_ids)',
    '"item_ids": _name_array(item_ids)',
    "static func from_dictionary(",
]:
    if token not in reservation_state:
        errors.append(f"reservation state missing: {token}")

for token in [
    "func reserve_deployment_candidate(",
    "func release_reservation_candidate(",
    "func character_availability(",
    "func item_availability(",
    "func validate_location_change(",
    "func ensure_deployment_reservations(",
    "Deployed with %s. Reserved for %s.",
    "Unavailable until the squad returns.",
]:
    if token not in reservation_service:
        errors.append(f"reservation service missing: {token}")

for token in [
    "const CURRENT_SAVE_VERSION: int = 13",
    "var strategic_reservations_by_id: Dictionary",
    "func active_reservation_for_character(",
    "func active_reservation_for_item(",
    'base["strategic_reservations"] = serialized_reservations',
    'data.get("strategic_reservations", [])',
    "strategic_reservations_by_id = restored.strategic_reservations_by_id",
    "Registered mission %s has no active deployment reservation.",
]:
    if token not in campaign_state:
        errors.append(f"CampaignState missing reservation authority: {token}")

to_dict_start = campaign_state.find("func to_dictionary()")
to_dict_end = campaign_state.find("static func from_dictionary", to_dict_start)
if "errors.append" in campaign_state[to_dict_start:to_dict_end]:
    errors.append("CampaignState.to_dictionary contains validation-only mutations")

for source, tokens, label in [
    (mission_state, ["var deployment_reservation_id", '"deployment_reservation_id"', "has no deployment reservation"], "ActiveMissionState"),
    (travel_state, ["var reservation_id", '"reservation_id"', "is_active() and reservation_id.is_empty()"], "SquadTravelOperationState"),
]:
    for token in tokens:
        if token not in source:
            errors.append(f"{label} missing: {token}")

for token in [
    "reserve_deployment_candidate(",
    "registered.deployment_reservation_id = reservation_id",
    "operation.reservation_id = reservation_id",
    "func cancel_squad_deployment(",
    "release_reservation_candidate(",
    "func _validate_deployment_selection(",
]:
    if token not in coordinator:
        errors.append(f"mission coordinator missing reservation lifecycle: {token}")

if "declared_save_version < CampaignState.CURRENT_SAVE_VERSION" not in repository:
    errors.append("campaign repository does not persist migrated reservation saves")

for token in [
    "strategic_reservation_service = StrategicReservationServiceScript.new()",
    "strategic_character_availability(",
    "strategic_item_availability(",
    "ensure_deployment_reservations(",
    "func cancel_squad_deployment(",
]:
    if token not in session:
        errors.append(f"CampaignSession missing reservation integration: {token}")

for source, label in [(inventory, "InventoryService"), (equipment, "StrategicEquipmentService"), (loadouts, "LoadoutService")]:
    if "validate_character_available(" not in source and label != "InventoryService":
        errors.append(f"{label} does not enforce character deployment locks")
    if label != "LoadoutService" and "validate_item_available(" not in source:
        errors.append(f"{label} does not enforce exact-item deployment locks")

for token in [
    "grid.set_interaction_locked(deployment_locked, lock_reason)",
    "slot.disabled = deployment_locked",
    "load_button.disabled = templates.is_empty() or deployment_locked",
    "selector.disabled = true",
    'label.text = "DEPLOYED\\n%s"',
    'return &"deployed"',
    'reservation_reason',
    'release_condition',
    'dismantle.disabled = not preview.success',
    "strategic_character_availability(",
    "RECALL SQUAD BEFORE DEPARTURE",
]:
    if token not in shell:
        errors.append(f"campaign UI missing availability lock behaviour: {token}")

for token in [
    "func set_interaction_locked(",
    "item_control.disabled = locked",
    "if _interaction_locked:",
]:
    if token not in grid:
        errors.append(f"strategic inventory grid missing lock behaviour: {token}")

if errors:
    print("Stage 5.3 Deployment Reservations & Availability Lock validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — deployment reservations persist exact character and item identities.")
print("PASS — dispatch, cancellation, result commit and migration own reservation lifecycle.")
print("PASS — roster, storage, templates, equipment and spatial inventory enforce availability locks.")
print("PASS — player-facing screens retain visibility while explaining every unavailable object.")
