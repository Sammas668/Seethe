class_name TacticalEnvironmentState
extends RefCounted

var opening_states_by_id: Dictionary = {}
var structure_states_by_id: Dictionary = {}
var geometry_revision: int = 0
var _dynamic_difficult_tiles: Dictionary = {}


func configure_from_map(map_definition: TacticalMapDefinition) -> void:
	opening_states_by_id.clear()
	structure_states_by_id.clear()
	geometry_revision = 0
	_dynamic_difficult_tiles.clear()
	if map_definition == null:
		return
	for definition: TacticalOpeningDefinition in map_definition.openings:
		if definition == null or definition.opening_id.is_empty():
			continue
		opening_states_by_id[definition.opening_id] = TacticalOpeningState.new(definition)
	for definition: TacticalStructureDefinition in map_definition.structures:
		if definition == null or definition.structure_id.is_empty():
			continue
		structure_states_by_id[definition.structure_id] = TacticalStructureState.new(definition)
	_rebuild_dynamic_difficult_index(map_definition)


func opening_state(opening_id: StringName) -> TacticalOpeningState:
	return opening_states_by_id.get(opening_id) as TacticalOpeningState


func structure_state(structure_id: StringName) -> TacticalStructureState:
	return structure_states_by_id.get(structure_id) as TacticalStructureState


func opening_definition_at_edge(
		map_definition: TacticalMapDefinition,
		first: Vector2i,
		second: Vector2i
) -> TacticalOpeningDefinition:
	if map_definition == null:
		return null
	return map_definition.opening_at_edge(first, second)


func structure_definition_at_edge(
		map_definition: TacticalMapDefinition,
		first: Vector2i,
		second: Vector2i
) -> TacticalStructureDefinition:
	if map_definition == null:
		return null
	return map_definition.structure_at_edge(first, second)


func barrier_definition_at_edge(
		map_definition: TacticalMapDefinition,
		first: Vector2i,
		second: Vector2i
) -> TacticalBarrierSegmentDefinition:
	if map_definition == null:
		return null
	return map_definition.barrier_at_edge(first, second)


func edge_blocks_movement(
		map_definition: TacticalMapDefinition,
		first: Vector2i,
		second: Vector2i
) -> bool:
	var opening: TacticalOpeningDefinition = opening_definition_at_edge(
		map_definition, first, second
	)
	if opening != null:
		var opening_runtime: TacticalOpeningState = opening_state(opening.opening_id)
		return opening_runtime == null or not opening_runtime.is_open()
	var structure: TacticalStructureDefinition = structure_definition_at_edge(
		map_definition, first, second
	)
	if structure != null:
		var structure_runtime: TacticalStructureState = structure_state(
			structure.structure_id
		)
		if structure_runtime == null:
			return structure.blocks_movement_intact
		return (
			structure.blocks_movement_intact
			and structure_runtime.integrity_state_id not in [
				TacticalStructureDefinition.STATE_BREACHED,
				TacticalStructureDefinition.STATE_DESTROYED,
				TacticalStructureDefinition.STATE_CLEARED,
			]
		)
	var barrier: TacticalBarrierSegmentDefinition = barrier_definition_at_edge(
		map_definition, first, second
	)
	return barrier != null and barrier.blocks_movement


func edge_blocks_sight(
		map_definition: TacticalMapDefinition,
		first: Vector2i,
		second: Vector2i
) -> bool:
	var opening: TacticalOpeningDefinition = opening_definition_at_edge(
		map_definition, first, second
	)
	if opening != null:
		var opening_runtime: TacticalOpeningState = opening_state(opening.opening_id)
		if opening_runtime == null:
			return true
		if opening_runtime.is_open():
			return false
		if opening.opening_kind == TacticalOpeningDefinition.KIND_WINDOW and opening.clear_glass:
			return false
		if opening.opening_kind == TacticalOpeningDefinition.KIND_BARRED_OPENING:
			return false
		return true
	var structure: TacticalStructureDefinition = structure_definition_at_edge(
		map_definition, first, second
	)
	if structure != null:
		var structure_runtime: TacticalStructureState = structure_state(
			structure.structure_id
		)
		if structure_runtime != null and structure_runtime.integrity_state_id in [
			TacticalStructureDefinition.STATE_BREACHED,
			TacticalStructureDefinition.STATE_DESTROYED,
			TacticalStructureDefinition.STATE_CLEARED,
		]:
			return false
		return structure.blocks_sight_intact
	var barrier: TacticalBarrierSegmentDefinition = barrier_definition_at_edge(
		map_definition, first, second
	)
	return barrier != null and barrier.blocks_sight


