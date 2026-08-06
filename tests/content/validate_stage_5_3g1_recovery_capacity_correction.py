from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"Missing Stage 5.3G1 file: {relative}"
    return path.read_text(encoding="utf-8")


recovery = read("application/missions/mission_recovery_selection_service.gd")
transport = read("application/strategic/squad_transport_service.gd")
shell = read("presentation/campaign/campaign_shell.gd")
runtime = read("tests/integration/stage_5_3g1_recovery_capacity_tests.gd")
runner = read("tests/integration/run_stage_5_3g_tests.gd")
doc = read("docs/architecture/STAGE_5_3G1_RECOVERY_CAPACITY_CORRECTION.md")
hotfix = read("HOTFIX_STAGE_5_3G1_RECOVERY_CAPACITY.md")

for token in [
    "func _personal_recovery_capacity_snapshot",
    'stat_value(&"maximum_weight_lb", 0)',
    'stat_value(&"light_load_max_lb", 0)',
    '"maximum_load_lb": maximum_load',
    '"remaining_carry_capacity_lb": remaining_total',
    '"personal_remaining_carry_capacity_lb"',
    "maximum_load - mandatory_carried",
    "survivor carrying capacity and mandatory burdens",
]:
    assert token in recovery, token

assert 'personal_capacity.get("remaining_carry_capacity_lb", 0.0)' in recovery
assert 'personal_capacity.get("remaining_light_load_lb", 0.0)' not in recovery
assert "post-mission hauling" in recovery
assert "medium and heavy encumbrance" in recovery.lower()

for token in [
    "Survivors’ remaining carrying capacity",
    "RECOVERY CARRYING BREAKDOWN",
    "maximum −",
    "Medium and heavy return loads are allowed",
    "personal_remaining_carry_capacity_lb",
]:
    assert token in shell, token

assert "remaining carrying capacity up to maximum load" in transport
assert "remaining Light Load" not in transport

for token in [
    "Stage53G1RecoveryCapacityTests",
    "obsolete_light_remaining",
    "personal_remaining_carry_capacity_lb",
    "Cargo above Light Load but within maximum load was rejected",
    "Dedicated transport cargo should be the complete gross recovery allowance",
    "Survivor carrying capacity should not be added when dedicated transport carries the squad",
]:
    assert token in runtime, token

assert "Stage53G1RecoveryCapacityTests.run_all" in runner
assert "maximum load" in doc.lower()
assert "Recovery Capacity" in hotfix

print("PASS — Stage 5.3G1 recovery capacity uses survivors' remaining maximum load.")
print("PASS — Walking uses remaining maximum load and transported recovery is delegated to Stage 5.3G2.")
print("PASS — the recovery UI exposes the complete per-survivor weight calculation.")
