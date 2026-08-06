class_name RegionAuthoringScreen
extends Control

signal close_requested

const AUTOSAVE_DELAY_SECONDS: float = 1.5
const TOP_SELECT: StringName = &"select"
const TOP_TERRAIN: StringName = &"terrain"
const TOP_ROADS: StringName = &"roads"
const TOP_BORDERS: StringName = &"borders"
const TOP_TOWNS: StringName = &"towns"
const TOP_DISTRICTS: StringName = &"districts"
const TOP_SITES: StringName = &"sites"
const TOP_LABELS: StringName = &"labels"
const TOP_ERASER: StringName = &"eraser"

var document: RegionAuthoringDocument
var _map_view: AuthoringRegionMapView
var _context_content: VBoxContainer
var _context_title: Label
var _tool_buttons: Dictionary = {}
var _tool_button_group: ButtonGroup
var _active_top_tool: StringName = TOP_SELECT
var _settlement_option: OptionButton
var _site_option: OptionButton
var _site_option_include_settlements: bool = false
var _inspector_title: Label
var _inspector_body: RichTextLabel
var _status_label: Label
var _validation_list: ItemList
var _validation_messages: Array[Dictionary] = []
var _layer_checks: Dictionary = {}
var _save_state_label: Label
var _save_path_label: Label
var _working_path: String = RegionAuthoringSerializer.DEFAULT_WORKING_PATH
var _undo_stack: Array[String] = []
var _redo_stack: Array[String] = []
var _pending_edit_snapshot: String = ""
var _dirty: bool = false
var _autosave_remaining: float = -1.0
var _open_dialog: FileDialog
var _save_dialog: FileDialog
var _export_dialog: FileDialog
var _new_entity_dialog: ConfirmationDialog
var _entity_kind_option: OptionButton
var _entity_id_edit: LineEdit
var _entity_name_edit: LineEdit
var _recover_dialog: ConfirmationDialog
var _pending_recovery_path: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_load_initial_document()
	set_process(true)


func _process(delta: float) -> void:
	if _autosave_remaining < 0.0:
		return
	_autosave_remaining -= delta
	if _autosave_remaining <= 0.0:
		_autosave_remaining = -1.0
		_autosave()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.ctrl_pressed:
		match key_event.keycode:
			KEY_S:
				_save_working()
				get_viewport().set_input_as_handled()
			KEY_Z:
				_undo()
				get_viewport().set_input_as_handled()
			KEY_Y:
				_redo()
				get_viewport().set_input_as_handled()
		return
	match key_event.keycode:
		KEY_S:
			_select_top_tool(TOP_SELECT)
		KEY_T:
			_select_top_tool(TOP_TERRAIN)
		KEY_R:
			_select_top_tool(TOP_ROADS)
		KEY_B:
			_select_top_tool(TOP_BORDERS)
		KEY_C:
			_select_top_tool(TOP_TOWNS)
		KEY_D:
			_select_top_tool(TOP_DISTRICTS)
		KEY_P:
			_select_top_tool(TOP_SITES)
		KEY_L:
			_select_top_tool(TOP_LABELS)
		KEY_E:
			_select_top_tool(TOP_ERASER)
		KEY_ESCAPE:
			_select_top_tool(TOP_SELECT)
		_:
			return
	get_viewport().set_input_as_handled()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("111416")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	background.add_child(root)

	root.add_child(_build_command_bar())
	root.add_child(_build_tool_ribbon())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)
	body.add_child(_build_context_panel())
	_map_view = AuthoringRegionMapView.new()
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.custom_minimum_size = Vector2(400, 360)
	_map_view.selection_changed.connect(_on_selection_changed)
	_map_view.edit_started.connect(_on_map_edit_started)
	_map_view.edit_finished.connect(_on_map_edit_finished)
	_map_view.status_changed.connect(_show_status)
	body.add_child(_map_view)
	body.add_child(_build_right_panel())
	root.add_child(_build_status_bar())
	_build_dialogs()
	_select_top_tool(TOP_SELECT)


func _build_command_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 50)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 5)
	panel.add_child(bar)
	var title := Label.new()
	title.text = "  REGION AUTHORING"
	title.custom_minimum_size = Vector2(170, 0)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("d0ad60"))
	bar.add_child(title)
	bar.add_child(_build_file_menu())
	bar.add_child(_compact_toolbar_button("SAVE", _save_working, 82))
	bar.add_child(VSeparator.new())
	bar.add_child(_compact_toolbar_button("UNDO", _undo, 74))
	bar.add_child(_compact_toolbar_button("REDO", _redo, 74))
	bar.add_child(VSeparator.new())
	bar.add_child(_compact_toolbar_button("VALIDATE", _validate_document, 92))
	bar.add_child(_build_export_menu())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_save_state_label = Label.new()
	_save_state_label.text = "NOT SAVED"
	_save_state_label.custom_minimum_size = Vector2(132, 0)
	_save_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_state_label.add_theme_color_override("font_color", Color("e3c96a"))
	bar.add_child(_save_state_label)
	bar.add_child(_compact_toolbar_button("CLOSE", _request_close, 76))
	return panel


func _build_file_menu() -> MenuButton:
	var menu := MenuButton.new()
	menu.text = "FILE"
	menu.custom_minimum_size = Vector2(76, 38)
	menu.tooltip_text = "New, open, save as, or open the save folder."
	var popup := menu.get_popup()
	popup.add_item("New from Runtime", 0)
	popup.add_item("Open Authoring File...", 1)
	popup.add_separator()
	popup.add_item("Save As...", 2)
	popup.add_item("Open Save Folder", 3)
	popup.id_pressed.connect(_on_file_menu_pressed)
	return menu


func _on_file_menu_pressed(item_id: int) -> void:
	match item_id:
		0:
			_new_from_runtime()
		1:
			_show_open_dialog()
		2:
			_show_save_dialog()
		3:
			_open_save_folder()


