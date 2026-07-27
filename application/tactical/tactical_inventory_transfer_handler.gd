class_name TacticalInventoryTransferHandler
extends RefCounted

var _state_store: TacticalStateStore


func _init(state_store: TacticalStateStore) -> void:
    _state_store = state_store


func preview(
        command: TacticalInventoryTransferCommand
) -> InventoryTransferPreview:
    if not _state_store.state.phase_state.is_player_phase():
        return InventoryTransferPreview.rejected(
            "Inventory changes are unavailable outside the Player Phase."
        )

    var unit := _state_store.state.get_unit(command.unit_id)
    if unit == null:
        return InventoryTransferPreview.rejected("The selected unit does not exist.")

    var item := _state_store.state.get_item(command.item_id)
    if item == null:
        return InventoryTransferPreview.rejected("The selected item does not exist.")

    if command.source_slot_id == command.target_slot_id:
        return InventoryTransferPreview.rejected("Choose a different destination.")

    var source_kind := TacticalInventoryState.slot_kind(command.source_slot_id)
    if source_kind == "ground":
        if not item.is_ground():
            return InventoryTransferPreview.rejected(
                "The item is no longer on the ground."
            )
        var offset := item.grid_position - unit.grid_position
        if absi(offset.x) > 1 or absi(offset.y) > 1:
            return InventoryTransferPreview.rejected(
                "The item is outside the selected unit's local access area."
            )
    else:
        if not item.is_owned_by(unit.unit_id):
            return InventoryTransferPreview.rejected(
                "The selected unit does not control that item."
            )
        if item.slot_id != command.source_slot_id:
            return InventoryTransferPreview.rejected(
                "The item has moved since it was selected."
            )

    var target_reason := TacticalInventoryRules.accepts_item(
        unit,
        item,
        command.target_slot_id
    )
    if not target_reason.is_empty():
        return InventoryTransferPreview.rejected(target_reason)

    var target_kind := TacticalInventoryState.slot_kind(command.target_slot_id)
    if source_kind == "ground" and target_kind != "ground":
        var projected_weight := unit.inventory.current_weight_lb + item.weight_lb
        if projected_weight > unit.inventory.maximum_weight_lb:
            return InventoryTransferPreview.rejected(
                "Picking up this item would exceed the unit's carrying limit."
            )

    var cost := TacticalInventoryRules.transfer_cost(
        item,
        command.source_slot_id,
        command.target_slot_id
    )
    var unavailable_reason := ActionEconomyRules.unavailable_reason(unit, cost)
    if not unavailable_reason.is_empty():
        return InventoryTransferPreview.rejected(unavailable_reason)

    var cost_feet := cost.resolved_normal_capacity_feet(
        unit.action_budget.maximum_turn_capacity_feet
    )
    var remaining_after := unit.action_budget.remaining_turn_capacity_feet - cost_feet

    return InventoryTransferPreview.accepted(
        TacticalInventoryRules.action_name(
            item,
            command.source_slot_id,
            command.target_slot_id
        ),
        cost,
        cost_feet,
        remaining_after
    )


func execute(command: TacticalInventoryTransferCommand) -> OperationResult:
    var preview_result := preview(command)
    if not preview_result.success:
        return OperationResult.fail(
            &"inventory_transfer_invalid",
            preview_result.reason
        )

    var unit := _state_store.state.get_unit(command.unit_id)
    var item := _state_store.state.get_item(command.item_id)
    if unit == null or item == null:
        return OperationResult.fail(
            &"inventory_transfer_missing_state",
            "The item transfer could not find its state."
        )

    if not item.is_ground():
        unit.inventory.clear_slot(item.slot_id)

    var target_kind := TacticalInventoryState.slot_kind(command.target_slot_id)
    if target_kind == "ground":
        item.set_ground(unit.grid_position)
    else:
        unit.inventory.set_item_id(command.target_slot_id, item.item_id)
        item.set_unit_slot(unit.unit_id, command.target_slot_id)

    var spent_feet := ActionEconomyRules.spend(unit, preview_result.action_cost)
    if spent_feet < 0:
        return OperationResult.fail(
            &"inventory_transfer_payment_failed",
            "The item transfer cost could not be paid."
        )

    _state_store.state.recalculate_inventory_weight(unit)
    _state_store.notify_changed(&"inventory_transferred")

    var cost_text := "free"
    if preview_result.action_cost.is_quick_action():
        cost_text = "Quick Action"
    elif preview_result.cost_feet > 0:
        cost_text = "%d ft" % preview_result.cost_feet

    return OperationResult.ok(
        item,
        "%s — %s." % [preview_result.action_name, cost_text]
    )
