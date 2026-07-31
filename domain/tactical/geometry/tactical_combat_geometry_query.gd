class_name TacticalCombatGeometryQuery
extends RefCounted

const SAMPLE_HEIGHTS: Array[int] = [4, 3, 2, 1, 0]
const EPSILON: float = 0.0001


static func evaluate(
		state: TacticalState,
		map_definition: TacticalMapDefinition,
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		origin_override: Variant = null,
		target_position_override: Variant = null
) -> TacticalCombatGeometryResult:
	var result := TacticalCombatGeometryResult.new()
	if state == null or map_definition == null or attacker == null or target == null:
		return result
	var environment: TacticalEnvironmentState = state.environment_state
	if environment == null:
		environment = TacticalEnvironmentState.new()
		environment.configure_from_map(map_definition)
	result.geometry_revision = environment.geometry_revision

	var origin: Vector2 = _resolved_origin(attacker, origin_override)
	var target_origin: Vector2 = _resolved_target_origin(target, target_position_override)
	result.attack_origin = origin
	var direction: Vector2 = target_origin - origin
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x).normalized()
	if perpendicular == Vector2.ZERO:
		perpendicular = Vector2.RIGHT
	var sample_offsets: Array[float] = [0.0, -0.18, 0.0, 0.18, 0.0]
	var sight_clear_count: int = 0
	var effect_clear_count: int = 0
	var cover_source_counts: Dictionary = {}
	var cover_source_kinds: Dictionary = {}

	for sample_index: int in range(SAMPLE_HEIGHTS.size()):
		var sample_point: Vector2 = target_origin + perpendicular * sample_offsets[sample_index]
		result.target_sample_points.append(sample_point)
		var sample: Dictionary = _evaluate_sample(
			state,
			map_definition,
			environment,
			attacker,
			target,
			origin,
			sample_point,
			SAMPLE_HEIGHTS[sample_index]
		)
		if bool(sample.get("sight_clear", false)):
			sight_clear_count += 1
		elif result.blocking_sight_source_id.is_empty():
			result.blocking_sight_source_id = StringName(sample.get("sight_source_id", &""))
		if bool(sample.get("effect_clear", false)):
			effect_clear_count += 1
		else:
			var source_id: StringName = StringName(sample.get("effect_source_id", &""))
			if result.blocking_effect_source_id.is_empty():
				result.blocking_effect_source_id = source_id
			if not source_id.is_empty():
				cover_source_counts[source_id] = int(cover_source_counts.get(source_id, 0)) + 1
				cover_source_kinds[source_id] = StringName(sample.get("source_kind", &"environment"))

	result.has_line_of_sight = sight_clear_count > 0
	result.has_line_of_effect = effect_clear_count > 0
	result.clear_exposure_samples = effect_clear_count

	var creature_cover: Dictionary = _creature_cover_between(
		state,
		attacker,
		target,
		origin,
		target_origin
	)
	if bool(creature_cover.get("applies", false)) and result.clear_exposure_samples > 3:
		result.clear_exposure_samples = 3
		var creature_id: StringName = StringName(creature_cover.get("unit_id", &""))
		cover_source_counts[creature_id] = maxi(
			2,
			int(cover_source_counts.get(creature_id, 0))
		)
		cover_source_kinds[creature_id] = &"creature"

	result.configure_cover_from_samples()
	var primary_source: StringName = _highest_count_source(cover_source_counts)
	result.primary_cover_source_id = primary_source
	result.primary_cover_source_kind = StringName(
		cover_source_kinds.get(primary_source, &"")
	)
	return result


static func evaluate_from_positions(
		state: TacticalState,
		map_definition: TacticalMapDefinition,
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		attacker_position: Vector2i,
		target_position: Vector2i
) -> TacticalCombatGeometryResult:
	return evaluate(
		state,
		map_definition,
		attacker,
		target,
		Vector2(attacker_position) + Vector2(0.5, 0.5),
		Vector2(target_position) + Vector2(0.5, 0.5)
	)