func _build_export_menu() -> MenuButton:
	var menu := MenuButton.new()
	menu.text = "EXPORT"
	menu.custom_minimum_size = Vector2(88, 38)
	menu.tooltip_text = "Export runtime data, an authoring ZIP, or a preview image."
	var popup := menu.get_popup()
	popup.add_item("Runtime Data", 0)
	popup.add_item("Authoring ZIP...", 1)
	popup.add_item("Preview PNG", 2)
	popup.id_pressed.connect(_on_export_menu_pressed)
	return menu


func _on_export_menu_pressed(item_id: int) -> void:
	match item_id:
		0:
			_export_runtime_data()
		1:
			_show_export_dialog()
		2:
			_export_preview_only()


func _build_tool_ribbon() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 66)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	_tool_button_group = ButtonGroup.new()
	_tool_button_group.allow_unpress = false
	for entry: Array in [
		["SELECT", "S", TOP_SELECT],
		["TERRAIN", "T", TOP_TERRAIN],
		["ROADS", "R", TOP_ROADS],
		["BORDERS", "B", TOP_BORDERS],
		["TOWNS", "C", TOP_TOWNS],
		["DISTRICTS", "D", TOP_DISTRICTS],
		["SITES", "P", TOP_SITES],
		["LABELS", "L", TOP_LABELS],
		["ERASER", "E", TOP_ERASER],
	]:
		var tool_id := StringName(entry[2])
		var button := Button.new()
		button.text = "%s\n[%s]" % [String(entry[0]), String(entry[1])]
		button.tooltip_text = "%s tool (%s)" % [String(entry[0]).capitalize(), String(entry[1])]
		button.toggle_mode = true
		button.button_group = _tool_button_group
		button.custom_minimum_size = Vector2(92, 54)
		button.pressed.connect(_select_top_tool.bind(tool_id))
		_tool_buttons[tool_id] = button
		row.add_child(button)
	return panel


func _build_context_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(204, 0)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)
	_context_title = Label.new()
	_context_title.text = "SELECT"
	_context_title.add_theme_font_size_override("font_size", 19)
	_context_title.add_theme_color_override("font_color", Color("d0ad60"))
	_context_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_context_title)
	root.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_context_content = VBoxContainer.new()
	_context_content.custom_minimum_size = Vector2(188, 0)
	_context_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_context_content)
	return panel


func _build_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(356, 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	_inspector_title = Label.new()
	_inspector_title.text = "PROPERTIES"
	_inspector_title.add_theme_font_size_override("font_size", 20)
	content.add_child(_inspector_title)
	_inspector_body = RichTextLabel.new()
	_inspector_body.bbcode_enabled = true
	_inspector_body.fit_content = false
	_inspector_body.custom_minimum_size = Vector2(352, 190)
	content.add_child(_inspector_body)

	content.add_child(HSeparator.new())
	content.add_child(_section_label("LAYERS"))
	var layer_grid := GridContainer.new()
	layer_grid.columns = 1
	for layer_entry: Array in [
		["Terrain", "terrain", true],
		["Terrain Detail", "terrain_symbols", true],
		["Hex Grid", "hex_outlines", true],
		["Coordinates", "coordinates", false],
		["Roads", "roads", true],
		["Borders", "borders", true],
		["Town Footprints", "settlement_footprints", true],
		["Sites", "sites", true],
		["Labels", "labels", true],
	]:
		var check := CheckBox.new()
		check.text = String(layer_entry[0])
		check.button_pressed = bool(layer_entry[2])
		var layer_id: StringName = StringName(layer_entry[1])
		check.toggled.connect(_on_layer_toggled_from_signal.bind(layer_id))
		_layer_checks[layer_id] = check
		layer_grid.add_child(check)
	content.add_child(layer_grid)

	content.add_child(HSeparator.new())
	content.add_child(_section_label("SAVE"))
	_save_path_label = Label.new()
	_save_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_path_label.text = "No working file selected."
	_save_path_label.tooltip_text = "The current editable authoring file."
	content.add_child(_save_path_label)
	content.add_child(_small_button("SAVE PROJECT NOW", _save_working))
	content.add_child(_small_button("OPEN SAVE FOLDER", _open_save_folder))
	content.add_child(_small_button("FIT REGION TO VIEW", func() -> void: _map_view.fit_region()))

	content.add_child(HSeparator.new())
	var validation_title := Label.new()
	validation_title.text = "VALIDATION"
	validation_title.add_theme_font_size_override("font_size", 18)
	content.add_child(validation_title)
	_validation_list = ItemList.new()
	_validation_list.custom_minimum_size = Vector2(352, 240)
	_validation_list.item_activated.connect(_on_validation_item_activated)
	content.add_child(_validation_list)
	return panel


func _build_status_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 32)
	_status_label = Label.new()
	_status_label.text = "Select a tool above. Left-click edits; right-click removes; middle-drag pans; wheel zooms."
	panel.add_child(_status_label)
	return panel


func _select_top_tool(tool_id: StringName) -> void:
	_active_top_tool = tool_id
	var button: Button = _tool_buttons.get(tool_id) as Button
	if button != null:
		button.set_pressed_no_signal(true)
	_rebuild_context_panel()


func _rebuild_context_panel() -> void:
	if _context_content == null or _map_view == null:
		return
	for child: Node in _context_content.get_children():
		_context_content.remove_child(child)
		child.queue_free()
	_settlement_option = null
	_site_option = null
	_site_option_include_settlements = false
	_map_view.primary_remove_mode = false
	_context_title.text = String(_active_top_tool).to_upper()
	match _active_top_tool:
		TOP_SELECT:
			_build_select_context()
		TOP_TERRAIN:
			_build_terrain_context()
		TOP_ROADS:
			_build_roads_context()
		TOP_BORDERS:
			_build_borders_context()
		TOP_TOWNS:
			_build_towns_context()
		TOP_DISTRICTS:
			_build_districts_context()
		TOP_SITES:
			_build_sites_context()
		TOP_LABELS:
			_build_labels_context()
		TOP_ERASER:
			_build_eraser_context()
	_refresh_entity_options()


func _build_select_context() -> void:
	_map_view.set_active_tool(AuthoringRegionMapView.TOOL_SELECT)
	_context_content.add_child(_help_label("Click a hex, road edge, town, district or site to inspect it.\n\nCtrl+Z / Ctrl+Y: Undo / Redo\nMiddle-drag: Pan\nMouse wheel: Zoom"))
	_context_content.add_child(_small_button("FIT WHOLE REGION", func() -> void: _map_view.fit_region()))


