class_name StrongholdGridView
extends Control

const StrongholdDefinitionScript = preload("res://domain/stronghold/stronghold_definition.gd")
const StrongholdStateScript = preload("res://domain/stronghold/stronghold_state.gd")
const StrongholdPlotDefinitionScript = preload("res://domain/stronghold/stronghold_plot_definition.gd")
const StrongholdPlotStateScript = preload("res://domain/stronghold/stronghold_plot_state.gd")
const StrongholdFacilityPresentationDefinitionScript = preload("res://domain/stronghold/stronghold_facility_presentation_definition.gd")
const StrongholdFacilityStateScript = preload("res://domain/stronghold/stronghold_facility_state.gd")
const StrongholdProjectStateScript = preload("res://domain/stronghold/stronghold_project_state.gd")
const CONSTRUCTION_ICON: Texture2D = preload("res://presentation/campaign/icons/stronghold_construction.svg")


signal plot_selected(coord: Vector2i)
signal plot_hovered(coord: Vector2i)

const TILE_GAP: float = 7.0
const OUTER_MARGIN: float = 10.0
const FACILITY_ART_INSET: float = 4.0
const ORTHOGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]

var _definition: StrongholdDefinitionScript
var _state: StrongholdStateScript
var _connectivity: Dictionary = {}
var _facility_groups: Dictionary = {}
var _facility_textures: Dictionary = {}
var _available_plot_textures: Array[Texture2D] = []
var _build_preview: Dictionary = {}
var _selected_coord: Vector2i = Vector2i(-1, -1)
var _hovered_coord: Vector2i = Vector2i(-1, -1)
var _cell_size: float = 72.0
var _grid_origin: Vector2 = Vector2.ZERO
var _campaign_tick: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(560, 500)
	set_process(false)


func configure(
	definition: StrongholdDefinitionScript,
	state: StrongholdStateScript,
	connectivity: Dictionary,
	campaign_tick: int = 0
) -> void:
	_definition = definition
	_state = state
	_connectivity = connectivity.duplicate(true)
	_campaign_tick = maxi(0, campaign_tick)
	_load_available_plot_textures()
	_rebuild_facility_groups()
	_selected_coord = Vector2i(-1, -1)
	queue_redraw()


func set_build_preview(
	facility_definition_id: StringName,
	origin: Vector2i,
	footprint: Vector2i,
	valid: bool,
	message: String = ""
) -> void:
	var presentation: StrongholdFacilityPresentationDefinitionScript = (
		_definition.facility_presentation(facility_definition_id) if _definition != null else null
	)
	_build_preview = {
		"facility_definition_id": facility_definition_id,
		"origin": origin,
		"footprint": footprint,
		"valid": valid,
		"message": message,
		"presentation": presentation,
		"texture": _texture_for_presentation(presentation),
	}
	queue_redraw()


func clear_build_preview() -> void:
	_build_preview.clear()
	queue_redraw()


func build_preview_origin() -> Vector2i:
	return _build_preview.get("origin", Vector2i(-1, -1)) as Vector2i


func select_plot(coord: Vector2i, emit_signal: bool = false) -> void:
	if _definition == null or _definition.plot_at(coord) == null:
		return
	_selected_coord = _canonical_coord(coord)
	queue_redraw()
	if emit_signal:
		plot_selected.emit(_selected_coord)


func clear_selection() -> void:
	_selected_coord = Vector2i(-1, -1)
	queue_redraw()


func selected_coord() -> Vector2i:
	return _selected_coord


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _definition == null:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var raw_hovered: Vector2i = _coord_at_position(motion.position)
		var display_hovered: Vector2i = (
			raw_hovered
			if not _build_preview.is_empty()
			else _canonical_coord(raw_hovered)
		)
		if display_hovered != _hovered_coord:
			_hovered_coord = display_hovered
			plot_hovered.emit(raw_hovered)
			queue_redraw()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var clicked: Vector2i = _coord_at_position(mouse_event.position)
			if clicked.x < 0:
				return
			if not _build_preview.is_empty():
				plot_selected.emit(clicked)
			else:
				var plot_state: StrongholdPlotStateScript = _state.get_plot(clicked) if _state != null else null
				if plot_state != null and not plot_state.facility_id.is_empty():
					select_plot(clicked)
				else:
					clear_selection()
				plot_selected.emit(clicked)
			accept_event()


