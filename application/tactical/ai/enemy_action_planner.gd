class_name EnemyActionPlanner
extends RefCounted

const TacticalGridDistance: Script = preload(
	"res://domain/tactical/tactical_grid_distance.gd"
)
# Legacy Stage 4.2.5.3 validator marker: TacticalGridDistance.minimum_steps_between_sets
const TacticalMeleeReachRules: Script = preload(
	"res://domain/tactical/combat/tactical_melee_reach_rules.gd"
)

const ENEMY_ACTION_PLAN_SCRIPT: Script = preload(
	"res://application/tactical/ai/enemy_action_plan.gd"
)
const ENEMY_ACTIVATION_PLANNING_JOB_SCRIPT: Script = preload(
	"res://application/tactical/ai/enemy_activation_planning_job.gd"
)
const MOVEMENT_REACHABLE_FIELD_JOB_SCRIPT: Script = preload(
	"res://domain/tactical/movement_reachable_field_job.gd"
)
const MOVEMENT_TARGETED_SEARCH_JOB_SCRIPT: Script = preload(
	"res://domain/tactical/movement_targeted_search_job.gd"
)
const TEAM_RELATIONS_SCRIPT: Script = preload(
	"res://domain/tactical/tactical_team_relations.gd"
)
const TacticalLineOfSightRules: Script = preload(
	"res://domain/tactical/visibility/tactical_line_of_sight_rules.gd"
)

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _catalogue: ContentCatalogue
var _attack_preview_query: RefCounted
var _ranged_candidate_tiles_scored: int = 0
var _ranged_exact_candidates_evaluated: int = 0
var _reachable_field_builds: int = 0
var _reachable_tiles_generated: int = 0
var _pathfinding_expansions: int = 0
var _targeted_melee_search_builds: int = 0
var _targeted_melee_expansions: int = 0
var _last_plan_diagnostics: Dictionary = {}

const RANGED_EXACT_SHORTLIST_SIZE: int = 12


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		catalogue: ContentCatalogue,
		attack_preview_query: RefCounted
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_catalogue = catalogue
	_attack_preview_query = attack_preview_query


func plan_activation(unit: TacticalUnitState) -> RefCounted:
	# Compatibility entry point for tests and non-presentational callers. Runtime
	# enemy turns use the resumable planning-job API below.
	var job: EnemyActivationPlanningJob = begin_plan_activation(unit)
	while job != null and not job.complete:
		step_plan_job(job, 1_000_000)
	if job == null or job.plan == null:
		var missing_plan: RefCounted = ENEMY_ACTION_PLAN_SCRIPT.new() as RefCounted
		missing_plan.call(
			"configure_failure",
			"The enemy planner could not create a planning job."
		)
		return missing_plan
	return job.plan


func begin_plan_activation(
		unit: TacticalUnitState,
		capacity_override_feet: int = -1,
		diagonal_steps_override: int = -1,
		forecast: bool = false
) -> EnemyActivationPlanningJob:
	var job := (
		ENEMY_ACTIVATION_PLANNING_JOB_SCRIPT.new()
		as EnemyActivationPlanningJob
	)
	job.configure(
		unit,
		capacity_override_feet,
		diagonal_steps_override,
		forecast
	)
	_last_plan_diagnostics = {
		"total_usec": 0,
		"processing_usec": 0,
		"planning_slices": 0,
		"target_discovery_usec": 0,
		"direct_attack_check_usec": 0,
		"reachable_field_usec": 0,
		"reachable_field_builds": 0,
		"targeted_melee_search_usec": 0,
		"targeted_melee_search_builds": 0,
		"targeted_melee_attack_searches": 0,
		"targeted_melee_approach_searches": 0,
		"targeted_melee_goal_count": 0,
		"targeted_melee_attack_capacity_feet": 0,
		"targeted_melee_expansions": 0,
		"candidate_scoring_usec": 0,
		"candidate_count": 0,
		"bounded_shortlist_count": 0,
		"exact_geometry_usec": 0,
		"target_count": 0,
		"reachable_tile_count": 0,
		"cheap_candidates_considered": 0,
		"exact_candidates_evaluated": 0,
		"pathfinding_expansions": 0,
		"plan_kind": &"none",
		"planning_stage": EnemyActivationPlanningJob.STAGE_TARGET_DISCOVERY,
	}
	if unit == null or _state_store == null or _state_store.state == null:
		job.plan.configure_failure("The enemy planner has no tactical state.")
		job.mark_complete()
		_finalize_job_diagnostics(job)
	return job


func step_plan_job(
		job: EnemyActivationPlanningJob,
		budget_usec: int = 3000
) -> bool:
	if job == null or job.complete:
		return true
	var slice_started_usec: int = Time.get_ticks_usec()
	var deadline_usec: int = slice_started_usec + maxi(250, budget_usec)
	job.processing_slices += 1
	while not job.complete and Time.get_ticks_usec() < deadline_usec:
		_last_plan_diagnostics["planning_stage"] = job.stage
		match job.stage:
			EnemyActivationPlanningJob.STAGE_TARGET_DISCOVERY:
				_step_target_discovery(job)
			EnemyActivationPlanningJob.STAGE_DIRECT_ATTACK_CHECKS:
				_step_direct_attack_checks(job)
			EnemyActivationPlanningJob.STAGE_REACHABLE_FIELD:
				if not _step_reachable_field(job, deadline_usec):
					break
			EnemyActivationPlanningJob.STAGE_TARGETED_MELEE_ATTACK_SEARCH:
				if not _step_targeted_melee_attack_search(job, deadline_usec):
					break
			EnemyActivationPlanningJob.STAGE_TARGETED_MELEE_APPROACH_SEARCH:
				if not _step_targeted_melee_approach_search(job, deadline_usec):
					break
			EnemyActivationPlanningJob.STAGE_TARGET_SCORING:
				_step_target_scoring(job)
			EnemyActivationPlanningJob.STAGE_RANGED_CANDIDATE_SCAN:
				if not _step_ranged_candidate_scan(job, deadline_usec):
					break
			EnemyActivationPlanningJob.STAGE_RANGED_EXACT_GEOMETRY:
				if not _step_ranged_exact_geometry(job, deadline_usec):
					break
			EnemyActivationPlanningJob.STAGE_APPROACH_SCAN:
				if not _step_approach_scan(job, deadline_usec):
					break
			EnemyActivationPlanningJob.STAGE_NO_TARGET_FINALISE:
				_step_no_target_finalise(job)
			EnemyActivationPlanningJob.STAGE_NO_TARGET_GOAL_SCAN:
				if not _step_no_target_goal_scan(job, deadline_usec):
					break
			_:
				job.plan.configure_failure(
					"The enemy planning job entered an unsupported stage."
				)
				job.mark_complete()
	var elapsed_usec: int = maxi(0, Time.get_ticks_usec() - slice_started_usec)
	job.accumulated_processing_usec += elapsed_usec
	_last_plan_diagnostics["processing_usec"] = job.accumulated_processing_usec
	_last_plan_diagnostics["planning_slices"] = job.processing_slices
	_last_plan_diagnostics["total_usec"] = maxi(
		0,
		Time.get_ticks_usec() - job.started_usec
	)
	if job.complete:
		_finalize_job_diagnostics(job)
	return job.complete


func cancel_plan_job(job: EnemyActivationPlanningJob) -> void:
	if job == null or job.complete:
		return
	job.cancelled = true
	job.plan.configure_failure("Enemy planning was cancelled before commitment.")
	job.mark_complete()
	_finalize_job_diagnostics(job)