func _build_terrain_context() -> void:
	_map_view.set_active_tool(AuthoringRegionMapView.TOOL_TERRAIN)
	_context_content.add_child(_section_label("TERRAIN BRUSH"))
	var grid := GridContainer.new()
	grid.columns = 2
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for terrain: StringName in RegionTerrainType.ALL:
		var button := _context_toggle_button(String(terrain).capitalize(), group, terrain == _map_view.active_terrain)
		button.pressed.connect(_set_active_terrain.bind(terrain))
		grid.add_child(button)
	var outside_button := _context_toggle_button("Outside Region", group, _map_view.active_terrain == &"outside_region")
	outside_button.pressed.connect(_set_active_terrain.bind(&"outside_region"))
	grid.add_child(outside_button)
	_context_content.add_child(grid)
	_context_content.add_child(_help_label("Left-click or drag to paint. Ctrl-click copies terrain. Right-click restores the fallback terrain."))


func _build_roads_context() -> void:
	_map_view.set_active_tool(AuthoringRegionMapView.TOOL_ROAD)
	_context_content.add_child(_section_label("ROAD TYPE"))
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for entry: Array in [
		["Primary Road", RegionRoadType.PRIMARY_ROAD],
		["Local Road", RegionRoadType.LOCAL_ROAD],
		["Forest Track", RegionRoadType.FOREST_TRACK],
	]:
		var road_type := StringName(entry[1])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		var preview := RoadStylePreview.new()
		preview.road_type = road_type
		row.add_child(preview)
		var button := _context_toggle_button(String(entry[0]), group, road_type == _map_view.active_road_type)
		button.custom_minimum_size = Vector2(112, 38)
		button.pressed.connect(_set_active_road_type.bind(road_type))
		row.add_child(button)
		_context_content.add_child(row)
	_context_content.add_child(_section_label("MODE"))
	_context_content.add_child(_mode_buttons(
		["DRAW", "REMOVE"],
		func(index: int) -> void: _map_view.primary_remove_mode = index == 1,
		1 if _map_view.primary_remove_mode else 0
	))
	_context_content.add_child(_help_label("Click or drag across shared hex edges. Primary roads are broad and paved, local roads are compacted earth, and forest tracks use two wheel ruts. Right-click always removes."))



func _set_active_terrain(terrain: StringName) -> void:
	_map_view.active_terrain = terrain


func _set_active_road_type(road_type: StringName) -> void:
	_map_view.active_road_type = RegionRoadType.normalize(road_type)


func _set_district_symbol(symbol_id: StringName) -> void:
	_map_view.active_district_symbol = symbol_id
	_map_view.district_operation = &"assign"


func _set_district_mode(index: int) -> void:
	_map_view.district_operation = &"clear" if index == 1 else &"assign"
	_map_view.set_active_tool(AuthoringRegionMapView.TOOL_DISTRICT)


func _set_erase_target(target: StringName) -> void:
	_map_view.erase_target = target


func _build_borders_context() -> void:
	_context_content.add_child(_section_label("EDIT"))
	var mode_group := ButtonGroup.new()
	mode_group.allow_unpress = false
	var editing_subregions: bool = _map_view.active_tool == AuthoringRegionMapView.TOOL_SUBREGION
	var border_button := _context_toggle_button("Draw Border", mode_group, not editing_subregions)
	var subregion_button := _context_toggle_button("Paint Subregion", mode_group, editing_subregions)
	border_button.pressed.connect(func() -> void:
		_map_view.set_active_tool(AuthoringRegionMapView.TOOL_BORDER)
		_map_view.primary_remove_mode = false
		_rebuild_context_panel()
	)
	subregion_button.pressed.connect(func() -> void:
		_map_view.set_active_tool(AuthoringRegionMapView.TOOL_SUBREGION)
		_rebuild_context_panel()
	)
	_context_content.add_child(border_button)
	_context_content.add_child(subregion_button)
	if _map_view.active_tool == AuthoringRegionMapView.TOOL_SUBREGION:
		_build_subregion_options()
	else:
		_map_view.set_active_tool(AuthoringRegionMapView.TOOL_BORDER)
		_context_content.add_child(_section_label("MODE"))
		_context_content.add_child(_mode_buttons(
			["DRAW", "REMOVE"],
			func(index: int) -> void: _map_view.primary_remove_mode = index == 1,
			0
		))
		_context_content.add_child(_help_label("Borders are independent from roads. Click or drag along hex edges."))


func _build_subregion_options() -> void:
	_context_content.add_child(_section_label("SUBREGION"))
	var option := OptionButton.new()
	var keys: Array = document.region.subregions_by_id.keys() if document != null else []
	keys.sort()
	for raw_id: Variant in keys:
		_add_option(option, String(document.region.subregions_by_id[raw_id]), StringName(raw_id))
	_select_option_by_metadata_no_signal(option, _map_view.active_subregion_id)
	option.item_selected.connect(func(index: int) -> void:
		_map_view.active_subregion_id = StringName(option.get_item_metadata(index))
	)
	_context_content.add_child(option)
	_context_content.add_child(_help_label("Paint the subregion held by each hex. This does not create or remove border edges."))


func _build_towns_context() -> void:
	_context_content.add_child(_section_label("ACTIVE TOWN"))
	_settlement_option = OptionButton.new()
	_settlement_option.item_selected.connect(_on_settlement_selected)
	_context_content.add_child(_settlement_option)
	var entity_row := HBoxContainer.new()
	entity_row.add_child(_small_button("NEW TOWN", _show_new_settlement_dialog))
	entity_row.add_child(_small_button("DELETE", _delete_selected_entity))
	_context_content.add_child(entity_row)
	_context_content.add_child(_section_label("EDIT"))
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for entry: Array in [
		["Select", &"select"],
		["Add Hex", &"add"],
		["Remove Hex", &"remove"],
		["Set Centre", &"set_anchor"],
		["Move Label", &"move_label"],
	]:
		var operation := StringName(entry[1])
		var button := _context_toggle_button(String(entry[0]), group, operation == &"select")
		button.pressed.connect(_set_town_operation.bind(operation))
		_context_content.add_child(button)
	_set_town_operation(&"select")
	_context_content.add_child(_help_label("Choose a town, then add or remove occupied hexes. Set Centre moves its anchor without changing the footprint."))


