class_name ContentCatalogue
extends RefCounted

const DismantlingRecipeDefinitionScript = preload(
	"res://domain/inventory/definitions/dismantling_recipe_definition.gd"
)

var item_definitions_by_id: Dictionary = {}
var action_definitions_by_id: Dictionary = {}
var defence_profiles_by_id: Dictionary = {}
var character_templates_by_id: Dictionary = {}
var character_modifiers_by_id: Dictionary = {}
var ai_profiles_by_id: Dictionary = {}
var dismantling_recipes_by_id: Dictionary = {}
var dismantling_recipe_ids_by_item_definition_id: Dictionary = {}
var troop_careers_by_id: Dictionary = {}
var prestige_stages_by_id: Dictionary = {}
var henchman_recruitment_definitions_by_id: Dictionary = {}
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


func register_dismantling_recipe(definition: DismantlingRecipeDefinitionScript) -> bool:
	if not _can_register(definition, definition.id if definition != null else &""):
		return false
	if dismantling_recipe_ids_by_item_definition_id.has(definition.input_item_definition_id):
		return false
	dismantling_recipes_by_id[definition.id] = definition
	dismantling_recipe_ids_by_item_definition_id[definition.input_item_definition_id] = definition.id
	return true


func register_troop_career(definition: TroopCareerDefinition) -> bool:
	if not _can_register(definition, definition.career_id if definition != null else &""):
		return false
	troop_careers_by_id[definition.career_id] = definition
	return true


func register_prestige_stage(definition: TroopPrestigeStageDefinition) -> bool:
	if not _can_register(definition, definition.stage_id if definition != null else &""):
		return false
	prestige_stages_by_id[definition.stage_id] = definition
	return true


func register_henchman_recruitment_definition(definition: HenchmanRecruitmentDefinition) -> bool:
	if not _can_register(definition, definition.recruitment_id if definition != null else &""):
		return false
	henchman_recruitment_definitions_by_id[definition.recruitment_id] = definition
	return true


func register_ai_profile(definition: TacticalAIProfileDefinition) -> bool:
	if not _can_register(definition, definition.id if definition != null else &""):
		return false
	ai_profiles_by_id[definition.id] = definition
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
		or ai_profiles_by_id.has(definition_id)
		or dismantling_recipes_by_id.has(definition_id)
		or troop_careers_by_id.has(definition_id)
		or prestige_stages_by_id.has(definition_id)
		or henchman_recruitment_definitions_by_id.has(definition_id)
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


func ai_profile(profile_id: StringName) -> TacticalAIProfileDefinition:
	return ai_profiles_by_id.get(profile_id) as TacticalAIProfileDefinition


func dismantling_recipe(recipe_id: StringName) -> DismantlingRecipeDefinitionScript:
	return dismantling_recipes_by_id.get(recipe_id) as DismantlingRecipeDefinitionScript


func dismantling_recipe_for_item(
		item_definition_id: StringName
) -> DismantlingRecipeDefinitionScript:
	var recipe_id := StringName(
		dismantling_recipe_ids_by_item_definition_id.get(item_definition_id, &"")
	)
	return dismantling_recipe(recipe_id) if not recipe_id.is_empty() else null


func troop_career(career_id: StringName) -> TroopCareerDefinition:
	return troop_careers_by_id.get(career_id) as TroopCareerDefinition


func prestige_stage(stage_id: StringName) -> TroopPrestigeStageDefinition:
	return prestige_stages_by_id.get(stage_id) as TroopPrestigeStageDefinition


func henchman_recruitment_definition(recruitment_id: StringName) -> HenchmanRecruitmentDefinition:
	return henchman_recruitment_definitions_by_id.get(recruitment_id) as HenchmanRecruitmentDefinition


func recruitment_definition(recruitment_id: StringName) -> HenchmanRecruitmentDefinition:
	return henchman_recruitment_definition(recruitment_id)


