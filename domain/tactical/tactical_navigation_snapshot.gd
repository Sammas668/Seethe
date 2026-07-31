class_name TacticalNavigationSnapshot
extends RefCounted

var map_definition: TacticalMapDefinition
var tactical_state: TacticalState
var mover_id: StringName
var mover_footprint: Vector2i


func _init(
		map_definition_value: TacticalMapDefinition,
		tactical_state_value: TacticalState,
		mover_id_value: StringName = &""
) -> void:
	map_definition = map_definition_value
	tactical_state = tactical_state_value
	mover_id = mover_id_value
	var mover := tactical_state.get_unit(mover_id) if tactical_state != null else null
	mover_footprint = mover.footprint if mover != null else Vector2i.ONE


func is_inside(origin: Vector2i) -> bool:
	for y: int in range(mover_footprint.y):
		for x: int in range(mover_footprint.x):
			if not map_definition.is_inside(origin + Vector2i(x, y)):
				return false
	return true


func is_blocked(origin: Vector2i) -> bool:
	if not is_inside(origin):
		return true

	for y: int in range(mover_footprint.y):
		for x: int in range(mover_footprint.x):
			var cell := origin + Vector2i(x, y)
			if map_definition.is_blocked(cell):
				return true
			if tactical_state != null:
				var occupant := tactical_state.get_unit_at_tile(cell, mover_id)
				if occupant != null:
					return true
	return false


func is_step_blocked(first: Vector2i, second: Vector2i) -> bool:
	if is_blocked(second):
		return true
	if tactical_state == null or tactical_state.environment_state == null:
		return false
	if not TacticalEdgeKey.are_adjacent(first, second):
		return false
	var environment: TacticalEnvironmentState = tactical_state.environment_state
	if not environment.edge_blocks_movement(map_definition, first, second):
		return false
	# A normal unlocked door is pathable because the route includes its authored
	# 5-foot opening interaction. Locked, barred, jammed and window edges remain
	# impassable until another action changes their state.
	return not environment.is_auto_openable_door(map_definition, first, second)


func additional_step_cost(first: Vector2i, second: Vector2i) -> int:
	if tactical_state == null or tactical_state.environment_state == null:
		return 0
	var environment: TacticalEnvironmentState = tactical_state.environment_state
	if not environment.is_auto_openable_door(map_definition, first, second):
		return 0
	var opening: TacticalOpeningDefinition = map_definition.opening_at_edge(first, second)
	return maxi(0, opening.operation_cost_feet) if opening != null else 0


func auto_opening_id(first: Vector2i, second: Vector2i) -> StringName:
	if tactical_state == null or tactical_state.environment_state == null:
		return &""
	if not tactical_state.environment_state.is_auto_openable_door(
		map_definition, first, second
	):
		return &""
	var opening: TacticalOpeningDefinition = map_definition.opening_at_edge(first, second)
	return opening.opening_id if opening != null else &""


func is_difficult(origin: Vector2i) -> bool:
	for y: int in range(mover_footprint.y):
		for x: int in range(mover_footprint.x):
			var cell: Vector2i = origin + Vector2i(x, y)
			if map_definition.is_difficult(cell):
				return true
			if (
				tactical_state != null
				and tactical_state.environment_state != null
				and tactical_state.environment_state.is_dynamic_difficult(map_definition, cell)
			):
				return true
			if tactical_state != null and tactical_state.has_ground_body_at(cell):
				return true
	return false


func mover_is_dragging_body() -> bool:
	if tactical_state == null or mover_id.is_empty():
		return false
	for hand_kind: StringName in [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
	]:
		var item: TacticalItemInstanceState = tactical_state.get_hand_item(
			mover_id, hand_kind
		)
		if item != null and item.is_body():
			return true
	return false


func movement_multiplier(origin: Vector2i) -> int:
	if mover_is_dragging_body():
		return 2
	return 2 if is_difficult(origin) else 1
