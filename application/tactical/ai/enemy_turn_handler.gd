class_name EnemyTurnHandler
extends RefCounted

const TEAM_RELATIONS_SCRIPT: Script = preload(
	"res://domain/tactical/tactical_team_relations.gd"
)

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _catalogue: ContentCatalogue
var _event_journal: RefCounted
var _attack_preview_query: RefCounted
var _attack_handler: RefCounted


func _init() -> void:
	pass


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		catalogue: ContentCatalogue,
		event_journal_value: RefCounted = null,
		attack_preview_query: RefCounted = null,
		attack_handler: RefCounted = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_catalogue = catalogue
	_event_journal = event_journal_value
	_attack_preview_query = attack_preview_query
	_attack_handler = attack_handler


func resolve_enemy_turn() -> OperationResult:
	if _state_store == null or _state_store.state == null:
		return OperationResult.fail(
			&"enemy_turn_state_missing",
			"The tactical state is unavailable."
		)
	if not _state_store.state.phase_state.is_enemy_turn():
		return OperationResult.fail(
			&"enemy_turn_wrong_phase",
			"Enemy activations are available only during the Enemy Turn."
		)

	var participant_ids: Array[StringName] = []
	for unit: TacticalUnitState in _state_store.state.get_enemy_turn_units():
		participant_ids.append(unit.unit_id)

	var summaries: Array[String] = []
	for unit_id: StringName in participant_ids:
		var result: OperationResult = _execute_activation(unit_id)
		if not result.success:
			return result
		if not result.message.is_empty():
			summaries.append(result.message)

	var message: String = "Enemy Turn completed."
	if not summaries.is_empty():
		message = "Enemy Turn completed: %s" % "; ".join(
			PackedStringArray(summaries)
		)
	return OperationResult.ok(participant_ids, message)


func _execute_activation(unit_id: StringName) -> OperationResult:
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return OperationResult.fail(
			&"enemy_turn_unit_missing",
			"An enemy participant no longer exists."
		)
	if not unit.should_receive_enemy_turn():
		return OperationResult.fail(
			&"enemy_turn_unit_ineligible",
			"%s is not eligible for an Enemy Turn activation."
			% unit.display_name
		)

	if unit.is_defeated():
		return _execute_defeated_skip(unit)
	if unit.turn_behavior == TacticalUnitState.TURN_BEHAVIOR_AUTO_PASS:
		return _execute_auto_pass(unit)
	if unit.turn_behavior == TacticalUnitState.TURN_BEHAVIOR_STANDARD:
		return _execute_standard_combat(unit)
	return OperationResult.fail(
		&"enemy_turn_behavior_unimplemented",
		"%s has an unsupported Enemy Turn behaviour." % unit.display_name
	)


func _execute_standard_combat(unit: TacticalUnitState) -> OperationResult:
	var started: OperationResult = _begin_activation(unit, "Standard Combat")
	if not started.success:
		return started

	var action_id: StringName = _preferred_attack_action(unit)
	if action_id.is_empty():
		return _finish_activation(
			unit,
			false,
			"%s has no usable melee attack and passes." % unit.display_name
		)

	var plan: Dictionary = _best_target_plan(unit, action_id)
	if plan.is_empty():
		return _finish_activation(
			unit,
			false,
			"%s cannot reach a hostile player and passes." % unit.display_name
		)

	var target_id: StringName = StringName(plan.get("target_id", &""))
	var target: TacticalUnitState = _state_store.state.get_unit(target_id)
	if target == null or target.is_defeated():
		return _finish_activation(
			unit,
			false,
			"%s found no active hostile target and passes." % unit.display_name
		)

	var acted: bool = false
	var initial_preview: Variant = _preview_attack(unit, target, action_id)
	if _preview_succeeds(initial_preview):
		var attack_result: OperationResult = _execute_attack(initial_preview)
		if not attack_result.success:
			return attack_result
		acted = true
	else:
		var path_result: MovementPathResult = plan.get("path") as MovementPathResult
		if path_result != null and path_result.success and path_result.path.size() > 1:
			var attack_definition: AttackDefinition = _catalogue.attack_definition(
				action_id
			)
			var attack_cost: int = 0
			if attack_definition != null:
				attack_cost = attack_definition.resolved_cost().resolved_normal_capacity_feet(
					unit.action_budget.maximum_turn_capacity_feet
				)

			var destination: Vector2i = unit.grid_position
			if (
				path_result.cost_feet + attack_cost
				<= unit.action_budget.remaining_turn_capacity_feet
			):
				destination = path_result.path[path_result.path.size() - 1]
			else:
				destination = _furthest_affordable_destination(
					unit,
					path_result.path,
					unit.action_budget.remaining_turn_capacity_feet
				)

			if destination != unit.grid_position:
				var movement_result: OperationResult = _commit_enemy_move(
					unit,
					destination
				)
				if not movement_result.success:
					return movement_result
				acted = true

		var moved_preview: Variant = _preview_attack(unit, target, action_id)
		if _preview_succeeds(moved_preview):
			var moved_attack_result: OperationResult = _execute_attack(moved_preview)
			if not moved_attack_result.success:
				return moved_attack_result
			acted = true

	return _finish_activation(
		unit,
		acted,
		(
			"%s completed its combat activation." % unit.display_name
			if acted
			else "%s has no legal actions and passes." % unit.display_name
		)
	)


