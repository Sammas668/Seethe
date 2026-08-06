class_name AuthoringRegionMapView
extends RegionMapView

signal selection_changed(selection: Dictionary)
signal edit_started
signal edit_finished(changed: bool)
signal status_changed(message: String)

const TOOL_SELECT: StringName = &"select"
const TOOL_TERRAIN: StringName = &"terrain"
const TOOL_ROAD: StringName = &"road"
const TOOL_BORDER: StringName = &"border"
const TOOL_SUBREGION: StringName = &"subregion"
const TOOL_SETTLEMENT: StringName = &"settlement"
const TOOL_DISTRICT: StringName = &"district"
const TOOL_SITE: StringName = &"site"
const TOOL_LABEL: StringName = &"label"
const TOOL_ERASE: StringName = &"erase"

const NEIGHBOUR_INDEX_BY_EDGE: Array[int] = [0, 5, 4, 3, 2, 1]

var document: RegionAuthoringDocument
var active_tool: StringName = TOOL_SELECT
var active_terrain: StringName = RegionTerrainType.GRASSLAND
var active_road_type: StringName = RegionRoadType.LOCAL_ROAD
var active_border_type: StringName = &"subregion_border"
var active_subregion_id: StringName = &"subregion.life.telluria_proper"
var active_settlement_id: StringName = &""
var active_district_symbol: StringName = RegionSymbolCatalogue.WHEAT_WAREHOUSE
var active_site_id: StringName = &""
var erase_target: StringName = &"roads"
var show_coordinates: bool = false
var primary_remove_mode: bool = false
var settlement_operation: StringName = &"add"
var district_operation: StringName = &"assign"

var _selected_hex: RegionHexCoord
var _selected_edge: Dictionary = {}
var _hovered_authoring_edge: Dictionary = {}
var _selected_authoring_site_id: StringName = &""
var _panning: bool = false
var _pan_drag_origin: Vector2
var _pan_start: Vector2
var _stroke_active: bool = false
var _stroke_changed: bool = false
var _last_stroke_key: StringName = &""
var _label_drag_site_id: StringName = &""
var _stroke_remove: bool = false
var _stroke_eyedropper: bool = false


func configure_document(value: RegionAuthoringDocument) -> void:
	document = value
	if document != null:
		document.apply_label_offsets_to_region()
		super.configure(document.region)
		set_view_transform(
			float(document.editor_metadata.get("camera_zoom", 1.0)),
			Vector2(
				float(document.editor_metadata.get("camera_pan_x", 0.0)),
				float(document.editor_metadata.get("camera_pan_y", 0.0))
			)
		)
	else:
		super.configure(null)
	queue_redraw()


func refresh_from_document(preserve_view: bool = true) -> void:
	if document == null:
		return
	var zoom_value: float = view_zoom()
	var pan_value: Vector2 = view_pan()
	document.apply_label_offsets_to_region()
	_definition = document.region
	if preserve_view:
		set_view_transform(zoom_value, pan_value)
	queue_redraw()


func set_active_tool(tool_id: StringName) -> void:
	active_tool = tool_id
	status_changed.emit("Active tool: %s" % String(tool_id).capitalize())


func selected_coord() -> RegionHexCoord:
	return _selected_hex.duplicate_coord() if _selected_hex != null else null


func prepare_clean_preview() -> Dictionary:
	var state: Dictionary = {
		"coordinates": show_coordinates,
		"selected_hex": _selected_hex,
		"selected_edge": _selected_edge.duplicate(true),
		"selected_site_id": _selected_authoring_site_id,
	}
	show_coordinates = false
	_selected_hex = null
	_selected_edge.clear()
	_selected_authoring_site_id = &""
	queue_redraw()
	return state


func restore_preview_state(state: Dictionary) -> void:
	show_coordinates = bool(state.get("coordinates", false))
	_selected_hex = state.get("selected_hex") as RegionHexCoord
	_selected_edge = (state.get("selected_edge", {}) as Dictionary).duplicate(true)
	_selected_authoring_site_id = StringName(state.get("selected_site_id", ""))
	queue_redraw()


func centre_on_coord(coord: RegionHexCoord) -> void:
	if coord == null or _definition == null:
		return
	var point: Vector2 = _screen_point(coord)
	_pan += size * 0.5 - point
	queue_redraw()


func _draw() -> void:
	super._draw()
	if document == null or document.region == null:
		return
	if show_coordinates:
		_draw_coordinates()
	_draw_authoring_selection()



