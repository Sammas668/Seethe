class_name CharacterProgressionService
extends RefCounted

var _catalogue: ContentCatalogue


func configure(catalogue: ContentCatalogue) -> void:
	_catalogue = catalogue


const DEFAULT_XP_THRESHOLDS: Array[int] = [
	0, 0, 1000, 3000, 6000, 10000, 15000, 21000, 28000, 36000,
	45000, 55000, 66000, 78000, 91000, 105000, 120000, 136000, 153000,
	171000, 190000,
]


func next_level_preview(
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Dictionary:
	if character == null or template == null:
		return {"eligible": false, "reason": "Character progression data is unavailable."}
	var current_level: int = character.resolved_level(template)
	var target_level: int = current_level + 1
	var entry: Dictionary = _entry_for_level(template, target_level)
	var xp_required: int = int(entry.get("xp_required", xp_required_for_level(target_level)))
	var selected_talent_ids: Array[StringName] = character.selected_talent_ids.duplicate()
	var talent_choices: Array = entry.get("talent_choices", []) as Array
	return {
		"eligible": not character.is_dead and character.xp >= xp_required,
		"current_level": current_level,
		"target_level": target_level,
		"xp": character.xp,
		"xp_required": xp_required,
		"automatic_stat_adjustments": (entry.get("stat_adjustments", {}) as Dictionary).duplicate(true),
		"automatic_ability_adjustments": (entry.get("ability_adjustments", {}) as Dictionary).duplicate(true),
		"granted_trait_ids": _string_name_array(entry.get("granted_trait_ids", [])),
		"granted_ability_ids": _string_name_array(entry.get("granted_ability_ids", [])),
		"talent_choices": talent_choices.duplicate(true),
		"selected_talent_ids": selected_talent_ids,
		"summary": String(entry.get("summary", "Authored troop progression.")),
	}


func apply_level_candidate(
		campaign: CampaignState,
		character_id: StringName,
		expected_level: int,
		selected_talent_id: StringName = &""
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var character: PersistentCharacterState = campaign.get_character(character_id)
	if character == null:
		return OperationResult.fail(&"character_missing", "The selected character no longer exists.")
	if character.is_dead:
		return OperationResult.fail(&"character_dead", "Dead characters cannot level up.")
	if _catalogue == null:
		return OperationResult.fail(&"progression_service_unconfigured", "Character progression service is not configured.")
	var template: CharacterTemplateDefinition = _catalogue.character_template(character.template_id)
	if template == null:
		return OperationResult.fail(&"character_template_missing", "The character template is missing.")
	var preview: Dictionary = next_level_preview(character, template)
	if int(preview.get("current_level", 0)) != expected_level:
		return OperationResult.fail(&"level_changed", "The character's current Level changed; refresh the progression view.")
	if not bool(preview.get("eligible", false)):
		return OperationResult.fail(&"xp_threshold_missing", "The character has not reached the next XP threshold.")
	var choices: Array = preview.get("talent_choices", []) as Array
	if not choices.is_empty():
		var chosen_valid: bool = false
		for raw_choice: Variant in choices:
			if raw_choice is Dictionary and StringName((raw_choice as Dictionary).get("id", "")) == selected_talent_id:
				chosen_valid = true
				break
		if not chosen_valid:
			return OperationResult.fail(&"talent_choice_required", "Choose one valid talent before confirming the Level.")
		if character.selected_talent_ids.has(selected_talent_id):
			return OperationResult.fail(&"talent_already_selected", "That talent is already selected.")
	var stat_adjustments: Dictionary = preview.get("automatic_stat_adjustments", {}) as Dictionary
	for raw_key: Variant in stat_adjustments.keys():
		var key: String = String(raw_key)
		character.stat_adjustments[key] = int(character.stat_adjustments.get(key, 0)) + int(stat_adjustments[raw_key])
	var ability_adjustments: Dictionary = preview.get("automatic_ability_adjustments", {}) as Dictionary
	for raw_key: Variant in ability_adjustments.keys():
		var key: String = String(raw_key)
		character.ability_adjustments[key] = int(character.ability_adjustments.get(key, 0)) + int(ability_adjustments[raw_key])
	var raw_traits: Variant = preview.get("granted_trait_ids", [])
	if raw_traits is Array:
		for raw_trait_id: Variant in raw_traits as Array:
			var trait_id := StringName(raw_trait_id)
			if not trait_id.is_empty() and not character.trait_entries.has(String(trait_id)):
				character.trait_entries.append(String(trait_id))
	var raw_abilities: Variant = preview.get("granted_ability_ids", [])
	if raw_abilities is Array:
		for raw_ability_id: Variant in raw_abilities as Array:
			var ability_id := StringName(raw_ability_id)
			if ability_id.is_empty():
				continue
			character.stat_adjustments["granted_ability.%s" % String(ability_id)] = 1
	if not selected_talent_id.is_empty():
		character.selected_talent_ids.append(selected_talent_id)
	character.set_level_adjustment(character.level_adjustment + 1)
	var reached_level: int = int(preview.get("target_level", expected_level + 1))
	# Ordinary henchmen follow one base class, so their class rank tracks their
	# Character Level. Do not mirror this onto the protagonist: protagonist
	# multiclass/archetype ranks belong to the separate class progression system.
	if not character.career_id.is_empty() and not character.base_class_id.is_empty():
		character.class_ranks[character.base_class_id] = maxi(
			character.class_rank(character.base_class_id),
			reached_level
		)
	character.add_history("Reached Level %d%s." % [
		int(preview.get("target_level", expected_level + 1)),
		" and selected %s" % String(selected_talent_id).replace("_", " ").capitalize()
		if not selected_talent_id.is_empty()
		else "",
	])
	return OperationResult.ok(character, "%s reached Level %d." % [character.display_name, int(preview.get("target_level", expected_level + 1))])


func xp_required_for_level(level: int) -> int:
	if level >= 0 and level < DEFAULT_XP_THRESHOLDS.size():
		return DEFAULT_XP_THRESHOLDS[level]
	var previous: int = DEFAULT_XP_THRESHOLDS[-1]
	var current_level: int = DEFAULT_XP_THRESHOLDS.size() - 1
	while current_level < level:
		previous += current_level * 1000
		current_level += 1
	return previous


func _entry_for_level(template: CharacterTemplateDefinition, target_level: int) -> Dictionary:
	for raw_entry: Variant in template.level_progression_entries:
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry as Dictionary
			if int(entry.get("level", 0)) == target_level:
				return entry.duplicate(true)
	return {
		"level": target_level,
		"xp_required": xp_required_for_level(target_level),
		"stat_adjustments": {
			"base_attack_bonus": 1,
			"maximum_hp": 6,
		},
		"summary": "Fallback ordinary-troop progression.",
	}


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not value is Array:
		return result
	for entry: Variant in value as Array:
		var parsed := StringName(entry)
		if not parsed.is_empty():
			result.append(parsed)
	return result