func _draw() -> void:
	if _definition == null or _state == null:
		return
	_update_layout()
	for plot_definition: StrongholdPlotDefinitionScript in _definition.all_plots():
		var plot_state: StrongholdPlotStateScript = _state.get_plot(plot_definition.coord)
		if plot_state == null or not plot_state.facility_id.is_empty():
			continue
		_draw_plot(plot_definition, plot_state)
	_draw_facilities()
	_draw_build_preview()


func _update_layout() -> void:
	var usable_width: float = maxf(1.0, size.x - OUTER_MARGIN * 2.0)
	var usable_height: float = maxf(1.0, size.y - OUTER_MARGIN * 2.0)
	_cell_size = floorf(minf(
		usable_width / float(_definition.width),
		usable_height / float(_definition.height)
	))
	_cell_size = clampf(_cell_size, 48.0, 118.0)
	var grid_size := Vector2(
		_cell_size * float(_definition.width),
		_cell_size * float(_definition.height)
	)
	_grid_origin = (size - grid_size) * 0.5


func _rebuild_facility_groups() -> void:
	_facility_groups.clear()
	if _state == null:
		return
	for plot_state: StrongholdPlotStateScript in _state.get_plots():
		if plot_state.facility_id.is_empty():
			continue
		var key: StringName = plot_state.facility_id
		var group: Dictionary = _facility_groups.get(key, {}) as Dictionary
		if group.is_empty():
			group = {
				"facility_id": key,
				"coords": [],
			}
		(group["coords"] as Array).append(plot_state.coord)
		_facility_groups[key] = group
	for raw_key: Variant in _facility_groups.keys():
		var key := StringName(raw_key)
		var group: Dictionary = _facility_groups[key] as Dictionary
		var coords: Array = group.get("coords", []) as Array
		if coords.is_empty():
			continue
		coords.sort_custom(
			func(a: Vector2i, b: Vector2i) -> bool:
				if a.y != b.y:
					return a.y < b.y
				return a.x < b.x
		)
		var minimum: Vector2i = coords[0] as Vector2i
		var maximum: Vector2i = coords[0] as Vector2i
		for raw_coord: Variant in coords:
			var coord: Vector2i = raw_coord as Vector2i
			minimum.x = mini(minimum.x, coord.x)
			minimum.y = mini(minimum.y, coord.y)
			maximum.x = maxi(maximum.x, coord.x)
			maximum.y = maxi(maximum.y, coord.y)
		group["origin"] = minimum
		group["maximum"] = maximum
		group["footprint"] = maximum - minimum + Vector2i.ONE
		var definition_id: StringName = _state.facility_definition_id(key)
		group["definition_id"] = definition_id
		group["facility_state"] = _state.get_facility(key)
		group["presentation"] = (
			_definition.facility_presentation(definition_id) if _definition != null else null
		)
		group["texture"] = _texture_for_presentation(group.get("presentation"))
		_facility_groups[key] = group


func _load_available_plot_textures() -> void:
	_available_plot_textures.clear()
	if _definition == null:
		return
	for art_path: String in _definition.available_plot_art_paths:
		if not ResourceLoader.exists(art_path):
			continue
		var texture := load(art_path) as Texture2D
		if texture != null:
			_available_plot_textures.append(texture)


func _available_texture_for_coord(coord: Vector2i) -> Texture2D:
	if _available_plot_textures.is_empty():
		return null
	var stable_key: int = abs((coord.x * 73856093) ^ (coord.y * 19349663) ^ String(_definition.id).hash())
	return _available_plot_textures[stable_key % _available_plot_textures.size()]


func _texture_for_presentation(raw_presentation: Variant) -> Texture2D:
	var presentation: StrongholdFacilityPresentationDefinitionScript = (
		raw_presentation as StrongholdFacilityPresentationDefinitionScript
	)
	if presentation == null or presentation.art_path.strip_edges().is_empty():
		return null
	if _facility_textures.has(presentation.art_path):
		return _facility_textures[presentation.art_path] as Texture2D
	var texture: Texture2D = null
	if ResourceLoader.exists(presentation.art_path):
		texture = load(presentation.art_path) as Texture2D
	_facility_textures[presentation.art_path] = texture
	return texture