func _draw_coordinates() -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: float = clampf(10.0 * _zoom, 9.0, 14.0)
	for hex: RegionHexDefinition in document.region.all_hexes():
		var centre: Vector2 = _screen_point(hex.coord)
		var text: String = "%d,%d" % [hex.coord.offset_col, hex.coord.offset_row]
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		draw_rect(Rect2(centre - text_size * 0.5 - Vector2(2, 1), text_size + Vector2(4, 2)), Color(0.03, 0.03, 0.03, 0.68), true)
		draw_string(font, centre + Vector2(-text_size.x * 0.5, font_size * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("f3ead2"))


func _draw_authoring_selection() -> void:
	var radius: float = _hex_radius()
	if not _hovered_authoring_edge.is_empty() and active_tool in [TOOL_ROAD, TOOL_BORDER]:
		var hover_owner: RegionHexCoord = _hovered_authoring_edge.get("owner") as RegionHexCoord
		var hover_edge_index: int = int(_hovered_authoring_edge.get("edge_index", -1))
		if hover_owner != null and hover_edge_index >= 0:
			var hover_polygon: PackedVector2Array = _hex_polygon(_screen_point(hover_owner), radius)
			var hover_path := PackedVector2Array([
				hover_polygon[hover_edge_index],
				hover_polygon[(hover_edge_index + 1) % 6],
			])
			if active_tool == TOOL_ROAD:
				_draw_road_path(hover_path, active_road_type)
			else:
				_draw_round_path(hover_path, Color("3b161a"), _border_outer_width())
				_draw_round_path(hover_path, Color("c82836"), _border_inner_width())
			draw_line(hover_path[0], hover_path[1], Color(1.0, 1.0, 1.0, 0.42), maxf(1.0, radius * 0.035), true)
	if _selected_hex != null:
		var polygon: PackedVector2Array = _hex_polygon(_screen_point(_selected_hex), radius * 0.90)
		polygon.append(polygon[0])
		draw_polyline(polygon, Color("fff173"), maxf(2.0, radius * 0.08), true)
	if not _selected_edge.is_empty():
		var owner: RegionHexCoord = _selected_edge.get("owner") as RegionHexCoord
		var edge_index: int = int(_selected_edge.get("edge_index", -1))
		if owner != null and edge_index >= 0:
			var polygon: PackedVector2Array = _hex_polygon(_screen_point(owner), radius)
			draw_line(polygon[edge_index], polygon[(edge_index + 1) % 6], Color("fff173"), maxf(4.0, radius * 0.16), true)
	if not _selected_authoring_site_id.is_empty():
		var site: RegionSiteDefinition = document.region.site(_selected_authoring_site_id)
		if site != null and site.coord != null:
			draw_circle(_screen_point(site.coord), radius * 0.55, Color(1.0, 0.95, 0.45, 0.25))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 1.12)
		_store_camera()
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 1.0 / 1.12)
		_store_camera()
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			_panning = true
			_pan_drag_origin = event.position
			_pan_start = _pan
		else:
			_panning = false
			_store_camera()
		accept_event()
		return
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	if event.pressed:
		_stroke_active = true
		_stroke_changed = false
		_stroke_remove = event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and primary_remove_mode)
		_stroke_eyedropper = event.ctrl_pressed
		_last_stroke_key = &""
		edit_started.emit()
		_apply_pointer_action(event.position, _stroke_remove, _stroke_eyedropper)
	else:
		if _stroke_active:
			_stroke_active = false
			_label_drag_site_id = &""
			edit_finished.emit(_stroke_changed)
	accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _panning:
		_pan = _pan_start + event.position - _pan_drag_origin
		queue_redraw()
		return
	if active_tool in [TOOL_ROAD, TOOL_BORDER]:
		var hovered: Dictionary = _edge_at(event.position)
		if _edge_dictionary_key(hovered) != _edge_dictionary_key(_hovered_authoring_edge):
			_hovered_authoring_edge = hovered
			queue_redraw()
	elif not _hovered_authoring_edge.is_empty():
		_hovered_authoring_edge.clear()
		queue_redraw()
	if _stroke_active and active_tool in [TOOL_TERRAIN, TOOL_ROAD, TOOL_BORDER, TOOL_SUBREGION, TOOL_SETTLEMENT, TOOL_DISTRICT, TOOL_LABEL, TOOL_ERASE]:
		_apply_pointer_action(event.position, _stroke_remove, _stroke_eyedropper)


func _edge_dictionary_key(edge: Dictionary) -> StringName:
	if edge.is_empty():
		return &""
	var owner: RegionHexCoord = edge.get("owner") as RegionHexCoord
	var neighbour: RegionHexCoord = edge.get("neighbour") as RegionHexCoord
	return _canonical_edge_key(owner, neighbour, int(edge.get("edge_index", -1))) if owner != null else &""