func _preferred_attack_action(unit: TacticalUnitState) -> StringName:
	if _catalogue == null or _attack_preview_query == null:
		return &""
	for action_id: StringName in _state_store.state.granted_action_ids_for_unit(
		unit.unit_id
	):
		var supported_value: Variant = _attack_preview_query.call(
			"is_supported_ai_action",
			action_id
		)
		if not bool(supported_value):
			continue
		var attack: AttackDefinition = _catalogue.attack_definition(action_id)
		if attack != null and attack.attack_kind == AttackDefinition.ATTACK_MELEE:
			return action_id
	return &""


func _best_target_plan(
		unit: TacticalUnitState,
		action_id: StringName
) -> Dictionary:
	var attack: AttackDefinition = _catalogue.attack_definition(action_id)
	if attack == null:
		return {}
	var reach_feet: int = (
		attack.range_profile.reach_feet
		if attack.range_profile != null
		else 5
	)

	var best: Dictionary = {}
	for target: TacticalUnitState in _state_store.state.get_player_units():
		if target == null or target.is_defeated():
			continue
		if not TEAM_RELATIONS_SCRIPT.are_hostile(unit.team_id, target.team_id):
			continue
		var path: MovementPathResult = _best_path_to_attack_position(
			unit,
			target,
			reach_feet
		)
		if path == null or not path.success:
			continue
		if best.is_empty() or _plan_is_better(target, path, best):
			best = {
				"target_id": target.unit_id,
				"path": path,
				"path_cost": path.cost_feet,
				"target_hp": target.current_hp,
			}
	return best


func _plan_is_better(
		target: TacticalUnitState,
		path: MovementPathResult,
		current_best: Dictionary
) -> bool:
	var best_cost: int = int(current_best.get("path_cost", 1_000_000))
	if path.cost_feet != best_cost:
		return path.cost_feet < best_cost
	var best_hp: int = int(current_best.get("target_hp", 1_000_000))
	if target.current_hp != best_hp:
		return target.current_hp < best_hp
	return str(target.unit_id) < str(current_best.get("target_id", &""))


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
	for y: int in range(_map_definition.grid_size.y):
		for x: int in range(_map_definition.grid_size.x):
			var candidate: Vector2i = Vector2i(x, y)
			if not _state_store.state.can_place_unit(
				unit,
				candidate,
				_map_definition,
				unit.unit_id
			):
				continue
			if _minimum_distance_feet_at(unit, candidate, target) > reach_feet:
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
	var best_steps: int = 1_000_000
	for y: int in range(maxi(1, unit.footprint.y)):
		for x: int in range(maxi(1, unit.footprint.x)):
			var unit_cell: Vector2i = origin + Vector2i(x, y)
			for target_cell: Vector2i in _state_store.state.occupied_cells_for_unit(
				target
			):
				var delta: Vector2i = target_cell - unit_cell
				best_steps = mini(
					best_steps,
					maxi(absi(delta.x), absi(delta.y))
				)
	return maxi(0, best_steps) * 5


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
	for end_index: int in range(2, path.size() + 1):
		var prefix: Array[Vector2i] = []
		for path_index: int in range(end_index):
			prefix.append(path[path_index])
		var result: MovementPathResult = MovementRules.calculate_path_cost(
			prefix,
			navigation,
			unit.diagonal_steps_used
		)
		if not result.success or result.cost_feet > maximum_cost_feet:
			break
		destination = prefix[prefix.size() - 1]
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


