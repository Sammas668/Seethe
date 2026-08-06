class_name TroopPrestigeStageDefinition
extends Resource

@export var stage_id: StringName = &""
@export var career_id: StringName = &""
@export var stage_index: int = 0
@export var troop_tier: int = 0
@export var minimum_character_level: int = 1
@export var source_troop_type_id: StringName = &""
@export var resulting_troop_type_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

# Only this package is exclusive. When a troop Prestiges, its previous Tier's
# starting feats are removed and these starting feats become active.
@export var tier_starting_feat_ids: Array[StringName] = []
@export var tier_starting_feat_parameters: Dictionary = {}

# Every other earned grant is permanent and cumulative. Level-up grants,
# ordinary feats, spells, abilities and earlier Prestige abilities remain.
@export var granted_feat_ids: Array[StringName] = []
@export var granted_ability_ids: Array[StringName] = []
@export var granted_proficiency_ids: Array[StringName] = []
@export var granted_trait_ids: Array[StringName] = []
@export var granted_action_ids: Array[StringName] = []
@export var granted_role_tags: Array[StringName] = []
@export var ability_entries: Array[String] = []
@export var feature_parameters: Dictionary = {}
@export var permanent_stat_adjustments: Dictionary = {}
@export var feature_upgrades: Dictionary = {}

@export var transition_type: StringName = &"role"
@export var resulting_body_profile_id: StringName = &""
@export var resulting_companion_definition_id: StringName = &""
@export var required_research_ids: Array[StringName] = []
@export var required_facility_id: StringName = &""
@export var minimum_facility_level: int = 1
@export var required_protagonist_class_id: StringName = &""
@export var minimum_protagonist_class_level: int = 1
@export var required_protagonist_archetype_id: StringName = &""
@export var minimum_protagonist_archetype_rank: int = 0
@export var resource_costs: Dictionary = {}
@export var required_item_ids: Array[StringName] = []
@export var duration_ticks: int = 720
@export var artwork_path: String = ""
@export var icon_path: String = ""


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if stage_id.is_empty():
		errors.append("Prestige stage has no ID.")
	if career_id.is_empty():
		errors.append("Prestige stage %s has no career." % stage_id)
	if stage_index < 1:
		errors.append("Prestige stage %s has invalid stage index." % stage_id)
	if troop_tier < 1:
		errors.append("Prestige stage %s has invalid troop tier." % stage_id)
	elif stage_index != troop_tier:
		errors.append("Prestige stage %s index %d does not match troop Tier %d." % [stage_id, stage_index, troop_tier])
	if minimum_character_level < 1:
		errors.append("Prestige stage %s has invalid minimum Level." % stage_id)
	if resulting_troop_type_id.is_empty():
		errors.append("Prestige stage %s has no resulting troop type." % stage_id)
	if duration_ticks <= 0:
		errors.append("Prestige stage %s has invalid duration." % stage_id)
	var seen: Dictionary = {}
	_validate_grants(tier_starting_feat_ids, "Tier starting feat", seen, errors)
	_validate_grants(granted_feat_ids, "permanent feat", seen, errors)
	_validate_grants(granted_ability_ids, "ability", seen, errors)
	_validate_grants(granted_proficiency_ids, "proficiency", seen, errors)
	_validate_grants(granted_trait_ids, "trait", seen, errors)
	_validate_grants(granted_action_ids, "action", seen, errors)
	for raw_resource_id: Variant in resource_costs.keys():
		var resource_id := StringName(raw_resource_id)
		if resource_id.is_empty() or int(resource_costs[raw_resource_id]) < 0:
			errors.append("Prestige stage %s has an invalid resource cost." % stage_id)
	return errors


func _validate_grants(ids: Array[StringName], kind: String, seen: Dictionary, errors: Array[String]) -> void:
	for grant_id: StringName in ids:
		if grant_id.is_empty():
			errors.append("Prestige stage %s grants an empty %s ID." % [stage_id, kind])
		elif seen.has(grant_id):
			errors.append("Prestige stage %s grants %s more than once." % [stage_id, grant_id])
		else:
			seen[grant_id] = kind