func _set_town_operation(operation: StringName) -> void:
	_map_view.primary_remove_mode = false
	match operation:
		&"add":
			_map_view.set_active_tool(AuthoringRegionMapView.TOOL_SETTLEMENT)
			_map_view.settlement_operation = &"add"
		&"remove":
			_map_view.set_active_tool(AuthoringRegionMapView.TOOL_SETTLEMENT)
			_map_view.settlement_operation = &"remove"
		&"set_anchor":
			_map_view.set_active_tool(AuthoringRegionMapView.TOOL_SETTLEMENT)
			_map_view.settlement_operation = &"set_anchor"
		&"move_label":
			_map_view.set_active_tool(AuthoringRegionMapView.TOOL_LABEL)
			_map_view.active_site_id = _map_view.active_settlement_id
		_:
			_map_view.set_active_tool(AuthoringRegionMapView.TOOL_SELECT)


func _build_districts_context() -> void:
	_map_view.set_active_tool(AuthoringRegionMapView.TOOL_DISTRICT)
	_context_content.add_child(_section_label("ACTIVE TOWN"))
	_settlement_option = OptionButton.new()
	_settlement_option.item_selected.connect(_on_settlement_selected)
	_context_content.add_child(_settlement_option)
	_context_content.add_child(_section_label("DISTRICT SYMBOL"))
	var grid := GridContainer.new()
	grid.columns = 2
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for symbol_id: StringName in RegionSymbolCatalogue.district_symbols():
		var button := _context_toggle_button(RegionSymbolCatalogue.display_name(symbol_id), group, symbol_id == _map_view.active_district_symbol)
		button.tooltip_text = RegionSymbolCatalogue.display_name(symbol_id)
		button.pressed.connect(_set_district_symbol.bind(symbol_id))
		grid.add_child(button)
	_context_content.add_child(grid)
	_context_content.add_child(_section_label("MODE"))
	_context_content.add_child(_mode_buttons(
		["ASSIGN", "CLEAR"],
		_set_district_mode,
		1 if _map_view.district_operation == &"clear" else 0
	))
	_context_content.add_child(_help_label("Click an occupied town hex to assign its exact symbol. Clear mode and right-click remove it."))


func _build_sites_context() -> void:
	_context_content.add_child(_section_label("ACTIVE SITE"))
	_site_option = OptionButton.new()
	_site_option.item_selected.connect(_on_site_selected)
	_context_content.add_child(_site_option)
	var site_row := HBoxContainer.new()
	site_row.add_child(_small_button("NEW SITE", _show_new_site_dialog))
	site_row.add_child(_small_button("DELETE", _delete_selected_entity))
	_context_content.add_child(site_row)
	_context_content.add_child(_section_label("EDIT"))
	var site_group := ButtonGroup.new()
	site_group.allow_unpress = false
	var select_button := _context_toggle_button("Select", site_group, true)
	var move_button := _context_toggle_button("Move / Place", site_group, false)
	select_button.pressed.connect(func() -> void: _map_view.set_active_tool(AuthoringRegionMapView.TOOL_SELECT))
	move_button.pressed.connect(func() -> void: _map_view.set_active_tool(AuthoringRegionMapView.TOOL_SITE))
	_context_content.add_child(select_button)
	_context_content.add_child(move_button)
	_map_view.set_active_tool(AuthoringRegionMapView.TOOL_SELECT)

	_context_content.add_child(_help_label("Sites are independent from towns. Public roads are authored only with the Roads tool."))


func _build_labels_context() -> void:
	_map_view.set_active_tool(AuthoringRegionMapView.TOOL_LABEL)
	_context_content.add_child(_section_label("LABEL OWNER"))
	_site_option_include_settlements = true
	_site_option = OptionButton.new()
	_site_option.item_selected.connect(_on_site_selected)
	_context_content.add_child(_site_option)
	_context_content.add_child(_small_button("MOVE LABEL", func() -> void: _map_view.set_active_tool(AuthoringRegionMapView.TOOL_LABEL)))
	_context_content.add_child(_small_button("RESET LABEL POSITION", _reset_active_label))
	_context_content.add_child(_help_label("Choose a site, then drag its label on the map. This does not change the site coordinate."))


func _build_eraser_context() -> void:
	_map_view.set_active_tool(AuthoringRegionMapView.TOOL_ERASE)
	_context_content.add_child(_section_label("ERASE LAYER"))
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for entry: Array in [
		["Roads", &"roads"],
		["Borders", &"borders"],
		["Districts", &"districts"],
		["Town Footprint", &"settlement_footprint"],
		["Label Override", &"label_override"],
	]:
		var target := StringName(entry[1])
		var button := _context_toggle_button(String(entry[0]), group, target == _map_view.erase_target)
		button.pressed.connect(_set_erase_target.bind(target))
		_context_content.add_child(button)
	_context_content.add_child(_help_label("Only the chosen layer is erased. Other overlapping map data is preserved."))


func _mode_buttons(labels: Array[String], callback: Callable, selected_index: int) -> Control:
	var row := HBoxContainer.new()
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for index: int in range(labels.size()):
		var button := _context_toggle_button(labels[index], group, index == selected_index)
		button.pressed.connect(callback.bind(index))
		row.add_child(button)
	return row


func _context_toggle_button(text_value: String, group: ButtonGroup, pressed: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = pressed
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(94, 38)
	return button


func _help_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("aeb8b9"))
	return label


func _show_new_entity_dialog_for(kind: StringName) -> void:
	_entity_id_edit.text = ""
	_entity_name_edit.text = ""
	_select_option_by_metadata_no_signal(_entity_kind_option, kind)
	_new_entity_dialog.popup_centered(Vector2i(520, 260))


func _show_new_settlement_dialog() -> void:
	_show_new_entity_dialog_for(&"settlement")


func _show_new_site_dialog() -> void:
	_show_new_entity_dialog_for(&"ruin")


