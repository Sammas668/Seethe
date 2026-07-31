class_name TacticalChangeSet
extends RefCounted

var reason: StringName = &"tactical_change"
var expected_revision: int = 0
var invalidation_flags: TacticalInvalidationFlags
var _steps: Array[TacticalMutationStep] = []
var _validators: Array[TacticalValidationRule] = []
var _post_commit_callbacks: Array[Callable] = []


func _init(
		reason_value: StringName = &"tactical_change",
		expected_revision_value: int = 0
) -> void:
	reason = reason_value
	expected_revision = expected_revision_value
	invalidation_flags = TacticalInvalidationFlags.for_reason(reason_value)


func set_invalidation_flags(flags: TacticalInvalidationFlags) -> void:
	invalidation_flags = (
		flags.duplicate_flags()
		if flags != null
		else TacticalInvalidationFlags.for_reason(reason)
	)


func stage(
		apply_change: Callable,
		rollback_change: Callable,
		failure_message: String,
		failure_code_value: StringName = &"tactical_change_failed"
) -> void:
	_steps.append(
		TacticalMutationStep.new(
			apply_change,
			rollback_change,
			failure_message,
			failure_code_value
		)
	)


func require(
		validator: Callable,
		failure_message: String,
		failure_code_value: StringName = &"tactical_change_invalid"
) -> void:
	_validators.append(
		TacticalValidationRule.new(
			validator,
			failure_message,
			failure_code_value
		)
	)


func after_commit(callback: Callable) -> void:
	if callback.is_valid():
		_post_commit_callbacks.append(callback)


func publish_post_commit() -> void:
	for callback: Callable in _post_commit_callbacks:
		if callback.is_valid():
			callback.call()


func execute(
		state: TacticalState,
		map_definition: TacticalMapDefinition = null
) -> OperationResult:
	if state == null:
		return OperationResult.fail(
			&"tactical_state_missing",
			"A tactical state is required to commit changes."
		)
	if state.revision != expected_revision:
		return OperationResult.fail(
			&"tactical_revision_conflict",
			"Tactical state changed from revision %d to %d before commit."
			% [expected_revision, state.revision]
		)

	var body_representation_before: Dictionary = (
		state.body_item_representation_snapshot()
	)
	var applied_steps: Array[TacticalMutationStep] = []
	for step: TacticalMutationStep in _steps:
		var step_result: OperationResult = step.apply()
		if not step_result.success:
			step.rollback()
			_rollback(state, applied_steps, body_representation_before)
			return step_result
		applied_steps.append(step)

	# Life-state mutations create/remove/update their one real body item before
	# validators and invariants inspect occupancy or inventory ownership.
	state.synchronise_body_items(map_definition)

	for rule: TacticalValidationRule in _validators:
		var validation_result: OperationResult = rule.validate()
		if not validation_result.success:
			_rollback(state, applied_steps, body_representation_before)
			return validation_result

	var invariant_errors: Array[String] = state.validate_all(map_definition)
	if not invariant_errors.is_empty():
		_rollback(state, applied_steps, body_representation_before)
		return OperationResult.fail(
			&"tactical_invariant_failed",
			"Tactical change rolled back: %s" % invariant_errors[0]
		)

	state.revision = expected_revision + 1
	return OperationResult.ok(self, "Tactical change committed.")


func _rollback(
		state: TacticalState,
		applied_steps: Array[TacticalMutationStep],
		body_representation_before: Dictionary
) -> void:
	for index: int in range(applied_steps.size() - 1, -1, -1):
		applied_steps[index].rollback()
	state.revision = expected_revision
	state.restore_body_item_representation(body_representation_before)
	state.synchronise_body_items()
	state.rebuild_unit_occupancy()
	state.rebuild_ground_item_index()
