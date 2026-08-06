class_name OperationResult
extends RefCounted

const STATUS_REJECTED_BEFORE_COMMIT: StringName = &"rejected_before_commit"
const STATUS_COMMITTED: StringName = &"committed"
const STATUS_COMMITTED_WITH_WARNING: StringName = &"committed_with_warning"
const STATUS_NO_CHANGE: StringName = &"no_change"
const STATUS_PENDING: StringName = &"pending"
const STATUS_DEFERRED: StringName = &"deferred"

var success: bool
var code: StringName
var message: String
var data: Variant
var commit_status: StringName
var warning_codes: Array[StringName] = []
var committed_revision: int = -1


func _init(
		success_value: bool = false,
		code_value: StringName = &"unknown",
		message_value: String = "",
		data_value: Variant = null,
		commit_status_value: StringName = STATUS_REJECTED_BEFORE_COMMIT,
		warning_codes_value: Array[StringName] = [],
		committed_revision_value: int = -1
) -> void:
	success = success_value
	code = code_value
	message = message_value
	data = data_value
	commit_status = commit_status_value
	warning_codes = warning_codes_value.duplicate()
	committed_revision = committed_revision_value


# Kept for compatibility with older handlers. New code should prefer committed(),
# no_change(), pending(), or deferred() so callers can distinguish outcomes.
static func ok(data_value: Variant = null, message_value: String = "") -> OperationResult:
	return OperationResult.new(
		true,
		&"ok",
		message_value,
		data_value,
		STATUS_COMMITTED
	)


static func committed(
		data_value: Variant,
		message_value: String,
		committed_revision_value: int
) -> OperationResult:
	return OperationResult.new(
		true,
		&"ok",
		message_value,
		data_value,
		STATUS_COMMITTED,
		[],
		committed_revision_value
	)


static func no_change(
		data_value: Variant = null,
		message_value: String = ""
) -> OperationResult:
	return OperationResult.new(
		true,
		&"no_change",
		message_value,
		data_value,
		STATUS_NO_CHANGE
	)


static func pending(
		code_value: StringName,
		data_value: Variant,
		message_value: String,
		committed_revision_value: int = -1
) -> OperationResult:
	return OperationResult.new(
		true,
		code_value,
		message_value,
		data_value,
		STATUS_PENDING,
		[],
		committed_revision_value
	)


static func deferred(
		data_value: Variant = null,
		message_value: String = "",
		committed_revision_value: int = -1
) -> OperationResult:
	return OperationResult.new(
		true,
		&"deferred",
		message_value,
		data_value,
		STATUS_DEFERRED,
		[],
		committed_revision_value
	)


static func committed_with_warning(
		data_value: Variant,
		message_value: String,
		committed_revision_value: int,
		warning_codes_value: Array[StringName]
) -> OperationResult:
	return OperationResult.new(
		true,
		&"committed_with_warning",
		message_value,
		data_value,
		STATUS_COMMITTED_WITH_WARNING,
		warning_codes_value,
		committed_revision_value
	)


static func fail(code_value: StringName, message_value: String) -> OperationResult:
	return OperationResult.new(
		false,
		code_value,
		message_value,
		null,
		STATUS_REJECTED_BEFORE_COMMIT
	)