func _execute_attack(preview: Variant) -> OperationResult:
	if _attack_handler == null:
		return OperationResult.fail(
			&"enemy_attack_handler_missing",
			"The enemy attack resolver is unavailable."
		)
	var value: Variant = _attack_handler.call("execute_preview", preview)
	var result: OperationResult = value as OperationResult
	return (
		result
		if result != null
		else OperationResult.fail(
			&"enemy_attack_result_missing",
			"The enemy attack resolver returned no result."
		)
	)


func _commit_enemy_move(
		unit: TacticalUnitState,
		destination: Vector2i
) -> OperationResult:
	var navigation: TacticalNavigationSnapshot = TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var path: MovementPathResult = MovementRules.find_path(
		unit.grid_position,
		destination,
		navigation,
		unit.diagonal_steps_used
	)
	if not path.success:
		return OperationResult.fail(&"enemy_move_invalid", path.failure_reason)
	if path.cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		return OperationResult.fail(
			&"enemy_move_capacity",
			"%s cannot afford its chosen route." % unit.display_name
		)

	var origin: Vector2i = unit.grid_position
	var budget_snapshot: Dictionary = _budget_snapshot(unit)
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"enemy_unit_moved",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_set_unit_position").bind(unit.unit_id, destination),
		Callable(self, "_restore_unit_position").bind(unit.unit_id, origin),
		"The enemy destination became invalid.",
		&"enemy_move_destination_failed"
	)
	changes.stage(
		Callable(self, "_spend_move_budget").bind(
			unit,
			path.cost_feet,
			path.diagonal_steps
		),
		Callable(self, "_restore_budget").bind(unit, budget_snapshot),
		"The enemy movement cost could not be paid.",
		&"enemy_move_cost_failed"
	)
	var committed: OperationResult = _state_store.commit(
		changes,
		_map_definition
	)
	if not committed.success:
		return committed

	_record_movement_event(unit, origin, destination, path, budget_snapshot)
	return OperationResult.ok(path, "%s moved %d ft." % [
		unit.display_name,
		path.cost_feet,
	])


func _begin_activation(
		unit: TacticalUnitState,
		behavior_label: String
) -> OperationResult:
	var budget_snapshot: Dictionary = _budget_snapshot(unit)
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"enemy_unit_started",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_refresh_activation").bind(unit),
		Callable(self, "_restore_budget").bind(unit, budget_snapshot),
		"%s could not begin its Enemy Turn activation." % unit.display_name,
		&"enemy_activation_start_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_turn_started(unit, behavior_label)
	return OperationResult.ok(unit.unit_id, "%s began its activation." % unit.display_name)


func _execute_auto_pass(unit: TacticalUnitState) -> OperationResult:
	var started: OperationResult = _begin_activation(unit, "Automatic Pass")
	if not started.success:
		return started
	return _finish_activation(
		unit,
		false,
		"%s has no legal actions and passes." % unit.display_name
	)


func _execute_defeated_skip(unit: TacticalUnitState) -> OperationResult:
	var started: OperationResult = _begin_activation(unit, "Defeated — Skip")
	if not started.success:
		return started
	return _finish_activation(
		unit,
		false,
		"%s is Defeated and skips its activation." % unit.display_name,
		true
	)


func _finish_activation(
		unit: TacticalUnitState,
		acted: bool,
		summary: String,
		defeated_skip: bool = false
) -> OperationResult:
	if not unit.action_budget.ended_activation:
		var ended_before: bool = unit.action_budget.ended_activation
		var changes: TacticalChangeSet = TacticalChangeSet.new(
			&"enemy_unit_ended",
			_state_store.state.revision
		)
		changes.stage(
			Callable(self, "_set_activation_ended").bind(unit, true),
			Callable(self, "_set_activation_ended_rollback").bind(
				unit,
				ended_before
			),
			"%s could not end its activation." % unit.display_name,
			&"enemy_activation_end_failed"
		)
		var committed: OperationResult = _state_store.commit(
			changes,
			_map_definition
		)
		if not committed.success:
			return committed

	_record_turn_finished(unit, acted, summary, defeated_skip)
	return OperationResult.ok(unit.unit_id, summary)


