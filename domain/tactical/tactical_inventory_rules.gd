class_name TacticalInventoryRules
extends RefCounted


static func is_ground_slot(slot_id: StringName) -> bool:
    return TacticalInventoryState.slot_kind(slot_id) == "ground"


static func is_equipment_slot(slot_id: StringName) -> bool:
    return slot_id in [
        TacticalInventoryState.MAIN_HAND,
        TacticalInventoryState.OFF_HAND,
        TacticalInventoryState.ARMOUR,
        TacticalInventoryState.SECONDARY,
    ]


static func accepts_item(
        unit: TacticalUnitState,
        item: TacticalItemState,
        target_slot_id: StringName
) -> String:
    if unit == null or item == null:
        return "The item or target unit is missing."

    if is_ground_slot(target_slot_id):
        return ""

    if not unit.inventory.is_empty(target_slot_id):
        return "The destination slot is occupied."

    var kind := TacticalInventoryState.slot_kind(target_slot_id)

    match kind:
        "main_hand", "off_hand", "secondary":
            if item.category not in [&"weapon", &"shield", &"tool"]:
                return "That slot accepts weapons, shields or hand-held tools."
        "armour":
            if item.category != &"armour":
                return "Only armour can be placed in the armour slot."
        "quick":
            if item.category in [&"armour", &"loot", &"container"]:
                return "That item category cannot be placed in Quick Access."
            if item.bulky or item.weight_lb > 10.0:
                return "That item is too bulky for Quick Access."
        "packed":
            pass
        _:
            return "The destination is not a recognised tactical inventory slot."

    return ""


static func transfer_cost(
        item: TacticalItemState,
        source_slot_id: StringName,
        target_slot_id: StringName
) -> ActionCost:
    var source_kind := TacticalInventoryState.slot_kind(source_slot_id)
    var target_kind := TacticalInventoryState.slot_kind(target_slot_id)

    if source_kind == "ground" and target_kind == "ground":
        return ActionCost.minor_interaction()

    if source_kind == "ground" and target_kind != "ground":
        if item.bulky or item.weight_lb >= 15.0:
            return ActionCost.half_action()
        return ActionCost.minor_interaction()

    if source_kind != "ground" and target_kind == "ground":
        return ActionCost.fixed_capacity(0)

    if source_kind == "packed" and target_kind == "packed":
        return ActionCost.fixed_capacity(0)

    if source_kind == "quick" and target_kind == "quick":
        return ActionCost.fixed_capacity(0)

    if (
        source_kind in ["quick", "main_hand", "off_hand", "secondary"]
        and target_kind in ["quick", "main_hand", "off_hand", "secondary"]
    ):
        return ActionCost.quick_action()

    if source_kind == "packed" or target_kind == "packed":
        return ActionCost.half_action()

    return ActionCost.quick_action()


static func action_name(
        item: TacticalItemState,
        source_slot_id: StringName,
        target_slot_id: StringName
) -> String:
    var source_kind := TacticalInventoryState.slot_kind(source_slot_id)
    var target_kind := TacticalInventoryState.slot_kind(target_slot_id)

    if source_kind == "ground" and target_kind != "ground":
        return "Pick up %s" % item.display_name
    if source_kind != "ground" and target_kind == "ground":
        return "Drop %s" % item.display_name
    if target_kind == "quick":
        return "Move %s to Quick Access" % item.display_name
    if target_kind == "packed":
        return "Pack %s" % item.display_name
    if target_kind == "armour":
        return "Equip %s as armour" % item.display_name
    if target_kind in ["main_hand", "off_hand", "secondary"]:
        return "Ready %s" % item.display_name
    return "Move %s" % item.display_name
