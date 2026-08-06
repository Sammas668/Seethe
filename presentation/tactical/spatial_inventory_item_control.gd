class_name SpatialInventoryItemControl
extends Button

signal item_activated(
	item_control: SpatialInventoryItemControl,
	mouse_button: int
)
signal item_dropped_onto(
	target_item_id: StringName,
	drag_data: Dictionary
)

var source_kind: StringName = &""
var item_id: StringName = &""
var item_name: String = ""
var footprint: Vector2i = Vector2i.ONE
var selected: bool = false
var visual_category: StringName = &"misc"
var instance_kind: StringName = &"item"
var _status_snapshot: Dictionary = {}
var fixed_fixture: bool = false
var is_rotated: bool = false
var _status_overlay: TacticalBodyStatusOverlay


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pressed.connect(
		func() -> void:
			item_activated.emit(self, MOUSE_BUTTON_LEFT)
	)
	gui_input.connect(_on_gui_input)
	_refresh_style()


func configure(
		source_kind_value: StringName,
		item_id_value: StringName,
		item_name_value: String,
		footprint_value: Vector2i,
		visual_category_value: StringName = &"misc",
		instance_kind_value: StringName = &"item",
		status_snapshot_value: Dictionary = {},
		fixed_fixture_value: bool = false,
		is_rotated_value: bool = false
) -> void:
	source_kind = source_kind_value
	item_id = item_id_value
	item_name = item_name_value
	footprint = footprint_value
	visual_category = visual_category_value
	instance_kind = instance_kind_value
	_status_snapshot = status_snapshot_value.duplicate(true)
	fixed_fixture = fixed_fixture_value
	is_rotated = is_rotated_value
	text = item_name
	tooltip_text = item_name + ("\nPermanent Belt item — left-click to open." if fixed_fixture else "")
	_refresh_status_overlay()
	_refresh_style()


func set_selected(value: bool) -> void:
	selected = value
	_refresh_style()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			item_activated.emit(self, MOUSE_BUTTON_RIGHT)
			accept_event()


func _get_drag_data(_position: Vector2) -> Variant:
	if fixed_fixture:
		return null
	if item_name.is_empty():
		return null

	var preview_root := Control.new()
	preview_root.custom_minimum_size = Vector2(
		maxf(120.0, size.x),
		maxf(38.0, size.y * 0.55)
	)
	var preview := PanelContainer.new()
	preview_root.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var preview_label := Label.new()
	preview_label.text = item_name
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_child(preview_label)
	if instance_kind == &"body":
		var preview_overlay := TacticalBodyStatusOverlay.new()
		preview_root.add_child(preview_overlay)
		preview_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_overlay.configure(_status_snapshot)
	set_drag_preview(preview_root)

	return {
		"source_kind": source_kind,
		"source_item_id": item_id,
		"item_name": item_name,
		"footprint": footprint,
		"instance_kind": instance_kind,
		"is_rotated": is_rotated,
	}


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if instance_kind != &"body" or not data is Dictionary:
		return false
	return StringName(data.get("source_item_id", &"")) != item_id


func _drop_data(_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	item_dropped_onto.emit(item_id, (data as Dictionary).duplicate(true))


func _refresh_style() -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = _item_colour()
	normal_style.border_color = Color(0.43, 0.49, 0.52, 1.0)
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.corner_radius_top_left = 2
	normal_style.corner_radius_top_right = 2
	normal_style.corner_radius_bottom_left = 2
	normal_style.corner_radius_bottom_right = 2

	if fixed_fixture:
		normal_style.border_color = Color(0.86, 0.58, 0.18, 1.0)
		normal_style.border_width_left = 2
		normal_style.border_width_top = 2
		normal_style.border_width_right = 2
		normal_style.border_width_bottom = 2

	if selected:
		normal_style.border_color = Color(0.96, 0.74, 0.20, 1.0)
		normal_style.border_width_left = 3
		normal_style.border_width_top = 3
		normal_style.border_width_right = 3
		normal_style.border_width_bottom = 3

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = normal_style.bg_color.lightened(0.10)

	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", hover_style)
	add_theme_font_size_override("font_size", 12 if fixed_fixture else 11)
	add_theme_color_override("font_color", Color(0.94, 0.94, 0.91, 1.0))


func _refresh_status_overlay() -> void:
	if instance_kind != &"body":
		if _status_overlay != null:
			_status_overlay.visible = false
		return
	if _status_overlay == null:
		_status_overlay = TacticalBodyStatusOverlay.new()
		add_child(_status_overlay)
		_status_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_status_overlay.z_index = 20
	_status_overlay.visible = true
	_status_overlay.configure(_status_snapshot)


func _item_colour() -> Color:
	match visual_category:
		&"medical":
			return Color(0.25, 0.13, 0.11, 0.98)
		&"tool":
			return Color(0.20, 0.17, 0.11, 0.98)
		&"loot":
			return Color(0.25, 0.18, 0.09, 0.98)
		&"container":
			return Color(0.30, 0.20, 0.08, 0.99)
		&"weapon":
			return Color(0.13, 0.19, 0.22, 0.98)
		&"body":
			return Color(0.18, 0.10, 0.11, 0.98)
		_:
			return Color(0.15, 0.17, 0.19, 0.98)