func _step_target_discovery(job: EnemyActivationPlanningJob) -> void:
	var started_usec: int = Time.get_ticks_usec()
	var unit: TacticalUnitState = _state_store.state.get_unit(job.unit_id)
	if unit == null:
		job.plan.configure_failure("The acting enemy no longer exists.")
		job.mark_complete()
		return
	job.revealed_targets = _revealed_hostile_targets(unit)
	_last_plan_diagnostics["target_count"] = job.revealed_targets.size()
	if job.revealed_targets.is_empty():
		_begin_job_reachable_field(job, unit)
		job.stage = EnemyActivationPlanningJob.STAGE_REACHABLE_FIELD
	else:
		job.action_id = _preferred_attack_action(unit)
		if job.action_id.is_empty():
			job.plan.configure_failure(
				"%s has no implemented AI-usable attack." % unit.display_name
			)
			job.mark_complete()
		else:
			job.attack = _catalogue.attack_definition(job.action_id)
			if job.attack == null:
				job.plan.configure_failure("The selected enemy attack is missing.")
				job.mark_complete()
			else:
				job.attack_cost_feet = (
					job.attack.resolved_cost().resolved_normal_capacity_feet(
						unit.action_budget.maximum_turn_capacity_feet
					)
				)
				job.target_index = 0
				job.stage = (
					EnemyActivationPlanningJob.STAGE_DIRECT_ATTACK_CHECKS
				)
	_last_plan_diagnostics["target_discovery_usec"] = int(
		_last_plan_diagnostics.get("target_discovery_usec", 0)
	) + maxi(0, Time.get_ticks_usec() - started_usec)


func _step_direct_attack_checks(job: EnemyActivationPlanningJob) -> void:
	var started_usec: int = Time.get_ticks_usec()
	var unit: TacticalUnitState = _state_store.state.get_unit(job.unit_id)
	if unit == null:
		job.plan.configure_failure("The acting enemy no longer exists.")
		job.mark_complete()
		return
	if job.target_index >= job.revealed_targets.size():
		if job.best_target != null:
			job.plan.configure_success(
				job.action_id,
				job.best_target.unit_id,
				unit.grid_position,
				false,
				true,
				0,
				[unit.grid_position]
			)
			job.mark_complete()
		else:
			job.best_target = null
			job.best_path = null
			job.best_candidate_score = -2_000_000_000
			job.target_index = 0
			if job.attack.attack_kind == AttackDefinition.ATTACK_RANGED:
				_begin_job_reachable_field(job, unit)
				job.stage = EnemyActivationPlanningJob.STAGE_REACHABLE_FIELD
			else:
				# Hotfix 5f8: ordinary melee actors no longer calculate the entire
				# reachable map before asking for a route to a small set of attack tiles.
				job.stage = EnemyActivationPlanningJob.STAGE_TARGET_SCORING
		_last_plan_diagnostics["direct_attack_check_usec"] = int(
			_last_plan_diagnostics.get("direct_attack_check_usec", 0)
		) + maxi(0, Time.get_ticks_usec() - started_usec)
		return
	var target: TacticalUnitState = job.revealed_targets[job.target_index]
	job.target_index += 1
	var direct_attack_legal: bool = (
		_forecast_direct_attack_succeeds(unit, target, job)
		if job.forecast_mode
		else _preview_succeeds(_preview_attack(unit, target, job.action_id))
	)
	if direct_attack_legal:
		var direct_score: int = (
			3_000_000
			- TacticalGridDistance.steps_between(
				unit.grid_position,
				target.grid_position
			) * 1_000
		)
		if (
			job.best_target == null
			or direct_score > job.best_candidate_score
			or (
				direct_score == job.best_candidate_score
				and String(target.unit_id) < String(job.best_target.unit_id)
			)
		):
			job.best_target = target
			job.best_candidate_score = direct_score
	_last_plan_diagnostics["direct_attack_check_usec"] = int(
		_last_plan_diagnostics.get("direct_attack_check_usec", 0)
	) + maxi(0, Time.get_ticks_usec() - started_usec)


func _begin_job_reachable_field(
	job: EnemyActivationPlanningJob,
	unit: TacticalUnitState
) -> void:
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	job.reachable_builder = (
		MOVEMENT_REACHABLE_FIELD_JOB_SCRIPT.new()
		as MovementReachableFieldJob
	)
	job.reachable_builder.configure(
		unit.grid_position,
		navigation,
		job.available_capacity_feet,
		job.planning_diagonal_steps
	)
	_reachable_field_builds += 1
	_last_plan_diagnostics["reachable_field_builds"] = int(
		_last_plan_diagnostics.get("reachable_field_builds", 0)
	) + 1


func _step_reachable_field(
	job: EnemyActivationPlanningJob,
	deadline_usec: int
) -> bool:
	var started_usec: int = Time.get_ticks_usec()
	if job.reachable_builder == null:
		var unit: TacticalUnitState = _state_store.state.get_unit(job.unit_id)
		if unit == null:
			job.plan.configure_failure("The acting enemy no longer exists.")
			job.mark_complete()
			return true
		_begin_job_reachable_field(job, unit)
	var completed: bool = job.reachable_builder.step(deadline_usec, 512)
	_last_plan_diagnostics["reachable_field_usec"] = int(
		_last_plan_diagnostics.get("reachable_field_usec", 0)
	) + maxi(0, Time.get_ticks_usec() - started_usec)
	if not completed:
		return false
	job.reachable_field = job.reachable_builder.result()
	job.reachable_tiles = job.reachable_field.reachable_tiles()
	_reachable_tiles_generated += job.reachable_field.reachable_tile_count()
	_pathfinding_expansions += job.reachable_field.pathfinding_expansions
	_last_plan_diagnostics["reachable_tile_count"] = (
		job.reachable_field.reachable_tile_count()
	)
	_last_plan_diagnostics["pathfinding_expansions"] = (
		job.reachable_field.pathfinding_expansions
	)
	if job.revealed_targets.is_empty():
		job.stage = EnemyActivationPlanningJob.STAGE_NO_TARGET_FINALISE
	else:
		job.target_index = 0
		job.stage = EnemyActivationPlanningJob.STAGE_TARGET_SCORING
	return true


func _step_target_scoring(job: EnemyActivationPlanningJob) -> void:
	var started_usec: int = Time.get_ticks_usec()
	var unit: TacticalUnitState = _state_store.state.get_unit(job.unit_id)
	if unit == null:
		job.plan.configure_failure("The acting enemy no longer exists.")
		job.mark_complete()
		return
	if job.target_index >= job.revealed_targets.size():
		_finalize_combat_job(job, unit)
		_last_plan_diagnostics["candidate_scoring_usec"] = int(
			_last_plan_diagnostics.get("candidate_scoring_usec", 0)
		) + maxi(0, Time.get_ticks_usec() - started_usec)
		return
	job.current_target = job.revealed_targets[job.target_index]
	job.current_candidate_priority = 0
	job.current_path_reaches_attack_position = false
	if job.attack.attack_kind == AttackDefinition.ATTACK_RANGED:
		job.bounded_ranged_candidates.clear()
		job.ranged_scan_index = 0
		job.ranged_exact_index = 0
		job.ranged_best_tile = Vector2i(-1, -1)
		job.ranged_best_score = -2_000_000_000
		job.stage = (
			EnemyActivationPlanningJob.STAGE_RANGED_CANDIDATE_SCAN
		)
	else:
		_begin_targeted_melee_attack_search(job, unit)
	_last_plan_diagnostics["candidate_scoring_usec"] = int(
		_last_plan_diagnostics.get("candidate_scoring_usec", 0)
	) + maxi(0, Time.get_ticks_usec() - started_usec)


func _step_ranged_candidate_scan(
	job: EnemyActivationPlanningJob,
	deadline_usec: int
) -> bool:
	var started_usec: int = Time.get_ticks_usec()
	var unit: TacticalUnitState = _state_store.state.get_unit(job.unit_id)
	if unit == null or job.current_target == null:
		job.plan.configure_failure("The ranged planning target is unavailable.")
		job.mark_complete()
		return true
	var processed: int = 0
	while job.ranged_scan_index < job.reachable_tiles.size():
		if processed >= 512 or Time.get_ticks_usec() >= deadline_usec:
			_last_plan_diagnostics["candidate_scoring_usec"] = int(
				_last_plan_diagnostics.get("candidate_scoring_usec", 0)
			) + maxi(0, Time.get_ticks_usec() - started_usec)
			return false
		var candidate: Vector2i = job.reachable_tiles[job.ranged_scan_index]
		job.ranged_scan_index += 1
		processed += 1
		var movement_cost: int = job.reachable_field.cost_to(candidate)
		if (
			movement_cost < 0
			or movement_cost + job.attack_cost_feet
			> job.available_capacity_feet
		):
			continue
		if not _ranged_position_is_plausible(
			candidate,
			job.current_target,
			job.attack
		):
			continue
		_ranged_candidate_tiles_scored += 1
		_last_plan_diagnostics["cheap_candidates_considered"] = int(
			_last_plan_diagnostics.get("cheap_candidates_considered", 0)
		) + 1
		_last_plan_diagnostics["candidate_count"] = int(
			_last_plan_diagnostics.get("candidate_count", 0)
		) + 1
		_insert_bounded_ranged_candidate(
			job.bounded_ranged_candidates,
			{
				"tile": candidate,
				"score": _cheap_ranged_position_score(
					job.current_target,
					candidate,
					job.attack,
					movement_cost
				),
			}
		)
	_last_plan_diagnostics["bounded_shortlist_count"] = maxi(
		int(_last_plan_diagnostics.get("bounded_shortlist_count", 0)),
		job.bounded_ranged_candidates.size()
	)
	job.stage = EnemyActivationPlanningJob.STAGE_RANGED_EXACT_GEOMETRY
	_last_plan_diagnostics["candidate_scoring_usec"] = int(
		_last_plan_diagnostics.get("candidate_scoring_usec", 0)
	) + maxi(0, Time.get_ticks_usec() - started_usec)
	return true