func _apply_pointer_action(position: Vector2, remove: bool, eyedropper: bool) -> void:
	if document == null or document.region == null:
		return
	match active_tool:
		TOOL_SELECT:
			_select_at(position)
		TOOL_TERRAIN:
			_apply_terrain(position, remove, eyedropper)
		TOOL_ROAD:
			_apply_edge(position, true, remove)
		TOOL_BORDER:
			_apply_edge(position, false, remove)
		TOOL_SUBREGION:
			_apply_subregion(position)
		TOOL_SETTLEMENT:
			match settlement_operation:
				&"remove":
					_apply_settlement(position, true)
				&"set_anchor":
					_apply_settlement(position, false, true)
				_:
					_apply_settlement(position, remove, eyedropper)
		TOOL_DISTRICT:
			_apply_district(position, remove or district_operation == &"clear")
		TOOL_SITE:
			_apply_site(position)
		TOOL_LABEL:
			_apply_label(position)
		TOOL_ERASE:
			_apply_erase(position)


func _select_at(position: Vector2) -> void:
	var site_id: StringName = _site_at(position)
	if not site_id.is_empty():
		_selected_authoring_site_id = site_id
		var site: RegionSiteDefinition = document.region.site(site_id)
		_selected_hex = site.coord.duplicate_coord() if site != null and site.coord != null else null
		_selected_edge.clear()
		_emit_site_selection(site)
		queue_redraw()
		return
	var edge: Dictionary = _edge_at(position)
	if not edge.is_empty():
		_selected_edge = edge
		_selected_hex = edge.get("owner") as RegionHexCoord
		_selected_authoring_site_id = &""
		selection_changed.emit(_edge_selection_dictionary(edge))
		queue_redraw()
		return
	var coord: RegionHexCoord = _hex_at(position)
	_selected_hex = coord
	_selected_edge.clear()
	_selected_authoring_site_id = &""
	if coord == null:
		selection_changed.emit({"kind": "none"})
	else:
		selection_changed.emit(_hex_selection_dictionary(coord))
	queue_redraw()


func _apply_terrain(position: Vector2, remove: bool, eyedropper: bool) -> void:
	var coord: RegionHexCoord = _hex_at(position)
	if coord == null:
		return
	var key: StringName = coord.key()
	if key == _last_stroke_key:
		return
	_last_stroke_key = key
	var hex: RegionHexDefinition = document.region.hex_at_offset(coord.offset_col, coord.offset_row)
	if hex == null:
		return
	if eyedropper:
		active_terrain = hex.terrain_type
		status_changed.emit("Terrain sampled: %s" % String(active_terrain).capitalize())
		return
	if active_terrain == &"outside_region" and not remove:
		if hex.playable:
			hex.playable = false
			_stroke_changed = true
		queue_redraw()
		return
	var target: StringName = RegionTerrainType.GRASSLAND if remove else active_terrain
	if not hex.playable:
		hex.playable = true
		_stroke_changed = true
	if hex.terrain_type == target and _stroke_changed:
		queue_redraw()
		return
	if hex.terrain_type == target:
		return
	hex.terrain_type = target
	_stroke_changed = true
	_selected_hex = coord
	queue_redraw()


func _apply_edge(position: Vector2, is_road: bool, remove: bool) -> void:
	var edge: Dictionary = _edge_at(position)
	if edge.is_empty():
		return
	var owner: RegionHexCoord = edge.get("owner") as RegionHexCoord
	var neighbour: RegionHexCoord = edge.get("neighbour") as RegionHexCoord
	var edge_index: int = int(edge.get("edge_index", -1))
	var stroke_key := StringName(("road:" if is_road else "border:") + String(_canonical_edge_key(owner, neighbour, edge_index)))
	if stroke_key == _last_stroke_key:
		return
	_last_stroke_key = stroke_key
	if is_road and not remove and _road_would_touch_stronghold(owner, neighbour):
		status_changed.emit("Public road rejected: the Fifth-God stronghold is concealed and off-road.")
		return
	var changed: bool = document.remove_edge(is_road, owner, neighbour, edge_index) if remove else document.add_or_replace_edge(
		is_road,
		owner,
		neighbour,
		edge_index,
		active_road_type if is_road else active_border_type
	)
	if changed:
		_stroke_changed = true
		_selected_edge = edge
		queue_redraw()


