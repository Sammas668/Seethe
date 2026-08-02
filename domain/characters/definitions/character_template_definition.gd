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
# Per-mission authored resources. Keys are stable resource IDs; values are
# maximum uses. Negative values represent at-will abilities.
@export var ability_resource_maximums: Dictionary = {}
# Mechanical feature metadata not reducible to ordinary attacks. Values are
# authored sheet facts and are queried by shared services and conformance tests.
@export var feature_parameters: Dictionary = {}
@export var skill_bonuses: Dictionary = {}
@export var ability_entries: Array[String] = []
@export var default_loadout_entries: Array[Dictionary] = []
@export var portrait_id: StringName = &""
@export var tactical_visual_id: StringName = &""

# Stage 4.7 production-content metadata. These values describe authored
# identity and AI/campaign eligibility; mission placements still own positions,
# squads and mission-specific role overrides.
@export var role_tags: Array[StringName] = []
@export var proficiency_ids: Array[StringName] = []
@export var ai_profile_id: StringName = &""
@export var combatant_classification: StringName = &"combatant"
@export var capture_eligible: bool = true
@export var surrender_eligible: bool = true
@export var loot_profile_id: StringName = &""
@export var provisional_content: bool = false

# Raider's Burden and future carrying-only features use an explicit effective
# Strength bonus. It never changes attacks, damage or manoeuvre checks.
@export var carrying_strength_bonus: int = 0
@export var carrying_capacity_bonus_per_strength_point_lb: float = 0.0


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
	if carrying_strength_bonus < 0:
		errors.append("Character template %s has a negative carrying Strength bonus." % id)
	if carrying_capacity_bonus_per_strength_point_lb < 0.0:
		errors.append("Character template %s has a negative carrying-capacity scale." % id)
	if combatant_classification not in [&"combatant", &"civilian", &"support"]:
		errors.append(
			"Character template %s has invalid combatant classification %s."
			% [id, combatant_classification]
		)
	if not provisional_content and ai_profile_id.is_empty() and combatant_classification != &"civilian":
		errors.append("Production combatant template %s has no AI profile." % id)
	if not provisional_content and loot_profile_id.is_empty():
		errors.append("Production character template %s has no loot profile." % id)
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

	var seen_roles: Dictionary = {}
	for role_id: StringName in role_tags:
		if role_id.is_empty():
			errors.append("Character template %s has an empty role tag." % id)
		elif seen_roles.has(role_id):
			errors.append("Character template %s repeats role tag %s." % [id, role_id])
		else:
			seen_roles[role_id] = true

	var seen_proficiencies: Dictionary = {}
	for proficiency_id: StringName in proficiency_ids:
		if proficiency_id.is_empty():
			errors.append("Character template %s has an empty proficiency ID." % id)
		elif seen_proficiencies.has(proficiency_id):
			errors.append(
				"Character template %s repeats proficiency %s."
				% [id, proficiency_id]
			)
		else:
			seen_proficiencies[proficiency_id] = true

	for raw_feature_id: Variant in feature_parameters.keys():
		var feature_id := StringName(raw_feature_id)
		if feature_id.is_empty():
			errors.append("Character template %s has an empty feature-parameter ID." % id)
		elif not trait_ids.has(feature_id):
			errors.append(
				"Character template %s has parameters for unowned feature %s."
				% [id, feature_id]
			)

	for raw_resource_id: Variant in ability_resource_maximums.keys():
		var resource_id := StringName(raw_resource_id)
		var maximum := int(ability_resource_maximums.get(raw_resource_id, 0))
		if resource_id.is_empty():
			errors.append("Character template %s has an empty ability resource ID." % id)
		elif maximum == 0 or maximum < -1:
			errors.append(
				"Character template %s has invalid maximum %d for %s."
				% [id, maximum, resource_id]
			)

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
