class_name TacticalMutationStep
extends RefCounted

var apply_change: Callable
var rollback_change: Callable
var failure_message: String = "Tactical mutation failed."
var failure_code: StringName = &"tactical_change_failed"


func _init(
		apply_value: Callable = Callable(),
		rollback_value: Callable = Callable(),
		failure_message_value: String = "Tactical mutation failed.",
		failure_code_value: StringName = &"tactical_change_failed"
) -> void:
	apply_change = apply_value
	rollback_change = rollback_value
	failure_message = failure_message_value
	failure_code = failure_code_value


func apply() -> OperationResult:
	if not apply_change.is_valid():
		return OperationResult.fail(
			&"tactical_change_invalid",
			"A staged tactical mutation has no apply function."
		)
	var outcome: Variant = apply_change.call()
	if outcome is OperationResult:
		return outcome as OperationResult
	if outcome is bool and not bool(outcome):
		return OperationResult.fail(failure_code, failure_message)
	return OperationResult.ok(self, "Tactical mutation applied.")


func rollback() -> void:
	if rollback_change.is_valid():
		rollback_change.call()
