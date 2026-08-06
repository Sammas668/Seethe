class_name SquadManagementService
extends RefCounted

const FIRST_SQUAD_ID: StringName = &"squad.first_company"
const FIRST_SQUAD_NAME: String = "First Company"


func ensure_campaign_squads(campaign: CampaignState) -> bool:
	if campaign == null:
		return false
	var changed: bool = false
	if campaign.get_squads().is_empty():
		var squad := CampaignSquadState.new()
		squad.squad_id = FIRST_SQUAD_ID
		squad.display_name = FIRST_SQUAD_NAME
		var preferred_ids: Array[StringName] = [
			campaign.protagonist_character_id,
			&"character.reaver.marauder.0001",
			&"character.reaver.marauder.0002",
		]
		for character_id: StringName in preferred_ids:
			var character: PersistentCharacterState = campaign.get_character(character_id)
			if character != null and not character.is_dead and not squad.member_character_ids.has(character_id):
				squad.member_character_ids.append(character_id)
		if squad.member_character_ids.has(campaign.protagonist_character_id):
			squad.leader_character_id = campaign.protagonist_character_id
		squad.history_entries.append("Formed as the first permanent expedition company at the Fifth-God ruin.")
		campaign.squads_by_id[squad.squad_id] = squad
		campaign.next_squad_sequence = maxi(campaign.next_squad_sequence, 2)
		changed = true
	if changed:
		campaign.revision += 1
	return changed


func create_squad(campaign: CampaignState, display_name: String) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var cleaned: String = display_name.strip_edges()
	if cleaned.is_empty():
		return OperationResult.fail(&"squad_name_missing", "Enter a squad name.")
	var squad := CampaignSquadState.new()
	squad.squad_id = campaign.next_squad_id()
	squad.display_name = cleaned
	if not campaign.upsert_squad(squad):
		return OperationResult.fail(&"squad_create_failed", "The squad could not be created.")
	return OperationResult.ok(squad, "%s created." % cleaned)


func rename_squad(campaign: CampaignState, squad_id: StringName, display_name: String) -> OperationResult:
	var squad: CampaignSquadState = campaign.get_squad(squad_id) if campaign != null else null
	if squad == null:
		return OperationResult.fail(&"squad_missing", "The squad no longer exists.")
	if squad.is_active():
		return OperationResult.fail(&"squad_active", "An active expedition cannot be renamed.")
	var cleaned: String = display_name.strip_edges()
	if cleaned.is_empty():
		return OperationResult.fail(&"squad_name_missing", "Enter a squad name.")
	squad.display_name = cleaned
	squad.revision += 1
	campaign.revision += 1
	return OperationResult.ok(squad, "Squad renamed.")


func disband_squad(campaign: CampaignState, squad_id: StringName) -> OperationResult:
	var squad: CampaignSquadState = campaign.get_squad(squad_id) if campaign != null else null
	if squad == null:
		return OperationResult.fail(&"squad_missing", "The squad no longer exists.")
	if squad.is_active() or not squad.assigned_stable_bay_id.is_empty():
		return OperationResult.fail(&"squad_assigned", "Remove this squad from its Stable bay before disbanding it.")
	campaign.squads_by_id.erase(squad_id)
	campaign.revision += 1
	return OperationResult.ok(null, "Squad disbanded. Its members are now unassigned.")


func assign_character(campaign: CampaignState, character_id: StringName, target_squad_id: StringName) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var character: PersistentCharacterState = campaign.get_character(character_id)
	if character == null or character.is_dead:
		return OperationResult.fail(&"character_unavailable", "The character cannot be assigned.")
	var current: CampaignSquadState = campaign.squad_for_character(character_id)
	if current != null and current.is_active():
		return OperationResult.fail(&"squad_active", "%s is away with an active expedition." % character.display_name)
	var target: CampaignSquadState = null
	if not target_squad_id.is_empty():
		target = campaign.get_squad(target_squad_id)
		if target == null:
			return OperationResult.fail(&"squad_missing", "The selected squad no longer exists.")
		if target.is_active():
			return OperationResult.fail(&"squad_active", "Characters cannot join a squad while it is away.")
	if current != null:
		current.member_character_ids.erase(character_id)
		if current.leader_character_id == character_id:
			current.leader_character_id = current.member_character_ids[0] if not current.member_character_ids.is_empty() else &""
		_remove_character_from_stable_formation(campaign, current.assigned_stable_bay_id, character_id)
		current.revision += 1
	if target != null:
		if not target.member_character_ids.has(character_id):
			target.member_character_ids.append(character_id)
		if target.leader_character_id.is_empty():
			target.leader_character_id = character_id
		target.revision += 1
	campaign.revision += 1
	return OperationResult.ok(target, "%s assignment updated." % character.display_name)

func _remove_character_from_stable_formation(
		campaign: CampaignState,
		bay_id: StringName,
		character_id: StringName
) -> void:
	if campaign == null or bay_id.is_empty() or character_id.is_empty():
		return
	var bay: StableBayState = campaign.get_stable_bay(bay_id)
	if bay == null or bay.is_active():
		return
	var removed: bool = false
	for raw_slot_id: Variant in bay.formation_character_ids_by_slot.keys():
		if StringName(bay.formation_character_ids_by_slot.get(raw_slot_id, "")) == character_id:
			bay.formation_character_ids_by_slot.erase(raw_slot_id)
			removed = true
	if removed:
		bay.revision += 1

