class_name TacticalInventoryTransferHandler
extends RefCounted

const KIND_PRIMARY_HAND: StringName = &"main_hand"
const KIND_SECONDARY_HAND: StringName = &"off_hand"
const KIND_BELT: StringName = &"belt"
const KIND_BACKPACK: StringName = &"backpack"
const KIND_GROUND: StringName = &"ground"

const BELT_WIDTH: int = TacticalInventoryState.BELT_WIDTH
const BACKPACK_WIDTH: int = TacticalInventoryState.BACKPACK_WIDTH

var _state_store: TacticalStateStore
var _drop_counter: int = 0


func _init(state_store: TacticalStateStore) -> void:
    _state_store = state_store


func preview(
        command: TacticalInventoryTransferCommand
) -> TacticalInventoryTransferPreview:
    if command == null:
        return TacticalInventoryTransferPreview.rejected(
            "No inventory transfer has been selected."
        )

    if not _state_store.state.phase_state.is_player_phase():
        return TacticalInventoryTransferPreview.rejected(
            "Inventory changes are unavailable outside the Player Phase."
        )

    var unit := _state_store.state.get_unit(command.unit_id)
    if unit == null:
        return TacticalInventoryTransferPreview.rejected(
            "The selected unit does not exist."
        )

    var item := resolve_source_item(command)
    if item == null:
        return TacticalInventoryTransferPreview.rejected(
            "The selected source item no longer exists."
        )

    if command.source_kind == command.target_kind:
        if command.source_kind in [KIND_PRIMARY_HAND, KIND_SECONDARY_HAND]:
            return TacticalInventoryTransferPreview.rejected(
                "The item is already in that hand."
            )
        if command.source_kind == KIND_GROUND:
            return TacticalInventoryTransferPreview.rejected(
                "The item is already in Items in Reach."
            )

    var destination_reason := _destination_reason(unit, item, command)
    if not destination_reason.is_empty():
        return TacticalInventoryTransferPreview.rejected(destination_reason)

    if command.source_kind == KIND_GROUND:
        var ground_item := _state_store.state.get_ground_item(
            command.source_item_id
        )
        if ground_item == null:
            return TacticalInventoryTransferPreview.rejected(
                "The ground item is no longer present."
            )

        var offset := ground_item.grid_position - unit.grid_position
        if absi(offset.x) > 1 or absi(offset.y) > 1:
            return TacticalInventoryTransferPreview.rejected(
                "The item is outside the unit's reach."
            )

        if (
            command.target_kind != KIND_GROUND
            and unit.inventory.current_weight_lb + ground_item.weight_lb
            > unit.inventory.maximum_weight_lb
        ):
            return TacticalInventoryTransferPreview.rejected(
                "Picking up this item would exceed the carrying limit."
            )

    var cost := _normal_cost(command, item)
    var requires_quick := _requires_additional_quick(command)
    var provokes := _provokes(command)

    var unavailable_reason := ActionEconomyRules.unavailable_reason(unit, cost)
    if not unavailable_reason.is_empty():
        return TacticalInventoryTransferPreview.rejected(unavailable_reason)

    if requires_quick:
        var quick_reason := ActionEconomyRules.unavailable_reason(
            unit,
            ActionCost.quick_action()
        )
        if not quick_reason.is_empty():
            return TacticalInventoryTransferPreview.rejected(quick_reason)

    var feet := cost.resolved_normal_capacity_feet(
        unit.action_budget.maximum_turn_capacity_feet
    )
    var remaining := unit.action_budget.remaining_turn_capacity_feet - feet

    return TacticalInventoryTransferPreview.accepted(
        _action_name(command, item.display_name),
        item.display_name,
        cost,
        requires_quick,
        provokes,
        feet,
        remaining
    )


func execute(command: TacticalInventoryTransferCommand) -> OperationResult:
    var transfer_preview := preview(command)
    if not transfer_preview.success:
        return OperationResult.fail(
            &"inventory_transfer_invalid",
            transfer_preview.reason
        )

    var unit := _state_store.state.get_unit(command.unit_id)
    if unit == null:
        return OperationResult.fail(
            &"inventory_unit_missing",
            "The selected unit no longer exists."
        )

    var item := _take_source_item(unit, command)
    if item == null:
        return OperationResult.fail(
            &"inventory_source_missing",
            "The source item could not be removed."
        )

    var spent := ActionEconomyRules.spend(
        unit,
        transfer_preview.action_cost
    )
    if spent < 0:
        _restore_source_item(unit, command, item)
        return OperationResult.fail(
            &"inventory_cost_failed",
            "The action cost could not be paid."
        )

    if transfer_preview.requires_quick_action:
        var quick_spent := ActionEconomyRules.spend(
            unit,
            ActionCost.quick_action()
        )
        if quick_spent < 0:
            _restore_source_item(unit, command, item)
            return OperationResult.fail(
                &"inventory_quick_cost_failed",
                "The Quick Action cost could not be paid."
            )

    var placed := _place_target_item(unit, command, item)
    if not placed:
        _restore_source_item(unit, command, item)
        return OperationResult.fail(
            &"inventory_destination_failed",
            "The item could not be placed in that destination."
        )

    if command.source_kind == KIND_GROUND:
        unit.inventory.current_weight_lb = minf(
            unit.inventory.maximum_weight_lb,
            unit.inventory.current_weight_lb + item.weight_lb
        )
    elif command.target_kind == KIND_GROUND:
        unit.inventory.current_weight_lb = maxf(
            0.0,
            unit.inventory.current_weight_lb - item.weight_lb
        )

    _state_store.notify_changed(&"inventory_transfer")
    return OperationResult.ok(
        transfer_preview,
        _format_success_message(transfer_preview)
    )


