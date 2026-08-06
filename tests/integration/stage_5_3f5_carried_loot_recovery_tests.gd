class_name Stage53F5CarriedLootRecoveryTests
extends RefCounted

const GRAIN_CRATE_ID: StringName = &"instance.ground.grain_crate"
const EXTRACTION_ZONE_ID: StringName = &"extraction.player.start"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var grain: TacticalItemInstanceState = state.get_item(GRAIN_CRATE_ID)
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	_expect(grain != null, "The carried-loot fixture has no authored Grain Crate.", failures)
	_expect(marauder != null, "The carried-loot fixture has no Marauder.", failures)
	if grain == null or marauder == null:
		return failures

	# Reproduce the reported mission state: an authored objective item has been
	# moved from the map into an extracting Barbarian's Backpack.
	grain.location = TacticalItemLocationState.unit_grid(
		marauder.unit_id,
		TacticalInventoryState.KIND_BACKPACK,
		Vector2i(3, 2)
	)
	state.rebuild_ground_item_index()

	var manifest: TacticalExtractionManifest = session.screen_facade.preview_extraction_manifest(
		EXTRACTION_ZONE_ID
	)
	_expect(
		manifest.extracted_item_ids.has(GRAIN_CRATE_ID),
		"A Grain Crate in an extracted Barbarian's Backpack was absent from the extraction manifest.",
		failures
	)

	var result: MissionResult = MissionResultBuilder.build_extraction_result(
		&"result.stage_5_3f5.carried_loot",
		session.mission_setup,
		state,
		manifest
	)
	var character_result: MissionCharacterResult = result.get_character_result(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_expect(character_result != null, "The Marauder received no mission character result.", failures)
	if character_result == null:
		return failures
	_expect(
		character_result.equipment_item_ids.has(GRAIN_CRATE_ID),
		"The carried Grain Crate was not retained in the Marauder's post-mission Backpack manifest.",
		failures
	)
	_expect(
		character_result.loot_item_ids.has(GRAIN_CRATE_ID),
		"An authored mission-ground Grain Crate was misclassified as outbound squad equipment.",
		failures
	)

	var authority: MissionAuthoritySnapshot = MissionAuthoritySnapshot.from_tactical_state(
		state,
		session.mission_setup
	)
	var envelope := MissionCommitEnvelope.new(session.mission_setup, result, authority)
	var recovery_service := MissionRecoverySelectionService.new()
	recovery_service.configure(session.content_catalogue)
	var campaign: CampaignState = session.screen_facade.current_campaign()
	var snapshot: Dictionary = recovery_service.build_snapshot(
		envelope,
		{
			"display_name": "Walking",
			"is_walking": true,
			"total_cargo_capacity_lb": 0.0,
			"total_captive_capacity": 0,
			"total_cage_anchor_capacity": 0,
			"total_monster_capacity": 0,
			"total_siege_anchor_capacity": 0,
			"total_oversized_cargo_capacity": 0,
		},
		campaign
	)
	var grain_is_optional: bool = false
	for raw_entry: Variant in snapshot.get("optional_entries", []):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		if StringName(entry.get("item_id", "")) == GRAIN_CRATE_ID:
			grain_is_optional = true
			break
	_expect(
		grain_is_optional,
		"The carried Grain Crate did not appear as selectable recovered loot.",
		failures
	)
	var selected: Array[StringName] = [GRAIN_CRATE_ID]
	var validation: OperationResult = recovery_service.validate_selection(snapshot, selected)
	_expect(
		validation.success,
		"The carried Grain Crate was charged twice against recovery capacity: %s" % validation.message,
		failures
	)
	return failures


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
