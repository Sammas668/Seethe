class_name Stage50CampaignShellTests
extends RefCounted

const TEST_SAVE_PATH: String = "user://stage_5_0_campaign_shell_tests.json"
const SUPPLY_A: StringName = &"instance.mission.farm.supply_crate_a"
const SUPPLY_B: StringName = &"instance.mission.farm.supply_crate_b"


static func run() -> Array[String]:
	var failures: Array[String] = []
	var campaign_session := CampaignSession.new()
	campaign_session.configure(TEST_SAVE_PATH)
	campaign_session.repository.clear_save()

	var created: OperationResult = campaign_session.create_new_campaign(5000)
	_expect(created.success, "New Campaign failed: %s" % created.message, failures)
	var campaign: CampaignState = campaign_session.current_campaign()
	_expect(campaign != null, "New Campaign did not bind an authoritative campaign root.", failures)
	if campaign == null:
		campaign_session.repository.clear_save()
		return failures
	_expect(campaign.campaign_tick == 480, "Starter strategic time was not 08:00 on Day 1.", failures)
	_expect(campaign.get_characters().size() == 3, "Starter campaign did not create the three persistent characters.", failures)
	_expect(campaign.resources.food == 80, "Starter resources were not stored in CampaignState.", failures)

	var initial_data: Dictionary = campaign.to_dictionary()
	var loaded: OperationResult = campaign_session.load_campaign()
	_expect(loaded.success, "Load Campaign failed: %s" % loaded.message, failures)
	_expect(
		campaign_session.current_campaign().to_dictionary() == initial_data,
		"Save/load did not reproduce the same authoritative CampaignState.",
		failures
	)

	campaign = campaign_session.current_campaign()
	_expect(
		campaign.first_actionable_mission() == null,
		"The Farm Raid should remain hidden until Agent discovery.",
		failures
	)
	var agent: AgentState = campaign_session.primary_agent()
	_expect(agent != null, "New Campaign did not create the starter Agent.", failures)
	if agent == null:
		campaign_session.repository.clear_save()
		return failures
	var dispatched: OperationResult = campaign_session.dispatch_agent(
		RegionHexCoord.from_offset(10, 10)
	)
	_expect(dispatched.success, "Agent dispatch failed: %s" % dispatched.message, failures)
	campaign_session.set_clock_speed(StrategicClockService.SPEED_VERY_FAST)
	var arrival_advance: OperationResult = campaign_session.process_strategic_time(300.0)
	_expect(arrival_advance.success, "Agent travel time failed to advance.", failures)
	var discovery_advance: OperationResult = campaign_session.process_strategic_time(100.0)
	_expect(discovery_advance.success, "Agent discovery time failed to advance.", failures)
	campaign = campaign_session.current_campaign()
	var mission: ActiveMissionState = campaign.first_actionable_mission()
	_expect(mission != null, "The Agent did not discover the authored Farm Raid.", failures)
	if mission == null:
		campaign_session.repository.clear_save()
		return failures
	var definition: MissionDefinition = MissionDefinitionRegistry.definition(mission.mission_definition_id)
	_expect(definition != null, "The active Farm Raid definition is missing.", failures)
	if definition == null:
		campaign_session.repository.clear_save()
		return failures

	var assembled: OperationResult = campaign_session.register_mission_and_create_session(
		mission.mission_instance_id,
		definition.player_character_ids
	)
	_expect(assembled.success, "Mission registration failed: %s" % assembled.message, failures)
	var tactical_session: TacticalSession = assembled.data as TacticalSession
	_expect(tactical_session != null, "Registered mission did not create a TacticalSession.", failures)
	mission = campaign_session.current_campaign().get_active_mission(mission.mission_instance_id)
	_expect(mission != null and mission.is_registered(), "Mission registration was not persisted.", failures)
	if mission != null:
		var setup: MissionSetupSnapshot = mission.setup_snapshot()
		_expect(setup != null and setup.verify_integrity(), "Registered setup failed integrity verification.", failures)
		_expect(setup != null and setup.mission_seed == mission.mission_seed, "Registered mission seed was not preserved.", failures)
		_expect(
			setup != null and setup.source_campaign_revision == campaign_session.current_campaign().revision,
			"Registered setup source revision does not match the post-registration campaign revision.",
			failures
		)

	if tactical_session != null:
		_test_exact_once_result_commit(campaign_session, tactical_session, failures)

	campaign_session.repository.clear_save()
	return failures


