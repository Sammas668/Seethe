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
	var plan: RefCounted = ENEMY_ACTION_PLAN_SCRIPT.new() as RefCounted
	if unit == null or _state_store == null or _state_store.state == null:
		plan.call("configure_failure", "The enemy planner has no tactical state.")
		return plan

	var revealed_targets: Array[TacticalUnitState] = _revealed_hostile_targets(unit)
	if revealed_targets.is_empty():
		_plan_search_or_return(unit, plan)
		return plan

	var action_id: StringName = _preferred_attack_action(unit)
	if action_id.is_empty():
		plan.call(
			"configure_failure",
			"%s has no implemented AI-usable attack." % unit.display_name
		)
		return plan

	var attack: AttackDefinition = _catalogue.attack_definition(action_id)
	if attack == null:
		plan.call("configure_failure", "The selected enemy attack is missing.")
		return plan

	var best_target: TacticalUnitState = null
	var best_path: MovementPathResult = null
	var best_attack_now: bool = false
	var best_path_reaches_attack_position: bool = false
	for target: TacticalUnitState in revealed_targets:
		var direct_preview: Variant = _preview_attack(unit, target, action_id)
		var path: MovementPathResult = null
		var attack_now: bool = _preview_succeeds(direct_preview)
		if attack_now:
			var stationary_path: Array[Vector2i] = [unit.grid_position]
			path = MovementPathResult.completed(stationary_path, 0, 0)
		var path_reaches_attack_position: bool = attack_now
		if not attack_now:
			if attack.attack_kind == AttackDefinition.ATTACK_RANGED:
				path = _best_path_to_ranged_attack_position(
					unit,
					target,
					attack
				)
				path_reaches_attack_position = path != null and path.success
				if not path_reaches_attack_position:
					path = _best_path_to_goal_area(unit, target.grid_position, true)
			else:
				var reach_feet: int = 5
				if attack.range_profile != null:
					reach_feet = attack.range_profile.reach_feet
				path = _best_path_to_attack_position(
					unit,
					target,
					reach_feet
				)
				path_reaches_attack_position = path != null and path.success
		if path == null or not path.success:
			continue
		if (
			best_target == null
			or _candidate_precedes(target, path, best_target, best_path)
		):
			best_target = target
			best_path = path
			best_attack_now = attack_now
			best_path_reaches_attack_position = path_reaches_attack_position

	if best_target == null or best_path == null:
		plan.call(
			"configure_failure",
			"%s cannot reach an active revealed hostile target."
			% unit.display_name
		)
		return plan

	if best_attack_now:
		plan.call(
			"configure_success",
			action_id,
			best_target.unit_id,
			unit.grid_position,
			false,
			true,
			0
		)
		return plan

	var attack_cost: int = attack.resolved_cost().resolved_normal_capacity_feet(
		unit.action_budget.maximum_turn_capacity_feet
	)
	var destination: Vector2i = unit.grid_position
	var attack_after_move: bool = false
	if (
		best_path_reaches_attack_position
		and best_path.cost_feet + attack_cost
		<= unit.action_budget.remaining_turn_capacity_feet
	):
		destination = best_path.path[best_path.path.size() - 1]
		attack_after_move = true
	else:
		destination = _furthest_affordable_destination(
			unit,
			best_path.path,
			unit.action_budget.remaining_turn_capacity_feet
		)

	plan.call(
		"configure_success",
		action_id,
		best_target.unit_id,
		destination,
		destination != unit.grid_position,
		attack_after_move,
		best_path.cost_feet
	)
	return plan


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
		plan: RefCounted
) -> void:
	var squad: TacticalSquadState = _state_store.state.get_squad(unit.squad_id)
	if squad != null and squad.is_searching():
		var best_memory_id: StringName = &""
		var best_goal: Vector2i = Vector2i(-1, -1)
		var best_path: MovementPathResult = null
		for memory_unit_id: StringName in squad.last_seen_unit_ids():
			var goal: Vector2i = squad.last_seen_position(memory_unit_id)
			var path: MovementPathResult = _best_path_to_goal_area(
				unit,
				goal,
				true
			)
			if path == null or not path.success:
				continue
			if (
				best_path == null
				or path.cost_feet < best_path.cost_feet
				or (
					path.cost_feet == best_path.cost_feet
					and String(memory_unit_id) < String(best_memory_id)
				)
			):
				best_memory_id = memory_unit_id
				best_goal = goal
				best_path = path
		if best_path != null:
			var search_destination: Vector2i = _furthest_affordable_destination(
				unit,
				best_path.path,
				unit.action_budget.remaining_turn_capacity_feet
			)
			var reached: bool = _search_goal_reached(
				unit,
				search_destination,
				best_goal
			)
			plan.call(
				"configure_search",
				best_memory_id,
				best_goal,
				search_destination,
				search_destination != unit.grid_position,
				reached,
				best_path.cost_feet
			)
			return

	var task_goal: Vector2i = unit.assigned_task_position
	if task_goal.x >= 0 and task_goal.y >= 0:
		var return_path: MovementPathResult = _best_path_to_goal_area(
			unit,
			task_goal,
			false
		)
		if return_path != null and return_path.success:
			var return_destination: Vector2i = _furthest_affordable_destination(
				unit,
				return_path.path,
				unit.action_budget.remaining_turn_capacity_feet
			)
			plan.call(
				"configure_return_to_task",
				task_goal,
				return_destination,
				return_destination != unit.grid_position,
				return_destination == task_goal,
				return_path.cost_feet
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
	var best_action_id: StringName = &""
	var best_score: int = -1
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
		reach_feet: int
) -> MovementPathResult:
	var navigation: TacticalNavigationSnapshot = TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var best: MovementPathResult = null
	for candidate: Vector2i in _candidate_attack_positions(
		unit,
		target,
		reach_feet
	):
		if not _state_store.state.can_place_unit(
			unit,
			candidate,
			_map_definition,
			unit.unit_id
		):
			continue
		var path: MovementPathResult = MovementRules.find_path(
			unit.grid_position,
			candidate,
			navigation,
			unit.diagonal_steps_used
		)
		if not path.success:
			continue
		if (
			best == null
			or path.cost_feet < best.cost_feet
			or (
				path.cost_feet == best.cost_feet
				and _path_destination_precedes(path, best)
			)
		):
			best = path
	return best


