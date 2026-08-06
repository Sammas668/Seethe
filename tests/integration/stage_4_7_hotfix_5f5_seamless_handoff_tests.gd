class_name Stage47Hotfix5f5SeamlessHandoffTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var state := TacticalState.new()
	var player := TacticalUnitState.new(
		&"handoff.player", "Player", Vector2i(2, 2), 80, &"player"
	)
	var guard := TacticalUnitState.new(
		&"handoff.guard", "Guard", Vector2i(5, 2), 80, &"enemy"
	)
	state.units_by_id[player.unit_id] = player
	state.units_by_id[guard.unit_id] = guard
	state.rebuild_unit_occupancy()
	var squad := TacticalSquadState.new(
		&"squad.handoff", &"enemy", [guard.unit_id]
	)
	squad.make_aware()
	state.squads_by_id[squad.squad_id] = squad
	guard.squad_id = squad.squad_id
	player.reveal_to_squad(squad.squad_id)
	state.phase_state.begin_initiative(
		[player.unit_id, guard.unit_id],
		{player.unit_id: 20, guard.unit_id: 10}
	)

	var store := TacticalStateStore.new(state)
	var handler := EnemyTurnHandler.new()
	handler.set("_state_store", store)
	handler.set("_map_definition", TacticalMapDefinition.new())

	var candidate: Dictionary = handler.call("_next_ai_handoff_candidate")
	_expect(
		StringName(candidate.get("unit_id", &"")) == guard.unit_id,
		"The immediate AI participant after the active player must be selected for warmup.",
		failures
	)
	_expect(
		StringName(candidate.get("mode", &"")) == &"initiative",
		"Initiative handoff warmup must preserve its mode.",
		failures
	)
	var signature_before: String = handler.call(
		"_handoff_warmup_signature_for_unit",
		guard,
		guard.action_budget.remaining_turn_capacity_feet,
		guard.diagonal_steps_used,
		&"initiative"
	)
	player.action_budget.ended_activation = true
	var signature_after: String = handler.call(
		"_handoff_warmup_signature_for_unit",
		guard,
		guard.action_budget.remaining_turn_capacity_feet,
		guard.diagonal_steps_used,
		&"initiative"
	)
	_expect(
		signature_before == signature_after,
		"Ending the current player's activation must not invalidate an otherwise current AI plan.",
		failures
	)

	var job := EnemyActivationPlanningJob.new()
	job.configure(guard, 55, 1, true)
	_expect(job.forecast_mode, "Forecast jobs must be marked read-only forecast mode.", failures)
	_expect(
		job.available_capacity_feet == 55 and job.planning_diagonal_steps == 1,
		"Forecast jobs must use the upcoming activation's projected movement budget.",
		failures
	)
	return failures


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
