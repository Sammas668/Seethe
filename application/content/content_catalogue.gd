class_name ContentCatalogue
extends RefCounted

var item_definitions_by_id: Dictionary = {}
var action_definitions_by_id: Dictionary = {}
var defence_profiles_by_id: Dictionary = {}
var character_templates_by_id: Dictionary = {}
var character_modifiers_by_id: Dictionary = {}
var _frozen: bool = false


func register_item_definition(definition: ItemDefinition) -> bool:
	if not _can_register(definition, definition.id if definition != null else &""):
		return false
	item_definitions_by_id[definition.id] = definition
	return true


func register_action_definition(definition: ActionDefinition) -> bool:
	if not _can_register(definition, definition.id if definition != null else &""):
		return false
	action_definitions_by_id[definition.id] = definition
	return true


func register_defence_profile(profile: DefenceProfile) -> bool:
	if not _can_register(profile, profile.id if profile != null else &""):
		return false
	defence_profiles_by_id[profile.id] = profile
	return true


func register_character_template(
		definition: CharacterTemplateDefinition
) -> bool:
	if not _can_register(definition, definition.id if definition != null else &""):
		return false
	character_templates_by_id[definition.id] = definition
	return true


func register_character_modifier(
		definition: CharacterModifierDefinition
) -> bool:
	if not _can_register(definition, definition.id if definition != null else &""):
		return false
	character_modifiers_by_id[definition.id] = definition
	return true


func _can_register(definition: Variant, definition_id: StringName) -> bool:
	if _frozen:
		push_error("ContentCatalogue is frozen and cannot accept new definitions.")
		return false
	if definition == null or definition_id.is_empty():
		return false
	return not _contains_definition_id(definition_id)


func _contains_definition_id(definition_id: StringName) -> bool:
	return (
		item_definitions_by_id.has(definition_id)
		or action_definitions_by_id.has(definition_id)
		or defence_profiles_by_id.has(definition_id)
		or character_templates_by_id.has(definition_id)
		or character_modifiers_by_id.has(definition_id)
	)


func item_definition(definition_id: StringName) -> ItemDefinition:
	return item_definitions_by_id.get(definition_id) as ItemDefinition


func action_definition(action_id: StringName) -> ActionDefinition:
	return action_definitions_by_id.get(action_id) as ActionDefinition


func attack_definition(action_id: StringName) -> AttackDefinition:
	return action_definitions_by_id.get(action_id) as AttackDefinition


func defence_profile(profile_id: StringName) -> DefenceProfile:
	return defence_profiles_by_id.get(profile_id) as DefenceProfile


func character_template(
		template_id: StringName
) -> CharacterTemplateDefinition:
	return character_templates_by_id.get(template_id) as CharacterTemplateDefinition


func character_modifier(
		modifier_id: StringName
) -> CharacterModifierDefinition:
	return character_modifiers_by_id.get(modifier_id) as CharacterModifierDefinition


func actions_granted_by_item(
		definition: ItemDefinition
) -> Array[ActionDefinition]:
	var result: Array[ActionDefinition] = []
	if definition == null:
		return result
	for action_id: StringName in definition.granted_action_ids:
		var action: ActionDefinition = action_definition(action_id)
		if action != null:
			result.append(action)
	return result


func freeze() -> void:
	_frozen = true


func is_frozen() -> bool:
	return _frozen


func definition_counts() -> Dictionary:
	return {
		"items": item_definitions_by_id.size(),
		"actions": action_definitions_by_id.size(),
		"defences": defence_profiles_by_id.size(),
		"characters": character_templates_by_id.size(),
		"modifiers": character_modifiers_by_id.size(),
	}


func validate_catalogue() -> Array[String]:
	var errors: Array[String] = []
	_validate_items(errors)
	_validate_actions(errors)
	_validate_defences(errors)
	_validate_character_templates(errors)
	_validate_character_modifiers(errors)
	return errors


