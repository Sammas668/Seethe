class_name TacticalValidationRule
extends RefCounted

var validator: Callable
var failure_message: String = "Tactical validation failed."
var failure_code: StringName = &"tactical_change_invalid"


func _init(
		validator_value: Callable = Callable(),
		failure_message_value: String = "Tactical validation failed.",
		failure_code_value: StringName = &"tactical_change_invalid"
) -> void:
	validator = validator_value
	failure_message = failure_message_value
	failure_code = failure_code_value


func validate() -> OperationResult:
	if not validator.is_valid():
		return OperationResult.ok(self, "No validation required.")
	var outcome: Variant = validator.call()
	if outcome is OperationResult:
		return outcome as OperationResult
	if outcome is String and not String(outcome).is_empty():
		return OperationResult.fail(failure_code, String(outcome))
	if outcome is bool and not bool(outcome):
		return OperationResult.fail(failure_code, failure_message)
	return OperationResult.ok(self, "Tactical validation passed.")
