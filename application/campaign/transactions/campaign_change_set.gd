class_name CampaignChangeSet
extends RefCounted

var reason: StringName = &"campaign_change"
var expected_revision: int = 0
var _mutations: Array[Callable] = []


func _init() -> void:
	pass


func configure(
		reason_value: StringName,
		expected_revision_value: int
) -> void:
	reason = reason_value
	expected_revision = expected_revision_value


func stage(mutation: Callable) -> void:
	if mutation.is_valid():
		_mutations.append(mutation)


func apply_to(candidate: CampaignState) -> OperationResult:
	if candidate == null:
		return OperationResult.fail(
			&"campaign_candidate_missing",
			"A candidate campaign state is required."
		)

	for mutation: Callable in _mutations:
		if not mutation.is_valid():
			return OperationResult.fail(
				&"campaign_mutation_invalid",
				"A staged campaign mutation is no longer callable."
			)

		var raw_result: Variant = mutation.call(candidate)
		if raw_result is OperationResult:
			var operation_result: OperationResult = raw_result as OperationResult
			if not operation_result.success:
				return operation_result
		elif raw_result is bool and not bool(raw_result):
			return OperationResult.fail(
				&"campaign_mutation_failed",
				"A staged campaign mutation was rejected."
			)

	return OperationResult.ok(candidate, "Campaign candidate prepared.")
