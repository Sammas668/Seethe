class_name TacticalPhaseState
extends RefCounted

const PLAYER_PHASE: StringName = &"player"
const WORLD_PHASE: StringName = &"world"
# Stage 4.0.1 presents the existing World Phase as the enemy team's turn.
const ENEMY_TURN: StringName = WORLD_PHASE

var round_number: int = 1
var current_phase: StringName = PLAYER_PHASE


func is_player_phase() -> bool:
	return current_phase == PLAYER_PHASE


func is_world_phase() -> bool:
	return current_phase == WORLD_PHASE


func is_enemy_turn() -> bool:
	return current_phase == ENEMY_TURN


func begin_world_phase() -> void:
	current_phase = WORLD_PHASE


func begin_next_player_phase() -> void:
	round_number += 1
	current_phase = PLAYER_PHASE
