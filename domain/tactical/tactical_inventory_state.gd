class_name TacticalInventoryState
extends RefCounted

const KIND_PRIMARY_HAND: StringName = &"main_hand"
const KIND_SECONDARY_HAND: StringName = &"off_hand"
const KIND_BELT: StringName = &"belt"
const KIND_BACKPACK: StringName = &"backpack"

const BELT_WIDTH: int = 5
const BELT_HEIGHT: int = 2
const BACKPACK_WIDTH: int = 10
const BACKPACK_HEIGHT: int = 4

# Compatibility text used by the tactical HUD.
var main_hand: String = "Empty"
var off_hand: String = "Empty"
var armour: String = "No armour"
var secondary_set: String = "None"
var quick_access_items: Array[String] = []
var packed_items: Array[String] = []

var primary_hand_item: TacticalInventoryItemState
var secondary_hand_item: TacticalInventoryItemState
var belt_items: Array[TacticalInventoryItemState] = []
var backpack_items: Array[TacticalInventoryItemState] = []

var current_weight_lb: float
var maximum_weight_lb: float
var _item_serial: int = 0


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
    armour = armour_value
    current_weight_lb = maxf(0.0, current_weight_value)
    maximum_weight_lb = maxf(1.0, maximum_weight_value)

    if not _normalise_name(main_hand_value).is_empty():
        primary_hand_item = _create_item(main_hand_value, KIND_PRIMARY_HAND)

    if not _normalise_name(off_hand_value).is_empty():
        secondary_hand_item = _create_item(off_hand_value, KIND_SECONDARY_HAND)

    if (
        primary_hand_item != null
        and primary_hand_item.two_handed
        and secondary_hand_item != null
    ):
        var displaced_secondary := secondary_hand_item
        secondary_hand_item = null
        var displaced_position := first_fit(displaced_secondary, KIND_BACKPACK)
        if displaced_position.x >= 0:
            add_grid_item(
                displaced_secondary,
                KIND_BACKPACK,
                displaced_position
            )

    for item_name: String in quick_access_value:
        _add_initial_grid_item(item_name, KIND_BELT)

    for item_name: String in packed_items_value:
        _add_initial_grid_item(item_name, KIND_BACKPACK)

    # Old prepared sets are preserved as ordinary backpack items.
    if not _normalise_name(secondary_set_value).is_empty():
        _add_initial_grid_item(secondary_set_value, KIND_BACKPACK)

    _sync_legacy_fields()


func find_item(
        item_id: StringName,
        container_kind: StringName
) -> TacticalInventoryItemState:
    match container_kind:
        KIND_PRIMARY_HAND:
            if primary_hand_item != null and primary_hand_item.item_id == item_id:
                return primary_hand_item
        KIND_SECONDARY_HAND:
            if secondary_hand_item != null and secondary_hand_item.item_id == item_id:
                return secondary_hand_item
        KIND_BELT:
            for item: TacticalInventoryItemState in belt_items:
                if item.item_id == item_id:
                    return item
        KIND_BACKPACK:
            for item: TacticalInventoryItemState in backpack_items:
                if item.item_id == item_id:
                    return item
    return null


func take_item(
        item_id: StringName,
        container_kind: StringName
) -> TacticalInventoryItemState:
    var item := find_item(item_id, container_kind)
    if item == null:
        return null

    match container_kind:
        KIND_PRIMARY_HAND:
            primary_hand_item = null
        KIND_SECONDARY_HAND:
            secondary_hand_item = null
        KIND_BELT:
            belt_items.erase(item)
        KIND_BACKPACK:
            backpack_items.erase(item)

    _sync_legacy_fields()
    return item


func set_hand_item(
        hand_kind: StringName,
        item: TacticalInventoryItemState
) -> void:
    if hand_kind == KIND_PRIMARY_HAND:
        primary_hand_item = item
        if item != null:
            item.container_kind = KIND_PRIMARY_HAND
            item.grid_position = Vector2i.ZERO
    elif hand_kind == KIND_SECONDARY_HAND:
        secondary_hand_item = item
        if item != null:
            item.container_kind = KIND_SECONDARY_HAND
            item.grid_position = Vector2i.ZERO

    _sync_legacy_fields()


