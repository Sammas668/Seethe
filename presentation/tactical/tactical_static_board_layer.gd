class_name TacticalStaticBoardLayer
extends Node2D

const WALL_ADJACENCY_RESOLVER_SCRIPT: Script = preload(
	"res://presentation/tactical/walls/wall_adjacency_resolver.gd"
)
const TACTICAL_WALL_RENDERER_SCRIPT: Script = preload(
	"res://presentation/tactical/walls/tactical_wall_renderer.gd"
)
const STONE_WALL_DEFINITION: Resource = preload(
	"res://content/environment/walls/stone_wall_definition.tres"
)
const WOOD_WALL_DEFINITION: Resource = preload(
	"res://content/environment/walls/wood_wall_definition.tres"
)

const TILE_SIZE: float = 28.0
const FLOOR_COLOR := Color(0.18, 0.21, 0.24, 1.0)
const ALTERNATE_FLOOR_COLOR := Color(0.205, 0.235, 0.265, 1.0)
const GRID_COLOR := Color(0.055, 0.07, 0.085, 0.88)
const BLOCKED_COLOR := Color(0.17, 0.12, 0.09, 1.0)
const DIFFICULT_COLOR := Color(0.40, 0.285, 0.16, 1.0)
const BARRIER_WOOD_COLOR := Color(0.52, 0.31, 0.14, 1.0)
const BARRIER_STONE_COLOR := Color(0.48, 0.51, 0.55, 1.0)
const BARRIER_METAL_COLOR := Color(0.56, 0.64, 0.68, 1.0)
const WINDOW_COLOR := Color(0.45, 0.86, 0.96, 0.78)
const OPENING_INK_COLOR := Color(0.08, 0.055, 0.035, 0.98)
const OPENING_GLASS_FILL := Color(0.42, 0.76, 0.88, 0.42)
const EXTRACTION_ZONE_COLOR := Color(0.18, 0.72, 0.76, 0.18)
const EXTRACTION_ZONE_BORDER := Color(0.32, 0.92, 0.94, 0.92)
const EXTRACTION_ZONE_BLOCKED := Color(0.82, 0.20, 0.16, 0.40)

var _map_definition: TacticalMapDefinition
var _facade
var _camera_zoom: float = 0.78
var _wall_adjacency_resolver: RefCounted
var _wall_renderer: RefCounted
var _redraw_count: int = 0
var _last_draw_usec: int = 0


func configure(
		map_definition: TacticalMapDefinition,
		facade,
		camera_zoom: float
) -> void:
	_map_definition = map_definition
	_facade = facade
	_camera_zoom = camera_zoom
	_wall_adjacency_resolver = WALL_ADJACENCY_RESOLVER_SCRIPT.new()
	_wall_renderer = TACTICAL_WALL_RENDERER_SCRIPT.new()
	queue_redraw()


func set_camera_zoom(value: float) -> void:
	if is_equal_approx(_camera_zoom, value):
		return
	_camera_zoom = value
	queue_redraw()


func refresh_environment() -> void:
	queue_redraw()


func performance_snapshot() -> Dictionary:
	return {
		"redraw_count": _redraw_count,
		"last_draw_usec": _last_draw_usec,
	}


func _draw() -> void:
	if _map_definition == null or _facade == null:
		return
	var started_usec: int = Time.get_ticks_usec()
	_draw_floor_and_walls()
	_draw_edge_geometry()
	_draw_extraction_zones()
	_redraw_count += 1
	_last_draw_usec = Time.get_ticks_usec() - started_usec


