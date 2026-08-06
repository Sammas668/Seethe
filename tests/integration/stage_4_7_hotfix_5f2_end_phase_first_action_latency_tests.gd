class_name Stage47Hotfix5f2EndPhaseFirstActionLatencyTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var handler: RefCounted = session.enemy_turn_handler
	if handler == null:
		failures.append("The Hotfix 5f2 EnemyTurnHandler fixture is unavailable.")
		return failures

	for method_name: StringName in [
		&"has_pending_enemy_destination_visibility",
		&"pending_enemy_destination_visibility_unit_id",
		&"step_pending_enemy_destination_visibility",
		&"cancel_pending_enemy_destination_visibility",
		&"is_enemy_plan_ready_to_commit",
		&"commit_ready_enemy_activation",
	]:
		_expect(
			handler.has_method(method_name),
			"EnemyTurnHandler must expose %s." % method_name,
			failures
		)

	_expect(
		not bool(handler.call("has_pending_enemy_destination_visibility")),
		"A new tactical session must not begin with a stale destination FOV job.",
		failures
	)
	_expect(
		bool(handler.call("step_pending_enemy_destination_visibility", 8000)),
		"Stepping an absent destination FOV job must complete safely.",
		failures
	)

	var premature_commit: OperationResult = handler.call(
		"commit_ready_enemy_activation"
	) as OperationResult
	_expect(
		premature_commit != null and not premature_commit.success,
		"A plan may not commit before read-only planning completes.",
		failures
	)
	_expect(
		premature_commit != null and premature_commit.code == &"enemy_plan_not_ready",
		"A premature Hotfix 5f2 commit must return enemy_plan_not_ready.",
		failures
	)

	var enemy: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	if enemy != null:
		var planner := EnemyActionPlanner.new()
		planner.configure(
			session.state_store,
			session.map_definition,
			session.content_catalogue,
			session.attack_preview_query
		)
		var job: EnemyActivationPlanningJob = planner.begin_plan_activation(enemy)
		var slices: int = 0
		while job != null and not job.complete and slices < 64:
			planner.step_plan_job(job, 8000)
			slices += 1
		_expect(
			job != null and job.complete,
			"The planner must consume an actual supplied frame budget without a rendered-frame dependency.",
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
