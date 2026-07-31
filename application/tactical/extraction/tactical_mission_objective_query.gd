class_name TacticalMissionObjectiveQuery
extends RefCounted


static func required_objective_complete(
		state: TacticalState,
		map_definition: TacticalMapDefinition
) -> bool:
	if state == null or map_definition == null:
		return false
	if _defending_force_neutralised(state):
		return true
	for unit: TacticalUnitState in state.get_player_units():
		if unit == null or not unit.can_take_actions():
			continue
		if _unit_occupies_objective(unit, map_definition):
			return true
	return false


static func area_secured(state: TacticalState) -> bool:
	return state != null and _defending_force_neutralised(state)


static func player_force_can_continue(state: TacticalState) -> bool:
	if state == null:
		return false
	for unit: TacticalUnitState in state.get_player_units():
		if unit != null and unit.can_take_actions():
			return true
	return false


static func _defending_force_neutralised(state: TacticalState) -> bool:
	for unit: TacticalUnitState in state.get_enemy_units():
		if unit == null or not unit.counts_for_victory:
			continue
		if unit.can_take_actions():
			return false
	return true


static func _unit_occupies_objective(
		unit: TacticalUnitState,
		map_definition: TacticalMapDefinition
) -> bool:
	if map_definition.primary_objective_tiles.is_empty():
		return false
	for y: int in range(maxi(1, unit.footprint.y)):
		for x: int in range(maxi(1, unit.footprint.x)):
			var cell := unit.grid_position + Vector2i(x, y)
			if not map_definition.is_primary_objective_tile(cell):
				return false
	return true