func resolve_source_item(
        command: TacticalInventoryTransferCommand
) -> TacticalInventoryItemState:
    if command == null:
        return null

    var unit := _state_store.state.get_unit(command.unit_id)
    if unit == null:
        return null

    if command.source_kind == KIND_GROUND:
        var ground_item := _state_store.state.get_ground_item(
            command.source_item_id
        )
        if ground_item == null:
            return null
        return TacticalInventoryItemState.new(
            ground_item.item_id,
            ground_item.display_name,
            ground_item.weight_lb,
            ground_item.inventory_footprint,
            ground_item.two_handed,
            ground_item.belt_allowed,
            KIND_GROUND,
            Vector2i.ZERO,
            ground_item.source_label
        )

    return unit.inventory.find_item(
        command.source_item_id,
        command.source_kind
    )


func first_fit_for_item(
        unit_id: StringName,
        item: TacticalInventoryItemState,
        target_kind: StringName
) -> int:
    var unit := _state_store.state.get_unit(unit_id)
    if unit == null or item == null:
        return -1

    var position := unit.inventory.first_fit(item, target_kind)
    if position.x < 0:
        return -1

    var width := (
        BELT_WIDTH
        if target_kind == KIND_BELT
        else BACKPACK_WIDTH
    )
    return position.y * width + position.x


func _destination_reason(
        unit: TacticalUnitState,
        item: TacticalInventoryItemState,
        command: TacticalInventoryTransferCommand
) -> String:
    match command.target_kind:
        KIND_PRIMARY_HAND:
            if unit.inventory.primary_hand_item != null:
                return "Primary Hand is already occupied."
            if item.two_handed and unit.inventory.secondary_hand_item != null:
                return "A two-handed item requires both hands to be empty."
            return ""
        KIND_SECONDARY_HAND:
            if item.two_handed:
                return "Two-handed items must be equipped through Primary Hand."
            if (
                unit.inventory.primary_hand_item != null
                and unit.inventory.primary_hand_item.two_handed
            ):
                return "Secondary Hand is reserved by the two-handed Primary item."
            if unit.inventory.secondary_hand_item != null:
                return "Secondary Hand is already occupied."
            return ""
        KIND_BELT, KIND_BACKPACK:
            if (
                command.target_kind == KIND_BACKPACK
                and not TacticalItemProfile.backpack_allowed(item.display_name)
            ):
                return "That bulky item cannot be packed into a backpack."
            var position := _cell_to_position(
                command.target_kind,
                command.target_cell_index
            )
            if position.x < 0:
                return "Choose an empty cell in that inventory grid."
            if not unit.inventory.can_place_item(
                item,
                command.target_kind,
                position,
                item.item_id if command.source_kind == command.target_kind else &""
            ):
                if command.target_kind == KIND_BELT and not item.belt_allowed:
                    return "That item is too large or unsuitable for the Belt."
                return "The item does not fit in that position."
            return ""
        KIND_GROUND:
            if command.source_kind == KIND_GROUND:
                return "The item is already on the ground."
            return ""
        _:
            return "That inventory destination is unavailable."


func _take_source_item(
        unit: TacticalUnitState,
        command: TacticalInventoryTransferCommand
) -> TacticalInventoryItemState:
    if command.source_kind == KIND_GROUND:
        var ground_item := _state_store.state.remove_ground_item(
            command.source_item_id
        )
        if ground_item == null:
            return null
        return TacticalInventoryItemState.new(
            ground_item.item_id,
            ground_item.display_name,
            ground_item.weight_lb,
            ground_item.inventory_footprint,
            ground_item.two_handed,
            ground_item.belt_allowed,
            KIND_GROUND,
            Vector2i.ZERO,
            ground_item.source_label
        )

    return unit.inventory.take_item(
        command.source_item_id,
        command.source_kind
    )


