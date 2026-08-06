class_name Stage46AuthoredMissionTests
extends RefCounted

const MISSION_ID: StringName = &"mission_definition.life.farm_storehouse_raid_01"
const SUPPLY_A: StringName = &"instance.mission.farm.supply_crate_a"
const SUPPLY_B: StringName = &"instance.mission.farm.supply_crate_b"


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_definition_and_map(failures)
	_test_authored_session_and_setup(failures)
	_test_supply_objective_and_result(failures)
	return failures


static func _test_definition_and_map(failures: Array[String]) -> void:
	var definition := MissionDefinitionRegistry.definition(MISSION_ID)
	_expect(definition != null, "Farm raid definition was not registered.", failures)
	if definition == null:
		return
	var errors: Array[String] = definition.validate_definition()
	_expect(errors.is_empty(), "Farm raid definition is invalid: %s" % (errors[0] if not errors.is_empty() else ""), failures)
	_expect(definition.map_definition.grid_size == Vector2i(40, 40), "Farm raid map dimensions changed.", failures)
	_expect(definition.map_definition.deployment_zones.size() == 1, "Farm raid needs one authored deployment zone.", failures)
	_expect(definition.map_definition.extraction_zones.size() == 1, "Farm raid needs one authored extraction zone.", failures)
	_expect(definition.primary_objectives.size() == 1, "Farm raid needs one primary objective.", failures)
	_expect(definition.optional_objectives.size() == 4, "Farm raid needs four optional objectives.", failures)


static func _test_authored_session_and_setup(failures: Array[String]) -> void:
	var definition := MissionDefinitionRegistry.definition(MISSION_ID)
	if definition == null:
		return
	var session := AuthoredMissionFactory.create_session(definition, [], false, "user://stage_4_6_test_campaign.json")
	_expect(session != null, "Authored mission session could not be created.", failures)
	if session == null:
		return
	_expect(session.mission_setup.verify_integrity(), "Authored mission setup hash failed integrity.", failures)
	_expect(session.mission_setup.mission_definition_id == MISSION_ID, "Mission setup lost its definition identity.", failures)
	_expect(session.mission_setup.tactical_map_definition_id == definition.map_definition.definition_id, "Mission setup lost its map identity.", failures)
	_expect(session.state_store.state.mission_runtime_state != null, "Mission runtime state was not created.", failures)
	_expect(session.state_store.state.get_item(SUPPLY_A) != null, "First authored supply item was not spawned.", failures)
	_expect(session.state_store.state.get_item(SUPPLY_B) != null, "Second authored supply item was not spawned.", failures)
	_test_authored_control_and_placement(session, definition, failures)
	var validation_errors: Array[String] = session.validate_session()
	_expect(validation_errors.is_empty(), "Authored mission session is invalid: %s" % (validation_errors[0] if not validation_errors.is_empty() else ""), failures)


static func _test_authored_control_and_placement(
		session: TacticalSession,
		definition: MissionDefinition,
		failures: Array[String]
) -> void:
	var state: TacticalState = session.state_store.state
	for placement: MissionCharacterPlacementDefinition in definition.character_placements:
		if placement == null:
			continue
		var unit: TacticalUnitState = state.get_unit(placement.character_id)
		_expect(
			unit != null,
			"Authored placement %s did not create its tactical unit." % placement.placement_id,
			failures
		)
		if unit == null:
			continue
		_expect(
			unit.grid_position == placement.grid_position,
			"Authored unit %s started at the wrong tile." % unit.unit_id,
			failures
		)
		if placement.team_id == &"player":
			_expect(unit.is_player_controlled(), "Player unit %s is not player-controlled." % unit.unit_id, failures)
			_expect(not unit.participates_in_enemy_turn, "Player unit %s incorrectly receives Enemy Turns." % unit.unit_id, failures)
			var in_deployment_zone: bool = false
			for zone: MapZoneDefinition in definition.map_definition.deployment_zones:
				if zone != null and zone.contains(unit.grid_position):
					in_deployment_zone = true
					break
			_expect(in_deployment_zone, "Player unit %s is outside the deployment zone." % unit.unit_id, failures)
		elif placement.team_id == &"enemy":
			_expect(unit.is_ai_controlled(), "Enemy unit %s is not AI-controlled." % unit.unit_id, failures)
			_expect(unit.participates_in_enemy_turn, "Enemy unit %s does not receive Enemy Turns." % unit.unit_id, failures)
		else:
			_expect(unit.controller_type == TacticalUnitState.CONTROLLER_WORLD, "Neutral unit %s is not world-controlled." % unit.unit_id, failures)
			_expect(not unit.participates_in_enemy_turn, "Neutral unit %s incorrectly receives Enemy Turns." % unit.unit_id, failures)


static func _test_supply_objective_and_result(failures: Array[String]) -> void:
	var definition := MissionDefinitionRegistry.definition(MISSION_ID)
	if definition == null:
		return
	var session := AuthoredMissionFactory.create_session(definition, [], false, "user://stage_4_6_objective_test.json")
	if session == null:
		failures.append("Supply objective test could not create a session.")
		return
	var state: TacticalState = session.state_store.state
	var zone: TacticalExtractionZoneDefinition = session.mission_setup.extraction_zones()[0]
	var extraction_tile: Vector2i = zone.tile_coordinates[0]
	_expect(state.move_item(SUPPLY_A, TacticalItemLocationState.ground(extraction_tile, "Test extraction"), false), "First supply could not be moved into extraction.", failures)
	_expect(state.move_item(SUPPLY_B, TacticalItemLocationState.ground(extraction_tile, "Test extraction"), false), "Second supply could not be moved into extraction.", failures)
	var reconcile: OperationResult = session.mission_objective_service.reconcile_now()
	_expect(reconcile.success, "Objective reconciliation failed.", failures)
	var primary: MissionObjectiveState = state.mission_runtime_state.objective(&"objective.farm.extract_supplies")
	_expect(primary != null and primary.is_complete(), "Two extracted supplies did not complete the primary objective.", failures)
	var manifest := TacticalExtractionManifestQuery.build_manifest(state, session.map_definition, session.mission_setup, zone.zone_id)
	_expect(manifest.required_objectives_complete, "Extraction manifest did not use authored objective state.", failures)
	var result := MissionResultBuilder.build_extraction_result(&"result.stage_4_6.test", session.mission_setup, state, manifest)
	_expect(result.source_setup_hash == session.mission_setup.finalized_setup_hash(), "Mission result setup hash does not match.", failures)
	_expect(result.objective_outcomes_by_id.has(&"objective.farm.extract_supplies"), "Mission result omitted authored objective outcomes.", failures)
	_expect(result.notoriety_preview_lines.size() == definition.notoriety_preview_lines.size(), "Mission result omitted Notoriety preview lines.", failures)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