func edge_blocks_line_of_effect(
		map_definition: TacticalMapDefinition,
		first: Vector2i,
		second: Vector2i
) -> bool:
	var opening: TacticalOpeningDefinition = opening_definition_at_edge(
		map_definition, first, second
	)
	if opening != null:
		var opening_runtime: TacticalOpeningState = opening_state(opening.opening_id)
		if opening_runtime == null:
			return true
		if opening_runtime.is_open():
			return false
		# Clear glass and closed doors are deliberately visible but physically
		# obstruct ordinary direct effects.
		return opening.opening_kind != TacticalOpeningDefinition.KIND_BARRED_OPENING
	var structure: TacticalStructureDefinition = structure_definition_at_edge(
		map_definition, first, second
	)
	if structure != null:
		var structure_runtime: TacticalStructureState = structure_state(
			structure.structure_id
		)
		if structure_runtime != null and structure_runtime.integrity_state_id in [
			TacticalStructureDefinition.STATE_BREACHED,
			TacticalStructureDefinition.STATE_DESTROYED,
			TacticalStructureDefinition.STATE_CLEARED,
		]:
			return false
		return structure.blocks_line_of_effect_intact
	var barrier: TacticalBarrierSegmentDefinition = barrier_definition_at_edge(
		map_definition, first, second
	)
	return barrier != null and barrier.blocks_line_of_effect


func cover_height_at_edge(
		map_definition: TacticalMapDefinition,
		first: Vector2i,
		second: Vector2i
) -> StringName:
	var opening: TacticalOpeningDefinition = opening_definition_at_edge(
		map_definition, first, second
	)
	if opening != null:
		var opening_runtime: TacticalOpeningState = opening_state(opening.opening_id)
		if opening_runtime == null:
			return TacticalBarrierSegmentDefinition.HEIGHT_FULL
		if opening_runtime.is_open():
			return &""
		if opening.opening_kind == TacticalOpeningDefinition.KIND_BARRED_OPENING:
			return TacticalBarrierSegmentDefinition.HEIGHT_HIGH
		return TacticalBarrierSegmentDefinition.HEIGHT_FULL
	var structure: TacticalStructureDefinition = structure_definition_at_edge(
		map_definition, first, second
	)
	if structure != null:
		var structure_runtime: TacticalStructureState = structure_state(
			structure.structure_id
		)
		if structure_runtime == null:
			return structure.height_profile
		match structure_runtime.integrity_state_id:
			TacticalStructureDefinition.STATE_DAMAGED:
				return (
					TacticalBarrierSegmentDefinition.HEIGHT_LOW
					if structure.height_profile == TacticalBarrierSegmentDefinition.HEIGHT_HIGH
					else structure.height_profile
				)
			TacticalStructureDefinition.STATE_BREACHED:
				return TacticalBarrierSegmentDefinition.HEIGHT_LOW
			TacticalStructureDefinition.STATE_DESTROYED, TacticalStructureDefinition.STATE_CLEARED:
				return &""
			_:
				return structure.height_profile
	var barrier: TacticalBarrierSegmentDefinition = barrier_definition_at_edge(
		map_definition, first, second
	)
	return barrier.height_profile if barrier != null and barrier.provides_cover else &""


func cover_source_id_at_edge(
		map_definition: TacticalMapDefinition,
		first: Vector2i,
		second: Vector2i
) -> StringName:
	var opening: TacticalOpeningDefinition = opening_definition_at_edge(
		map_definition, first, second
	)
	if opening != null:
		return opening.opening_id
	var structure: TacticalStructureDefinition = structure_definition_at_edge(
		map_definition, first, second
	)
	if structure != null:
		return structure.structure_id
	var barrier: TacticalBarrierSegmentDefinition = barrier_definition_at_edge(
		map_definition, first, second
	)
	return barrier.segment_id if barrier != null else &""


func is_auto_openable_door(
		map_definition: TacticalMapDefinition,
		first: Vector2i,
		second: Vector2i
) -> bool:
	var definition: TacticalOpeningDefinition = opening_definition_at_edge(
		map_definition, first, second
	)
	if definition == null or definition.opening_kind != TacticalOpeningDefinition.KIND_DOOR:
		return false
	var runtime: TacticalOpeningState = opening_state(definition.opening_id)
	return runtime != null and not runtime.is_open() and runtime.can_operate_normally()