func _reset_active_label() -> void:
	if document == null:
		return
	var site_id: StringName = _map_view.active_site_id
	if site_id.is_empty():
		site_id = _map_view.active_settlement_id
	if site_id.is_empty() or not document.label_offsets_by_site_id.has(site_id):
		_show_status("The selected object has no custom label position.")
		return
	var snapshot: String = document.snapshot_text()
	document.label_offsets_by_site_id.erase(site_id)
	document.apply_label_offsets_to_region()
	_undo_stack.append(snapshot)
	_redo_stack.clear()
	_mark_dirty()
	_map_view.refresh_from_document()
	_show_status("Label position reset.")


func _build_dialogs() -> void:
	_open_dialog = FileDialog.new()
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_open_dialog.add_filter("*.json", "Region Authoring Document")
	_open_dialog.file_selected.connect(_open_document_path)
	add_child(_open_dialog)
	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.add_filter("*.json", "Region Authoring Document")
	_save_dialog.file_selected.connect(_save_document_path)
	add_child(_save_dialog)
	_export_dialog = FileDialog.new()
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_dialog.add_filter("*.zip", "ZIP Archive")
	_export_dialog.file_selected.connect(_export_zip_to_path)
	add_child(_export_dialog)
	_build_new_entity_dialog()
	_build_recovery_dialog()


func _build_new_entity_dialog() -> void:
	_new_entity_dialog = ConfirmationDialog.new()
	_new_entity_dialog.title = "Create Region Entity"
	_new_entity_dialog.confirmed.connect(_create_entity_from_dialog)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(460, 170)
	_new_entity_dialog.add_child(content)
	_entity_kind_option = OptionButton.new()
	_add_option(_entity_kind_option, "Settlement", &"settlement")
	_add_option(_entity_kind_option, "Ancient Ruin", &"ruin")
	_add_option(_entity_kind_option, "Farm", &"farm")
	_add_option(_entity_kind_option, "Religious Site", &"religious")
	_add_option(_entity_kind_option, "Military Site", &"military")
	_add_option(_entity_kind_option, "Wilderness Site", &"wilderness")
	content.add_child(_entity_kind_option)
	_entity_id_edit = LineEdit.new()
	_entity_id_edit.placeholder_text = "Unique ID, e.g. site.settlement.example"
	content.add_child(_entity_id_edit)
	_entity_name_edit = LineEdit.new()
	_entity_name_edit.placeholder_text = "Display name"
	content.add_child(_entity_name_edit)
	var note := Label.new()
	note.text = "The new entity is created at the selected playable hex, or at the first playable hex when nothing is selected."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	add_child(_new_entity_dialog)


func _build_recovery_dialog() -> void:
	_recover_dialog = ConfirmationDialog.new()
	_recover_dialog.title = "Recover Region Autosave"
	_recover_dialog.dialog_text = "A recovery copy is newer than the saved region. Recover the newer edits?"
	_recover_dialog.get_ok_button().text = "RECOVER AUTOSAVE"
	_recover_dialog.confirmed.connect(_recover_autosave)
	_recover_dialog.canceled.connect(_load_saved_working_document)
	add_child(_recover_dialog)


func _load_initial_document() -> void:
	_working_path = RegionAuthoringSerializer.preferred_working_path()
	if not RegionAuthoringSerializer.document_exists(_working_path):
		var default_path: String = RegionAuthoringSerializer.DEFAULT_WORKING_PATH
		if RegionAuthoringSerializer.document_exists(default_path):
			_working_path = default_path
	_pending_recovery_path = RegionAuthoringSerializer.recovery_path_for(_working_path)
	_update_save_path_display()
	if RegionAuthoringSerializer.has_recoverable_autosave(_working_path):
		_recover_dialog.popup_centered(Vector2i(560, 210))
	elif RegionAuthoringSerializer.document_exists(_working_path):
		_load_saved_working_document()
	else:
		_working_path = RegionAuthoringSerializer.DEFAULT_WORKING_PATH
		_load_runtime_document()


func _load_saved_working_document() -> void:
	if not RegionAuthoringSerializer.document_exists(_working_path):
		_working_path = RegionAuthoringSerializer.DEFAULT_WORKING_PATH
		_load_runtime_document()
		return
	var result: OperationResult = RegionAuthoringSerializer.load_document(_working_path)
	if not result.success:
		_show_status("Saved authoring file could not be loaded: %s" % result.message)
		_update_save_state("LOAD FAILED", Color("e06b73"), result.message)
		_working_path = RegionAuthoringSerializer.DEFAULT_WORKING_PATH
		_load_runtime_document()
		return
	document = result.data as RegionAuthoringDocument
	RegionAuthoringSerializer.remember_last_document_path(_working_path)
	_undo_stack.clear()
	_redo_stack.clear()
	_apply_document(result.message, true)


func _load_runtime_document() -> void:
	var definition: RegionMapDefinition = LifeStarterRegionFactory.create_definition()
	if definition == null:
		_show_status("Could not load the current Life-region runtime definition.")
		_update_save_state("LOAD FAILED", Color("e06b73"), "Runtime region definition was unavailable.")
		return
	document = RegionAuthoringDocument.from_runtime(definition)
	_apply_document("Loaded the built-in Life-region data. Press SAVE PROJECT to create the working file.", false)


func _new_from_runtime() -> void:
	if _dirty and not _save_working():
		return
	_working_path = RegionAuthoringSerializer.DEFAULT_WORKING_PATH
	RegionAuthoringSerializer.remember_last_document_path(_working_path)
	_undo_stack.clear()
	_redo_stack.clear()
	_load_runtime_document()


func _recover_autosave() -> void:
	var recovery_path: String = _pending_recovery_path
	if recovery_path.is_empty():
		recovery_path = RegionAuthoringSerializer.recovery_path_for(_working_path)
	var result: OperationResult = RegionAuthoringSerializer.load_document(recovery_path)
	if not result.success:
		_show_status(result.message)
		_load_saved_working_document()
		return
	document = result.data as RegionAuthoringDocument
	_undo_stack.clear()
	_redo_stack.clear()
	_apply_document("Recovered newer edits. Press SAVE PROJECT to make them the main working file.", false)
	_update_save_state("RECOVERED", Color("e3c96a"), "Recovered edits are loaded but have not yet replaced the main working file.")


