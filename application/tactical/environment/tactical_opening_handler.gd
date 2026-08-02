class_name TacticalOpeningHandler
extends RefCounted

const OPENING_COST_FEET: int = 5

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _event_journal: RefCounted
var _dice_roller: TacticalDiceRoller
var _visibility_service: RefCounted
var _detection_service: TacticalDetectionService


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		event_journal: RefCounted,
		dice_roller: TacticalDiceRoller,
		visibility_service: RefCounted,
		detection_service: TacticalDetectionService
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_event_journal = event_journal
	_dice_roller = dice_roller
	_visibility_service = visibility_service
	_detection_service = detection_service


func opening_between(first: Vector2i, second: Vector2i) -> TacticalOpeningDefinition:
	return _map_definition.opening_at_edge(first, second) if _map_definition != null else null


func opening_state(opening_id: StringName) -> TacticalOpeningState:
	if _state_store == null or _state_store.state.environment_state == null:
		return null
	return _state_store.state.environment_state.opening_state(opening_id)


func available_interactions(
		unit_id: StringName,
		opening_id: StringName
) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var validation: Dictionary = _validate_adjacent_opening(unit_id, opening_id)
	if not bool(validation.get("success", false)):
		return options
	var unit: TacticalUnitState = validation.get("unit") as TacticalUnitState
	var definition: TacticalOpeningDefinition = validation.get("definition") as TacticalOpeningDefinition
	var runtime: TacticalOpeningState = validation.get("runtime") as TacticalOpeningState
	if definition.opening_kind != TacticalOpeningDefinition.KIND_BARRED_OPENING:
		var operation_name: String = "Close" if runtime.is_open() else "Open"
		var enabled: bool = runtime.can_operate_normally() and not runtime.locked and not runtime.barred and not runtime.jammed
		if runtime.is_open() and _doorway_is_obstructed(definition, unit.unit_id):
			enabled = false
		options.append({
			"action_id": &"toggle_opening",
			"display_name": "%s %s" % [operation_name, definition.display_name],
			"cost_label": "%d ft" % definition.operation_cost_feet,
			"enabled": enabled,
			"rejection_reason": "The opening is secured, damaged, or obstructed." if not enabled else "",
			"icon_id": &"open_close",
		})
	if runtime.locked:
		var has_tools: bool = _lockpick_item_for_unit(unit_id) != null
		options.append({
			"action_id": &"pick_lock",
			"display_name": "Pick Lock",
			"cost_label": "Half Action",
			"enabled": has_tools,
			"rejection_reason": "Lockpicks are required." if not has_tools else "",
			"icon_id": &"pick_lock",
		})
	return options


func toggle_opening(unit_id: StringName, opening_id: StringName) -> OperationResult:
	var validation: Dictionary = _validate_adjacent_opening(unit_id, opening_id)
	if not bool(validation.get("success", false)):
		return OperationResult.fail(&"opening_unavailable", String(validation.get("reason", "Opening unavailable.")))
	var unit: TacticalUnitState = validation.get("unit") as TacticalUnitState
	var definition: TacticalOpeningDefinition = validation.get("definition") as TacticalOpeningDefinition
	var runtime: TacticalOpeningState = validation.get("runtime") as TacticalOpeningState
	if definition.opening_kind == TacticalOpeningDefinition.KIND_BARRED_OPENING:
		return OperationResult.fail(&"opening_not_operable", "The barred opening cannot be operated normally.")
	if not runtime.can_operate_normally():
		return OperationResult.fail(&"opening_damaged", "This opening is too damaged to operate normally.")
	if runtime.locked or runtime.barred or runtime.jammed:
		return OperationResult.fail(&"opening_secured", "The opening is locked, barred, or jammed.")
	if unit.action_budget.remaining_turn_capacity_feet < definition.operation_cost_feet:
		return OperationResult.fail(&"opening_cost_unavailable", "Operating this opening costs %d ft." % definition.operation_cost_feet)
	if runtime.is_open() and _doorway_is_obstructed(definition, unit.unit_id):
		return OperationResult.fail(&"doorway_obstructed", "A creature, body, or bulky item obstructs the opening.")
	var environment: TacticalEnvironmentState = _state_store.state.environment_state
	var source_snapshot: Dictionary = environment.snapshot_source(opening_id)
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	var spent_before: int = unit.action_budget.normal_capacity_spent_feet
	var opening_was_open: bool = runtime.is_open()
	var changes := TacticalChangeSet.new(
		&"opening_state_changed",
		_state_store.state.revision,
		TacticalInvalidationContract.environment_interaction(unit.unit_id)
	)
	changes.stage(
		func() -> bool:
			unit.action_budget.spend_normal_capacity(definition.operation_cost_feet)
			return environment.close_door(opening_id) if opening_was_open else environment.open_door(opening_id),
		func() -> void:
			unit.action_budget.remaining_turn_capacity_feet = capacity_before
			unit.action_budget.normal_capacity_spent_feet = spent_before
			environment.restore_source(opening_id, source_snapshot),
		"The opening state could not be changed.",
		&"opening_commit_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_event(
		unit,
		&"opening_closed" if opening_was_open else &"opening_opened",
		"%s %s %s." % [unit.display_name, "closed" if opening_was_open else "opened", definition.display_name],
		["Cost: %d ft" % definition.operation_cost_feet]
	)
	_refresh_geometry_perception(unit)
	return OperationResult.ok(runtime, "%s %s." % [definition.display_name, "closed" if opening_was_open else "opened"])