func open_door(opening_id: StringName) -> bool:
	var runtime: TacticalOpeningState = opening_state(opening_id)
	if runtime == null or runtime.is_open() or not runtime.can_operate_normally():
		return false
	runtime.state_id = TacticalOpeningDefinition.STATE_OPEN
	geometry_revision += 1
	return true


func close_door(opening_id: StringName) -> bool:
	var runtime: TacticalOpeningState = opening_state(opening_id)
	if runtime == null or not runtime.is_open() or not runtime.can_operate_normally():
		return false
	runtime.state_id = TacticalOpeningDefinition.STATE_CLOSED
	geometry_revision += 1
	return true


func unlock_opening(opening_id: StringName) -> bool:
	var runtime: TacticalOpeningState = opening_state(opening_id)
	if runtime == null or not runtime.locked:
		return false
	runtime.locked = false
	runtime.state_id = TacticalOpeningDefinition.STATE_CLOSED
	geometry_revision += 1
	return true


func snapshot_source(source_id: StringName) -> Dictionary:
	var opening: TacticalOpeningState = opening_state(source_id)
	if opening != null:
		return {
			"kind": &"opening",
			"state": opening.snapshot(),
			"geometry_revision": geometry_revision,
		}
	var structure: TacticalStructureState = structure_state(source_id)
	if structure != null:
		return {
			"kind": &"structure",
			"state": structure.snapshot(),
			"geometry_revision": geometry_revision,
		}
	return {}


func restore_source(source_id: StringName, snapshot_value: Dictionary) -> void:
	var kind: StringName = StringName(snapshot_value.get("kind", &""))
	var state_value: Variant = snapshot_value.get("state", {})
	if not state_value is Dictionary:
		return
	if kind == &"opening":
		var opening: TacticalOpeningState = opening_state(source_id)
		if opening != null:
			opening.restore(state_value)
	elif kind == &"structure":
		var structure: TacticalStructureState = structure_state(source_id)
		if structure != null:
			structure.restore(state_value)
	geometry_revision = int(snapshot_value.get(
		"geometry_revision", geometry_revision
	))


func apply_damage_to_source(
		map_definition: TacticalMapDefinition,
		source_id: StringName,
		raw_damage: int
) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"source_id": source_id,
		"raw_damage": maxi(0, raw_damage),
		"hardness": 0,
		"applied_damage": 0,
		"before_hp": 0,
		"after_hp": 0,
		"before_integrity": &"",
		"after_integrity": &"",
		"destroyed": false,
		"salvage_item_definition_id": &"",
		"salvage_quantity": 0,
	}
	if map_definition == null or source_id.is_empty():
		return result
	var opening_definition: TacticalOpeningDefinition = map_definition.opening_definition(source_id)
	var opening_runtime: TacticalOpeningState = opening_state(source_id)
	if opening_definition != null and opening_runtime != null:
		result.hardness = opening_definition.hardness
		result.before_hp = opening_runtime.current_hp
		result.before_integrity = opening_runtime.state_id
		result.applied_damage = maxi(0, raw_damage - opening_definition.hardness)
		opening_runtime.current_hp = maxi(0, opening_runtime.current_hp - int(result.applied_damage))
		if opening_runtime.current_hp <= 0:
			opening_runtime.state_id = (
				TacticalOpeningDefinition.STATE_BROKEN
				if opening_definition.opening_kind == TacticalOpeningDefinition.KIND_WINDOW
				else TacticalOpeningDefinition.STATE_DESTROYED
			)
		elif opening_runtime.current_hp <= int(ceil(float(opening_definition.maximum_hp) * 0.5)):
			opening_runtime.state_id = TacticalOpeningDefinition.STATE_DAMAGED
		result.after_hp = opening_runtime.current_hp
		result.after_integrity = opening_runtime.state_id
		result.destroyed = opening_runtime.state_id in [
			TacticalOpeningDefinition.STATE_BROKEN,
			TacticalOpeningDefinition.STATE_DESTROYED,
		]
		result.salvage_item_definition_id = opening_definition.salvage_item_definition_id
		result.salvage_quantity = 1
		result.success = true
		if result.before_integrity != result.after_integrity:
			geometry_revision += 1
			_rebuild_dynamic_difficult_index(map_definition)
		return result
	var structure_definition: TacticalStructureDefinition = map_definition.structure_definition(source_id)
	var structure_runtime: TacticalStructureState = structure_state(source_id)
	if structure_definition != null and structure_runtime != null:
		result.hardness = structure_definition.hardness
		result.before_hp = structure_runtime.current_hp
		result.before_integrity = structure_runtime.integrity_state_id
		result.applied_damage = maxi(0, raw_damage - structure_definition.hardness)
		structure_runtime.current_hp = maxi(0, structure_runtime.current_hp - int(result.applied_damage))
		if structure_runtime.current_hp <= 0:
			structure_runtime.integrity_state_id = TacticalStructureDefinition.STATE_DESTROYED
		elif structure_runtime.current_hp <= structure_definition.breached_threshold_hp:
			structure_runtime.integrity_state_id = TacticalStructureDefinition.STATE_BREACHED
		elif structure_runtime.current_hp <= structure_definition.damaged_threshold_hp:
			structure_runtime.integrity_state_id = TacticalStructureDefinition.STATE_DAMAGED
		else:
			structure_runtime.integrity_state_id = TacticalStructureDefinition.STATE_INTACT
		result.after_hp = structure_runtime.current_hp
		result.after_integrity = structure_runtime.integrity_state_id
		result.destroyed = structure_runtime.integrity_state_id == TacticalStructureDefinition.STATE_DESTROYED
		result.salvage_item_definition_id = structure_definition.salvage_item_definition_id
		result.salvage_quantity = structure_definition.salvage_quantity
		result.success = true
		if result.before_integrity != result.after_integrity:
			geometry_revision += 1
			_rebuild_dynamic_difficult_index(map_definition)
		return result
	return result