static func cheap_has_line_of_sight(
		state: TacticalState,
		map_definition: TacticalMapDefinition,
		origin_tile: Vector2i,
		target_tile: Vector2i
) -> bool:
	if map_definition == null:
		return false
	if origin_tile == target_tile:
		return true
	var environment: TacticalEnvironmentState = (
		state.environment_state
		if state != null and state.environment_state != null
		else null
	)
	var trace: Dictionary = _trace_grid(
		Vector2(origin_tile) + Vector2(0.5, 0.5),
		Vector2(target_tile) + Vector2(0.5, 0.5)
	)
	var tiles: Array = trace.get("tiles", [])
	for index: int in range(1, maxi(1, tiles.size() - 1)):
		var tile_value: Variant = tiles[index]
		if tile_value is Vector2i and map_definition.blocks_vision(Vector2i(tile_value)):
			return false
	for corner_value: Variant in trace.get("corner_pairs", []):
		if not corner_value is Dictionary:
			continue
		var corner: Dictionary = corner_value
		var from_tile: Vector2i = Vector2i(corner.get("from", origin_tile))
		var first_side: Vector2i = Vector2i(corner.get("first", from_tile))
		var second_side: Vector2i = Vector2i(corner.get("second", from_tile))
		var first_solid: bool = map_definition.blocks_vision(first_side)
		var second_solid: bool = map_definition.blocks_vision(second_side)
		if environment != null:
			first_solid = first_solid or environment.edge_blocks_sight(
				map_definition, from_tile, first_side
			)
			second_solid = second_solid or environment.edge_blocks_sight(
				map_definition, from_tile, second_side
			)
		if first_solid and second_solid:
			return false
	if environment != null:
		for crossing_value: Variant in trace.get("crossings", []):
			if not crossing_value is Dictionary:
				continue
			var crossing: Dictionary = crossing_value
			if environment.edge_blocks_sight(
				map_definition,
				Vector2i(crossing.get("from", origin_tile)),
				Vector2i(crossing.get("to", target_tile))
			):
				return false
	return true


