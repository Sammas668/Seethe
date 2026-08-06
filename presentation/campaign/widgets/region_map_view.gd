class_name RegionMapView
extends Control

signal site_selected(site_id: StringName)
signal selection_cleared
signal agent_destination_confirmed(destination: RegionHexCoord)
signal agent_preview_cancelled
signal squad_waypoint_added(destination: RegionHexCoord)
signal squad_waypoint_removed
signal squad_route_cancelled
signal squad_selected(operation_id: StringName)

const REGION_SITE_ID: StringName = &"site.farm.starter_storehouse"
const STRONGHOLD_SITE_ID: StringName = &"site.fifth_god_ruin"
const SQRT_THREE: float = 1.7320508075688772
const MAP_MARGIN: Vector2 = Vector2(42.0, 28.0)

var _definition: RegionMapDefinition
var _campaign: CampaignState
var _agent_preview_provider: Callable
var _agent_preview_mode: bool = false
var _agent_preview_plan: AgentTravelPlan
var _agent_preview_destination: RegionHexCoord
var _agent_preview_invalid_reason: String = ""
var _agent_selected: bool = false
var _squad_selected: bool = false
var _squad_route_mode: bool = false
var _squad_route_provider: Callable
var _squad_route_mission_id: StringName = &""
var _squad_route_mission_site_id: StringName = &""
var _squad_route_waypoints: Array[RegionHexCoord] = []
var _squad_route_plan: SquadRoutePlan
var _squad_hover_plan: SquadRoutePlan
var _squad_hover_destination: RegionHexCoord
var _new_mission_attention_until_ms: Dictionary = {}
var _redraw_accumulator: float = 0.0
var _visual_campaign_tick: float = 0.0
var _strategic_speed: int = StrategicClockService.SPEED_PAUSED
var _agent_walk_phase: float = 0.0
var _camera_target_pan: Vector2 = Vector2.ZERO
var _camera_focus_active: bool = false
var _pending_focus_point: Vector2 = Vector2.INF
var _pending_focus_target: Vector2 = Vector2.INF
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_origin: Vector2 = Vector2.ZERO
var _pan_origin: Vector2 = Vector2.ZERO
var _hovered_site_id: StringName = &""
var _selected_site_id: StringName = &""
var _layer_visibility: Dictionary = {
	"terrain": true,
	"terrain_symbols": true,
	"hex_outlines": true,
	"roads": true,
	"borders": true,
	"settlement_footprints": true,
	"sites": true,
	"labels": true,
}
var _background_layer: ColorRect
var _static_layer: Control
var _cached_hexes: Array[RegionHexDefinition] = []
var _cached_sites: Array[RegionSiteDefinition] = []
var _hex_by_key: Dictionary = {}
var _site_ids_by_hex_key: Dictionary = {}
var _coverage_by_centre_key: Dictionary = {}


func _ready() -> void:
	# Keep cached map children above the CampaignShell background while still
	# allowing this control's dynamic overlay to render over them. The previous
	# large negative child z-indices placed the static map behind an ancestor
	# ColorRect, leaving only the dynamic overlay visible.
	z_index = 3
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_background_layer = ColorRect.new()
	_background_layer.color = Color("111619")
	_background_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background_layer.z_index = -2
	_background_layer.show_behind_parent = true
	add_child(_background_layer)
	var static_layer_script: Script = load(
		"res://presentation/campaign/widgets/region_map_static_layer.gd"
	) as Script
	if static_layer_script != null:
		_static_layer = static_layer_script.new() as Control
		_static_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_static_layer.z_index = -1
		_static_layer.show_behind_parent = true
		add_child(_static_layer)
		if _definition != null and _static_layer.has_method("configure_static"):
			_static_layer.call("configure_static", _definition, _layer_visibility)
	set_process(true)
	_sync_static_layer_transform()
	queue_redraw()


func configure(
	definition: RegionMapDefinition,
	campaign: CampaignState = null,
	agent_preview_provider: Callable = Callable()
) -> void:
	_definition = definition
	_campaign = campaign
	_agent_preview_provider = agent_preview_provider
	_zoom = 1.0
	_pan = Vector2.ZERO
	_hovered_site_id = &""
	_selected_site_id = &""
	_agent_preview_mode = false
	_agent_preview_plan = null
	_agent_preview_destination = null
	_agent_preview_invalid_reason = ""
	_agent_selected = false
	_squad_selected = false
	_squad_route_mode = false
	_squad_route_provider = Callable()
	_squad_route_mission_id = &""
	_squad_route_mission_site_id = &""
	_squad_route_waypoints.clear()
	_squad_route_plan = null
	_squad_hover_plan = null
	_squad_hover_destination = null
	_new_mission_attention_until_ms.clear()
	_visual_campaign_tick = float(_campaign.campaign_tick) if _campaign != null else 0.0
	_agent_walk_phase = 0.0
	_camera_focus_active = false
	_pending_focus_point = Vector2.INF
	_pending_focus_target = Vector2.INF
	_rebuild_runtime_caches()
	if _static_layer != null and _static_layer.has_method("configure_static"):
		_static_layer.call("configure_static", _definition, _layer_visibility)
	_sync_static_layer_transform()
	queue_redraw()


func update_campaign(campaign: CampaignState) -> void:
	var previous_tick: int = _campaign.campaign_tick if _campaign != null else -1
	_campaign = campaign
	if _campaign == null:
		_visual_campaign_tick = 0.0
	else:
		var authoritative_tick := float(_campaign.campaign_tick)
		# Presentation may run fractionally ahead of the last committed whole
		# campaign minute. Never snap it backwards during an ordinary clock commit,
		# but do resynchronise after loading, rewinding or a large discontinuity.
		if previous_tick < 0 or _campaign.campaign_tick < previous_tick:
			_visual_campaign_tick = authoritative_tick
		elif absf(_visual_campaign_tick - authoritative_tick) > 30.0:
			_visual_campaign_tick = authoritative_tick
		else:
			_visual_campaign_tick = maxf(_visual_campaign_tick, authoritative_tick)
	# Campaign changes affect only missions and the Agent overlay. The authored
	# terrain, roads, borders, permanent sites and labels remain cached.
	queue_redraw()


func set_strategic_speed(speed: int) -> void:
	_strategic_speed = speed if speed in [
		StrategicClockService.SPEED_PAUSED,
		StrategicClockService.SPEED_NORMAL,
		StrategicClockService.SPEED_FAST,
		StrategicClockService.SPEED_VERY_FAST,
	] else StrategicClockService.SPEED_PAUSED


func set_agent_preview_mode(active: bool) -> void:
	_agent_preview_mode = active
	_agent_selected = active
	if not active:
		_agent_preview_plan = null
		_agent_preview_destination = null
		_agent_preview_invalid_reason = ""
	elif is_inside_tree():
		_update_agent_preview(get_local_mouse_position())
	queue_redraw()


func is_agent_preview_mode() -> bool:
	return _agent_preview_mode


func set_squad_route_mode(
	active: bool,
	mission_instance_id: StringName = &"",
	mission_site_id: StringName = &"",
	waypoints: Array[RegionHexCoord] = [],
	route_plan: SquadRoutePlan = null,
	provider: Callable = Callable()
) -> void:
	_squad_route_mode = active
	if active:
		set_agent_preview_mode(false)
		_squad_route_mission_id = mission_instance_id
		_squad_route_mission_site_id = mission_site_id
		_squad_route_provider = provider
		_squad_route_waypoints.clear()
		for waypoint: RegionHexCoord in waypoints:
			if waypoint != null:
				_squad_route_waypoints.append(waypoint.duplicate_coord())
		_squad_route_plan = route_plan
		_squad_hover_plan = null
		_squad_hover_destination = null
	else:
		_squad_route_provider = Callable()
		_squad_route_mission_id = &""
		_squad_route_mission_site_id = &""
		_squad_route_waypoints.clear()
		_squad_route_plan = null
		_squad_hover_plan = null
		_squad_hover_destination = null
	queue_redraw()


func is_squad_route_mode() -> bool:
	return _squad_route_mode


func update_squad_route(
	waypoints: Array[RegionHexCoord],
	route_plan: SquadRoutePlan
) -> void:
	_squad_route_waypoints.clear()
	for waypoint: RegionHexCoord in waypoints:
		if waypoint != null:
			_squad_route_waypoints.append(waypoint.duplicate_coord())
	_squad_route_plan = route_plan
	_squad_hover_plan = null
	_squad_hover_destination = null
	queue_redraw()


func focus_squad() -> void:
	var position: Vector2 = _squad_map_position()
	if position != Vector2.INF:
		_focus_map_unit(position, size * 0.5)


func clear_squad_selection() -> void:
	_squad_selected = false
	queue_redraw()


func focus_agent() -> void:
	var position: Vector2 = _agent_map_position()
	if position == Vector2.INF:
		return
	_focus_map_unit(position, size * 0.5)
	_agent_selected = true
	queue_redraw()


func focus_site(site_id: StringName, reserve_right_panel: bool = false) -> void:
	if _definition == null:
		return
	var site: RegionSiteDefinition = _definition.site(site_id)
	if site == null or site.coord == null:
		return
	var target: Vector2 = size * 0.5
	if reserve_right_panel:
		target.x = size.x * 0.38
	_focus_map_unit(RegionBoundaryPathfinder.map_center(site.coord), target)
	_selected_site_id = site.id
	queue_redraw()


func mark_mission_new(mission_instance_id: StringName) -> void:
	if mission_instance_id.is_empty():
		return
	_new_mission_attention_until_ms[mission_instance_id] = Time.get_ticks_msec() + 3200
	queue_redraw()


func acknowledge_mission_at_site(site_id: StringName) -> void:
	if _campaign == null or site_id.is_empty():
		return
	for mission: ActiveMissionState in _campaign.get_active_missions():
		if mission.site_id == site_id:
			_new_mission_attention_until_ms.erase(mission.mission_instance_id)
	queue_redraw()


