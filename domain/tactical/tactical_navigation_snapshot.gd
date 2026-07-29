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


func is_difficult(origin: Vector2i) -> bool:
	for y: int in range(mover_footprint.y):
		for x: int in range(mover_footprint.x):
			if map_definition.is_difficult(origin + Vector2i(x, y)):
				return true
	return false


func movement_multiplier(origin: Vector2i) -> int:
	return 2 if is_difficult(origin) else 1