func _apply_document(message: String, mark_clean: bool = true) -> void:
	if document == null:
		return
	_map_view.configure_document(document)
	_rebuild_context_panel()
	_validate_document(false)
	_dirty = not mark_clean
	_autosave_remaining = AUTOSAVE_DELAY_SECONDS if _dirty else -1.0
	_update_save_path_display()
	if mark_clean:
		_update_save_state("SAVED", Color("9fc7a3"), RegionAuthoringSerializer.display_path(_working_path))
	else:
		_update_save_state("UNSAVED CHANGES", Color("e3c96a"), "Changes are not yet in the main working file.")
	_show_status(message)


func _refresh_entity_options() -> void:
	if document == null or document.region == null:
		return
	if _settlement_option != null:
		_settlement_option.clear()
		for site: RegionSiteDefinition in document.region.all_sites():
			if site.site_type == &"settlement":
				_add_option(_settlement_option, site.display_name, site.id)
		if not _select_option_by_metadata_no_signal(_settlement_option, _map_view.active_settlement_id) and _settlement_option.item_count > 0:
			_settlement_option.select(0)
			_map_view.active_settlement_id = StringName(_settlement_option.get_item_metadata(0))
	if _site_option != null:
		_site_option.clear()
		for site: RegionSiteDefinition in document.region.all_sites():
			if site.site_type == &"district":
				continue
			if site.site_type == &"settlement" and not _site_option_include_settlements:
				continue
			_add_option(_site_option, "%s — %s" % [site.display_name, String(site.site_type).capitalize()], site.id)
		if not _select_option_by_metadata_no_signal(_site_option, _map_view.active_site_id) and _site_option.item_count > 0:
			_site_option.select(0)
			_map_view.active_site_id = StringName(_site_option.get_item_metadata(0))

func _on_layer_toggled_from_signal(visible: bool, layer_id: StringName) -> void:
	_on_layer_toggled(layer_id, visible)


func _on_layer_toggled(layer_id: StringName, visible: bool) -> void:
	if _map_view == null:
		return
	if layer_id == &"coordinates":
		_map_view.show_coordinates = visible
		_map_view.queue_redraw()
	else:
		_map_view.set_layer_visible(layer_id, visible)


func _on_settlement_selected(index: int) -> void:
	if _settlement_option != null and index >= 0 and index < _settlement_option.item_count:
		_map_view.active_settlement_id = StringName(_settlement_option.get_item_metadata(index))
		_map_view.queue_redraw()


func _on_site_selected(index: int) -> void:
	if _site_option != null and index >= 0 and index < _site_option.item_count:
		_map_view.active_site_id = StringName(_site_option.get_item_metadata(index))
		_map_view.queue_redraw()




func _on_map_edit_started() -> void:
	_pending_edit_snapshot = document.snapshot_text() if document != null else ""


func _on_map_edit_finished(changed: bool) -> void:
	if not changed or _pending_edit_snapshot.is_empty():
		_pending_edit_snapshot = ""
		return
	_undo_stack.append(_pending_edit_snapshot)
	if _undo_stack.size() > 200:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_pending_edit_snapshot = ""
	_mark_dirty()
	_refresh_entity_options()
	_validate_document(false)


func _undo() -> void:
	if document == null or _undo_stack.is_empty():
		_show_status("Nothing to undo.")
		return
	_redo_stack.append(document.snapshot_text())
	var snapshot: String = _undo_stack.pop_back()
	if document.restore_snapshot(snapshot):
		_map_view.configure_document(document)
		_rebuild_context_panel()
		_mark_dirty()
		_validate_document(false)
		_show_status("Undo complete.")


func _redo() -> void:
	if document == null or _redo_stack.is_empty():
		_show_status("Nothing to redo.")
		return
	_undo_stack.append(document.snapshot_text())
	var snapshot: String = _redo_stack.pop_back()
	if document.restore_snapshot(snapshot):
		_map_view.configure_document(document)
		_rebuild_context_panel()
		_mark_dirty()
		_validate_document(false)
		_show_status("Redo complete.")


func _save_working() -> bool:
	if document == null:
		_show_status("No region document is loaded.")
		return false
	var result: OperationResult = RegionAuthoringSerializer.save_working_document(_working_path, document)
	if not result.success:
		_show_status(result.message)
		_update_save_state("SAVE FAILED", Color("e06b73"), result.message)
		return false
	_dirty = false
	_autosave_remaining = -1.0
	_update_save_path_display()
	_update_save_state("SAVED", Color("9fc7a3"), RegionAuthoringSerializer.display_path(_working_path))
	_show_status(result.message)
	return true


func _save_document_path(path: String) -> void:
	var target_path: String = path.strip_edges()
	if not target_path.to_lower().ends_with(".json"):
		target_path += ".json"
	var result: OperationResult = RegionAuthoringSerializer.save_working_document(target_path, document)
	if not result.success:
		_show_status(result.message)
		_update_save_state("SAVE FAILED", Color("e06b73"), result.message)
		return
	_working_path = target_path
	_dirty = false
	_autosave_remaining = -1.0
	_update_save_path_display()
	_update_save_state("SAVED", Color("9fc7a3"), RegionAuthoringSerializer.display_path(_working_path))
	_show_status(result.message)


func _open_document_path(path: String) -> void:
	if _dirty and not _save_working():
		_show_status("Open cancelled because the current document could not be saved.")
		return
	var result: OperationResult = RegionAuthoringSerializer.load_document(path)
	if not result.success:
		_show_status(result.message)
		_update_save_state("LOAD FAILED", Color("e06b73"), result.message)
		return
	document = result.data as RegionAuthoringDocument
	_working_path = path
	RegionAuthoringSerializer.remember_last_document_path(_working_path)
	_undo_stack.clear()
	_redo_stack.clear()
	_apply_document(result.message, true)


