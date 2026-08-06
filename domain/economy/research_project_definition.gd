class_name ResearchProjectDefinition
extends Resource

const BRANCH_UNIVERSAL: StringName = &"universal"
const BRANCH_CLASS: StringName = &"class"
const BRANCH_ARCHETYPE: StringName = &"archetype"
const BRANCH_HYBRID: StringName = &"hybrid"

@export var research_id: StringName = &""
@export var display_name: String = "Research project"
@export_multiline var description: String = ""
@export var branch_id: StringName = BRANCH_UNIVERSAL
@export var starting_revealed: bool = false
@export var reveal_source_ids: Array[StringName] = []
@export var prerequisite_research_ids: Array[StringName] = []
@export var required_facility_definition_id: StringName = &"facility.fifth_god_heart"
@export var minimum_facility_level: int = 1
@export var resource_costs: Dictionary = {}
@export var total_work_required: int = 1
@export var minimum_workers: int = 1
@export var maximum_workers: int = 1
@export var granted_capability_ids: Array[StringName] = []
@export var unlocked_contact_ids: Array[StringName] = []
@export var unlocked_recipe_ids: Array[StringName] = []
@export var unlocked_worker_definition_ids: Array[StringName] = []


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if research_id.is_empty():
		errors.append("Research project has no ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Research project %s has no display name." % research_id)
	if branch_id not in [BRANCH_UNIVERSAL, BRANCH_CLASS, BRANCH_ARCHETYPE, BRANCH_HYBRID]:
		errors.append("Research project %s has invalid branch %s." % [research_id, branch_id])
	if minimum_facility_level <= 0:
		errors.append("Research project %s has an invalid facility level." % research_id)
	if total_work_required <= 0:
		errors.append("Research project %s has non-positive work." % research_id)
	if minimum_workers <= 0 or maximum_workers <= 0 or minimum_workers > maximum_workers:
		errors.append("Research project %s has invalid worker limits." % research_id)
	for raw_resource_id: Variant in resource_costs.keys():
		if StringName(raw_resource_id).is_empty() or int(resource_costs[raw_resource_id]) < 0:
			errors.append("Research project %s has an invalid resource cost." % research_id)
	return errors


func is_revealed(campaign: CampaignState) -> bool:
	if campaign == null:
		return false
	if starting_revealed or campaign.has_completed_research(research_id):
		return true
	for source_id: StringName in reveal_source_ids:
		if campaign.has_research_source(source_id):
			return true
	return false


func prerequisites_met(campaign: CampaignState) -> bool:
	if campaign == null:
		return false
	for prerequisite_id: StringName in prerequisite_research_ids:
		if not campaign.has_completed_research(prerequisite_id):
			return false
	return true
