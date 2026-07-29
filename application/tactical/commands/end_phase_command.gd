class_name EndPhaseCommand
extends RefCounted

var requested_from_phase: StringName


func _init(requested_from_phase_value: StringName = TacticalPhaseState.PLAYER_PHASE) -> void:
	requested_from_phase = requested_from_phase_value