func _draw_floor_and_walls() -> void:
	for y: int in range(_map_definition.grid_size.y):
		for x: int in range(_map_definition.grid_size.x):
			var tile := Vector2i(x, y)
			var rectangle := _tile_rect(tile)
			var fill_color := FLOOR_COLOR
			if _camera_zoom > 0.62 and (x + y) % 2 != 0:
				fill_color = ALTERNATE_FLOOR_COLOR
			if _map_definition.is_difficult(tile):
				fill_color = DIFFICULT_COLOR
			draw_rect(rectangle, fill_color, true)
			if _map_definition.is_wall(tile):
				var material_definition: Resource = _wall_definition_for_tile(tile)
				var connections: int = int(
					_wall_adjacency_resolver.call(
						"connections_for",
						_map_definition,
						tile
					)
				)
				_wall_renderer.call(
					"draw_wall",
					self,
					rectangle,
					material_definition,
					connections,
					_camera_zoom,
					_map_definition.wall_variant_seed(tile)
				)
			elif _map_definition.blocked_tiles.has(tile):
				draw_rect(rectangle.grow(-2.0), BLOCKED_COLOR, true)
			if _camera_zoom >= 0.52 and not _map_definition.is_wall(tile):
				draw_rect(rectangle, GRID_COLOR, false, 1.0 / _camera_zoom)
	var board_size := Vector2(_map_definition.grid_size) * TILE_SIZE
	draw_rect(
		Rect2(Vector2.ZERO, board_size),
		Color(0.55, 0.61, 0.66, 1.0),
		false,
		2.0 / _camera_zoom
	)


func _draw_edge_geometry() -> void:
	for barrier: TacticalBarrierSegmentDefinition in _map_definition.edge_barriers:
		if barrier == null:
			continue
		_draw_geometry_edge(
			barrier.first_tile,
			barrier.second_tile,
			_barrier_color(barrier.material_profile_id),
			3.0 if barrier.height_profile == TacticalBarrierSegmentDefinition.HEIGHT_LOW else 5.0,
			false
		)
	var environment: TacticalEnvironmentState = _facade.state().environment_state
	for opening: TacticalOpeningDefinition in _map_definition.openings:
		if opening == null:
			continue
		var runtime: TacticalOpeningState = (
			environment.opening_state(opening.opening_id)
			if environment != null else null
		)
		_draw_opening_feature(opening, runtime)
	for structure: TacticalStructureDefinition in _map_definition.structures:
		if structure == null:
			continue
		var runtime: TacticalStructureState = (
			environment.structure_state(structure.structure_id)
			if environment != null else null
		)
		if structure.geometry_kind == TacticalStructureDefinition.GEOMETRY_EDGE:
			var broken: bool = runtime != null and runtime.integrity_state_id in [
				TacticalStructureDefinition.STATE_BREACHED,
				TacticalStructureDefinition.STATE_DESTROYED,
				TacticalStructureDefinition.STATE_CLEARED,
			]
			_draw_geometry_edge(
				structure.first_tile,
				structure.second_tile,
				_barrier_color(structure.material_profile_id),
				2.0 if broken else 6.0,
				broken
			)
			if runtime != null and runtime.integrity_state_id == TacticalStructureDefinition.STATE_DAMAGED:
				_draw_damage_crack(_edge_midpoint(structure.first_tile, structure.second_tile))
		elif runtime != null:
			for tile: Vector2i in structure.tile_coordinates:
				var rectangle: Rect2 = _tile_rect(tile).grow(-3.0)
				draw_rect(rectangle, _barrier_color(structure.material_profile_id), true)


func _draw_geometry_edge(
		first: Vector2i,
		second: Vector2i,
		color: Color,
		width: float,
		broken: bool
) -> void:
	var endpoints: PackedVector2Array = _edge_endpoints(first, second)
	if endpoints.size() < 2:
		return
	if broken:
		var middle: Vector2 = (endpoints[0] + endpoints[1]) * 0.5
		var direction: Vector2 = (endpoints[1] - endpoints[0]).normalized()
		draw_line(endpoints[0], middle - direction * 4.0, color, width / _camera_zoom, true)
		draw_line(middle + direction * 4.0, endpoints[1], color, width / _camera_zoom, true)
	else:
		draw_line(endpoints[0], endpoints[1], color, width / _camera_zoom, true)


func _draw_opening_feature(
		opening: TacticalOpeningDefinition,
		runtime: TacticalOpeningState
) -> void:
	var endpoints: PackedVector2Array = _edge_endpoints(
		opening.first_tile,
		opening.second_tile
	)
	if endpoints.size() < 2:
		return
	var state_id: StringName = (
		runtime.state_id if runtime != null else opening.initial_state_id
	)
	if opening.opening_kind == TacticalOpeningDefinition.KIND_WINDOW:
		_draw_inked_window(state_id, endpoints)
	elif opening.opening_kind == TacticalOpeningDefinition.KIND_BARRED_OPENING:
		_draw_inked_barred_opening(opening, endpoints)
	else:
		_draw_inked_door(opening, state_id, endpoints)
	if runtime != null and runtime.locked:
		_draw_small_lock(_edge_midpoint(opening.first_tile, opening.second_tile))
	if state_id == TacticalOpeningDefinition.STATE_DAMAGED:
		_draw_damage_crack(_edge_midpoint(opening.first_tile, opening.second_tile))