func _draw_connectors() -> void:
	var raw_connectors: Variant = _connectivity.get("connectors", [])
	if not raw_connectors is Array:
		return
	for raw_connector: Variant in raw_connectors as Array:
		if not raw_connector is Dictionary:
			continue
		var connector: Dictionary = raw_connector as Dictionary
		var a: Vector2i = _coord_from_key(StringName(connector.get("a", "")))
		var b: Vector2i = _coord_from_key(StringName(connector.get("b", "")))
		if a.x < 0 or b.x < 0 or _is_internal_facility_edge(a, b):
			continue
		var from: Vector2 = _cell_rect(a).get_center()
		var to: Vector2 = _cell_rect(b).get_center()
		draw_line(from, to, Color("2c332f"), 18.0, true)
		draw_line(from, to, Color("7a6c52"), 7.0, true)


func _is_internal_facility_edge(a: Vector2i, b: Vector2i) -> bool:
	if _state == null:
		return false
	var a_state: StrongholdPlotStateScript = _state.get_plot(a)
	var b_state: StrongholdPlotStateScript = _state.get_plot(b)
	return (
		a_state != null
		and b_state != null
		and not a_state.facility_id.is_empty()
		and a_state.facility_id == b_state.facility_id
	)


func _draw_plot(
	plot_definition: StrongholdPlotDefinitionScript,
	plot_state: StrongholdPlotStateScript
) -> void:
	var rect: Rect2 = _cell_rect(plot_definition.coord).grow(-TILE_GAP * 0.5)
	var fill: Color = _fill_color(plot_state.current_state)
	var border: Color = _border_color(plot_state.current_state)
	if plot_state.current_state == StrongholdPlotDefinitionScript.AVAILABLE:
		var texture: Texture2D = _available_texture_for_coord(plot_definition.coord)
		if texture != null:
			draw_style_box(_tile_style(fill, border), rect)
			draw_texture_rect(texture, rect.grow(-3.0), false, Color.WHITE)
		else:
			draw_style_box(_tile_style(fill, border), rect)
	elif plot_state.current_state == StrongholdPlotDefinitionScript.PERMANENT_BLOCK:
		draw_rect(rect, fill, true)
		_draw_block_hatching(rect)
	else:
		draw_style_box(_tile_style(fill, border), rect)
	if plot_definition.coord == _hovered_coord:
		draw_rect(rect.grow(1.0), Color(0.78, 0.84, 0.74, 0.19), true)
	if plot_definition.coord == _selected_coord:
		draw_rect(rect.grow(2.0), Color("f0d889"), false, 3.0)
	elif plot_definition.coord == _hovered_coord:
		draw_rect(rect.grow(1.0), Color("d9d2bd"), false, 2.0)
	if plot_state.current_state != StrongholdPlotDefinitionScript.AVAILABLE:
		var symbol: String = _symbol_for_state(plot_state.current_state)
		var font: Font = ThemeDB.fallback_font
		var font_size: int = maxi(16, int(_cell_size * 0.28))
		var text_width: float = font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(
			font,
			Vector2(rect.get_center().x - text_width * 0.5, rect.get_center().y + font_size * 0.35),
			symbol,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color("ede6d5")
		)


func _draw_facilities() -> void:
	var groups: Array = _facility_groups.values()
	groups.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_origin: Vector2i = a.get("origin", Vector2i.ZERO)
			var b_origin: Vector2i = b.get("origin", Vector2i.ZERO)
			if a_origin.y != b_origin.y:
				return a_origin.y < b_origin.y
			return a_origin.x < b_origin.x
	)
	for raw_group: Variant in groups:
		if raw_group is Dictionary:
			_draw_facility(raw_group as Dictionary)


