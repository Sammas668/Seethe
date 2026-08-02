class_name Stage47Hotfix5f1AdaptiveEnemyPlanningTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var handler: RefCounted = session.enemy_turn_handler
	if handler == null:
		failures.append("The Hotfix 5f1 EnemyTurnHandler fixture is unavailable.")
		return failures

	_expect(
		handler.has_method("is_enemy_plan_ready_to_commit"),
		"EnemyTurnHandler must expose the read-only plan/commit boundary.",
		failures
	)
	_expect(
		handler.has_method("commit_ready_enemy_activation"),
		"EnemyTurnHandler must expose explicit completed-plan commitment.",
		failures
	)
	_expect(
		handler.has_method("pending_enemy_planning_is_visibility"),
		"EnemyTurnHandler must identify destination-visibility planning work.",
		failures
	)
	_expect(
		handler.has_method("record_enemy_planning_frame_yield"),
		"EnemyTurnHandler must retain adaptive-scheduler yield diagnostics.",
		failures
	)

	var premature_commit: OperationResult = handler.call(
		"commit_ready_enemy_activation"
	) as OperationResult
	_expect(
		premature_commit != null and not premature_commit.success,
		"Committing without a completed plan must fail safely.",
		failures
	)
	_expect(
		premature_commit != null and premature_commit.code == &"enemy_plan_not_ready",
		"A premature plan commit must return enemy_plan_not_ready.",
		failures
	)

	var enemy: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	_expect(enemy != null, "The adaptive-planning enemy fixture is missing.", failures)
	if enemy != null:
		var planner := EnemyActionPlanner.new()
		planner.configure(
			session.state_store,
			session.map_definition,
			session.content_catalogue,
			session.attack_preview_query
		)
		var job: EnemyActivationPlanningJob = planner.begin_plan_activation(enemy)
		var slices_without_frame_wait: int = 0
		while job != null and not job.complete and slices_without_frame_wait < 256:
			planner.step_plan_job(job, 3000)
			slices_without_frame_wait += 1
		_expect(
			job != null and job.complete,
			"Read-only planning slices must be runnable consecutively without a rendered-frame dependency.",
			failures
		)
		var diagnostics: Dictionary = planner.last_plan_diagnostics()
		_expect(
			diagnostics.has("processing_usec") and diagnostics.has("total_usec"),
			"Planner diagnostics must distinguish processing time from wall-clock time.",
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