func _place_target_item(
        unit: TacticalUnitState,
        command: TacticalInventoryTransferCommand,
        item: TacticalInventoryItemState
) -> bool:
    match command.target_kind:
        KIND_PRIMARY_HAND, KIND_SECONDARY_HAND:
            unit.inventory.set_hand_item(command.target_kind, item)
            return true
        KIND_BELT, KIND_BACKPACK:
            var position := _cell_to_position(
                command.target_kind,
                command.target_cell_index
            )
            return unit.inventory.add_grid_item(
                item,
                command.target_kind,
                position
            )
        KIND_GROUND:
            _drop_counter += 1
            var drop_id := StringName(
                "item.dropped.%s.%d"
                % [String(unit.unit_id), _drop_counter]
            )
            var dropped := TacticalItemState.new(
                drop_id,
                item.display_name,
                unit.grid_position,
                1,
                item.weight_lb,
                "Current tile",
                item.footprint,
                item.two_handed,
                item.belt_allowed
            )
            _state_store.state.add_ground_item(dropped)
            return true
    return false


func _restore_source_item(
        unit: TacticalUnitState,
        command: TacticalInventoryTransferCommand,
        item: TacticalInventoryItemState
) -> void:
    match command.source_kind:
        KIND_PRIMARY_HAND, KIND_SECONDARY_HAND:
            unit.inventory.set_hand_item(command.source_kind, item)
        KIND_BELT, KIND_BACKPACK:
            unit.inventory.add_grid_item(
                item,
                command.source_kind,
                item.grid_position
            )
        KIND_GROUND:
            var restored := TacticalItemState.new(
                item.item_id,
                item.display_name,
                unit.grid_position,
                1,
                item.weight_lb,
                item.source_label,
                item.footprint,
                item.two_handed,
                item.belt_allowed
            )
            _state_store.state.add_ground_item(restored)


func _cell_to_position(
        container_kind: StringName,
        cell_index: int
) -> Vector2i:
    if cell_index < 0:
        return Vector2i(-1, -1)

    var width := BACKPACK_WIDTH
    if container_kind == KIND_BELT:
        width = BELT_WIDTH

    return Vector2i(cell_index % width, int(cell_index / width))


func _normal_cost(
        command: TacticalInventoryTransferCommand,
        item: TacticalInventoryItemState
) -> ActionCost:
    if command.target_kind == KIND_GROUND:
        return ActionCost.fixed_capacity(0)

    if command.source_kind == KIND_GROUND:
        if command.target_kind == KIND_BACKPACK:
            return ActionCost.half_action()
        if item.weight_lb >= 15.0:
            return ActionCost.half_action()
        return ActionCost.minor_interaction()

    if command.source_kind == command.target_kind:
        if command.source_kind in [KIND_BELT, KIND_BACKPACK]:
            return ActionCost.fixed_capacity(0)

    if (
        command.source_kind == KIND_BELT
        and command.target_kind in [KIND_PRIMARY_HAND, KIND_SECONDARY_HAND]
    ):
        return ActionCost.quick_action()

    if (
        command.target_kind == KIND_BELT
        and command.source_kind in [KIND_PRIMARY_HAND, KIND_SECONDARY_HAND]
    ):
        return ActionCost.quick_action()

    if (
        command.source_kind == KIND_BACKPACK
        or command.target_kind == KIND_BACKPACK
    ):
        return ActionCost.half_action()

    return ActionCost.quick_action()


func _requires_additional_quick(
        command: TacticalInventoryTransferCommand
) -> bool:
    return (
        command.source_kind == KIND_GROUND
        and command.target_kind == KIND_BELT
    )


func _provokes(command: TacticalInventoryTransferCommand) -> bool:
    if command.source_kind == command.target_kind:
        return false
    return (
        command.source_kind == KIND_BACKPACK
        or command.target_kind == KIND_BACKPACK
    )


func _action_name(
        command: TacticalInventoryTransferCommand,
        item_name: String
) -> String:
    if command.source_kind == KIND_GROUND:
        if command.target_kind == KIND_BELT:
            return "Pick up %s and stow it on the Belt" % item_name
        if command.target_kind == KIND_BACKPACK:
            return "Pack %s from Items in Reach" % item_name
        return "Pick up %s" % item_name

    if command.target_kind == KIND_GROUND:
        return "Drop %s into Items in Reach" % item_name
    if command.target_kind == KIND_PRIMARY_HAND:
        return "Move %s to Primary Hand" % item_name
    if command.target_kind == KIND_SECONDARY_HAND:
        return "Move %s to Secondary Hand" % item_name
    if command.target_kind == KIND_BELT:
        return "Move %s to the Belt" % item_name
    if command.target_kind == KIND_BACKPACK:
        return "Move %s to the Backpack" % item_name
    return "Move %s" % item_name


func _format_success_message(
        transfer_preview: TacticalInventoryTransferPreview
) -> String:
    var cost_parts: Array[String] = []

    if transfer_preview.action_cost.is_quick_action():
        cost_parts.append("Quick Action")
    elif transfer_preview.cost_feet <= 0:
        cost_parts.append("free")
    else:
        cost_parts.append("%d ft" % transfer_preview.cost_feet)

    if transfer_preview.requires_quick_action:
        cost_parts.append("Quick Action")
    if transfer_preview.provokes:
        cost_parts.append("normally Provokes")

    return "%s — %s." % [
        transfer_preview.action_name,
        " + ".join(PackedStringArray(cost_parts)),
    ]