func _autosave() -> void:
	if not _dirty or document == null:
		return
	var result: OperationResult = RegionAuthoringSerializer.autosave(document, _working_path)
	if result.success:
		_update_save_state("RECOVERY SAVED", Color("8eb6d8"), result.message)
		_show_status(result.message + " Use SAVE PROJECT to update the main file.")
	else:
		_update_save_state("RECOVERY FAILED", Color("e06b73"), result.message)
		_show_status(result.message)


func _mark_dirty() -> void:
	_dirty = true
	_autosave_remaining = AUTOSAVE_DELAY_SECONDS
	_update_save_state("UNSAVED CHANGES", Color("e3c96a"), "A recovery copy will be written automatically; press SAVE PROJECT for the main file.")


func _update_save_path_display() -> void:
	var displayed_path: String = RegionAuthoringSerializer.display_path(_working_path)
	if _save_path_label != null:
		_save_path_label.text = "Current file:\n%s" % displayed_path
		_save_path_label.tooltip_text = displayed_path
	if _save_state_label != null:
		_save_state_label.tooltip_text = displayed_path


func _update_save_state(text_value: String, color: Color, tooltip: String) -> void:
	if _save_state_label == null:
		return
	_save_state_label.text = text_value
	_save_state_label.add_theme_color_override("font_color", color)
	_save_state_label.tooltip_text = tooltip


func _open_save_folder() -> void:
	var error: Error = RegionAuthoringSerializer.open_document_directory(_working_path)
	if error == OK:
		_show_status("Opened the Region Authoring save folder.")
	else:
		_show_status("Could not open the Region Authoring save folder.")


func _validate_document(show_message: bool = true) -> void:
	_validation_messages = RegionValidationService.validate(document)
	_validation_list.clear()
	for message: Dictionary in _validation_messages:
		var severity: String = String(message.get("severity", "information")).to_upper()
		var index: int = _validation_list.add_item("%s — %s" % [severity, String(message.get("message", ""))])
		_validation_list.set_item_metadata(index, message)
		match StringName(message.get("severity", "")):
			RegionValidationService.ERROR:
				_validation_list.set_item_custom_fg_color(index, Color("e06b73"))
			RegionValidationService.WARNING:
				_validation_list.set_item_custom_fg_color(index, Color("e3c96a"))
			_:
				_validation_list.set_item_custom_fg_color(index, Color("9fc7a3"))
	if show_message:
		var error_count: int = 0
		var warning_count: int = 0
		for message: Dictionary in _validation_messages:
			if StringName(message.get("severity", "")) == RegionValidationService.ERROR:
				error_count += 1
			elif StringName(message.get("severity", "")) == RegionValidationService.WARNING:
				warning_count += 1
		_show_status("Validation complete: %d errors, %d warnings." % [error_count, warning_count])


func _on_validation_item_activated(index: int) -> void:
	var message: Dictionary = _validation_list.get_item_metadata(index) as Dictionary
	var coord_value: Variant = message.get("coord", [])
	if coord_value is Array and (coord_value as Array).size() >= 2:
		var coord := RegionHexCoord.from_offset(int((coord_value as Array)[0]), int((coord_value as Array)[1]))
		_map_view.centre_on_coord(coord)
	_show_status(String(message.get("message", "")))


func _on_selection_changed(selection: Dictionary) -> void:
	var kind: String = String(selection.get("kind", "none"))
	_inspector_title.text = "PROPERTIES — %s" % kind.to_upper()
	_inspector_body.text = _selection_bbcode(selection)
	if kind == "site":
		var site_id := StringName(selection.get("site_id", ""))
		var site: RegionSiteDefinition = document.region.site(site_id) if document != null else null
		if site != null and site.site_type == &"settlement":
			_map_view.active_settlement_id = site_id
			if _settlement_option != null:
				_select_option_by_metadata(_settlement_option, site_id)
		else:
			_map_view.active_site_id = site_id
			if _site_option != null:
				_select_option_by_metadata(_site_option, site_id)


func _selection_bbcode(selection: Dictionary) -> String:
	var lines: PackedStringArray = []
	var keys: Array = selection.keys()
	keys.sort()
	for raw_key: Variant in keys:
		if String(raw_key) == "kind":
			continue
		lines.append("[b]%s[/b]: %s" % [String(raw_key).replace("_", " ").capitalize(), str(selection[raw_key])])
	if lines.is_empty():
		lines.append("Nothing selected.")
	return "\n".join(lines)


func _show_new_entity_dialog() -> void:
	_entity_id_edit.text = ""
	_entity_name_edit.text = ""
	_new_entity_dialog.popup_centered(Vector2i(520, 260))


func _create_entity_from_dialog() -> void:
	if document == null:
		return
	var id := StringName(_entity_id_edit.text.strip_edges())
	var display_name: String = _entity_name_edit.text.strip_edges()
	if id.is_empty() or display_name.is_empty():
		_show_status("New entities require a unique ID and display name.")
		return
	var kind := StringName(_entity_kind_option.get_item_metadata(_entity_kind_option.selected))
	var start_coord: RegionHexCoord = _map_view.selected_coord()
	if start_coord == null:
		start_coord = _first_playable_coord()
	var column: int = start_coord.offset_col if start_coord != null else 0
	var row: int = start_coord.offset_row if start_coord != null else 0
	var snapshot: String = document.snapshot_text()
	var changed: bool = false
	if kind == &"settlement":
		var start_hex: RegionHexDefinition = document.region.hex_at_offset(column, row)
		var subregion_id: StringName = start_hex.subregion_id if start_hex != null else _first_subregion_id()
		changed = document.create_settlement(id, display_name, column, row, subregion_id, RegionSymbolCatalogue.VILLAGE_CENTRE)
	else:
		var icon_id: StringName = _site_icon_for_type(kind)
		changed = document.create_site(id, display_name, kind, column, row, icon_id)
	if not changed:
		_show_status("The entity could not be created. Check its ID and starting hex.")
		return
	_undo_stack.append(snapshot)
	_redo_stack.clear()
	_mark_dirty()
	if kind == &"settlement":
		_map_view.active_settlement_id = id
	else:
		_map_view.active_site_id = id
	_rebuild_context_panel()
	_map_view.refresh_from_document()
	_show_status("Created %s. Use the contextual options on the left to edit it." % display_name)


