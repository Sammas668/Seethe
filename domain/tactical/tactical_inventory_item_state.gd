class_name TacticalInventoryItemState
extends RefCounted

var item_id: StringName
var display_name: String
var weight_lb: float
var footprint: Vector2i
var two_handed: bool
var belt_allowed: bool
var container_kind: StringName
var grid_position: Vector2i
var source_label: String


func _init(
        item_id_value: StringName = &"",
        display_name_value: String = "Unknown item",
        weight_value: float = 0.0,
        footprint_value: Vector2i = Vector2i.ONE,
        two_handed_value: bool = false,
        belt_allowed_value: bool = true,
        container_kind_value: StringName = &"",
        grid_position_value: Vector2i = Vector2i.ZERO,
        source_label_value: String = ""
) -> void:
    item_id = item_id_value
    display_name = display_name_value
    weight_lb = maxf(0.0, weight_value)
    footprint = Vector2i(
        maxi(1, footprint_value.x),
        maxi(1, footprint_value.y)
    )
    two_handed = two_handed_value
    belt_allowed = belt_allowed_value
    container_kind = container_kind_value
    grid_position = grid_position_value
    source_label = source_label_value


static func create_from_name(
        item_id_value: StringName,
        item_name: String,
        container_kind_value: StringName = &"",
        grid_position_value: Vector2i = Vector2i.ZERO,
        weight_override: float = -1.0,
        source_label_value: String = ""
) -> TacticalInventoryItemState:
    var weight := TacticalItemProfile.weight_for(item_name)
    if weight_override >= 0.0:
        weight = weight_override

    return TacticalInventoryItemState.new(
        item_id_value,
        item_name,
        weight,
        TacticalItemProfile.footprint_for(item_name),
        TacticalItemProfile.is_two_handed(item_name),
        TacticalItemProfile.belt_allowed(item_name),
        container_kind_value,
        grid_position_value,
        source_label_value
    )


func clone_for_container(
        new_container: StringName,
        new_position: Vector2i
) -> TacticalInventoryItemState:
    return TacticalInventoryItemState.new(
        item_id,
        display_name,
        weight_lb,
        footprint,
        two_handed,
        belt_allowed,
        new_container,
        new_position,
        source_label
    )