static func _evaluate_sample(
		state: TacticalState,
		map_definition: TacticalMapDefinition,
		environment: TacticalEnvironmentState,
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		origin: Vector2,
		sample_point: Vector2,
		sample_height: int
) -> Dictionary:
	var result: Dictionary = {
		"sight_clear": true,
		"effect_clear": true,
		"sight_source_id": &"",
		"effect_source_id": &"",
		"source_kind": &"",
	}
	var trace: Dictionary = _trace_grid(origin, sample_point)
	var tiles: Array = trace.get("tiles", [])
	for index: int in range(1, maxi(1, tiles.size() - 1)):
		var tile_value: Variant = tiles[index]
		if not tile_value is Vector2i:
			continue
		var tile: Vector2i = Vector2i(tile_value)
		if map_definition.blocks_vision(tile):
			var tile_source: StringName = StringName("tile:%d,%d" % [tile.x, tile.y])
			result.sight_clear = false
			result.effect_clear = false
			result.sight_source_id = tile_source
			result.effect_source_id = tile_source
			result.source_kind = &"tile"
			return result

	for corner_value: Variant in trace.get("corner_pairs", []):
		if not corner_value is Dictionary:
			continue
		var corner: Dictionary = corner_value
		var corner_from: Vector2i = Vector2i(corner.get("from", Vector2i.ZERO))
		var first_side: Vector2i = Vector2i(corner.get("first", corner_from))
		var second_side: Vector2i = Vector2i(corner.get("second", corner_from))
		var first_sight: bool = map_definition.blocks_vision(first_side)
		var second_sight: bool = map_definition.blocks_vision(second_side)
		var first_effect: bool = map_definition.blocks_line_of_effect(first_side)
		var second_effect: bool = map_definition.blocks_line_of_effect(second_side)
		var first_source: StringName = StringName("tile:%d,%d" % [first_side.x, first_side.y])
		var second_source: StringName = StringName("tile:%d,%d" % [second_side.x, second_side.y])
		if not first_sight:
			first_sight = environment.edge_blocks_sight(
				map_definition, corner_from, first_side
			)
			if first_sight:
				first_source = environment.cover_source_id_at_edge(
					map_definition, corner_from, first_side
				)
		if not second_sight:
			second_sight = environment.edge_blocks_sight(
				map_definition, corner_from, second_side
			)
			if second_sight:
				second_source = environment.cover_source_id_at_edge(
					map_definition, corner_from, second_side
				)
		if not first_effect:
			var first_edge_effect: bool = environment.edge_blocks_line_of_effect(
				map_definition, corner_from, first_side
			) or _height_blocks_sample(
				environment.cover_height_at_edge(map_definition, corner_from, first_side),
				sample_height
			)
			first_effect = first_edge_effect
			if first_edge_effect:
				first_source = environment.cover_source_id_at_edge(
					map_definition, corner_from, first_side
				)
		if not second_effect:
			var second_edge_effect: bool = environment.edge_blocks_line_of_effect(
				map_definition, corner_from, second_side
			) or _height_blocks_sample(
				environment.cover_height_at_edge(map_definition, corner_from, second_side),
				sample_height
			)
			second_effect = second_edge_effect
			if second_edge_effect:
				second_source = environment.cover_source_id_at_edge(
					map_definition, corner_from, second_side
				)
		if first_sight and second_sight:
			result.sight_clear = false
			result.sight_source_id = first_source if not first_source.is_empty() else second_source
		if first_effect and second_effect:
			result.effect_clear = false
			result.effect_source_id = first_source if not first_source.is_empty() else second_source
			result.source_kind = _source_kind(map_definition, StringName(result.effect_source_id))
		if not bool(result.sight_clear) and not bool(result.effect_clear):
			return result

	for crossing_value: Variant in trace.get("crossings", []):
		if not crossing_value is Dictionary:
			continue
		var crossing: Dictionary = crossing_value
		var from_tile: Vector2i = Vector2i(crossing.get("from", Vector2i.ZERO))
		var to_tile: Vector2i = Vector2i(crossing.get("to", Vector2i.ZERO))
		var source_id: StringName = environment.cover_source_id_at_edge(
			map_definition, from_tile, to_tile
		)
		if environment.edge_blocks_sight(map_definition, from_tile, to_tile):
			result.sight_clear = false
			result.sight_source_id = source_id
		if environment.edge_blocks_line_of_effect(map_definition, from_tile, to_tile):
			result.effect_clear = false
			result.effect_source_id = source_id
			result.source_kind = _source_kind(map_definition, source_id)
		var height_profile: StringName = environment.cover_height_at_edge(
			map_definition, from_tile, to_tile
		)
		if _height_blocks_sample(height_profile, sample_height):
			result.effect_clear = false
			if StringName(result.effect_source_id).is_empty():
				result.effect_source_id = source_id
				result.source_kind = _source_kind(map_definition, source_id)
		if not bool(result.sight_clear) and not bool(result.effect_clear):
			return result
	return result


static func _height_blocks_sample(
		height_profile: StringName,
		sample_height: int
) -> bool:
	match height_profile:
		TacticalBarrierSegmentDefinition.HEIGHT_LOW:
			return sample_height <= 1
		TacticalBarrierSegmentDefinition.HEIGHT_HIGH:
			return sample_height <= 3
		TacticalBarrierSegmentDefinition.HEIGHT_FULL:
			return true
		_:
			return false


static func _source_kind(
		map_definition: TacticalMapDefinition,
		source_id: StringName
) -> StringName:
	if map_definition == null or source_id.is_empty():
		return &""
	if map_definition.opening_definition(source_id) != null:
		return &"opening"
	if map_definition.structure_definition(source_id) != null:
		return &"structure"
	if map_definition.barrier_definition(source_id) != null:
		return &"barrier"
	return &"environment"


