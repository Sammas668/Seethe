class_name Stage47Hotfix5f8TargetedMeleeStallTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_targeted_search_resumes_and_reaches_a_goal(failures)
	_test_enemy_guard_uses_targeted_melee_planning(failures)
	return failures


static func _test_targeted_search_resumes_and_reaches_a_goal(
		failures: Array[String]
) -> void:
	var map := TacticalMapDefinition.new()
	map.grid_size = Vector2i(14, 14)
	var state := TacticalState.new()
	var mover := TacticalUnitState.new(
		&"targeted.mover", "Mover", Vector2i(1, 1), 80, &"enemy"
	)
	state.units_by_id[mover.unit_id] = mover
	state.rebuild_unit_occupancy()
	var navigation := TacticalNavigationSnapshot.new(map, state, mover.unit_id)
	var job := MovementTargetedSearchJob.new()
	var goals: Array[Vector2i] = [
		Vector2i(6, 5),
		Vector2i(5, 6),
	]
	job.configure(mover.grid_position, navigation, goals, 40, 0)
	var slices: int = 0
	while not job.complete and slices < 256:
		job.step(Time.get_ticks_usec() + 1_000_000, 1)
		slices += 1
	_expect(job.complete, "The targeted movement search must complete.", failures)
	_expect(slices > 1, "A constrained targeted search must resume across slices.", failures)
	var result: MovementPathResult = job.result()
	_expect(result.success, "The targeted movement search must reach a legal goal.", failures)
	if result.success and not result.path.is_empty():
		_expect(goals.has(result.path.back()), "The targeted search must stop on one authored goal.", failures)
		_expect(result.cost_feet <= 40, "The targeted search must respect its movement bound.", failures)


static func _test_enemy_guard_uses_targeted_melee_planning(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var guard: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var player: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	if guard == null or player == null:
		failures.append("The Hotfix 5f8 tactical fixture is incomplete.")
		return
	var squad: TacticalSquadState = state.get_squad(guard.squad_id)
	if squad != null:
		squad.make_aware()
	player.reveal_to_squad(guard.squad_id)
	state.rebuild_unit_occupancy()

	var planner := EnemyActionPlanner.new()
	planner.configure(
		session.state_store,
		session.map_definition,
		session.content_catalogue,
		session.attack_preview_query
	)
	var job: EnemyActivationPlanningJob = planner.begin_plan_activation(
		guard,
		guard.action_budget.maximum_turn_capacity_feet,
		0,
		true
	)
	var slices: int = 0
	while job != null and not job.complete and slices < 512:
		planner.step_plan_job(job, 1_000_000)
		slices += 1
	_expect(job != null and job.complete, "The guard plan must complete.", failures)
	var diagnostics: Dictionary = planner.last_plan_diagnostics()
	_expect(
		int(diagnostics.get("targeted_melee_search_builds", 0)) >= 1,
		"A moving melee guard must use a targeted search.",
		failures
	)
	_expect(
		int(diagnostics.get("reachable_field_builds", 0)) == 0,
		"A revealed-target melee guard must not build the universal reachable field.",
		failures
	)
	_expect(
		int(diagnostics.get("targeted_melee_attack_capacity_feet", -1))
		== int(guard.action_budget.maximum_turn_capacity_feet / 2),
		"Move-and-attack planning must reserve the Half Action attack cost.",
		failures
	)


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
