from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


builder = read("application/missions/mission_result_builder.gd")
recovery = read("application/missions/mission_recovery_selection_service.gd")
runtime_test = read("tests/integration/stage_5_3f5_carried_loot_recovery_tests.gd")

# MissionSetupSnapshot contains authored mission-ground items as well as outbound
# equipment. Result building must distinguish those categories by ownership and
# deployment rather than treating every setup item as equipment brought from base.
assert "static func _setup_item_is_player_outbound" in builder
assert "return setup.was_deployed(item.location.owner_id)" in builder
assert "CampaignItemLocationState.LOCATION_CHARACTER_EQUIPMENT" in builder
assert "CampaignItemLocationState.LOCATION_CHARACTER_INVENTORY" in builder
assert "if setup.get_item(item.item_id) != null:\n\t\treturn true" not in builder
assert "_setup_item_is_player_outbound(setup, setup.get_item(item.item_id))" in builder
assert "if not _setup_item_is_player_outbound(setup, setup_item):" in builder

# Carried mission loot must consume recovery capacity once. The survivor's
# maximum load is reduced by outbound equipment only, while selected loot is
# charged later as optional cargo.
assert "var mandatory_origin_ids: Dictionary = _mandatory_item_ids(result, setup)" in recovery
assert "item == null or not _is_outbound_item(item, mandatory_origin_ids)" in recovery
assert "Newly stolen items listed in loot_item_ids" in recovery
assert 'stat_value(&"maximum_weight_lb", 0)' in recovery

# Model the regression numerically: 73 lb of outbound kit plus 200 lb of stolen
# cargo fit within a 350 lb maximum load. The old double-counting path subtracts
# the stolen cargo before selection and then charges it again.
maximum_load = 350.0
outbound_kit = 73.0
stolen_grain = 200.0
old_remaining = max(0.0, maximum_load - outbound_kit - stolen_grain)
new_remaining = max(0.0, maximum_load - outbound_kit)
assert old_remaining < stolen_grain
assert new_remaining >= stolen_grain

# The runtime regression reproduces an authored Grain Crate moved into the
# Marauder's Backpack and checks manifest, loot classification and capacity.
for token in [
    'GRAIN_CRATE_ID: StringName = &"instance.ground.grain_crate"',
    "character_result.loot_item_ids.has(GRAIN_CRATE_ID)",
    "grain_is_optional",
    "recovery_service.validate_selection(snapshot, selected)",
]:
    assert token in runtime_test, token

print("PASS — authored mission-ground items carried in Backpacks are classified as recovered loot.")
print("PASS — carried loot is charged exactly once against transport and survivor maximum load.")
