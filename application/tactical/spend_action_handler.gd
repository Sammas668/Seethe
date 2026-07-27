class_name SpendActionHandler
extends RefCounted

var _state_store: TacticalStateStore


func _init(state_store: TacticalStateStore) -> void:
    _state_store = state_store


func execute(command: SpendActionCommand) -> OperationResult:
    if not _state_store.state.phase_state.is_player_phase():
        return OperationResult.fail(
            &"wrong_phase",
            "Actions are unavailable outside the Player Phase."
        )

    var unit := _state_store.state.get_unit(command.unit_id)
    if unit == null:
        return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")

    var reason := ActionEconomyRules.unavailable_reason(unit, command.action_cost)
    if not reason.is_empty():
        return OperationResult.fail(&"action_unavailable", reason)

    var spent_feet := ActionEconomyRules.spend(unit, command.action_cost)
    if spent_feet < 0:
        return OperationResult.fail(
            &"action_failed",
            "The action could not be paid for."
        )

    _state_store.notify_changed(&"action_spent")

    if command.action_cost.is_quick_action():
        return OperationResult.ok(
            spent_feet,
            "%s used. The unit's normal capacity is unchanged." % command.action_name
        )

    return OperationResult.ok(
        spent_feet,
        "%s used for %d ft. %d ft remain."
        % [
            command.action_name,
            spent_feet,
            unit.action_budget.remaining_turn_capacity_feet,
        ]
    )
