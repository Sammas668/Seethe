class_name Stage433CMissionLoopStabilisationTests
extends RefCounted

const ZONE_ID: StringName = &"extraction.player.start"
const TEST_SAVE_PATH: String = "user://seethe_stage_4_3_3c_e2e_test.json"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_startup_map_visibility_and_tokens(failures)
	_test_manifest_integrity_and_stale_preview_guard(failures)
	_test_carried_and_dragged_friendly_bodies_build_results(failures)
	_test_unconscious_dead_and_restrained_enemy_semantics(failures)
	_test_defeat_result_recovers_no_property(failures)
	_test_withdrawal_end_to_end_persists_once(failures)
	return failures


static func _test_startup_map_visibility_and_tokens(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	_expect(
		session.map_definition != null
		and session.map_definition.grid_size.x > 0
		and session.map_definition.grid_size.y > 0,
		"The stabilised sandbox must retain its authored tactical map.",
		failures
	)
	_expect(
		state.get_units().size() == 7,
		"All seven authored sandbox characters must deploy before presentation begins.",
		failures
	)
	_expect(
		state.extraction_zone_state(ZONE_ID) != null,
		"The extraction-zone registry must exist before deployed characters validate.",
		failures
	)
	_expect(
		session.screen_facade.visible_tile_count_for_player() > 0,
		"Deployed player units must still reveal the tactical map.",
		failures
	)

	var enemy: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	if enemy == null:
		failures.append("The token regression fixture needs the first guard.")
		return
	enemy.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	var body: TacticalItemInstanceState = state.body_item_for_unit(enemy.unit_id)
	_expect(body != null, "Downing the guard must still create its linked body item.", failures)
	_expect(
		body != null and state.should_body_token_be_visible(body),
		"A body on tactical ground must retain its fallen map token.",
		failures
	)


static func _test_manifest_integrity_and_stale_preview_guard(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var preview: TacticalExtractionManifest = (
		session.screen_facade.preview_extraction_manifest(ZONE_ID)
	)
	_expect(
		preview.source_tactical_revision == state.revision,
		"Every extraction preview must identify the exact tactical revision it represents.",
		failures
	)
	_expect(
		TacticalExtractionManifestValidator.validate(preview, state).is_empty(),
		"A normal withdrawal preview must pass manifest-integrity validation.",
		failures
	)

	state.set_extraction_zone_contested(ZONE_ID, true)
	var stale: OperationResult = session.screen_facade.resolve_tactical_mission(
		ZONE_ID, preview.source_tactical_revision
	)
	_expect(
		not stale.success and stale.code == &"extraction_preview_stale",
		"Confirmation must reject a preview after any tactical revision change.",
		failures
	)
	var refreshed: TacticalExtractionManifest = (
		session.screen_facade.preview_extraction_manifest(ZONE_ID)
	)
	_expect(
		refreshed.source_tactical_revision == state.revision,
		"Refreshing the extraction UI must rebuild from the latest tactical revision.",
		failures
	)
	_expect(
		not refreshed.extraction_is_legal,
		"The refreshed manifest must immediately show a contested route as blocked.",
		failures
	)


static func _test_carried_and_dragged_friendly_bodies_build_results(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var carrier: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var carried_unit: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var dragged_unit: TacticalUnitState = state.get_unit(TacticalSandboxFactory.SCOUT_ID)
	if carrier == null or carried_unit == null or dragged_unit == null:
		failures.append("The body-transport result fixture needs all three player characters.")
		return

	_clear_actor_inventory_to_ground(state, carrier)
	carrier.inventory.maximum_weight_lb = 600.0
	state.set_unit_position(
		carried_unit.unit_id, Vector2i(2, 3), session.map_definition, false
	)
	state.set_unit_position(
		dragged_unit.unit_id, Vector2i(3, 3), session.map_definition, false
	)
	carried_unit.restore_damage_state(-1, 0)
	dragged_unit.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	state.rebuild_unit_occupancy()
	state.rebuild_ground_item_index()
	var carried_body: TacticalItemInstanceState = state.body_item_for_unit(
		carried_unit.unit_id
	)
	var dragged_body: TacticalItemInstanceState = state.body_item_for_unit(
		dragged_unit.unit_id
	)
	if carried_body == null or dragged_body == null:
		failures.append("The body-transport result fixture could not create both bodies.")
		return

	carrier.refresh_for_new_round()
	var carry_result: OperationResult = session.inventory_transfer_handler.execute(
		TacticalInventoryTransferCommand.new(
			carrier.unit_id,
			TacticalItemLocationState.CONTAINER_GROUND,
			carried_body.item_id,
			TacticalInventoryState.KIND_BACKPACK,
			0
		)
	)
	_expect(
		carry_result.success,
		"The result fixture must carry the first body through a real Backpack transfer.",
		failures
	)
	carrier.refresh_for_new_round()
	var drag_result: OperationResult = session.inventory_transfer_handler.execute(
		TacticalInventoryTransferCommand.new(
			carrier.unit_id,
			TacticalItemLocationState.CONTAINER_GROUND,
			dragged_body.item_id,
			TacticalInventoryState.KIND_PRIMARY_HAND,
			-1
		)
	)
	_expect(
		drag_result.success,
		"The result fixture must drag the second body through a real Hand transfer.",
		failures
	)
	if not carry_result.success or not drag_result.success:
		return

	var manifest: TacticalExtractionManifest = (
		session.screen_facade.preview_extraction_manifest(ZONE_ID)
	)
	_expect(
		manifest.extracted_friendly_body_item_ids.has(carried_body.item_id),
		"A friendly body packed in an extracted Backpack must enter the manifest.",
		failures
	)
	_expect(
		manifest.extracted_friendly_body_item_ids.has(dragged_body.item_id),
		"A friendly dragged body whose actual ground cell is in-zone must enter the manifest.",
		failures
	)

	var result: MissionResult = MissionResultBuilder.build_extraction_result(
		&"result.test.stage_4_3_3c.body_transport",
		session.mission_setup,
		state,
		manifest
	)
	var carried_result: MissionCharacterResult = result.get_character_result(
		carried_unit.unit_id
	)
	var dragged_result: MissionCharacterResult = result.get_character_result(
		dragged_unit.unit_id
	)
	_expect(
		carried_result != null
		and carried_result.extracted
		and carried_result.body_recovered
		and carried_result.outcome_state
		== MissionCharacterResult.OUTCOME_EXTRACTED_CRITICAL,
		"A carried unconscious ally must become an extracted critical casualty.",
		failures
	)
	_expect(
		dragged_result != null
		and dragged_result.extracted
		and dragged_result.body_recovered
		and dragged_result.outcome_state
		== MissionCharacterResult.OUTCOME_EXTRACTED_CRITICAL,
		"A dragged unconscious ally must become an extracted critical casualty.",
		failures
	)


static func _test_unconscious_dead_and_restrained_enemy_semantics(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var unconscious_enemy: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var dead_enemy: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_TWO_ID)
	if actor == null or unconscious_enemy == null or dead_enemy == null:
		failures.append("The hostile outcome fixture needs the Marauder and both guards.")
		return

	state.set_unit_position(
		unconscious_enemy.unit_id, Vector2i(3, 3), session.map_definition, false
	)
	state.set_unit_position(
		dead_enemy.unit_id, Vector2i(4, 3), session.map_definition, false
	)
	unconscious_enemy.restore_damage_state(-1, 0)
	dead_enemy.restore_damage_state(dead_enemy.death_threshold_hp(), 0)
	state.synchronise_body_items(session.map_definition)
	state.rebuild_unit_occupancy()
	state.rebuild_ground_item_index()

	var unsecured_manifest: TacticalExtractionManifest = (
		session.screen_facade.preview_extraction_manifest(ZONE_ID)
	)
	_expect(
		unsecured_manifest.unsecured_enemy_unit_ids.has(unconscious_enemy.unit_id),
		"An unconscious but unrestrained enemy may be recovered but is not a Captive.",
		failures
	)
	_expect(
		not unsecured_manifest.captured_enemy_unit_ids.has(unconscious_enemy.unit_id),
		"Unconsciousness alone must never create a captive result.",
		failures
	)
	_expect(
		unsecured_manifest.recovered_enemy_body_item_ids.has(
			state.body_item_for_unit(dead_enemy.unit_id).item_id
		),
		"A dead enemy body deliberately moved into extraction remains corpse recovery.",
		failures
	)
	_expect(
		not unsecured_manifest.captured_enemy_unit_ids.has(dead_enemy.unit_id),
		"A dead enemy body must never become a living Captive.",
		failures
	)

	var rope: TacticalItemInstanceState = _find_restraint_owned_by(
		state, actor.unit_id
	)
	var unconscious_body: TacticalItemInstanceState = state.body_item_for_unit(
		unconscious_enemy.unit_id
	)
	if rope == null or unconscious_body == null:
		failures.append("The hostile outcome fixture needs a rope and unconscious body.")
		return
	actor.refresh_for_new_round()
	var restrained: OperationResult = session.body_action_handler.apply_item_to_body(
		actor.unit_id, rope.item_id, unconscious_body.item_id
	)
	_expect(restrained.success, "The unconscious enemy must be restrainable.", failures)
	var captive_manifest: TacticalExtractionManifest = (
		session.screen_facade.preview_extraction_manifest(ZONE_ID)
	)
	_expect(
		captive_manifest.captured_enemy_unit_ids.has(unconscious_enemy.unit_id),
		"Only the restrained living enemy must become a Captive.",
		failures
	)


static func _test_defeat_result_recovers_no_property(
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
	var result: MissionResult = MissionResultBuilder.build_extraction_result(
		&"result.test.stage_4_3_3c.defeat",
		session.mission_setup,
		state,
		manifest
	)
	_expect(
		manifest.mission_outcome == MissionOutcome.DEFEAT,
		"A fully incapacitated squad must still build Tactical Defeat.",
		failures
	)
	_expect(
		result.extracted_item_entries.is_empty(),
		"Tactical Defeat must not recover loose or carried property.",
		failures
	)
	_expect(
		result.get_captive_results().is_empty(),
		"Tactical Defeat must not create captive records.",
		failures
	)


static func _test_withdrawal_end_to_end_persists_once(
		failures: Array[String]
) -> void:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var cleanup_repository := JsonCampaignRepository.new(
		TEST_SAVE_PATH, true, catalogue
	)
	cleanup_repository.clear_save()

	var session: TacticalSession = TacticalSandboxFactory.create_session(
		true, TEST_SAVE_PATH
	)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var enemy: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	if actor == null or enemy == null:
		failures.append("The end-to-end fixture needs the Marauder and first guard.")
		cleanup_repository.clear_save()
		return

	state.set_unit_position(enemy.unit_id, Vector2i(3, 3), session.map_definition, false)
	enemy.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	state.rebuild_unit_occupancy()
	state.rebuild_ground_item_index()
	var body: TacticalItemInstanceState = state.body_item_for_unit(enemy.unit_id)
	var rope: TacticalItemInstanceState = _find_restraint_owned_by(state, actor.unit_id)
	if body == null or rope == null:
		failures.append("The end-to-end fixture needs a body and rope.")
		cleanup_repository.clear_save()
		return

	actor.refresh_for_new_round()
	var restrained: OperationResult = session.body_action_handler.apply_item_to_body(
		actor.unit_id, rope.item_id, body.item_id
	)
	_expect(restrained.success, "The end-to-end fixture must restrain its captive.", failures)
	actor.refresh_for_new_round()
	var searched: OperationResult = session.body_action_handler.search_body(
		actor.unit_id, body.item_id
	)
	_expect(searched.success, "The end-to-end fixture must unload the captive's equipment.", failures)
	var searched_item_ids: Array[StringName] = []
	if searched.data is Array:
		for raw_item: Variant in searched.data as Array:
			var item: TacticalItemInstanceState = raw_item as TacticalItemInstanceState
			if item != null:
				searched_item_ids.append(item.item_id)

	var preview: TacticalExtractionManifest = (
		session.screen_facade.preview_extraction_manifest(ZONE_ID)
	)
	_expect(
		preview.mission_outcome == MissionOutcome.WITHDRAWAL,
		"Leaving one defender active must keep the end-to-end result as Withdrawal.",
		failures
	)
	_expect(
		preview.captured_enemy_unit_ids.has(enemy.unit_id),
		"The restrained enemy must be present in the final withdrawal preview.",
		failures
	)
	for item_id: StringName in searched_item_ids:
		_expect(
			preview.extracted_item_ids.has(item_id),
			"Searched equipment placed on an extraction tile must be recovered: %s."
			% item_id,
			failures
		)

	var pre_resolution_reload: CampaignState = cleanup_repository.load_campaign()
	_expect(
		pre_resolution_reload != null
		and not pre_resolution_reload.has_resolved_mission(
			session.mission_setup.mission_id
		),
		"The safe campaign save immediately before extraction must remain unresolved.",
		failures
	)

	var resolved: OperationResult = session.screen_facade.resolve_tactical_mission(
		ZONE_ID, preview.source_tactical_revision
	)
	_expect(resolved.success, "The end-to-end Withdrawal must commit successfully.", failures)
	var result: MissionResult = resolved.data as MissionResult
	_expect(
		result != null and result.mission_outcome == MissionOutcome.WITHDRAWAL,
		"The committed end-to-end MissionResult must preserve Withdrawal.",
		failures
	)
	_expect(
		result != null
		and result.failed_objective_ids.has(session.mission_setup.primary_objective_id),
		"Withdrawal before completing the primary objective must record that objective as failed.",
		failures
	)
	_expect(
		result != null and result.get_captive_results().size() == 1,
		"The committed end-to-end MissionResult must contain one captive.",
		failures
	)

	var reloaded_repository := JsonCampaignRepository.new(
		TEST_SAVE_PATH, true, catalogue
	)
	var reloaded: CampaignState = reloaded_repository.load_campaign()
	_expect(reloaded != null, "The committed campaign must reload from JSON.", failures)
	if reloaded == null:
		cleanup_repository.clear_save()
		return
	_expect(
		reloaded.has_resolved_mission(session.mission_setup.mission_id),
		"Reloaded campaign history must retain the resolved mission ID.",
		failures
	)
	_expect(
		reloaded.get_captives().size() == 1,
		"Reloaded campaign state must retain the extracted captive.",
		failures
	)
	for item_id: StringName in searched_item_ids:
		_expect(
			reloaded.get_item(item_id) != null,
			"Reloaded campaign state must retain searched extraction loot: %s."
			% item_id,
			failures
		)
	var reloaded_marauder: PersistentCharacterState = reloaded.get_character(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_expect(
		reloaded_marauder != null and reloaded_marauder.deployment_count == 1,
		"Reloaded character progression must record exactly one deployment.",
		failures
	)

	var revision_before_repeat: int = reloaded.revision
	var reloaded_store := CampaignStateStore.new()
	reloaded_store.configure(reloaded, reloaded_repository, catalogue)
	var commit_service := CampaignResultCommitService.new()
	commit_service.configure(reloaded_store, catalogue)
	var repeated: OperationResult = commit_service.commit_result(
		result, session.mission_setup, catalogue
	)
	_expect(
		repeated.success,
		"Reapplying the reloaded MissionResult must be an idempotent success.",
		failures
	)
	_expect(
		reloaded_store.current_campaign().revision == revision_before_repeat,
		"Idempotent reapplication after reload must not duplicate or advance campaign state.",
		failures
	)
	_expect(
		reloaded_store.current_campaign().get_captives().size() == 1,
		"Idempotent reapplication after reload must not duplicate the captive.",
		failures
	)
	cleanup_repository.clear_save()


static func _clear_actor_inventory_to_ground(
		state: TacticalState,
		actor: TacticalUnitState
) -> void:
	for item: TacticalItemInstanceState in state.get_items():
		if item == null or item.location == null:
			continue
		if item.location.owner_id != actor.unit_id:
			continue
		if item.location.location_type not in [
			TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
			TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
		]:
			continue
		item.location = TacticalItemLocationState.ground(
			actor.grid_position, "Stage 4.3.3c test setup"
		)
	state.rebuild_ground_item_index()


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
