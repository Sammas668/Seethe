class_name Stage47Hotfix5f9CadencePolishTests
extends RefCounted

const TACTICAL_SCREEN_SCRIPT: Script = preload(
	"res://presentation/tactical/tactical_screen.gd"
)


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_dependency_stamp_uses_direct_revisions(failures)
	_test_dependency_stamp_rejects_spatial_change(failures)
	_test_readable_enemy_movement_curve(failures)
	return failures


static func _test_dependency_stamp_uses_direct_revisions(
		failures: Array[String]
) -> void:
	var state := TacticalState.new()
	var player := TacticalUnitState.new(
		&"cadence.player", "Player", Vector2i(2, 2), 80, &"player"
	)
	var guard := TacticalUnitState.new(
		&"cadence.guard", "Guard", Vector2i(6, 2), 80, &"enemy"
	)
	state.units_by_id[player.unit_id] = player
	state.units_by_id[guard.unit_id] = guard
	var squad := TacticalSquadState.new(
		&"squad.cadence", &"enemy", [guard.unit_id]
	)
	squad.make_aware()
	state.squads_by_id[squad.squad_id] = squad
	guard.squad_id = squad.squad_id
	player.reveal_to_squad(squad.squad_id)
	state.rebuild_unit_occupancy()
	var stamp: EnemyPlanDependencyStamp = EnemyPlanDependencyStamp.capture(
		state,
		guard,
		guard.action_budget.remaining_turn_capacity_feet,
		guard.diagonal_steps_used,
		&"initiative",
		4
	)
	_expect(stamp != null, "The enemy-plan dependency stamp must be captured.", failures)
	if stamp == null:
		return
	player.action_budget.ended_activation = true
	_expect(
		stamp.matches(
			state,
			guard,
			guard.action_budget.remaining_turn_capacity_feet,
			guard.diagonal_steps_used,
			&"initiative",
			4
		),
		"Ending the outgoing player activation must not invalidate a warmed enemy plan.",
		failures
	)


static func _test_dependency_stamp_rejects_spatial_change(
		failures: Array[String]
) -> void:
	var state := TacticalState.new()
	var player := TacticalUnitState.new(
		&"stamp.player", "Player", Vector2i(3, 3), 80, &"player"
	)
	var guard := TacticalUnitState.new(
		&"stamp.guard", "Guard", Vector2i(8, 3), 80, &"enemy"
	)
	state.units_by_id[player.unit_id] = player
	state.units_by_id[guard.unit_id] = guard
	var squad := TacticalSquadState.new(
		&"squad.stamp", &"enemy", [guard.unit_id]
	)
	squad.make_aware()
	state.squads_by_id[squad.squad_id] = squad
	guard.squad_id = squad.squad_id
	player.reveal_to_squad(squad.squad_id)
	state.rebuild_unit_occupancy()
	var stamp: EnemyPlanDependencyStamp = EnemyPlanDependencyStamp.capture(
		state, guard, 80, 0, &"initiative", 7
	)
	player.grid_position = Vector2i(4, 3)
	state.rebuild_unit_occupancy()
	_expect(
		stamp != null and not stamp.matches(state, guard, 80, 0, &"initiative", 7),
		"A target or occupancy change must invalidate the warmed enemy plan.",
		failures
	)


static func _test_readable_enemy_movement_curve(
		failures: Array[String]
) -> void:
	var screen: Node = TACTICAL_SCREEN_SCRIPT.new()
	var guard := TacticalUnitState.new(
		&"curve.guard", "Guard", Vector2i.ZERO, 80, &"enemy"
	)
	var one_step: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	var two_steps: Array[Vector2i] = [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)
	]
	var three_steps: Array[Vector2i] = [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)
	]
	var long_path: Array[Vector2i] = []
	for index: int in range(25):
		long_path.append(Vector2i(index, 0))
	_expect(
		is_equal_approx(float(screen.call("_movement_animation_duration", guard, one_step)), 0.06),
		"One-tile enemy movement must retain the 0.06-second readable duration.",
		failures
	)
	_expect(
		is_equal_approx(float(screen.call("_movement_animation_duration", guard, two_steps)), 0.105),
		"Two-tile enemy movement must retain the 0.105-second readable duration.",
		failures
	)
	_expect(
		is_equal_approx(float(screen.call("_movement_animation_duration", guard, three_steps)), 0.15),
		"Three-tile enemy movement must retain the 0.15-second readable duration.",
		failures
	)
	_expect(
		float(screen.call("_movement_animation_duration", guard, long_path)) <= 0.40,
		"Long enemy movement must remain under the 0.40-second absolute cap.",
		failures
	)
	screen.free()


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
