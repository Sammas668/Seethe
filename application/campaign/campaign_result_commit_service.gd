class_name CampaignResultCommitService
extends RefCounted

const CAMPAIGN_CHANGE_SET_SCRIPT: Script = preload(
	"res://application/campaign/transactions/campaign_change_set.gd"
)

var _state_store: RefCounted
var _catalogue: ContentCatalogue


func _init() -> void:
	pass


func configure(
		state_store: RefCounted,
		catalogue: ContentCatalogue = null
) -> void:
	_state_store = state_store
	_catalogue = catalogue


func commit_result(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		catalogue_override: ContentCatalogue = null
) -> OperationResult:
	if result == null or setup == null or _state_store == null:
		return OperationResult.fail(
			&"mission_result_missing",
			"A mission result, finalized mission setup and campaign store are required."
		)
	if not setup.is_finalized():
		return OperationResult.fail(
			&"mission_setup_not_finalized",
			"Mission results cannot commit against a mutable setup draft."
		)
	if not _state_store.has_method("current_campaign"):
		return OperationResult.fail(
			&"campaign_store_invalid",
			"The configured campaign store has no current campaign."
		)

	var campaign_value: Variant = _state_store.call("current_campaign")
	var campaign: CampaignState = campaign_value as CampaignState
	if campaign == null:
		return OperationResult.fail(
			&"campaign_state_missing",
			"No active campaign state is available."
		)

	var basic_errors: Array[String] = result.validate_result()
	if not basic_errors.is_empty():
		return OperationResult.fail(&"mission_result_invalid", basic_errors[0])

	if campaign.has_applied_result(result.result_id):
		return OperationResult.new(
			true,
			&"already_applied",
			"Mission result %s was already applied." % result.result_id,
			campaign
		)

	if campaign.revision != result.source_campaign_revision:
		return OperationResult.fail(
			&"campaign_revision_conflict",
			"Campaign revision changed from %d to %d while mission %s was active."
			% [result.source_campaign_revision, campaign.revision, result.mission_id]
		)

	var catalogue: ContentCatalogue = (
		catalogue_override if catalogue_override != null else _catalogue
	)
	var validation_errors: Array[String] = MissionResultValidator.validate(
		result,
		setup,
		campaign,
		catalogue
	)
	if not validation_errors.is_empty():
		return OperationResult.fail(
			&"mission_result_context_invalid",
			validation_errors[0]
		)

	var changes: RefCounted = CAMPAIGN_CHANGE_SET_SCRIPT.new() as RefCounted
	changes.set("reason", &"mission_result_committed")
	changes.set("expected_revision", campaign.revision)
	changes.call(
		"stage",
		Callable(self, "_apply_result_to_candidate").bind(result)
	)
	var committed_value: Variant = _state_store.call("commit", changes)
	var committed: OperationResult = committed_value as OperationResult
	if committed == null:
		return OperationResult.fail(
			&"campaign_commit_invalid",
			"CampaignStateStore returned no OperationResult."
		)
	if committed.success:
		committed.message = "Mission result %s committed once." % result.result_id
	return committed


func _apply_result_to_candidate(
		candidate: CampaignState,
		result: MissionResult
) -> OperationResult:
	for character_result: MissionCharacterResult in result.get_character_results():
		var character: PersistentCharacterState = candidate.get_character(
			character_result.character_id
		)
		if character == null:
			continue
		if character.persistence_scope == PersistentCharacterState.PERSISTENCE_MISSION:
			continue
		_apply_character_progression(character, character_result)
		_reconcile_character_item_ownership(candidate, character_result)

	for entry: Dictionary in result.extracted_item_entries:
		var item: CampaignItemState = CampaignItemState.from_dictionary(entry)
		if item.item_id.is_empty() or item.definition_id.is_empty():
			return OperationResult.fail(
				&"mission_result_item_invalid",
				"An extracted mission item could not be restored to the campaign."
			)
		candidate.upsert_item(item)

	if not candidate.mark_result_applied(result.result_id):
		return OperationResult.fail(
			&"mission_result_apply_failed",
			"The mission result could not be marked as applied."
		)
	return OperationResult.ok(candidate, "Mission result applied to candidate.")


func _apply_character_progression(
		character: PersistentCharacterState,
		result: MissionCharacterResult
) -> void:
	if result.was_deployed:
		character.deployment_count += 1
		character.revision += 1
	if result.xp_awarded > 0 and result.survived:
		character.award_xp(result.xp_awarded)
	for injury: String in result.injury_entries:
		if not character.injury_entries.has(injury):
			character.add_injury(injury)
	if not result.survived:
		character.is_dead = true
		character.revision += 1
	if not result.history_entry.strip_edges().is_empty():
		character.add_history(result.history_entry)


func _reconcile_character_item_ownership(
		campaign: CampaignState,
		result: MissionCharacterResult
) -> void:
	if not result.was_deployed:
		return
	var retained_ids: Dictionary = {}
	if result.survived and result.extracted:
		for item_id: StringName in result.equipment_item_ids:
			retained_ids[item_id] = true
	for existing_item: CampaignItemState in campaign.items_for_character(
		result.character_id
	):
		if retained_ids.has(existing_item.item_id):
			continue
		campaign.remove_item(existing_item.item_id)