func _draw_inked_door(
		opening: TacticalOpeningDefinition,
		state_id: StringName,
		endpoints: PackedVector2Array
) -> void:
	var tangent: Vector2 = (endpoints[1] - endpoints[0]).normalized()
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	var wood: Color = _barrier_color(opening.material_profile_id)
	var is_open: bool = state_id in [
		TacticalOpeningDefinition.STATE_OPEN,
		TacticalOpeningDefinition.STATE_BROKEN,
		TacticalOpeningDefinition.STATE_DESTROYED,
	]
	for endpoint: Vector2 in endpoints:
		draw_line(endpoint - normal * 4.5, endpoint + normal * 4.5, OPENING_INK_COLOR, 5.5 / _camera_zoom, true)
		draw_line(endpoint - normal * 3.2, endpoint + normal * 3.2, wood.lightened(0.12), 2.8 / _camera_zoom, true)
	if not is_open:
		draw_line(endpoints[0], endpoints[1], OPENING_INK_COLOR, 10.0 / _camera_zoom, true)
		draw_line(endpoints[0], endpoints[1], wood, 6.5 / _camera_zoom, true)
		for ratio: float in [0.24, 0.50, 0.76]:
			var point: Vector2 = endpoints[0].lerp(endpoints[1], ratio)
			draw_line(point - normal * 3.2, point + normal * 3.2, OPENING_INK_COLOR, 1.0 / _camera_zoom, true)
	else:
		var hinge: Vector2 = endpoints[0]
		var leaf_end: Vector2 = hinge + normal * 17.0 + tangent * 3.0
		draw_line(hinge, leaf_end, OPENING_INK_COLOR, 9.0 / _camera_zoom, true)
		draw_line(hinge, leaf_end, wood, 5.8 / _camera_zoom, true)


func _draw_inked_window(
		state_id: StringName,
		endpoints: PackedVector2Array
) -> void:
	var tangent: Vector2 = (endpoints[1] - endpoints[0]).normalized()
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	var is_open: bool = state_id in [
		TacticalOpeningDefinition.STATE_OPEN,
		TacticalOpeningDefinition.STATE_BROKEN,
		TacticalOpeningDefinition.STATE_DESTROYED,
	]
	draw_line(endpoints[0], endpoints[1], OPENING_INK_COLOR, 10.0 / _camera_zoom, true)
	draw_line(endpoints[0], endpoints[1], WINDOW_COLOR.darkened(0.18), 6.5 / _camera_zoom, true)
	if not is_open:
		draw_line(endpoints[0] + tangent * 2.0, endpoints[1] - tangent * 2.0, OPENING_GLASS_FILL, 4.5 / _camera_zoom, true)
		var middle: Vector2 = (endpoints[0] + endpoints[1]) * 0.5
		draw_line(middle - normal * 4.0, middle + normal * 4.0, OPENING_INK_COLOR, 1.2 / _camera_zoom, true)
	else:
		var middle: Vector2 = (endpoints[0] + endpoints[1]) * 0.5
		draw_line(endpoints[0], middle - tangent * 4.0, WINDOW_COLOR, 4.5 / _camera_zoom, true)
		draw_line(middle + tangent * 4.0, endpoints[1], WINDOW_COLOR, 4.5 / _camera_zoom, true)


