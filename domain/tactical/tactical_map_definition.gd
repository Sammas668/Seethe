class_name TacticalMapDefinition
extends Resource

const WALL_MATERIAL_NONE: StringName = &""
const WALL_MATERIAL_STONE: StringName = &"wall.stone"
const WALL_MATERIAL_WOOD: StringName = &"wall.wood"

var _runtime_index_cache: TacticalMapRuntimeIndex

@export var definition_id: StringName = &""
@export var grid_size: Vector2i = Vector2i(20, 20)
@export var blocked_tiles: Array[Vector2i] = []
@export var difficult_tiles: Array[Vector2i] = []
@export var starting_tile: Vector2i = Vector2i(2, 2)
@export var player_starting_tiles: Array[Vector2i] = []
# Compatibility field retained for existing map resources. Current general sight
# is locked by TacticalGridDistance.GENERAL_SIGHT_RADIUS_TILES.
@export var base_sight_radius_tiles: int = 40
@export var visibility_blocking_tiles: Array[Vector2i] = []
@export var stone_wall_tiles: Array[Vector2i] = []
@export var wood_wall_tiles: Array[Vector2i] = []
# Stage 4.4 authored combat geometry. Thick walls remain full-tile terrain;
# low barriers, openings and damageable cover occupy edges or authored tiles.
@export var edge_barriers: Array[TacticalBarrierSegmentDefinition] = []
@export var openings: Array[TacticalOpeningDefinition] = []
@export var structures: Array[TacticalStructureDefinition] = []

# Stage 4.3.3 mission-loop metadata. Authored map content owns physical
# extraction and objective tiles; TacticalState owns their mutable enabled state.
@export var mission_display_name: String = "Tactical Mission"
@export var primary_objective_id: StringName = &"objective.primary"
@export var primary_objective_text: String = "Complete the mission objective."
@export var primary_objective_tiles: Array[Vector2i] = []
@export var optional_captive_objective_id: StringName = &"objective.optional.captive"
@export var optional_captive_objective_text: String = "Extract at least one living captive."
@export var allows_withdrawal: bool = true
@export var requires_protagonist_extraction: bool = true
@export var extraction_zones: Array[TacticalExtractionZoneDefinition] = []


func runtime_index() -> TacticalMapRuntimeIndex:
	if _runtime_index_cache == null:
		_runtime_index_cache = TacticalMapRuntimeIndex.new()
		_runtime_index_cache.configure(self)
	return _runtime_index_cache


func invalidate_runtime_index() -> void:
	_runtime_index_cache = null


func is_inside(tile: Vector2i) -> bool:
	return runtime_index().is_inside(tile)


func is_wall(tile: Vector2i) -> bool:
	return runtime_index().has_flag(tile, TacticalMapRuntimeIndex.FLAG_WALL)


func wall_material_id(tile: Vector2i) -> StringName:
	return runtime_index().wall_material_id(tile)


func wall_variant_seed(tile: Vector2i) -> int:
	# Stable coordinate hash used only to vary presentation details.
	return absi((tile.x * 73856093) ^ (tile.y * 19349663))


func is_blocked(tile: Vector2i) -> bool:
	return runtime_index().has_flag(
		tile, TacticalMapRuntimeIndex.FLAG_BLOCKS_MOVEMENT
	)


func is_difficult(tile: Vector2i) -> bool:
	return runtime_index().has_flag(tile, TacticalMapRuntimeIndex.FLAG_DIFFICULT)


func blocks_vision(tile: Vector2i) -> bool:
	return runtime_index().has_flag(tile, TacticalMapRuntimeIndex.FLAG_BLOCKS_SIGHT)


func blocks_line_of_effect(tile: Vector2i) -> bool:
	return runtime_index().has_flag(tile, TacticalMapRuntimeIndex.FLAG_BLOCKS_EFFECT)


func movement_multiplier(tile: Vector2i) -> int:
	return 2 if is_difficult(tile) else 1


func barrier_at_edge(
		first: Vector2i,
		second: Vector2i
) -> TacticalBarrierSegmentDefinition:
	return runtime_index().barrier_at_edge(first, second)


func opening_at_edge(
		first: Vector2i,
		second: Vector2i
) -> TacticalOpeningDefinition:
	return runtime_index().opening_at_edge(first, second)


func structure_at_edge(
		first: Vector2i,
		second: Vector2i
) -> TacticalStructureDefinition:
	return runtime_index().structure_at_edge(first, second)


func barrier_definition(segment_id: StringName) -> TacticalBarrierSegmentDefinition:
	return runtime_index().barrier_definition(segment_id)


func opening_definition(opening_id: StringName) -> TacticalOpeningDefinition:
	return runtime_index().opening_definition(opening_id)


func structure_definition(structure_id: StringName) -> TacticalStructureDefinition:
	return runtime_index().structure_definition(structure_id)


