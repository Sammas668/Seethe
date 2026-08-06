from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    file_path = ROOT / path
    assert file_path.is_file(), f"Missing Stage 5.3G file: {path}"
    return file_path.read_text(encoding="utf-8")


character_result = read("domain/missions/mission_character_result.gd")
outcome_service = read("application/missions/mission_character_outcome_service.gd")
xp_service = read("application/missions/mission_experience_award_service.gd")
resolver = read("application/tactical/extraction/resolve_tactical_mission_handler.gd")
recovery = read("application/missions/mission_recovery_selection_service.gd")
validator = read("application/missions/mission_result_validator.gd")
commit = read("application/campaign/campaign_result_commit_service.gd")
character = read("domain/characters/state/persistent_character_state.gd")
coordinator = read("application/missions/campaign_mission_coordinator.gd")
shell = read("presentation/campaign/campaign_shell.gd")
session = read("bootstrap/app/campaign_session.gd")
tests = read("tests/integration/stage_5_3g_persistent_mission_lifecycle_tests.gd")
runner = read("tests/integration/run_stage_5_3g_tests.gd")
doc = read("docs/architecture/STAGE_5_3G_PERSISTENT_MISSION_LIFECYCLE_HARDENING.md")
hotfix = read("HOTFIX_STAGE_5_3G_PERSISTENT_MISSION_LIFECYCLE.md")

for token in [
    "mission_statistics",
    "completed_objective_ids",
    "failed_objective_ids",
    "xp_award_breakdown",
    "func statistic",
]:
    assert token in character_result, f"MissionCharacterResult lacks {token}"

for token in [
    "class_name MissionCharacterOutcomeService",
    "populate(",
    "reconcile_after_recovery_selection(",
    "needs_lifecycle_migration(",
    '"kills"',
    '"incapacitations"',
    '"captures"',
    '"allies_stabilised"',
]:
    assert token in outcome_service, f"Outcome service lacks {token}"

for token in [
    "award_plan(",
    '"enemies_killed"',
    '"enemies_incapacitated"',
    '"captives_taken"',
    '"allies_stabilised"',
    "validate_awards(",
]:
    assert token in xp_service, f"XP authority lacks {token}"

assert resolver.count("MissionCharacterOutcomeService.populate") >= 3
assert resolver.count("MissionExperienceAwardService.apply_awards") >= 3
assert "_finalize_event_statistics(result)" in resolver

for token in [
    "MissionCharacterOutcomeService.reconcile_after_recovery_selection",
    "MissionExperienceAwardService.apply_awards",
    "MissionExperienceAwardService.validate_awards",
    'mission_statistics["captives_taken"]',
]:
    assert token in recovery, f"Recovery selection lacks {token}"

for token in [
    "MissionExperienceAwardService.validate_awards",
    "completed-objective history disagrees",
    "persistent mission-history entry",
]:
    assert token in validator, f"Context validator lacks {token}"

for token in [
    "_audit_candidate_against_result",
    "mission_commit_item_audit_failed",
    "mission_commit_captive_audit_failed",
    "mission_commit_missing_audit_failed",
    "mission_commit_death_audit_failed",
]:
    assert token in commit, f"Candidate audit lacks {token}"

assert "func is_missing_or_unrecovered" in character
assert "not is_missing_or_unrecovered()" in character
assert "character_missing_unrecovered" in coordinator

for token in [
    "Kills %d",
    "Incapacitations %d",
    "Captures %d",
    "XP: ",
    "LEVEL UP AVAILABLE",
]:
    assert token in shell, f"Mission summary lacks {token}"

for token in [
    "MissionCharacterOutcomeService.needs_lifecycle_migration",
    "save_pending_mission_recovery",
    "MissionExperienceAwardService.apply_awards",
]:
    assert token in session, f"Pending recovery migration lacks {token}"

for token in [
    "_test_atomic_return_with_multiple_carriers_and_death",
    "_test_full_backpack_extraction_preserves_every_item",
    "_test_missing_character_remains_unavailable",
    "_test_recovery_selection_rebuilds_captures_xp_and_history",
    "_test_pending_result_round_trip_migration",
    "FailingRepository",
    "campaign_save_failed",
]:
    assert token in tests, f"Integration coverage lacks {token}"

assert "Stage53GPersistentMissionLifecycleTests.run_all" in runner
assert "Stage53G1RecoveryCapacityTests.run_all" in runner
assert "detached" in doc.lower() and "exact-once" in doc.lower()
assert "Persistent Mission Lifecycle" in hotfix

print("Stage 5.3G persistent mission lifecycle hardening static validation passed.")
