class_name CharacterResolver
extends RefCounted

const RESOLVED_CHARACTER_SNAPSHOT_SCRIPT: Script = preload(
	"res://domain/characters/resolution/resolved_character_snapshot.gd"
)
const RESOLVED_STAT_SCRIPT: Script = preload(
	"res://domain/characters/resolution/resolved_stat.gd"
)


func resolve(
		character,
		template,
		defence_profile,
		equipment_inputs: Array,
		active_modifiers: Array = []
):
	var result = RESOLVED_CHARACTER_SNAPSHOT_SCRIPT.new()
	if character == null or template == null:
		return result

	result.character_id = character.character_id
	result.template_id = template.id
	result.display_name = character.display_name
	result.faction_id = character.faction_id
	result.team_id = character.team_id
	result.roster_role = character.roster_role
	result.persistence_scope = character.persistence_scope
	result.level = character.resolved_level(template)
	result.xp = character.xp
	result.species_name = template.species_name
	result.class_name_text = template.class_name_text
	result.archetype_name = template.archetype_name
	result.troop_type = character.troop_display_name(template.troop_type)
	result.troop_tier = character.troop_tier if not character.career_id.is_empty() else template.troop_tier
	result.portrait_id = character.effective_portrait_id(template)
	result.tactical_visual_id = template.tactical_visual_id
	result.footprint = template.footprint
	result.role_tags = template.role_tags.duplicate()
	_append_unique_string_names(result.role_tags, character.prestige_role_tag_ids)
	result.proficiency_ids = template.proficiency_ids.duplicate()
	_append_unique_string_names(result.proficiency_ids, character.prestige_proficiency_ids)
	result.ai_profile_id = template.ai_profile_id
	result.combatant_classification = template.combatant_classification
	result.capture_eligible = template.capture_eligible
	result.surrender_eligible = template.surrender_eligible
	result.loot_profile_id = template.loot_profile_id
	result.provisional_content = template.provisional_content
	result.carrying_strength_bonus = _resolved_carrying_strength_bonus(character, template)
	result.ability_resource_maximums = template.ability_resource_maximums.duplicate(true)
	result.feature_parameters = template.feature_parameters.duplicate(true)
	for tier_feat_id: StringName in template.tier_starting_feat_ids:
		result.feature_parameters.erase(tier_feat_id)
	for raw_key: Variant in character.active_tier_starting_feat_parameters.keys():
		var tier_value: Variant = character.active_tier_starting_feat_parameters[raw_key]
		result.feature_parameters[raw_key] = tier_value.duplicate(true) if tier_value is Dictionary else tier_value
	for raw_key: Variant in character.prestige_feature_parameters.keys():
		var value: Variant = character.prestige_feature_parameters[raw_key]
		result.feature_parameters[raw_key] = value.duplicate(true) if value is Dictionary else value
	result.defence_profile_id = (
		defence_profile.id if defence_profile != null else &""
	)
	result.skill_bonuses = template.skill_bonuses.duplicate(true)
	# Template Tier-starting feats are not permanent. Remove the template's
	# original Tier package, then install the character's currently active Tier
	# package. All level-up choices and all other earned Prestige content remain.
	result.trait_ids = template.trait_ids.duplicate()
	for tier_feat_id: StringName in template.tier_starting_feat_ids:
		result.trait_ids.erase(tier_feat_id)
	_append_unique_string_names(result.trait_ids, character.active_tier_starting_feat_ids)
	_append_unique_string_names(result.trait_ids, character.prestige_feat_ids)
	_append_unique_string_names(result.trait_ids, character.prestige_trait_ids)
	_append_unique_string_names(result.trait_ids, character.selected_talent_ids)
	_append_unique_string_names(result.trait_ids, character.ordinary_feat_choice_ids)
	for character_trait: String in character.trait_entries:
		var trait_id := StringName(character_trait)
		if not trait_id.is_empty() and not result.trait_ids.has(trait_id):
			result.trait_ids.append(trait_id)

	result.ability_entries = template.ability_entries.duplicate()
	for prestige_entry: String in character.prestige_ability_entries:
		if not result.ability_entries.has(prestige_entry):
			result.ability_entries.append(prestige_entry)
	for prestige_ability_id: StringName in character.prestige_ability_ids:
		var prestige_ability_text := String(prestige_ability_id).replace("ability.", "").replace("_", " ").capitalize()
		if not result.ability_entries.has(prestige_ability_text):
			result.ability_entries.append(prestige_ability_text)
	for raw_stat_key: Variant in character.stat_adjustments.keys():
		var stat_key := String(raw_stat_key)
		if not stat_key.begins_with("granted_ability.") or int(character.stat_adjustments[raw_stat_key]) <= 0:
			continue
		var learned_ability_text := stat_key.trim_prefix("granted_ability.").replace("ability.", "").replace("_", " ").capitalize()
		if not result.ability_entries.has(learned_ability_text):
			result.ability_entries.append(learned_ability_text)
	result.injury_entries = character.injury_entries.duplicate()
	result.condition_entries = character.permanent_condition_entries.duplicate()
	result.history_entries = character.history_entries.duplicate()

	_resolve_abilities(result, character, template, active_modifiers)
	_resolve_equipment_manifest(result, equipment_inputs)
	_resolve_core_stats(
		result,
		character,
		template,
		defence_profile,
		equipment_inputs,
		active_modifiers
	)
	_resolve_actions(result, character, template, equipment_inputs, active_modifiers)

	for modifier in active_modifiers:
		if modifier == null:
			continue
		var condition_text = String(modifier.sheet_condition_text).strip_edges()
		if not condition_text.is_empty():
			result.condition_entries.append(condition_text)

	return result


