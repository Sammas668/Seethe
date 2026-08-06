class_name CaptiveService
extends RefCounted

const CHANGE_SET_SCRIPT: Script = preload(
	"res://application/campaign/transactions/campaign_change_set.gd"
)

var _state_store: RefCounted
var _prison_capacity_service: PrisonCapacityService
var _policy_registry: CaptivePolicyRegistry
var _region_registry: RegionDefinitionRegistry
var _catalogue: ContentCatalogue


func configure(
	state_store: RefCounted,
	prison_capacity_service: PrisonCapacityService,
	policy_registry: CaptivePolicyRegistry,
	region_registry: RegionDefinitionRegistry,
	catalogue: ContentCatalogue = null
) -> void:
	_state_store = state_store
	_prison_capacity_service = prison_capacity_service
	_policy_registry = policy_registry
	_region_registry = region_registry
	_catalogue = catalogue


func prison_snapshot(campaign: CampaignState) -> Dictionary:
	var capacity: Dictionary = (
		_prison_capacity_service.capacity_snapshot(campaign)
		if _prison_capacity_service != null
		else {}
	)
	var captives: Array[Dictionary] = []
	if campaign != null:
		for captive: CampaignCaptiveState in campaign.get_captives():
			if not captive.is_active_custody():
				continue
			captives.append(_captive_snapshot(campaign, captive))
	captives.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_incoming: bool = String(a.get("status", "")) == "incoming"
		var b_incoming: bool = String(b.get("status", "")) == "incoming"
		if a_incoming != b_incoming:
			return not a_incoming
		return String(a.get("display_name", "")) < String(b.get("display_name", ""))
	)
	capacity["captives"] = captives
	var action_reports: Array[Dictionary] = []
	if campaign != null:
		for raw_report: Variant in campaign.captive_action_reports_by_id.values():
			if raw_report is Dictionary:
				action_reports.append((raw_report as Dictionary).duplicate(true))
	action_reports.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("created_tick", 0)) > int(b.get("created_tick", 0))
	)
	if action_reports.size() > 5:
		action_reports.resize(5)
	capacity["action_reports"] = action_reports
	return capacity


func preview_release(captive_id: StringName) -> OperationResult:
	var campaign: CampaignState = _current_campaign()
	var captive: CampaignCaptiveState = campaign.get_captive(captive_id) if campaign != null else null
	if captive == null:
		return OperationResult.fail(&"captive_missing", "The selected captive no longer exists.")
	if not captive.is_held() or not captive.is_living() or not captive.release_allowed:
		return OperationResult.fail(&"captive_release_unavailable", "This captive cannot currently be released.")
	return OperationResult.ok(_captive_snapshot(campaign, captive), "Release is available.")


func release_captive(captive_id: StringName) -> OperationResult:
	return _commit_action(&"captive_released", captive_id, &"release")


func preview_ransom(captive_id: StringName) -> OperationResult:
	var campaign: CampaignState = _current_campaign()
	var captive: CampaignCaptiveState = campaign.get_captive(captive_id) if campaign != null else null
	if captive == null:
		return OperationResult.fail(&"captive_missing", "The selected captive no longer exists.")
	if not captive.is_held() or not captive.is_living() or not captive.ransom_allowed or captive.ransom_value <= 0:
		return OperationResult.fail(&"captive_ransom_unavailable", "No valid ransom channel exists for this captive.")
	if _assigned_prison_condition(campaign, captive) == StrongholdFacilityState.CONDITION_DISABLED:
		return OperationResult.fail(&"prison_disabled", "Ransom processing is suspended until the assigned Prison is repaired.")
	return OperationResult.ok(_captive_snapshot(campaign, captive), "Ransom is available.")


func ransom_captive(captive_id: StringName) -> OperationResult:
	return _commit_action(&"captive_ransomed", captive_id, &"ransom")


