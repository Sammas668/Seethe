class_name OperationResult
extends RefCounted

var success: bool
var code: StringName
var message: String
var data: Variant


func _init(
		success_value: bool = false,
		code_value: StringName = &"unknown",
		message_value: String = "",
		data_value: Variant = null
) -> void:
	success = success_value
	code = code_value
	message = message_value
	data = data_value


static func ok(data_value: Variant = null, message_value: String = "") -> OperationResult:
	return OperationResult.new(true, &"ok", message_value, data_value)


static func fail(code_value: StringName, message_value: String) -> OperationResult:
	return OperationResult.new(false, code_value, message_value, null)
