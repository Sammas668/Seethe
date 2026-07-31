class_name TacticalStateStore
extends RefCounted

signal state_changed(reason: StringName)
signal state_changed_with_flags(reason: StringName, flags: TacticalInvalidationFlags)

var _state: TacticalState
var state: TacticalState:
	get:
		return _state


func _init(initial_state: TacticalState) -> void:
	_state = initial_state


func commit(
		change_set: TacticalChangeSet,
		map_definition: TacticalMapDefinition = null
) -> OperationResult:
	if change_set == null:
		return OperationResult.fail(
			&"tactical_change_missing",
			"No TacticalChangeSet was supplied."
		)
	var result: OperationResult = change_set.execute(_state, map_definition)
	if result.success:
		change_set.publish_post_commit()
		state_changed.emit(change_set.reason)
		state_changed_with_flags.emit(
			change_set.reason,
			change_set.invalidation_flags.duplicate_flags()
		)
	return result
