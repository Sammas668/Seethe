class_name TacticalFiringOriginQuery
extends RefCounted


static func legal_origins(
		state: TacticalState,
		map_definition: TacticalMapDefinition,
		attacker: TacticalUnitState
) -> Array[TacticalFiringOrigin]:
	var result: Array[TacticalFiringOrigin] = []
	if state == null or map_definition == null or attacker == null:
		return result
	result.append(TacticalFiringOrigin.centre(attacker.grid_position))
	if attacker.is_incapacitated() or state.environment_state == null:
		return result
	var environment: TacticalEnvironmentState = state.environment_state
	var origin_tile: Vector2i = attacker.grid_position

	for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var other: Vector2i = origin_tile + direction
		if not map_definition.is_inside(other):
			continue
		var opening: TacticalOpeningDefinition = map_definition.opening_at_edge(origin_tile, other)
		if opening == null:
			continue
		if environment.edge_blocks_line_of_effect(map_definition, origin_tile, other):
			continue
		var opening_origin := TacticalFiringOrigin.new()
		opening_origin.origin_kind = TacticalFiringOrigin.KIND_OPENING_LEAN
		opening_origin.world_position = Vector2(origin_tile) + Vector2(0.5, 0.5) + Vector2(direction) * 0.46
		opening_origin.source_edge_id = opening.opening_id
		opening_origin.uses_automatic_lean = true
		opening_origin.direction = direction
		_append_unique(result, opening_origin)

	for toward_wall: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var wall_tile: Vector2i = origin_tile + toward_wall
		if not map_definition.is_inside(wall_tile) or not map_definition.blocks_vision(wall_tile):
			continue
		var sides: Array[Vector2i] = [
			Vector2i(-toward_wall.y, toward_wall.x),
			Vector2i(toward_wall.y, -toward_wall.x),
		]
		for side: Vector2i in sides:
			var side_tile: Vector2i = origin_tile + side
			if not map_definition.is_inside(side_tile) or map_definition.is_blocked(side_tile):
				continue
			if environment.edge_blocks_line_of_effect(map_definition, origin_tile, side_tile):
				continue
			var corner_origin := TacticalFiringOrigin.new()
			corner_origin.origin_kind = TacticalFiringOrigin.KIND_CORNER_LEAN
			corner_origin.world_position = Vector2(origin_tile) + Vector2(0.5, 0.5) + Vector2(side) * 0.46
			corner_origin.source_edge_id = StringName("corner:%d,%d:%d,%d" % [wall_tile.x, wall_tile.y, side.x, side.y])
			corner_origin.uses_automatic_lean = true
			corner_origin.direction = side
			_append_unique(result, corner_origin)
	return result


static func _append_unique(
		origins: Array[TacticalFiringOrigin],
		candidate: TacticalFiringOrigin
) -> void:
	for existing: TacticalFiringOrigin in origins:
		if existing.world_position.distance_to(candidate.world_position) < 0.001:
			return
	origins.append(candidate)