func _draw_inked_barred_opening(
		opening: TacticalOpeningDefinition,
		endpoints: PackedVector2Array
) -> void:
	var tangent: Vector2 = (endpoints[1] - endpoints[0]).normalized()
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	draw_line(endpoints[0], endpoints[1], OPENING_INK_COLOR, 10.0 / _camera_zoom, true)
	draw_line(endpoints[0], endpoints[1], _barrier_color(opening.material_profile_id), 6.0 / _camera_zoom, true)
	for ratio: float in [0.18, 0.40, 0.62, 0.84]:
		var point: Vector2 = endpoints[0].lerp(endpoints[1], ratio)
		draw_line(point - normal * 5.0, point + normal * 5.0, OPENING_INK_COLOR, 2.4 / _camera_zoom, true)
		draw_line(point - normal * 4.2, point + normal * 4.2, BARRIER_METAL_COLOR, 1.2 / _camera_zoom, true)


func _draw_extraction_zones() -> void:
	if not _facade.has_method("extraction_zone_definitions"):
		return
	for zone: TacticalExtractionZoneDefinition in _facade.extraction_zone_definitions():
		if zone == null:
			continue
		var zone_state: TacticalExtractionZoneState = _facade.extraction_zone_state(
			zone.zone_id
		)
		var usable: bool = zone_state != null and zone_state.is_usable()
		var fill: Color = EXTRACTION_ZONE_COLOR if usable else EXTRACTION_ZONE_BLOCKED
		var border: Color = EXTRACTION_ZONE_BORDER if usable else Color(0.96, 0.34, 0.28, 0.95)
		for tile: Vector2i in zone.tile_coordinates:
			if not _map_definition.is_inside(tile):
				continue
			var rectangle: Rect2 = _tile_rect(tile).grow(-2.0)
			draw_rect(rectangle, fill, true)
			draw_rect(rectangle, border, false, 1.5 / _camera_zoom)


func _wall_definition_for_tile(tile: Vector2i) -> Resource:
	if _map_definition.wall_material_id(tile) == TacticalMapDefinition.WALL_MATERIAL_WOOD:
		return WOOD_WALL_DEFINITION
	return STONE_WALL_DEFINITION


func _barrier_color(material_id: StringName) -> Color:
	var value: String = String(material_id)
	if value.contains("stone"):
		return BARRIER_STONE_COLOR
	if value.contains("iron") or value.contains("metal"):
		return BARRIER_METAL_COLOR
	return BARRIER_WOOD_COLOR


func _edge_endpoints(first: Vector2i, second: Vector2i) -> PackedVector2Array:
	var delta: Vector2i = second - first
	if delta.x != 0:
		var x: float = float(maxi(first.x, second.x)) * TILE_SIZE
		var y0: float = float(first.y) * TILE_SIZE
		return PackedVector2Array([
			Vector2(x, y0 + 2.0),
			Vector2(x, y0 + TILE_SIZE - 2.0),
		])
	if delta.y != 0:
		var y: float = float(maxi(first.y, second.y)) * TILE_SIZE
		var x0: float = float(first.x) * TILE_SIZE
		return PackedVector2Array([
			Vector2(x0 + 2.0, y),
			Vector2(x0 + TILE_SIZE - 2.0, y),
		])
	return PackedVector2Array()


func _edge_midpoint(first: Vector2i, second: Vector2i) -> Vector2:
	var endpoints: PackedVector2Array = _edge_endpoints(first, second)
	return (
		(endpoints[0] + endpoints[1]) * 0.5
		if endpoints.size() >= 2
		else _tile_rect(first).get_center()
	)


func _draw_small_lock(centre: Vector2) -> void:
	draw_rect(Rect2(centre - Vector2(3.5, 1.0), Vector2(7.0, 6.0)), Color(0.94, 0.76, 0.22, 1.0), true)
	draw_arc(centre + Vector2(0.0, -1.0), 3.0, PI, TAU, 10, Color(0.94, 0.76, 0.22, 1.0), 1.3 / _camera_zoom, true)


func _draw_damage_crack(centre: Vector2) -> void:
	draw_polyline(PackedVector2Array([
		centre + Vector2(-4.0, -5.0),
		centre + Vector2(-1.0, -1.0),
		centre + Vector2(-3.0, 2.0),
		centre + Vector2(4.0, 5.0),
	]), Color(0.08, 0.06, 0.04, 0.95), 1.5 / _camera_zoom, true)


func _tile_rect(tile: Vector2i) -> Rect2:
	return Rect2(Vector2(tile) * TILE_SIZE, Vector2.ONE * TILE_SIZE)
