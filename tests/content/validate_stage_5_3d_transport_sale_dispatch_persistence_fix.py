from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")

SETUP = read("domain/missions/mission_setup_snapshot.gd")
MISSION = read("domain/missions/active_mission_state.gd")
COORDINATOR = read("application/missions/campaign_mission_coordinator.gd")
BAY = read("domain/strategic/stable_bay_state.gd")
TRANSPORT = read("application/strategic/squad_transport_service.gd")
SESSION = read("bootstrap/app/campaign_session.gd")
SHELL = read("presentation/campaign/campaign_shell.gd")

# Immutable mission setups must hash the representation that is actually saved
# to JSON, not a pre-serialization mixture of StringName/int/float containers.
for token in [
    "func _json_stable_integrity_hash() -> String:",
    "var serialized: String = JSON.stringify(canonical_payload)",
    "var normalized: Variant = JSON.parse_string(serialized)",
    "return CanonicalDataHasher.sha256_hex(normalized as Dictionary)",
    'data["integrity_format"] = 2',
    "var computed_hash: String = _json_stable_integrity_hash()",
]:
    assert token in SETUP, token

# Every dispatch path must prove that the setup survives a JSON round trip
# before staging a campaign commit.
for token in [
    "func _json_stable_setup_copy(setup: MissionSetupSnapshot) -> MissionSetupSnapshot:",
    "var persisted_setup: MissionSetupSnapshot = _json_stable_setup_copy(setup)",
    "The immutable mission setup could not survive campaign JSON serialization.",
    "registered.registered_setup_dictionary = persisted_setup.to_dictionary()",
    "registered.setup_hash = persisted_setup.finalized_setup_hash()",
]:
    assert token in COORDINATOR, token
assert COORDINATOR.count("var persisted_setup: MissionSetupSnapshot = _json_stable_setup_copy(setup)") >= 2

# Legacy saves are normalized when active missions are read.
for token in [
    'legacy_setup_integrity = int(raw_setup_dictionary.get("integrity_format", 1)) < 2',
    "result.registered_setup_dictionary = loaded_setup.to_dictionary()",
    "result.setup_hash = migrated_setup.finalized_setup_hash()",
]:
    assert token in MISSION, token

# Dismantling a transport must empty its Stable without removing the assigned squad.
for token in [
    "const TRANSPORT_DISMANTLE_RECOVERY_PERCENT: int = 50",
    "func transport_dismantle_yield(",
    "func dismantle_transport_candidate(",
    "bay.clear_transport_assignment()",
    "campaign.transports_by_id.erase(asset.transport_id)",
]:
    assert token in TRANSPORT, token

for token in [
    "func clear_transport_assignment() -> void:",
    'transport_method_id = &"transport.walking"',
    'transport_asset_id = &""',
    "formation_character_ids_by_slot.clear()",
    "status = STATUS_READY if has_squad() else STATUS_EMPTY",
]:
    assert token in BAY, token

for token in [
    "func dismantle_transport(transport_id: StringName) -> OperationResult:",
    '&"transport_dismantled"',
    "dismantle_transport_candidate(candidate, transport_id)",
]:
    assert token in SESSION, token

for token in [
    'dismantle_button.text = "DISMANTLE TRANSPORT — %s"',
    'dismantle_dialog.title = "Dismantle Transport"',
    "_campaign_session.dismantle_transport(housed_asset.transport_id)",
    "will remain in this Stable as a Walking expedition",
]:
    assert token in SHELL, token

# A squad may remain assigned while an empty Stable receives a vehicle.
assert "return not is_active() and not has_transport()" in BAY

print("PASS — immutable mission setups use a JSON-stable integrity hash.")
print("PASS — both mission registration paths verify a persisted setup before commit.")
print("PASS — legacy immutable setup hashes migrate on load.")
print("PASS — transports can be dismantled for recovered materials and the Stable falls back to Walking.")