func geometry_feature_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: TacticalBarrierSegmentDefinition in edge_barriers:
		if definition != null:
			result.append(definition.segment_id)
	for definition: TacticalOpeningDefinition in openings:
		if definition != null:
			result.append(definition.opening_id)
	for definition: TacticalStructureDefinition in structures:
		if definition != null:
			result.append(definition.structure_id)
	return result


func get_player_starting_tile(index: int, fallback: Vector2i) -> Vector2i:
	if index >= 0 and index < player_starting_tiles.size():
		return player_starting_tiles[index]
	if index == 0:
		return starting_tile
	return fallback


func extraction_zone(zone_id: StringName) -> TacticalExtractionZoneDefinition:
	for zone: TacticalExtractionZoneDefinition in extraction_zones:
		if zone != null and zone.zone_id == zone_id:
			return zone
	return null


func extraction_zone_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for zone: TacticalExtractionZoneDefinition in extraction_zones:
		if zone != null and not zone.zone_id.is_empty():
			result.append(zone.zone_id)
	return result


func is_primary_objective_tile(tile: Vector2i) -> bool:
	return primary_objective_tiles.has(tile)


func validate_definition() -> Array[String]:
	invalidate_runtime_index()
	var errors: Array[String] = []
	if grid_size.x <= 0 or grid_size.y <= 0:
		errors.append("Tactical map grid size must be positive.")
	var occupied_wall_tiles: Dictionary = {}
	_validate_wall_tiles(
		stone_wall_tiles,
		WALL_MATERIAL_STONE,
		occupied_wall_tiles,
		errors
	)
	_validate_wall_tiles(
		wood_wall_tiles,
		WALL_MATERIAL_WOOD,
		occupied_wall_tiles,
		errors
	)
	if mission_display_name.strip_edges().is_empty():
		errors.append("Tactical map has no mission display name.")
	if primary_objective_id.is_empty():
		errors.append("Tactical map has no primary objective ID.")
	for objective_tile: Vector2i in primary_objective_tiles:
		if not is_inside(objective_tile) or is_blocked(objective_tile):
			errors.append("Primary objective tile %s is not usable." % objective_tile)
	var seen_geometry_ids: Dictionary = {}
	var seen_edges: Dictionary = {}
	for barrier: TacticalBarrierSegmentDefinition in edge_barriers:
		if barrier == null:
			errors.append("Tactical map contains a missing edge barrier.")
			continue
		errors.append_array(barrier.validate_definition(self))
		_validate_geometry_identity(
			barrier.segment_id, barrier.edge_id(), seen_geometry_ids, seen_edges, errors
		)
	for opening: TacticalOpeningDefinition in openings:
		if opening == null:
			errors.append("Tactical map contains a missing opening.")
			continue
		errors.append_array(opening.validate_definition(self))
		_validate_geometry_identity(
			opening.opening_id, opening.edge_id(), seen_geometry_ids, seen_edges, errors
		)
	for structure: TacticalStructureDefinition in structures:
		if structure == null:
			errors.append("Tactical map contains a missing structure.")
			continue
		errors.append_array(structure.validate_definition(self))
		var structure_edge: StringName = (
			structure.edge_id()
			if structure.geometry_kind == TacticalStructureDefinition.GEOMETRY_EDGE
			else &""
		)
		_validate_geometry_identity(
			structure.structure_id,
			structure_edge,
			seen_geometry_ids,
			seen_edges,
			errors
		)
	var seen_zone_ids: Dictionary = {}
	for zone: TacticalExtractionZoneDefinition in extraction_zones:
		if zone == null:
			errors.append("Tactical map contains a missing extraction zone.")
			continue
		if seen_zone_ids.has(zone.zone_id):
			errors.append("Tactical map duplicates extraction zone %s." % zone.zone_id)
		seen_zone_ids[zone.zone_id] = true
		errors.append_array(zone.validate_definition(self))
	return errors


func _validate_geometry_identity(
		feature_id: StringName,
		edge_id: StringName,
		seen_ids: Dictionary,
		seen_edges: Dictionary,
		errors: Array[String]
) -> void:
	if feature_id.is_empty():
		return
	if seen_ids.has(feature_id):
		errors.append("Tactical geometry duplicates feature ID %s." % feature_id)
	seen_ids[feature_id] = true
	if edge_id.is_empty():
		return
	if seen_edges.has(edge_id):
		errors.append(
			"Tactical geometry places %s and %s on edge %s."
			% [seen_edges[edge_id], feature_id, edge_id]
		)
	seen_edges[edge_id] = feature_id


func _validate_wall_tiles(
	tiles: Array[Vector2i],
	material_id: StringName,
	occupied_wall_tiles: Dictionary,
	errors: Array[String]
) -> void:
	for tile: Vector2i in tiles:
		if not is_inside(tile):
			errors.append(
				"Wall %s at %s lies outside the map."
				% [material_id, tile]
			)
		if occupied_wall_tiles.has(tile):
			errors.append(
				"Wall tile %s has more than one material." % tile
			)
		occupied_wall_tiles[tile] = material_id
		if blocked_tiles.has(tile):
			errors.append(
				"Wall tile %s is duplicated in blocked_tiles." % tile
			)
