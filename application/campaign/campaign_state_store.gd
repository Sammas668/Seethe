class_name CampaignStateStore
extends RefCounted

signal state_changed(reason: StringName)

var _campaign: CampaignState
var _repository: RefCounted
var _catalogue: ContentCatalogue

var campaign: CampaignState:
	get:
		return _campaign


func _init() -> void:
	pass


func configure(
		initial_campaign: CampaignState,
		repository: RefCounted = null,
		catalogue: ContentCatalogue = null
) -> void:
	_campaign = initial_campaign if initial_campaign != null else CampaignState.new()
	_repository = repository
	_catalogue = catalogue


func current_campaign() -> CampaignState:
	return _campaign


func commit(change_set: RefCounted) -> OperationResult:
	if change_set == null or not change_set.has_method("apply_to"):
		return OperationResult.fail(
			&"campaign_change_missing",
			"No valid CampaignChangeSet was supplied."
		)
	if _campaign == null:
		return OperationResult.fail(
			&"campaign_state_missing",
			"No active campaign state is available."
		)

	var expected_revision: int = int(change_set.get("expected_revision"))
	if _campaign.revision != expected_revision:
		return OperationResult.fail(
			&"campaign_revision_conflict",
			"Campaign state changed from revision %d to %d before commit."
			% [expected_revision, _campaign.revision]
		)

	var candidate: CampaignState = CampaignState.from_dictionary(
		_campaign.to_dictionary()
	)
	var applied_value: Variant = change_set.call("apply_to", candidate)
	var applied: OperationResult = applied_value as OperationResult
	if applied == null:
		return OperationResult.fail(
			&"campaign_change_invalid",
			"CampaignChangeSet returned no OperationResult."
		)
	if not applied.success:
		return applied

	var original_data: Dictionary = _campaign.to_dictionary()
	var candidate_data: Dictionary = candidate.to_dictionary()
	original_data["revision"] = expected_revision
	candidate_data["revision"] = expected_revision
	if original_data == candidate_data:
		return OperationResult.new(
			true,
			&"no_change",
			"Campaign candidate contained no state changes.",
			_campaign
		)

	# One successful campaign operation advances the root exactly once, even
	# when candidate mutators increment their own local revision counters.
	candidate.revision = expected_revision + 1
	var validation_errors: Array[String] = candidate.validate_campaign()
	if _catalogue != null:
		validation_errors.append_array(
			CampaignItemValidator.validate_campaign(candidate, _catalogue)
		)
	if not validation_errors.is_empty():
		return OperationResult.fail(
			&"campaign_invariant_failed",
			"Campaign candidate rejected: %s" % validation_errors[0]
		)

	# Persistence is part of the commit. The active root is replaced only after
	# the complete candidate has been validated and safely written.
	if _repository != null:
		if not _repository.has_method("save_campaign"):
			return OperationResult.fail(
				&"campaign_repository_invalid",
				"The configured campaign repository cannot save campaigns."
			)
		var saved_value: Variant = _repository.call("save_campaign", candidate)
		if not bool(saved_value):
			return OperationResult.fail(
				&"campaign_save_failed",
				"The validated campaign candidate could not be saved."
			)

	_campaign = candidate
	var reason: StringName = StringName(change_set.get("reason"))
	state_changed.emit(reason)
	return OperationResult.ok(
		_campaign,
		"Campaign change committed at revision %d." % _campaign.revision
	)
