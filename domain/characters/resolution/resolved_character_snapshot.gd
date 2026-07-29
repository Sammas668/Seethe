class_name ResolvedCharacterSnapshot
extends RefCounted

var character_id: StringName = &""
var template_id: StringName = &""
var display_name: String = "Unnamed Character"
var faction_id: StringName = &""
var team_id: StringName = &"neutral"
var roster_role: StringName = &"neutral"
var persistence_scope: StringName = &"mission"

var level: int = 1
var xp: int = 0
var species_name: String = "Unknown"
var class_name_text: String = "Unassigned"
var archetype_name: String = "None"
var troop_type: String = "Individual"
var troop_tier: int = 0
var portrait_id: StringName = &""
var tactical_visual_id: StringName = &""
var footprint: Vector2i = Vector2i.ONE

var ability_scores: Dictionary = {}
var stats_by_id: Dictionary = {}
var skill_bonuses: Dictionary = {}
var innate_action_ids: Array = []
var granted_action_ids: Array = []
var trait_ids: Array[StringName] = []
var equipped_item_ids: Array[StringName] = []
var carried_item_ids: Array[StringName] = []
var defence_profile_id: StringName = &""
var ability_entries: Array = []
var condition_entries: Array = []
var injury_entries: Array = []
var history_entries: Array = []


func has_trait(trait_id: StringName) -> bool:
	return trait_ids.has(trait_id)


func ability_score(abbreviation: String) -> int:
	return int(ability_scores.get(abbreviation, 10))


func ability_modifier(abbreviation: String) -> int:
	return score_modifier(ability_score(abbreviation))


func stat(stat_id: StringName):
	return stats_by_id.get(stat_id)


func stat_value(stat_id: StringName, fallback: int = 0) -> int:
	var resolved = stat(stat_id)
	return int(resolved.final_value) if resolved != null else fallback


func stat_breakdown(stat_id: StringName) -> Array[String]:
	var resolved = stat(stat_id)
	if resolved == null:
		var empty_result: Array[String] = []
		return empty_result
	return resolved.breakdown_lines()


func ability_line(abbreviation: String) -> String:
	var score := ability_score(abbreviation)
	return "%s  %d  (%+d)" % [abbreviation, score, score_modifier(score)]


func list_or_none(entries: Array, empty_text: String = "None") -> String:
	if entries.is_empty():
		return empty_text
	var strings := PackedStringArray()
	for entry in entries:
		strings.append(String(entry))
	return "\n".join(strings)


static func score_modifier(score: int) -> int:
	return int(floor((score - 10) / 2.0))


func attack_bonus_for(attack) -> int:
	if attack == null:
		return 0
	var ability_abbreviation := _ability_abbreviation(attack.attack_ability)
	return (
		stat_value(&"base_attack_bonus")
		+ ability_modifier(ability_abbreviation)
		+ int(attack.attack_bonus_modifier)
		+ stat_value(StringName("attack.%s" % attack.id), 0)
	)


func damage_bonus_for(attack) -> int:
	if attack == null:
		return 0
	var damage_ability_id: StringName = attack.damage_ability
	if damage_ability_id.is_empty():
		damage_ability_id = attack.attack_ability
	var ability_abbreviation := _ability_abbreviation(damage_ability_id)
	return (
		ability_modifier(ability_abbreviation)
		+ int(attack.damage_bonus_modifier)
		+ stat_value(StringName("damage.%s" % attack.id), 0)
	)


func damage_notation_for(attack) -> String:
	if attack == null or attack.damage_profile == null:
		return "No damage"
	var bonus := int(attack.damage_profile.flat_bonus) + damage_bonus_for(attack)
	var result := "%dd%d" % [
		maxi(1, int(attack.damage_profile.dice_count)),
		maxi(2, int(attack.damage_profile.die_size)),
	]
	if bonus > 0:
		result += "+%d" % bonus
	elif bonus < 0:
		result += "%d" % bonus
	return result


func attack_breakdown_for(attack) -> Array[String]:
	var lines: Array[String] = []
	if attack == null:
		return lines
	var ability_abbreviation := _ability_abbreviation(attack.attack_ability)
	lines.append(
		"%-28s %+d" % [
			"Base Attack Bonus",
			stat_value(&"base_attack_bonus"),
		]
	)
	lines.append(
		"%-28s %+d" % [
			_ability_display_name(ability_abbreviation),
			ability_modifier(ability_abbreviation),
		]
	)
	if int(attack.attack_bonus_modifier) != 0:
		lines.append(
			"%-28s %+d" % [
				attack.display_name,
				int(attack.attack_bonus_modifier),
			]
		)
	var situational := stat_value(StringName("attack.%s" % attack.id), 0)
	if situational != 0:
		lines.append("%-28s %+d" % ["Situational", situational])
	return lines


func damage_breakdown_for(attack) -> Array[String]:
	var lines: Array[String] = []
	if attack == null:
		return lines
	var damage_ability_id: StringName = attack.damage_ability
	if damage_ability_id.is_empty():
		damage_ability_id = attack.attack_ability
	var ability_abbreviation := _ability_abbreviation(damage_ability_id)
	lines.append(
		"%-28s %+d" % [
			_ability_display_name(ability_abbreviation),
			ability_modifier(ability_abbreviation),
		]
	)
	if int(attack.damage_bonus_modifier) != 0:
		lines.append(
			"%-28s %+d" % [
				attack.display_name,
				int(attack.damage_bonus_modifier),
			]
		)
	if attack.damage_profile != null and int(attack.damage_profile.flat_bonus) != 0:
		lines.append(
			"%-28s %+d" % [
				"Weapon profile",
				int(attack.damage_profile.flat_bonus),
			]
		)
	return lines


func _ability_abbreviation(ability_id: StringName) -> String:
	match ability_id:
		&"strength":
			return "STR"
		&"dexterity":
			return "DEX"
		&"constitution":
			return "CON"
		&"intelligence":
			return "INT"
		&"wisdom":
			return "WIS"
		&"charisma":
			return "CHA"
		_:
			return String(ability_id).left(3).to_upper()


func _ability_display_name(abbreviation: String) -> String:
	match abbreviation:
		"STR":
			return "Strength"
		"DEX":
			return "Dexterity"
		"CON":
			return "Constitution"
		"INT":
			return "Intelligence"
		"WIS":
			return "Wisdom"
		"CHA":
			return "Charisma"
		_:
			return abbreviation