func _apply_settlement(position: Vector2, remove: bool, set_anchor: bool = false) -> void:
	if active_settlement_id.is_empty():
		status_changed.emit("Choose a settlement before editing its footprint.")
		return
	var coord: RegionHexCoord = _hex_at(position)
	if coord == null or coord.key() == _last_stroke_key:
		return
	_last_stroke_key = coord.key()
	if set_anchor:
		var settlement: RegionSiteDefinition = document.region.site(active_settlement_id)
		if settlement != null and settlement.contains_offset(coord.offset_col, coord.offset_row):
			settlement.coord = coord.duplicate_coord()
			_stroke_changed = true
			_selected_hex = coord
			refresh_from_document()
			status_changed.emit("Settlement anchor moved to %s." % coord.key())
		return
	if document.toggle_settlement_footprint(active_settlement_id, coord.offset_col, coord.offset_row, not remove):
		_stroke_changed = true
		_selected_hex = coord
		refresh_from_document()


func _apply_subregion(position: Vector2) -> void:
	var coord: RegionHexCoord = _hex_at(position)
	if coord == null or coord.key() == _last_stroke_key:
		return
	_last_stroke_key = coord.key()
	if document.paint_subregion(coord.offset_col, coord.offset_row, active_subregion_id):
		_stroke_changed = true
		_selected_hex = coord
		queue_redraw()



func _apply_district(position: Vector2, remove: bool) -> void:
	if active_settlement_id.is_empty():
		status_changed.emit("Choose a settlement before assigning district symbols.")
		return
	var coord: RegionHexCoord = _hex_at(position)
	if coord == null or coord.key() == _last_stroke_key:
		return
	_last_stroke_key = coord.key()
	var changed: bool = document.clear_district(coord.offset_col, coord.offset_row) if remove else document.assign_district(
		active_settlement_id,
		coord.offset_col,
		coord.offset_row,
		active_district_symbol
	)
	if changed:
		_stroke_changed = true
		_selected_hex = coord
		refresh_from_document()


func _apply_site(position: Vector2) -> void:
	if active_site_id.is_empty():
		status_changed.emit("Choose a site before moving it.")
		return
	var coord: RegionHexCoord = _hex_at(position)
	if coord == null:
		return
	if document.move_site(active_site_id, coord.offset_col, coord.offset_row):
		_stroke_changed = true
		_selected_authoring_site_id = active_site_id
		_selected_hex = coord
		refresh_from_document()


func _apply_label(position: Vector2) -> void:
	if _label_drag_site_id.is_empty():
		var site_id: StringName = _site_at(position)
		if site_id.is_empty():
			site_id = _selected_authoring_site_id
		if site_id.is_empty():
			return
		_label_drag_site_id = site_id
	var site: RegionSiteDefinition = document.region.site(_label_drag_site_id)
	if site == null or site.coord == null:
		return
	var offset: Vector2 = position - _screen_point(site.coord)
	if document.set_label_offset(site.id, offset):
		_stroke_changed = true
		_selected_authoring_site_id = site.id
		queue_redraw()


func _apply_erase(position: Vector2) -> void:
	match erase_target:
		&"roads":
			_apply_edge(position, true, true)
		&"borders":
			_apply_edge(position, false, true)
		&"districts":
			_apply_district(position, true)
		&"settlement_footprint":
			_apply_settlement(position, true)
		&"label_override":
			var site_id: StringName = _site_at(position)
			if not site_id.is_empty() and document.label_offsets_by_site_id.erase(site_id):
				document.apply_label_offsets_to_region()
				_stroke_changed = true
				queue_redraw()


func _emit_site_selection(site: RegionSiteDefinition) -> void:
	if site == null:
		selection_changed.emit({"kind": "none"})
		return
	selection_changed.emit({
		"kind": "site",
		"site_id": String(site.id),
		"display_name": site.display_name,
		"site_type": String(site.site_type),
		"icon_id": String(site.icon_id),
		"coord": [site.coord.offset_col, site.coord.offset_row] if site.coord != null else [],
		"parent_settlement_id": String(site.parent_settlement_id),
	})


func _hex_selection_dictionary(coord: RegionHexCoord) -> Dictionary:
	var hex: RegionHexDefinition = document.region.hex_at_offset(coord.offset_col, coord.offset_row)
	var settlement: RegionSiteDefinition = document.settlement_at_offset(coord.offset_col, coord.offset_row)
	var district: RegionSiteDefinition = document.district_at_offset(coord.offset_col, coord.offset_row)
	return {
		"kind": "hex",
		"coord": [coord.offset_col, coord.offset_row],
		"terrain": String(hex.terrain_type) if hex != null else "",
		"playable": hex.playable if hex != null else false,
		"subregion": String(hex.subregion_id) if hex != null else "",
		"settlement_id": String(settlement.id) if settlement != null else "",
		"district_id": String(district.id) if district != null else "",
		"district_symbol": String(district.icon_id) if district != null else "",
	}