func _step_ranged_exact_geometry(
	job: EnemyActivationPlanningJob,
	deadline_usec: int
) -> bool:
	var started_usec: int = Time.get_ticks_usec()
	var unit: TacticalUnitState = _state_store.state.get_unit(job.unit_id)
	if unit == null or job.current_target == null:
		job.plan.configure_failure("The ranged planning target is unavailable.")
		job.mark_complete()
		return true
	var processed: int = 0
	while job.ranged_exact_index < job.bounded_ranged_candidates.size():
		if processed >= RANGED_EXACT_SHORTLIST_SIZE or Time.get_ticks_usec() >= deadline_usec:
			_last_plan_diagnostics["exact_geometry_usec"] = int(
				_last_plan_diagnostics.get("exact_geometry_usec", 0)
			) + maxi(0, Time.get_ticks_usec() - started_usec)
			return false
		var entry: Dictionary = (
			job.bounded_ranged_candidates[job.ranged_exact_index]
		)
		job.ranged_exact_index += 1
		processed += 1
		var candidate: Vector2i = Vector2i(
			entry.get("tile", Vector2i(-1, -1))
		)
		var movement_cost: int = job.reachable_field.cost_to(candidate)
		if movement_cost < 0:
			continue
		_ranged_exact_candidates_evaluated += 1
		_last_plan_diagnostics["exact_candidates_evaluated"] = int(
			_last_plan_diagnostics.get("exact_candidates_evaluated", 0)
		) + 1
		if not _ranged_position_can_attack(
			candidate,
			job.current_target,
			job.attack,
			unit
		):
			continue
		var defence_geometry: TacticalCombatGeometryResult = _geometry_between(
			job.current_target,
			unit,
			null,
			Vector2(candidate) + Vector2(0.5, 0.5)
		)
		var score: int = 500 - movement_cost
		match defence_geometry.cover_category:
			TacticalCombatGeometryResult.COVER_HEAVY:
				score += 300
			TacticalCombatGeometryResult.COVER_LIGHT:
				score += 150
			TacticalCombatGeometryResult.COVER_TOTAL:
				score += 340
		if TacticalGridDistance.steps_between(
			candidate,
			job.current_target.grid_position
		) <= 1:
			score -= 250
		if (
			score > job.ranged_best_score
			or (
				score == job.ranged_best_score
				and _tile_precedes(candidate, job.ranged_best_tile)
			)
		):
			job.ranged_best_score = score
			job.ranged_best_tile = candidate
	_last_plan_diagnostics["exact_geometry_usec"] = int(
		_last_plan_diagnostics.get("exact_geometry_usec", 0)
	) + maxi(0, Time.get_ticks_usec() - started_usec)
	if job.ranged_best_tile.x >= 0:
		var path: MovementPathResult = job.reachable_field.path_to(
			job.ranged_best_tile
		)
		_commit_job_target_candidate(job, path, true, 2)
		job.target_index += 1
		job.stage = EnemyActivationPlanningJob.STAGE_TARGET_SCORING
	else:
		_begin_approach_scan(job)
	return true


func _begin_targeted_melee_attack_search(
		job: EnemyActivationPlanningJob,
		unit: TacticalUnitState
) -> void:
	var reach_feet: int = 5
	if job.attack != null and job.attack.range_profile != null:
		reach_feet = maxi(5, job.attack.range_profile.reach_feet)
	job.targeted_goal_tiles = _candidate_attack_positions(
		unit,
		job.current_target,
		reach_feet
	)
	# A failed direct attack from the current tile must not be turned into a
	# zero-distance move-and-attack plan merely because it is inside reach.
	job.targeted_goal_tiles.erase(unit.grid_position)
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	job.targeted_search = (
		MOVEMENT_TARGETED_SEARCH_JOB_SCRIPT.new()
		as MovementTargetedSearchJob
	)
	var movement_capacity: int = maxi(
		0,
		job.available_capacity_feet - job.attack_cost_feet
	)
	job.targeted_search.configure(
		unit.grid_position,
		navigation,
		job.targeted_goal_tiles,
		movement_capacity,
		job.planning_diagonal_steps
	)
	job.targeted_search_accounted_expansions = 0
	_targeted_melee_search_builds += 1
	_last_plan_diagnostics["targeted_melee_search_builds"] = int(
		_last_plan_diagnostics.get("targeted_melee_search_builds", 0)
	) + 1
	_last_plan_diagnostics["targeted_melee_attack_searches"] = int(
		_last_plan_diagnostics.get("targeted_melee_attack_searches", 0)
	) + 1
	_last_plan_diagnostics["targeted_melee_goal_count"] = maxi(
		int(_last_plan_diagnostics.get("targeted_melee_goal_count", 0)),
		job.targeted_goal_tiles.size()
	)
	_last_plan_diagnostics["targeted_melee_attack_capacity_feet"] = (
		movement_capacity
	)
	job.stage = EnemyActivationPlanningJob.STAGE_TARGETED_MELEE_ATTACK_SEARCH


func _step_targeted_melee_attack_search(
		job: EnemyActivationPlanningJob,
		deadline_usec: int
) -> bool:
	var started_usec: int = Time.get_ticks_usec()
	if job.targeted_search == null:
		var unit: TacticalUnitState = _state_store.state.get_unit(job.unit_id)
		if unit == null or job.current_target == null:
			job.plan.configure_failure("The targeted melee planning state is unavailable.")
			job.mark_complete()
			return true
		_begin_targeted_melee_attack_search(job, unit)
	var completed: bool = job.targeted_search.step(deadline_usec, 1024)
	_account_targeted_search_expansions(job)
	_last_plan_diagnostics["targeted_melee_search_usec"] = int(
		_last_plan_diagnostics.get("targeted_melee_search_usec", 0)
	) + maxi(0, Time.get_ticks_usec() - started_usec)
	if not completed:
		return false
	var path: MovementPathResult = job.targeted_search.result()
	if path != null and path.success:
		_commit_job_target_candidate(job, path, true, 2)
		job.target_index += 1
		job.targeted_search = null
		job.stage = EnemyActivationPlanningJob.STAGE_TARGET_SCORING
		return true
	var unit: TacticalUnitState = _state_store.state.get_unit(job.unit_id)
	if unit == null:
		job.plan.configure_failure("The acting enemy no longer exists.")
		job.mark_complete()
		return true
	_begin_targeted_melee_approach_search(job, unit)
	return true


func _begin_targeted_melee_approach_search(
		job: EnemyActivationPlanningJob,
		unit: TacticalUnitState
) -> void:
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	job.targeted_search = (
		MOVEMENT_TARGETED_SEARCH_JOB_SCRIPT.new()
		as MovementTargetedSearchJob
	)
	# Find one shortest route toward a legal attack tile, then retain only the
	# affordable prefix. This avoids generating and scoring every reachable tile.
	job.targeted_search.configure(
		unit.grid_position,
		navigation,
		job.targeted_goal_tiles,
		-1,
		job.planning_diagonal_steps
	)
	job.targeted_search_accounted_expansions = 0
	_targeted_melee_search_builds += 1
	_last_plan_diagnostics["targeted_melee_search_builds"] = int(
		_last_plan_diagnostics.get("targeted_melee_search_builds", 0)
	) + 1
	_last_plan_diagnostics["targeted_melee_approach_searches"] = int(
		_last_plan_diagnostics.get("targeted_melee_approach_searches", 0)
	) + 1
	job.stage = EnemyActivationPlanningJob.STAGE_TARGETED_MELEE_APPROACH_SEARCH


