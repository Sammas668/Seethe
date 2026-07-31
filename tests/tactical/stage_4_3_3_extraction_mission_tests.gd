class_name Stage433ExtractionMissionTests
extends RefCounted

const ZONE_ID: StringName = &"extraction.player.start"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_authored_zone_and_withdrawal_manifest(failures)
	_test_ground_items_in_zone_are_withdrawn(failures)
	_test_conscious_unrestrained_enemy_is_not_withdrawn(failures)
	_test_body_and_dragged_body_physical_extraction(failures)
	_test_restrained_enemy_becomes_captive(failures)
	_test_tactical_defeat_does_not_auto_rescue_zone_bodies(failures)
	_test_victory_result_commits_exactly_once(failures)
	_test_campaign_defeat_does_not_commit_safe_campaign(failures)
	return failures


static func _test_authored_zone_and_withdrawal_manifest(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var setup: MissionSetupSnapshot = session.mission_setup
	var state: TacticalState = session.state_store.state
	var zone: TacticalExtractionZoneDefinition = setup.extraction_zone(ZONE_ID)
	_expect(zone != null, "The sandbox mission must load its authored extraction zone.", failures)
	_expect(
		state.extraction_zone_state(ZONE_ID) != null,
		"TacticalState must own mutable state for the authored extraction zone.",
		failures
	)
	var manifest: TacticalExtractionManifest = session.screen_facade.preview_extraction_manifest(
		ZONE_ID
	)
	_expect(manifest.extraction_is_legal, "The deployed squad should have a legal initial extraction manifest.", failures)
	_expect(
		manifest.mission_outcome == MissionOutcome.WITHDRAWAL,
		"Leaving before the objective is complete must preview Withdrawal.",
		failures
	)
	_expect(manifest.protagonist_extracted, "The protagonist begins physically inside the extraction zone.", failures)
	_expect(
		manifest.extracted_friendly_unit_ids.size() == 3,
		"All three deployed player characters begin in the authored zone.",
		failures
	)


static func _test_ground_items_in_zone_are_withdrawn(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var manifest: TacticalExtractionManifest = (
		session.screen_facade.preview_extraction_manifest(ZONE_ID)
	)
	for item_id: StringName in [
		&"instance.ground.spear",
		&"instance.ground.grain_crate",
		&"instance.ground.bandages",
		&"instance.ground.healing_potion",
	]:
		_expect(
			manifest.extracted_item_ids.has(item_id),
			"A loose item physically inside the withdrawal zone must be extracted: %s."
			% item_id,
			failures
		)


static func _test_conscious_unrestrained_enemy_is_not_withdrawn(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var enemy: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	if actor == null or enemy == null:
		failures.append("The hostile-withdrawal fixture needs the Marauder and first guard.")
		return

	# Exercise the important edge case: a body item can remain authoritative
	# after healing while it is still packed. A conscious, unrestrained enemy
	# must not be swept into the withdrawal merely because the item is inside an
	# extracting character's Backpack.
	enemy.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	var body: TacticalItemInstanceState = state.body_item_for_unit(enemy.unit_id)
	if body == null:
		failures.append("The hostile-withdrawal fixture could not create its body item.")
		return
	body.location = TacticalItemLocationState.unit_grid(
		actor.unit_id,
		TacticalInventoryState.KIND_BACKPACK,
		Vector2i.ZERO
	)
	enemy.restore_damage_state(enemy.maximum_hp, 0)
	enemy.set_awaiting_body_placement(true)
	state.rebuild_ground_item_index()

	var manifest: TacticalExtractionManifest = (
		session.screen_facade.preview_extraction_manifest(ZONE_ID)
	)
	_expect(
		not manifest.recovered_enemy_body_item_ids.has(body.item_id),
		"A conscious, unrestrained enemy must not be brought through withdrawal.",
		failures
	)
	_expect(
		not manifest.captured_enemy_unit_ids.has(enemy.unit_id),
		"A conscious, unrestrained enemy must not become a captive result.",
		failures
	)


static func _test_body_and_dragged_body_physical_extraction(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var target: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	if actor == null or target == null:
		failures.append("The physical extraction fixture needs the Marauder and first guard.")
		return
	state.set_unit_position(target.unit_id, Vector2i(3, 3), session.map_definition, false)
	target.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	var body: TacticalItemInstanceState = state.body_item_for_unit(target.unit_id)
	if body == null:
		failures.append("The physical extraction fixture could not create a body item.")
		return

	body.location = TacticalItemLocationState.unit_grid(
		actor.unit_id,
		TacticalInventoryState.KIND_BACKPACK,
		Vector2i.ZERO
	)
	state.rebuild_ground_item_index()
	var carried_manifest: TacticalExtractionManifest = (
		session.screen_facade.preview_extraction_manifest(ZONE_ID)
	)
	_expect(
		carried_manifest.recovered_enemy_body_item_ids.has(body.item_id),
		"A body packed in an extracted character's Backpack must be physically extracted.",
		failures
	)

	body.location = TacticalItemLocationState.dragged_body(
		actor.unit_id,
		TacticalInventoryState.KIND_PRIMARY_HAND,
		Vector2i(7, 2)
	)
	target.grid_position = Vector2i(7, 2)
	state.rebuild_ground_item_index()
	var dragged_manifest: TacticalExtractionManifest = (
		session.screen_facade.preview_extraction_manifest(ZONE_ID)
	)
	_expect(
		not dragged_manifest.recovered_enemy_body_item_ids.has(body.item_id),
		"A dragged body outside the zone must not extract merely because its dragger is inside.",
		failures
	)


static func _test_restrained_enemy_becomes_captive(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var target: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	if actor == null or target == null:
		failures.append("The captive fixture needs the Marauder and first guard.")
		return
	state.set_unit_position(target.unit_id, Vector2i(3, 3), session.map_definition, false)
	target.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	var body: TacticalItemInstanceState = state.body_item_for_unit(target.unit_id)
	var rope: TacticalItemInstanceState = _find_restraint_owned_by(state, actor.unit_id)
	if body == null or rope == null:
		failures.append("The captive fixture needs one body and one owned rope item.")
		return
	actor.refresh_for_new_round()
	var restrained: OperationResult = session.body_action_handler.apply_item_to_body(
		actor.unit_id, rope.item_id, body.item_id
	)
	_expect(restrained.success, "Dragging rope onto the helpless guard must restrain it.", failures)
	var manifest: TacticalExtractionManifest = session.screen_facade.preview_extraction_manifest(
		ZONE_ID
	)
	_expect(
		manifest.captured_enemy_unit_ids.has(target.unit_id),
		"A restrained living enemy body in the zone must enter the captive manifest.",
		failures
	)
	_expect(
		manifest.extracted_item_ids.has(rope.item_id),
		"The real attached restraint item must be part of extraction.",
		failures
	)


static func _test_tactical_defeat_does_not_auto_rescue_zone_bodies(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	for player: TacticalUnitState in state.get_player_units():
		if player != null:
			player.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	state.rebuild_unit_occupancy()
	state.rebuild_ground_item_index()
	var manifest: TacticalExtractionManifest = (
		session.screen_facade.preview_extraction_manifest(ZONE_ID)
	)
	_expect(
		manifest.mission_outcome == MissionOutcome.DEFEAT,
		"A fully incapacitated player force must produce Tactical Defeat.",
		failures
	)
	_expect(
		manifest.extracted_friendly_body_item_ids.is_empty(),
		"Tactical Defeat must not automatically rescue bodies merely lying in the zone.",
		failures
	)
	_expect(
		manifest.extracted_item_ids.is_empty(),
		"Tactical Defeat must not automatically recover zone loot without a conscious extractor.",
		failures
	)
	_expect(
		manifest.abandoned_friendly_body_item_ids.size() == 3,
		"All three player bodies must remain explicitly unrecovered after a wipe.",
		failures
	)


static func _test_victory_result_commits_exactly_once(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	for enemy: TacticalUnitState in state.get_enemy_units():
		if enemy == null or not enemy.counts_for_victory:
			continue
		enemy.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	state.rebuild_unit_occupancy()
	state.rebuild_ground_item_index()

	var manifest: TacticalExtractionManifest = session.screen_facade.preview_extraction_manifest(
		ZONE_ID
	)
	_expect(manifest.required_objectives_complete, "Neutralising the defending force must complete the objective.", failures)
	_expect(manifest.mission_outcome == MissionOutcome.VICTORY, "The extraction preview must become Victory.", failures)

	var resolved: OperationResult = session.screen_facade.resolve_tactical_mission(ZONE_ID)
	_expect(resolved.success, "A legal victory manifest must commit successfully.", failures)
	var result: MissionResult = resolved.data as MissionResult
	if result == null:
		failures.append("Mission resolution returned no MissionResult.")
		return
	_expect(result.mission_outcome == MissionOutcome.VICTORY, "The committed result must preserve Victory.", failures)
	_expect(
		int(result.mission_statistics.get("enemies_killed", 0)) == 2,
		"The committed summary must count the two victory-relevant enemies killed.",
		failures
	)
	_expect(state.mission_resolution_locked, "Successful resolution must lock all further tactical commands.", failures)
	var campaign: CampaignState = session.screen_facade.current_campaign()
	_expect(
		campaign != null and campaign.has_resolved_mission(session.mission_setup.mission_id),
		"The campaign must record the mission ID after the atomic commit.",
		failures
	)
	var revision_after_first: int = campaign.revision if campaign != null else -1
	var service := CampaignResultCommitService.new()
	service.configure(session.campaign_store, session.content_catalogue)
	var repeated: OperationResult = service.commit_result(
		result, session.mission_setup, session.content_catalogue
	)
	_expect(repeated.success, "Reapplying an already committed result must be an idempotent success.", failures)
	var campaign_after: CampaignState = session.screen_facade.current_campaign()
	_expect(
		campaign_after != null and campaign_after.revision == revision_after_first,
		"An idempotent repeated result must not advance campaign revision or duplicate outcomes.",
		failures
	)


static func _test_campaign_defeat_does_not_commit_safe_campaign(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var protagonist: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	if protagonist == null:
		failures.append("The campaign-defeat fixture needs its protagonist.")
		return
	var campaign_before: CampaignState = session.screen_facade.current_campaign()
	var revision_before: int = campaign_before.revision if campaign_before != null else -1
	protagonist.restore_damage_state(protagonist.death_threshold_hp(), 0)
	session.state_store.state.synchronise_body_items(session.map_definition)
	var resolved: OperationResult = session.screen_facade.resolve_tactical_mission(ZONE_ID)
	_expect(resolved.success, "Actual protagonist death must resolve Campaign Defeat.", failures)
	var result: MissionResult = resolved.data as MissionResult
	_expect(
		result != null and result.mission_outcome == MissionOutcome.CAMPAIGN_DEFEAT,
		"Protagonist death must produce the explicit Campaign Defeat outcome.",
		failures
	)
	var campaign_after: CampaignState = session.screen_facade.current_campaign()
	_expect(
		campaign_after != null and campaign_after.revision == revision_before,
		"Campaign Defeat must not overwrite the last safe campaign save.",
		failures
	)


static func _find_restraint_owned_by(
		state: TacticalState,
		owner_id: StringName
) -> TacticalItemInstanceState:
	for item: TacticalItemInstanceState in state.get_items():
		if (
			item != null
			and item.definition != null
			and item.definition.is_restraint
			and item.location != null
			and item.location.owner_id == owner_id
		):
			return item
	return null


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
