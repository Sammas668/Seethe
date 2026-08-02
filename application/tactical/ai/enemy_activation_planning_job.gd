class_name EnemyActivationPlanningJob
extends RefCounted

const STAGE_TARGET_DISCOVERY: StringName = &"target_discovery"
const STAGE_DIRECT_ATTACK_CHECKS: StringName = &"direct_attack_checks"
const STAGE_REACHABLE_FIELD: StringName = &"reachable_field"
const STAGE_TARGETED_MELEE_ATTACK_SEARCH: StringName = &"targeted_melee_attack_search"
const STAGE_TARGETED_MELEE_APPROACH_SEARCH: StringName = &"targeted_melee_approach_search"
const STAGE_TARGET_SCORING: StringName = &"target_scoring"
const STAGE_RANGED_CANDIDATE_SCAN: StringName = &"ranged_candidate_scan"
const STAGE_RANGED_EXACT_GEOMETRY: StringName = &"ranged_exact_geometry"
const STAGE_APPROACH_SCAN: StringName = &"approach_scan"
const STAGE_NO_TARGET_FINALISE: StringName = &"no_target_finalise"
const STAGE_NO_TARGET_GOAL_SCAN: StringName = &"no_target_goal_scan"
const STAGE_COMPLETE: StringName = &"complete"

var unit_id: StringName = &""
var stage: StringName = STAGE_TARGET_DISCOVERY
var plan: EnemyActionPlan
var revealed_targets: Array[TacticalUnitState] = []
var action_id: StringName = &""
var attack: AttackDefinition
var attack_cost_feet: int = 0
var target_index: int = 0
var reachable_builder: MovementReachableFieldJob
var reachable_field: MovementReachableField
var targeted_search: MovementTargetedSearchJob
var targeted_goal_tiles: Array[Vector2i] = []
var targeted_search_accounted_expansions: int = 0
var reachable_tiles: Array[Vector2i] = []
var current_target: TacticalUnitState
var current_candidate_priority: int = 0
var current_path_reaches_attack_position: bool = false
var bounded_ranged_candidates: Array[Dictionary] = []
var ranged_scan_index: int = 0
var ranged_exact_index: int = 0
var ranged_best_tile: Vector2i = Vector2i(-1, -1)
var ranged_best_score: int = -2_000_000_000
var approach_scan_index: int = 0
var approach_best_tile: Vector2i = Vector2i(-1, -1)
var approach_best_distance: int = 1_000_000
var approach_best_cost: int = 1_000_000_000
var no_target_memory_ids: Array[StringName] = []
var no_target_memory_index: int = 0
var no_target_current_memory_id: StringName = &""
var no_target_current_goal: Vector2i = Vector2i(-1, -1)
var no_target_allow_adjacent: bool = false
var no_target_task_mode: bool = false
var no_target_scan_index: int = 0
var no_target_goal_best_tile: Vector2i = Vector2i(-1, -1)
var no_target_goal_best_distance: int = 1_000_000
var no_target_goal_best_cost: int = 1_000_000_000
var no_target_best_memory_id: StringName = &""
var no_target_best_goal: Vector2i = Vector2i(-1, -1)
var no_target_best_path: MovementPathResult
var no_target_best_distance: int = 1_000_000
var best_target: TacticalUnitState
var best_path: MovementPathResult
var best_path_reaches_attack_position: bool = false
var best_candidate_score: int = -2_000_000_000
var started_usec: int = 0
var accumulated_processing_usec: int = 0
var processing_slices: int = 0
var complete: bool = false
var cancelled: bool = false
# Hotfix 5f5: anticipatory handoff planning may run before the actor owns the
# turn. These values describe the budget expected at the upcoming activation
# without mutating the authoritative TacticalUnitState.
var forecast_mode: bool = false
var available_capacity_feet: int = -1
var planning_diagonal_steps: int = -1


func configure(
	unit: TacticalUnitState,
	capacity_override_feet: int = -1,
	diagonal_steps_override: int = -1,
	forecast: bool = false
) -> void:
	unit_id = unit.unit_id if unit != null else &""
	forecast_mode = forecast
	available_capacity_feet = (
		capacity_override_feet
		if capacity_override_feet >= 0
		else (
			unit.action_budget.remaining_turn_capacity_feet
			if unit != null
			else 0
		)
	)
	planning_diagonal_steps = (
		diagonal_steps_override
		if diagonal_steps_override >= 0
		else (unit.diagonal_steps_used if unit != null else 0)
	)
	plan = EnemyActionPlan.new()
	started_usec = Time.get_ticks_usec()
	stage = STAGE_TARGET_DISCOVERY
	complete = false
	cancelled = false


func mark_complete() -> void:
	complete = true
	stage = STAGE_COMPLETE
