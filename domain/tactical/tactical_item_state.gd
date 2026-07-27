class_name TacticalItemState
extends RefCounted

var item_id: StringName
var display_name: String
var grid_position: Vector2i
var quantity: int
var weight_lb: float
var source_label: String
var inventory_footprint: Vector2i
var two_handed: bool
var belt_allowed: bool


func _init(
        item_id_value: StringName = &"",
        display_name_value: String = "Unknown item",
        grid_position_value: Vector2i = Vector2i.ZERO,
        quantity_value: int = 1,
        weight_value: float = 0.0,
        source_label_value: String = "Ground",
        footprint_value: Vector2i = Vector2i.ZERO,
        two_handed_value: bool = false,
        belt_allowed_value: bool = true
) -> void:
    item_id = item_id_value
    display_name = display_name_value
    grid_position = grid_position_value
    quantity = maxi(1, quantity_value)
    weight_lb = maxf(0.0, weight_value)
    source_label = source_label_value
    inventory_footprint = (
        TacticalItemProfile.footprint_for(display_name)
        if footprint_value == Vector2i.ZERO
        else footprint_value
    )
    two_handed = (
        TacticalItemProfile.is_two_handed(display_name)
        if not two_handed_value
        else true
    )
    belt_allowed = (
        TacticalItemProfile.belt_allowed(display_name)
        if belt_allowed_value
        else false
    )


func display_line() -> String:
    var quantity_text := ""
    if quantity > 1:
        quantity_text = " x%d" % quantity

    var weight_text := ""
    if weight_lb > 0.0:
        weight_text = " · %.1f lb" % weight_lb

    return "%s%s%s" % [display_name, quantity_text, weight_text]