static func _creature_cover_between(
		state: TacticalState,
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		origin: Vector2,
		target_origin: Vector2
) -> Dictionary:
	var trace: Dictionary = _trace_grid(origin, target_origin)
	var tiles: Array = trace.get("tiles", [])
	for index: int in range(1, maxi(1, tiles.size() - 1)):
		var tile_value: Variant = tiles[index]
		if not tile_value is Vector2i:
			continue
		var occupant: TacticalUnitState = state.get_unit_at_tile(
			Vector2i(tile_value),
			attacker.unit_id
		)
		if occupant == null or occupant.unit_id == target.unit_id:
			continue
		if occupant.has_fallen_body_state() or occupant.is_incapacitated():
			continue
		if occupant.footprint.x < target.footprint.x or occupant.footprint.y < target.footprint.y:
			continue
		return {"applies": true, "unit_id": occupant.unit_id}
	return {"applies": false, "unit_id": &""}


static func _highest_count_source(counts: Dictionary) -> StringName:
	var result: StringName = &""
	var highest: int = -1
	var keys: Array = counts.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return String(a) < String(b)
	)
	for key_value: Variant in keys:
		var count: int = int(counts.get(key_value, 0))
		if count > highest:
			highest = count
			result = StringName(key_value)
	return result


static func _resolved_origin(
		unit: TacticalUnitState,
		override_value: Variant
) -> Vector2:
	if override_value is Vector2:
		return Vector2(override_value)
	if override_value is Vector2i:
		return Vector2(override_value) + Vector2(0.5, 0.5)
	return Vector2(unit.grid_position) + Vector2(
		float(maxi(1, unit.footprint.x)) * 0.5,
		float(maxi(1, unit.footprint.y)) * 0.5
	)


static func _resolved_target_origin(
		unit: TacticalUnitState,
		override_value: Variant
) -> Vector2:
	return _resolved_origin(unit, override_value)


static func _trace_grid(start: Vector2, finish: Vector2) -> Dictionary:
	var tiles: Array[Vector2i] = []
	var crossings: Array[Dictionary] = []
	var corner_pairs: Array[Dictionary] = []
	var current := Vector2i(int(floor(start.x)), int(floor(start.y)))
	var target := Vector2i(int(floor(finish.x)), int(floor(finish.y)))
	tiles.append(current)
	if current == target:
		return {"tiles": tiles, "crossings": crossings, "corner_pairs": corner_pairs}

	var delta: Vector2 = finish - start
	var step_x: int = 1 if delta.x > 0.0 else -1
	var step_y: int = 1 if delta.y > 0.0 else -1
	var t_delta_x: float = absf(1.0 / delta.x) if absf(delta.x) > EPSILON else INF
	var t_delta_y: float = absf(1.0 / delta.y) if absf(delta.y) > EPSILON else INF
	var next_boundary_x: float = float(current.x + 1) if step_x > 0 else float(current.x)
	var next_boundary_y: float = float(current.y + 1) if step_y > 0 else float(current.y)
	var t_max_x: float = (next_boundary_x - start.x) / delta.x if absf(delta.x) > EPSILON else INF
	var t_max_y: float = (next_boundary_y - start.y) / delta.y if absf(delta.y) > EPSILON else INF
	var guard: int = 0
	while current != target and guard < 4096:
		guard += 1
		if absf(t_max_x - t_max_y) <= EPSILON:
			# Exact corner crossing is resolved as a pair. One solid side does not
			# create an impossible zero-width wall; two meeting solid sides do.
			var horizontal := current + Vector2i(step_x, 0)
			var vertical := current + Vector2i(0, step_y)
			corner_pairs.append({
				"from": current,
				"first": horizontal,
				"second": vertical,
			})
			current += Vector2i(step_x, step_y)
			t_max_x += t_delta_x
			t_max_y += t_delta_y
		elif t_max_x < t_max_y:
			var next_x := current + Vector2i(step_x, 0)
			crossings.append({"from": current, "to": next_x})
			current = next_x
			t_max_x += t_delta_x
		else:
			var next_y := current + Vector2i(0, step_y)
			crossings.append({"from": current, "to": next_y})
			current = next_y
			t_max_y += t_delta_y
		if not tiles.has(current):
			tiles.append(current)
	return {"tiles": tiles, "crossings": crossings, "corner_pairs": corner_pairs}
