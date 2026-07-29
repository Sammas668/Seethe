class_name GodotContentLoader
extends RefCounted


static func populate_catalogue(
		catalogue: ContentCatalogue,
		item_resources: Array,
		action_resources: Array,
		defence_resources: Array,
		character_resources: Array,
		modifier_resources: Array
) -> Array[String]:
	var errors: Array[String] = []
	if catalogue == null:
		errors.append("GodotContentLoader requires a ContentCatalogue.")
		return errors

	for resource: Resource in item_resources:
		var definition: ItemDefinition = resource as ItemDefinition
		if definition == null or not catalogue.register_item_definition(definition):
			errors.append("Duplicate or invalid item definition resource.")

	for resource: Resource in action_resources:
		var definition: ActionDefinition = resource as ActionDefinition
		if definition == null or not catalogue.register_action_definition(definition):
			errors.append("Duplicate or invalid action definition resource.")

	for resource: Resource in defence_resources:
		var profile: DefenceProfile = resource as DefenceProfile
		if profile == null or not catalogue.register_defence_profile(profile):
			errors.append("Duplicate or invalid defence profile resource.")

	for resource: Resource in character_resources:
		var template: CharacterTemplateDefinition = (
			resource as CharacterTemplateDefinition
		)
		if template == null or not catalogue.register_character_template(template):
			errors.append("Duplicate or invalid character template resource.")

	for resource: Resource in modifier_resources:
		var modifier: CharacterModifierDefinition = (
			resource as CharacterModifierDefinition
		)
		if modifier == null or not catalogue.register_character_modifier(modifier):
			errors.append("Duplicate or invalid character modifier resource.")

	return errors