func _resolve_equipment_manifest(result, equipment_inputs: Array) -> void:
	for equipment_value: Variant in equipment_inputs:
		var equipment: RefCounted = equipment_value as RefCounted
		if equipment == null:
			continue
		var item_id: StringName = StringName(equipment.get("item_id"))
		if item_id.is_empty():
			continue
		if bool(equipment.get("carried")):
			result.carried_item_ids.append(item_id)
		if bool(equipment.get("equipped")):
			result.equipped_item_ids.append(item_id)


func _append_equipment_stat_modifiers(
		stat,
		stat_id: StringName,
		equipment_inputs: Array,
		defence_profile
) -> void:
	for equipment_value: Variant in equipment_inputs:
		var equipment: RefCounted = equipment_value as RefCounted
		if equipment == null or not bool(equipment.get("equipped")):
			continue
		if float(equipment.get("condition")) <= 0.0:
			continue
		var definition: ItemDefinition = equipment.get("definition") as ItemDefinition
		if definition == null:
			continue
		# Armour represented by the selected DefenceProfile is not added twice.
		if (
			stat_id == &"armour_class"
			and defence_profile != null
			and definition.defence_profile_id == defence_profile.id
		):
			continue
		var modifier_value: int = int(equipment.call("stat_modifier", stat_id))
		if modifier_value == 0:
			continue
		var item_id: StringName = StringName(equipment.get("item_id"))
		var label: String = definition.display_name
		var condition: float = float(equipment.get("condition"))
		if condition < 0.999:
			label += " (%d%% condition)" % int(round(condition * 100.0))
		stat.add_line(item_id, label, modifier_value, &"equipment")


