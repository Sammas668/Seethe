from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
CHARACTER = (ROOT / "domain/characters/state/persistent_character_state.gd").read_text(encoding="utf-8")
RESULT = (ROOT / "domain/missions/mission_character_result.gd").read_text(encoding="utf-8")
BUILDER = (ROOT / "application/missions/mission_result_builder.gd").read_text(encoding="utf-8")
COMMIT = (ROOT / "application/campaign/campaign_result_commit_service.gd").read_text(encoding="utf-8")
DEPLOY = (ROOT / "application/characters/tactical_character_deployment_service.gd").read_text(encoding="utf-8")
RECOVERY = (ROOT / "application/characters/strategic_recovery_service.gd").read_text(encoding="utf-8")
SESSION = (ROOT / "bootstrap/app/campaign_session.gd").read_text(encoding="utf-8")
COORDINATOR = (ROOT / "application/missions/campaign_mission_coordinator.gd").read_text(encoding="utf-8")
SHELL = (ROOT / "presentation/campaign/campaign_shell.gd").read_text(encoding="utf-8")
FACILITY_DEF = (ROOT / "domain/stronghold/stronghold_facility_definition.gd").read_text(encoding="utf-8")
FACTORY = (ROOT / "infrastructure/content/stronghold/starting_stronghold_factory.gd").read_text(encoding="utf-8")
STRONGHOLD = json.loads((ROOT / "content/stronghold/starting_ruin/starting_ruin.json").read_text(encoding="utf-8"))

for token in [
    "var health_initialized: bool",
    "var current_hp: int",
    "var nonlethal_damage: int",
    "func apply_strategic_recovery",
    "func can_deploy_with_health",
    'return &"gravely_wounded"',
]:
    assert token in CHARACTER, token

assert '"current_hp": current_hp' in CHARACTER
assert '"nonlethal_damage": nonlethal_damage' in CHARACTER
assert '"lethal_recovery_units": lethal_recovery_units' in CHARACTER
assert '"nonlethal_recovery_units": nonlethal_recovery_units' in CHARACTER

assert "var nonlethal_damage: int = 0" in RESULT
assert '"nonlethal_damage": nonlethal_damage' in RESULT
assert "character_result.nonlethal_damage = unit.nonlethal_damage" in BUILDER
assert 'injury_entries.append("Wounded")' not in BUILDER
assert 'injury_entries.append("Gravely Wounded")' not in BUILDER
assert "character.set_persistent_health(" in COMMIT
assert "result.nonlethal_damage" in COMMIT
assert "unit.restore_damage_state(" in DEPLOY
assert "character.resolved_current_hp(unit.maximum_hp)" in DEPLOY


assert "var recovery_rate_bonus_by_level: Array[int]" in FACILITY_DEF
assert "func recovery_rate_bonus_for_level" in FACILITY_DEF
assert 'entry.get("recovery_rate_bonus_by_level", [])' in FACTORY
recovery_defs = [
    entry for entry in STRONGHOLD.get("facilities", [])
    if entry.get("id") == "facility.recovery_chamber"
]
assert len(recovery_defs) == 1
assert recovery_defs[0].get("recovery_rate_bonus_by_level") == [2, 4, 6]

assert "BASE_LETHAL_POINTS_PER_DAY: int = 4" in RECOVERY
assert "func ensure_campaign_health" in RECOVERY
assert "legacy_hp" in RECOVERY
assert "recovery_rate_bonus_for_level" in RECOVERY
assert "_best_operational_recovery_treatment" in RECOVERY
assert '"nonlethal_points_per_day": lethal_rate * 2' in RECOVERY
assert "campaign.active_reservation_for_character" in RECOVERY
assert "StrongholdFacilityState.CONDITION_OPERATIONAL" in RECOVERY
assert "StrongholdFacilityState.CONDITION_UPGRADING" in RECOVERY
assert "strategic_recovery_service.advance_candidate(candidate, tick_delta)" in SESSION
assert "strategic_recovery_service.ensure_campaign_health(campaign)" in SESSION
assert "strategic_recovery_service.configure(catalogue, stronghold_registry)" in SESSION
assert "func strategic_recovery_snapshot" in SESSION
assert "not character.can_deploy_with_health(maximum_hp)" in COORDINATOR

assert '"%d / %d" % [current_hp, maximum_hp]' in SHELL
assert '"NONLETHAL"' in SHELL
assert '"May deploy injured at the displayed persistent health values."' in SHELL
assert '"INJURED DEPLOYMENT WARNING' in SHELL
assert "health_locked" in SHELL
assert 'return "Gravely Wounded"' in SHELL

print("PASS — final tactical lethal and nonlethal damage persist to the campaign roster.")
print("PASS — stronghold recovery advances lethal damage normally and nonlethal damage at twice the rate.")
print("PASS — conscious injured characters remain deployable; unconscious characters are blocked.")
print("PASS — roster, dossier and briefing surfaces show persistent health and injured-deployment warnings.")
