class_name RegionMapStaticLayer
extends RegionMapView

const STATIC_RADIUS: float = 32.0

var _terrain_symbol_detail_visible: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	size = Vector2(2048.0, 2048.0)


func configure_static(definition: RegionMapDefinition, layer_visibility: Dictionary) -> void:
	_definition = definition
	_campaign = null
	_agent_preview_provider = Callable()
	_layer_visibility = layer_visibility.duplicate(true)
	_hovered_site_id = &""
	_selected_site_id = &""
	_zoom = 1.0 if _terrain_symbol_detail_visible else 0.5
	queue_redraw()


func set_static_layer_visible(layer_id: StringName, visible: bool) -> void:
	_layer_visibility[String(layer_id)] = visible
	queue_redraw()


func set_terrain_symbol_detail_visible(visible: bool) -> void:
	if _terrain_symbol_detail_visible == visible:
		return
	_terrain_symbol_detail_visible = visible
	_zoom = 1.0 if visible else 0.5
	queue_redraw()


func rebuild_static_content() -> void:
	var started_usec: int = RuntimeStallAttribution.begin()
	queue_redraw()
	RuntimeStallAttribution.end(&"region_static_rebuild", started_usec, "queued")


func _draw() -> void:
	var started_usec: int = RuntimeStallAttribution.begin()
	if _definition == null:
		return
	if bool(_layer_visibility.get("terrain", true)):
		_draw_hex_fills()
	if bool(_layer_visibility.get("terrain_symbols", true)):
		_draw_terrain_symbols()
	if bool(_layer_visibility.get("hex_outlines", true)):
		_draw_hex_borders()
	if bool(_layer_visibility.get("settlement_footprints", true)):
		_draw_settlement_footprint_pads()
	if bool(_layer_visibility.get("borders", true)):
		_draw_subregion_borders()
	if bool(_layer_visibility.get("roads", true)):
		_draw_road_edges()
	if bool(_layer_visibility.get("sites", true)):
		_draw_static_sites()
	RuntimeStallAttribution.end(&"region_static_rebuild", started_usec, "draw")


func _draw_static_sites() -> void:
	for site: RegionSiteDefinition in _definition.all_sites():
		if site.coord == null:
			continue
		if site.site_type == &"settlement" and site.footprint.size() > 1:
			continue
		_draw_site_marker(site, _screen_point(site.coord), false)


func _process(_delta: float) -> void:
	pass


func _gui_input(_event: InputEvent) -> void:
	pass


func _hex_radius() -> float:
	return STATIC_RADIUS


func _map_origin() -> Vector2:
	return Vector2.ZERO