func _resolved_carrying_strength_bonus(
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> int:
	var result: int = template.carrying_strength_bonus if template != null else 0
	# A legacy troop template may contain the starting feat directly. Once the
	# character is career-enabled that template package is replaced by the
	# persistent active Tier package, so its carrying modifier must not leak into
	# later Tiers.
	if template != null and not character.career_id.is_empty() and not template.tier_starting_feat_ids.is_empty():
		result = 0
	for raw_feat_id: Variant in character.active_tier_starting_feat_ids:
		var feat_id := StringName(raw_feat_id)
		var raw_parameters: Variant = character.active_tier_starting_feat_parameters.get(feat_id, {})
		if raw_parameters is Dictionary:
			result += int((raw_parameters as Dictionary).get("carrying_strength_bonus", 0))
	for raw_feature_id: Variant in character.prestige_feature_parameters.keys():
		var raw_parameters: Variant = character.prestige_feature_parameters[raw_feature_id]
		if raw_parameters is Dictionary:
			result += int((raw_parameters as Dictionary).get("carrying_strength_bonus", 0))
	return result


func _resolve_abilities(result, character, template, active_modifiers: Array) -> void:
	var abbreviations = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]

	for abbreviation_value in abbreviations:
		var abbreviation = String(abbreviation_value)
		var base_value = int(template.ability_score(abbreviation))
		var persistent_value = int(
			character.ability_adjustments.get(abbreviation, 0)
		)
		var effect_value = 0

		for modifier in active_modifiers:
			if modifier != null:
				effect_value += int(modifier.ability_modifier(abbreviation))

		result.ability_scores[abbreviation] = (
			base_value + persistent_value + effect_value
		)

		var stat = _new_stat(
			StringName("ability.%s" % abbreviation.to_lower()),
			_ability_display_name(abbreviation)
		)
		if stat == null:
			continue

		stat.add_line(template.id, "Base", base_value, &"template")

		if persistent_value != 0:
			stat.add_line(
				character.character_id,
				"Progression",
				persistent_value,
				&"progression"
			)

		for modifier in active_modifiers:
			if modifier == null:
				continue
			var modifier_value = int(modifier.ability_modifier(abbreviation))
			if modifier_value != 0:
				stat.add_line(
					modifier.id,
					modifier.display_name,
					modifier_value,
					&"effect"
				)

		result.stats_by_id[stat.stat_id] = stat