func preview_interrogate(captive_id: StringName) -> OperationResult:
	var campaign: CampaignState = _current_campaign()
	var captive: CampaignCaptiveState = campaign.get_captive(captive_id) if campaign != null else null
	if captive == null:
		return OperationResult.fail(&"captive_missing", "The selected captive no longer exists.")
	if not captive.is_held() or not captive.is_living():
		return OperationResult.fail(&"captive_interrogation_unavailable", "Only a living held captive can be interrogated.")
	if captive.interrogation_completed:
		return OperationResult.fail(&"captive_already_interrogated", "This captive has already yielded their available organisational knowledge.")
	if _assigned_prison_condition(campaign, captive) == StrongholdFacilityState.CONDITION_DISABLED:
		return OperationResult.fail(&"prison_disabled", "Interrogation is suspended until the assigned Prison is repaired.")
	var source_id: StringName = _interrogation_source_for_captive(captive)
	if source_id.is_empty():
		return OperationResult.fail(&"captive_no_research_source", "This captive has no authored Research or contact knowledge to reveal.")
	return OperationResult.ok({
		"captive_id": captive.captive_id,
		"research_source_id": source_id,
		"already_known": campaign.has_research_source(source_id),
	}, "Interrogation can reveal an authored Research source.")


func interrogate_captive(captive_id: StringName) -> OperationResult:
	return _commit_action(&"captive_interrogated", captive_id, &"interrogate")


func _commit_action(reason: StringName, captive_id: StringName, action_id: StringName) -> OperationResult:
	var campaign: CampaignState = _current_campaign()
	if campaign == null or _state_store == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is available.")
	var change_set: RefCounted = CHANGE_SET_SCRIPT.new()
	change_set.set("reason", reason)
	change_set.set("expected_revision", campaign.revision)
	change_set.call("stage", Callable(self, "_apply_action_candidate").bind(captive_id, action_id))
	var committed: Variant = _state_store.call("commit", change_set)
	return committed as OperationResult if committed is OperationResult else OperationResult.fail(
		&"captive_action_commit_failed", "The captive action produced no campaign result."
	)


func _apply_action_candidate(
	campaign: CampaignState,
	captive_id: StringName,
	action_id: StringName
) -> OperationResult:
	var captive: CampaignCaptiveState = campaign.get_captive(captive_id)
	if captive == null:
		return OperationResult.fail(&"captive_missing", "The selected captive no longer exists.")
	if not captive.is_held() or not captive.is_living():
		return OperationResult.fail(&"captive_not_held", "Only a living held captive can be processed.")
	match action_id:
		&"release":
			if not captive.release_allowed:
				return OperationResult.fail(&"captive_release_unavailable", "This captive cannot be released.")
			var report_id: StringName = _next_captive_action_report_id(campaign)
			var applied_delta: int = _apply_release_notoriety(campaign, captive, report_id)
			_record_captive_action_report(campaign, captive, &"release", applied_delta, 0, report_id)
			captive.status = &"released"
			captive.assigned_prison_id = &""
			captive.holding_location_id = &"released"
			captive.history_entries.append("Released from custody.%s" % (
				" Regional Notoriety %+d." % applied_delta if applied_delta != 0 else ""
			))
			captive.revision += 1
			campaign.revision += 1
			return OperationResult.ok({
				"captive_id": captive_id,
				"notoriety_delta": applied_delta,
			}, "%s was released.%s" % [
				captive.display_name,
				" Notoriety %d." % applied_delta if applied_delta != 0 else "",
			])
		&"ransom":
			if not captive.ransom_allowed or captive.ransom_value <= 0:
				return OperationResult.fail(&"captive_ransom_unavailable", "No valid ransom is available.")
			if _assigned_prison_condition(campaign, captive) == StrongholdFacilityState.CONDITION_DISABLED:
				return OperationResult.fail(&"prison_disabled", "Ransom processing is suspended until the assigned Prison is repaired.")
			if campaign.resources == null or not campaign.resources.add(&"gold", captive.ransom_value):
				return OperationResult.fail(&"captive_ransom_payment_failed", "The ransom payment could not be applied.")
			var report_id: StringName = _next_captive_action_report_id(campaign)
			_record_captive_action_report(campaign, captive, &"ransom", 0, captive.ransom_value, report_id)
			captive.status = &"ransomed"
			captive.assigned_prison_id = &""
			captive.holding_location_id = &"ransomed"
			captive.history_entries.append("Ransomed for %d Gold." % captive.ransom_value)
			captive.revision += 1
			campaign.revision += 1
			return OperationResult.ok({
				"captive_id": captive_id,
				"gold": captive.ransom_value,
			}, "%s was ransomed for %d Gold." % [captive.display_name, captive.ransom_value])
		&"interrogate":
			var preview: OperationResult = preview_interrogate_for_campaign(campaign, captive)
			if not preview.success:
				return preview
			var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
			var source_id := StringName(data.get("research_source_id", &""))
			var newly_revealed: bool = campaign.add_research_source(source_id)
			captive.interrogation_completed = true
			if not captive.interrogation_result_ids.has(source_id):
				captive.interrogation_result_ids.append(source_id)
			captive.history_entries.append(
				"Interrogated for organisational knowledge: %s." % String(source_id).replace("source.research.", "").replace("_", " ").capitalize()
			)
			captive.revision += 1
			campaign.revision += 1
			return OperationResult.ok({
				"captive_id": captive_id,
				"research_source_id": source_id,
				"newly_revealed": newly_revealed,
			}, "%s revealed %s.%s" % [
				captive.display_name,
				String(source_id).replace("source.research.", "").replace("_", " ").capitalize(),
				"" if newly_revealed else " The source was already known.",
			])
		_:
			return OperationResult.fail(&"captive_action_unknown", "Unknown captive action.")


