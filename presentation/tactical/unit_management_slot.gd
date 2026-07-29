class_name UnitManagementSlot
extends Button

signal item_activated(
	slot: UnitManagementSlot,
	mouse_button: int
)
signal transfer_requested(
	source_kind: StringName,
	source_item_id: StringName,
	target_kind: StringName,
	target_cell_index: int
)

var slot_kind: StringName = &""
var slot_label: String = ""
var item_id: StringName = &""
var item_name: String = ""
var footprint: Vector2i = Vector2i.ONE
var accepts_items: bool = true
var selected: bool = false
var valid_target: bool = false


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
		slot_kind_value: StringName,
		slot_label_value: String,
		item: TacticalItemInstanceState,
		accepts_items_value: bool = true,
		reserved_text: String = ""
) -> void:
	slot_kind = slot_kind_value
	slot_label = slot_label_value
	accepts_items = accepts_items_value

	if item == null:
		item_id = &""
		item_name = ""
		footprint = Vector2i.ONE
		text = (
			"%s\n%s" % [slot_label, reserved_text]
			if not reserved_text.is_empty()
			else "%s\nEMPTY" % slot_label
		)
	else:
		item_id = item.item_id
		item_name = item.display_name
		footprint = item.footprint
		text = "%s\n%s" % [slot_label, item_name]

	disabled = not accepts_items and item_name.is_empty()
	tooltip_text = text.replace("\n", ": ")
	_refresh_style()


func set_selected(value: bool) -> void:
	selected = value
	_refresh_style()


func set_valid_target(value: bool) -> void:
	valid_target = value
	_refresh_style()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			item_activated.emit(self, MOUSE_BUTTON_RIGHT)
			accept_event()


func _get_drag_data(_position: Vector2) -> Variant:
	if item_name.is_empty():
		return null

	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(200.0, 42.0)
	var label := Label.new()
	label.text = item_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_child(label)
	set_drag_preview(preview)

	return {
		"source_kind": slot_kind,
		"source_item_id": item_id,
		"item_name": item_name,
		"footprint": footprint,
	}


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if not accepts_items or not item_name.is_empty():
		return false
	return data is Dictionary


func _drop_data(_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return

	transfer_requested.emit(
		StringName(data.get("source_kind", &"")),
		StringName(data.get("source_item_id", &"")),
		slot_kind,
		-1
	)


func _refresh_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.060, 0.072, 0.99)
	style.border_color = Color(0.28, 0.35, 0.40, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3

	if selected:
		style.bg_color = Color(0.17, 0.12, 0.045, 0.99)
		style.border_color = Color(0.96, 0.74, 0.20, 1.0)
	elif valid_target:
		style.bg_color = Color(0.045, 0.15, 0.085, 0.99)
		style.border_color = Color(0.30, 0.80, 0.47, 1.0)
	elif not accepts_items:
		style.bg_color = Color(0.075, 0.075, 0.075, 0.95)
		style.border_color = Color(0.30, 0.30, 0.30, 1.0)

	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_font_size_override("font_size", 12)
