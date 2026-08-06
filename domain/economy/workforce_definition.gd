class_name WorkforceDefinition
extends Resource

const ROLE_MANUFACTURING: StringName = &"manufacturing"
const ROLE_RESEARCH: StringName = &"research"

@export var worker_definition_id: StringName = &""
@export var role_id: StringName = ROLE_MANUFACTURING
@export var display_name: String = "Worker"
@export_multiline var description: String = "Abstract stronghold personnel."
@export var work_rating: int = 1
@export var personnel_capacity_cost: int = 1
@export var hire_gold_cost: int = 0
@export var market_offer_count: int = 0
@export var starting_available: bool = false
@export var required_research_ids: Array[StringName] = []
@export var required_contact_ids: Array[StringName] = []
@export var required_campaign_flags: Array[StringName] = []


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if worker_definition_id.is_empty():
		errors.append("Workforce definition has no ID.")
	if role_id not in [ROLE_MANUFACTURING, ROLE_RESEARCH]:
		errors.append("Worker %s has invalid role %s." % [worker_definition_id, role_id])
	if display_name.strip_edges().is_empty():
		errors.append("Worker %s has no display name." % worker_definition_id)
	if work_rating <= 0:
		errors.append("Worker %s has a non-positive Work Rating." % worker_definition_id)
	if personnel_capacity_cost <= 0:
		errors.append("Worker %s has a non-positive personnel cost." % worker_definition_id)
	if hire_gold_cost < 0:
		errors.append("Worker %s has a negative hiring cost." % worker_definition_id)
	if market_offer_count < 0:
		errors.append("Worker %s has a negative market offer count." % worker_definition_id)
	return errors


func is_unlocked(campaign: CampaignState) -> bool:
	if campaign == null:
		return false
	if starting_available:
		return true
	for research_id: StringName in required_research_ids:
		if not campaign.completed_research_ids.has(research_id):
			return false
	for contact_id: StringName in required_contact_ids:
		if not campaign.has_shop_contact(contact_id):
			return false
	# Campaign flags remain reserved for later authored content. They are not
	# inferred from display text or unrelated state.
	if not required_campaign_flags.is_empty():
		return false
	return not required_research_ids.is_empty() or not required_contact_ids.is_empty()
