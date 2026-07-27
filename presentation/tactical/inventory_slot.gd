class_name TacticalInventorySlot
extends PanelContainer

signal slot_activated(
    slot_id: StringName,
    item_id: StringName,
    mouse_button: int
)
signal transfer_requested(
    source_slot_id: StringName,
    target_slot_id: StringName,
    item_id: StringName
)
signal slot_hovered(slot_id: StringName)

var slot_id: StringName = &""
var item_id: StringName = &""
var slot_title: String = ""
var item_name: String = ""
var _selected: bool = false
var _valid_target: bool = false
var _label: Label


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    custom_minimum_size = Vector2(80.0, 58.0)

    _label = Label.new()
    _label.layout_mode = 2
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_label)

    mouse_entered.connect(func() -> void: slot_hovered.emit(slot_id))
    _apply_presentation()


func configure(
        slot_id_value: StringName,
        slot_title_value: String,
        item_id_value: StringName,
        item_name_value: String
) -> void:
    slot_id = slot_id_value
    slot_title = slot_title_value
    item_id = item_id_value
    item_name = item_name_value
    tooltip_text = (
        item_name
        if item_id != &""
        else slot_title
    )
    if is_node_ready():
        _apply_presentation()


func set_selected(selected: bool) -> void:
    _selected = selected
    if is_node_ready():
        _apply_style()


func set_valid_target(valid_target: bool) -> void:
    _valid_target = valid_target
    if is_node_ready():
        _apply_style()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var button_event := event as InputEventMouseButton
        if button_event.pressed:
            slot_activated.emit(
                slot_id,
                item_id,
                button_event.button_index
            )
            accept_event()


func _get_drag_data(_position: Vector2) -> Variant:
    if item_id == &"":
        return null

    var preview := PanelContainer.new()
    preview.custom_minimum_size = Vector2(160.0, 42.0)
    var preview_label := Label.new()
    preview_label.text = item_name
    preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    preview.add_child(preview_label)
    set_drag_preview(preview)

    return {
        "source_slot_id": slot_id,
        "item_id": item_id,
    }


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
    if not data is Dictionary:
        return false
    var source_slot := StringName(data.get("source_slot_id", &""))
    return source_slot != &"" and source_slot != slot_id


func _drop_data(_position: Vector2, data: Variant) -> void:
    if not data is Dictionary:
        return

    transfer_requested.emit(
        StringName(data.get("source_slot_id", &"")),
        slot_id,
        StringName(data.get("item_id", &""))
    )


func _apply_presentation() -> void:
    if _label == null:
        return

    if item_id == &"":
        _label.text = slot_title
        _label.modulate = Color(0.66, 0.70, 0.73, 1.0)
    else:
        _label.text = "%s\n%s" % [slot_title, item_name]
        _label.modulate = Color.WHITE

    _apply_style()


func _apply_style() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.055, 0.070, 0.085, 0.98)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 3
    style.corner_radius_top_right = 3
    style.corner_radius_bottom_left = 3
    style.corner_radius_bottom_right = 3

    if _selected:
        style.bg_color = Color(0.16, 0.13, 0.07, 0.99)
        style.border_color = Color(0.94, 0.74, 0.25, 1.0)
        style.border_width_left = 2
        style.border_width_top = 2
        style.border_width_right = 2
        style.border_width_bottom = 2
    elif _valid_target:
        style.bg_color = Color(0.06, 0.15, 0.10, 0.99)
        style.border_color = Color(0.28, 0.78, 0.46, 1.0)
    else:
        style.border_color = Color(0.30, 0.36, 0.41, 1.0)

    add_theme_stylebox_override("panel", style)
