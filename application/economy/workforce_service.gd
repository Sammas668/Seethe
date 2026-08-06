class_name WorkforceService
extends RefCounted

const CAMPAIGN_DAY_TICKS: int = 1440
const CAMPAIGN_MONTH_TICKS: int = CAMPAIGN_DAY_TICKS * 30

var _catalogue: WorkforceCatalogue
var _personnel_capacity_service: PersonnelCapacityService


func configure(catalogue: WorkforceCatalogue, personnel_capacity_service: PersonnelCapacityService) -> void:
	_catalogue = catalogue
	_personnel_capacity_service = personnel_capacity_service


func ensure_market_candidate(campaign: CampaignState) -> bool:
	if campaign == null or _catalogue == null:
		return false
	var current_month: int = market_month_index(campaign.campaign_tick)
	if campaign.workforce_market_month_index < 0 or current_month > campaign.workforce_market_month_index:
		return refresh_market_candidate(campaign, current_month)
	return false


func refresh_market_if_due_candidate(campaign: CampaignState) -> bool:
	return ensure_market_candidate(campaign)


func refresh_market_candidate(campaign: CampaignState, month_index: int = -1) -> bool:
	if campaign == null or _catalogue == null:
		return false
	var resolved_month: int = market_month_index(campaign.campaign_tick) if month_index < 0 else month_index
	campaign.workforce_market_revision += 1
	campaign.workforce_market_month_index = resolved_month
	campaign.workforce_offers_by_id.clear()
	var sequence: int = 1
	for definition_value: WorkforceDefinition in _catalogue.definitions():
		if not definition_value.is_unlocked(campaign):
			continue
		for _index: int in range(definition_value.market_offer_count):
			var offer := WorkforceOfferState.new()
			offer.offer_id = StringName("workforce.offer.%04d.%02d" % [campaign.workforce_market_revision, sequence])
			offer.worker_definition_id = definition_value.worker_definition_id
			offer.market_revision = campaign.workforce_market_revision
			campaign.workforce_offers_by_id[offer.offer_id] = offer
			sequence += 1
	campaign.revision += 1
	return true


func offers(campaign: CampaignState) -> Array[WorkforceOfferState]:
	return campaign.get_workforce_offers() if campaign != null else []


func market_status(campaign: CampaignState) -> Dictionary:
	var month: int = market_month_index(campaign.campaign_tick) if campaign != null else 0
	if campaign != null and campaign.workforce_market_month_index >= 0:
		month = campaign.workforce_market_month_index
	var next_tick: int = (month + 1) * CAMPAIGN_MONTH_TICKS
	return {"month_index": month, "next_refresh_tick": next_tick, "next_refresh_day": next_tick / CAMPAIGN_DAY_TICKS + 1}


func preview_offer(campaign: CampaignState, offer_id: StringName) -> Dictionary:
	var offer: WorkforceOfferState = campaign.get_workforce_offer(offer_id) if campaign != null else null
	var definition_value: WorkforceDefinition = _catalogue.definition(offer.worker_definition_id) if offer != null and _catalogue != null else null
	var reasons: Array[String] = []
	if campaign == null or offer == null or definition_value == null:
		reasons.append("This workforce offer is no longer available.")
	else:
		if not definition_value.is_unlocked(campaign):
			reasons.append("This worker type has not been unlocked.")
		if campaign.resources == null or campaign.resources.amount(&"gold") < definition_value.hire_gold_cost:
			reasons.append("Requires %d Gold." % definition_value.hire_gold_cost)
		if _personnel_capacity_service == null or not _personnel_capacity_service.can_add(campaign, definition_value.personnel_capacity_cost):
			reasons.append("Personnel capacity is full.")
	return {
		"eligible": reasons.is_empty(),
		"reason": reasons[0] if not reasons.is_empty() else "Available",
		"reasons": reasons,
		"offer": offer,
		"definition": definition_value,
	}


func hire_candidate(campaign: CampaignState, offer_id: StringName) -> OperationResult:
	var preview: Dictionary = preview_offer(campaign, offer_id)
	if not bool(preview.get("eligible", false)):
		return OperationResult.fail(&"workforce_hiring_ineligible", String(preview.get("reason", "Hiring is unavailable.")))
	var offer: WorkforceOfferState = preview.get("offer") as WorkforceOfferState
	var definition_value: WorkforceDefinition = preview.get("definition") as WorkforceDefinition
	if offer == null or definition_value == null:
		return OperationResult.fail(&"workforce_offer_changed", "The selected workforce offer changed.")
	if not campaign.resources.add(&"gold", -definition_value.hire_gold_cost):
		return OperationResult.fail(&"workforce_hiring_cost_changed", "The hiring cost could not be paid.")
	campaign.add_workforce(definition_value.worker_definition_id, 1)
	campaign.workforce_offers_by_id.erase(offer.offer_id)
	campaign.revision += 1
	return OperationResult.ok(definition_value.worker_definition_id, "Hired one %s." % definition_value.display_name)


func dismiss_candidate(campaign: CampaignState, worker_definition_id: StringName, quantity: int = 1) -> OperationResult:
	if campaign == null or _catalogue == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var definition_value: WorkforceDefinition = _catalogue.definition(worker_definition_id)
	if definition_value == null:
		return OperationResult.fail(&"workforce_definition_missing", "That worker type no longer exists.")
	var amount: int = maxi(1, quantity)
	if campaign.workforce_count(worker_definition_id) < amount:
		return OperationResult.fail(&"workforce_count_changed", "Not enough workers of that type remain.")
	campaign.add_workforce(worker_definition_id, -amount)
	campaign.revision += 1
	return OperationResult.ok(worker_definition_id, "Dismissed %d %s." % [amount, definition_value.display_name])


static func market_month_index(campaign_tick: int) -> int:
	return maxi(0, campaign_tick) / CAMPAIGN_MONTH_TICKS
