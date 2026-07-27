class_name TacticalStateStore
extends RefCounted

signal state_changed(reason: StringName)

var state: TacticalState


func _init(initial_state: TacticalState) -> void:
    state = initial_state


func notify_changed(reason: StringName) -> void:
    state_changed.emit(reason)