func _best_path_to_ranged_attack_position(
		unit: TacticalUnitState,
		target: TacticalUnitState,
		attack: AttackDefinition
) -> MovementPathResult:
	if attack == null or attack.range_profile == null:
		return null
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var maximum_move_tiles: int = int(ceil(
		float(unit.action_budget.remaining_turn_capacity_feet) / 5.0
	))
	var minimum_x: int = maxi(0, unit.grid_position.x - maximum_move_tiles)
	var maximum_x: int = mini(
		_map_definition.grid_size.x - 1,
		unit.grid_position.x + maximum_move_tiles
	)
	var minimum_y: int = maxi(0, unit.grid_position.y - maximum_move_tiles)
	var maximum_y: int = mini(
		_map_definition.grid_size.y - 1,
		unit.grid_position.y + maximum_move_tiles
	)

	# Stage 4.4e uses a cheap first pass. Full pathfinding, five-sample cover and
	# automatic Lean are reserved for the best few plausible firing positions.
	var cheap_candidates: Array[Dictionary] = []
	for y: int in range(minimum_y, maximum_y + 1):
		for x: int in range(minimum_x, maximum_x + 1):
			var candidate := Vector2i(x, y)
			if not _state_store.state.can_place_unit(
				unit, candidate, _map_definition, unit.unit_id
			):
				continue
			if not _ranged_position_is_plausible(candidate, target, attack):
				continue
			_ranged_candidate_tiles_scored += 1
			cheap_candidates.append({
				"tile": candidate,
				"score": _cheap_ranged_position_score(
					unit, target, candidate, attack
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
			return (
				tile_a.y < tile_b.y
				or (tile_a.y == tile_b.y and tile_a.x < tile_b.x)
			)
	)

	var best_path: MovementPathResult = null
	var best_score: int = -1000000
	var exact_count: int = mini(
		RANGED_EXACT_SHORTLIST_SIZE,
		cheap_candidates.size()
	)
	for index: int in range(exact_count):
		var candidate: Vector2i = Vector2i(
			cheap_candidates[index].get("tile", Vector2i.ZERO)
		)
		var path: MovementPathResult = MovementRules.find_path(
			unit.grid_position,
			candidate,
			navigation,
			unit.diagonal_steps_used
		)
		if not path.success:
			continue
		_ranged_exact_candidates_evaluated += 1
		if not _ranged_position_can_attack(candidate, target, attack, unit):
			continue
		var defence_geometry: TacticalCombatGeometryResult = (
			_geometry_between(
				target,
				unit,
				null,
				Vector2(candidate) + Vector2(0.5, 0.5)
			)
		)
		var score: int = 500 - path.cost_feet
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
				and (best_path == null or _path_destination_precedes(path, best_path))
			)
		):
			best_score = score
			best_path = path
	return best_path


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
		unit: TacticalUnitState,
		target: TacticalUnitState,
		candidate: Vector2i,
		attack: AttackDefinition
) -> int:
	var movement_estimate: int = TacticalGridDistance.steps_between(
		unit.grid_position, candidate
	) * TacticalGridDistance.TILE_SIZE_FEET
	var target_distance_feet: int = TacticalGridDistance.steps_between(
		candidate, target.grid_position
	) * TacticalGridDistance.TILE_SIZE_FEET
	var preferred_range: int = maxi(
		5, attack.range_profile.range_increment_feet
	)
	var range_penalty: int = abs(target_distance_feet - preferred_range)
	return (
		500
		- movement_estimate
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
	}


func _best_path_to_goal_area(
		unit: TacticalUnitState,
		goal: Vector2i,
		allow_adjacent: bool
) -> MovementPathResult:
	var navigation: TacticalNavigationSnapshot = TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var candidates: Array[Vector2i] = [goal]
	if allow_adjacent:
		for y: int in range(goal.y - 1, goal.y + 2):
			for x: int in range(goal.x - 1, goal.x + 2):
				var candidate := Vector2i(x, y)
				if candidate != goal:
					candidates.append(candidate)
	var best: MovementPathResult = null
	for candidate: Vector2i in candidates:
		if not _map_definition.is_inside(candidate):
			continue
		if not _state_store.state.can_place_unit(
			unit,
			candidate,
			_map_definition,
			unit.unit_id
		):
			continue
		var path: MovementPathResult = MovementRules.find_path(
			unit.grid_position,
			candidate,
			navigation,
			unit.diagonal_steps_used
		)
		if not path.success:
			continue
		if (
			best == null
			or path.cost_feet < best.cost_feet
			or (
				path.cost_feet == best.cost_feet
				and _path_destination_precedes(path, best)
			)
		):
			best = path
	return best


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
