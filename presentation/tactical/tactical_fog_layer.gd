class_name TacticalFogLayer
extends Node2D

const TILE_SIZE: float = 28.0
const EXPLORED_OVERLAY_COLOR := Color(0.025, 0.035, 0.065, 0.62)
const UNSEEN_COLOR := Color(0.018, 0.014, 0.027, 1.0)
const VISIBLE_COLOR := Color(0.0, 0.0, 0.0, 0.0)

var _map_definition: TacticalMapDefinition
var _facade
var _camera_zoom: float = 0.78
var _fog_image: Image
var _fog_texture: ImageTexture
var _redraw_count: int = 0
var _last_draw_usec: int = 0
var _mask_update_count: int = 0
var _full_mask_rebuild_count: int = 0
var _texture_upload_count: int = 0
var _last_mask_update_usec: int = 0
var _last_changed_cell_count: int = 0
var _last_applied_visibility_revision: int = -1
var _last_applied_knowledge_revision: int = -1
var _fallback_refresh_scheduled: bool = false


func configure(
		map_definition: TacticalMapDefinition,
		facade,
		camera_zoom: float
) -> void:
	_map_definition = map_definition
	_facade = facade
	_camera_zoom = camera_zoom
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_initial_mask()
	queue_redraw()


func set_camera_zoom(value: float) -> void:
	_camera_zoom = value


func refresh_fog() -> void:
	if _try_apply_latest_delta():
		return
	if _fallback_refresh_scheduled:
		return
	_fallback_refresh_scheduled = true
	call_deferred("_refresh_fog_fallback")


func apply_visibility_delta(delta: Dictionary) -> void:
	if _map_definition == null or _facade == null or delta.is_empty():
		return
	var visibility_revision: int = int(delta.get("visibility_revision", -1))
	var knowledge_revision: int = int(delta.get("knowledge_revision", -1))
	if (
		visibility_revision <= _last_applied_visibility_revision
		and knowledge_revision <= _last_applied_knowledge_revision
	):
		return

	var started_usec: int = Time.get_ticks_usec()
	var changed_tiles: Dictionary = {}
	_apply_tile_array(
		delta.get("newly_explored", []),
		TacticalVisibilityService.TILE_EXPLORED,
		changed_tiles,
		false
	)
	_apply_tile_array(
		delta.get("no_longer_visible", []),
		TacticalVisibilityService.TILE_EXPLORED,
		changed_tiles,
		false
	)
	_apply_tile_array(
		delta.get("newly_visible", []),
		TacticalVisibilityService.TILE_VISIBLE,
		changed_tiles,
		false
	)

	_last_applied_visibility_revision = maxi(
		_last_applied_visibility_revision,
		visibility_revision
	)
	_last_applied_knowledge_revision = maxi(
		_last_applied_knowledge_revision,
		knowledge_revision
	)
	_last_changed_cell_count = changed_tiles.size()
	if _last_changed_cell_count > 0:
		_upload_mask()
		_mask_update_count += 1
	_last_mask_update_usec = Time.get_ticks_usec() - started_usec


func performance_snapshot() -> Dictionary:
	return {
		"redraw_count": _redraw_count,
		"last_draw_usec": _last_draw_usec,
		"mask_update_count": _mask_update_count,
		"full_mask_rebuild_count": _full_mask_rebuild_count,
		"texture_upload_count": _texture_upload_count,
		"last_mask_update_usec": _last_mask_update_usec,
		"last_changed_cell_count": _last_changed_cell_count,
		"last_applied_visibility_revision": _last_applied_visibility_revision,
		"last_applied_knowledge_revision": _last_applied_knowledge_revision,
	}


func _draw() -> void:
	if _map_definition == null or _fog_texture == null:
		return
	var started_usec: int = Time.get_ticks_usec()
	draw_texture_rect(
		_fog_texture,
		Rect2(
			Vector2.ZERO,
			Vector2(_map_definition.grid_size) * TILE_SIZE
		),
		false
	)
	_redraw_count += 1
	_last_draw_usec = Time.get_ticks_usec() - started_usec