func _apply_release_notoriety(
		campaign: CampaignState,
		captive: CampaignCaptiveState,
		report_id: StringName
) -> int:
	var requested_delta: int = mini(0, captive.release_notoriety_delta)
	if requested_delta == 0 or captive.source_region_id.is_empty():
		return 0
	var target: SubregionNotorietyState = _release_notoriety_target(campaign, captive)
	if target == null:
		return 0
	return target.apply_delta(requested_delta, report_id)


func _next_captive_action_report_id(campaign: CampaignState) -> StringName:
	if campaign == null:
		return &""
	var report_id := StringName(
		"captive_report.%s.%04d" % [campaign.campaign_id, campaign.next_captive_action_report_sequence]
	)
	campaign.next_captive_action_report_sequence += 1
	return report_id


func _record_captive_action_report(
		campaign: CampaignState,
		captive: CampaignCaptiveState,
		action_id: StringName,
		notoriety_delta: int,
		gold_delta: int,
		report_id: StringName
) -> void:
	if campaign == null or captive == null or report_id.is_empty():
		return
	var label: String = (
		"Release of %s" % captive.display_name
		if action_id == &"release"
		else "Ransom of %s" % captive.display_name
	)
	campaign.captive_action_reports_by_id[report_id] = {
		"report_id": String(report_id),
		"action": String(action_id),
		"captive_id": String(captive.captive_id),
		"label": label,
		"region_id": String(captive.source_region_id),
		"subregion_id": String(captive.source_subregion_id),
		"notoriety_delta": notoriety_delta,
		"gold_delta": gold_delta,
		"created_tick": campaign.campaign_tick,
	}


func _projected_release_notoriety_delta(
		campaign: CampaignState,
		captive: CampaignCaptiveState
) -> int:
	if campaign == null or captive == null:
		return 0
	var requested_delta: int = mini(0, captive.release_notoriety_delta)
	if requested_delta == 0:
		return 0
	var target: SubregionNotorietyState = _release_notoriety_target(campaign, captive)
	if target == null:
		return 0
	return maxi(-target.value, requested_delta)


func _release_notoriety_target(
		campaign: CampaignState,
		captive: CampaignCaptiveState
) -> SubregionNotorietyState:
	if campaign == null or captive == null or captive.source_region_id.is_empty():
		return null
	var region_states: Dictionary = campaign.subregion_notoriety_by_region.get(
		captive.source_region_id, {}
	) as Dictionary
	if region_states.is_empty():
		return null
	var target: SubregionNotorietyState = region_states.get(captive.source_subregion_id) as SubregionNotorietyState
	if target == null:
		for raw_state: Variant in region_states.values():
			var candidate: SubregionNotorietyState = raw_state as SubregionNotorietyState
			if candidate != null and (target == null or candidate.value > target.value):
				target = candidate
	return target