func _draw_facility(group: Dictionary) -> void:
	var facility_id := StringName(group.get("facility_id", ""))
	var origin: Vector2i = group.get("origin", Vector2i(-1, -1))
	if facility_id.is_empty() or origin.x < 0:
		return
	var origin_state: StrongholdPlotStateScript = _state.get_plot(origin)
	if origin_state == null:
		return
	var rect: Rect2 = _facility_rect(group)
	var presentation: StrongholdFacilityPresentationDefinitionScript = (
		group.get("presentation") as StrongholdFacilityPresentationDefinitionScript
	)
	var accent: Color = _border_color(origin_state.current_state)
	if presentation != null and not presentation.accent_color.is_empty():
		accent = Color(presentation.accent_color)
	var fill: Color = _fill_color(origin_state.current_state).darkened(0.08)
	draw_style_box(_facility_style(fill, accent), rect)
	var texture: Texture2D = group.get("texture") as Texture2D
	var art_rect: Rect2 = rect.grow(-FACILITY_ART_INSET)
	if texture != null:
		draw_texture_rect(texture, art_rect, false, Color.WHITE)
	else:
		_draw_facility_fallback(rect, presentation, accent)
	_draw_facility_condition_overlay(group, rect)
	var selected: bool = origin == _selected_coord
	var hovered: bool = origin == _hovered_coord
	if selected:
		draw_rect(rect.grow(3.0), Color("f0d889"), false, 4.0)
	elif hovered:
		draw_rect(rect.grow(2.0), Color("d9d2bd"), false, 3.0)


func _draw_facility_fallback(
	rect: Rect2,
	presentation: StrongholdFacilityPresentationDefinitionScript,
	accent: Color
) -> void:
	var inner: Rect2 = rect.grow(-8.0)
	draw_rect(inner, Color("242927"), true)
	for index: int in range(5):
		var inset: float = 10.0 + float(index) * 8.0
		draw_rect(inner.grow(-inset), accent.darkened(0.25 + index * 0.08), false, 2.0)
	var symbol: String = "?"
	if presentation != null and not presentation.fallback_symbol.is_empty():
		symbol = presentation.fallback_symbol
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(18, int(minf(rect.size.x, rect.size.y) * 0.24))
	var width: float = font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		font,
		Vector2(rect.get_center().x - width * 0.5, rect.get_center().y + font_size * 0.32),
		symbol,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		accent.lightened(0.25)
	)


func _draw_facility_condition_overlay(group: Dictionary, rect: Rect2) -> void:
	var coords: Array = group.get("coords", []) as Array
	var damaged: bool = false
	var ruined: bool = false
	for raw_coord: Variant in coords:
		var plot_state: StrongholdPlotStateScript = _state.get_plot(raw_coord as Vector2i)
		if plot_state == null:
			continue
		if plot_state.damage_state == StrongholdPlotStateScript.DAMAGE_DAMAGED:
			damaged = true
		elif plot_state.damage_state == StrongholdPlotStateScript.DAMAGE_RUINED:
			ruined = true
	if ruined:
		draw_rect(rect.grow(-4.0), Color(0.12, 0.08, 0.08, 0.58), true)
	elif damaged:
		draw_rect(rect.grow(-4.0), Color(0.35, 0.14, 0.10, 0.26), true)
	var facility_state: StrongholdFacilityStateScript = group.get("facility_state") as StrongholdFacilityStateScript
	var project: StrongholdProjectStateScript = (
		_state.project_for_facility(facility_state.instance_id)
		if facility_state != null
		else null
	)
	if project == null:
		return
	_draw_active_project_overlay(project, rect)


func _draw_active_project_overlay(project: StrongholdProjectStateScript, rect: Rect2) -> void:
	var inner: Rect2 = rect.grow(-6.0)
	var shortest_side: float = minf(inner.size.x, inner.size.y)
	var icon_size: float = clampf(shortest_side * 0.38, 34.0, 76.0)
	var icon_rect := Rect2(
		inner.get_center() - Vector2.ONE * icon_size * 0.5,
		Vector2.ONE * icon_size
	)
	var icon_backing: Rect2 = icon_rect.grow(9.0)
	draw_style_box(_project_badge_style(Color(0.05, 0.06, 0.06, 0.82), Color("c5a35b")), icon_backing)
	if CONSTRUCTION_ICON != null:
		draw_texture_rect(CONSTRUCTION_ICON, icon_rect, false, Color.WHITE)

	var remaining_days: int = maxi(
		1,
		ceili(float(project.remaining_minutes(_campaign_tick)) / 1440.0)
	)
	var day_word: String = "DAY" if remaining_days == 1 else "DAYS"
	var badge_width: float = clampf(inner.size.x * 0.30, 48.0, 86.0)
	var badge_height: float = clampf(inner.size.y * 0.31, 52.0, 82.0)
	var countdown_rect := Rect2(
		inner.end - Vector2(badge_width, badge_height),
		Vector2(badge_width, badge_height)
	)
	draw_style_box(_project_badge_style(Color(0.05, 0.06, 0.06, 0.90), Color("d0bd83")), countdown_rect)

	var font: Font = ThemeDB.fallback_font
	var number_font_size: int = clampi(int(badge_height * 0.52), 24, 46)
	var label_font_size: int = clampi(int(badge_height * 0.18), 9, 14)
	var number_text: String = str(remaining_days)
	var number_width: float = font.get_string_size(
		number_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		number_font_size
	).x
	draw_string(
		font,
		Vector2(
			countdown_rect.get_center().x - number_width * 0.5,
			countdown_rect.position.y + number_font_size * 0.92
		),
		number_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		number_font_size,
		Color("f4e3a2")
	)
	draw_string(
		font,
		Vector2(
			countdown_rect.position.x + 4.0,
			countdown_rect.end.y - 7.0
		),
		day_word,
		HORIZONTAL_ALIGNMENT_CENTER,
		countdown_rect.size.x - 8.0,
		label_font_size,
		Color("d8cfb5")
	)

	var progress_track := Rect2(
		Vector2(inner.position.x, inner.end.y - 6.0),
		Vector2(inner.size.x, 4.0)
	)
	draw_rect(progress_track, Color(0.05, 0.06, 0.06, 0.78), true)
	var progress_fill := progress_track
	progress_fill.size.x *= project.progress(_campaign_tick)
	draw_rect(progress_fill, Color("c5a35b"), true)