func _resolve_core_stats(result, character, template, defence_profile, equipment_inputs: Array, active_modifiers: Array) -> void:
	_add_simple_stat(
		result,
		&"base_attack_bonus",
		"Base Attack Bonus",
		int(template.base_attack_bonus),
		"Class progression",
		character,
		active_modifiers
	)

	var hp = _new_stat(&"maximum_hp", "Maximum HP")
	if hp != null:
		hp.add_line(
			template.id,
			"Class and hit dice",
			int(template.base_hp_before_constitution),
			&"template"
		)
		hp.add_line(
			&"ability.constitution",
			"Constitution x %d" % int(template.hp_constitution_levels),
			result.ability_modifier("CON") * int(template.hp_constitution_levels),
			&"ability"
		)
		_append_external_stat_modifiers(
			hp,
			&"maximum_hp",
			character,
			active_modifiers
		)
		result.stats_by_id[hp.stat_id] = hp

	var armour = _new_stat(&"armour_class", "Armour Class")
	if armour != null:
		armour.add_line(
			template.id,
			"Base",
			int(template.base_armour_class),
			&"template"
		)
		var dexterity_modifier: int = result.ability_modifier("DEX")
		var maximum_dexterity_bonus: int = _equipped_maximum_dexterity_bonus(
			equipment_inputs
		)
		var dexterity_contribution: int = mini(
			dexterity_modifier,
			maximum_dexterity_bonus
		)
		armour.add_line(
			&"ability.dexterity",
			(
				"Dexterity (capped at %+d by armour)" % maximum_dexterity_bonus
				if dexterity_contribution != dexterity_modifier
				else "Dexterity"
			),
			dexterity_contribution,
			&"ability"
		)
		if defence_profile != null:
			armour.add_line(
				defence_profile.id,
				defence_profile.display_name,
				int(defence_profile.armour_class_bonus),
				&"equipment"
			)
		_append_equipment_stat_modifiers(
			armour,
			&"armour_class",
			equipment_inputs,
			defence_profile
		)
		_append_external_stat_modifiers(
			armour,
			&"armour_class",
			character,
			active_modifiers
		)
		result.stats_by_id[armour.stat_id] = armour

	var armour_check = _new_stat(&"armour_check_penalty", "Armour-check Penalty")
	if armour_check != null:
		var armour_penalty: int = _equipped_armour_check_penalty(equipment_inputs)
		armour_check.add_line(
			&"equipped_armour",
			"Equipped armour",
			armour_penalty,
			&"equipment"
		)
		result.stats_by_id[armour_check.stat_id] = armour_check

	var trap_ac = _new_stat(&"trap_armour_class_bonus", "Trap Sense AC Bonus")
	if trap_ac != null:
		trap_ac.add_line(
			&"feature.trap_sense_1",
			"Trap Sense +1",
			int(result.feature_parameter(&"feature.trap_sense_1", &"trap_armour_class_bonus", 0)),
			&"trait"
		)
		result.stats_by_id[trap_ac.stat_id] = trap_ac

	var trap_reflex = _new_stat(&"trap_reflex_bonus", "Trap Sense Reflex Bonus")
	if trap_reflex != null:
		trap_reflex.add_line(
			&"feature.trap_sense_1",
			"Trap Sense +1",
			int(result.feature_parameter(&"feature.trap_sense_1", &"trap_reflex_bonus", 0)),
			&"trait"
		)
		result.stats_by_id[trap_reflex.stat_id] = trap_reflex

	_add_save_stat(
		result,
		&"fortitude",
		"Fortitude",
		int(template.save_base(&"fortitude")),
		"CON",
		character,
		active_modifiers
	)
	_add_save_stat(
		result,
		&"reflex",
		"Reflex",
		int(template.save_base(&"reflex")),
		"DEX",
		character,
		active_modifiers
	)
	_add_save_stat(
		result,
		&"will",
		"Will",
		int(template.save_base(&"will")),
		"WIS",
		character,
		active_modifiers
	)

	var initiative = _new_stat(&"initiative", "Initiative")
	if initiative != null:
		initiative.add_line(
			&"ability.dexterity",
			"Dexterity",
			result.ability_modifier("DEX"),
			&"ability"
		)
		if int(template.initiative_flat_bonus) != 0:
			initiative.add_line(
				template.id,
				"Template bonus",
				int(template.initiative_flat_bonus),
				&"template"
			)
		_append_external_stat_modifiers(
			initiative,
			&"initiative",
			character,
			active_modifiers
		)
		result.stats_by_id[initiative.stat_id] = initiative

	var perception = _new_stat(&"passive_perception", "Passive Perception")
	if perception != null:
		perception.add_line(
			template.id,
			"Base",
			int(template.passive_perception_base),
			&"template"
		)
		perception.add_line(
			&"ability.wisdom",
			"Wisdom",
			result.ability_modifier("WIS"),
			&"ability"
		)
		if int(template.perception_skill_bonus) != 0:
			perception.add_line(
				template.id,
				"Perception training",
				int(template.perception_skill_bonus),
				&"skill"
			)
		_append_external_stat_modifiers(
			perception,
			&"passive_perception",
			character,
			active_modifiers
		)
		result.stats_by_id[perception.stat_id] = perception

	var movement = _new_stat(&"turn_capacity", "Movement Capacity")
	if movement != null:
		movement.add_line(
			template.id,
			"Base movement",
			int(template.base_turn_capacity_feet),
			&"template"
		)
		_append_external_stat_modifiers(
			movement,
			&"turn_capacity",
			character,
			active_modifiers
		)
		result.stats_by_id[movement.stat_id] = movement

		var half_action = _new_stat(&"half_action_cost", "Half Action")
		if half_action != null:
			half_action.add_line(
				&"turn_capacity",
				"50% of movement capacity",
				int(floor(float(movement.final_value) * 0.5)),
				&"derived"
			)
			result.stats_by_id[half_action.stat_id] = half_action

		var sprint = _new_stat(&"sprint_distance", "Sprint")
		if sprint != null:
			var sprint_percent = int(
				round(float(template.sprint_multiplier) * 100.0)
			)
			var sprint_distance = int(
				floor(
					float(movement.final_value) * float(template.sprint_multiplier)
				)
			)
			sprint.add_line(
				&"turn_capacity",
				"%d%% of movement capacity" % sprint_percent,
				sprint_distance,
				&"derived"
			)
			result.stats_by_id[sprint.stat_id] = sprint

	var manoeuvre = _new_stat(&"manoeuvre", "Manoeuvre")
	if manoeuvre != null:
		manoeuvre.add_line(
			&"base_attack_bonus",
			"Base Attack Bonus",
			result.stat_value(&"base_attack_bonus"),
			&"progression"
		)
		manoeuvre.add_line(
			&"ability.strength",
			"Strength",
			result.ability_modifier("STR"),
			&"ability"
		)
		_append_external_stat_modifiers(
			manoeuvre,
			&"manoeuvre",
			character,
			active_modifiers
		)
		result.stats_by_id[manoeuvre.stat_id] = manoeuvre

	var manoeuvre_defence = _new_stat(&"manoeuvre_defence", "Manoeuvre Defence")
	if manoeuvre_defence != null:
		manoeuvre_defence.add_line(template.id, "Base", 10, &"template")
		manoeuvre_defence.add_line(
			&"base_attack_bonus",
			"Base Attack Bonus",
			result.stat_value(&"base_attack_bonus"),
			&"progression"
		)
		manoeuvre_defence.add_line(
			&"ability.strength",
			"Strength",
			result.ability_modifier("STR"),
			&"ability"
		)
		_append_external_stat_modifiers(
			manoeuvre_defence,
			&"manoeuvre_defence",
			character,
			active_modifiers
		)
		result.stats_by_id[manoeuvre_defence.stat_id] = manoeuvre_defence

	# Compatibility alias: existing grapple rules use the shared physical
	# manoeuvre value while older UI/tests still request the grapple stat.
	var grapple = _new_stat(&"grapple", "Grapple")
	if grapple != null:
		grapple.add_line(
			&"manoeuvre",
			"Shared Manoeuvre",
			result.stat_value(&"manoeuvre"),
			&"derived"
		)
		_append_external_stat_modifiers(
			grapple,
			&"grapple",
			character,
			active_modifiers
		)
		result.stats_by_id[grapple.stat_id] = grapple

	var effective_carrying_strength = _new_stat(
		&"effective_carrying_strength",
		"Effective Strength for Carrying"
	)
	if effective_carrying_strength != null:
		effective_carrying_strength.add_line(
			&"ability.strength",
			"Strength",
			result.ability_score("STR"),
			&"ability"
		)
		if result.carrying_strength_bonus != 0:
			effective_carrying_strength.add_line(
				&"active_tier_starting_feat",
				"Tier carrying feature",
				result.carrying_strength_bonus,
				&"trait"
			)
		result.stats_by_id[effective_carrying_strength.stat_id] = effective_carrying_strength

	var carrying_strength_value: int = result.stat_value(
		&"effective_carrying_strength", result.ability_score("STR")
	)
	var maximum_load: int = (
		_maximum_load_for_strength(carrying_strength_value)
		if result.carrying_strength_bonus > 0
		else int(round(float(template.maximum_weight_lb)))
	)
	var carry = _new_stat(&"maximum_weight_lb", "Maximum Carried Load")
	if carry != null:
		carry.add_line(
			template.id,
			"Carrying table at Strength %d" % carrying_strength_value,
			maximum_load,
			&"derived"
		)
		_append_external_stat_modifiers(
			carry,
			&"maximum_weight_lb",
			character,
			active_modifiers
		)
		result.stats_by_id[carry.stat_id] = carry

	var light_load = _new_stat(&"light_load_max_lb", "Light Load Maximum")
	if light_load != null:
		light_load.add_line(
			&"maximum_weight_lb",
			"One third of maximum load",
			int(floor(float(maximum_load) / 3.0)),
			&"derived"
		)
		result.stats_by_id[light_load.stat_id] = light_load

	var medium_load = _new_stat(&"medium_load_max_lb", "Medium Load Maximum")
	if medium_load != null:
		medium_load.add_line(
			&"maximum_weight_lb",
			"Two thirds of maximum load",
			int(floor(float(maximum_load) * 2.0 / 3.0)),
			&"derived"
		)
		result.stats_by_id[medium_load.stat_id] = medium_load


