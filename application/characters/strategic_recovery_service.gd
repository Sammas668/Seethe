class_name StrategicRecoveryService
extends RefCounted

const BASE_LETHAL_POINTS_PER_DAY: int = 4
const HEALING_UNITS_PER_POINT: int = 1440

var _catalogue: ContentCatalogue
var _stronghold_registry: RefCounted


func configure(
		catalogue: ContentCatalogue,
		stronghold_registry: RefCounted = null
) -> void:
	_catalogue = catalogue
	_stronghold_registry = stronghold_registry


func ensure_campaign_health(campaign: CampaignState) -> bool:
	if campaign == null or _catalogue == null:
		return false
	var changed: bool = false
	for character: PersistentCharacterState in campaign.get_characters():
		if character.is_dead:
			continue
		if character.persistence_scope == PersistentCharacterState.PERSISTENCE_MISSION:
			continue
		var maximum_hp: int = _maximum_hp(campaign, character)
		if character.health_initialized:
			if character.initialize_health(maximum_hp):
				changed = true
			continue
		var legacy_hp: int = maximum_hp
		if character.injury_entries.has("Gravely Wounded"):
			legacy_hp = maxi(1, maximum_hp / 2)
		elif character.injury_entries.has("Wounded"):
			legacy_hp = maxi(1, maximum_hp - maxi(1, ceili(float(maximum_hp) / 4.0)))
		character.set_persistent_health(legacy_hp, 0, maximum_hp)
		var retained_injuries: Array[String] = []
		for injury: String in character.injury_entries:
			if injury not in ["Wounded", "Gravely Wounded"]:
				retained_injuries.append(injury)
		if retained_injuries.size() != character.injury_entries.size():
			character.injury_entries = retained_injuries
			character.revision += 1
		changed = true
	if changed:
		campaign.revision += 1
	return changed


func advance_candidate(campaign: CampaignState, delta_minutes: int) -> bool:
	if campaign == null or delta_minutes <= 0 or _catalogue == null:
		return false
	var rates: Dictionary = recovery_rates(campaign)
	var lethal_rate: int = int(rates.get("lethal_points_per_day", BASE_LETHAL_POINTS_PER_DAY))
	var nonlethal_rate: int = int(rates.get("nonlethal_points_per_day", lethal_rate * 2))
	var changed: bool = false
	for character: PersistentCharacterState in campaign.get_characters():
		if not _can_recover_at_stronghold(campaign, character):
			continue
		var maximum_hp: int = _maximum_hp(campaign, character)
		if character.apply_strategic_recovery(
			delta_minutes,
			maximum_hp,
			lethal_rate,
			nonlethal_rate
		):
			changed = true
	for captive: CampaignCaptiveState in campaign.get_captives():
		if captive.status != &"held" or not captive.is_living():
			continue
		# Captives receive natural recovery only; they do not consume Recovery Chamber allocation.
		captive.lethal_recovery_units += delta_minutes * BASE_LETHAL_POINTS_PER_DAY
		captive.nonlethal_recovery_units += delta_minutes * BASE_LETHAL_POINTS_PER_DAY * 2
		var healed_hp: int = captive.lethal_recovery_units / HEALING_UNITS_PER_POINT
		var healed_nonlethal: int = captive.nonlethal_recovery_units / HEALING_UNITS_PER_POINT
		if healed_hp > 0 and captive.current_hp < captive.maximum_hp:
			var actual_hp: int = mini(healed_hp, captive.maximum_hp - captive.current_hp)
			captive.current_hp += actual_hp
			captive.lethal_recovery_units -= actual_hp * HEALING_UNITS_PER_POINT
			captive.revision += 1
			changed = true
		if healed_nonlethal > 0 and captive.nonlethal_damage > 0:
			var actual_nonlethal: int = mini(healed_nonlethal, captive.nonlethal_damage)
			captive.nonlethal_damage -= actual_nonlethal
			captive.nonlethal_recovery_units -= actual_nonlethal * HEALING_UNITS_PER_POINT
			captive.revision += 1
			changed = true
	if changed:
		campaign.revision += 1
	return changed