func _project_badge_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _draw_facility_external_connections(group: Dictionary, accent: Color) -> void:
	var coords: Array = group.get("coords", []) as Array
	var facility_id := StringName(group.get("facility_id", ""))
	var connected: Dictionary = _connectivity.get("connected", {}) as Dictionary
	for raw_coord: Variant in coords:
		var coord: Vector2i = raw_coord as Vector2i
		if not connected.has(StrongholdDefinitionScript.coord_key(coord)):
			continue
		for direction: Vector2i in ORTHOGONAL_DIRECTIONS:
			var neighbour_coord: Vector2i = coord + direction
			var neighbour: StrongholdPlotStateScript = _state.get_plot(neighbour_coord)
			if neighbour == null or neighbour.facility_id == facility_id:
				continue
			if not connected.has(neighbour.key()):
				continue
			var cell: Rect2 = _cell_rect(coord).grow(-TILE_GAP * 0.5)
			var point: Vector2 = cell.get_center()
			if direction == Vector2i.LEFT:
				point.x = cell.position.x
			elif direction == Vector2i.RIGHT:
				point.x = cell.end.x
			elif direction == Vector2i.UP:
				point.y = cell.position.y
			else:
				point.y = cell.end.y
			draw_circle(point, 5.0, Color("171a19"))
			draw_circle(point, 3.0, accent.lightened(0.18))


