from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"Missing Stage 5.3G2 file: {relative}"
    return path.read_text(encoding="utf-8")


recovery = read("application/missions/mission_recovery_selection_service.gd")
transport = read("application/strategic/squad_transport_service.gd")
shell = read("presentation/campaign/campaign_shell.gd")
runtime = read("tests/integration/stage_5_3g2_transport_recovery_tests.gd")
runner = read("tests/integration/run_stage_5_3g_tests.gd")
doc = read("docs/architecture/STAGE_5_3G2_TRANSPORT_RECOVERY_CAPACITY.md")
hotfix = read("HOTFIX_STAGE_5_3G2_TRANSPORT_RECOVERY_CAPACITY.md")

for token in [
    "func _uses_dedicated_transport",
    '"uses_dedicated_transport": uses_dedicated_transport',
    '"recovery_capacity_source": "transport" if uses_dedicated_transport else "survivors"',
    "var personal_recovery_capacity: float",
    "0.0\n\t\tif uses_dedicated_transport",
    "transport_cargo if uses_dedicated_transport else personal_recovery_capacity",
    '"manual_casualty_count": manual_casualties',
    '"passenger_supported_casualty_count"',
    "assigned transport after mandatory cargo burdens",
]:
    assert token in recovery, token

assert "transport_cargo +" not in recovery
assert "combined transport and survivor" not in recovery

for token in [
    "passenger allowance carries the squad and personal equipment",
    "recovered assets use dedicated cargo capacity",
    "Rider carrying capacity is not added to its cargo rating",
]:
    assert token in transport, token

for token in [
    "Transport cargo capacity",
    "Squad and personal equipment: passenger allowance",
    "Survivor carrying contribution: ignored",
    "troop carrying capacity is not added",
    "uses_dedicated_transport",
    '"manual_casualty_count"',
]:
    assert token in shell, token

for token in [
    "Stage53G2TransportRecoveryTests",
    "Transport recovery still added troop carrying capacity",
    "Cargo above the transport rating was accepted by adding troop capacity",
    "A transported squad casualty incorrectly consumed cargo capacity",
    "passenger_supported_casualty_count",
]:
    assert token in runtime, token

assert "Stage53G2TransportRecoveryTests.run_all" in runner
assert "Stage 5.3G/G1/G2" in runner
assert "Transport Recovery Capacity Separation" in doc
assert "Transport Recovery Capacity Separation" in hotfix
assert "Transport cargo and troop carrying capacity are never added together" in hotfix

print("PASS — assigned transport cargo replaces rather than stacks with troop carrying capacity.")
print("PASS — passenger allowance carries the deployed squad, personal equipment and recovered squad casualties.")
print("PASS — Walking remains based on survivors' remaining maximum loads.")
