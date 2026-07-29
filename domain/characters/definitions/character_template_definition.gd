class_name CharacterTemplateDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Unnamed Character Template"
@export var species_name: String = "Unknown"
@export var class_name_text: String = "Unassigned"
@export var archetype_name: String = "None"
@export var troop_type: String = "Individual"
@export var troop_tier: int = 0
@export var base_level: int = 1
@export var base_xp: int = 0

@export var base_ability_scores: Dictionary = {
	"STR": 10,
	"DEX": 10,
	"CON": 10,
	"INT": 10,
	"WIS": 10,
	"CHA": 10,
}
@export var base_attack_bonus: int = 0
@export var base_save_bonuses: Dictionary = {
	"fortitude": 0,
	"reflex": 0,
	"will": 0,
}
@export var base_hp_before_constitution: int = 1
@export var hp_constitution_levels: int = 1
@export var base_armour_class: int = 10
@export var base_turn_capacity_feet: int = 30
@export var sprint_multiplier: float = 1.5
@export var passive_perception_base: int = 10
@export var perception_skill_bonus: int = 0
@export var initiative_flat_bonus: int = 0
@export var maximum_weight_lb: float = 60.0
@export var footprint: Vector2i = Vector2i.ONE

@export var default_defence_profile_id: StringName = &""
@export var innate_action_ids: Array[StringName] = []
@export var trait_ids: Array[StringName] = []
@export var skill_bonuses: Dictionary = {}
@export var ability_entries: Array[String] = []
@export var default_loadout_entries: Array[Dictionary] = []
@export var portrait_id: StringName = &""
@export var tactical_visual_id: StringName = &""


func ability_score(abbreviation: String) -> int:
	return int(base_ability_scores.get(abbreviation, 10))


func save_base(save_id: StringName) -> int:
	return int(base_save_bonuses.get(String(save_id), 0))


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Character template has an empty ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Character template %s has an empty display name." % id)
	if base_level < 1:
		errors.append("Character template %s has a base level below 1." % id)
	if troop_tier < 0:
		errors.append("Character template %s has a negative troop tier." % id)
	if base_hp_before_constitution < 1:
		errors.append("Character template %s has invalid base HP." % id)
	if hp_constitution_levels < 0:
		errors.append("Character template %s has negative Constitution HP levels." % id)
	if base_turn_capacity_feet < 5:
		errors.append("Character template %s has turn capacity below 5 feet." % id)
	if sprint_multiplier < 1.0:
		errors.append("Character template %s has a sprint multiplier below 1.0." % id)
	if maximum_weight_lb <= 0.0:
		errors.append("Character template %s has non-positive carrying capacity." % id)
	if footprint.x <= 0 or footprint.y <= 0:
		errors.append("Character template %s has a non-positive footprint." % id)
	for abbreviation: String in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		if not base_ability_scores.has(abbreviation):
			errors.append(
				"Character template %s is missing ability score %s."
				% [id, abbreviation]
			)

	var seen_actions: Dictionary = {}
	for action_id: StringName in innate_action_ids:
		if action_id.is_empty():
			errors.append("Character template %s has an empty action ID." % id)
		elif seen_actions.has(action_id):
			errors.append(
				"Character template %s repeats action %s." % [id, action_id]
			)
		else:
			seen_actions[action_id] = true

	var seen_traits: Dictionary = {}
	for trait_id: StringName in trait_ids:
		if trait_id.is_empty():
			errors.append("Character template %s has an empty trait ID." % id)
		elif seen_traits.has(trait_id):
			errors.append(
				"Character template %s repeats trait %s." % [id, trait_id]
			)
		else:
			seen_traits[trait_id] = true

	for entry: Dictionary in default_loadout_entries:
		var definition_id := StringName(entry.get("definition_id", &""))
		var container_kind := StringName(entry.get("container_kind", &""))
		if entry.has("instance_id"):
			errors.append(
				(
					"Character template %s authors a persistent item instance ID. "
					+ "Templates must remain identity-free."
				) % id
			)
		if definition_id.is_empty():
			errors.append(
				"Character template %s has a loadout entry with no item definition."
				% id
			)
		if container_kind.is_empty():
			errors.append(
				"Character template %s has a loadout entry with no container."
				% id
			)

	return errors
