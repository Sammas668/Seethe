class_name TacticalStateStore
extends RefCounted

signal state_changed(reason: StringName)
signal state_changed_with_flags(reason: StringName, flags: TacticalInvalidationFlags)

var _state: TacticalState
var state: TacticalState:
	get:
		return _state

var _notification_depth: int = 0
var _deferred_commits: Array[Dictionary] = []
var _deferred_flush_scheduled: bool = false
var _lightweight_commits_since_full_audit: int = 0
var _development_full_audit_count: int = 0
var _development_full_audit_failures: int = 0

const DEVELOPMENT_FULL_AUDIT_INTERVAL: int = 32


func _init(initial_state: TacticalState) -> void:
	_state = initial_state


func is_delivering_notifications() -> bool:
	return _notification_depth > 0


func commit(
		change_set: TacticalChangeSet,
		map_definition: TacticalMapDefinition = null
) -> OperationResult:
	if change_set == null:
		return OperationResult.fail(
			&"tactical_change_missing",
			"No TacticalChangeSet was supplied."
		)
	if is_delivering_notifications():
		return OperationResult.fail(
			&"nested_tactical_commit_forbidden",
			(
				"Transaction %s attempted to commit while tactical state-change "
				+ "notifications were still being delivered. Use commit_after_notifications()."
			) % change_set.reason
		)
	if (
		_state != null
		and _state.pending_movement_reaction != null
		and not change_set.allows_commit_while_pending()
	):
		return OperationResult.fail(
			&"pending_tactical_decision",
			"Resolve the interrupted movement Reaction before issuing another tactical command."
		)
	var result: OperationResult = change_set.execute(_state, map_definition)
	if result.success:
		_run_development_full_state_audit_if_due(change_set, map_definition)
		change_set.publish_post_commit()
		_notification_depth += 1
		state_changed.emit(change_set.reason)
		state_changed_with_flags.emit(
			change_set.reason,
			change_set.invalidation_contract.duplicate_contract()
		)
		_notification_depth -= 1
		if _notification_depth == 0 and not _deferred_commits.is_empty():
			_schedule_deferred_flush()
	return result


func _run_development_full_state_audit_if_due(
		change_set: TacticalChangeSet,
		map_definition: TacticalMapDefinition
) -> void:
	if change_set == null or change_set.uses_full_state_validation():
		_lightweight_commits_since_full_audit = 0
		return
	_lightweight_commits_since_full_audit += 1
	if _lightweight_commits_since_full_audit < DEVELOPMENT_FULL_AUDIT_INTERVAL:
		return
	_lightweight_commits_since_full_audit = 0
	if not OS.is_debug_build():
		return
	_development_full_audit_count += 1
	var errors: Array[String] = _state.validate_all(map_definition)
	if errors.is_empty():
		return
	_development_full_audit_failures += 1
	push_error(
		"Development tactical-state audit failed after %s: %s"
		% [String(change_set.reason), errors[0]]
	)


func performance_snapshot() -> Dictionary:
	return {
		"lightweight_commits_since_full_audit": (
			_lightweight_commits_since_full_audit
		),
		"development_full_audit_count": _development_full_audit_count,
		"development_full_audit_failures": _development_full_audit_failures,
		"development_full_audit_interval": DEVELOPMENT_FULL_AUDIT_INTERVAL,
	}


func commit_after_notifications(
		change_set: TacticalChangeSet,
		map_definition: TacticalMapDefinition = null
) -> OperationResult:
	if change_set == null:
		return OperationResult.fail(
			&"tactical_change_missing",
			"No TacticalChangeSet was supplied."
		)
	if not is_delivering_notifications():
		return commit(change_set, map_definition)
	var deduplication_key: StringName = change_set.deferred_deduplication_key
	if not deduplication_key.is_empty():
		for index: int in range(_deferred_commits.size()):
			var existing: Dictionary = _deferred_commits[index]
			var existing_change: TacticalChangeSet = (
				existing.get("change_set") as TacticalChangeSet
			)
			if (
				existing_change != null
				and existing_change.deferred_deduplication_key == deduplication_key
			):
				# The caller has already accumulated the complete batch in the new
				# change set. Keep one derived commit for this notification cycle.
				_deferred_commits[index] = {
					"change_set": change_set,
					"map_definition": map_definition,
				}
				_schedule_deferred_flush()
				return OperationResult.deferred(
					change_set,
					"A compatible derived tactical update was replaced by the latest complete batch.",
					_state.revision if _state != null else -1
				)
	_deferred_commits.append({
		"change_set": change_set,
		"map_definition": map_definition,
	})
	_schedule_deferred_flush()
	return OperationResult.deferred(
		change_set,
		"The derived tactical update will commit after current state notifications finish.",
		_state.revision if _state != null else -1
	)


func _schedule_deferred_flush() -> void:
	if _deferred_flush_scheduled:
		return
	_deferred_flush_scheduled = true
	call_deferred("_flush_deferred_commits")


func _flush_deferred_commits() -> void:
	_deferred_flush_scheduled = false
	if is_delivering_notifications():
		_schedule_deferred_flush()
		return
	while not _deferred_commits.is_empty():
		var queued: Dictionary = _deferred_commits.pop_front()
		var change_set: TacticalChangeSet = queued.get("change_set") as TacticalChangeSet
		if change_set == null:
			continue
		change_set.expected_revision = _state.revision
		var result: OperationResult = commit(
			change_set,
			queued.get("map_definition") as TacticalMapDefinition
		)
		if not result.success:
			push_warning(result.message)
