class_name TacticalChangeSet
extends RefCounted

var reason: StringName = &"tactical_change"
var expected_revision: int = 0
var invalidation_contract: TacticalInvalidationContract
var invalidation_flags: TacticalInvalidationFlags:
	get:
		return invalidation_contract
var deferred_deduplication_key: StringName = &""
var _steps: Array[TacticalMutationStep] = []
var _validators: Array[TacticalValidationRule] = []
var _post_commit_callbacks: Array[Callable] = []
var _synchronise_body_items_before_validation: bool = true
var _validate_full_state_after_steps: bool = true
var _allow_while_pending: bool = false

static var _commit_count: int = 0
static var _lightweight_commit_count: int = 0
static var _last_snapshot_usec: int = 0
static var _last_validation_usec: int = 0
static var _total_snapshot_usec: int = 0
static var _total_validation_usec: int = 0


func _init(
		reason_value: StringName = &"tactical_change",
		expected_revision_value: int = 0,
		contract_value: TacticalInvalidationContract = null
) -> void:
	reason = reason_value
	expected_revision = expected_revision_value
	invalidation_contract = (
		contract_value.duplicate_contract() if contract_value != null else null
	)


func set_invalidation_contract(contract_value: TacticalInvalidationContract) -> void:
	invalidation_contract = (
		contract_value.duplicate_contract() if contract_value != null else null
	)


func set_invalidation_flags(flags: TacticalInvalidationFlags) -> void:
	# Deprecated migration bridge. Production validation rejects callers.
	if flags == null:
		invalidation_contract = null
		return
	var contract := TacticalInvalidationContract.new()
	contract.occupancy_changed = flags.occupancy_changed
	contract.visibility_changed = flags.visibility_changed
	contract.exploration_changed = flags.exploration_changed
	contract.geometry_changed = flags.geometry_changed
	contract.environment_visuals_changed = flags.environment_visuals_changed
	contract.inventory_changed = flags.inventory_changed
	contract.initiative_changed = flags.initiative_changed
	contract.token_status_changed = flags.token_status_changed
	contract.action_budget_changed = flags.action_budget_changed
	contract.justification = "Legacy explicit flag bridge."
	invalidation_contract = contract


func set_deferred_deduplication_key(value: StringName) -> void:
	deferred_deduplication_key = value


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


func set_allow_while_pending(value: bool = true) -> void:
	_allow_while_pending = value


func allows_commit_while_pending() -> bool:
	return _allow_while_pending


func set_commit_validation_policy(
		synchronise_body_items: bool,
		validate_full_state: bool
) -> void:
	_synchronise_body_items_before_validation = synchronise_body_items
	_validate_full_state_after_steps = validate_full_state


func uses_full_state_validation() -> bool:
	return _validate_full_state_after_steps


func synchronises_body_items_before_validation() -> bool:
	return _synchronise_body_items_before_validation


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
	if invalidation_contract == null:
		return OperationResult.fail(
			&"tactical_invalidation_contract_missing",
			"Transaction %s has no explicit invalidation contract." % reason
		)
	var contract_errors: Array[String] = invalidation_contract.validate_contract()
	if not contract_errors.is_empty():
		return OperationResult.fail(
			&"tactical_invalidation_contract_invalid",
			contract_errors[0]
		)
	if state.revision != expected_revision:
		return OperationResult.fail(
			&"tactical_revision_conflict",
			"Tactical state changed from revision %d to %d before commit."
			% [expected_revision, state.revision]
		)

	var snapshot_started_usec: int = Time.get_ticks_usec()
	var transaction_snapshot := TacticalTransactionSnapshot.capture(
		state,
		_synchronise_body_items_before_validation
		or _validate_full_state_after_steps
	)
	_last_snapshot_usec = maxi(
		0,
		Time.get_ticks_usec() - snapshot_started_usec
	)
	_total_snapshot_usec += _last_snapshot_usec
	_commit_count += 1
	if not _synchronise_body_items_before_validation and not _validate_full_state_after_steps:
		_lightweight_commit_count += 1
	var body_representation_before: Dictionary = {}
	if _synchronise_body_items_before_validation:
		body_representation_before = state.body_item_representation_snapshot()
	var applied_steps: Array[TacticalMutationStep] = []
	for step: TacticalMutationStep in _steps:
		var step_result: OperationResult = step.apply()
		if not step_result.success:
			step.rollback()
			_rollback(state, applied_steps, body_representation_before, transaction_snapshot)
			return step_result
		applied_steps.append(step)

	if _synchronise_body_items_before_validation:
		state.synchronise_body_items(map_definition)

	var validation_started_usec: int = Time.get_ticks_usec()
	for rule: TacticalValidationRule in _validators:
		var validation_result: OperationResult = rule.validate()
		if not validation_result.success:
			_rollback(state, applied_steps, body_representation_before, transaction_snapshot)
			return validation_result

	if _validate_full_state_after_steps:
		var invariant_errors: Array[String] = state.validate_all(map_definition)
		if not invariant_errors.is_empty():
			_rollback(state, applied_steps, body_representation_before, transaction_snapshot)
			return OperationResult.fail(
				&"tactical_invariant_failed",
				"Tactical change rolled back: %s" % invariant_errors[0]
			)

	_last_validation_usec = maxi(
		0,
		Time.get_ticks_usec() - validation_started_usec
	)
	_total_validation_usec += _last_validation_usec
	state.revision = expected_revision + 1
	return OperationResult.committed(
		self,
		"Tactical change committed.",
		state.revision
	)


static func performance_snapshot() -> Dictionary:
	return {
		"commit_count": _commit_count,
		"lightweight_commit_count": _lightweight_commit_count,
		"last_snapshot_usec": _last_snapshot_usec,
		"last_validation_usec": _last_validation_usec,
		"total_snapshot_usec": _total_snapshot_usec,
		"total_validation_usec": _total_validation_usec,
	}


func _rollback(
		state: TacticalState,
		applied_steps: Array[TacticalMutationStep],
		body_representation_before: Dictionary,
		transaction_snapshot: TacticalTransactionSnapshot
) -> void:
	for index: int in range(applied_steps.size() - 1, -1, -1):
		applied_steps[index].rollback()
	if _synchronise_body_items_before_validation:
		state.restore_body_item_representation(body_representation_before)
		state.synchronise_body_items()
		state.rebuild_unit_occupancy()
		state.rebuild_ground_item_index()
	transaction_snapshot.restore_revisions(state)
	# Disposable service caches may be cleared by listeners after the failed
	# command. Authoritative revision/signature identity is restored here.
