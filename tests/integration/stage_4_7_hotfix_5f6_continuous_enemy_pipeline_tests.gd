class_name Stage47Hotfix5f6ContinuousEnemyPipelineTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_initiative_chain_candidate(failures)
	_test_player_boundary_stops_chain(failures)
	_test_side_based_chain_candidate(failures)
	return failures


static func _test_initiative_chain_candidate(failures: Array[String]) -> void:
	var state := TacticalState.new()
	var guard_a := TacticalUnitState.new(
		&"pipeline.guard_a", "Guard A", Vector2i(4, 2), 80, &"enemy"
	)
	var guard_b := TacticalUnitState.new(
		&"pipeline.guard_b", "Guard B", Vector2i(6, 2), 80, &"enemy"
	)
	var player := TacticalUnitState.new(
		&"pipeline.player", "Player", Vector2i(2, 2), 80, &"player"
	)
	guard_a.turn_behavior = TacticalUnitState.TURN_BEHAVIOR_STANDARD
	guard_b.turn_behavior = TacticalUnitState.TURN_BEHAVIOR_STANDARD
	for unit: TacticalUnitState in [guard_a, guard_b, player]:
		state.units_by_id[unit.unit_id] = unit
	var squad := TacticalSquadState.new(
		&"squad.pipeline", &"enemy", [guard_a.unit_id, guard_b.unit_id]
	)
	squad.make_aware()
	state.squads_by_id[squad.squad_id] = squad
	guard_a.squad_id = squad.squad_id
	guard_b.squad_id = squad.squad_id
	player.reveal_to_squad(squad.squad_id)
	state.rebuild_unit_occupancy()
	state.phase_state.begin_initiative(
		[guard_a.unit_id, guard_b.unit_id, player.unit_id],
		{guard_a.unit_id: 20, guard_b.unit_id: 15, player.unit_id: 10}
	)

	var handler := EnemyTurnHandler.new()
	handler.set("_state_store", TacticalStateStore.new(state))
	handler.set("_map_definition", TacticalMapDefinition.new())

	var before_commit: Dictionary = handler.call("_next_ai_handoff_candidate")
	_expect(
		before_commit.is_empty(),
		"Lookahead must not begin while the current AI activation is unresolved.",
		failures
	)
	guard_a.action_budget.ended_activation = true
	var candidate: Dictionary = handler.call("_next_ai_handoff_candidate")
	_expect(
		StringName(candidate.get("unit_id", &"")) == guard_b.unit_id,
		"The immediate consecutive AI actor must be selected for chain warmup.",
		failures
	)
	_expect(
		bool(candidate.get("chain", false)),
		"Enemy-to-enemy initiative warmup must be marked as a chain warmup.",
		failures
	)


static func _test_player_boundary_stops_chain(failures: Array[String]) -> void:
	var state := TacticalState.new()
	var guard_a := TacticalUnitState.new(
		&"boundary.guard_a", "Guard A", Vector2i(4, 2), 80, &"enemy"
	)
	var guard_b := TacticalUnitState.new(
		&"boundary.guard_b", "Guard B", Vector2i(7, 2), 80, &"enemy"
	)
	var player := TacticalUnitState.new(
		&"boundary.player", "Player", Vector2i(2, 2), 80, &"player"
	)
	guard_a.turn_behavior = TacticalUnitState.TURN_BEHAVIOR_STANDARD
	guard_b.turn_behavior = TacticalUnitState.TURN_BEHAVIOR_STANDARD
	for unit: TacticalUnitState in [guard_a, player, guard_b]:
		state.units_by_id[unit.unit_id] = unit
	var squad := TacticalSquadState.new(
		&"squad.boundary", &"enemy", [guard_a.unit_id, guard_b.unit_id]
	)
	squad.make_aware()
	state.squads_by_id[squad.squad_id] = squad
	guard_a.squad_id = squad.squad_id
	guard_b.squad_id = squad.squad_id
	player.reveal_to_squad(squad.squad_id)
	state.rebuild_unit_occupancy()
	state.phase_state.begin_initiative(
		[guard_a.unit_id, player.unit_id, guard_b.unit_id],
		{guard_a.unit_id: 20, player.unit_id: 15, guard_b.unit_id: 10}
	)
	guard_a.action_budget.ended_activation = true

	var handler := EnemyTurnHandler.new()
	handler.set("_state_store", TacticalStateStore.new(state))
	handler.set("_map_definition", TacticalMapDefinition.new())
	var candidate: Dictionary = handler.call("_next_ai_handoff_candidate")
	_expect(
		candidate.is_empty(),
		"AI lookahead must stop at an intervening player initiative actor.",
		failures
	)


static func _test_side_based_chain_candidate(failures: Array[String]) -> void:
	var state := TacticalState.new()
	var guard_a := TacticalUnitState.new(
		&"side.guard_a", "Guard A", Vector2i(4, 2), 80, &"enemy"
	)
	var guard_b := TacticalUnitState.new(
		&"side.guard_b", "Guard B", Vector2i(6, 2), 80, &"enemy"
	)
	guard_a.turn_behavior = TacticalUnitState.TURN_BEHAVIOR_STANDARD
	guard_b.turn_behavior = TacticalUnitState.TURN_BEHAVIOR_STANDARD
	for unit: TacticalUnitState in [guard_a, guard_b]:
		state.units_by_id[unit.unit_id] = unit
	var squad := TacticalSquadState.new(
		&"squad.side", &"enemy", [guard_a.unit_id, guard_b.unit_id]
	)
	squad.make_aware()
	state.squads_by_id[squad.squad_id] = squad
	guard_a.squad_id = squad.squad_id
	guard_b.squad_id = squad.squad_id
	state.rebuild_unit_occupancy()
	state.phase_state.begin_enemy_phase()

	var handler := EnemyTurnHandler.new()
	handler.set("_state_store", TacticalStateStore.new(state))
	handler.set("_map_definition", TacticalMapDefinition.new())
	handler.set("_side_turn_participant_ids", [guard_a.unit_id, guard_b.unit_id])
	handler.set("_side_turn_index", 1)
	var candidate: Dictionary = handler.call("_next_ai_handoff_candidate")
	_expect(
		StringName(candidate.get("unit_id", &"")) == guard_b.unit_id,
		"Side-based lookahead must use the next authoritative participant index.",
		failures
	)
	_expect(
		bool(candidate.get("chain", false)),
		"Side-based enemy-to-enemy warmup must be marked as a chain warmup.",
		failures
	)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
