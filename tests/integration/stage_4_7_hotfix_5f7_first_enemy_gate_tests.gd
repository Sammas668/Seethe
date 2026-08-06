class_name Stage47Hotfix5f7FirstEnemyGateTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_perception_revision_is_monotonic(failures)
	_test_lightweight_dependency_stamp_ignores_outgoing_player_end(failures)
	_test_ordinary_guard_fast_eligibility(failures)
	return failures


static func _test_perception_revision_is_monotonic(
		failures: Array[String]
) -> void:
	var service := TacticalDetectionService.new()
	service.call("_advance_perception_revision", &"squad.test")
	var first: int = service.perception_revision_for_squad(&"squad.test")
	service.call("_advance_perception_revision", &"squad.test")
	var second: int = service.perception_revision_for_squad(&"squad.test")
	_expect(first > 0 and second > first,
		"Perception dependency revisions must advance monotonically.", failures)


static func _test_lightweight_dependency_stamp_ignores_outgoing_player_end(
		failures: Array[String]
) -> void:
	var state := TacticalState.new()
	var player := TacticalUnitState.new(
		&"gate.player", "Player", Vector2i(2, 2), 80, &"player"
	)
	var guard := TacticalUnitState.new(
		&"gate.guard", "Guard", Vector2i(5, 2), 80, &"enemy"
	)
	state.units_by_id[player.unit_id] = player
	state.units_by_id[guard.unit_id] = guard
	var squad := TacticalSquadState.new(
		&"squad.gate", &"enemy", [guard.unit_id]
	)
	squad.make_aware()
	state.squads_by_id[squad.squad_id] = squad
	guard.squad_id = squad.squad_id
	player.reveal_to_squad(squad.squad_id)
	state.rebuild_unit_occupancy()
	var handler := EnemyTurnHandler.new()
	handler.set("_state_store", TacticalStateStore.new(state))
	handler.set("_map_definition", TacticalMapDefinition.new())
	var before: String = handler.call(
		"_handoff_warmup_signature_for_unit",
		guard,
		guard.action_budget.remaining_turn_capacity_feet,
		guard.diagonal_steps_used,
		&"initiative"
	)
	player.action_budget.ended_activation = true
	var after: String = handler.call(
		"_handoff_warmup_signature_for_unit",
		guard,
		guard.action_budget.remaining_turn_capacity_feet,
		guard.diagonal_steps_used,
		&"initiative"
	)
	_expect(before == after,
		"The outgoing player's ended marker must not invalidate the enemy plan.", failures)


static func _test_ordinary_guard_fast_eligibility(
		failures: Array[String]
) -> void:
	var state := TacticalState.new()
	var guard := TacticalUnitState.new(
		&"fast.guard", "Guard", Vector2i(4, 4), 80, &"enemy"
	)
	state.units_by_id[guard.unit_id] = guard
	var service := TacticalAbilityService.new()
	service.set("_state_store", TacticalStateStore.new(state))
	_expect(
		not service.has_start_of_activation_work(guard.unit_id),
		"An ordinary guard must bypass global start-effect scanning.", failures
	)
	_expect(
		not service.has_ai_usable_special_abilities(guard.unit_id),
		"An ordinary guard must bypass specialist ability scanning.", failures
	)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