func troop_careers() -> Array[TroopCareerDefinition]:
	var result: Array[TroopCareerDefinition] = []
	for definition: TroopCareerDefinition in troop_careers_by_id.values():
		result.append(definition)
	return result


func henchman_recruitment_definitions() -> Array[HenchmanRecruitmentDefinition]:
	var result: Array[HenchmanRecruitmentDefinition] = []
	for definition: HenchmanRecruitmentDefinition in henchman_recruitment_definitions_by_id.values():
		result.append(definition)
	return result


func recruitment_definitions() -> Array[HenchmanRecruitmentDefinition]:
	return henchman_recruitment_definitions()


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
		"ai_profiles": ai_profiles_by_id.size(),
		"dismantling_recipes": dismantling_recipes_by_id.size(),
		"troop_careers": troop_careers_by_id.size(),
		"prestige_stages": prestige_stages_by_id.size(),
		"henchman_recruitment_definitions": henchman_recruitment_definitions_by_id.size(),
	}


func validate_catalogue() -> Array[String]:
	var errors: Array[String] = []
	_validate_items(errors)
	_validate_actions(errors)
	_validate_defences(errors)
	_validate_character_templates(errors)
	_validate_character_modifiers(errors)
	_validate_ai_profiles(errors)
	_validate_dismantling_recipes(errors)
	_validate_troop_careers(errors)
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
		if (
			not template.ai_profile_id.is_empty()
			and not ai_profiles_by_id.has(template.ai_profile_id)
		):
			errors.append(
				"Character template %s references unknown AI profile %s."
				% [template.id, template.ai_profile_id]
			)
		for action_id: StringName in template.innate_action_ids:
			if not action_definitions_by_id.has(action_id):
				errors.append(
					"Character template %s references unknown innate action %s."
					% [template.id, action_id]
				)
		_validate_character_default_loadout(template, errors)


