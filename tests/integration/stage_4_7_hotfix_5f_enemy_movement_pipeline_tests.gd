class_name Stage47Hotfix5fEnemyMovementPipelineTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var enemy: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var player: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	if enemy == null or player == null:
		failures.append("The Hotfix 5f tactical fixture is incomplete.")
		return failures

	var navigation := TacticalNavigationSnapshot.new(
		session.map_definition,
		state,
		enemy.unit_id
	)
	var incremental := MovementReachableFieldJob.new()
	incremental.configure(
		enemy.grid_position,
		navigation,
		40,
		enemy.diagonal_steps_used
	)
	var slices: int = 0
	while not incremental.complete and slices < 512:
		incremental.step(Time.get_ticks_usec() + 1_000_000, 4)
		slices += 1
	_expect(incremental.complete, "Incremental reachable-field planning must complete.", failures)
	_expect(slices > 1, "A constrained reachable-field job must resume across slices.", failures)
	var incremental_field: MovementReachableField = incremental.result()
	var synchronous_field: MovementReachableField = MovementRules.build_reachable_field(
		enemy.grid_position,
		navigation,
		40,
		enemy.diagonal_steps_used
	)
	_expect(
		incremental_field.reachable_tile_count() == synchronous_field.reachable_tile_count(),
		"Incremental and synchronous reachable fields must contain the same tiles.",
		failures
	)
	for tile: Vector2i in synchronous_field.reachable_tiles():
		if incremental_field.cost_to(tile) != synchronous_field.cost_to(tile):
			failures.append("Incremental reachable-field costs diverged at %s." % tile)
			break

	_expect(
		session.enemy_turn_handler.has_method("peek_next_enemy_activation_unit_id"),
		"EnemyTurnHandler must expose the next side-based actor before planning.",
		failures
	)
	_expect(
		session.enemy_turn_handler.has_method("has_pending_enemy_planning"),
		"EnemyTurnHandler must expose resumable planning state.",
		failures
	)
	_expect(
		session.visibility_service.has_method("begin_visibility_preparation_for_destination"),
		"Visibility preparation must expose a resumable destination job.",
		failures
	)
	_expect(
		session.detection_service.has_method("refresh_current_perception_for_ai_planning"),
		"AI perception must refresh independently of fog presentation deferral.",
		failures
	)

	var visibility_job: RefCounted = session.visibility_service.call(
		"begin_visibility_preparation_for_destination",
		enemy.unit_id,
		enemy.grid_position
	) as RefCounted
	_expect(visibility_job != null, "A legal enemy destination must create a visibility job.", failures)
	var visibility_slices: int = 0
	while (
		visibility_job != null
		and not bool(visibility_job.get("complete"))
		and visibility_slices < 64
	):
		session.visibility_service.call(
			"step_visibility_preparation_job",
			visibility_job,
			500
		)
		visibility_slices += 1
	_expect(
		visibility_job != null and bool(visibility_job.get("valid")),
		"Destination visibility preparation must complete with a valid field.",
		failures
	)

	var first_refresh: OperationResult = session.detection_service.call(
		"refresh_current_perception_for_ai_planning",
		enemy.squad_id
	) as OperationResult
	var before_second: Dictionary = session.detection_service.performance_snapshot()
	var second_refresh: OperationResult = session.detection_service.call(
		"refresh_current_perception_for_ai_planning",
		enemy.squad_id
	) as OperationResult
	var after_second: Dictionary = session.detection_service.performance_snapshot()
	_expect(first_refresh != null and first_refresh.success, "Initial AI perception refresh must succeed.", failures)
	_expect(second_refresh != null and second_refresh.success, "Repeated AI perception refresh must succeed.", failures)
	_expect(
		int(after_second.get("perception_refresh_skipped_count", 0))
		> int(before_second.get("perception_refresh_skipped_count", 0)),
		"An unchanged squad perception signature must skip duplicate work.",
		failures
	)

	var transaction_snapshot: Dictionary = TacticalChangeSet.performance_snapshot()
	_expect(
		transaction_snapshot.has("last_snapshot_usec")
		and transaction_snapshot.has("last_validation_usec"),
		"Transaction diagnostics must expose snapshot and validation timing.",
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