func _step_targeted_melee_approach_search(
		job: EnemyActivationPlanningJob,
		deadline_usec: int
) -> bool:
	var started_usec: int = Time.get_ticks_usec()
	if job.targeted_search == null:
		var missing_unit: TacticalUnitState = _state_store.state.get_unit(job.unit_id)
		if missing_unit == null:
			job.plan.configure_failure("The acting enemy no longer exists.")
			job.mark_complete()
			return true
		_begin_targeted_melee_approach_search(job, missing_unit)
	var completed: bool = job.targeted_search.step(deadline_usec, 1024)
	_account_targeted_search_expansions(job)
	_last_plan_diagnostics["targeted_melee_search_usec"] = int(
		_last_plan_diagnostics.get("targeted_melee_search_usec", 0)
	) + maxi(0, Time.get_ticks_usec() - started_usec)
	if not completed:
		return false
	var unit: TacticalUnitState = _state_store.state.get_unit(job.unit_id)
	var full_path: MovementPathResult = job.targeted_search.result()
	if unit != null and full_path != null and full_path.success:
		var approach_path: MovementPathResult = _affordable_path_prefix(
			unit,
			full_path.path,
			job.available_capacity_feet,
			job.planning_diagonal_steps
		)
		if (
			approach_path != null
			and approach_path.success
			and approach_path.path.size() > 1
		):
			_commit_job_target_candidate(job, approach_path, false, 1)
	job.target_index += 1
	job.targeted_search = null
	job.stage = EnemyActivationPlanningJob.STAGE_TARGET_SCORING
	return true


func _account_targeted_search_expansions(
		job: EnemyActivationPlanningJob
) -> void:
	if job == null or job.targeted_search == null:
		return
	var current_expansions: int = job.targeted_search.pathfinding_expansions
	var delta: int = maxi(
		0,
		current_expansions - job.targeted_search_accounted_expansions
	)
	if delta <= 0:
		return
	job.targeted_search_accounted_expansions = current_expansions
	_pathfinding_expansions += delta
	_targeted_melee_expansions += delta
	_last_plan_diagnostics["targeted_melee_expansions"] = int(
		_last_plan_diagnostics.get("targeted_melee_expansions", 0)
	) + delta
	_last_plan_diagnostics["pathfinding_expansions"] = int(
		_last_plan_diagnostics.get("pathfinding_expansions", 0)
	) + delta


func _affordable_path_prefix(
		unit: TacticalUnitState,
		path: Array[Vector2i],
		maximum_cost_feet: int,
		diagonal_steps_already_used: int
) -> MovementPathResult:
	if unit == null or path.is_empty():
		return MovementPathResult.failed("The targeted approach path is empty.")
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var prefix: Array[Vector2i] = [path[0]]
	var accumulated_cost: int = 0
	var diagonal_steps: int = 0
	var diagonal_parity: int = diagonal_steps_already_used % 2
	for path_index: int in range(1, path.size()):
		var previous: Vector2i = path[path_index - 1]
		var current: Vector2i = path[path_index]
		var step_cost: int = MovementRules.movement_step_cost(
			previous,
			current,
			navigation,
			diagonal_parity
		)
		if step_cost < 0 or accumulated_cost + step_cost > maximum_cost_feet:
			break
		accumulated_cost += step_cost
		var delta: Vector2i = current - previous
		if delta.x != 0 and delta.y != 0:
			diagonal_parity = 1 - diagonal_parity
			diagonal_steps += 1
		prefix.append(current)
	return MovementPathResult.completed(prefix, accumulated_cost, diagonal_steps)


func _begin_approach_scan(job: EnemyActivationPlanningJob) -> void:
	job.approach_scan_index = 0
	job.approach_best_tile = Vector2i(-1, -1)
	job.approach_best_distance = 1_000_000
	job.approach_best_cost = 1_000_000_000
	job.stage = EnemyActivationPlanningJob.STAGE_APPROACH_SCAN


func _step_approach_scan(
	job: EnemyActivationPlanningJob,
	deadline_usec: int
) -> bool:
	var started_usec: int = Time.get_ticks_usec()
	var processed: int = 0
	while job.approach_scan_index < job.reachable_tiles.size():
		if processed >= 512 or Time.get_ticks_usec() >= deadline_usec:
			_last_plan_diagnostics["candidate_scoring_usec"] = int(
				_last_plan_diagnostics.get("candidate_scoring_usec", 0)
			) + maxi(0, Time.get_ticks_usec() - started_usec)
			return false
		var candidate: Vector2i = job.reachable_tiles[job.approach_scan_index]
		job.approach_scan_index += 1
		processed += 1
		var distance: int = TacticalGridDistance.steps_between(
			candidate,
			job.current_target.grid_position
		)
		var movement_cost: int = job.reachable_field.cost_to(candidate)
		if movement_cost < 0:
			continue
		if (
			job.approach_best_tile.x < 0
			or distance < job.approach_best_distance
			or (
				distance == job.approach_best_distance
				and movement_cost < job.approach_best_cost
			)
			or (
				distance == job.approach_best_distance
				and movement_cost == job.approach_best_cost
				and _tile_precedes(candidate, job.approach_best_tile)
			)
		):
			job.approach_best_tile = candidate
			job.approach_best_distance = distance
			job.approach_best_cost = movement_cost
	if job.approach_best_tile.x >= 0:
		var path: MovementPathResult = job.reachable_field.path_to(
			job.approach_best_tile
		)
		_commit_job_target_candidate(job, path, false, 1)
	job.target_index += 1
	job.stage = EnemyActivationPlanningJob.STAGE_TARGET_SCORING
	_last_plan_diagnostics["candidate_scoring_usec"] = int(
		_last_plan_diagnostics.get("candidate_scoring_usec", 0)
	) + maxi(0, Time.get_ticks_usec() - started_usec)
	return true


func _commit_job_target_candidate(
	job: EnemyActivationPlanningJob,
	path: MovementPathResult,
	path_reaches_attack_position: bool,
	candidate_priority: int
) -> void:
	if path == null or not path.success or job.current_target == null:
		return
	var destination: Vector2i = path.path.back()
	var remaining_steps: int = TacticalGridDistance.steps_between(
		destination,
		job.current_target.grid_position
	)
	var candidate_score: int = (
		candidate_priority * 1_000_000
		- remaining_steps * 1_000
		- path.cost_feet
	)
	if (
		job.best_target == null
		or candidate_score > job.best_candidate_score
		or (
			candidate_score == job.best_candidate_score
			and String(job.current_target.unit_id)
			< String(job.best_target.unit_id)
		)
	):
		job.best_target = job.current_target
		job.best_path = path
		job.best_path_reaches_attack_position = (
			path_reaches_attack_position
		)
		job.best_candidate_score = candidate_score


func _finalize_combat_job(
	job: EnemyActivationPlanningJob,
	unit: TacticalUnitState
) -> void:
	if job.best_target == null or job.best_path == null:
		job.plan.configure_failure(
			"%s cannot reach or approach an active revealed hostile target."
			% unit.display_name
		)
		job.mark_complete()
		return
	var destination: Vector2i = job.best_path.path.back()
	var attack_after_move: bool = (
		job.best_path_reaches_attack_position
		and job.best_path.cost_feet + job.attack_cost_feet
		<= job.available_capacity_feet
	)
	job.plan.configure_success(
		job.action_id,
		job.best_target.unit_id,
		destination,
		destination != unit.grid_position,
		attack_after_move,
		job.best_path.cost_feet,
		job.best_path.path
	)
	job.mark_complete()