func add_grid_item(
        item: TacticalInventoryItemState,
        container_kind: StringName,
        position: Vector2i
) -> bool:
    if item == null:
        return false
    if (
        container_kind == KIND_BACKPACK
        and not TacticalItemProfile.backpack_allowed(item.display_name)
    ):
        return false
    if not can_place_item(item, container_kind, position):
        return false

    item.container_kind = container_kind
    item.grid_position = position

    if container_kind == KIND_BELT:
        belt_items.append(item)
    elif container_kind == KIND_BACKPACK:
        backpack_items.append(item)
    else:
        return false

    _sync_legacy_fields()
    return true


func can_place_item(
        item: TacticalInventoryItemState,
        container_kind: StringName,
        position: Vector2i,
        ignore_item_id: StringName = &""
) -> bool:
    if item == null:
        return false

    var width := BACKPACK_WIDTH
    var height := BACKPACK_HEIGHT
    var items := backpack_items

    if container_kind == KIND_BELT:
        if not item.belt_allowed:
            return false
        width = BELT_WIDTH
        height = BELT_HEIGHT
        items = belt_items
    elif container_kind != KIND_BACKPACK:
        return false

    if (
        container_kind == KIND_BACKPACK
        and not TacticalItemProfile.backpack_allowed(item.display_name)
    ):
        return false

    if position.x < 0 or position.y < 0:
        return false
    if position.x + item.footprint.x > width:
        return false
    if position.y + item.footprint.y > height:
        return false

    var proposed := Rect2i(position, item.footprint)
    for other: TacticalInventoryItemState in items:
        if other.item_id == ignore_item_id:
            continue
        var occupied := Rect2i(other.grid_position, other.footprint)
        if proposed.intersects(occupied):
            return false

    return true


func first_fit(
        item: TacticalInventoryItemState,
        container_kind: StringName,
        ignore_item_id: StringName = &""
) -> Vector2i:
    var width := BACKPACK_WIDTH
    var height := BACKPACK_HEIGHT

    if container_kind == KIND_BELT:
        width = BELT_WIDTH
        height = BELT_HEIGHT

    for y: int in range(height):
        for x: int in range(width):
            var candidate := Vector2i(x, y)
            if can_place_item(item, container_kind, candidate, ignore_item_id):
                return candidate

    return Vector2i(-1, -1)


func belt_summary() -> String:
    if belt_items.is_empty():
        return "Empty"

    var names: Array[String] = []
    for item: TacticalInventoryItemState in belt_items:
        names.append(item.display_name)
    return ", ".join(PackedStringArray(names))


func backpack_summary() -> String:
    if backpack_items.is_empty():
        return "Empty"

    var names: Array[String] = []
    for item: TacticalInventoryItemState in backpack_items:
        names.append(item.display_name)
    return "\n".join(PackedStringArray(names))


func quick_access_summary() -> String:
    return belt_summary()


func packed_summary() -> String:
    return backpack_summary()


func _add_initial_grid_item(
        item_name: String,
        preferred_container: StringName
) -> void:
    var clean_name := _normalise_name(item_name)
    if clean_name.is_empty():
        return

    var item := _create_item(clean_name, preferred_container)
    var position := first_fit(item, preferred_container)

    if position.x >= 0:
        add_grid_item(item, preferred_container, position)
        return

    if preferred_container == KIND_BELT:
        position = first_fit(item, KIND_BACKPACK)
        if position.x >= 0:
            add_grid_item(item, KIND_BACKPACK, position)


func _create_item(
        item_name: String,
        container_kind: StringName
) -> TacticalInventoryItemState:
    _item_serial += 1
    return TacticalInventoryItemState.create_from_name(
        StringName("inventory.%d" % _item_serial),
        item_name,
        container_kind
    )


func _sync_legacy_fields() -> void:
    main_hand = (
        primary_hand_item.display_name
        if primary_hand_item != null
        else "Empty"
    )

    if primary_hand_item != null and primary_hand_item.two_handed:
        off_hand = "Reserved by %s" % primary_hand_item.display_name
    else:
        off_hand = (
            secondary_hand_item.display_name
            if secondary_hand_item != null
            else "Empty"
        )

    secondary_set = "None"
    quick_access_items.clear()
    packed_items.clear()

    for item: TacticalInventoryItemState in belt_items:
        quick_access_items.append(item.display_name)
    for item: TacticalInventoryItemState in backpack_items:
        packed_items.append(item.display_name)


func _normalise_name(item_name: String) -> String:
    var lower := item_name.to_lower()
    if lower in ["", "empty", "none", "no armour"]:
        return ""
    return item_name