func agent_preview_invalid_reason() -> String:
	return _agent_preview_invalid_reason


func _draw() -> void:
	var started_usec: int = RuntimeStallAttribution.begin()
	if _definition == null:
		_draw_missing_region_message()
		RuntimeStallAttribution.end(&"region_dynamic_draw", started_usec, "missing_region")
		return
	if _static_layer == null:
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
			_draw_sites()
	_draw_site_interaction_highlights()
	_draw_agent_destination_preview()
	_draw_agent_coverage()
	_draw_agent_route()
	_draw_squad_route()
	if bool(_layer_visibility.get("labels", true)):
		_draw_site_labels_dynamic()
	_draw_mission_markers()
	_draw_raid_markers()
	_draw_agent_token()
	_draw_squad_token()
	_draw_agent_debug_overlay()
	_draw_region_performance_overlay()
	RuntimeStallAttribution.end(&"region_dynamic_draw", started_usec, "overlay")


func set_layer_visible(layer_id: StringName, visible: bool) -> void:
	_layer_visibility[String(layer_id)] = visible
	if _static_layer != null and _static_layer.has_method("set_static_layer_visible"):
		_static_layer.call("set_static_layer_visible", layer_id, visible)
	queue_redraw()


func is_layer_visible(layer_id: StringName) -> bool:
	return bool(_layer_visibility.get(String(layer_id), false))


func view_zoom() -> float:
	return _zoom


func view_pan() -> Vector2:
	return _pan


func set_view_transform(zoom_value: float, pan_value: Vector2) -> void:
	_zoom = clampf(zoom_value, 0.42, 3.5)
	_pan = pan_value
	_sync_static_layer_transform()
	queue_redraw()


func fit_region() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_sync_static_layer_transform()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_static_layer_transform()


func _rebuild_runtime_caches() -> void:
	_cached_hexes.clear()
	_cached_sites.clear()
	_hex_by_key.clear()
	_site_ids_by_hex_key.clear()
	_coverage_by_centre_key.clear()
	if _definition == null:
		return
	_cached_hexes = _definition.all_hexes()
	_cached_sites = _definition.all_sites()
	for hex: RegionHexDefinition in _cached_hexes:
		if hex.coord != null:
			_hex_by_key[hex.coord.key()] = hex
	for site: RegionSiteDefinition in _cached_sites:
		if site.coord != null:
			_index_site_at_hex(site.id, site.coord)
		for coord: RegionHexCoord in site.footprint:
			_index_site_at_hex(site.id, coord)


func _index_site_at_hex(site_id: StringName, coord: RegionHexCoord) -> void:
	if coord == null or site_id.is_empty():
		return
	var key: StringName = coord.key()
	if not _site_ids_by_hex_key.has(key):
		_site_ids_by_hex_key[key] = []
	var ids: Array = _site_ids_by_hex_key[key] as Array
	if not ids.has(site_id):
		ids.append(site_id)


func _sync_static_layer_transform() -> void:
	if _static_layer == null or _definition == null or size.x <= 1.0 or size.y <= 1.0:
		return
	var scale_factor: float = _hex_radius() / 32.0
	_static_layer.visible = true
	_static_layer.position = _map_origin()
	_static_layer.scale = Vector2(scale_factor, scale_factor)
	if _static_layer.has_method("set_terrain_symbol_detail_visible"):
		_static_layer.call("set_terrain_symbol_detail_visible", _zoom >= 0.62)


func _draw_site_interaction_highlights() -> void:
	if not bool(_layer_visibility.get("sites", true)):
		return
	var highlighted_ids: Array[StringName] = []
	if not _hovered_site_id.is_empty():
		highlighted_ids.append(_hovered_site_id)
	if not _selected_site_id.is_empty() and not highlighted_ids.has(_selected_site_id):
		highlighted_ids.append(_selected_site_id)
	for site_id: StringName in highlighted_ids:
		var site: RegionSiteDefinition = _definition.site(site_id)
		if site == null or site.coord == null:
			continue
		if site.site_type == &"settlement" and site.footprint.size() > 1:
			for coord: RegionHexCoord in site.footprint:
				var polygon: PackedVector2Array = _hex_polygon(
					_screen_point(coord),
					_hex_radius() * 0.82
				)
				polygon.append(polygon[0])
				draw_polyline(
					polygon,
					Color(0.93, 0.82, 0.36, 0.88),
					maxf(2.0, _hex_radius() * 0.075),
					true
				)
		else:
			draw_arc(
				_screen_point(site.coord),
				_site_hit_radius(site) + _hex_radius() * 0.10,
				0.0,
				TAU,
				30,
				Color(0.93, 0.82, 0.36, 0.88),
				maxf(2.0, _hex_radius() * 0.075),
				true
			)


func _draw_site_labels_dynamic() -> void:
	for site: RegionSiteDefinition in _cached_sites:
		if site.coord == null or not _should_draw_label(site):
			continue
		_draw_site_label(site, _screen_point(site.coord))