func _add_simple_stat(result, stat_id: StringName, display_name: String, base_value: int, base_label: String, character, active_modifiers: Array) -> void:
	var stat = _new_stat(stat_id, display_name)
	if stat == null:
		return
	stat.add_line(character.template_id, base_label, base_value, &"template")
	_append_external_stat_modifiers(stat, stat_id, character, active_modifiers)
	result.stats_by_id[stat_id] = stat


func _add_save_stat(result, stat_id: StringName, display_name: String, base_value: int, ability_abbreviation: String, character, active_modifiers: Array) -> void:
	var stat = _new_stat(stat_id, display_name)
	if stat == null:
		return
	stat.add_line(
		character.template_id,
		"Base save",
		base_value,
		&"progression"
	)
	stat.add_line(
		StringName("ability.%s" % ability_abbreviation.to_lower()),
		_ability_display_name(ability_abbreviation),
		result.ability_modifier(ability_abbreviation),
		&"ability"
	)
	_append_external_stat_modifiers(stat, stat_id, character, active_modifiers)
	result.stats_by_id[stat_id] = stat


func _append_external_stat_modifiers(stat, stat_id: StringName, character, active_modifiers: Array) -> void:
	var persistent_value = int(
		character.stat_adjustments.get(String(stat_id), 0)
	)
	if persistent_value != 0:
		stat.add_line(
			character.character_id,
			"Progression and injuries",
			persistent_value,
			&"persistent"
		)

	for modifier in active_modifiers:
		if modifier == null:
			continue
		var modifier_value = int(modifier.stat_modifier(stat_id))
		if modifier_value != 0:
			stat.add_line(
				modifier.id,
				modifier.display_name,
				modifier_value,
				&"effect"
			)


