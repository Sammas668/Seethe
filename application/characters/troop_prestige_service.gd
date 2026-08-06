class_name TroopPrestigeService
extends RefCounted

var _catalogue: ContentCatalogue
var _career_service: TroopCareerService


func configure(catalogue: ContentCatalogue, career_service: TroopCareerService) -> void:
	_catalogue = catalogue
	_career_service = career_service


func options(campaign: CampaignState, character_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var character: PersistentCharacterState = campaign.get_character(character_id) if campaign != null else null
	if character == null or _career_service == null:
		return result
	for stage: TroopPrestigeStageDefinition in _career_service.stages_for_character(character):
		result.append(preview_stage(campaign, character_id, stage.stage_id))
	return result


func preview_stage(campaign: CampaignState, character_id: StringName, stage_id: StringName) -> Dictionary:
	var reasons: Array[String] = []
	var character: PersistentCharacterState = campaign.get_character(character_id) if campaign != null else null
	var stage: TroopPrestigeStageDefinition = _catalogue.prestige_stage(stage_id) if _catalogue != null else null
	if campaign == null or character == null or stage == null:
		reasons.append("Prestige data is unavailable.")
		return {"eligible": false, "reasons": reasons, "reason": reasons[0], "stage": stage}
	var career: TroopCareerDefinition = _career_service.career_for_character(character) if _career_service != null else null
	if career == null or stage.career_id != career.career_id:
		reasons.append("This Tier does not belong to the troop's career.")
	if character.completed_prestige_stage_ids.has(stage.stage_id):
		reasons.append("This Tier has already been completed.")
	if _career_service == null or not _career_service.is_next_stage(character, stage.stage_id):
		reasons.append("Prestige is linear; the preceding Tier must be completed first.")
	if not stage.source_troop_type_id.is_empty() and character.current_troop_type_id != stage.source_troop_type_id:
		reasons.append("The troop is not currently in the required source Tier.")
	var template: CharacterTemplateDefinition = _catalogue.character_template(character.template_id)
	var current_level: int = character.resolved_level(template)
	if current_level < stage.minimum_character_level:
		reasons.append("Requires character Level %d." % stage.minimum_character_level)
	if character.is_dead:
		reasons.append("Dead troops cannot Prestige.")
	elif character.health_initialized and (character.current_hp <= 0 or character.nonlethal_damage >= maxi(1, character.current_hp)):
		reasons.append("The troop must be conscious to begin Prestige.")
	if _has_active_project(campaign, character_id):
		reasons.append("This troop is already in Prestige training.")
	for reservation: StrategicReservationState in campaign.get_strategic_reservations():
		if reservation.is_active() and reservation.character_ids.has(character_id):
			reasons.append("The troop is deployed, travelling or reserved by another operation.")
			break
	if not _operational_facility(campaign, stage.required_facility_id, stage.minimum_facility_level):
		reasons.append("Requires an operational %s at Level %d." % [_short_id(stage.required_facility_id), stage.minimum_facility_level])
	for research_id: StringName in stage.required_research_ids:
		if not campaign.completed_research_ids.has(research_id):
			reasons.append("Required Research is incomplete: %s." % _short_id(research_id))
	var protagonist: PersistentCharacterState = campaign.get_character(campaign.protagonist_character_id)
	if (
		not stage.required_protagonist_class_id.is_empty()
		and (
			protagonist == null
			or protagonist.class_rank(stage.required_protagonist_class_id) < stage.minimum_protagonist_class_level
		)
	):
		reasons.append("The protagonist has not unlocked this Reaver Tier.")
	if not stage.required_protagonist_archetype_id.is_empty() and (protagonist == null or protagonist.archetype_rank(stage.required_protagonist_archetype_id) < stage.minimum_protagonist_archetype_rank):
		reasons.append("The protagonist's Reaver archetype rank is too low.")
	for raw_id: Variant in stage.resource_costs.keys():
		var resource_id := StringName(raw_id)
		var required: int = int(stage.resource_costs[raw_id])
		if campaign.resources.amount(resource_id) < required:
			reasons.append("Requires %d %s." % [required, String(resource_id).capitalize()])
	return {
		"eligible": reasons.is_empty(), "reasons": reasons,
		"reason": reasons[0] if not reasons.is_empty() else "Available",
		"character": character, "stage": stage, "career": career,
		"current_level": current_level,
		"current_tier_starting_feats": character.active_tier_starting_feat_ids.duplicate(),
		"new_tier_starting_feats": stage.tier_starting_feat_ids.duplicate(),
		"retained_permanent_grants": true,
	}


func start_candidate(campaign: CampaignState, character_id: StringName, stage_id: StringName) -> OperationResult:
	var preview: Dictionary = preview_stage(campaign, character_id, stage_id)
	if not bool(preview.get("eligible", false)):
		return OperationResult.fail(&"prestige_ineligible", String(preview.get("reason", "Prestige is unavailable.")))
	var character: PersistentCharacterState = preview.get("character") as PersistentCharacterState
	var stage: TroopPrestigeStageDefinition = preview.get("stage") as TroopPrestigeStageDefinition
	if character == null or stage == null:
		return OperationResult.fail(&"prestige_data_changed", "Prestige data changed before confirmation.")
	for raw_id: Variant in stage.resource_costs.keys():
		if not campaign.resources.add(StringName(raw_id), -int(stage.resource_costs[raw_id])):
			return OperationResult.fail(&"prestige_cost_changed", "Prestige resources changed before confirmation.")
	var project := TroopPrestigeProjectState.new()
	project.project_id = campaign.allocate_prestige_project_id()
	project.character_id = character.character_id
	project.career_id = character.career_id
	project.source_stage_id = character.completed_prestige_stage_ids[-1] if not character.completed_prestige_stage_ids.is_empty() else &""
	project.target_stage_id = stage.stage_id
	project.host_facility_id = _facility_instance(campaign, stage.required_facility_id, stage.minimum_facility_level)
	project.started_tick = campaign.campaign_tick
	project.completion_tick = campaign.campaign_tick + stage.duration_ticks
	campaign.prestige_projects_by_id[project.project_id] = project
	campaign.revision += 1
	return OperationResult.ok(project, "%s began %s Prestige training." % [character.display_name, stage.display_name])


func advance_candidate(campaign: CampaignState) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	if campaign == null or _catalogue == null:
		return completed
	for project: TroopPrestigeProjectState in campaign.get_prestige_projects():
		if project.applied or project.status in [TroopPrestigeProjectState.STATUS_APPLIED, TroopPrestigeProjectState.STATUS_CANCELLED]:
			continue
		var character: PersistentCharacterState = campaign.get_character(project.character_id)
		var stage: TroopPrestigeStageDefinition = _catalogue.prestige_stage(project.target_stage_id)
		if character == null or stage == null or character.is_dead:
			project.status = TroopPrestigeProjectState.STATUS_CANCELLED
			project.revision += 1
			continue
		var facility_ok: bool = _operational_facility(campaign, stage.required_facility_id, stage.minimum_facility_level)
		if not facility_ok:
			if project.status != TroopPrestigeProjectState.STATUS_PAUSED:
				project.status = TroopPrestigeProjectState.STATUS_PAUSED
				project.paused_at_tick = campaign.campaign_tick
				project.revision += 1
			continue
		if project.status == TroopPrestigeProjectState.STATUS_PAUSED:
			project.completion_tick += maxi(0, campaign.campaign_tick - project.paused_at_tick)
			project.paused_at_tick = 0
			project.status = TroopPrestigeProjectState.STATUS_ACTIVE
			project.revision += 1
		if campaign.campaign_tick < project.completion_tick:
			continue
		if not _career_service.is_next_stage(character, stage.stage_id):
			continue
		project.status = TroopPrestigeProjectState.STATUS_COMPLETE
		_apply_stage(campaign, character, stage)
		project.applied = true
		project.status = TroopPrestigeProjectState.STATUS_APPLIED
		project.revision += 1
		completed.append({"character_id": character.character_id, "stage_id": stage.stage_id})
	if not completed.is_empty():
		campaign.revision += 1
	return completed


func active_project_for_character(campaign: CampaignState, character_id: StringName) -> TroopPrestigeProjectState:
	if campaign == null:
		return null
	for project: TroopPrestigeProjectState in campaign.get_prestige_projects():
		if project.character_id == character_id and not project.applied and project.status != TroopPrestigeProjectState.STATUS_CANCELLED:
			return project
	return null


func _apply_stage(campaign: CampaignState, character: PersistentCharacterState, stage: TroopPrestigeStageDefinition) -> void:
	# The only replacement operation: swap the active Tier's starting feats.
	character.active_tier_starting_feat_ids = stage.tier_starting_feat_ids.duplicate()
	character.active_tier_starting_feat_parameters = stage.tier_starting_feat_parameters.duplicate(true)
	_append_unique(character.prestige_feat_ids, stage.granted_feat_ids)
	_append_unique(character.prestige_trait_ids, stage.granted_trait_ids)
	_append_unique(character.prestige_ability_ids, stage.granted_ability_ids)
	_append_unique(character.prestige_action_ids, stage.granted_action_ids)
	_append_unique(character.prestige_proficiency_ids, stage.granted_proficiency_ids)
	_append_unique(character.prestige_role_tag_ids, stage.granted_role_tags)
	for entry: String in stage.ability_entries:
		if not character.prestige_ability_entries.has(entry):
			character.prestige_ability_entries.append(entry)
	for raw_key: Variant in stage.feature_parameters.keys():
		character.prestige_feature_parameters[raw_key] = (stage.feature_parameters[raw_key] as Dictionary).duplicate(true) if stage.feature_parameters[raw_key] is Dictionary else stage.feature_parameters[raw_key]
	for raw_key: Variant in stage.feature_upgrades.keys():
		character.active_feature_upgrade_ids[raw_key] = stage.feature_upgrades[raw_key]
	for raw_key: Variant in stage.permanent_stat_adjustments.keys():
		var stat_key: String = String(raw_key)
		var provenance_id := StringName("%s.%s" % [stage.stage_id, stat_key])
		if character.has_permanent_grant(provenance_id, stage.stage_id):
			continue
		character.stat_adjustments[stat_key] = int(character.stat_adjustments.get(stat_key, 0)) + int(stage.permanent_stat_adjustments[raw_key])
		_record_grant(character, provenance_id, &"stat", stage, campaign.campaign_tick)
	for feat_id: StringName in stage.tier_starting_feat_ids:
		_record_grant(character, feat_id, &"tier_starting_feat", stage, campaign.campaign_tick)
	for feat_id: StringName in stage.granted_feat_ids:
		_record_grant(character, feat_id, &"feat", stage, campaign.campaign_tick)
	for trait_id: StringName in stage.granted_trait_ids:
		_record_grant(character, trait_id, &"trait", stage, campaign.campaign_tick)
	for ability_id: StringName in stage.granted_ability_ids:
		_record_grant(character, ability_id, &"ability", stage, campaign.campaign_tick)
	character.completed_prestige_stage_ids.append(stage.stage_id)
	character.current_troop_type_id = stage.resulting_troop_type_id
	character.troop_tier = stage.troop_tier
	# Raider's Sack is the physical expression of the Marauder-only
	# Raider's Burden starting feat. Entering Marauder creates and fixes it;
	# replacing that Tier package removes it without touching learned features.
	MarauderLoadoutMigration.repair_raiders_sack_fixture(
		campaign,
		character,
		_catalogue
	)
	if not stage.resulting_body_profile_id.is_empty():
		character.body_transition_history.append(stage.resulting_body_profile_id)
	if not stage.resulting_companion_definition_id.is_empty():
		character.active_companion_id = stage.resulting_companion_definition_id
	character.add_history("Completed Tier %d Prestige: %s. Earlier levels and earned features were retained; Tier starting feats were replaced." % [stage.troop_tier, stage.display_name])
	character.revision += 1


func _record_grant(character: PersistentCharacterState, grant_id: StringName, grant_type: StringName, stage: TroopPrestigeStageDefinition, tick: int) -> void:
	if character.has_permanent_grant(grant_id, stage.stage_id):
		return
	var grant := CharacterPermanentGrantState.new()
	grant.grant_id = grant_id
	grant.grant_type = grant_type
	grant.source_type = &"prestige_stage"
	grant.source_id = stage.stage_id
	grant.acquired_level = stage.minimum_character_level
	grant.acquired_tick = tick
	character.add_permanent_grant(grant)


static func _append_unique(target: Array[StringName], values: Array[StringName]) -> void:
	for value: StringName in values:
		if not target.has(value):
			target.append(value)


func _has_active_project(campaign: CampaignState, character_id: StringName) -> bool:
	return active_project_for_character(campaign, character_id) != null


static func _operational_facility(campaign: CampaignState, definition_id: StringName, minimum_level: int) -> bool:
	return not _facility_instance(campaign, definition_id, minimum_level).is_empty()


static func _facility_instance(campaign: CampaignState, definition_id: StringName, minimum_level: int) -> StringName:
	if definition_id.is_empty():
		return &"none"
	if campaign == null or campaign.stronghold == null:
		return &""
	for facility: StrongholdFacilityState in campaign.stronghold.get_facilities():
		if facility.definition_id == definition_id and facility.condition == StrongholdFacilityState.CONDITION_OPERATIONAL and facility.level >= minimum_level:
			return facility.instance_id
	return &""


static func _short_id(value: StringName) -> String:
	return String(value).get_slice(".", String(value).count(".")).replace("_", " ").capitalize()