func _draw_region_performance_overlay() -> void:
	if not bool(ProjectSettings.get_setting("seethe/development/show_region_performance", false)):
		return
	var lines: Array[String] = RuntimeStallAttribution.diagnostic_lines()
	var width: float = 330.0
	var height: float = 24.0 + float(lines.size()) * 17.0
	var origin := Vector2(12.0, size.y - height - 12.0)
	draw_rect(Rect2(origin, Vector2(width, height)), Color(0.02, 0.03, 0.04, 0.88), true)
	var font: Font = ThemeDB.fallback_font
	for index: int in range(lines.size()):
		draw_string(
			font,
			origin + Vector2(10.0, 21.0 + float(index) * 17.0),
			lines[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12.0,
			Color("c8e0e8")
		)


func _draw_hex_fills() -> void:
	for hex: RegionHexDefinition in _definition.all_hexes():
		if not hex.playable:
			continue
		var centre: Vector2 = _screen_point(hex.coord)
		var polygon: PackedVector2Array = _hex_polygon(centre, _hex_radius())
		var base_color: Color = _terrain_color(hex.terrain_type)
		var variant_shift: float = (float((hex.visual_variant % 5) - 2)) * 0.012
		base_color = base_color.lightened(maxf(variant_shift, 0.0)) if variant_shift >= 0.0 else base_color.darkened(-variant_shift)
		draw_colored_polygon(polygon, base_color)


func _draw_terrain_symbols() -> void:
	if _zoom < 0.62:
		return
	var radius: float = _hex_radius()
	for hex: RegionHexDefinition in _definition.all_hexes():
		if not hex.playable:
			continue
		_draw_terrain_symbol(hex, _screen_point(hex.coord), radius)


func _draw_hex_borders() -> void:
	var radius: float = _hex_radius()
	for hex: RegionHexDefinition in _definition.all_hexes():
		if not hex.playable:
			continue
		var polygon: PackedVector2Array = _hex_polygon(_screen_point(hex.coord), radius)
		polygon.append(polygon[0])
		draw_polyline(
			polygon,
			Color(0.86, 0.88, 0.83, 0.82),
			maxf(1.0, radius * 0.042),
			true
		)


func _draw_settlement_footprint_pads() -> void:
	var radius: float = _hex_radius()
	for site: RegionSiteDefinition in _definition.all_sites():
		if site.site_type != &"settlement" or site.footprint.size() <= 1:
			continue
		var highlighted: bool = site.id in [_hovered_site_id, _selected_site_id]
		for coord: RegionHexCoord in site.footprint:
			var centre: Vector2 = _screen_point(coord)
			var pad: PackedVector2Array = _hex_polygon(centre, radius * 0.78)
			draw_colored_polygon(
				pad,
				Color(0.33, 0.34, 0.31, 0.86) if not highlighted else Color(0.48, 0.43, 0.27, 0.90)
			)
			pad.append(pad[0])
			draw_polyline(pad, Color(0.18, 0.18, 0.16, 0.82), maxf(1.0, radius * 0.035), true)


func _draw_road_edges() -> void:
	var paths_by_style: Dictionary = _build_edge_paths(_definition.all_road_edges(), false)
	# Render roads by material pass rather than completing one path at a time.
	# Otherwise the dark underlay of a later path can cut across the already-drawn
	# surface of another path where different road classes meet at an endpoint.
	# Drawing every underlay first, then every surface, then final highlights keeps
	# shared endpoints and junctions continuous without exposing clipped caps.
	for pass_id: StringName in [&"underlay", &"surface", &"detail"]:
		_draw_road_pass(paths_by_style, pass_id)


func _draw_road_pass(paths_by_style: Dictionary, pass_id: StringName) -> void:
	# Lesser roads are drawn first within each pass so a primary road remains the
	# visually dominant continuous route where different classes meet.
	for road_type: StringName in [RegionRoadType.FOREST_TRACK, RegionRoadType.LOCAL_ROAD, RegionRoadType.PRIMARY_ROAD]:
		var raw_paths: Array = paths_by_style.get(road_type, []) as Array
		for raw_path: Variant in raw_paths:
			var path: PackedVector2Array = raw_path
			_draw_road_path_pass(path, road_type, pass_id)


func _draw_subregion_borders() -> void:
	var paths_by_style: Dictionary = _build_edge_paths(_definition.all_border_edges(), true)
	var raw_paths: Array = paths_by_style.get(&"subregion_border", []) as Array
	for raw_path: Variant in raw_paths:
		var path: PackedVector2Array = raw_path
		_draw_round_path(path, Color("3b161a"), _border_outer_width())
		_draw_round_path(path, Color("c82836"), _border_inner_width())


func _draw_road_path(path: PackedVector2Array, road_type: StringName) -> void:
	# Standalone path rendering is retained for authoring hover previews. Runtime
	# roads use _draw_road_edges(), which batches these passes across all paths.
	for pass_id: StringName in [&"underlay", &"surface", &"detail"]:
		_draw_road_path_pass(path, road_type, pass_id)


func _draw_road_path_pass(path: PackedVector2Array, road_type: StringName, pass_id: StringName) -> void:
	if path.size() < 2:
		return
	match RegionRoadType.normalize(road_type):
		RegionRoadType.PRIMARY_ROAD:
			match pass_id:
				&"underlay":
					_draw_round_path(path, Color("292219"), _primary_road_outer_width())
				&"surface":
					_draw_round_path(path, Color("d8c18a"), _primary_road_surface_width())
				&"detail":
					_draw_round_path(path, Color("f2e2b7"), _primary_road_highlight_width())
		RegionRoadType.FOREST_TRACK:
			if pass_id == &"detail":
				return
			var separation: float = maxf(2.4, _hex_radius() * 0.070)
			var first_rut: PackedVector2Array = _offset_polyline(path, -separation)
			var second_rut: PackedVector2Array = _offset_polyline(path, separation)
			if pass_id == &"underlay":
				var outer_width: float = maxf(3.2, _hex_radius() * 0.090)
				_draw_round_path(first_rut, Color("2b251d"), outer_width)
				_draw_round_path(second_rut, Color("2b251d"), outer_width)
			elif pass_id == &"surface":
				var inner_width: float = maxf(1.5, _hex_radius() * 0.042)
				_draw_round_path(first_rut, Color("795534"), inner_width)
				_draw_round_path(second_rut, Color("795534"), inner_width)
		_:
			if pass_id == &"underlay":
				_draw_round_path(path, Color("3a291b"), _local_road_outer_width())
			elif pass_id == &"surface":
				_draw_round_path(path, Color("b87940"), _local_road_surface_width())


func _draw_round_path(path: PackedVector2Array, color: Color, width: float) -> void:
	if path.size() < 2 or width <= 0.0:
		return
	draw_polyline(path, color, width, true)
	var radius: float = width * 0.5
	for point: Vector2 in path:
		draw_circle(point, radius, color)


func _build_edge_paths(
	edges: Array[RegionMapEdgeDefinition],
	offset_shared_borders: bool
) -> Dictionary:
	var segments: Array[Dictionary] = []
	var point_accumulators: Dictionary = {}
	var road_type_by_edge: Dictionary = _road_type_by_canonical_key()
	for edge: RegionMapEdgeDefinition in edges:
		var base_segment: PackedVector2Array = _edge_segment(edge)
		if base_segment.size() != 2:
			continue
		var style: StringName = &"subregion_border" if edge.edge_type == RegionMapEdgeDefinition.BORDER else RegionRoadType.normalize(edge.style_id)
		var first_key: StringName = StringName("%s@%s" % [style, _point_key(base_segment[0])])
		var second_key: StringName = StringName("%s@%s" % [style, _point_key(base_segment[1])])
		var display_segment: PackedVector2Array = base_segment.duplicate()
		if offset_shared_borders and road_type_by_edge.has(edge.canonical_key()):
			var road_type: StringName = StringName(road_type_by_edge[edge.canonical_key()])
			var shift: Vector2 = _shared_border_shift(edge, road_type, base_segment)
			display_segment[0] += shift
			display_segment[1] += shift
		_accumulate_path_point(point_accumulators, first_key, display_segment[0])
		_accumulate_path_point(point_accumulators, second_key, display_segment[1])
		segments.append({
			"style": style,
			"first": first_key,
			"second": second_key,
		})
	var points: Dictionary = {}
	for raw_key: Variant in point_accumulators.keys():
		var key := StringName(raw_key)
		var accumulator: Dictionary = point_accumulators[key] as Dictionary
		var total: Vector2 = accumulator.get("total", Vector2.ZERO)
		var count: int = maxi(1, int(accumulator.get("count", 1)))
		points[key] = total / float(count)
	return _trace_edge_paths(segments, points)


func _trace_edge_paths(segments: Array[Dictionary], points: Dictionary) -> Dictionary:
	var adjacency: Dictionary = {}
	for index: int in range(segments.size()):
		var segment: Dictionary = segments[index]
		var first := StringName(segment.get("first", ""))
		var second := StringName(segment.get("second", ""))
		if not adjacency.has(first):
			adjacency[first] = []
		if not adjacency.has(second):
			adjacency[second] = []
		(adjacency[first] as Array).append(index)
		(adjacency[second] as Array).append(index)
	var used: Dictionary = {}
	var result: Dictionary = {}
	var starts: Array = adjacency.keys()
	starts.sort()
	for raw_start: Variant in starts:
		var start := StringName(raw_start)
		var touching: Array = adjacency[start] as Array
		if touching.size() == 2:
			continue
		for raw_index: Variant in touching:
			var index: int = int(raw_index)
			if used.has(index):
				continue
			_append_traced_path(result, _walk_edge_path(start, index, segments, adjacency, points, used), segments[index])
	for index: int in range(segments.size()):
		if used.has(index):
			continue
		var start := StringName(segments[index].get("first", ""))
		_append_traced_path(result, _walk_edge_path(start, index, segments, adjacency, points, used), segments[index])
	return result


func _walk_edge_path(
	start: StringName,
	first_segment_index: int,
	segments: Array[Dictionary],
	adjacency: Dictionary,
	points: Dictionary,
	used: Dictionary
) -> PackedVector2Array:
	var path := PackedVector2Array()
	if not points.has(start):
		return path
	path.append(points[start])
	var current: StringName = start
	var segment_index: int = first_segment_index
	while segment_index >= 0 and not used.has(segment_index):
		used[segment_index] = true
		var segment: Dictionary = segments[segment_index]
		var first := StringName(segment.get("first", ""))
		var second := StringName(segment.get("second", ""))
		var next: StringName = second if current == first else first
		if not points.has(next):
			break
		path.append(points[next])
		var touching: Array = adjacency.get(next, []) as Array
		if touching.size() != 2:
			break
		var next_segment_index: int = -1
		for raw_candidate: Variant in touching:
			var candidate: int = int(raw_candidate)
			if not used.has(candidate):
				next_segment_index = candidate
				break
		if next_segment_index < 0:
			break
		current = next
		segment_index = next_segment_index
	return path


func _append_traced_path(result: Dictionary, path: PackedVector2Array, segment: Dictionary) -> void:
	if path.size() < 2:
		return
	var style := StringName(segment.get("style", RegionRoadType.LOCAL_ROAD))
	if not result.has(style):
		result[style] = []
	(result[style] as Array).append(path)


func _accumulate_path_point(accumulators: Dictionary, key: StringName, point: Vector2) -> void:
	var entry: Dictionary = accumulators.get(key, {"total": Vector2.ZERO, "count": 0}) as Dictionary
	var total: Vector2 = entry.get("total", Vector2.ZERO)
	entry["total"] = total + point
	entry["count"] = int(entry.get("count", 0)) + 1
	accumulators[key] = entry


func _road_type_by_canonical_key() -> Dictionary:
	var result: Dictionary = {}
	if _definition == null:
		return result
	for edge: RegionMapEdgeDefinition in _definition.all_road_edges():
		result[edge.canonical_key()] = RegionRoadType.normalize(edge.style_id)
	return result


func _shared_border_shift(
	edge: RegionMapEdgeDefinition,
	road_type: StringName,
	segment: PackedVector2Array
) -> Vector2:
	if edge.coord == null or edge.neighbour_coord == null or segment.size() != 2:
		return Vector2.ZERO
	var first_hex: RegionHexDefinition = _definition.hex_at_offset(edge.coord.offset_col, edge.coord.offset_row)
	var second_hex: RegionHexDefinition = _definition.hex_at_offset(edge.neighbour_coord.offset_col, edge.neighbour_coord.offset_row)
	var target_coord: RegionHexCoord = edge.coord
	if first_hex != null and second_hex != null and String(second_hex.subregion_id) < String(first_hex.subregion_id):
		target_coord = edge.neighbour_coord
	var midpoint: Vector2 = (segment[0] + segment[1]) * 0.5
	var direction: Vector2 = (_screen_point(target_coord) - midpoint).normalized()
	if direction.length_squared() < 0.0001:
		var edge_direction: Vector2 = (segment[1] - segment[0]).normalized()
		direction = Vector2(-edge_direction.y, edge_direction.x)
	return direction * (_road_outer_width(road_type) * 0.58 + _border_inner_width() * 0.80)


func _offset_polyline(path: PackedVector2Array, distance: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if path.size() < 2:
		return result
	for index: int in range(path.size()):
		var previous_direction: Vector2
		var next_direction: Vector2
		if index > 0:
			previous_direction = (path[index] - path[index - 1]).normalized()
		else:
			previous_direction = (path[1] - path[0]).normalized()
		if index < path.size() - 1:
			next_direction = (path[index + 1] - path[index]).normalized()
		else:
			next_direction = previous_direction
		var previous_normal := Vector2(-previous_direction.y, previous_direction.x)
		var next_normal := Vector2(-next_direction.y, next_direction.x)
		var normal: Vector2 = (previous_normal + next_normal).normalized()
		if normal.length_squared() < 0.0001:
			normal = next_normal
		result.append(path[index] + normal * distance)
	return result


func _point_key(point: Vector2) -> String:
	return "%d,%d" % [roundi(point.x * 1000.0), roundi(point.y * 1000.0)]


func _road_outer_width(road_type: StringName) -> float:
	match RegionRoadType.normalize(road_type):
		RegionRoadType.PRIMARY_ROAD:
			return _primary_road_outer_width()
		RegionRoadType.FOREST_TRACK:
			return maxf(7.0, _hex_radius() * 0.23)
		_:
			return _local_road_outer_width()


func _primary_road_outer_width() -> float:
	return maxf(9.0, _hex_radius() * 0.30)


func _primary_road_surface_width() -> float:
	return maxf(6.0, _hex_radius() * 0.205)


func _primary_road_highlight_width() -> float:
	return maxf(1.2, _hex_radius() * 0.035)


func _local_road_outer_width() -> float:
	return maxf(6.0, _hex_radius() * 0.205)


func _local_road_surface_width() -> float:
	return maxf(3.8, _hex_radius() * 0.135)


func _border_outer_width() -> float:
	return maxf(4.2, _hex_radius() * 0.130)


func _border_inner_width() -> float:
	return maxf(2.2, _hex_radius() * 0.068)


func _edge_segment(edge: RegionMapEdgeDefinition) -> PackedVector2Array:
	var result := PackedVector2Array()
	if edge == null or edge.coord == null or edge.edge_index < 0 or edge.edge_index > 5:
		return result
	var polygon: PackedVector2Array = _hex_polygon(_screen_point(edge.coord), _hex_radius())
	result.append(polygon[edge.edge_index])
	result.append(polygon[(edge.edge_index + 1) % 6])
	return result


func _draw_terrain_symbol(hex: RegionHexDefinition, centre: Vector2, radius: float) -> void:
	var ink := Color(0.12, 0.17, 0.16, 0.72)
	var variant: int = hex.visual_variant % 4
	match hex.terrain_type:
		RegionTerrainType.GRASSLAND:
			_draw_grassland_symbol(centre, radius, ink, variant)
		RegionTerrainType.FARMLAND:
			_draw_farmland_symbol(centre, radius, ink, variant)
		RegionTerrainType.LAKE:
			_draw_lake_symbol(centre, radius)
		RegionTerrainType.MARSH:
			_draw_marsh_symbol(centre, radius, ink, variant)
		RegionTerrainType.FOREST:
			_draw_forest_symbol(centre, radius, false, variant)
		RegionTerrainType.DEEP_FOREST:
			_draw_forest_symbol(centre, radius, true, variant)


func _draw_grassland_symbol(centre: Vector2, radius: float, ink: Color, variant: int) -> void:
	var shift: float = float(variant - 1) * radius * 0.025
	for index: int in range(-1, 2):
		var base := centre + Vector2(float(index) * radius * 0.16 + shift, radius * 0.24)
		draw_line(base, base + Vector2(-radius * 0.045, -radius * (0.24 + 0.03 * abs(index))), ink, maxf(1.0, radius * 0.035), true)
		draw_line(base, base + Vector2(radius * 0.055, -radius * (0.18 + 0.03 * abs(index))), ink, maxf(1.0, radius * 0.035), true)
	var flower := Color(0.93, 0.88, 0.53, 0.78)
	draw_circle(centre + Vector2(-radius * 0.26, -radius * 0.08), maxf(1.0, radius * 0.035), flower)
	draw_circle(centre + Vector2(radius * 0.24, radius * 0.02), maxf(1.0, radius * 0.028), flower)


func _draw_farmland_symbol(centre: Vector2, radius: float, ink: Color, variant: int) -> void:
	var row_color := Color(0.28, 0.27, 0.14, 0.72)
	for row: int in range(-2, 3):
		var x: float = centre.x + float(row) * radius * 0.13
		draw_line(
			Vector2(x - radius * 0.035, centre.y + radius * 0.30),
			Vector2(x + radius * 0.05, centre.y - radius * 0.27),
			row_color,
			maxf(1.0, radius * 0.035),
			true
		)
		for stalk: int in range(3):
			var y: float = centre.y + radius * (0.18 - float(stalk) * 0.18)
			draw_line(Vector2(x, y), Vector2(x - radius * 0.06, y - radius * 0.06), ink, maxf(1.0, radius * 0.026), true)
			draw_line(Vector2(x, y), Vector2(x + radius * 0.06, y - radius * 0.055), ink, maxf(1.0, radius * 0.026), true)


func _draw_lake_symbol(centre: Vector2, radius: float) -> void:
	var water_ink := Color(0.18, 0.43, 0.62, 0.54)
	for row: int in range(-1, 2):
		var y: float = centre.y + float(row) * radius * 0.17
		draw_arc(centre + Vector2(-radius * 0.17, y - centre.y), radius * 0.18, 0.10, PI - 0.10, 12, water_ink, maxf(1.0, radius * 0.038), true)
		draw_arc(centre + Vector2(radius * 0.19, y - centre.y), radius * 0.18, PI + 0.10, TAU - 0.10, 12, water_ink, maxf(1.0, radius * 0.038), true)


func _draw_marsh_symbol(centre: Vector2, radius: float, ink: Color, variant: int) -> void:
	var pool := Color(0.20, 0.47, 0.55, 0.48)
	draw_arc(centre + Vector2(0, radius * 0.17), radius * 0.29, 0.12, PI - 0.12, 18, pool, maxf(1.0, radius * 0.045), true)
	for index: int in range(-2, 3):
		var x: float = centre.x + float(index) * radius * 0.13
		var base_y: float = centre.y + radius * 0.23
		draw_line(Vector2(x, base_y), Vector2(x + float(index % 2) * radius * 0.03, centre.y - radius * (0.11 + 0.025 * abs(index))), ink, maxf(1.0, radius * 0.035), true)
		if index % 2 == 0:
			draw_line(Vector2(x, centre.y - radius * 0.03), Vector2(x + radius * 0.07, centre.y - radius * 0.10), ink, maxf(1.0, radius * 0.025), true)


func _draw_forest_symbol(centre: Vector2, radius: float, deep: bool, variant: int) -> void:
	var canopy := Color("175a38") if not deep else Color("0d442b")
	var trunk := Color("5b4227") if not deep else Color("352c21")
	var positions: Array[Vector2] = [
		Vector2(-0.22, 0.09),
		Vector2(0.18, 0.10),
		Vector2(0.00, -0.12),
	]
	if deep:
		positions.append(Vector2(-0.18, -0.18))
		positions.append(Vector2(0.22, -0.16))
	for index: int in range(positions.size()):
		var pos: Vector2 = centre + positions[index] * radius
		var crown_radius: float = radius * (0.13 if deep else 0.15)
		draw_line(pos + Vector2(0, crown_radius * 0.45), pos + Vector2(0, radius * 0.27), trunk, maxf(1.0, radius * 0.045), true)
		draw_circle(pos, crown_radius, canopy)
		draw_circle(pos + Vector2(-crown_radius * 0.55, crown_radius * 0.22), crown_radius * 0.70, canopy)
		draw_circle(pos + Vector2(crown_radius * 0.55, crown_radius * 0.22), crown_radius * 0.70, canopy)


func _draw_sites() -> void:
	for site: RegionSiteDefinition in _definition.all_sites():
		if site.coord == null:
			continue
		var highlighted: bool = site.id in [_hovered_site_id, _selected_site_id]
		if site.site_type == &"settlement" and site.footprint.size() > 1:
			if bool(_layer_visibility.get("labels", true)) and _should_draw_label(site):
				_draw_site_label(site, _screen_point(site.coord))
			continue
		var centre: Vector2 = _screen_point(site.coord)
		_draw_site_marker(site, centre, highlighted)
		if bool(_layer_visibility.get("labels", true)) and _should_draw_label(site):
			_draw_site_label(site, centre)


func _draw_site_marker(site: RegionSiteDefinition, centre: Vector2, highlighted: bool) -> void:
	var radius: float = _hex_radius()
	if highlighted:
		draw_circle(centre, _site_hit_radius(site) + radius * 0.10, Color(0.93, 0.82, 0.36, 0.78))
	match site.site_type:
		&"settlement":
			_draw_settlement_building(centre, radius * 0.43, site.icon_id)
		&"district":
			_draw_settlement_building(centre, radius * 0.50, site.icon_id)
		&"stronghold":
			_draw_stronghold_marker(centre, radius * 0.42)
		&"ruin":
			_draw_ruin_marker(centre, radius * 0.40)
		&"farm":
			_draw_farm_marker(centre, radius * 0.34)
		&"religious":
			_draw_religious_marker(centre, radius * 0.34)
		&"military":
			_draw_military_marker(centre, radius * 0.34)
		_:
			draw_circle(centre, radius * 0.18, Color("181817"))
			draw_circle(centre, radius * 0.14, Color("9a8d74"))


func _draw_settlement_building(centre: Vector2, radius: float, icon_id: StringName) -> void:
	var outline := Color("171716")
	var wall := Color("e2d4aa")
	var roof := Color("24764b")
	var door := Color("6f4932")
	var warehouse: bool = icon_id in [
		RegionSymbolCatalogue.WHEAT_WAREHOUSE,
		RegionSymbolCatalogue.TEXTILES_WAREHOUSE,
		&"district_warehouse",
		&"farm_storehouse",
	]
	if icon_id == RegionSymbolCatalogue.WHEAT_WAREHOUSE:
		roof = Color("e8d07a")
		wall = Color("d9794d")
	elif icon_id == RegionSymbolCatalogue.LUMBERMILL:
		roof = Color("6f4a2a")
		wall = Color("c69a63")
	elif icon_id == RegionSymbolCatalogue.TEXTILES_WAREHOUSE:
		roof = Color("397d5c")
		wall = Color("d7cdb7")
	elif icon_id == RegionSymbolCatalogue.CRAFTSMANS_DISTRICT:
		roof = Color("2c7250")
		wall = Color("b98358")
	elif icon_id == RegionSymbolCatalogue.GUILD_HOUSE:
		roof = Color("386d55")
		wall = Color("d0c19d")
	elif icon_id == RegionSymbolCatalogue.NOBLE_HOUSING:
		roof = Color("2d8252")
		wall = Color("eadcb7")
	elif icon_id in [RegionSymbolCatalogue.HAMLET, &"settlement_hamlet"]:
		radius *= 0.82
	elif icon_id in [RegionSymbolCatalogue.VILLAGE_CENTRE, &"settlement_village"]:
		radius *= 0.92
	elif icon_id in [RegionSymbolCatalogue.TOWN_CENTRE, &"settlement_large"]:
		roof = Color("27814e")
		wall = Color("eadcb7")
	var footprint := Rect2(centre + Vector2(-radius * 0.56, -radius * 0.02), Vector2(radius * 1.12, radius * 0.72))
	draw_rect(footprint.grow(radius * 0.08), outline, true)
	draw_rect(footprint, wall, true)
	var roof_shape := PackedVector2Array([
		centre + Vector2(-radius * 0.72, -radius * 0.02),
		centre + Vector2(0, -radius * 0.72),
		centre + Vector2(radius * 0.72, -radius * 0.02),
	])
	draw_colored_polygon(roof_shape, outline)
	var inner_roof := PackedVector2Array([
		centre + Vector2(-radius * 0.62, -radius * 0.01),
		centre + Vector2(0, -radius * 0.60),
		centre + Vector2(radius * 0.62, -radius * 0.01),
	])
	draw_colored_polygon(inner_roof, roof)
	draw_rect(Rect2(centre + Vector2(-radius * 0.11, radius * 0.24), Vector2(radius * 0.22, radius * 0.36)), door, true)
	if warehouse:
		for index: int in range(-1, 2):
			draw_line(
				centre + Vector2(float(index) * radius * 0.20, radius * 0.02),
				centre + Vector2(float(index) * radius * 0.20, radius * 0.20),
				Color("8a5535"),
				maxf(1.0, radius * 0.055),
				true
			)
	elif icon_id == RegionSymbolCatalogue.LUMBERMILL:
		draw_circle(centre + Vector2(radius * 0.43, radius * 0.22), radius * 0.16, Color("81572f"), false, maxf(1.0, radius * 0.07))
		draw_line(centre + Vector2(radius * 0.28, radius * 0.22), centre + Vector2(radius * 0.58, radius * 0.22), Color("81572f"), maxf(1.0, radius * 0.05), true)
	elif icon_id == RegionSymbolCatalogue.CRAFTSMANS_DISTRICT:
		draw_rect(Rect2(centre + Vector2(radius * 0.40, -radius * 0.25), Vector2(radius * 0.25, radius * 0.70)), Color("8b9790"), true)
	elif icon_id == RegionSymbolCatalogue.GUILD_HOUSE:
		draw_circle(centre + Vector2(0, radius * 0.10), radius * 0.11, Color("b79b4e"))
	elif icon_id == RegionSymbolCatalogue.NOBLE_HOUSING:
		draw_line(centre + Vector2(-radius * 0.44, radius * 0.32), centre + Vector2(radius * 0.44, radius * 0.32), Color("b79b4e"), maxf(1.0, radius * 0.05), true)


func _draw_stronghold_marker(centre: Vector2, radius: float) -> void:
	var outline := Color("131313")
	var diamond := PackedVector2Array([
		centre + Vector2(0, -radius),
		centre + Vector2(radius, 0),
		centre + Vector2(0, radius),
		centre + Vector2(-radius, 0),
	])
	draw_colored_polygon(diamond, outline)
	diamond.append(diamond[0])
	draw_polyline(diamond, Color("9b3942"), maxf(2.0, radius * 0.15), true)
	draw_circle(centre, radius * 0.30, Color("c9aa62"))
	draw_line(centre + Vector2(-radius * 0.18, 0), centre + Vector2(radius * 0.18, 0), outline, maxf(1.0, radius * 0.10), true)


func _draw_ruin_marker(centre: Vector2, radius: float) -> void:
	var stone := Color("30312f")
	var shadow := Color("0b0c0b")
	draw_rect(Rect2(centre + Vector2(-radius * 0.48, -radius * 0.45), Vector2(radius * 0.78, radius * 0.94)), shadow, true)
	draw_rect(Rect2(centre + Vector2(-radius * 0.38, -radius * 0.36), Vector2(radius * 0.58, radius * 0.78)), stone, true)
	draw_rect(Rect2(centre + Vector2(-radius * 0.16, radius * 0.02), Vector2(radius * 0.20, radius * 0.40)), shadow, true)
	draw_line(centre + Vector2(-radius * 0.48, -radius * 0.45), centre + Vector2(-radius * 0.12, -radius * 0.70), shadow, maxf(2.0, radius * 0.16), true)
	draw_line(centre + Vector2(-radius * 0.12, -radius * 0.70), centre + Vector2(radius * 0.30, -radius * 0.45), shadow, maxf(2.0, radius * 0.16), true)


func _draw_farm_marker(centre: Vector2, radius: float) -> void:
	draw_circle(centre, radius * 1.10, Color("1a1916"))
	draw_circle(centre, radius, Color("d8b94a"))
	for index: int in range(-1, 2):
		var x: float = centre.x + float(index) * radius * 0.30
		draw_line(Vector2(x, centre.y + radius * 0.52), Vector2(x + radius * 0.08, centre.y - radius * 0.48), Color("4b4426"), maxf(1.0, radius * 0.12), true)


func _draw_religious_marker(centre: Vector2, radius: float) -> void:
	draw_circle(centre, radius * 1.10, Color("171716"))
	draw_circle(centre, radius, Color("e4d5a6"))
	draw_circle(centre, radius * 0.52, Color("5f8a55"), false, maxf(2.0, radius * 0.15))


func _draw_military_marker(centre: Vector2, radius: float) -> void:
	var shield := PackedVector2Array([
		centre + Vector2(-radius * 0.75, -radius * 0.68),
		centre + Vector2(radius * 0.75, -radius * 0.68),
		centre + Vector2(radius * 0.58, radius * 0.36),
		centre + Vector2(0, radius),
		centre + Vector2(-radius * 0.58, radius * 0.36),
	])
	draw_colored_polygon(shield, Color("8a3339"))
	shield.append(shield[0])
	draw_polyline(shield, Color("151515"), maxf(1.5, radius * 0.13), true)


func _draw_site_label(site: RegionSiteDefinition, centre: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: float = clampf(14.0 * _zoom, 12.0, 20.0)
	var offset: Vector2 = _site_label_offset(site) * clampf(_zoom, 0.85, 1.45)
	var position: Vector2 = centre + offset
	var text_size: Vector2 = font.get_string_size(site.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var background := Rect2(position + Vector2(-5, -font_size), text_size + Vector2(10, 7))
	draw_rect(background, Color(0.04, 0.05, 0.05, 0.80), true)
	draw_string(font, position, site.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("e9e1c9"))


func _should_draw_label(site: RegionSiteDefinition) -> bool:
	if site.site_type == &"district":
		return false
	if _zoom < 0.72:
		return site.id in [_definition.main_settlement_site_id, _definition.fifth_god_ruin_site_id]
	return site.label_priority >= 55


func _site_label_offset(site: RegionSiteDefinition) -> Vector2:
	if _definition != null and _definition.label_offsets_by_site_id.has(site.id):
		var authored: Variant = _definition.label_offsets_by_site_id[site.id]
		if authored is Vector2:
			return authored
	var custom: Dictionary = {
		&"site.settlement.crullfeld": Vector2(-20, -24),
		&"site.settlement.barnemouth": Vector2(-10, -25),
		&"site.settlement.westmarch": Vector2(18, 28),
		&"site.settlement.bellmare": Vector2(-15, 28),
		&"site.settlement.telluria": Vector2(-72, -30),
		&"site.settlement.dornwich": Vector2(-20, -25),
		&"site.settlement.torrine": Vector2(-25, -24),
		&"site.settlement.solis": Vector2(16, 24),
		&"site.settlement.laencaster": Vector2(-20, -25),
		&"site.settlement.lullin": Vector2(16, 22),
		&"site.settlement.balerno": Vector2(-18, 27),
		&"site.settlement.oakstead": Vector2(-22, -25),
		&"site.settlement.dalry": Vector2(-15, -24),
		&"site.settlement.ascot": Vector2(15, 23),
		&"site.fifth_god_ruin": Vector2(-88, 28),
		&"site.wilderness.deep_forest_ruins": Vector2(-110, -20),
		&"site.farm.starter_storehouse": Vector2(15, -22),
	}
	return custom.get(site.id, Vector2(15, -18))


func _process(delta: float) -> void:
	if _pending_focus_point != Vector2.INF and size.x > 1.0 and size.y > 1.0:
		var point: Vector2 = _pending_focus_point
		var target: Vector2 = _pending_focus_target
		_pending_focus_point = Vector2.INF
		_pending_focus_target = Vector2.INF
		_focus_map_unit(point, target)
	if _camera_focus_active:
		var weight: float = clampf(delta * 8.0, 0.0, 1.0)
		_pan = _pan.lerp(_camera_target_pan, weight)
		if _pan.distance_to(_camera_target_pan) < 0.5:
			_pan = _camera_target_pan
			_camera_focus_active = false
		_sync_static_layer_transform()
		queue_redraw()
	var agent: AgentState = _primary_agent()
	var agent_travelling: bool = (
		agent != null
		and agent.status == AgentState.STATUS_TRAVELLING
		and agent.active_travel_plan != null
	)
	var squad_operation: SquadTravelOperationState = _current_squad_operation()
	var squad_travelling: bool = (
		squad_operation != null
		and squad_operation.status in [
			SquadTravelOperationState.STATUS_TRAVELLING,
			SquadTravelOperationState.STATUS_RETURNING,
		]
		and squad_operation.route_plan != null
	)
	if (agent_travelling or squad_travelling) and _strategic_speed > StrategicClockService.SPEED_PAUSED:
		_visual_campaign_tick += delta * float(_strategic_speed)
		var arrival_limit: float = 0.0
		if agent_travelling:
			arrival_limit = maxf(arrival_limit, float(agent.active_travel_plan.arrival_tick))
		if squad_travelling:
			arrival_limit = maxf(arrival_limit, float(squad_operation.arrival_tick))
		if arrival_limit > 0.0:
			_visual_campaign_tick = minf(_visual_campaign_tick, arrival_limit)
		var gait_speed: float = clampf(5.5 + sqrt(float(_strategic_speed)) * 1.5, 5.5, 12.0)
		_agent_walk_phase = fmod(_agent_walk_phase + delta * gait_speed, TAU)
		queue_redraw()

	_redraw_accumulator += delta
	if _redraw_accumulator < 0.10:
		return
	_redraw_accumulator = 0.0
	var needs_animation: bool = _agent_preview_mode or _agent_selected
	if agent_travelling or squad_travelling:
		needs_animation = true
	var now: int = Time.get_ticks_msec()
	var expired_ids: Array[Variant] = []
	for raw_id: Variant in _new_mission_attention_until_ms.keys():
		if now < int(_new_mission_attention_until_ms[raw_id]):
			needs_animation = true
		else:
			expired_ids.append(raw_id)
	for raw_id: Variant in expired_ids:
		_new_mission_attention_until_ms.erase(raw_id)
	if needs_animation and not (
		(agent_travelling or squad_travelling)
		and _strategic_speed > StrategicClockService.SPEED_PAUSED
	):
		queue_redraw()


func _draw_agent_destination_preview() -> void:
	if not _agent_preview_mode or _agent_preview_destination == null:
		return
	var centre: Vector2 = _screen_point(_agent_preview_destination)
	var polygon: PackedVector2Array = _hex_polygon(centre, _hex_radius() * 0.94)
	var fill := Color(0.38, 0.78, 0.68, 0.22)
	var line := Color(0.58, 0.96, 0.83, 0.90)
	if _agent_preview_plan == null:
		fill = Color(0.82, 0.20, 0.20, 0.25)
		line = Color(0.97, 0.37, 0.35, 0.94)
		if _agent_preview_invalid_reason == "Agent is already here":
			fill = Color(0.88, 0.66, 0.22, 0.22)
			line = Color(0.96, 0.79, 0.37, 0.94)
	draw_colored_polygon(polygon, fill)
	polygon.append(polygon[0])
	draw_polyline(polygon, line, maxf(2.0, _hex_radius() * 0.075), true)
	if _agent_preview_plan == null and not _agent_preview_invalid_reason.is_empty():
		var font: Font = ThemeDB.fallback_font
		var font_size: float = clampf(13.0 * _zoom, 11.0, 18.0)
		var text_size: Vector2 = font.get_string_size(_agent_preview_invalid_reason, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var label_position := centre + Vector2(-text_size.x * 0.5, -_hex_radius() * 0.76)
		draw_rect(Rect2(label_position + Vector2(-5, -font_size), text_size + Vector2(10, 7)), Color(0.08, 0.04, 0.04, 0.88), true)
		draw_string(font, label_position, _agent_preview_invalid_reason, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("ffd3cd"))


func _draw_agent_debug_overlay() -> void:
	if not bool(ProjectSettings.get_setting("seethe/development/show_agent_debug", false)):
		return
	if _definition == null:
		return
	for segment: PackedVector2Array in RegionBoundaryPathfinder.debug_navigation_segments(_definition):
		if segment.size() == 2:
			draw_line(_screen_point_from_map_unit(segment[0]), _screen_point_from_map_unit(segment[1]), Color(0.35, 0.75, 1.0, 0.18), 1.0, true)
	var agent: AgentState = _primary_agent()
	if agent == null or _campaign == null:
		return
	var logical_hex: String = "none"
	if agent.current_hex != null:
		logical_hex = String(agent.current_hex.key())
	var lines: Array[String] = [
		"Agent state: %s" % String(agent.status).to_upper(),
		"Current tick: %d (visual %.2f)" % [_campaign.campaign_tick, _visual_campaign_tick],
		"Logical hex: %s" % logical_hex,
	]
	if agent.active_travel_plan != null:
		lines.append("Arrival tick: %d" % agent.active_travel_plan.arrival_tick)
		lines.append("Route progress: %.1f%%" % (agent.active_travel_plan.progress_at_time(_visual_campaign_tick) * 100.0))
	if agent.discovery_due_tick >= 0:
		lines.append("Hidden discovery due: %d" % agent.discovery_due_tick)
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2(12, 12), Vector2(265, 24 + lines.size() * 17)), Color(0.02, 0.03, 0.04, 0.86), true)
	for index: int in range(lines.size()):
		draw_string(font, Vector2(22, 34 + index * 17), lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13.0, Color("b8dced"))


func _draw_agent_coverage() -> void:
	var centre: RegionHexCoord = null
	if (
		_agent_preview_mode
		and _agent_preview_destination != null
		and _agent_preview_plan != null
	):
		centre = _agent_preview_destination
	elif _agent_selected:
		var agent: AgentState = _primary_agent()
		if agent != null and agent.status != AgentState.STATUS_TRAVELLING:
			centre = agent.current_hex
	if centre == null or _definition == null:
		return
	var coverage_key: StringName = StringName("%s:2" % centre.key())
	if not _coverage_by_centre_key.has(coverage_key):
		_coverage_by_centre_key[coverage_key] = RegionBoundaryPathfinder.covered_hexes(
			_definition,
			centre,
			2
		)
	var covered: Array = _coverage_by_centre_key[coverage_key] as Array
	for raw_coord: Variant in covered:
		var coord: RegionHexCoord = raw_coord as RegionHexCoord
		if coord == null:
			continue
		var polygon: PackedVector2Array = _hex_polygon(_screen_point(coord), _hex_radius() * 0.92)
		draw_colored_polygon(polygon, Color(0.22, 0.68, 0.63, 0.18))
		polygon.append(polygon[0])
		draw_polyline(polygon, Color(0.42, 0.90, 0.81, 0.62), maxf(1.0, _hex_radius() * 0.035), true)


func _draw_agent_route() -> void:
	var plan: AgentTravelPlan = _agent_preview_plan
	if plan == null and _agent_selected:
		var agent: AgentState = _primary_agent()
		if agent != null and agent.status == AgentState.STATUS_TRAVELLING:
			plan = agent.active_travel_plan
	if plan == null or plan.route_points.size() < 2:
		return
	var path := PackedVector2Array()
	for point: Vector2 in plan.route_points:
		path.append(_screen_point_from_map_unit(point))
	_draw_round_path(path, Color(0.06, 0.12, 0.12, 0.78), maxf(5.0, _hex_radius() * 0.16))
	_draw_round_path(path, Color(0.45, 0.94, 0.82, 0.92), maxf(2.0, _hex_radius() * 0.065))


func _draw_agent_token() -> void:
	var agent: AgentState = _primary_agent()
	if agent == null:
		return
	var map_position: Vector2 = _agent_map_position()
	if map_position == Vector2.INF:
		return
	var direction := Vector2.RIGHT
	var walk_phase: float = 0.0
	if agent.status == AgentState.STATUS_TRAVELLING and agent.active_travel_plan != null:
		direction = agent.active_travel_plan.direction_at_time(_visual_campaign_tick)
		walk_phase = sin(_agent_walk_phase)
	var centre: Vector2 = _screen_point_from_map_unit(map_position)
	if agent.status == AgentState.STATUS_TRAVELLING:
		centre.y += walk_phase * maxf(0.8, _hex_radius() * 0.025)
	var radius: float = maxf(7.0, _hex_radius() * 0.22)
	draw_circle(centre + Vector2(2, 3), radius * 1.08, Color(0.02, 0.03, 0.03, 0.55))
	draw_circle(centre, radius, Color("1b2425"))
	var ring_color := Color("d4b766") if _agent_selected else Color("7ea89e")
	var ring_width: float = maxf(2.0, radius * 0.16)
	if agent.status == AgentState.STATUS_DEPLOYED and _agent_selected:
		var pulse: float = 1.0 + sin(float(Time.get_ticks_msec()) * 0.004) * 0.06
		draw_arc(centre, radius * 1.25 * pulse, 0.0, TAU, 28, Color(0.48, 0.90, 0.80, 0.28), ring_width, true)
	draw_arc(centre, radius, 0.0, TAU, 28, ring_color, ring_width, true)
	var hood := PackedVector2Array([
		centre + Vector2(0, -radius * 0.68),
		centre + Vector2(-radius * 0.55, radius * 0.48),
		centre + Vector2(radius * 0.55, radius * 0.48),
	])
	draw_colored_polygon(hood, Color("354646"))
	draw_circle(centre + Vector2(0, -radius * 0.08), radius * 0.25, Color("0b1011"))
	draw_line(centre + Vector2(-radius * 0.13, -radius * 0.05), centre + Vector2(radius * 0.13, -radius * 0.05), Color("b9d9c8"), maxf(1.0, radius * 0.08), true)
	if agent.status == AgentState.STATUS_TRAVELLING:
		var forward: Vector2 = direction.normalized()
		var side := Vector2(-forward.y, forward.x)
		var foot_origin: Vector2 = centre + forward * radius * 0.44
		var stride: float = radius * 0.18 * walk_phase
		draw_line(foot_origin + side * (radius * 0.20 + stride), foot_origin + forward * radius * 0.38 + side * radius * 0.24, Color("d4b766"), maxf(1.2, radius * 0.10), true)
		draw_line(foot_origin - side * (radius * 0.20 + stride), foot_origin + forward * radius * 0.30 - side * radius * 0.24, Color("d4b766"), maxf(1.2, radius * 0.10), true)
		draw_line(centre + forward * radius * 0.92, centre + forward * radius * 1.28, Color("b9d9c8"), maxf(1.0, radius * 0.08), true)


func _draw_squad_route() -> void:
	var plan: SquadRoutePlan = _squad_hover_plan if _squad_hover_plan != null else _squad_route_plan
	if plan == null and not _squad_route_mode:
		var operation: SquadTravelOperationState = _current_squad_operation()
		if operation != null and operation.status in [
			SquadTravelOperationState.STATUS_TRAVELLING,
			SquadTravelOperationState.STATUS_RETURNING,
		]:
			plan = operation.route_plan
	if plan == null or plan.route_points.size() < 2:
		return
	var path := PackedVector2Array()
	for point: Vector2 in plan.route_points:
		path.append(_screen_point_from_map_unit(point))
	var active_operation: SquadTravelOperationState = _current_squad_operation()
	var is_returning: bool = (
		active_operation != null
		and active_operation.status == SquadTravelOperationState.STATUS_RETURNING
		and active_operation.route_plan == plan
	)
	var outer_color := Color(0.04, 0.07, 0.10, 0.86) if is_returning else Color(0.10, 0.04, 0.04, 0.82)
	var inner_color := Color(0.45, 0.78, 0.90, 0.96) if is_returning else Color(0.94, 0.56, 0.25, 0.95)
	_draw_round_path(path, outer_color, maxf(6.0, _hex_radius() * 0.19))
	_draw_round_path(path, inner_color, maxf(2.2, _hex_radius() * 0.075))
	if _squad_route_mode:
		var font: Font = ThemeDB.fallback_font
		for index: int in range(_squad_route_waypoints.size()):
			var centre: Vector2 = _screen_point(_squad_route_waypoints[index])
			draw_circle(centre, maxf(8.0, _hex_radius() * 0.23), Color(0.20, 0.08, 0.04, 0.90))
			draw_string(
				font,
				centre + Vector2(-4.0, 5.0),
				str(index + 1),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				maxf(12.0, _hex_radius() * 0.30),
				Color("ffe1b5")
			)


func _draw_squad_token() -> void:
	var operation: SquadTravelOperationState = _current_squad_operation()
	if operation == null or operation.status not in [
		SquadTravelOperationState.STATUS_TRAVELLING,
		SquadTravelOperationState.STATUS_RETURNING,
	]:
		return
	var map_position: Vector2 = operation.map_position_at_time(_visual_campaign_tick)
	var centre: Vector2 = _screen_point_from_map_unit(map_position)
	var direction: Vector2 = operation.route_plan.direction_at_time(_visual_campaign_tick)
	var radius: float = maxf(9.0, _hex_radius() * 0.25)
	var bob: float = sin(_agent_walk_phase) * maxf(0.8, _hex_radius() * 0.022)
	centre.y += bob
	var is_returning: bool = operation.status == SquadTravelOperationState.STATUS_RETURNING
	var token_fill := Color("28596b") if is_returning else Color("7b2e21")
	var token_edge := Color("8bd0e3") if is_returning else Color("edb75f")
	var token_mark := Color("d8f3f8") if is_returning else Color("f5dfaa")
	draw_circle(centre + Vector2(2, 3), radius * 1.12, Color(0.02, 0.02, 0.02, 0.65))
	draw_circle(centre, radius, token_fill)
	draw_arc(centre, radius, 0.0, TAU, 28, token_edge, maxf(2.0, radius * 0.14), true)
	if _squad_selected:
		draw_arc(centre, radius * 1.35, 0.0, TAU, 36, Color("f2df9d"), maxf(2.0, radius * 0.12), true)
	var forward: Vector2 = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	draw_line(centre - forward * radius * 0.55, centre + forward * radius * 0.72, token_mark, maxf(2.0, radius * 0.18), true)
	draw_circle(centre + forward * radius * 0.72, radius * 0.20, token_mark)
	if _squad_selected:
		var label_text: String = "RETURNING" if is_returning else "TRAVELLING"
		var font: Font = ThemeDB.fallback_font
		var font_size: int = maxi(11, roundi(_hex_radius() * 0.25))
		var label_position := centre + Vector2(radius * 1.35, -radius * 0.55)
		draw_string(font, label_position + Vector2(1, 1), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0, 0, 0, 0.85))
		draw_string(font, label_position, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("d8f3f8") if is_returning else Color("f5dfaa"))


func _draw_mission_markers() -> void:
	if _campaign == null or _definition == null:
		return
	for mission: ActiveMissionState in _campaign.get_active_missions():
		if mission.status in [
			ActiveMissionState.STATUS_RESOLVED,
			ActiveMissionState.STATUS_CANCELLED,
			ActiveMissionState.STATUS_EXPIRED,
		]:
			continue
		var site: RegionSiteDefinition = _definition.site(mission.site_id)
		if site == null or site.coord == null:
			continue
		var centre: Vector2 = _screen_point(site.coord) + Vector2(_hex_radius() * 0.38, -_hex_radius() * 0.38)
		var attention_until: int = int(_new_mission_attention_until_ms.get(mission.mission_instance_id, 0))
		var pulse: float = 1.0
		if Time.get_ticks_msec() < attention_until:
			pulse += sin(float(Time.get_ticks_msec()) * 0.006) * 0.10
		var radius: float = maxf(8.0, _hex_radius() * 0.22) * pulse
		var urgent: bool = (
			mission.is_available()
			and mission.remaining_minutes(_campaign.campaign_tick) <= 12 * 60
		)
		var marker_color: Color = Color("d64135") if urgent else Color("b83f2f")
		var ring_color: Color = Color("ffd06f") if urgent else Color("f2d38b")
		draw_circle(centre, radius * 1.20, Color(0.05, 0.03, 0.02, 0.72))
		draw_circle(centre, radius, marker_color)
		draw_arc(centre, radius, 0.0, TAU, 24, ring_color, maxf(2.0, radius * 0.14), true)
		if urgent:
			draw_arc(centre, radius * 1.38, 0.0, TAU, 24, Color(1.0, 0.35, 0.16, 0.72), maxf(1.4, radius * 0.09), true)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, centre + Vector2(-3.5, 5.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, radius * 1.25, Color("fff1c7"))


func _draw_raid_markers() -> void:
	if _campaign == null or _definition == null:
		return
	for raw_raid: Variant in _campaign.raid_operations_by_id.values():
		var raid: RaidOperationState = raw_raid as RaidOperationState
		if raid == null or not raid.is_active():
			continue
		var origin: RegionSiteDefinition = _definition.site(raid.origin_settlement_id)
		if origin == null or origin.coord == null:
			continue
		var centre: Vector2 = _screen_point(origin.coord) + Vector2(-_hex_radius() * 0.38, -_hex_radius() * 0.38)
		var radius: float = maxf(10.0, _hex_radius() * 0.25)
		draw_circle(centre, radius * 1.28, Color(0.04, 0.01, 0.01, 0.82))
		draw_circle(centre, radius, Color("7c1f2a"))
		draw_arc(centre, radius, 0.0, TAU, 28, Color("f0aa78"), maxf(2.0, radius * 0.14), true)
		var font: Font = ThemeDB.fallback_font
		draw_string(
			font,
			centre + Vector2(-radius * 0.68, radius * 0.22),
			"RAID",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			maxf(8.0, radius * 0.58),
			Color("fff0d7")
		)


func _update_agent_preview(screen_position: Vector2) -> void:
	var destination: RegionHexCoord = _hex_at_screen_position(screen_position)
	if destination == null:
		_agent_preview_destination = null
		_agent_preview_plan = null
		_agent_preview_invalid_reason = ""
		queue_redraw()
		return
	if _agent_preview_destination != null and _agent_preview_destination.key() == destination.key():
		return
	_agent_preview_destination = destination
	_agent_preview_plan = null
	_agent_preview_invalid_reason = _basic_agent_destination_error(destination)
	if _agent_preview_invalid_reason.is_empty() and _agent_preview_provider.is_valid():
		var route_started_usec: int = RuntimeStallAttribution.begin()
		var raw_plan: Variant = _agent_preview_provider.call(destination)
		RuntimeStallAttribution.end(
			&"agent_route_preview",
			route_started_usec,
			String(destination.key())
		)
		_agent_preview_plan = raw_plan as AgentTravelPlan
		if _agent_preview_plan == null:
			_agent_preview_invalid_reason = "No valid route"
	queue_redraw()


func _update_squad_route_preview(screen_position: Vector2) -> void:
	if not _squad_route_mode:
		return
	var destination: RegionHexCoord = _hex_at_screen_position(screen_position)
	if destination == null:
		if _squad_hover_destination != null or _squad_hover_plan != null:
			_squad_hover_destination = null
			_squad_hover_plan = null
			queue_redraw()
		return
	if _squad_hover_destination != null and _squad_hover_destination.key() == destination.key():
		return
	_squad_hover_destination = destination
	_squad_hover_plan = null
	var destination_hex: RegionHexDefinition = _definition.hex_at_offset(
		destination.offset_col,
		destination.offset_row
	)
	if destination_hex == null or not destination_hex.playable or destination_hex.terrain_type == RegionTerrainType.LAKE:
		queue_redraw()
		return
	if _squad_route_provider.is_valid():
		var preview_waypoints: Array[RegionHexCoord] = []
		for waypoint: RegionHexCoord in _squad_route_waypoints:
			preview_waypoints.append(waypoint.duplicate_coord())
		var mission_site: RegionSiteDefinition = _definition.site(_squad_route_mission_site_id)
		if mission_site == null or mission_site.coord == null or mission_site.coord.key() != destination.key():
			var duplicate: bool = false
			for waypoint: RegionHexCoord in preview_waypoints:
				if waypoint.key() == destination.key():
					duplicate = true
					break
			if not duplicate:
				preview_waypoints.append(destination.duplicate_coord())
		var raw_plan: Variant = _squad_route_provider.call(
			_squad_route_mission_id,
			preview_waypoints
		)
		_squad_hover_plan = raw_plan as SquadRoutePlan
	queue_redraw()


func _basic_agent_destination_error(destination: RegionHexCoord) -> String:
	if destination == null or _definition == null:
		return "Outside region"
	var destination_hex: RegionHexDefinition = _definition.hex_at_offset(destination.offset_col, destination.offset_row)
	if destination_hex == null or not destination_hex.playable:
		return "Outside region"
	if destination_hex.terrain_type == RegionTerrainType.LAKE:
		return "Lake"
	var agent: AgentState = _primary_agent()
	if agent != null and agent.current_hex != null and agent.current_hex.key() == destination.key():
		return "Agent is already here"
	return ""


func _hex_at_screen_position(screen_position: Vector2) -> RegionHexCoord:
	var started_usec: int = RuntimeStallAttribution.begin()
	if _definition == null:
		RuntimeStallAttribution.end(&"region_hex_hit_test", started_usec, "missing_region")
		return null
	var radius: float = _hex_radius()
	if radius <= 0.001:
		RuntimeStallAttribution.end(&"region_hex_hit_test", started_usec, "invalid_radius")
		return null
	var map_point: Vector2 = (screen_position - _map_origin()) / radius
	var approximate_col: int = roundi(map_point.x / 1.5)
	for col: int in range(approximate_col - 1, approximate_col + 2):
		if col < 0 or col >= _definition.width:
			continue
		var vertical_offset: float = 0.5 if col % 2 == 0 else 0.0
		var approximate_row: int = roundi(map_point.y / SQRT_THREE - vertical_offset)
		for row: int in range(approximate_row - 1, approximate_row + 2):
			if row < 0 or row >= _definition.height:
				continue
			var coord: RegionHexCoord = RegionHexCoord.from_offset(col, row)
			var hex: RegionHexDefinition = _hex_by_key.get(coord.key()) as RegionHexDefinition
			if hex == null or not hex.playable:
				continue
			var polygon: PackedVector2Array = _hex_polygon(
				RegionBoundaryPathfinder.map_center(coord),
				1.0
			)
			if Geometry2D.is_point_in_polygon(map_point, polygon):
				RuntimeStallAttribution.end(&"region_hex_hit_test", started_usec, "candidate_hit")
				return coord
	RuntimeStallAttribution.end(&"region_hex_hit_test", started_usec, "no_hit")
	return null


func _current_squad_operation() -> SquadTravelOperationState:
	return _campaign.current_squad_travel_operation() if _campaign != null else null


func _squad_map_position() -> Vector2:
	var operation: SquadTravelOperationState = _current_squad_operation()
	if operation == null or operation.route_plan == null:
		return Vector2.INF
	return operation.map_position_at_time(_visual_campaign_tick)


func _primary_agent() -> AgentState:
	if _campaign == null:
		return null
	var agents: Array[AgentState] = _campaign.get_agents()
	return agents[0] if not agents.is_empty() else null


func _agent_map_position() -> Vector2:
	var agent: AgentState = _primary_agent()
	if agent == null or agent.current_hex == null:
		return Vector2.INF
	if agent.status == AgentState.STATUS_TRAVELLING and agent.active_travel_plan != null:
		return agent.active_travel_plan.map_position_at_time(_visual_campaign_tick)
	return RegionBoundaryPathfinder.map_center(agent.current_hex)


func _is_agent_at_screen_position(screen_position: Vector2) -> bool:
	var map_position: Vector2 = _agent_map_position()
	if map_position == Vector2.INF:
		return false
	return screen_position.distance_to(_screen_point_from_map_unit(map_position)) <= maxf(10.0, _hex_radius() * 0.30)


func _is_squad_at_screen_position(screen_position: Vector2) -> bool:
	var operation: SquadTravelOperationState = _current_squad_operation()
	if operation == null or operation.status not in [
		SquadTravelOperationState.STATUS_TRAVELLING,
		SquadTravelOperationState.STATUS_RETURNING,
	]:
		return false
	var map_position: Vector2 = _squad_map_position()
	if map_position == Vector2.INF:
		return false
	return screen_position.distance_to(_screen_point_from_map_unit(map_position)) <= maxf(12.0, _hex_radius() * 0.36)


func _screen_point_from_map_unit(point: Vector2) -> Vector2:
	return _map_origin() + point * _hex_radius()


func _map_origin() -> Vector2:
	var radius: float = _hex_radius()
	var unit_width: float = 1.5 * float(_definition.width - 1) + 2.0
	var unit_height: float = SQRT_THREE * (float(_definition.height) + 0.5)
	var map_size := Vector2(unit_width * radius, unit_height * radius)
	return (size - map_size) * 0.5 + Vector2(radius, SQRT_THREE * radius * 0.5) + _pan


func _focus_map_unit(point: Vector2, screen_target: Vector2) -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		_pending_focus_point = point
		_pending_focus_target = screen_target
		return
	var current: Vector2 = _screen_point_from_map_unit(point)
	var limit: Vector2 = size * 0.42
	_camera_target_pan = (_pan + screen_target - current).clamp(-limit, limit)
	_camera_focus_active = true
	queue_redraw()


func _draw_missing_region_message() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string(font, size * 0.5 - Vector2(160, 0), "Authored region definition unavailable.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18.0, Color("d98a8a"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_at(mouse_button.position, 1.12)
			accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_at(mouse_button.position, 1.0 / 1.12)
			accept_event()
		elif _squad_route_mode and mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			squad_waypoint_removed.emit()
			accept_event()
		elif _agent_preview_mode and mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			set_agent_preview_mode(false)
			agent_preview_cancelled.emit()
			accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_button.pressed:
				_camera_focus_active = false
				_dragging = true
				_drag_origin = mouse_button.position
				_pan_origin = _pan
			else:
				_dragging = false
			accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if _squad_route_mode:
				if mouse_button.pressed:
					var destination: RegionHexCoord = _hex_at_screen_position(mouse_button.position)
					if destination != null:
						var destination_hex: RegionHexDefinition = _definition.hex_at_offset(
							destination.offset_col,
							destination.offset_row
						)
						if (
							destination_hex != null
							and destination_hex.playable
							and destination_hex.terrain_type != RegionTerrainType.LAKE
						):
							squad_waypoint_added.emit(destination.duplicate_coord())
				accept_event()
			elif _agent_preview_mode:
				if mouse_button.pressed and _agent_preview_plan != null and _agent_preview_destination != null:
					agent_destination_confirmed.emit(_agent_preview_destination.duplicate_coord())
				accept_event()
			elif mouse_button.pressed:
				_camera_focus_active = false
				_dragging = true
				_drag_origin = mouse_button.position
				_pan_origin = _pan
				accept_event()
			else:
				var travel: float = mouse_button.position.distance_to(_drag_origin)
				_dragging = false
				if travel < 7.0:
					if _is_squad_at_screen_position(mouse_button.position):
						_squad_selected = not _squad_selected
						_agent_selected = false
						_selected_site_id = &""
						var operation: SquadTravelOperationState = _current_squad_operation()
						if _squad_selected and operation != null:
							squad_selected.emit(operation.operation_id)
						else:
							selection_cleared.emit()
					elif _is_agent_at_screen_position(mouse_button.position):
						_squad_selected = false
						_agent_selected = not _agent_selected
						_selected_site_id = &""
						selection_cleared.emit()
					else:
						_squad_selected = false
						_agent_selected = false
						_select_site_at(mouse_button.position)
				accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging:
			_pan = _pan_origin + motion.position - _drag_origin
			var limit: Vector2 = size * 0.42
			_pan = _pan.clamp(-limit, limit)
			_sync_static_layer_transform()
			queue_redraw()
		elif _squad_route_mode:
			_update_squad_route_preview(motion.position)
		elif _agent_preview_mode:
			_update_agent_preview(motion.position)
		else:
			var next_hovered_site_id: StringName = _site_at(motion.position)
			if next_hovered_site_id != _hovered_site_id:
				_hovered_site_id = next_hovered_site_id
				queue_redraw()


func _zoom_at(position: Vector2, factor: float) -> void:
	_camera_focus_active = false
	var old_zoom: float = _zoom
	_zoom = clampf(_zoom * factor, 0.42, 3.5)
	if not is_equal_approx(old_zoom, _zoom):
		var ratio: float = _zoom / old_zoom
		_pan = position - (position - _pan - size * 0.5) * ratio - size * 0.5
		_sync_static_layer_transform()
	queue_redraw()


func _select_site_at(position: Vector2) -> void:
	var site_id: StringName = _site_at(position)
	_selected_site_id = site_id
	if site_id.is_empty():
		selection_cleared.emit()
	else:
		site_selected.emit(site_id)
	queue_redraw()


func _site_at(position: Vector2) -> StringName:
	if _definition == null:
		return &""
	var hovered_hex: RegionHexCoord = _hex_at_screen_position(position)
	if hovered_hex == null:
		return &""
	var candidate_ids: Array = _site_ids_by_hex_key.get(hovered_hex.key(), []) as Array
	# Independent sites and districts take precedence over their parent settlement.
	for raw_id: Variant in candidate_ids:
		var site: RegionSiteDefinition = _definition.site(StringName(raw_id))
		if site == null or not site.inspectable or site.coord == null or site.site_type == &"settlement":
			continue
		if position.distance_to(_screen_point(site.coord)) <= _site_hit_radius(site):
			return site.id
	for raw_id: Variant in candidate_ids:
		var site: RegionSiteDefinition = _definition.site(StringName(raw_id))
		if site == null or not site.inspectable or site.site_type != &"settlement":
			continue
		return site.id
	return &""


func _site_hit_radius(site: RegionSiteDefinition) -> float:
	var radius: float = _hex_radius()
	match site.site_type:
		&"district":
			return radius * 0.48
		&"settlement":
			return radius * 0.45
		&"stronghold", &"ruin":
			return radius * 0.46
	return radius * 0.38


func _hex_radius() -> float:
	if _definition == null or size.x <= 1.0 or size.y <= 1.0:
		return 24.0
	var unit_width: float = 1.5 * float(_definition.width - 1) + 2.0
	var unit_height: float = SQRT_THREE * (float(_definition.height) + 0.5)
	var fit: float = minf(
		(size.x - MAP_MARGIN.x * 2.0) / unit_width,
		(size.y - MAP_MARGIN.y * 2.0) / unit_height
	)
	return maxf(10.0, fit * _zoom)


func _screen_point(coord: RegionHexCoord) -> Vector2:
	return _screen_point_from_map_unit(RegionBoundaryPathfinder.map_center(coord))


func _hex_polygon(centre: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(6):
		var angle: float = deg_to_rad(float(index) * 60.0)
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _terrain_color(terrain_type: StringName) -> Color:
	match terrain_type:
		RegionTerrainType.FARMLAND:
			return Color("e3c33a")
		RegionTerrainType.LAKE:
			return Color("91c8ee")
		RegionTerrainType.MARSH:
			return Color("83c998")
		RegionTerrainType.FOREST:
			return Color("087b43")
		RegionTerrainType.DEEP_FOREST:
			return Color("056423")
	return Color("91bb47")