func _resolve_actions(result, character, template, equipment_inputs: Array, active_modifiers: Array) -> void:
	var seen: Dictionary = {}

	for action_id_value in template.innate_action_ids:
		var action_id = StringName(action_id_value)
		if action_id.is_empty() or seen.has(action_id):
			continue
		seen[action_id] = true
		result.innate_action_ids.append(action_id)
		result.granted_action_ids.append(action_id)

	for prestige_action_id: StringName in character.prestige_action_ids:
		_append_action(result.granted_action_ids, seen, prestige_action_id)
		if not result.innate_action_ids.has(prestige_action_id):
			result.innate_action_ids.append(prestige_action_id)

	for equipment_value: Variant in equipment_inputs:
		var equipment: RefCounted = equipment_value as RefCounted
		if equipment == null or not bool(equipment.get("carried")):
			continue
		var definition: ItemDefinition = equipment.get("definition") as ItemDefinition
		if definition == null:
			continue
		for action_id_value in definition.granted_action_ids:
			_append_action(
				result.granted_action_ids,
				seen,
				StringName(action_id_value)
			)

	for modifier in active_modifiers:
		if modifier == null:
			continue
		for action_id_value in modifier.granted_action_ids:
			_append_action(
				result.granted_action_ids,
				seen,
				StringName(action_id_value)
			)


func _append_unique_string_names(target: Array, values: Array) -> void:
	for raw_value: Variant in values:
		var value := StringName(raw_value)
		if not value.is_empty() and not target.has(value):
			target.append(value)


func _append_action(target: Array, seen: Dictionary, action_id: StringName) -> void:
	if action_id.is_empty() or seen.has(action_id):
		return
	seen[action_id] = true
	target.append(action_id)


func _equipped_maximum_dexterity_bonus(equipment_inputs: Array) -> int:
	var result: int = 99
	for equipment_value: Variant in equipment_inputs:
		var equipment: RefCounted = equipment_value as RefCounted
		if equipment == null or not bool(equipment.get("equipped")):
			continue
		if float(equipment.get("condition")) <= 0.0:
			continue
		var definition: ItemDefinition = equipment.get("definition") as ItemDefinition
		if definition == null or definition.defence_profile_id.is_empty():
			continue
		result = mini(result, definition.maximum_dexterity_bonus)
	return result


func _equipped_armour_check_penalty(equipment_inputs: Array) -> int:
	var result: int = 0
	for equipment_value: Variant in equipment_inputs:
		var equipment: RefCounted = equipment_value as RefCounted
		if equipment == null or not bool(equipment.get("equipped")):
			continue
		if float(equipment.get("condition")) <= 0.0:
			continue
		var definition: ItemDefinition = equipment.get("definition") as ItemDefinition
		if definition != null:
			result += mini(0, definition.armour_check_penalty)
	return result


func _maximum_load_for_strength(strength_score: int) -> int:
	# D&D 3.5 carrying-capacity table. Scores above 29 multiply the value
	# ten points lower by four, preserving the standard progression.
	var table: Array[int] = [
		0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100,
		115, 130, 150, 175, 200, 230, 260, 300, 350, 400,
		460, 520, 600, 700, 800, 920, 1040, 1200, 1400,
	]
	var score: int = maxi(1, strength_score)
	var multiplier: int = 1
	while score > 29:
		score -= 10
		multiplier *= 4
	return table[score] * multiplier


func _new_stat(
		stat_id: StringName,
		display_name: String
):
	var stat = RESOLVED_STAT_SCRIPT.new()
	stat.configure(stat_id, display_name)
	return stat


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
