class_name SprintMoveHandler
extends RefCounted

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition


func _init(
        state_store: TacticalStateStore,
        map_definition: TacticalMapDefinition
) -> void:
    _state_store = state_store
    _map_definition = map_definition


func preview(unit: TacticalUnitState, destination: Vector2i) -> MovementPathResult:
    if unit == null:
        return MovementPathResult.failed("No unit is selected.")
    if unit.action_budget.ended_activation:
        return MovementPathResult.failed("This unit is marked as ended.")
    if unit.action_budget.has_spent_normal_capacity():
        return MovementPathResult.failed(
            "Sprint is a Full Action and requires an untouched normal-action budget."
        )

    var path_result := MovementRules.find_path(
        unit.grid_position,
        destination,
        _map_definition,
        unit.diagonal_steps_used
    )
    if not path_result.success:
        return path_result

    for tile: Vector2i in path_result.path:
        if _map_definition.is_difficult(tile):
            return MovementPathResult.failed(
                "The prototype Sprint cannot cross difficult terrain."
            )

    var sprint_allowance := int(floor(unit.action_budget.maximum_turn_capacity_feet * 1.5 / 5.0)) * 5
    if path_result.cost_feet > sprint_allowance:
        return MovementPathResult.failed(
            "Sprint route costs %d ft; the unit's Sprint limit is %d ft."
            % [path_result.cost_feet, sprint_allowance]
        )

    return path_result


func execute(command: SprintMoveCommand) -> OperationResult:
    if not _state_store.state.phase_state.is_player_phase():
        return OperationResult.fail(
            &"wrong_phase",
            "Sprint is unavailable outside the Player Phase."
        )

    var unit := _state_store.state.get_unit(command.unit_id)
    if unit == null:
        return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")

    var occupying_unit := _state_store.state.get_unit_at_tile(
        command.destination,
        command.unit_id
    )
    if occupying_unit != null:
        return OperationResult.fail(
            &"destination_occupied",
            "%s already occupies that destination." % occupying_unit.display_name
        )

    var path_result := preview(unit, command.destination)
    if not path_result.success:
        return OperationResult.fail(&"invalid_sprint", path_result.failure_reason)

    unit.grid_position = command.destination
    unit.diagonal_steps_used += path_result.diagonal_steps
    unit.action_budget.spend_normal_capacity(
        unit.action_budget.maximum_turn_capacity_feet
    )
    unit.action_budget.reaction_available = false

    _state_store.notify_changed(&"unit_sprinted")
    return OperationResult.ok(
        path_result,
        "%s sprinted %d ft and spent its Full Action. Reaction lost until refresh."
        % [unit.display_name, path_result.cost_feet]
    )
