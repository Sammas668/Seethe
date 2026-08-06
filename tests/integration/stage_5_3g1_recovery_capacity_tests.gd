class_name Stage53G1RecoveryCapacityTests
extends RefCounted

const EXTRACTION_ZONE_ID: StringName = &"extraction.player.start"
const GRAIN_CRATE_ID: StringName = &"instance.ground.grain_crate"
const BULK_GRAIN_ID: StringName = &"instance.test.recovery_bulk_grain"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_recovery_uses_remaining_maximum_load(failures)
	return failures


static func _test_recovery_uses_remaining_maximum_load(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var grain: TacticalItemInstanceState = state.get_item(GRAIN_CRATE_ID)
	_expect(marauder != null, "The recovery-capacity fixture has no Marauder.", failures)
	_expect(grain != null, "The recovery-capacity fixture has no Grain Crate.", failures)
	if marauder == null or grain == null:
		return

	grain.location = TacticalItemLocationState.unit_grid(
		marauder.unit_id,
		TacticalInventoryState.KIND_BACKPACK,
		Vector2i(3, 2)
	)
	state.rebuild_ground_item_index()
	var manifest: TacticalExtractionManifest = session.screen_facade.preview_extraction_manifest(
		EXTRACTION_ZONE_ID
	)
	var result: MissionResult = MissionResultBuilder.build_extraction_result(
		&"result.stage_5_3g1.recovery_capacity",
		session.mission_setup,
		state,
		manifest
	)
	var authority: MissionAuthoritySnapshot = MissionAuthoritySnapshot.from_tactical_state(
		state,
		session.mission_setup
	)
	var envelope := MissionCommitEnvelope.new(session.mission_setup, result, authority)
	var recovery_service := MissionRecoverySelectionService.new()
	recovery_service.configure(session.content_catalogue)
	var walking: Dictionary = {
		"display_name": "Walking",
		"is_walking": true,
		"total_cargo_capacity_lb": 0.0,
		"total_captive_capacity": 0,
		"total_cage_anchor_capacity": 0,
		"total_monster_capacity": 0,
		"total_siege_anchor_capacity": 0,
		"total_oversized_cargo_capacity": 0,
	}
	var campaign: CampaignState = session.screen_facade.current_campaign()
	var snapshot: Dictionary = recovery_service.build_snapshot(
		envelope,
		walking,
		campaign
	)
	var contributors: Array = snapshot.get("contributing_survivors", []) as Array
	_expect(not contributors.is_empty(), "No conscious extracting survivor contributed recovery capacity.", failures)
	var expected_maximum_remaining: float = 0.0
	var obsolete_light_remaining: float = 0.0
	for raw_contributor: Variant in contributors:
		if not raw_contributor is Dictionary:
			continue
		var contributor: Dictionary = raw_contributor as Dictionary
		var maximum_load: float = float(contributor.get("maximum_load_lb", 0.0))
		var light_limit: float = float(contributor.get("light_load_limit_lb", 0.0))
		var mandatory: float = float(contributor.get("mandatory_carried_lb", 0.0))
		expected_maximum_remaining += maxf(0.0, maximum_load - mandatory)
		obsolete_light_remaining += maxf(0.0, light_limit - mandatory)
	var personal_capacity: float = float(
		snapshot.get("personal_remaining_carry_capacity_lb", 0.0)
	)
	_expect(
		is_equal_approx(personal_capacity, expected_maximum_remaining),
		"Recovery capacity did not equal survivors' remaining maximum loads.",
		failures
	)
	_expect(
		personal_capacity > obsolete_light_remaining + 0.001,
		"Recovery still appears capped at unused Light Load instead of maximum load.",
		failures
	)

	var grain_definition: ItemDefinition = session.content_catalogue.item_definition(
		&"item.grain_crate"
	)
	_expect(grain_definition != null, "The Grain Crate item definition is missing.", failures)
	if grain_definition == null or grain_definition.weight_lb <= 0.0:
		return
	var minimum_quantity: int = int(floor(obsolete_light_remaining / grain_definition.weight_lb)) + 1
	var maximum_quantity: int = int(floor(personal_capacity / grain_definition.weight_lb))
	_expect(
		maximum_quantity >= minimum_quantity,
		"The fixture cannot construct cargo above Light Load but within maximum load.",
		failures
	)
	if maximum_quantity < minimum_quantity:
		return
	var character_result: MissionCharacterResult = result.get_character_result(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_expect(character_result != null, "The Marauder has no mission result.", failures)
	if character_result == null:
		return
	var bulk_grain := CampaignItemState.new(
		BULK_GRAIN_ID,
		&"item.grain_crate",
		minimum_quantity,
		1.0,
		CampaignItemLocationState.character_slot(
			TacticalSandboxFactory.MARAUDER_ID,
			CampaignItemLocationState.CONTAINER_BACKPACK,
			Vector2i(0, 0)
		)
	)
	result.extracted_item_entries.append(bulk_grain.to_dictionary())
	character_result.equipment_item_ids.append(BULK_GRAIN_ID)
	character_result.loot_item_ids.append(BULK_GRAIN_ID)
	envelope = MissionCommitEnvelope.new(session.mission_setup, result, authority)
	snapshot = recovery_service.build_snapshot(envelope, walking, campaign)
	var selected: Array[StringName] = [BULK_GRAIN_ID]
	var selected_weight: float = recovery_service.selected_weight(snapshot, selected)
	_expect(
		selected_weight > obsolete_light_remaining + 0.001,
		"The regression cargo did not exceed the obsolete Light Load allowance.",
		failures
	)
	var validation: OperationResult = recovery_service.validate_selection(snapshot, selected)
	_expect(
		validation.success,
		"Cargo above Light Load but within maximum load was rejected: %s" % validation.message,
		failures
	)

	var transport_snapshot: Dictionary = walking.duplicate(true)
	transport_snapshot["display_name"] = "Test Cargo Transport"
	transport_snapshot["is_walking"] = false
	transport_snapshot["id"] = "transport.test_cargo"
	transport_snapshot["assigned_count"] = 1
	transport_snapshot["total_cargo_capacity_lb"] = 300.0
	var transported: Dictionary = recovery_service.build_snapshot(
		envelope,
		transport_snapshot,
		campaign
	)
	_expect(
		is_equal_approx(float(transported.get("gross_recovery_capacity_lb", 0.0)), 300.0),
		"Dedicated transport cargo should be the complete gross recovery allowance.",
		failures
	)
	_expect(
		is_zero_approx(float(transported.get("personal_remaining_carry_capacity_lb", -1.0))),
		"Survivor carrying capacity should not be added when dedicated transport carries the squad.",
		failures
	)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