static func _test_exact_once_result_commit(
		campaign_session: CampaignSession,
		tactical_session: TacticalSession,
		failures: Array[String]
) -> void:
	var zones: Array[TacticalExtractionZoneDefinition] = tactical_session.mission_setup.extraction_zones()
	if zones.is_empty() or zones[0].tile_coordinates.is_empty():
		failures.append("Farm Raid has no extraction tile for the campaign-loop test.")
		return
	var zone: TacticalExtractionZoneDefinition = zones[0]
	var state: TacticalState = tactical_session.state_store.state
	var protagonist_id: StringName = tactical_session.mission_setup.protagonist_character_id
	var protagonist: TacticalUnitState = state.get_unit(protagonist_id)
	var extraction_tile: Vector2i = zone.tile_coordinates[0]
	var found_legal_tile := false
	for candidate: Vector2i in zone.tile_coordinates:
		if state.can_place_unit(protagonist, candidate, tactical_session.map_definition, protagonist_id):
			extraction_tile = candidate
			found_legal_tile = true
			break
	_expect(found_legal_tile, "The Farm Raid extraction zone has no legal protagonist tile.", failures)
	if not found_legal_tile:
		return
	_expect(
		state.move_item(SUPPLY_A, TacticalItemLocationState.ground(extraction_tile, "Stage 5.0 test"), false),
		"First authored supply could not enter the extraction zone.",
		failures
	)
	_expect(
		state.move_item(SUPPLY_B, TacticalItemLocationState.ground(extraction_tile, "Stage 5.0 test"), false),
		"Second authored supply could not enter the extraction zone.",
		failures
	)
	_expect(
		state.set_unit_position(protagonist_id, extraction_tile, tactical_session.map_definition, false),
		"The protagonist could not enter the extraction zone.",
		failures
	)
	state.rebuild_ground_item_index()
	state.rebuild_unit_occupancy()
	var reconciled: OperationResult = tactical_session.mission_objective_service.reconcile_now()
	_expect(reconciled.success, "Farm Raid objective reconciliation failed.", failures)
	var manifest: TacticalExtractionManifest = tactical_session.screen_facade.preview_extraction_manifest(zone.zone_id)
	_expect(manifest.required_objectives_complete, "Recovered supplies did not complete the Farm Raid objective.", failures)
	_expect(manifest.extraction_is_legal, "The completed Farm Raid extraction was not legal.", failures)
	if not manifest.extraction_is_legal:
		return
	var resolved: OperationResult = tactical_session.screen_facade.resolve_tactical_mission(
		zone.zone_id,
		manifest.source_tactical_revision
	)
	_expect(resolved.success, "Tactical result resolution failed: %s" % resolved.message, failures)
	var envelope: MissionCommitEnvelope = tactical_session.screen_facade.pending_commit_envelope()
	_expect(envelope != null, "Tactical resolution returned no immutable campaign handoff.", failures)
	if envelope == null:
		return
	var first_commit: OperationResult = campaign_session.commit_tactical_envelope(envelope)
	_expect(first_commit.success, "First campaign result commit failed: %s" % first_commit.message, failures)
	var revision_after_first: int = campaign_session.current_campaign().revision
	var repeat_commit: OperationResult = campaign_session.commit_tactical_envelope(envelope)
	_expect(repeat_commit.success, "Repeated result commit was not idempotent.", failures)
	_expect(
		campaign_session.current_campaign().revision == revision_after_first,
		"Repeated result commit changed campaign revision.",
		failures
	)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