func pick_lock(unit_id: StringName, opening_id: StringName) -> OperationResult:
	var validation: Dictionary = _validate_adjacent_opening(unit_id, opening_id)
	if not bool(validation.get("success", false)):
		return OperationResult.fail(&"lockpick_unavailable", String(validation.get("reason", "Lock unavailable.")))
	var unit: TacticalUnitState = validation.get("unit") as TacticalUnitState
	var definition: TacticalOpeningDefinition = validation.get("definition") as TacticalOpeningDefinition
	var runtime: TacticalOpeningState = validation.get("runtime") as TacticalOpeningState
	if not runtime.locked:
		return OperationResult.fail(&"opening_not_locked", "This opening is not locked.")
	var lockpick_item: TacticalItemInstanceState = _lockpick_item_for_unit(unit.unit_id)
	if lockpick_item == null:
		return OperationResult.fail(&"lockpicks_missing", "Lockpicks are required.")
	var cost_feet: int = int(ceil(float(unit.action_budget.maximum_turn_capacity_feet) * 0.5))
	if unit.action_budget.remaining_turn_capacity_feet < cost_feet:
		return OperationResult.fail(&"lockpick_cost_unavailable", "Picking the lock costs a Half Action.")
	var thievery_bonus: int = int(unit.resolved_character.skill_bonuses.get("Thievery", 0))
	var tool_bonus: int = lockpick_item.definition.stat_modifier(&"skill.thievery")
	var dice_checkpoint: Dictionary = _dice_roller.snapshot_state()
	var natural_roll: int = _dice_roller.roll_die(20)
	var total: int = natural_roll + thievery_bonus + tool_bonus
	var succeeded: bool = natural_roll == 20 or (natural_roll != 1 and total >= definition.lock_dc)
	var environment: TacticalEnvironmentState = _state_store.state.environment_state
	var source_snapshot: Dictionary = environment.snapshot_source(opening_id)
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	var spent_before: int = unit.action_budget.normal_capacity_spent_feet
	var life_before: Dictionary = unit.life_state_snapshot()
	var unit_was_disabled: bool = unit.is_disabled()
	var changes := TacticalChangeSet.new(
		&"opening_state_changed",
		_state_store.state.revision,
		TacticalInvalidationContract.environment_interaction(unit.unit_id)
	)
	changes.stage(
		func() -> bool:
			unit.action_budget.spend_normal_capacity(cost_feet)
			if succeeded and not environment.unlock_opening(opening_id):
				return false
			if unit_was_disabled:
				unit.apply_disabled_strain()
			return true,
		func() -> void:
			unit.action_budget.remaining_turn_capacity_feet = capacity_before
			unit.action_budget.normal_capacity_spent_feet = spent_before
			unit.restore_life_state(life_before)
			environment.restore_source(opening_id, source_snapshot),
		"The lockpicking attempt could not be committed.",
		&"lockpick_commit_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		_dice_roller.restore_state(dice_checkpoint)
		return committed
	_record_event(
		unit,
		&"lock_picked" if succeeded else &"lockpick_failed",
		"%s %s the lock on %s." % [unit.display_name, "picked" if succeeded else "failed to pick", definition.display_name],
		[
			"Roll: %d + Thievery %d + Tools %d = %d vs DC %d" % [natural_roll, thievery_bonus, tool_bonus, total, definition.lock_dc],
			"Cost: Half Action (%d ft)" % cost_feet,
		]
	)
	if succeeded:
		_refresh_geometry_perception(unit)
	return OperationResult.ok({"success": succeeded, "roll": natural_roll, "total": total}, "%s: %d vs DC %d." % ["Lock opened" if succeeded else "Lock remains closed", total, definition.lock_dc])


func peek(unit_id: StringName, opening_id: StringName) -> OperationResult:
	# Compatibility entry point only. Stage 4.4d makes Peek an automatic and
	# completely free observation origin; the player never invokes this through
	# a menu and no turn capacity is spent.
	var validation: Dictionary = _validate_adjacent_opening(unit_id, opening_id)
	if not bool(validation.get("success", false)):
		return OperationResult.fail(&"peek_unavailable", String(validation.get("reason", "Peek unavailable.")))
	var unit: TacticalUnitState = validation.get("unit") as TacticalUnitState
	var definition: TacticalOpeningDefinition = validation.get("definition") as TacticalOpeningDefinition
	var runtime: TacticalOpeningState = validation.get("runtime") as TacticalOpeningState
	if definition.opening_kind == TacticalOpeningDefinition.KIND_DOOR and not runtime.is_open():
		return OperationResult.fail(&"peek_blocked_by_closed_door", "The closed door blocks automatic observation.")
	if _visibility_service != null:
		_visibility_service.call("recalculate_all_teams", true)
	if _detection_service != null and not unit.squad_id.is_empty():
		_detection_service.request_current_perception_for_squad(unit.squad_id)
	return OperationResult.ok(definition.opening_id, "Automatic Peek is active at %s." % definition.display_name)


func lean_origin(unit_id: StringName, opening_id: StringName) -> Variant:
	var validation: Dictionary = _validate_adjacent_opening(unit_id, opening_id)
	if not bool(validation.get("success", false)):
		return null
	var unit: TacticalUnitState = validation.get("unit") as TacticalUnitState
	var definition: TacticalOpeningDefinition = validation.get("definition") as TacticalOpeningDefinition
	var runtime: TacticalOpeningState = validation.get("runtime") as TacticalOpeningState
	if (
		definition.opening_kind == TacticalOpeningDefinition.KIND_DOOR
		and not runtime.is_open()
	):
		return null
	var other: Vector2i = definition.second_tile if unit.grid_position == definition.first_tile else definition.first_tile
	var direction: Vector2 = Vector2(other - unit.grid_position).normalized()
	return Vector2(unit.grid_position) + Vector2(0.5, 0.5) + direction * 0.46


func corner_lean_origin(unit_id: StringName, wall_tile: Vector2i) -> Variant:
	var validation: Dictionary = _validate_adjacent_corner(unit_id, wall_tile)
	if not bool(validation.get("success", false)):
		return null
	var unit: TacticalUnitState = validation.get("unit") as TacticalUnitState
	var side: Vector2i = Vector2i(validation.get("side", Vector2i.ZERO))
	return (
		Vector2(unit.grid_position)
		+ Vector2(0.5, 0.5)
		+ Vector2(side) * 0.46
	)


func peek_around_corner(unit_id: StringName, wall_tile: Vector2i) -> OperationResult:
	# Compatibility entry point only. Corner observation is included in the
	# unit's visibility automatically and never spends movement or an action.
	var validation: Dictionary = _validate_adjacent_corner(unit_id, wall_tile)
	if not bool(validation.get("success", false)):
		return OperationResult.fail(
			&"corner_peek_unavailable",
			String(validation.get("reason", "Corner Peek unavailable."))
		)
	var unit: TacticalUnitState = validation.get("unit") as TacticalUnitState
	if _visibility_service != null:
		_visibility_service.call("recalculate_all_teams", true)
	if _detection_service != null and not unit.squad_id.is_empty():
		_detection_service.request_current_perception_for_squad(unit.squad_id)
	return OperationResult.ok(wall_tile, "%s is observing automatically around this corner." % unit.display_name)


func _validate_adjacent_corner(unit_id: StringName, wall_tile: Vector2i) -> Dictionary:
	if _state_store == null or _state_store.state == null or _map_definition == null:
		return {"success": false, "reason": "Corner services are unavailable."}
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return {"success": false, "reason": "The unit no longer exists."}
	if not _state_store.state.can_unit_act(unit_id) or unit.is_incapacitated():
		return {"success": false, "reason": "This unit cannot Peek now."}
	if not TacticalEdgeKey.are_adjacent(unit.grid_position, wall_tile):
		return {"success": false, "reason": "The wall corner must be adjacent."}
	if not _map_definition.blocks_vision(wall_tile):
		return {"success": false, "reason": "That tile does not form a solid corner."}
	var toward_wall: Vector2i = wall_tile - unit.grid_position
	var candidates: Array[Vector2i] = [
		Vector2i(-toward_wall.y, toward_wall.x),
		Vector2i(toward_wall.y, -toward_wall.x),
	]
	for side: Vector2i in candidates:
		var side_tile: Vector2i = unit.grid_position + side
		if not _map_definition.is_inside(side_tile):
			continue
		if _map_definition.is_blocked(side_tile):
			continue
		if (
			_state_store.state.environment_state != null
			and _state_store.state.environment_state.edge_blocks_movement(
				_map_definition, unit.grid_position, side_tile
			)
		):
			continue
		return {"success": true, "unit": unit, "side": side}
	return {
		"success": false,
		"reason": "No clear side of this corner is available for Peek or Lean Attack.",
	}


func _validate_adjacent_opening(unit_id: StringName, opening_id: StringName) -> Dictionary:
	if _state_store == null or _state_store.state == null or _map_definition == null:
		return {"success": false, "reason": "Opening services are unavailable."}
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	var definition: TacticalOpeningDefinition = _map_definition.opening_definition(opening_id)
	var runtime: TacticalOpeningState = opening_state(opening_id)
	if unit == null or definition == null or runtime == null:
		return {"success": false, "reason": "The unit or opening no longer exists."}
	if not _state_store.state.can_unit_act(unit_id):
		return {"success": false, "reason": "This unit is not currently active."}
	if unit.is_incapacitated():
		return {"success": false, "reason": "An incapacitated unit cannot use an opening."}
	if unit.grid_position not in [definition.first_tile, definition.second_tile]:
		return {"success": false, "reason": "The unit must be adjacent to the opening."}
	return {"success": true, "unit": unit, "definition": definition, "runtime": runtime}


func _lockpick_item_for_unit(unit_id: StringName) -> TacticalItemInstanceState:
	for item: TacticalItemInstanceState in _state_store.state.get_items():
		if item.location == null or item.location.owner_id != unit_id:
			continue
		if item.definition != null and item.definition.has_tag(&"lockpick"):
			return item
	return null


func _doorway_is_obstructed(definition: TacticalOpeningDefinition, actor_id: StringName) -> bool:
	for tile: Vector2i in [definition.first_tile, definition.second_tile]:
		var occupant: TacticalUnitState = _state_store.state.get_unit_at_tile(tile, actor_id)
		if occupant != null:
			return true
		if _state_store.state.has_ground_body_at(tile):
			return true
		for item: TacticalItemInstanceState in _state_store.state.get_ground_items():
			if item.location == null or item.location.map_position != tile:
				continue
			if item.definition != null and item.definition.has_tag(&"bulky"):
				return true
	return false


func _refresh_geometry_perception(unit: TacticalUnitState) -> void:
	if _visibility_service != null and _visibility_service.has_method("invalidate_for_map_change"):
		_visibility_service.call("invalidate_for_map_change")
	if _detection_service != null and unit != null and not unit.squad_id.is_empty():
		_detection_service.request_current_perception_for_squad(unit.squad_id)


func _record_event(
		unit: TacticalUnitState,
		event_type: StringName,
		summary: String,
		details: Array[String]
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call("record_event", event_type, phase.round_number, phase.current_phase, summary, {
		"category": &"events",
		"source_actor_id": unit.unit_id,
		"details": details,
	})