func _refresh_activation(unit: TacticalUnitState) -> bool:
	unit.refresh_for_new_round()
	return true


func _set_activation_ended(
		unit: TacticalUnitState,
		ended: bool
) -> bool:
	if ended:
		unit.mark_activation_ended()
	else:
		unit.action_budget.ended_activation = false
	return true


func _set_activation_ended_rollback(
		unit: TacticalUnitState,
		ended: bool
) -> void:
	unit.action_budget.ended_activation = ended


func _set_unit_position(
		unit_id: StringName,
		destination: Vector2i
) -> bool:
	return _state_store.state.set_unit_position(
		unit_id,
		destination,
		_map_definition,
		false
	)


func _restore_unit_position(
		unit_id: StringName,
		destination: Vector2i
) -> void:
	_state_store.state.set_unit_position(
		unit_id,
		destination,
		_map_definition,
		false
	)


func _spend_move_budget(
		unit: TacticalUnitState,
		cost_feet: int,
		diagonal_steps: int
) -> bool:
	if cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		return false
	unit.action_budget.spend_normal_capacity(cost_feet)
	unit.diagonal_steps_used += diagonal_steps
	return true


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_available,
		"ordinary_attack": unit.action_budget.ordinary_attack_available,
		"ended": unit.action_budget.ended_activation,
		"diagonal": unit.diagonal_steps_used,
	}


func _restore_budget(
		unit: TacticalUnitState,
		snapshot: Dictionary
) -> void:
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot["remaining"])
	unit.action_budget.normal_capacity_spent_feet = int(snapshot["spent"])
	unit.action_budget.quick_action_available = bool(snapshot["quick"])
	unit.action_budget.reaction_available = bool(snapshot["reaction"])
	unit.action_budget.ordinary_attack_available = bool(
		snapshot["ordinary_attack"]
	)
	unit.action_budget.ended_activation = bool(snapshot["ended"])
	unit.diagonal_steps_used = int(snapshot["diagonal"])


func _record_turn_started(
		unit: TacticalUnitState,
		behavior_label: String
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"unit_turn_started",
		phase.round_number,
		phase.current_phase,
		"%s begins its Enemy Turn activation." % unit.display_name,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"details": [
				"Team: Enemy",
				"Controller: AI",
				"Turn behaviour: %s" % behavior_label,
			],
		}
	)


func _record_turn_finished(
		unit: TacticalUnitState,
		acted: bool,
		summary: String,
		defeated_skip: bool
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	var event_type: StringName = &"unit_turn_ended" if acted else &"unit_passed"
	var details: Array[String] = [
		"Remaining capacity: %d ft"
		% unit.action_budget.remaining_turn_capacity_feet,
		"Normal attack: %s"
		% (
			"Ready"
			if unit.action_budget.ordinary_attack_available
			else "Spent"
		),
	]
	if defeated_skip:
		details.append("Combat state: Defeated")
	elif not acted:
		details.append("No movement or attack was taken.")
	_event_journal.call(
		"record_event",
		event_type,
		phase.round_number,
		phase.current_phase,
		summary,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"details": details,
		}
	)


func _record_movement_event(
		unit: TacticalUnitState,
		origin: Vector2i,
		destination: Vector2i,
		path: MovementPathResult,
		budget_snapshot: Dictionary
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"movement",
		phase.round_number,
		phase.current_phase,
		"%s moved %d ft." % [unit.display_name, path.cost_feet],
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"action_id": &"action.move",
			"details": [
				"From: (%d, %d)" % [origin.x, origin.y],
				"To: (%d, %d)" % [destination.x, destination.y],
				"Distance: %d ft" % path.cost_feet,
				"Capacity: %d → %d ft" % [
					int(budget_snapshot.get("remaining", 0)),
					unit.action_budget.remaining_turn_capacity_feet,
				],
			],
			"resource_changes": [
				{
					"resource": &"normal_capacity",
					"before": int(budget_snapshot.get("remaining", 0)),
					"after": unit.action_budget.remaining_turn_capacity_feet,
				},
			],
		}
	)
