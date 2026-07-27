class_name TacticalItemState
extends RefCounted

var item_id: StringName
var display_name: String
var grid_position: Vector2i
var quantity: int
var weight_lb: float
var source_label: String


func _init(
        item_id_value: StringName = &"",
        display_name_value: String = "Unknown item",
        grid_position_value: Vector2i = Vector2i.ZERO,
        quantity_value: int = 1,
        weight_value: float = 0.0,
        source_label_value: String = "Ground"
) -> void:
    item_id = item_id_value
    display_name = display_name_value
    grid_position = grid_position_value
    quantity = maxi(1, quantity_value)
    weight_lb = maxf(0.0, weight_value)
    source_label = source_label_value


func display_line() -> String:
    var quantity_text := ""
    if quantity > 1:
        quantity_text = " x%d" % quantity

    var weight_text := ""
    if weight_lb > 0.0:
        weight_text = " · %.1f lb" % weight_lb

    return "%s%s%s" % [display_name, quantity_text, weight_text]
