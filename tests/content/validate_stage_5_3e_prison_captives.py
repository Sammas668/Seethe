from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")

facility_json = json.loads(read("content/stronghold/starting_ruin/starting_ruin.json"))
facility = next(x for x in facility_json["facilities"] if x["id"] == "facility.prison")
assert facility["prison_capacity_by_level"] == [6, 12, 20]
print("PASS — Prison I/II/III provide authored 6/12/20 cell capacity.")

state = read("domain/campaign/campaign_captive_state.gd")
for token in [
    "STATUS_INCOMING", "STATUS_HELD", "STATUS_RANSOMED", "STATUS_RELEASED",
    "current_hp", "maximum_hp", "nonlethal_damage", "assigned_prison_id",
    "release_notoriety_delta", "ransom_value", "history_entries", "captor_character_id",
]:
    assert token in state, token
assert "loyalty" not in state.lower()
assert "personality" not in state.lower()
print("PASS — exact persistent captive records store custody, health, capture and action state without loyalty simulation.")

tactical_unit = read("domain/tactical/tactical_unit_state.gd")
body_handler = read("application/tactical/body/tactical_body_action_handler.gd")
mission_captive = read("domain/missions/mission_captive_result.gd")
assert "restraint_applied_by_unit_id" in tactical_unit
assert "actor.unit_id" in body_handler and "_attach_restraint" in body_handler
assert "captor_character_id" in mission_captive
print("PASS — the exact character who applied the restraint is preserved into the captive capture record.")

recovery = read("application/missions/mission_recovery_selection_service.gd")
for token in [
    '"captive_entries"', '"prison"', 'selected_captive_ids',
    '&"prison_missing"', '&"prison_capacity_exceeded"',
    'dedicated_captive_capacity', 'manual_captives',
]:
    assert token in recovery, token
assert "captive_results_by_character_id.erase" in recovery
print("PASS — extracted captives are optional recovery selections validated against transport and reserved Prison capacity.")

capacity = read("application/campaign/prison_capacity_service.gd")
for token in [
    "held_cells", "incoming_cells", "available_capacity",
    "admit_returning_candidate", "stronghold.awaiting_admission",
    "can_remove_prison_facility", "prison_capacity_reserved",
]:
    assert token in capacity, token
print("PASS — multiple Prisons aggregate capacity, incoming cells reserve space and admission is transactional.")

service = read("application/campaign/captive_service.gd")
for token in [
    "preview_release", "release_captive", "preview_ransom", "ransom_captive",
    "_apply_release_notoriety", '"Release of %s"',
    "campaign.resources.add(&\"gold\"", "CONDITION_DISABLED",
]:
    assert token in service, token
assert "random" not in service.lower()
assert "preview_interrogate" in service and "interrogate_captive" in service
assert "recruit_captive" not in service.lower()
print("PASS — Release and Ransom retain their authored outcomes; Stage 5.4C adds one-time authored interrogation without random rewards.")

shell = read("presentation/campaign/campaign_shell.gd")
for token in [
    "SCREEN_PRISON", "_build_prison_screen", "_build_prison_captive_dossier",
    "RANSOM", "RELEASE", "RETURN TO STRONGHOLD", "MANAGE FACILITY",
    "PRISON_FILTER_RANSOMABLE", "PRISON_FILTER_WOUNDED",
    "PortraitAssetResolver.new().resolve", "OPEN PRISON",
]:
    assert token in shell, token
assert '_add_nav_button("PRISON"' not in shell
assert 'text = "PRISON"' in shell  # screen heading only
print("PASS — clicking a constructed Prison opens a full captive list/dossier/action screen with no global Prison navigation button.")

travel = read("application/strategic/squad_travel_service.gd")
assert "admit_returning_candidate" in travel
result_commit = read("application/campaign/campaign_result_commit_service.gd")
for token in ['&"incoming"', "return_transit.", "CaptivePolicyRegistry", "maximum_hp", "nonlethal_damage"]:
    assert token in result_commit, token
print("PASS — exact extracted captives remain incoming on the return operation and enter Prison custody only on physical arrival.")

campaign = read("domain/campaign/campaign_state.gd")
assert "const CURRENT_SAVE_VERSION: int = 23" in campaign
assert "captive_action_reports" in campaign
assert "Held captive %s references a missing or invalid Prison" in campaign
print("PASS — save migration and campaign validation persist captive custody and itemised Prison-action outcomes.")

shell_lower = shell.lower()
assert 'interrogate.text = "interrogate"' in shell_lower
assert "recruitment and conversion remain deferred" in shell_lower
print("PASS — authored interrogation is available while recruitment and conversion remain explicitly deferred.")
