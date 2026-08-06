class_name Stage53G2TransportRecoveryTests
extends RefCounted

const EXTRACTION_ZONE_ID: StringName = &"extraction.player.start"
const GRAIN_CRATE_ID: StringName = &"instance.ground.grain_crate"
const TEST_BULK_ID: StringName = &"instance.test.transport_only_bulk"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_transport_replaces_personal_recovery_capacity(failures)
	return failures


static func _test_transport_replaces_personal_recovery_capacity(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var grain: TacticalItemInstanceState = state.get_item(GRAIN_CRATE_ID)
	_expect(marauder != null, "The transport-recovery fixture has no Marauder.", failures)
	_expect(grain != null, "The transport-recovery fixture has no Grain Crate.", failures)
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
		&"result.stage_5_3g2.transport_recovery",
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
	var campaign: CampaignState = session.screen_facade.current_campaign()

	var walking: Dictionary = {
		"id": "transport.walking",
		"display_name": "Walking Expedition",
		"is_walking": true,
		"assigned_count": 0,
		"total_cargo_capacity_lb": 0.0,
		"total_captive_capacity": 0,
		"total_cage_anchor_capacity": 0,
		"total_monster_capacity": 0,
		"total_siege_anchor_capacity": 0,
		"total_oversized_cargo_capacity": 0,
	}
	var walking_snapshot: Dictionary = recovery_service.build_snapshot(
		envelope,
		walking,
		campaign
	)
	var walking_personal: float = float(
		walking_snapshot.get("personal_remaining_carry_capacity_lb", 0.0)
	)
	_expect(
		walking_personal > 0.0,
		"Walking no longer uses conscious survivors' remaining maximum load.",
		failures
	)
	_expect(
		is_equal_approx(
			float(walking_snapshot.get("gross_recovery_capacity_lb", 0.0)),
			walking_personal
		),
		"Walking gross recovery capacity did not equal the survivor pool.",
		failures
	)

	var transport: Dictionary = walking.duplicate(true)
	transport["id"] = "transport.test_wagon"
	transport["display_name"] = "Test Wagon"
	transport["is_walking"] = false
	transport["assigned_count"] = 1
	transport["transport_asset_id"] = "transport.asset.test_wagon"
	transport["total_cargo_capacity_lb"] = 300.0
	var transported: Dictionary = recovery_service.build_snapshot(
		envelope,
		transport,
		campaign
	)
	_expect(
		bool(transported.get("uses_dedicated_transport", false)),
		"The assigned transport was not recognised as dedicated transport.",
		failures
	)
	_expect(
		is_zero_approx(float(transported.get("personal_remaining_carry_capacity_lb", -1.0))),
		"Transport recovery still added troop carrying capacity.",
		failures
	)
	_expect(
		is_equal_approx(float(transported.get("gross_recovery_capacity_lb", 0.0)), 300.0),
		"Transport recovery did not use the exact dedicated cargo rating.",
		failures
	)

	var grain_definition: ItemDefinition = session.content_catalogue.item_definition(
		&"item.grain_crate"
	)
	_expect(grain_definition != null, "The Grain Crate definition is missing.", failures)
	if grain_definition == null or grain_definition.weight_lb <= 0.0:
		return
	var over_capacity_quantity: int = int(floor(300.0 / grain_definition.weight_lb)) + 1
	var character_result: MissionCharacterResult = result.get_character_result(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_expect(character_result != null, "The Marauder has no mission result.", failures)
	if character_result == null:
		return
	var bulk_grain := CampaignItemState.new(
		TEST_BULK_ID,
		&"item.grain_crate",
		over_capacity_quantity,
		1.0,
		CampaignItemLocationState.character_slot(
			TacticalSandboxFactory.MARAUDER_ID,
			CampaignItemLocationState.CONTAINER_BACKPACK,
			Vector2i(0, 0)
		)
	)
	result.extracted_item_entries.append(bulk_grain.to_dictionary())
	character_result.equipment_item_ids.append(TEST_BULK_ID)
	character_result.loot_item_ids.append(TEST_BULK_ID)
	envelope = MissionCommitEnvelope.new(session.mission_setup, result, authority)
	transported = recovery_service.build_snapshot(envelope, transport, campaign)
	var over_capacity: OperationResult = recovery_service.validate_selection(
		transported,
		[TEST_BULK_ID]
	)
	_expect(
		not over_capacity.success and over_capacity.code == &"mission_recovery_over_capacity",
		"Cargo above the transport rating was accepted by adding troop capacity: %s"
		% over_capacity.message,
		failures
	)

	# Recovered members of the deployed squad already have passenger places. They
	# must not also reduce cargo capacity when unconscious or dead and recovered.
	var archer_result: MissionCharacterResult = result.get_character_result(
		TacticalSandboxFactory.ARCHER_ID
	)
	if archer_result != null and archer_result.extracted:
		archer_result.current_hp = 0
		archer_result.nonlethal_damage = maxi(1, archer_result.nonlethal_damage)
		archer_result.survived = true
		envelope = MissionCommitEnvelope.new(session.mission_setup, result, authority)
		var walking_with_casualty: Dictionary = recovery_service.build_snapshot(
			envelope,
			walking,
			campaign
		)
		var transport_with_casualty: Dictionary = recovery_service.build_snapshot(
			envelope,
			transport,
			campaign
		)
		_expect(
			int(walking_with_casualty.get("manual_casualty_count", 0)) >= 1,
			"Walking did not treat an unconscious extracted ally as a manual burden.",
			failures
		)
		_expect(
			int(transport_with_casualty.get("manual_casualty_count", -1)) == 0,
			"A transported squad casualty incorrectly consumed cargo capacity.",
			failures
		)
		_expect(
			int(transport_with_casualty.get("passenger_supported_casualty_count", 0)) >= 1,
			"A transported squad casualty was not assigned to the passenger allowance.",
			failures
		)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