func _validate_items(errors: Array[String]) -> void:
	for raw_id: Variant in item_definitions_by_id.keys():
		var definition_id: StringName = StringName(raw_id)
		var definition: ItemDefinition = item_definition(definition_id)
		if definition == null:
			errors.append("Item catalogue contains a null entry: %s" % definition_id)
			continue
		if definition.id != definition_id:
			errors.append("Item catalogue key does not match %s." % definition_id)
		errors.append_array(definition.validate_definition())
		if (
			not definition.defence_profile_id.is_empty()
			and not defence_profiles_by_id.has(definition.defence_profile_id)
		):
			errors.append(
				"Item %s references unknown defence profile %s."
				% [definition.id, definition.defence_profile_id]
			)
		for action_id: StringName in definition.granted_action_ids:
			if not action_definitions_by_id.has(action_id):
				errors.append(
					"Item %s grants unknown action %s."
					% [definition.id, action_id]
				)


func _validate_actions(errors: Array[String]) -> void:
	for raw_id: Variant in action_definitions_by_id.keys():
		var action_id: StringName = StringName(raw_id)
		var action: ActionDefinition = action_definition(action_id)
		if action == null:
			errors.append("Action catalogue contains a null entry: %s" % action_id)
			continue
		if action.id != action_id:
			errors.append("Action catalogue key does not match %s." % action_id)
		errors.append_array(action.validate_definition())


func _validate_defences(errors: Array[String]) -> void:
	for raw_id: Variant in defence_profiles_by_id.keys():
		var profile_id: StringName = StringName(raw_id)
		var profile: DefenceProfile = defence_profile(profile_id)
		if profile == null:
			errors.append("Defence catalogue contains a null entry: %s" % profile_id)
			continue
		if profile.id != profile_id:
			errors.append("Defence catalogue key does not match %s." % profile_id)
		errors.append_array(profile.validate_definition())


func _validate_character_templates(errors: Array[String]) -> void:
	for raw_id: Variant in character_templates_by_id.keys():
		var template_id: StringName = StringName(raw_id)
		var template: CharacterTemplateDefinition = character_template(template_id)
		if template == null:
			errors.append(
				"Character template catalogue contains a null entry: %s"
				% template_id
			)
			continue
		if template.id != template_id:
			errors.append(
				"Character template catalogue key does not match %s."
				% template_id
			)
		errors.append_array(template.validate_definition())
		if not defence_profiles_by_id.has(template.default_defence_profile_id):
			errors.append(
				"Character template %s references unknown defence profile %s."
				% [template.id, template.default_defence_profile_id]
			)
		for action_id: StringName in template.innate_action_ids:
			if not action_definitions_by_id.has(action_id):
				errors.append(
					"Character template %s references unknown innate action %s."
					% [template.id, action_id]
				)
		for entry: Dictionary in template.default_loadout_entries:
			var item_id: StringName = StringName(entry.get("definition_id", &""))
			if not item_definitions_by_id.has(item_id):
				errors.append(
					"Character template %s references unknown item %s."
					% [template.id, item_id]
				)


func _validate_character_modifiers(errors: Array[String]) -> void:
	for raw_id: Variant in character_modifiers_by_id.keys():
		var modifier_id: StringName = StringName(raw_id)
		var modifier: CharacterModifierDefinition = character_modifier(modifier_id)
		if modifier == null:
			errors.append(
				"Character modifier catalogue contains a null entry: %s"
				% modifier_id
			)
			continue
		if modifier.id != modifier_id:
			errors.append(
				"Character modifier catalogue key does not match %s."
				% modifier_id
			)
		errors.append_array(modifier.validate_definition())
		for action_id: StringName in modifier.granted_action_ids:
			if not action_definitions_by_id.has(action_id):
				errors.append(
					"Character modifier %s grants unknown action %s."
					% [modifier.id, action_id]
				)