func recovery_snapshot(
		campaign: CampaignState,
		character: PersistentCharacterState
) -> Dictionary:
	if campaign == null or character == null:
		return {}
	var maximum_hp: int = _maximum_hp(campaign, character)
	var rates: Dictionary = recovery_rates(campaign)
	var lethal_rate: int = int(rates.get("lethal_points_per_day", BASE_LETHAL_POINTS_PER_DAY))
	var nonlethal_rate: int = int(rates.get("nonlethal_points_per_day", lethal_rate * 2))
	var current_hp: int = character.resolved_current_hp(maximum_hp)
	var nonlethal: int = character.resolved_nonlethal_damage()
	var at_base: bool = _is_at_stronghold(campaign, character)
	return {
		"maximum_hp": maximum_hp,
		"current_hp": current_hp,
		"nonlethal_damage": nonlethal,
		"condition_id": character.health_condition_id(maximum_hp),
		"can_deploy": character.can_deploy_with_health(maximum_hp),
		"unconscious": character.is_persistently_unconscious(maximum_hp),
		"at_base": at_base,
		"recovery_paused": not at_base,
		"lethal_points_per_day": lethal_rate,
		"nonlethal_points_per_day": nonlethal_rate,
		"lethal_minutes_remaining": _minutes_for_units(
			character.missing_lethal_hp(maximum_hp) * HEALING_UNITS_PER_POINT
			- character.lethal_recovery_units,
			lethal_rate
		),
		"nonlethal_minutes_remaining": _minutes_for_units(
			nonlethal * HEALING_UNITS_PER_POINT
			- character.nonlethal_recovery_units,
			nonlethal_rate
		),
		"recovery_chamber_level": int(rates.get("recovery_chamber_level", 0)),
		"treatment_source": String(rates.get("treatment_source", "Natural recovery")),
	}


func recovery_rates(campaign: CampaignState) -> Dictionary:
	var treatment: Dictionary = _best_operational_recovery_treatment(campaign)
	var facility_bonus: int = int(treatment.get("lethal_bonus_per_day", 0))
	var lethal_rate: int = BASE_LETHAL_POINTS_PER_DAY + facility_bonus
	var treatment_name: String = String(
		treatment.get("display_name", "Natural stronghold recovery")
	)
	var treatment_level: int = int(treatment.get("level", 0))
	return {
		"lethal_points_per_day": lethal_rate,
		"nonlethal_points_per_day": lethal_rate * 2,
		"recovery_chamber_level": treatment_level,
		"recovery_facility_bonus": facility_bonus,
		"treatment_source": (
			"%s %d" % [treatment_name, treatment_level]
			if treatment_level > 0
			else treatment_name
		),
	}


func _can_recover_at_stronghold(
		campaign: CampaignState,
		character: PersistentCharacterState
) -> bool:
	return (
		character != null
		and character.health_initialized
		and _is_at_stronghold(campaign, character)
	)


func _is_at_stronghold(
		campaign: CampaignState,
		character: PersistentCharacterState
) -> bool:
	if campaign == null or character == null or character.is_dead:
		return false
	if character.persistence_scope == PersistentCharacterState.PERSISTENCE_MISSION:
		return false
	if character.injury_entries.has("Missing / Unrecovered"):
		return false
	return campaign.active_reservation_for_character(character.character_id) == null


func _maximum_hp(
		campaign: CampaignState,
		character: PersistentCharacterState
) -> int:
	var service := CharacterResolutionService.new()
	service.configure(_catalogue)
	var snapshot: ResolvedCharacterSnapshot = service.resolve_character(
		character,
		[],
		campaign.items_for_character(character.character_id)
	)
	return maxi(1, snapshot.stat_value(&"maximum_hp", 1))


func _best_operational_recovery_treatment(campaign: CampaignState) -> Dictionary:
	if (
		campaign == null
		or campaign.stronghold == null
		or _stronghold_registry == null
		or not _stronghold_registry.has_method("definition")
	):
		return {
			"display_name": "Natural stronghold recovery",
			"level": 0,
			"lethal_bonus_per_day": 0,
		}
	var stronghold_definition: StrongholdDefinition = (
		_stronghold_registry.call(
			"definition",
			campaign.stronghold.definition_id
		) as StrongholdDefinition
	)
	if stronghold_definition == null:
		return {
			"display_name": "Natural stronghold recovery",
			"level": 0,
			"lethal_bonus_per_day": 0,
		}
	var best: Dictionary = {
		"display_name": "Natural stronghold recovery",
		"level": 0,
		"lethal_bonus_per_day": 0,
	}
	for facility: StrongholdFacilityState in campaign.stronghold.get_facilities():
		if facility.condition not in [
			StrongholdFacilityState.CONDITION_OPERATIONAL,
			StrongholdFacilityState.CONDITION_UPGRADING,
		]:
			continue
		var facility_definition: StrongholdFacilityDefinition = (
			stronghold_definition.facility_definition(facility.definition_id)
		)
		if facility_definition == null:
			continue
		var bonus: int = facility_definition.recovery_rate_bonus_for_level(
			facility.level
		)
		if bonus <= int(best.get("lethal_bonus_per_day", 0)):
			continue
		best = {
			"display_name": facility_definition.display_name,
			"level": facility.level,
			"lethal_bonus_per_day": bonus,
		}
	return best


func _minutes_for_units(units_remaining: int, points_per_day: int) -> int:
	if units_remaining <= 0:
		return 0
	if points_per_day <= 0:
		return -1
	return int(ceili(float(units_remaining) / float(points_per_day)))