func _step_no_target_finalise(job: EnemyActivationPlanningJob) -> void:
	var unit: TacticalUnitState = _state_store.state.get_unit(job.unit_id)
	if unit == null:
		job.plan.configure_failure("The acting enemy no longer exists.")
		job.mark_complete()
		return
	var squad: TacticalSquadState = _state_store.state.get_squad(unit.squad_id)
	job.no_target_memory_ids.clear()
	job.no_target_memory_index = 0
	job.no_target_best_memory_id = &""
	job.no_target_best_goal = Vector2i(-1, -1)
	job.no_target_best_path = null
	job.no_target_best_distance = 1_000_000
	if squad != null and squad.is_searching():
		job.no_target_memory_ids = squad.last_seen_unit_ids()
		job.no_target_memory_ids.sort_custom(
			func(a: StringName, b: StringName) -> bool:
				return String(a) < String(b)
		)
	if not job.no_target_memory_ids.is_empty():
		_begin_no_target_memory_goal(job, squad)
		return
	_begin_no_target_task_goal_or_fail(job, unit)


func _begin_no_target_memory_goal(
	job: EnemyActivationPlanningJob,
	squad: TacticalSquadState
) -> void:
	if (
		squad == null
		or job.no_target_memory_index < 0
		or job.no_target_memory_index >= job.no_target_memory_ids.size()
	):
		return
	var memory_id: StringName = (
		job.no_target_memory_ids[job.no_target_memory_index]
	)
	_begin_no_target_goal_scan(
		job,
		squad.last_seen_position(memory_id),
		true,
		memory_id,
		false
	)


func _begin_no_target_task_goal_or_fail(
	job: EnemyActivationPlanningJob,
	unit: TacticalUnitState
) -> void:
	var task_goal: Vector2i = unit.assigned_task_position
	if task_goal.x >= 0 and task_goal.y >= 0:
		_begin_no_target_goal_scan(
			job,
			task_goal,
			false,
			&"",
			true
		)
		return
	job.plan.configure_failure(
		"%s has no revealed target or Last Seen Position and remains on task."
		% unit.display_name
	)
	job.mark_complete()


func _begin_no_target_goal_scan(
	job: EnemyActivationPlanningJob,
	goal: Vector2i,
	allow_adjacent: bool,
	memory_id: StringName,
	task_mode: bool
) -> void:
	job.no_target_current_goal = goal
	job.no_target_allow_adjacent = allow_adjacent
	job.no_target_current_memory_id = memory_id
	job.no_target_task_mode = task_mode
	job.no_target_scan_index = 0
	job.no_target_goal_best_tile = Vector2i(-1, -1)
	job.no_target_goal_best_distance = 1_000_000
	job.no_target_goal_best_cost = 1_000_000_000
	job.stage = EnemyActivationPlanningJob.STAGE_NO_TARGET_GOAL_SCAN


func _step_no_target_goal_scan(
	job: EnemyActivationPlanningJob,
	deadline_usec: int
) -> bool:
	var started_usec: int = Time.get_ticks_usec()
	var unit: TacticalUnitState = _state_store.state.get_unit(job.unit_id)
	if unit == null:
		job.plan.configure_failure("The acting enemy no longer exists.")
		job.mark_complete()
		return true
	var processed: int = 0
	while job.no_target_scan_index < job.reachable_tiles.size():
		if processed >= 512 or Time.get_ticks_usec() >= deadline_usec:
			_last_plan_diagnostics["candidate_scoring_usec"] = int(
				_last_plan_diagnostics.get("candidate_scoring_usec", 0)
			) + maxi(0, Time.get_ticks_usec() - started_usec)
			return false
		var candidate: Vector2i = job.reachable_tiles[job.no_target_scan_index]
		job.no_target_scan_index += 1
		processed += 1
		var distance: int = TacticalGridDistance.steps_between(
			candidate,
			job.no_target_current_goal
		)
		var effective_distance: int = maxi(
			0,
			distance - (1 if job.no_target_allow_adjacent else 0)
		)
		var movement_cost: int = job.reachable_field.cost_to(candidate)
		if movement_cost < 0:
			continue
		if (
			job.no_target_goal_best_tile.x < 0
			or effective_distance < job.no_target_goal_best_distance
			or (
				effective_distance == job.no_target_goal_best_distance
				and movement_cost < job.no_target_goal_best_cost
			)
			or (
				effective_distance == job.no_target_goal_best_distance
				and movement_cost == job.no_target_goal_best_cost
				and _tile_precedes(
					candidate,
					job.no_target_goal_best_tile
				)
			)
		):
			job.no_target_goal_best_tile = candidate
			job.no_target_goal_best_distance = effective_distance
			job.no_target_goal_best_cost = movement_cost
	_last_plan_diagnostics["candidate_scoring_usec"] = int(
		_last_plan_diagnostics.get("candidate_scoring_usec", 0)
	) + maxi(0, Time.get_ticks_usec() - started_usec)
	var path: MovementPathResult = null
	if job.no_target_goal_best_tile.x >= 0:
		path = job.reachable_field.path_to(job.no_target_goal_best_tile)
	if job.no_target_task_mode:
		if path != null and path.success:
			var destination: Vector2i = path.path.back()
			job.plan.configure_return_to_task(
				job.no_target_current_goal,
				destination,
				destination != unit.grid_position,
				destination == job.no_target_current_goal,
				path.cost_feet,
				path.path
			)
		else:
			job.plan.configure_failure(
				"%s cannot return to its assigned task." % unit.display_name
			)
		job.mark_complete()
		return true

	if path != null and path.success:
		var actual_distance: int = TacticalGridDistance.steps_between(
			path.path.back(),
			job.no_target_current_goal
		)
		if (
			job.no_target_best_path == null
			or actual_distance < job.no_target_best_distance
			or (
				actual_distance == job.no_target_best_distance
				and path.cost_feet < job.no_target_best_path.cost_feet
			)
			or (
				actual_distance == job.no_target_best_distance
				and path.cost_feet == job.no_target_best_path.cost_feet
				and String(job.no_target_current_memory_id)
				< String(job.no_target_best_memory_id)
			)
		):
			job.no_target_best_memory_id = job.no_target_current_memory_id
			job.no_target_best_goal = job.no_target_current_goal
			job.no_target_best_path = path
			job.no_target_best_distance = actual_distance

	job.no_target_memory_index += 1
	var squad: TacticalSquadState = _state_store.state.get_squad(unit.squad_id)
	if (
		squad != null
		and job.no_target_memory_index < job.no_target_memory_ids.size()
	):
		_begin_no_target_memory_goal(job, squad)
		return true
	if job.no_target_best_path != null:
		var search_destination: Vector2i = job.no_target_best_path.path.back()
		var reached: bool = _search_goal_reached(
			unit,
			search_destination,
			job.no_target_best_goal
		)
		job.plan.configure_search(
			job.no_target_best_memory_id,
			job.no_target_best_goal,
			search_destination,
			search_destination != unit.grid_position,
			reached,
			job.no_target_best_path.cost_feet,
			job.no_target_best_path.path
		)
		job.mark_complete()
		return true
	_begin_no_target_task_goal_or_fail(job, unit)
	return true


func _insert_bounded_ranged_candidate(
	shortlist: Array[Dictionary],
	candidate: Dictionary
) -> void:
	var insert_index: int = 0
	while (
		insert_index < shortlist.size()
		and _ranged_candidate_precedes(shortlist[insert_index], candidate)
	):
		insert_index += 1
	shortlist.insert(insert_index, candidate)
	while shortlist.size() > RANGED_EXACT_SHORTLIST_SIZE:
		shortlist.pop_back()


