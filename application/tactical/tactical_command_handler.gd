class_name TacticalCommandHandler
extends RefCounted

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition


func _init(
        state_store: TacticalStateStore,
        map_definition: TacticalMapDefinition
) -> void:
    _state_store = state_store
    _map_definition = map_definition


func execute_move(command: MoveCommand) -> OperationResult:
    if not _state_store.state.phase_state.is_player_phase():
        return OperationResult.fail(
            &"wrong_phase",
            "Movement is unavailable outside the Player Phase."
        )

    var unit := _state_store.state.get_unit(command.unit_id)
    if unit == null:
        return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")
    if unit.action_budget.ended_activation:
        return OperationResult.fail(
            &"unit_ended",
            "This unit is marked as ended. Reactivate it before moving."
        )

    var occupying_unit := _state_store.state.get_unit_at_tile(
        command.destination,
        command.unit_id
    )
    if occupying_unit != null:
        return OperationResult.fail(
            &"destination_occupied",
            "%s already occupies that destination." % occupying_unit.display_name
        )

    var path_result := MovementRules.find_path(
        unit.grid_position,
        command.destination,
        _map_definition,
        unit.diagonal_steps_used
    )

    if not path_result.success:
        return OperationResult.fail(&"invalid_path", path_result.failure_reason)

    if path_result.cost_feet > unit.action_budget.remaining_turn_capacity_feet:
        return OperationResult.fail(
            &"insufficient_capacity",
            "The route costs %d ft, but the unit has only %d ft remaining."
            % [
                path_result.cost_feet,
                unit.action_budget.remaining_turn_capacity_feet,
            ]
        )

    unit.grid_position = command.destination
    unit.action_budget.spend_normal_capacity(path_result.cost_feet)
    unit.diagonal_steps_used += path_result.diagonal_steps

    _state_store.notify_changed(&"unit_moved")
    return OperationResult.ok(path_result, "Movement completed.")


func mark_unit_ended(unit_id: StringName) -> OperationResult:
    if not _state_store.state.phase_state.is_player_phase():
        return OperationResult.fail(
            &"wrong_phase",
            "Units can only be ended during the Player Phase."
        )

    var unit := _state_store.state.get_unit(unit_id)
    if unit == null:
        return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")

    unit.mark_activation_ended()
    _state_store.notify_changed(&"unit_ended")
    return OperationResult.ok(
        null,
        "%s is marked as ended. Select it again to reactivate its unspent options."
        % unit.display_name
    )


func reactivate_unit(unit_id: StringName) -> OperationResult:
    if not _state_store.state.phase_state.is_player_phase():
        return OperationResult.fail(
            &"wrong_phase",
            "Units can only be reactivated during the Player Phase."
        )

    var unit := _state_store.state.get_unit(unit_id)
    if unit == null:
        return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")
    if not unit.action_budget.ended_activation:
        return OperationResult.ok(null, "%s is already active." % unit.display_name)

    unit.reactivate_without_refresh()
    _state_store.notify_changed(&"unit_reactivated")
    return OperationResult.ok(
        null,
        "%s reactivated with its existing unspent budget." % unit.display_name
    )