func _edge_selection_dictionary(edge: Dictionary) -> Dictionary:
	var owner: RegionHexCoord = edge.get("owner") as RegionHexCoord
	var neighbour: RegionHexCoord = edge.get("neighbour") as RegionHexCoord
	var edge_index: int = int(edge.get("edge_index", -1))
	var road_id: StringName = _edge_id_at(true, owner, neighbour, edge_index)
	var border_id: StringName = _edge_id_at(false, owner, neighbour, edge_index)
	var road_type: StringName = &""
	if not road_id.is_empty():
		var road_edge: RegionMapEdgeDefinition = document.region.road_edges_by_id.get(road_id) as RegionMapEdgeDefinition
		if road_edge != null:
			road_type = road_edge.style_id
	return {
		"kind": "edge",
		"owner": [owner.offset_col, owner.offset_row],
		"neighbour": [neighbour.offset_col, neighbour.offset_row] if neighbour != null else [],
		"edge_index": edge_index,
		"road_id": String(road_id),
		"road_type": String(road_type),
		"border_id": String(border_id),
	}


func _hex_at(position: Vector2) -> RegionHexCoord:
	if document == null or document.region == null:
		return null
	var best: RegionHexCoord
	var best_distance: float = INF
	var radius: float = _hex_radius()
	for hex: RegionHexDefinition in document.region.all_hexes():
		var distance: float = position.distance_to(_screen_point(hex.coord))
		if distance < radius * 0.92 and distance < best_distance:
			best = hex.coord.duplicate_coord()
			best_distance = distance
	return best


func _edge_at(position: Vector2) -> Dictionary:
	var coord: RegionHexCoord = _hex_at(position)
	if coord == null:
		return {}
	var polygon: PackedVector2Array = _hex_polygon(_screen_point(coord), _hex_radius())
	var threshold: float = maxf(7.0, _hex_radius() * 0.20)
	var best_index: int = -1
	var best_distance: float = INF
	for edge_index: int in range(6):
		var distance: float = _distance_to_segment(position, polygon[edge_index], polygon[(edge_index + 1) % 6])
		if distance < threshold and distance < best_distance:
			best_distance = distance
			best_index = edge_index
	if best_index < 0:
		return {}
	var neighbours: Array[RegionHexCoord] = coord.neighbours()
	var neighbour: RegionHexCoord = neighbours[NEIGHBOUR_INDEX_BY_EDGE[best_index]]
	if document.region.hex_at_offset(neighbour.offset_col, neighbour.offset_row) == null:
		neighbour = null
	return {"owner": coord, "neighbour": neighbour, "edge_index": best_index}


func _edge_id_at(is_road: bool, owner: RegionHexCoord, neighbour: RegionHexCoord, edge_index: int) -> StringName:
	var source: Dictionary = document.region.road_edges_by_id if is_road else document.region.border_edges_by_id
	var key: StringName = _canonical_edge_key(owner, neighbour, edge_index)
	for raw_edge: Variant in source.values():
		var edge: RegionMapEdgeDefinition = raw_edge as RegionMapEdgeDefinition
		if edge != null and edge.canonical_key() == key:
			return edge.id
	return &""


func _road_would_touch_stronghold(owner: RegionHexCoord, neighbour: RegionHexCoord) -> bool:
	var stronghold: RegionSiteDefinition = document.region.site(document.region.fifth_god_ruin_site_id)
	if stronghold == null or stronghold.coord == null or owner == null:
		return false
	if stronghold.coord.key() == owner.key():
		return true
	return neighbour != null and stronghold.coord.key() == neighbour.key()


func _canonical_edge_key(first: RegionHexCoord, second: RegionHexCoord, edge_index: int = -1) -> StringName:
	if first == null:
		return &""
	if second == null:
		return StringName("%s:e%d" % [String(first.key()), edge_index])
	var a: String = String(first.key())
	var b: String = String(second.key())
	if b < a:
		var swap: String = a
		a = b
		b = swap
	return StringName("%s|%s" % [a, b])


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment: Vector2 = finish - start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _store_camera() -> void:
	if document == null:
		return
	document.editor_metadata["camera_zoom"] = view_zoom()
	document.editor_metadata["camera_pan_x"] = view_pan().x
	document.editor_metadata["camera_pan_y"] = view_pan().y