func _delete_selected_entity() -> void:
	var site_id: StringName = _map_view.active_site_id
	if _active_top_tool in [TOP_TOWNS, TOP_DISTRICTS]:
		site_id = _map_view.active_settlement_id
	if site_id.is_empty() or document == null:
		_show_status("Choose a settlement or site before deleting it.")
		return
	var snapshot: String = document.snapshot_text()
	if not document.delete_site(site_id):
		_show_status("The selected entity could not be deleted.")
		return
	_undo_stack.append(snapshot)
	_redo_stack.clear()
	_mark_dirty()
	if site_id == _map_view.active_settlement_id:
		_map_view.active_settlement_id = &""
	if site_id == _map_view.active_site_id:
		_map_view.active_site_id = &""
	_rebuild_context_panel()
	_map_view.refresh_from_document()
	_validate_document(false)
	_show_status("Deleted %s." % site_id)


func _export_runtime_data() -> void:
	_validate_document(false)
	if RegionValidationService.has_errors(_validation_messages):
		_show_status("Runtime export blocked by validation errors.")
		return
	var output_directory: String = "user://region_authoring/exports/runtime_%s" % String(document.region.id).replace(".", "_")
	var result: OperationResult = RegionExportService.export_runtime_files(document, output_directory)
	_show_status(result.message)
	if result.success:
		OS.shell_open(ProjectSettings.globalize_path(output_directory))


func _export_zip_to_path(path: String) -> void:
	_validate_document(false)
	if RegionValidationService.has_errors(_validation_messages):
		_show_status("ZIP export blocked by validation errors.")
		return
	var preview_state: Dictionary = _map_view.prepare_clean_preview()
	await get_tree().process_frame
	var preview: Image = _capture_map_preview()
	_map_view.restore_preview_state(preview_state)
	var result: OperationResult = RegionExportService.export_bundle(document, preview, _validation_messages, path)
	_show_status(result.message)
	if result.success:
		OS.shell_open(ProjectSettings.globalize_path(String(result.data).get_base_dir()))


func _export_preview_only() -> void:
	var preview_state: Dictionary = _map_view.prepare_clean_preview()
	await get_tree().process_frame
	var preview: Image = _capture_map_preview()
	_map_view.restore_preview_state(preview_state)
	if preview == null or preview.is_empty():
		_show_status("Could not capture the map preview.")
		return
	var directory: String = "user://region_authoring/exports"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path: String = directory + "/%s_preview.png" % String(document.region.id).replace(".", "_")
	var error: Error = preview.save_png(path)
	if error == OK:
		_show_status("Preview exported to %s." % path)
		OS.shell_open(ProjectSettings.globalize_path(path.get_base_dir()))
	else:
		_show_status("Preview export failed.")


func _capture_map_preview() -> Image:
	var viewport_image: Image = get_viewport().get_texture().get_image()
	if viewport_image == null or viewport_image.is_empty():
		return null
	var global_rect: Rect2 = _map_view.get_global_rect()
	var image_rect := Rect2i(
		maxi(0, int(global_rect.position.x)),
		maxi(0, int(global_rect.position.y)),
		mini(int(global_rect.size.x), viewport_image.get_width() - maxi(0, int(global_rect.position.x))),
		mini(int(global_rect.size.y), viewport_image.get_height() - maxi(0, int(global_rect.position.y)))
	)
	return viewport_image.get_region(image_rect) if image_rect.size.x > 0 and image_rect.size.y > 0 else viewport_image


func _request_close() -> void:
	if _dirty and not _save_working():
		_show_status("Close cancelled because the current region could not be saved.")
		return
	close_requested.emit()


func _show_open_dialog() -> void:
	_open_dialog.popup_centered_ratio(0.82)


func _show_save_dialog() -> void:
	_save_dialog.current_file = "life_starter_authoring.json"
	_save_dialog.popup_centered_ratio(0.82)


func _show_export_dialog() -> void:
	_export_dialog.current_file = "Seethe_Life_Starter_Region_Authoring.zip"
	_export_dialog.popup_centered_ratio(0.82)


func _show_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _compact_toolbar_button(text_value: String, callback: Callable, width: float) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(width, 38)
	button.pressed.connect(callback)
	return button


func _toolbar_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(maxi(86, text_value.length() * 8 + 22), 38)
	button.pressed.connect(callback)
	return button


func _small_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _section_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("c8a75e"))
	return label


func _add_option(option: OptionButton, label: String, metadata: Variant) -> void:
	var index: int = option.item_count
	option.add_item(label)
	option.set_item_metadata(index, metadata)


func _select_option_by_metadata(option: OptionButton, metadata: StringName) -> void:
	if option == null:
		return
	for index: int in range(option.item_count):
		if StringName(option.get_item_metadata(index)) == metadata:
			option.select(index)
			if option == _site_option:
				_on_site_selected(index)
			elif option == _settlement_option:
				_on_settlement_selected(index)
			return


func _select_option_by_metadata_no_signal(option: OptionButton, metadata: StringName) -> bool:
	if option == null:
		return false
	for index: int in range(option.item_count):
		if StringName(option.get_item_metadata(index)) == metadata:
			option.select(index)
			return true
	return false


func _first_playable_coord() -> RegionHexCoord:
	if document == null or document.region == null:
		return null
	for hex: RegionHexDefinition in document.region.all_hexes():
		if hex.playable:
			return hex.coord.duplicate_coord()
	return null


func _first_subregion_id() -> StringName:
	if document == null or document.region.subregions_by_id.is_empty():
		return &"subregion.life.telluria_proper"
	var keys: Array = document.region.subregions_by_id.keys()
	keys.sort()
	return StringName(keys[0])


func _site_icon_for_type(site_type: StringName) -> StringName:
	match site_type:
		&"ruin":
			return RegionSymbolCatalogue.ANCIENT_RUIN
		&"farm":
			return RegionSymbolCatalogue.FARM
		&"religious":
			return RegionSymbolCatalogue.RELIGIOUS_SITE
		&"military":
			return RegionSymbolCatalogue.MILITARY_SITE
	return RegionSymbolCatalogue.WILDERNESS_SITE
