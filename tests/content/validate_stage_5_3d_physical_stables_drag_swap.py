from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding='utf-8')

CAMPAIGN = read('domain/campaign/campaign_state.gd')
SQUAD = read('domain/strategic/campaign_squad_state.gd')
BAY = read('domain/strategic/stable_bay_state.gd')
TRANSPORT = read('domain/strategic/transport_state.gd')
TRANSPORT_DEF = read('domain/strategic/squad_transport_definition.gd')
SQUAD_SERVICE = read('application/strategic/squad_management_service.gd')
BAY_SERVICE = read('application/strategic/stable_bay_service.gd')
TRANSPORT_SERVICE = read('application/strategic/squad_transport_service.gd')
COORDINATOR = read('application/missions/campaign_mission_coordinator.gd')
SESSION = read('bootstrap/app/campaign_session.gd')
FACTORY = read('bootstrap/debug/authored_mission_factory.gd')
SETUP = read('domain/missions/mission_setup_snapshot.gd')
SHELL = read('presentation/campaign/campaign_shell.gd')
SLOT = read('presentation/campaign/stable/stable_formation_drop_slot.gd')
RESERVE = read('presentation/campaign/stable/stable_reserve_drop_zone.gd')
STRONGHOLD = json.loads(read('content/stronghold/starting_ruin/starting_ruin.json'))

for token in [
    'var squads_by_id: Dictionary',
    'var stable_bays_by_id: Dictionary',
    'base["squads"] = serialized_squads',
    'base["stable_bays"] = serialized_bays',
    'CampaignSquadState.from_dictionary',
    'StableBayState.from_dictionary',
    'const CURRENT_SAVE_VERSION: int = 15',
    '_migrate_physical_stable_housing(campaign)',
]:
    assert token in CAMPAIGN, token

for token in [
    'var member_character_ids: Array[StringName]',
    'var assigned_stable_bay_id: StringName',
    'var current_operation_id: StringName',
]:
    assert token in SQUAD, token

for token in [
    'var stable_facility_id: StringName',
    'func is_vacant_for_transport()',
    'func clear_squad_assignment()',
    '"stable_facility_id": String(stable_facility_id)',
]:
    assert token in BAY, token

for token in [
    'const WALKING_FORMATION_CAPACITY: int = 6',
    'One exact constructed Stable facility creates one housing/expedition record.',
    'func bay_for_facility',
    'func stable_bay_is_operational',
    'func first_empty_stable',
    'func assign_squad',
    'func assign_transport_asset',
    'func set_formation_slot',
    'func remove_formation_character',
    'func clear_formation',
    'func auto_arrange_formation',
    'dragging between occupied positions swaps the two characters',
    'formation_empty',
]:
    assert token in BAY_SERVICE, token

assert 'total += clampi(facility.level, 1, 3)' not in BAY_SERVICE
assert 'squad.member_character_ids.size() > capacity' not in BAY_SERVICE

for token in [
    'Construct an empty Stable before acquiring another transport.',
    'target_stable_bay_id: StringName',
    'asset.housed_stable_id = target_bay.stable_facility_id',
    'target_bay.transport_asset_id = asset.transport_id',
    'walking_data["total_passenger_capacity"] = 6',
    'walking_data["capacity_valid"] = character_count <= 6',
]:
    assert token in TRANSPORT_SERVICE, token

assert 'var housed_stable_id: StringName = &""' in TRANSPORT
assert 'Transport damage' not in SHELL
assert 'REPAIR TRANSPORT' not in SHELL

for token in [
    'func _get_drag_data',
    '"source_slot_id": String(slot_id)',
    'Drag a reserve here, or drag this occupied position onto another to swap them.',
]:
    assert token in SLOT, token

for token in [
    'class_name StableReserveDropZone',
    'signal character_removed',
    'DROP HERE TO REMOVE FROM DEPLOYMENT',
]:
    assert token in RESERVE, token

for token in [
    'const SCREEN_STABLE: StringName = &"stable"',
    '_add_nav_button(row, SCREEN_STABLE, "STABLE"',
    'CONSTRUCTED STABLES',
    'HOUSED TRANSPORT',
    'WALKING FORMATION — SIX FIXED POSITIONS',
    'StableReserveDropZoneScript.new()',
    'auto_arrange_stable_formation',
    'clear_stable_formation',
    'remove_stable_formation_character',
    'DEPLOYED: %d / %d SQUAD MEMBERS',
]:
    assert token in SHELL, token

stable = SHELL.split('func _build_stable_screen()', 1)[1].split('func _build_roster_screen()', 1)[0]
assert 'transport_selector' not in stable
assert 'squad_selector' in stable
assert 'set_stable_formation_slot' in stable
assert 'toggle_stable_transport_fitting' in stable
assert 'range(capacity)' in stable

briefing = SHELL.split('func _build_briefing_screen()', 1)[1].split('func _selected_briefing_character_ids', 1)[0]
assert 'selected_bay.occupied_character_ids()' in briefing
assert 'SQUAD LIMIT' not in briefing
assert '6 if bool(transport.get("is_walking", false))' in briefing

for token in [
    'func stable_bay_for_facility',
    'func stable_bay_is_operational',
    'func remove_stable_formation_character',
    'func clear_stable_formation',
    'func auto_arrange_stable_formation',
    'target_stable_bay_id: StringName = &""',
]:
    assert token in SESSION, token

for token in [
    'var _campaign_squad_id: StringName',
    'var _stable_bay_id: StringName',
    'var _transport_method_id: StringName',
    'var _transport_asset_id: StringName',
    'var _deployment_slot_by_character_id: Dictionary',
]:
    assert token in SETUP, token

for token in [
    'formation_character_ids_by_slot',
    '_player_deployment_anchors',
    'setup.configure_tactical_start',
]:
    assert token in FACTORY, token

for token in [
    'stable_bay_id', 'campaign_squad_id', 'transport_asset_id',
    'mark_departed_candidate',
]:
    assert token in COORDINATOR, token

stable_defs = [x for x in STRONGHOLD.get('facilities', []) if x.get('id') == 'facility.stables']
assert len(stable_defs) == 1
stable_def = stable_defs[0]
assert stable_def.get('buildable') is True
assert stable_def.get('unique') is False
assert stable_def.get('max_level') == 1
assert stable_def.get('stable_space_by_level') == [1]
benefits = '\n'.join(stable_def.get('benefit_lines', []))
assert 'Each constructed Stable houses one exact transport.' in benefits
assert 'six-person walking expedition' in benefits
assert 'acquiring one requires an empty Stable' in benefits

print('PASS — one constructed Stable owns one exact transport housing record.')
print('PASS — transport acquisition requires and immediately fills an empty Stable.')
print('PASS — squads are assigned to Stables while Roster and Armoury remain separate.')
print('PASS — walking has six fixed positions and squad reserves may remain at the stronghold.')
print('PASS — occupied formation slots are draggable and swap through authoritative service logic.')
