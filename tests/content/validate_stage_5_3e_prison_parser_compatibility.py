from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")

external_files = [
    "application/campaign/captive_service.gd",
    "application/campaign/prison_capacity_service.gd",
    "application/campaign/campaign_result_commit_service.gd",
    "application/characters/strategic_recovery_service.gd",
    "presentation/campaign/campaign_shell.gd",
    "domain/campaign/campaign_state.gd",
]
for rel in external_files:
    assert "CampaignCaptiveState.STATUS_" not in read(rel), rel
print("PASS — captive status comparisons do not depend on stale global-class constant metadata.")

body = read("application/tactical/body/tactical_body_action_handler.gd")
assert "target.apply_restraint(attached_item.item_id)" in body
assert "target.apply_restraint(attached_item.item_id, applied_by_unit_id)" not in body
assert 'target.set("restraint_applied_by_unit_id", applied_by_unit_id)' in body
print("PASS — restraint application remains compatible with both one-argument and newer TacticalUnitState scripts.")

builder = read("application/missions/mission_result_builder.gd")
assert 'captive_unit.get("restraint_applied_by_unit_id")' in builder
print("PASS — mission capture attribution uses dynamic member access and avoids stale parser metadata.")