func _ranged_candidate_precedes(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var score_a: int = int(a.get("score", -2_000_000_000))
	var score_b: int = int(b.get("score", -2_000_000_000))
	if score_a != score_b:
		return score_a > score_b
	var tile_a: Vector2i = Vector2i(a.get("tile", Vector2i.ZERO))
	var tile_b: Vector2i = Vector2i(b.get("tile", Vector2i.ZERO))
	return tile_a.y < tile_b.y or (
		tile_a.y == tile_b.y and tile_a.x < tile_b.x
	)


func _finalize_job_diagnostics(job: EnemyActivationPlanningJob) -> void:
	_last_plan_diagnostics["total_usec"] = (
		maxi(0, Time.get_ticks_usec() - job.started_usec)
		if job != null
		else 0
	)
	_last_plan_diagnostics["processing_usec"] = (
		job.accumulated_processing_usec if job != null else 0
	)
	_last_plan_diagnostics["planning_slices"] = (
		job.processing_slices if job != null else 0
	)
	_last_plan_diagnostics["planning_stage"] = EnemyActivationPlanningJob.STAGE_COMPLETE
	_last_plan_diagnostics["plan_kind"] = (
		StringName(job.plan.kind)
		if (
			job != null
			and job.plan != null
			and job.plan.valid
		)
		else &"failure"
	)


func _build_reachable_field(unit: TacticalUnitState) -> MovementReachableField:
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var field: MovementReachableField = MovementRules.build_reachable_field(
		unit.grid_position,
		navigation,
		unit.action_budget.remaining_turn_capacity_feet,
		unit.diagonal_steps_used
	)
	_reachable_field_builds += 1
	_reachable_tiles_generated += field.reachable_tile_count()
	_pathfinding_expansions += field.pathfinding_expansions
	return field


func _finalize_plan_diagnostics(
		planning_started_usec: int,
		plan: RefCounted
) -> void:
	_last_plan_diagnostics["total_usec"] = maxi(
		0, Time.get_ticks_usec() - planning_started_usec
	)
	_last_plan_diagnostics["plan_kind"] = (
		StringName(plan.get("kind"))
		if plan != null and bool(plan.get("valid"))
		else &"failure"
	)
	_last_plan_diagnostics["cheap_candidates_considered"] = int(
		_last_plan_diagnostics.get("cheap_candidates_considered", 0)
	)
	_last_plan_diagnostics["exact_candidates_evaluated"] = int(
		_last_plan_diagnostics.get("exact_candidates_evaluated", 0)
	)


func _revealed_hostile_targets(
		unit: TacticalUnitState
) -> Array[TacticalUnitState]:
	var result: Array[TacticalUnitState] = []
	for target: TacticalUnitState in _state_store.state.get_units():
		if (
			target == null
			or target.unit_id == unit.unit_id
			or target.is_defeated()
			or not TEAM_RELATIONS_SCRIPT.are_hostile(unit.team_id, target.team_id)
		):
			continue
		if (
			target.team_id == &"player"
			and (
				unit.squad_id.is_empty()
				or not _state_store.state.is_unit_revealed_to_squad(
					target.unit_id,
					unit.squad_id
				)
			)
		):
			continue
		result.append(target)
	return result


func _plan_search_or_return(
		unit: TacticalUnitState,
		plan: RefCounted,
		reachable_field: MovementReachableField
) -> void:
	var squad: TacticalSquadState = _state_store.state.get_squad(unit.squad_id)
	if squad != null and squad.is_searching():
		var best_memory_id: StringName = &""
		var best_goal: Vector2i = Vector2i(-1, -1)
		var best_path: MovementPathResult = null
		var best_distance: int = 1_000_000
		for memory_unit_id: StringName in squad.last_seen_unit_ids():
			var goal: Vector2i = squad.last_seen_position(memory_unit_id)
			var path: MovementPathResult = _best_path_to_goal_area(
				unit, goal, true, reachable_field
			)
			if path == null or not path.success:
				continue
			var distance: int = TacticalGridDistance.steps_between(path.path.back(), goal)
			if (
				best_path == null
				or distance < best_distance
				or (distance == best_distance and path.cost_feet < best_path.cost_feet)
				or (
					distance == best_distance
					and path.cost_feet == best_path.cost_feet
					and String(memory_unit_id) < String(best_memory_id)
				)
			):
				best_memory_id = memory_unit_id
				best_goal = goal
				best_path = path
				best_distance = distance
		if best_path != null:
			var search_destination: Vector2i = best_path.path.back()
			var reached: bool = _search_goal_reached(unit, search_destination, best_goal)
			plan.call(
				"configure_search",
				best_memory_id,
				best_goal,
				search_destination,
				search_destination != unit.grid_position,
				reached,
				best_path.cost_feet,
				best_path.path
			)
			return

	var task_goal: Vector2i = unit.assigned_task_position
	if task_goal.x >= 0 and task_goal.y >= 0:
		var return_path: MovementPathResult = _best_path_to_goal_area(
			unit, task_goal, false, reachable_field
		)
		if return_path != null and return_path.success:
			var return_destination: Vector2i = return_path.path.back()
			plan.call(
				"configure_return_to_task",
				task_goal,
				return_destination,
				return_destination != unit.grid_position,
				return_destination == task_goal,
				return_path.cost_feet,
				return_path.path
			)
			return

	plan.call(
		"configure_failure",
		"%s has no revealed target or Last Seen Position and remains on task."
		% unit.display_name
	)


func _preferred_attack_action(unit: TacticalUnitState) -> StringName:
	if _catalogue == null or _attack_preview_query == null:
		return &""
	var profile: TacticalAIProfileDefinition = _catalogue.ai_profile(unit.ai_profile_id)
	if profile != null and profile.role == TacticalAIProfileDefinition.ROLE_CIVILIAN:
		return &""
	var best_action_id: StringName = &""
	var best_score: int = -1000000
	for action_id: StringName in _state_store.state.granted_action_ids_for_unit(
		unit.unit_id
	):
		var attack: AttackDefinition = _catalogue.attack_definition(action_id)
		if attack == null:
			continue
		var supported_value: Variant = _attack_preview_query.call(
			"is_supported_ai_action",
			action_id
		)
		if not bool(supported_value):
			continue
		var score: int = _attack_preference_score(attack)
		if profile != null:
			score += profile.attack_preference_bonus(attack)
		if (
			score > best_score
			or (score == best_score and String(action_id) < String(best_action_id))
		):
			best_score = score
			best_action_id = action_id
	return best_action_id


func _attack_preference_score(attack: AttackDefinition) -> int:
	if attack == null or attack.range_profile == null:
		return 0
	if attack.attack_kind == AttackDefinition.ATTACK_RANGED:
		return (
			100000
			+ attack.range_profile.range_increment_feet
			* maxi(1, attack.range_profile.maximum_increments)
		)
	return maxi(5, attack.range_profile.reach_feet)


func _candidate_precedes(
		target: TacticalUnitState,
		path: MovementPathResult,
		current_target: TacticalUnitState,
		current_path: MovementPathResult
) -> bool:
	if current_path == null:
		return true
	if path.cost_feet != current_path.cost_feet:
		return path.cost_feet < current_path.cost_feet
	return str(target.unit_id) < str(current_target.unit_id)


func _best_path_to_attack_position(
		unit: TacticalUnitState,
		target: TacticalUnitState,
		reach_feet: int,
		reachable_field: MovementReachableField,
		reserved_attack_cost_feet: int,
		available_capacity_feet: int = -1
) -> MovementPathResult:
	if reachable_field == null:
		return null
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_cost: int = 1_000_000_000
	for candidate: Vector2i in _candidate_attack_positions(unit, target, reach_feet):
		if not reachable_field.has_tile(candidate):
			continue
		var movement_cost: int = reachable_field.cost_to(candidate)
		if (
			movement_cost < 0
			or movement_cost + reserved_attack_cost_feet
			> (
				available_capacity_feet
				if available_capacity_feet >= 0
				else unit.action_budget.remaining_turn_capacity_feet
			)
		):
			continue
		if (
			movement_cost < best_cost
			or (
				movement_cost == best_cost
				and _tile_precedes(candidate, best_tile)
			)
		):
			best_tile = candidate
			best_cost = movement_cost
	return (
		reachable_field.path_to(best_tile)
		if best_tile.x >= 0 and best_tile.y >= 0
		else null
	)


func _best_path_to_ranged_attack_position(
		unit: TacticalUnitState,
		target: TacticalUnitState,
		attack: AttackDefinition,
		reachable_field: MovementReachableField,
		reserved_attack_cost_feet: int
) -> MovementPathResult:
	if attack == null or attack.range_profile == null or reachable_field == null:
		return null

	var cheap_candidates: Array[Dictionary] = []
	for candidate: Vector2i in reachable_field.reachable_tiles():
		if not _state_store.state.can_place_unit(
			unit, candidate, _map_definition, unit.unit_id
		):
			continue
		var movement_cost: int = reachable_field.cost_to(candidate)
		if (
			movement_cost < 0
			or movement_cost + reserved_attack_cost_feet
			> unit.action_budget.remaining_turn_capacity_feet
		):
			continue
		if not _ranged_position_is_plausible(candidate, target, attack):
			continue
		_ranged_candidate_tiles_scored += 1
		_last_plan_diagnostics["cheap_candidates_considered"] = int(
			_last_plan_diagnostics.get("cheap_candidates_considered", 0)
		) + 1
		cheap_candidates.append({
			"tile": candidate,
			"score": _cheap_ranged_position_score(
				target, candidate, attack, movement_cost
			),
		})
	cheap_candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var score_a: int = int(a.get("score", -1000000))
			var score_b: int = int(b.get("score", -1000000))
			if score_a != score_b:
				return score_a > score_b
			var tile_a: Vector2i = Vector2i(a.get("tile", Vector2i.ZERO))
			var tile_b: Vector2i = Vector2i(b.get("tile", Vector2i.ZERO))
			return tile_a.y < tile_b.y or (tile_a.y == tile_b.y and tile_a.x < tile_b.x)
	)

	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_score: int = -1000000
	var exact_count: int = mini(RANGED_EXACT_SHORTLIST_SIZE, cheap_candidates.size())
	var exact_started_usec: int = Time.get_ticks_usec()
	for index: int in range(exact_count):
		var candidate: Vector2i = Vector2i(
			cheap_candidates[index].get("tile", Vector2i.ZERO)
		)
		var movement_cost: int = reachable_field.cost_to(candidate)
		if movement_cost < 0:
			continue
		_ranged_exact_candidates_evaluated += 1
		_last_plan_diagnostics["exact_candidates_evaluated"] = int(
			_last_plan_diagnostics.get("exact_candidates_evaluated", 0)
		) + 1
		if not _ranged_position_can_attack(candidate, target, attack, unit):
			continue
		var defence_geometry: TacticalCombatGeometryResult = _geometry_between(
			target,
			unit,
			null,
			Vector2(candidate) + Vector2(0.5, 0.5)
		)
		var score: int = 500 - movement_cost
		match defence_geometry.cover_category:
			TacticalCombatGeometryResult.COVER_HEAVY:
				score += 300
			TacticalCombatGeometryResult.COVER_LIGHT:
				score += 150
			TacticalCombatGeometryResult.COVER_TOTAL:
				score += 340
		if TacticalGridDistance.steps_between(candidate, target.grid_position) <= 1:
			score -= 250
		if (
			score > best_score
			or (
				score == best_score
				and _tile_precedes(candidate, best_tile)
			)
		):
			best_score = score
			best_tile = candidate
	_last_plan_diagnostics["exact_geometry_usec"] = int(
		_last_plan_diagnostics.get("exact_geometry_usec", 0)
	) + (Time.get_ticks_usec() - exact_started_usec)
	return (
		reachable_field.path_to(best_tile)
		if best_tile.x >= 0 and best_tile.y >= 0
		else null
	)