func _draw_build_preview() -> void:
	if _build_preview.is_empty():
		return
	var origin: Vector2i = _build_preview.get("origin", Vector2i(-1, -1))
	var footprint: Vector2i = _build_preview.get("footprint", Vector2i.ONE)
	if origin.x < 0 or footprint.x <= 0 or footprint.y <= 0:
		return
	var maximum: Vector2i = origin + footprint - Vector2i.ONE
	var first: Rect2 = _cell_rect(origin).grow(-TILE_GAP * 0.5)
	var last: Rect2 = _cell_rect(maximum).grow(-TILE_GAP * 0.5)
	var rect := Rect2(first.position, last.end - first.position)
	var valid: bool = bool(_build_preview.get("valid", false))
	var accent: Color = Color("7fb386") if valid else Color("c65f62")
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.16), true)
	var texture: Texture2D = _build_preview.get("texture") as Texture2D
	if texture != null:
		draw_texture_rect(texture, rect.grow(-5.0), false, Color(1.0, 1.0, 1.0, 0.58))
	draw_rect(rect.grow(2.0), accent, false, 4.0)
	var font: Font = ThemeDB.fallback_font
	var text: String = "VALID BUILD" if valid else "INVALID PLACEMENT"
	draw_string(
		font,
		rect.position + Vector2(10.0, 20.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(20.0, rect.size.x - 20.0),
		12,
		accent.lightened(0.25)
	)


func _facility_display_name(
	facility_id: StringName,
	presentation: StrongholdFacilityPresentationDefinitionScript
) -> String:
	if presentation != null and not presentation.display_name.strip_edges().is_empty():
		return presentation.display_name
	return String(facility_id).get_slice(".", String(facility_id).get_slice_count(".") - 1).replace("_", " ").capitalize()


func _facility_rect(group: Dictionary) -> Rect2:
	var origin: Vector2i = group.get("origin", Vector2i.ZERO)
	var maximum: Vector2i = group.get("maximum", origin)
	var first: Rect2 = _cell_rect(origin).grow(-TILE_GAP * 0.5)
	var last: Rect2 = _cell_rect(maximum).grow(-TILE_GAP * 0.5)
	return Rect2(first.position, last.end - first.position)


func _facility_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _tile_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _draw_block_hatching(rect: Rect2) -> void:
	var step: float = 12.0
	var x: float = rect.position.x - rect.size.y
	while x < rect.end.x:
		var from := Vector2(
			maxf(rect.position.x, x),
			rect.end.y - maxf(0.0, rect.position.x - x)
		)
		var to := Vector2(
			minf(rect.end.x, x + rect.size.y),
			rect.position.y + maxf(0.0, x + rect.size.y - rect.end.x)
		)
		draw_line(from, to, Color(0.32, 0.34, 0.35, 0.5), 2.0)
		x += step


func _cell_rect(coord: Vector2i) -> Rect2:
	return Rect2(
		_grid_origin + Vector2(float(coord.x), float(coord.y)) * _cell_size,
		Vector2.ONE * _cell_size
	)


func _coord_at_position(position: Vector2) -> Vector2i:
	_update_layout()
	var local: Vector2 = position - _grid_origin
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	var coord := Vector2i(floori(local.x / _cell_size), floori(local.y / _cell_size))
	if (
		coord.x < 0
		or coord.y < 0
		or coord.x >= _definition.width
		or coord.y >= _definition.height
	):
		return Vector2i(-1, -1)
	return coord if _definition.plot_at(coord) != null else Vector2i(-1, -1)


func _canonical_coord(coord: Vector2i) -> Vector2i:
	if coord.x < 0 or _state == null:
		return coord
	return _state.canonical_coord(coord)


func _fill_color(state: StringName) -> Color:
	match state:
		StrongholdPlotDefinitionScript.FIXED_HEART:
			return Color("4b243d")
		StrongholdPlotDefinitionScript.FIXED_ENTRANCE:
			return Color("46564e")
		StrongholdPlotDefinitionScript.SEALED:
			return Color("35383c")
		StrongholdPlotDefinitionScript.RUINED:
			return Color("5c463d")
		StrongholdPlotDefinitionScript.AVAILABLE:
			return Color("3b4842")
		StrongholdPlotDefinitionScript.OCCUPIED:
			return Color("4a4931")
		StrongholdPlotDefinitionScript.PERMANENT_BLOCK:
			return Color("171a1c")
	return Color("2c3032")


func _border_color(state: StringName) -> Color:
	match state:
		StrongholdPlotDefinitionScript.FIXED_HEART:
			return Color("c3a257")
		StrongholdPlotDefinitionScript.FIXED_ENTRANCE:
			return Color("8aa695")
		StrongholdPlotDefinitionScript.SEALED:
			return Color("70747a")
		StrongholdPlotDefinitionScript.RUINED:
			return Color("a8785e")
		StrongholdPlotDefinitionScript.AVAILABLE:
			return Color("74877d")
		StrongholdPlotDefinitionScript.OCCUPIED:
			return Color("b4a85f")
	return Color("3c4144")


func _symbol_for_state(state: StringName) -> String:
	match state:
		StrongholdPlotDefinitionScript.FIXED_HEART:
			return "H"
		StrongholdPlotDefinitionScript.FIXED_ENTRANCE:
			return "G"
		StrongholdPlotDefinitionScript.SEALED:
			return "S"
		StrongholdPlotDefinitionScript.RUINED:
			return "R"
		StrongholdPlotDefinitionScript.AVAILABLE:
			return "A"
		StrongholdPlotDefinitionScript.OCCUPIED:
			return "O"
		StrongholdPlotDefinitionScript.PERMANENT_BLOCK:
			return "#"
	return "?"


func _coord_from_key(raw_key: StringName) -> Vector2i:
	var pieces: PackedStringArray = String(raw_key).split(",")
	if pieces.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(pieces[0]), int(pieces[1]))
