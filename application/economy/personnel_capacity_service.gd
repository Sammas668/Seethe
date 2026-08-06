class_name PersonnelCapacityService
extends RefCounted

const LIVING_QUARTERS_ID: StringName = &"facility.living_quarters"

var _stronghold_registry


func configure(stronghold_registry) -> void:
	_stronghold_registry = stronghold_registry


func snapshot(campaign: CampaignState) -> Dictionary:
	if campaign == null:
		return {"used": 0, "maximum": 0, "troops": 0, "manufacturing_workers": 0, "research_workers": 0, "free": 0, "deficit": 0}
	var troops: int = 0
	for character: PersistentCharacterState in campaign.get_characters():
		if character == null or character.is_dead:
			continue
		if character.persistence_scope != PersistentCharacterState.PERSISTENCE_CAMPAIGN:
			continue
		if character.character_id == campaign.protagonist_character_id:
			continue
		troops += 1
	var manufacturing_workers: int = campaign.workforce_count_for_role(&"manufacturing")
	var research_workers: int = campaign.workforce_count_for_role(&"research")
	var maximum: int = maxi(1, campaign.roster_capacity)
	if campaign.stronghold != null and _stronghold_registry != null:
		var definition = _stronghold_registry.definition(campaign.stronghold.definition_id)
		if definition != null:
			for facility: StrongholdFacilityState in campaign.stronghold.get_facilities():
				if facility == null or facility.condition != StrongholdFacilityState.CONDITION_OPERATIONAL:
					continue
				var facility_definition = definition.facility_definition(facility.definition_id)
				if facility_definition != null:
					maximum += facility_definition.personnel_capacity_for_level(facility.level)
	var used: int = troops + manufacturing_workers + research_workers
	return {
		"used": used,
		"maximum": maximum,
		"troops": troops,
		"manufacturing_workers": manufacturing_workers,
		"research_workers": research_workers,
		"free": maxi(0, maximum - used),
		"deficit": maxi(0, used - maximum),
	}


func can_add(campaign: CampaignState, capacity_cost: int) -> bool:
	var current: Dictionary = snapshot(campaign)
	return int(current.get("used", 0)) + maxi(0, capacity_cost) <= int(current.get("maximum", 0))