func _ranged_position_is_plausible(
		origin: Vector2i,
		target: TacticalUnitState,
		attack: AttackDefinition
) -> bool:
	if attack == null or attack.range_profile == null or target == null:
		return false
	var maximum_range_feet: int = (
		maxi(5, attack.range_profile.range_increment_feet)
		* maxi(1, attack.range_profile.maximum_increments)
	)
	var distance_feet: int = TacticalGridDistance.steps_between(
		origin, target.grid_position
	) * TacticalGridDistance.TILE_SIZE_FEET
	if distance_feet > maximum_range_feet:
		return false
	# A cheap centre LOS test removes obviously sealed positions. Automatic Lean
	# may still rescue a centre line obstructed only at the origin, so nearby
	# corner candidates are retained when they are directionally plausible.
	if TacticalLineOfSightRules.has_line_of_sight(
		origin,
		target.grid_position,
		_map_definition,
		_state_store.state
	):
		return true
	return _has_local_lean_edge_toward(origin, target.grid_position)


func _cheap_ranged_position_score(
		target: TacticalUnitState,
		candidate: Vector2i,
		attack: AttackDefinition,
		movement_cost_feet: int
) -> int:
	var target_distance_feet: int = TacticalGridDistance.steps_between(
		candidate, target.grid_position
	) * TacticalGridDistance.TILE_SIZE_FEET
	var preferred_range: int = maxi(5, attack.range_profile.range_increment_feet)
	var range_penalty: int = abs(target_distance_feet - preferred_range)
	return (
		500
		- movement_cost_feet
		- range_penalty
		+ _cheap_local_cover_score(candidate, target.grid_position)
	)


func _cheap_local_cover_score(
		candidate: Vector2i,
		threat_tile: Vector2i
) -> int:
	var delta: Vector2i = threat_tile - candidate
	var direction := Vector2i(
		0 if delta.x == 0 else (1 if delta.x > 0 else -1),
		0 if delta.y == 0 else (1 if delta.y > 0 else -1)
	)
	var directions: Array[Vector2i] = []
	if direction.x != 0:
		directions.append(Vector2i(direction.x, 0))
	if direction.y != 0:
		directions.append(Vector2i(0, direction.y))
	var best: int = 0
	for edge_direction: Vector2i in directions:
		var neighbour: Vector2i = candidate + edge_direction
		if not _map_definition.is_inside(neighbour):
			continue
		if _map_definition.blocks_vision(neighbour):
			best = maxi(best, 340)
		elif _state_store.state.environment_state != null:
			var height: StringName = (
				_state_store.state.environment_state.cover_height_at_edge(
					_map_definition, candidate, neighbour
				)
			)
			match height:
				TacticalBarrierSegmentDefinition.HEIGHT_LOW:
					best = maxi(best, 150)
				TacticalBarrierSegmentDefinition.HEIGHT_HIGH:
					best = maxi(best, 300)
				TacticalBarrierSegmentDefinition.HEIGHT_FULL:
					best = maxi(best, 340)
	return best


func _has_local_lean_edge_toward(
		origin: Vector2i,
		target_tile: Vector2i
) -> bool:
	return not _candidate_lean_world_origins(origin, target_tile).is_empty()