func _validate_character_default_loadout(
		template: CharacterTemplateDefinition,
		errors: Array[String]
) -> void:
	var occupied_inventory_cells: Dictionary = {}
	var equipped_hand_item_ids: Dictionary = {}
	var equipped_fixed_slot_item_ids: Dictionary = {}

	for entry_index: int in range(template.default_loadout_entries.size()):
		var entry: Dictionary = template.default_loadout_entries[entry_index]
		var item_id: StringName = StringName(entry.get("definition_id", &""))
		if not item_definitions_by_id.has(item_id):
			errors.append(
				"Character template %s references unknown item %s."
				% [template.id, item_id]
			)
			continue

		var definition: ItemDefinition = item_definition(item_id)
		if definition == null:
			continue
		var container_kind: StringName = StringName(
			entry.get("container_kind", &"")
		)
		var grid_position: Vector2i = entry.get(
			"grid_position", Vector2i.ZERO
		)
		var quantity: int = maxi(1, int(entry.get("quantity", 1)))

		if quantity > definition.maximum_stack_size:
			errors.append(
				"Character template %s loadout item %s exceeds stack limit %d."
				% [template.id, item_id, definition.maximum_stack_size]
			)
		if not definition.stackable and quantity != 1:
			errors.append(
				"Character template %s gives non-stackable item %s quantity %d."
				% [template.id, item_id, quantity]
			)

		match container_kind:
			TacticalInventoryState.KIND_PRIMARY_HAND, TacticalInventoryState.KIND_SECONDARY_HAND:
				if not definition.can_equip_in_hand():
					errors.append(
						"Character template %s equips item %s in a hand, but the item is not hand-equippable."
						% [template.id, item_id]
					)
				if quantity != 1:
					errors.append(
						"Character template %s equips item %s with quantity %d."
						% [template.id, item_id, quantity]
					)
				if equipped_hand_item_ids.has(container_kind):
					errors.append(
						"Character template %s assigns both %s and %s to %s."
						% [
							template.id,
							equipped_hand_item_ids[container_kind],
							item_id,
							container_kind,
						]
					)
				else:
					equipped_hand_item_ids[container_kind] = item_id
				if (
					container_kind == TacticalInventoryState.KIND_SECONDARY_HAND
					and definition.is_two_handed()
				):
					errors.append(
						"Character template %s equips two-handed item %s in Secondary Hand."
						% [template.id, item_id]
					)

			TacticalInventoryState.KIND_ARMOUR, TacticalInventoryState.KIND_WORN_UTILITY:
				if not definition.can_equip_in_slot(container_kind):
					errors.append(
						"Character template %s equips item %s in unsupported fixed slot %s."
						% [template.id, item_id, container_kind]
					)
				if quantity != 1:
					errors.append(
						"Character template %s equips fixed-slot item %s with quantity %d."
						% [template.id, item_id, quantity]
					)
				if equipped_fixed_slot_item_ids.has(container_kind):
					errors.append(
						"Character template %s assigns both %s and %s to %s."
						% [template.id, equipped_fixed_slot_item_ids[container_kind], item_id, container_kind]
					)
				else:
					equipped_fixed_slot_item_ids[container_kind] = item_id

			TacticalInventoryState.KIND_BELT, TacticalInventoryState.KIND_BACKPACK:
				if (
					container_kind == TacticalInventoryState.KIND_BELT
					and not definition.belt_allowed
				):
					errors.append(
						"Character template %s places item %s on the Belt, but the item is not Belt-legal."
						% [template.id, item_id]
					)
				if (
					container_kind == TacticalInventoryState.KIND_BACKPACK
					and not definition.backpack_allowed
				):
					errors.append(
						"Character template %s places item %s in the Backpack, but the item is not Backpack-legal."
						% [template.id, item_id]
					)

				var container_width: int = (
					TacticalInventoryState.BELT_WIDTH
					if container_kind == TacticalInventoryState.KIND_BELT
					else TacticalInventoryState.BACKPACK_WIDTH
				)
				var container_height: int = (
					TacticalInventoryState.BELT_HEIGHT
					if container_kind == TacticalInventoryState.KIND_BELT
					else TacticalInventoryState.BACKPACK_HEIGHT
				)
				var rect: Rect2i = Rect2i(
					grid_position, definition.inventory_footprint
				)
				var rect_end: Vector2i = rect.position + rect.size
				if (
					rect.position.x < 0
					or rect.position.y < 0
					or rect_end.x > container_width
					or rect_end.y > container_height
				):
					errors.append(
						"Character template %s places item %s outside the %s grid."
						% [template.id, item_id, container_kind]
					)

				for y: int in range(rect.position.y, rect_end.y):
					for x: int in range(rect.position.x, rect_end.x):
						var occupancy_key: String = "%s|%d|%d" % [
							container_kind, x, y,
						]
						if occupied_inventory_cells.has(occupancy_key):
							errors.append(
								"Character template %s loadout items %s and %s overlap in %s."
								% [
									template.id,
									occupied_inventory_cells[occupancy_key],
									item_id,
									container_kind,
								]
							)
						else:
							occupied_inventory_cells[occupancy_key] = item_id

			_:
				errors.append(
					"Character template %s places item %s in unknown container %s."
					% [template.id, item_id, container_kind]
				)

	var primary_item_id: StringName = StringName(
		equipped_hand_item_ids.get(TacticalInventoryState.KIND_PRIMARY_HAND, &"")
	)
	var secondary_item_id: StringName = StringName(
		equipped_hand_item_ids.get(TacticalInventoryState.KIND_SECONDARY_HAND, &"")
	)
	if not primary_item_id.is_empty() and not secondary_item_id.is_empty():
		var primary_definition: ItemDefinition = item_definition(primary_item_id)
		if primary_definition != null and primary_definition.is_two_handed():
			errors.append(
				"Character template %s equips two-handed item %s with Secondary Hand item %s."
				% [template.id, primary_item_id, secondary_item_id]
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


func _validate_ai_profiles(errors: Array[String]) -> void:
	for raw_id: Variant in ai_profiles_by_id.keys():
		var profile_id: StringName = StringName(raw_id)
		var profile: TacticalAIProfileDefinition = ai_profile(profile_id)
		if profile == null:
			errors.append("AI profile catalogue contains a null entry: %s" % profile_id)
			continue
		if profile.id != profile_id:
			errors.append("AI profile catalogue key does not match %s." % profile_id)
		errors.append_array(profile.validate_definition())


func _validate_dismantling_recipes(errors: Array[String]) -> void:
	for raw_id: Variant in dismantling_recipes_by_id.keys():
		var recipe_id := StringName(raw_id)
		var definition: DismantlingRecipeDefinitionScript = dismantling_recipe(recipe_id)
		if definition == null:
			errors.append("Dismantling catalogue contains a null entry: %s" % recipe_id)
			continue
		if definition.id != recipe_id:
			errors.append("Dismantling catalogue key does not match %s." % recipe_id)
		errors.append_array(definition.validate_definition())
		if not item_definitions_by_id.has(definition.input_item_definition_id):
			errors.append(
				"Dismantling recipe %s references unknown item %s."
				% [definition.id, definition.input_item_definition_id]
			)

func _validate_troop_careers(errors: Array[String]) -> void:
	for raw_id: Variant in troop_careers_by_id.keys():
		var career_id := StringName(raw_id)
		var career: TroopCareerDefinition = troop_career(career_id)
		if career == null:
			errors.append("Troop career catalogue contains a null entry: %s" % career_id)
			continue
		if career.career_id != career_id:
			errors.append("Troop career catalogue key does not match %s." % career_id)
		errors.append_array(career.validate_definition())
		if not henchman_recruitment_definitions_by_id.has(career.base_recruitment_definition_id):
			errors.append("Troop career %s references unknown recruitment definition %s." % [career_id, career.base_recruitment_definition_id])
		for stage_index: int in range(career.stage_ids.size()):
			var stage_id: StringName = career.stage_ids[stage_index]
			var stage: TroopPrestigeStageDefinition = prestige_stage(stage_id)
			if stage == null:
				errors.append("Troop career %s references unknown Prestige stage %s." % [career_id, stage_id])
				continue
			if stage.career_id != career_id or stage.stage_index != stage_index + 1:
				errors.append("Prestige stage %s is not in the correct ordered position for career %s." % [stage_id, career_id])

	for raw_id: Variant in prestige_stages_by_id.keys():
		var stage_id := StringName(raw_id)
		var stage: TroopPrestigeStageDefinition = prestige_stage(stage_id)
		if stage == null:
			errors.append("Prestige stage catalogue contains a null entry: %s" % stage_id)
			continue
		if stage.stage_id != stage_id:
			errors.append("Prestige stage catalogue key does not match %s." % stage_id)
		errors.append_array(stage.validate_definition())
		if not troop_careers_by_id.has(stage.career_id):
			errors.append("Prestige stage %s references unknown career %s." % [stage_id, stage.career_id])
		for action_id: StringName in stage.granted_action_ids:
			if not action_definitions_by_id.has(action_id):
				errors.append("Prestige stage %s grants unknown action %s." % [stage_id, action_id])

	for raw_id: Variant in henchman_recruitment_definitions_by_id.keys():
		var recruitment_id := StringName(raw_id)
		var definition: HenchmanRecruitmentDefinition = henchman_recruitment_definition(recruitment_id)
		if definition == null:
			errors.append("Henchman recruitment catalogue contains a null entry: %s" % recruitment_id)
			continue
		if definition.recruitment_id != recruitment_id:
			errors.append("Henchman recruitment catalogue key does not match %s." % recruitment_id)
		errors.append_array(definition.validate_definition())
		if not troop_careers_by_id.has(definition.career_id):
			errors.append("Recruitment definition %s references unknown career %s." % [recruitment_id, definition.career_id])
		if not character_templates_by_id.has(definition.resulting_character_template_id):
			errors.append("Recruitment definition %s references unknown character template %s." % [recruitment_id, definition.resulting_character_template_id])

