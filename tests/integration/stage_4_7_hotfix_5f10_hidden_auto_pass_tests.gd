class_name Stage47Hotfix5f10HiddenAutoPassTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_consecutive_hidden_unaware_units_commit_once(failures)
	_test_visible_actor_stops_hidden_batch(failures)
	return failures


static func _test_consecutive_hidden_unaware_units_commit_once(
	failures: Array[String]
) -> void:
	var state := TacticalState.new()
	var guard_a := TacticalUnitState.new(
		&"batch.guard_a", "Guard A", Vector2i(8, 8), 80, &"enemy"
	)
	var guard_b := TacticalUnitState.new(
		&"batch.guard_b", "Guard B", Vector2i(10, 8), 80, &"enemy"
	)
	guard_a.turn_behavior = TacticalUnitState.TURN_BEHAVIOR_STANDARD
	guard_b.turn_behavior = TacticalUnitState.TURN_BEHAVIOR_STANDARD
	state.units_by_id[guard_a.unit_id] = guard_a
	state.units_by_id[guard_b.unit_id] = guard_b
	var squad := TacticalSquadState.new(
		&"squad.batch", &"enemy", [guard_a.unit_id, guard_b.unit_id]
	)
	state.squads_by_id[squad.squad_id] = squad
	guard_a.squad_id = squad.squad_id
	guard_b.squad_id = squad.squad_id
	state.rebuild_unit_occupancy()
	state.phase_state.begin_enemy_phase()

	var store := TacticalStateStore.new(state)
	var reasons: Array[StringName] = []
	store.state_changed.connect(
		func(reason: StringName) -> void:
			reasons.append(reason)
	)
	var handler := EnemyTurnHandler.new()
	handler.set("_state_store", store)
	handler.set("_map_definition", TacticalMapDefinition.new())

	var result: OperationResult = handler.resolve_next_enemy_activation(20_000)
	_expect(result.success, "The hidden auto-pass batch must commit successfully.", failures)
	_expect(
		bool((result.data as Dictionary).get("hidden_auto_pass_batch", false)),
		"The activation result must identify the hidden batch.",
		failures
	)
	_expect(
		int((result.data as Dictionary).get("batch_size", 0)) == 2,
		"Both consecutive hidden unaware actors must share one batch.",
		failures
	)
	_expect(
		reasons.size() == 1 and reasons[0] == &"hidden_enemy_auto_pass_batch",
		"The batch must emit exactly one tactical state change.",
		failures
	)
	_expect(
		guard_a.action_budget.ended_activation
		and guard_b.action_budget.ended_activation,
		"Every batched actor must end its activation authoritatively.",
		failures
	)
	_expect(
		store.state.revision == 1,
		"The two hidden passes must consume one transaction revision.",
		failures
	)
	var completed: OperationResult = handler.resolve_next_enemy_activation(20_000)
	_expect(
		completed.success and completed.code == &"enemy_turn_completed",
		"The next call must complete the Enemy Phase without another pass transaction.",
		failures
	)


static func _test_visible_actor_stops_hidden_batch(
	failures: Array[String]
) -> void:
	var state := TacticalState.new()
	var hidden_guard := TacticalUnitState.new(
		&"batch.hidden", "Hidden Guard", Vector2i(8, 8), 80, &"enemy"
	)
	var visible_guard := TacticalUnitState.new(
		&"batch.visible", "Visible Guard", Vector2i(2, 2), 80, &"enemy"
	)
	hidden_guard.turn_behavior = TacticalUnitState.TURN_BEHAVIOR_STANDARD
	visible_guard.turn_behavior = TacticalUnitState.TURN_BEHAVIOR_AUTO_PASS
	state.units_by_id[hidden_guard.unit_id] = hidden_guard
	state.units_by_id[visible_guard.unit_id] = visible_guard
	var hidden_squad := TacticalSquadState.new(
		&"squad.hidden", &"enemy", [hidden_guard.unit_id]
	)
	state.squads_by_id[hidden_squad.squad_id] = hidden_squad
	hidden_guard.squad_id = hidden_squad.squad_id
	var visible_squad := TacticalSquadState.new(
		&"squad.visible", &"enemy", [visible_guard.unit_id]
	)
	visible_squad.make_aware()
	state.squads_by_id[visible_squad.squad_id] = visible_squad
	visible_guard.squad_id = visible_squad.squad_id
	state.rebuild_unit_occupancy()
	state.phase_state.begin_enemy_phase()

	var handler := EnemyTurnHandler.new()
	handler.set("_state_store", TacticalStateStore.new(state))
	handler.set("_map_definition", TacticalMapDefinition.new())
	# The visibility service is absent in this isolated fixture, so force the
	# candidate check directly: player-visible actors must never qualify.
	_expect(
		handler.call("_is_hidden_auto_pass_batch_candidate", hidden_guard),
		"An unaware hidden guard must qualify for batching.",
		failures
	)
	visible_guard.team_id = &"player"
	_expect(
		not handler.call("_is_hidden_auto_pass_batch_candidate", visible_guard),
		"A player-observable or player-controlled actor must not enter the hidden batch.",
		failures
	)


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