func _candidate_lean_world_origins(
		origin: Vector2i,
		target_tile: Vector2i
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var target_direction: Vector2 = Vector2(target_tile - origin).normalized()
	var environment: TacticalEnvironmentState = _state_store.state.environment_state
	if environment == null:
		return result
	for direction: Vector2i in [
		Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT
	]:
		var direction_vector: Vector2 = Vector2(direction).normalized()
		if (
			target_direction != Vector2.ZERO
			and direction_vector.dot(target_direction) < 0.05
		):
			continue
		var other: Vector2i = origin + direction
		if not _map_definition.is_inside(other):
			continue
		var opening: TacticalOpeningDefinition = _map_definition.opening_at_edge(
			origin, other
		)
		if (
			opening != null
			and not environment.edge_blocks_line_of_effect(
				_map_definition, origin, other
			)
		):
			result.append(
				Vector2(origin) + Vector2(0.5, 0.5)
				+ Vector2(direction) * 0.46
			)
			continue
		# A clear side beside an adjacent perpendicular wall is a legal corner
		# lean. This is a cheap local test; exact exposure is still sampled later.
		if _map_definition.is_blocked(other):
			continue
		var perpendiculars: Array[Vector2i] = [
			Vector2i(-direction.y, direction.x),
			Vector2i(direction.y, -direction.x),
		]
		for wall_direction: Vector2i in perpendiculars:
			var wall_tile: Vector2i = origin + wall_direction
			if (
				_map_definition.is_inside(wall_tile)
				and _map_definition.blocks_vision(wall_tile)
			):
				result.append(
					Vector2(origin) + Vector2(0.5, 0.5)
					+ Vector2(direction) * 0.46
				)
				break
	return result


func _ranged_position_can_attack(
		origin: Vector2i,
		target: TacticalUnitState,
		attack: AttackDefinition,
		attacker: TacticalUnitState
) -> bool:
	if attack == null or attack.range_profile == null or target == null:
		return false
	var maximum_range_feet: int = (
		maxi(5, attack.range_profile.range_increment_feet)
		* maxi(1, attack.range_profile.maximum_increments)
	)
	var distance_feet: int = TacticalGridDistance.steps_between(
		origin,
		target.grid_position
	) * TacticalGridDistance.TILE_SIZE_FEET
	if distance_feet > maximum_range_feet:
		return false
	var centre_world: Vector2 = Vector2(origin) + Vector2(0.5, 0.5)
	var geometry: TacticalCombatGeometryResult = _geometry_between(
		attacker, target, centre_world
	)
	if _geometry_allows_direct_attack(geometry):
		return true
	for lean_world: Vector2 in _candidate_lean_world_origins(
		origin, target.grid_position
	):
		var lean_geometry: TacticalCombatGeometryResult = _geometry_between(
			attacker, target, lean_world
		)
		if _geometry_allows_direct_attack(lean_geometry):
			return true
	return false


func _geometry_between(
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		origin_override: Variant = null,
		target_position_override: Variant = null
) -> TacticalCombatGeometryResult:
	if (
		_attack_preview_query != null
		and _attack_preview_query.has_method("combat_geometry_between")
	):
		return _attack_preview_query.call(
			"combat_geometry_between",
			attacker.unit_id,
			target.unit_id,
			origin_override,
			target_position_override
		) as TacticalCombatGeometryResult
	return TacticalCombatGeometryQuery.evaluate(
		_state_store.state,
		_map_definition,
		attacker,
		target,
		origin_override,
		target_position_override
	)


func _geometry_allows_direct_attack(
		geometry: TacticalCombatGeometryResult
) -> bool:
	return (
		geometry != null
		and geometry.has_line_of_sight
		and geometry.has_line_of_effect
		and geometry.cover_category != TacticalCombatGeometryResult.COVER_TOTAL
	)


func performance_snapshot() -> Dictionary:
	return {
		"ranged_candidate_tiles_scored": _ranged_candidate_tiles_scored,
		"ranged_exact_candidates_evaluated": _ranged_exact_candidates_evaluated,
		"ranged_shortlist_size": RANGED_EXACT_SHORTLIST_SIZE,
		"reachable_field_builds": _reachable_field_builds,
		"reachable_tiles_generated": _reachable_tiles_generated,
		"pathfinding_expansions": _pathfinding_expansions,
		"targeted_melee_search_builds": _targeted_melee_search_builds,
		"targeted_melee_expansions": _targeted_melee_expansions,
		"last_plan": _last_plan_diagnostics.duplicate(true),
	}


func last_plan_diagnostics() -> Dictionary:
	return _last_plan_diagnostics.duplicate(true)


func _best_path_to_goal_area(
		unit: TacticalUnitState,
		goal: Vector2i,
		allow_adjacent: bool,
		reachable_field: MovementReachableField
) -> MovementPathResult:
	if reachable_field == null:
		return null
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 1_000_000
	var best_cost: int = 1_000_000_000
	for candidate: Vector2i in reachable_field.reachable_tiles():
		var distance: int = TacticalGridDistance.steps_between(candidate, goal)
		var effective_distance: int = maxi(0, distance - (1 if allow_adjacent else 0))
		var movement_cost: int = reachable_field.cost_to(candidate)
		if movement_cost < 0:
			continue
		if (
			best_tile.x < 0
			or effective_distance < best_distance
			or (
				effective_distance == best_distance
				and movement_cost < best_cost
			)
			or (
				effective_distance == best_distance
				and movement_cost == best_cost
				and _tile_precedes(candidate, best_tile)
			)
		):
			best_tile = candidate
			best_distance = effective_distance
			best_cost = movement_cost
	return (
		reachable_field.path_to(best_tile)
		if best_tile.x >= 0 and best_tile.y >= 0
		else null
	)


func _best_reachable_approach_path(
		unit: TacticalUnitState,
		goal: Vector2i,
		reachable_field: MovementReachableField
) -> MovementPathResult:
	return _best_path_to_goal_area(unit, goal, false, reachable_field)


func _search_goal_reached(
		unit: TacticalUnitState,
		destination: Vector2i,
		goal: Vector2i
) -> bool:
	if TacticalGridDistance.steps_between(destination, goal) > 1:
		return false
	return TacticalLineOfSightRules.has_line_of_sight(
		destination,
		goal,
		_map_definition
	)


func _candidate_attack_positions(
		unit: TacticalUnitState,
		target: TacticalUnitState,
		reach_feet: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var reach_tiles: int = maxi(1, int(ceil(float(reach_feet) / 5.0)))
	var minimum: Vector2i = target.grid_position - Vector2i.ONE * reach_tiles
	var maximum: Vector2i = (
		target.grid_position
		+ target.footprint
		+ Vector2i.ONE * (reach_tiles - 1)
	)
	for y: int in range(minimum.y, maximum.y + 1):
		for x: int in range(minimum.x, maximum.x + 1):
			var candidate := Vector2i(x, y)
			if not _map_definition.is_inside(candidate):
				continue
			if _minimum_distance_feet_at(unit, candidate, target) > reach_feet:
				continue
			result.append(candidate)
	result.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			return a.x < b.x
	)
	return result


func _tile_precedes(candidate: Vector2i, current: Vector2i) -> bool:
	if current.x < 0 or current.y < 0:
		return true
	return (
		candidate.y < current.y
		or (candidate.y == current.y and candidate.x < current.x)
	)


func _path_destination_precedes(
		candidate: MovementPathResult,
		current: MovementPathResult
) -> bool:
	if candidate.path.is_empty():
		return false
	if current.path.is_empty():
		return true
	var candidate_tile: Vector2i = candidate.path[candidate.path.size() - 1]
	var current_tile: Vector2i = current.path[current.path.size() - 1]
	if candidate_tile.y != current_tile.y:
		return candidate_tile.y < current_tile.y
	return candidate_tile.x < current_tile.x


func _minimum_distance_feet_at(
		unit: TacticalUnitState,
		origin: Vector2i,
		target: TacticalUnitState
) -> int:
	var unit_cells: Array[Vector2i] = []
	for y: int in range(maxi(1, unit.footprint.y)):
		for x: int in range(maxi(1, unit.footprint.x)):
			unit_cells.append(origin + Vector2i(x, y))
	var target_cells: Array[Vector2i] = (
		_state_store.state.occupied_cells_for_unit(target)
	)
	return TacticalMeleeReachRules.minimum_reach_distance_feet(
		unit_cells,
		target_cells,
		_map_definition
	)


func _furthest_affordable_destination(
		unit: TacticalUnitState,
		path: Array[Vector2i],
		maximum_cost_feet: int
) -> Vector2i:
	if path.is_empty():
		return unit.grid_position
	var navigation: TacticalNavigationSnapshot = TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var destination: Vector2i = path[0]
	var accumulated_cost: int = 0
	var diagonal_parity: int = unit.diagonal_steps_used % 2
	for path_index: int in range(1, path.size()):
		var previous: Vector2i = path[path_index - 1]
		var current: Vector2i = path[path_index]
		var step_cost: int = MovementRules.movement_step_cost(
			previous,
			current,
			navigation,
			diagonal_parity
		)
		if step_cost < 0 or accumulated_cost + step_cost > maximum_cost_feet:
			break
		accumulated_cost += step_cost
		var delta: Vector2i = current - previous
		if delta.x != 0 and delta.y != 0:
			diagonal_parity = 1 - diagonal_parity
		destination = current
	return destination


func _forecast_direct_attack_succeeds(
		unit: TacticalUnitState,
		target: TacticalUnitState,
		job: EnemyActivationPlanningJob
) -> bool:
	if (
		unit == null
		or target == null
		or job == null
		or job.attack == null
		or job.available_capacity_feet < job.attack_cost_feet
	):
		return false
	if job.attack.attack_kind == AttackDefinition.ATTACK_RANGED:
		return _ranged_position_can_attack(
			unit.grid_position,
			target,
			job.attack,
			unit
		)
	var reach_feet: int = 5
	if job.attack.range_profile != null:
		reach_feet = maxi(5, job.attack.range_profile.reach_feet)
	if _minimum_distance_feet_at(
		unit,
		unit.grid_position,
		target
	) > reach_feet:
		return false
	return _geometry_allows_direct_attack(_geometry_between(unit, target))


func _preview_attack(
		unit: TacticalUnitState,
		target: TacticalUnitState,
		action_id: StringName
) -> Variant:
	if _attack_preview_query == null:
		return null
	return _attack_preview_query.call(
		"execute",
		unit.unit_id,
		target.unit_id,
		action_id,
		0,
		TacticalUnitState.DAMAGE_CHANNEL_LETHAL
	)


func _preview_succeeds(preview: Variant) -> bool:
	return preview != null and bool(preview.get("success"))