func validate_state(map_definition: TacticalMapDefinition) -> Array[String]:
	var errors: Array[String] = []
	if map_definition == null:
		return errors
	for definition: TacticalOpeningDefinition in map_definition.openings:
		if definition != null and opening_state(definition.opening_id) == null:
			errors.append("Environment is missing opening %s." % definition.opening_id)
	for definition: TacticalStructureDefinition in map_definition.structures:
		if definition != null and structure_state(definition.structure_id) == null:
			errors.append("Environment is missing structure %s." % definition.structure_id)
	return errors

func is_dynamic_difficult(
		_map_definition: TacticalMapDefinition,
		tile: Vector2i
) -> bool:
	return bool(_dynamic_difficult_tiles.get(tile, false))


func _rebuild_dynamic_difficult_index(
		map_definition: TacticalMapDefinition
) -> void:
	_dynamic_difficult_tiles.clear()
	if map_definition == null:
		return
	for definition: TacticalStructureDefinition in map_definition.structures:
		if definition == null or not definition.rubble_difficult_terrain:
			continue
		var runtime: TacticalStructureState = structure_state(definition.structure_id)
		if runtime == null or runtime.integrity_state_id not in [
			TacticalStructureDefinition.STATE_BREACHED,
			TacticalStructureDefinition.STATE_DESTROYED,
		]:
			continue
		if definition.geometry_kind == TacticalStructureDefinition.GEOMETRY_TILE:
			for tile: Vector2i in definition.tile_coordinates:
				_dynamic_difficult_tiles[tile] = true
		else:
			_dynamic_difficult_tiles[definition.first_tile] = true
			_dynamic_difficult_tiles[definition.second_tile] = true


func snapshot() -> Dictionary:
	var opening_values: Dictionary = {}
	for key: Variant in opening_states_by_id.keys():
		var runtime: TacticalOpeningState = opening_states_by_id.get(key) as TacticalOpeningState
		if runtime != null:
			opening_values[StringName(key)] = runtime.snapshot()
	var structure_values: Dictionary = {}
	for key: Variant in structure_states_by_id.keys():
		var runtime: TacticalStructureState = structure_states_by_id.get(key) as TacticalStructureState
		if runtime != null:
			structure_values[StringName(key)] = runtime.snapshot()
	return {
		"geometry_revision": geometry_revision,
		"openings": opening_values,
		"structures": structure_values,
	}


func restore(snapshot_value: Dictionary) -> void:
	var opening_values: Variant = snapshot_value.get("openings", {})
	if opening_values is Dictionary:
		for key: Variant in opening_values.keys():
			var runtime: TacticalOpeningState = opening_state(StringName(key))
			var value: Variant = opening_values.get(key, {})
			if runtime != null and value is Dictionary:
				runtime.restore(value)
	var structure_values: Variant = snapshot_value.get("structures", {})
	if structure_values is Dictionary:
		for key: Variant in structure_values.keys():
			var runtime: TacticalStructureState = structure_state(StringName(key))
			var value: Variant = structure_values.get(key, {})
			if runtime != null and value is Dictionary:
				runtime.restore(value)
	geometry_revision = int(snapshot_value.get("geometry_revision", geometry_revision))
