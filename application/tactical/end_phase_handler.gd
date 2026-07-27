class_name EndPhaseHandler
extends RefCounted

var _state_store: TacticalStateStore


func _init(state_store: TacticalStateStore) -> void:
    _state_store = state_store


func begin_world_phase(command: EndPhaseCommand) -> OperationResult:
    if not _state_store.state.phase_state.is_player_phase():
        return OperationResult.fail(
            &"wrong_phase",
            "The Player Phase is not currently active."
        )
    if command.requested_from_phase != TacticalPhaseState.PLAYER_PHASE:
        return OperationResult.fail(
            &"invalid_request",
            "The phase-change request did not originate from the Player Phase."
        )

    _state_store.state.phase_state.begin_world_phase()
    _state_store.notify_changed(&"world_phase_started")
    return OperationResult.ok(null, "World Phase started.")


func complete_world_phase() -> OperationResult:
    if not _state_store.state.phase_state.is_world_phase():
        return OperationResult.fail(
            &"wrong_phase",
            "The World Phase is not currently active."
        )

    for unit: TacticalUnitState in _state_store.state.get_player_units():
        unit.refresh_for_new_round()

    _state_store.state.phase_state.begin_next_player_phase()
    _state_store.notify_changed(&"player_phase_started")
    return OperationResult.ok(
        null,
        "Round %d began. All friendly action budgets refreshed."
        % _state_store.state.phase_state.round_number
    )
