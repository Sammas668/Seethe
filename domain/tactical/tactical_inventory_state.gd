class_name TacticalInventoryState
extends RefCounted

var main_hand: String
var off_hand: String
var armour: String
var secondary_set: String
var quick_access_items: Array[String]
var packed_items: Array[String]
var current_weight_lb: float
var maximum_weight_lb: float


func _init(
        main_hand_value: String = "Empty",
        off_hand_value: String = "Empty",
        armour_value: String = "No armour",
        secondary_set_value: String = "None",
        quick_access_value: Array[String] = [],
        packed_items_value: Array[String] = [],
        current_weight_value: float = 0.0,
        maximum_weight_value: float = 60.0
) -> void:
    main_hand = main_hand_value
    off_hand = off_hand_value
    armour = armour_value
    secondary_set = secondary_set_value
    quick_access_items = quick_access_value.duplicate()
    packed_items = packed_items_value.duplicate()
    current_weight_lb = maxf(0.0, current_weight_value)
    maximum_weight_lb = maxf(1.0, maximum_weight_value)


func quick_access_summary() -> String:
    if quick_access_items.is_empty():
        return "Empty"
    return ", ".join(PackedStringArray(quick_access_items))


func packed_summary() -> String:
    if packed_items.is_empty():
        return "Empty"
    return "\n".join(PackedStringArray(packed_items))
