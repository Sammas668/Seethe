class_name TacticalMapRuntimeIndex
extends RefCounted

const FLAG_BLOCKS_MOVEMENT: int = 1 << 0
const FLAG_BLOCKS_SIGHT: int = 1 << 1
const FLAG_BLOCKS_EFFECT: int = 1 << 2
const FLAG_DIFFICULT: int = 1 << 3
const FLAG_WALL: int = 1 << 4
const FLAG_SUPPORTS_GROUND: int = 1 << 5

var grid_size: Vector2i = Vector2i.ZERO
var tile_flags: PackedByteArray = PackedByteArray()
var wall_material_by_tile: Dictionary = {}
var barrier_by_edge: Dictionary = {}
var opening_by_edge: Dictionary = {}
var structure_by_edge: Dictionary = {}
var barriers_by_id: Dictionary = {}
var openings_by_id: Dictionary = {}
var structures_by_id: Dictionary = {}
var build_revision: int = 0


func configure(map_definition: TacticalMapDefinition) -> void:
	grid_size = map_definition.grid_size if map_definition != null else Vector2i.ZERO
	tile_flags = PackedByteArray()
	tile_flags.resize(maxi(0, grid_size.x * grid_size.y))
	tile_flags.fill(FLAG_SUPPORTS_GROUND)
	wall_material_by_tile.clear()
	barrier_by_edge.clear()
	opening_by_edge.clear()
	structure_by_edge.clear()
	barriers_by_id.clear()
	openings_by_id.clear()
	structures_by_id.clear()
	if map_definition == null:
		build_revision += 1
		return

	for tile: Vector2i in map_definition.blocked_tiles:
		_set_flags(tile, FLAG_BLOCKS_MOVEMENT | FLAG_BLOCKS_SIGHT | FLAG_BLOCKS_EFFECT)
	for tile: Vector2i in map_definition.visibility_blocking_tiles:
		_set_flags(tile, FLAG_BLOCKS_SIGHT)
	for tile: Vector2i in map_definition.difficult_tiles:
		_set_flags(tile, FLAG_DIFFICULT)
	for tile: Vector2i in map_definition.stone_wall_tiles:
		_set_wall(tile, TacticalMapDefinition.WALL_MATERIAL_STONE)
	for tile: Vector2i in map_definition.wood_wall_tiles:
		_set_wall(tile, TacticalMapDefinition.WALL_MATERIAL_WOOD)

	for definition: TacticalBarrierSegmentDefinition in map_definition.edge_barriers:
		if definition == null:
			continue
		barriers_by_id[definition.segment_id] = definition
		barrier_by_edge[definition.edge_id()] = definition
	for definition: TacticalOpeningDefinition in map_definition.openings:
		if definition == null:
			continue
		openings_by_id[definition.opening_id] = definition
		opening_by_edge[definition.edge_id()] = definition
	for definition: TacticalStructureDefinition in map_definition.structures:
		if definition == null:
			continue
		structures_by_id[definition.structure_id] = definition
		if definition.geometry_kind == TacticalStructureDefinition.GEOMETRY_EDGE:
			structure_by_edge[definition.edge_id()] = definition
	build_revision += 1


func is_inside(tile: Vector2i) -> bool:
	return (
		tile.x >= 0
		and tile.y >= 0
		and tile.x < grid_size.x
		and tile.y < grid_size.y
	)


func has_flag(tile: Vector2i, flag: int) -> bool:
	if not is_inside(tile):
		return flag in [FLAG_BLOCKS_MOVEMENT, FLAG_BLOCKS_SIGHT, FLAG_BLOCKS_EFFECT]
	return (int(tile_flags[_tile_index(tile)]) & flag) != 0


func wall_material_id(tile: Vector2i) -> StringName:
	return StringName(wall_material_by_tile.get(tile, TacticalMapDefinition.WALL_MATERIAL_NONE))


func barrier_at_edge(first: Vector2i, second: Vector2i) -> TacticalBarrierSegmentDefinition:
	return barrier_by_edge.get(TacticalEdgeKey.make_id(first, second)) as TacticalBarrierSegmentDefinition


func opening_at_edge(first: Vector2i, second: Vector2i) -> TacticalOpeningDefinition:
	return opening_by_edge.get(TacticalEdgeKey.make_id(first, second)) as TacticalOpeningDefinition


func structure_at_edge(first: Vector2i, second: Vector2i) -> TacticalStructureDefinition:
	return structure_by_edge.get(TacticalEdgeKey.make_id(first, second)) as TacticalStructureDefinition


func barrier_definition(segment_id: StringName) -> TacticalBarrierSegmentDefinition:
	return barriers_by_id.get(segment_id) as TacticalBarrierSegmentDefinition


func opening_definition(opening_id: StringName) -> TacticalOpeningDefinition:
	return openings_by_id.get(opening_id) as TacticalOpeningDefinition


func structure_definition(structure_id: StringName) -> TacticalStructureDefinition:
	return structures_by_id.get(structure_id) as TacticalStructureDefinition


func _set_wall(tile: Vector2i, material_id: StringName) -> void:
	_set_flags(
		tile,
		FLAG_BLOCKS_MOVEMENT
		| FLAG_BLOCKS_SIGHT
		| FLAG_BLOCKS_EFFECT
		| FLAG_WALL
	)
	if is_inside(tile):
		wall_material_by_tile[tile] = material_id


func _set_flags(tile: Vector2i, flags: int) -> void:
	if not is_inside(tile):
		return
	var index: int = _tile_index(tile)
	tile_flags[index] = int(tile_flags[index]) | flags


func _tile_index(tile: Vector2i) -> int:
	return tile.y * grid_size.x + tile.x