func _build_initial_mask() -> void:
	if _map_definition == null or _facade == null:
		return
	var started_usec: int = Time.get_ticks_usec()
	_fog_image = Image.create(
		maxi(1, _map_definition.grid_size.x),
		maxi(1, _map_definition.grid_size.y),
		false,
		Image.FORMAT_RGBA8
	)
	for y: int in range(_map_definition.grid_size.y):
		for x: int in range(_map_definition.grid_size.x):
			var tile := Vector2i(x, y)
			_set_tile_state(tile, _resolved_tile_state(tile))
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	_texture_upload_count += 1
	_full_mask_rebuild_count += 1
	_last_changed_cell_count = (
		_map_definition.grid_size.x * _map_definition.grid_size.y
	)
	_last_applied_visibility_revision = int(_facade.visibility_revision())
	_last_applied_knowledge_revision = int(_facade.knowledge_revision())
	_last_mask_update_usec = Time.get_ticks_usec() - started_usec


func _try_apply_latest_delta() -> bool:
	if _facade == null or not _facade.has_method("visibility_delta_for_player"):
		return false
	var delta_value: Variant = _facade.call("visibility_delta_for_player")
	if not (delta_value is Dictionary):
		return false
	var delta: Dictionary = delta_value
	var visibility_revision: int = int(delta.get("visibility_revision", -1))
	var knowledge_revision: int = int(delta.get("knowledge_revision", -1))
	if (
		visibility_revision <= _last_applied_visibility_revision
		and knowledge_revision <= _last_applied_knowledge_revision
	):
		return false
	apply_visibility_delta(delta)
	return true


func _refresh_fog_fallback() -> void:
	_fallback_refresh_scheduled = false
	if _try_apply_latest_delta():
		return
	if _facade == null:
		return
	var current_visibility_revision: int = int(_facade.visibility_revision())
	var current_knowledge_revision: int = int(_facade.knowledge_revision())
	if (
		current_visibility_revision == _last_applied_visibility_revision
		and current_knowledge_revision == _last_applied_knowledge_revision
	):
		return
	_build_initial_mask()
	queue_redraw()


func _apply_tile_array(
		tiles_value: Variant,
		requested_state: int,
		changed_tiles: Dictionary,
		resolve_visible_state: bool
) -> void:
	if not (tiles_value is Array):
		return
	for tile_value: Variant in tiles_value:
		if not (tile_value is Vector2i):
			continue
		var tile := Vector2i(tile_value)
		if _map_definition == null or not _map_definition.is_inside(tile):
			continue
		var tile_state: int = requested_state
		if resolve_visible_state and _facade.is_tile_visible_to_player(tile):
			tile_state = TacticalVisibilityService.TILE_VISIBLE
		_set_tile_state(tile, tile_state)
		changed_tiles[tile] = true


func _resolved_tile_state(tile: Vector2i) -> int:
	if _facade.is_tile_visible_to_player(tile):
		return TacticalVisibilityService.TILE_VISIBLE
	if _facade.is_tile_explored_by_player(tile):
		return TacticalVisibilityService.TILE_EXPLORED
	return TacticalVisibilityService.TILE_UNSEEN


func _set_tile_state(tile: Vector2i, tile_state: int) -> void:
	if _fog_image == null:
		return
	match tile_state:
		TacticalVisibilityService.TILE_VISIBLE:
			_fog_image.set_pixelv(tile, VISIBLE_COLOR)
		TacticalVisibilityService.TILE_EXPLORED:
			_fog_image.set_pixelv(tile, _varied_fog_color(tile, EXPLORED_OVERLAY_COLOR))
		_:
			_fog_image.set_pixelv(tile, _varied_fog_color(tile, UNSEEN_COLOR))


func _varied_fog_color(tile: Vector2i, base_color: Color) -> Color:
	var seed: int = _map_definition.wall_variant_seed(tile)
	var variation: float = float((seed % 9) - 4) * 0.0025
	return Color(
		clampf(base_color.r + variation, 0.0, 1.0),
		clampf(base_color.g + variation, 0.0, 1.0),
		clampf(base_color.b + variation, 0.0, 1.0),
		base_color.a
	)


func _upload_mask() -> void:
	if _fog_image == null:
		return
	if _fog_texture == null:
		_fog_texture = ImageTexture.create_from_image(_fog_image)
	else:
		_fog_texture.update(_fog_image)
	_texture_upload_count += 1
	queue_redraw()
