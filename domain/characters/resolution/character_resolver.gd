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
	result.troop_type = template.troop_type
	result.troop_tier = template.troop_tier
	result.portrait_id = character.effective_portrait_id(template)
	result.tactical_visual_id = template.tactical_visual_id
	result.footprint = template.footprint
	result.defence_profile_id = (
		defence_profile.id if defence_profile != null else &""
	)
	result.skill_bonuses = template.skill_bonuses.duplicate(true)
	result.trait_ids = template.trait_ids.duplicate()
	result.ability_entries = template.ability_entries.duplicate()
	result.injury_entries = character.injury_entries.duplicate()
	result.condition_entries = character.permanent_condition_entries.duplicate()
	result.history_entries = character.history_entries.duplicate()

	for character_trait in character.trait_entries:
		result.ability_entries.append(String(character_trait))

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
	_resolve_actions(result, template, equipment_inputs, active_modifiers)

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
		armour.add_line(
			&"ability.dexterity",
			"Dexterity",
			result.ability_modifier("DEX"),
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

	var grapple = _new_stat(&"grapple", "Grapple")
	if grapple != null:
		grapple.add_line(
			&"base_attack_bonus",
			"Base Attack Bonus",
			result.stat_value(&"base_attack_bonus"),
			&"progression"
		)
		grapple.add_line(
			&"ability.strength",
			"Strength",
			result.ability_modifier("STR"),
			&"ability"
		)
		_append_external_stat_modifiers(
			grapple,
			&"grapple",
			character,
			active_modifiers
		)
		result.stats_by_id[grapple.stat_id] = grapple

	var carry = _new_stat(&"maximum_weight_lb", "Carrying Capacity")
	if carry != null:
		carry.add_line(
			template.id,
			"Template capacity",
			int(round(float(template.maximum_weight_lb))),
			&"template"
		)
		_append_external_stat_modifiers(
			carry,
			&"maximum_weight_lb",
			character,
			active_modifiers
		)
		result.stats_by_id[carry.stat_id] = carry


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


func _resolve_actions(result, template, equipment_inputs: Array, active_modifiers: Array) -> void:
	var seen: Dictionary = {}

	for action_id_value in template.innate_action_ids:
		var action_id = StringName(action_id_value)
		if action_id.is_empty() or seen.has(action_id):
			continue
		seen[action_id] = true
		result.innate_action_ids.append(action_id)
		result.granted_action_ids.append(action_id)

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


func _append_action(target: Array, seen: Dictionary, action_id: StringName) -> void:
	if action_id.is_empty() or seen.has(action_id):
		return
	seen[action_id] = true
	target.append(action_id)


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
