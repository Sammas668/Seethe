class_name Stage47Hotfix5eEnemyTurnResponsivenessTests
extends RefCounted

const SCREEN_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var player: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var enemy: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	if player == null or enemy == null:
		failures.append("The Hotfix 5e tactical fixture is incomplete.")
		return failures

	var navigation := TacticalNavigationSnapshot.new(
		session.map_definition,
		state,
		player.unit_id
	)
	var field: MovementReachableField = MovementRules.build_reachable_field(
		player.grid_position,
		navigation,
		20,
		player.diagonal_steps_used
	)
	_expect(
		field != null and field.has_tile(player.grid_position),
		"The reachable field must always contain its legal origin.",
		failures
	)
	_expect(
		field.reachable_tile_count() > 1,
		"The sandbox actor must receive more than one reachable tile.",
		failures
	)

	var chosen_tile: Vector2i = player.grid_position
	for candidate: Vector2i in field.reachable_tiles():
		if candidate != player.grid_position and field.cost_to(candidate) >= 10:
			chosen_tile = candidate
			break
	_expect(
		chosen_tile != player.grid_position,
		"The test must find a non-trivial destination in the reachable field.",
		failures
	)
	if chosen_tile != player.grid_position:
		var field_path: MovementPathResult = field.path_to(chosen_tile)
		var heap_path: MovementPathResult = MovementRules.find_path(
			player.grid_position,
			chosen_tile,
			navigation,
			player.diagonal_steps_used
		)
		_expect(field_path.success, "The field must reconstruct its selected route.", failures)
		_expect(heap_path.success, "Heap A* must reach the selected route.", failures)
		_expect(
			field_path.cost_feet == field.cost_to(chosen_tile),
			"The reconstructed field path must preserve its cheapest stored cost.",
			failures
		)
		_expect(
			heap_path.cost_feet == field_path.cost_feet,
			"Heap A* and the bounded reachable field must agree on path cost.",
			failures
		)

	var plan := EnemyActionPlan.new()
	var planned_path: Array[Vector2i] = [
		player.grid_position,
		chosen_tile,
	]
	plan.configure_success(
		&"attack.test",
		enemy.unit_id,
		chosen_tile,
		true,
		true,
		10,
		planned_path
	)
	_expect(
		plan.move_path == planned_path,
		"EnemyActionPlan must carry the selected route into authoritative commit.",
		failures
	)

	var screen = SCREEN_SCENE.instantiate()
	screen.call("configure", session)
	tree.root.add_child(screen)
	await tree.process_frame
	var long_path: Array[Vector2i] = [enemy.grid_position]
	for step: int in range(1, 18):
		long_path.append(enemy.grid_position + Vector2i(step, 0))
	var long_duration: float = float(
		screen.call("_movement_animation_duration", enemy, long_path)
	)
	_expect(
		long_duration <= 0.50 and long_duration >= 0.16,
		"Long visible AI routes must remain readable while respecting the 0.50-second cap.",
		failures
	)

	var performance: Dictionary = session.enemy_turn_handler.call(
		"performance_snapshot"
	)
	var activation_timing: Dictionary = performance.get("activation_timing", {})
	_expect(
		activation_timing.has("slowest"),
		"Enemy AI diagnostics must expose retained slow-activation history.",
		failures
	)
	_expect(
		session.enemy_turn_handler.has_method("resolve_next_enemy_activation"),
		"EnemyTurnHandler must expose actor-by-actor side-turn resolution.",
		failures
	)

	screen.queue_free()
	await tree.process_frame
	return failures


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
