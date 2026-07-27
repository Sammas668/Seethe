class_name TacticalPhaseState
extends RefCounted

const PLAYER_PHASE: StringName = &"player"
const WORLD_PHASE: StringName = &"world"

var round_number: int = 1
var current_phase: StringName = PLAYER_PHASE


func is_player_phase() -> bool:
    return current_phase == PLAYER_PHASE


func is_world_phase() -> bool:
    return current_phase == WORLD_PHASE


func begin_world_phase() -> void:
    current_phase = WORLD_PHASE


func begin_next_player_phase() -> void:
    round_number += 1
    current_phase = PLAYER_PHASE
