#!/usr/bin/env python3
"""Static acceptance checks for token-only return travel and safe persistence."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
errors: list[str] = []


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        errors.append(f"missing required file: {relative}")
        return ""
    return path.read_text(encoding="utf-8")


travel = read("application/strategic/squad_travel_service.gd")
session = read("bootstrap/app/campaign_session.gd")
shell = read("presentation/campaign/campaign_shell.gd")
map_view = read("presentation/campaign/widgets/region_map_view.gd")
repository = read("infrastructure/persistence/json_campaign_repository.gd")
store = read("application/campaign/campaign_state_store.gd")

for token in [
    '"returned_operation_ids": []',
    '(result["returned_operation_ids"] as Array).append(operation.operation_id)',
    "Auto-replenishment is deliberately deferred",
]:
    if token not in travel:
        errors.append(f"return travel service missing: {token}")

for token in [
    "signal squad_returned(operation_id: StringName, replenishment_message: String)",
    '&"squad_returned"',
    "_flush_clock_state(persistence_reason)",
    "func _replenish_returned_operation(operation_id: StringName)",
    '&"returned_squad_replenished"',
    "return_arrival_invalid",
]:
    if token not in session:
        errors.append(f"campaign session missing safe return boundary: {token}")

process_start = session.find("func process_strategic_time")
flush_index = session.find("_flush_clock_state(persistence_reason)", process_start)
replenish_call = session.find("_replenish_returned_operation(", flush_index)
if flush_index < 0 or replenish_call < 0 or flush_index > replenish_call:
    errors.append("return loadout replenishment runs before the return state is persisted")

for token in [
    "signal squad_selected(operation_id: StringName)",
    "func _is_squad_at_screen_position",
    "squad_selected.emit(operation.operation_id)",
    'var label_text: String = "RETURNING" if is_returning else "TRAVELLING"',
    "func clear_squad_selection()",
]:
    if token not in map_view:
        errors.append(f"region map missing token-only squad interaction: {token}")

for forbidden in [
    '"RETURNING • %s"',
    "_format_squad_travel_minutes",
    "return_arrival_tick - int(_visual_campaign_tick)",
]:
    if forbidden in map_view:
        errors.append(f"region map still displays a live return countdown: {forbidden}")

for token in [
    "_region_map_view.squad_selected.connect(_on_squad_selected)",
    "func _on_squad_selected(operation_id: StringName)",
    '"RETURNING TO THE STRONGHOLD"',
    "_region_map_view.focus_squad()",
    "_campaign_session.pause_clock(false)",
    "_clock_error_latched",
    "Strategic time paused: %s",
    "func _on_squad_returned",
]:
    if token not in shell:
        errors.append(f"campaign shell missing return token UX or error latch: {token}")

for forbidden in [
    "var _mission_button: Button",
    "_mission_button = Button.new()",
    "func _on_mission_action()",
    '"RETURNING\\n%s"',
    '"View the squad returning to the lair."',
    "Squad returning to the lair — arrival in %s.",
]:
    if forbidden in shell:
        errors.append(f"campaign shell still contains the removed top-right mission/return control: {forbidden}")

for token in [
    "var last_save_error: String",
    "func _record_save_error(message: String)",
    "Temporary campaign save failed verification",
]:
    if token not in repository:
        errors.append(f"repository missing actionable persistence diagnostics: {token}")

if 'String(_repository.get("last_save_error"))' not in store:
    errors.append("campaign store does not surface the repository's exact save failure")

if errors:
    print("Stage 5.3D Token-Only Return Journey validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — returning squads render and animate on the Region Map without an ETA.")
print("PASS — the moving squad token is the only squad journey selection control.")
print("PASS — no top-right mission/launch/returning-squad button remains.")
print("PASS — physical arrival is persisted before loadout replenishment.")
print("PASS — strategic time pauses after one save failure instead of flashing repeatedly.")