func _regional_total(campaign: CampaignState, region_id: StringName) -> int:
	var total: int = 0
	var states: Dictionary = campaign.subregion_notoriety_by_region.get(region_id, {}) as Dictionary
	for raw_state: Variant in states.values():
		var state: SubregionNotorietyState = raw_state as SubregionNotorietyState
		if state != null:
			total += state.value
	return total


func _captive_snapshot(campaign: CampaignState, captive: CampaignCaptiveState) -> Dictionary:
	var template: CharacterTemplateDefinition = (
		_catalogue.character_template(captive.source_definition_id)
		if _catalogue != null
		else null
	)
	return {
		"captive_id": captive.captive_id,
		"display_name": captive.display_name,
		"identity_known": captive.identity_known,
		"source_definition_id": captive.source_definition_id,
		"portrait_id": template.portrait_id if template != null else &"",
		"faction_id": captive.faction_id,
		"troop_type_id": captive.troop_type_id,
		"level": captive.level,
		"current_hp": captive.current_hp,
		"maximum_hp": captive.maximum_hp,
		"nonlethal_damage": captive.nonlethal_damage,
		"injury_entries": captive.injury_entries.duplicate(),
		"status": String(captive.status),
		"cell_cost": captive.cell_cost,
		"assigned_prison_id": captive.assigned_prison_id,
		"assigned_prison_condition": String(_assigned_prison_condition(campaign, captive)),
		"capture_location_label": captive.capture_location_label,
		"captured_mission_id": captive.captured_mission_id,
		"captor_character_id": captive.captor_character_id,
		"days_held": captive.days_held(campaign.campaign_tick),
		"ransom_allowed": captive.ransom_allowed,
		"ransom_value": captive.ransom_value,
		"release_allowed": captive.release_allowed,
		"release_notoriety_delta": _projected_release_notoriety_delta(campaign, captive),
		"authored_release_notoriety_delta": captive.release_notoriety_delta,
		"interrogation_completed": captive.interrogation_completed,
		"interrogation_result_ids": captive.interrogation_result_ids.duplicate(),
		"interrogation_source_id": _interrogation_source_for_captive(captive),
		"containment_profile_id": captive.containment_profile_id,
		"history_entries": captive.history_entries.duplicate(),
	}


func preview_interrogate_for_campaign(
	campaign: CampaignState,
	captive: CampaignCaptiveState
) -> OperationResult:
	if campaign == null or captive == null:
		return OperationResult.fail(&"captive_missing", "The selected captive no longer exists.")
	if not captive.is_held() or not captive.is_living():
		return OperationResult.fail(&"captive_interrogation_unavailable", "Only a living held captive can be interrogated.")
	if captive.interrogation_completed:
		return OperationResult.fail(&"captive_already_interrogated", "This captive has already yielded their available organisational knowledge.")
	if _assigned_prison_condition(campaign, captive) == StrongholdFacilityState.CONDITION_DISABLED:
		return OperationResult.fail(&"prison_disabled", "Interrogation is suspended until the assigned Prison is repaired.")
	var source_id: StringName = _interrogation_source_for_captive(captive)
	if source_id.is_empty():
		return OperationResult.fail(&"captive_no_research_source", "This captive has no authored Research or contact knowledge to reveal.")
	return OperationResult.ok({
		"captive_id": captive.captive_id,
		"research_source_id": source_id,
		"already_known": campaign.has_research_source(source_id),
	}, "Interrogation can reveal an authored Research source.")


func _interrogation_source_for_captive(captive: CampaignCaptiveState) -> StringName:
	if captive == null:
		return &""
	match captive.source_definition_id:
		&"character_template.life.patrol_leader":
			return &"source.research.life_officer"
		&"character_template.life.mercy_bearer", &"character_template.life.novice_mercy_bearer":
			return &"source.research.life_medicine"
		_:
			return &""


func _assigned_prison_condition(
		campaign: CampaignState,
		captive: CampaignCaptiveState
) -> StringName:
	if campaign == null or campaign.stronghold == null or captive == null or captive.assigned_prison_id.is_empty():
		return &""
	var facility = campaign.stronghold.get_facility(captive.assigned_prison_id)
	return facility.condition if facility != null else &""


func _current_campaign() -> CampaignState:
	if _state_store == null or not _state_store.has_method("current_campaign"):
		return null
	return _state_store.call("current_campaign") as CampaignState
