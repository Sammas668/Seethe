class_name TacticalFogLayer
extends Node2D

const TACTICAL_FOG_RENDERER_SCRIPT: Script = preload(
	"res://presentation/tactical/walls/tactical_fog_renderer.gd"
)

const TILE_SIZE: float = 28.0
const EXPLORED_OVERLAY_COLOR := Color(0.025, 0.035, 0.065, 0.62)
const UNSEEN_COLOR := Color(0.018, 0.014, 0.027, 1.0)

var _map_definition: TacticalMapDefinition
var _facade
var _camera_zoom: float = 0.78
var _fog_renderer: RefCounted
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
	_fog_renderer = TACTICAL_FOG_RENDERER_SCRIPT.new()
	queue_redraw()


func set_camera_zoom(value: float) -> void:
	if is_equal_approx(_camera_zoom, value):
		return
	_camera_zoom = value
	queue_redraw()


func refresh_fog() -> void:
	queue_redraw()


func performance_snapshot() -> Dictionary:
	return {
		"redraw_count": _redraw_count,
		"last_draw_usec": _last_draw_usec,
	}


func _draw() -> void:
	if _map_definition == null or _facade == null or _fog_renderer == null:
		return
	var started_usec: int = Time.get_ticks_usec()
	for y: int in range(_map_definition.grid_size.y):
		for x: int in range(_map_definition.grid_size.x):
			var tile := Vector2i(x, y)
			var rectangle := Rect2(Vector2(tile) * TILE_SIZE, Vector2.ONE * TILE_SIZE)
			var seed: int = _map_definition.wall_variant_seed(tile)
			if not _facade.is_tile_explored_by_player(tile):
				_fog_renderer.call(
					"draw_unseen",
					self,
					rectangle,
					_camera_zoom,
					seed,
					UNSEEN_COLOR
				)
			elif not _facade.is_tile_visible_to_player(tile):
				_fog_renderer.call(
					"draw_explored",
					self,
					rectangle,
					_camera_zoom,
					seed,
					EXPLORED_OVERLAY_COLOR
				)
	_redraw_count += 1
	_last_draw_usec = Time.get_ticks_usec() - started_usec
