class_name Stage54CResearchOrganisationalUnlocksTests
extends RefCounted

const StrongholdDefinitionRegistryScript = preload(
	"res://application/stronghold/stronghold_definition_registry.gd"
)
const StrategicReservationServiceScript = preload(
	"res://application/inventory/strategic_reservation_service.gd"
)
const CaptiveServiceScript = preload("res://application/campaign/captive_service.gd")
const PrisonCapacityServiceScript = preload("res://application/campaign/prison_capacity_service.gd")
const CaptivePolicyRegistryScript = preload("res://application/campaign/captive_policy_registry.gd")


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_research_workers_and_monthly_quality_unlock(failures)
	_test_level_one_heart_runs_one_project_per_position(failures)
	_test_best_research_workers_and_priority(failures)
	_test_captive_source_shop_and_production_unlocks(failures)
	_test_permanent_knowledge_pause_and_save_round_trip(failures)
	return failures


static func _test_research_workers_and_monthly_quality_unlock(failures: Array[String]) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	var workforce: WorkforceService = context["workforce_service"] as WorkforceService
	_expect(workforce.ensure_market_candidate(campaign), "The first workforce market was not generated.", failures)
	var research_offer: WorkforceOfferState = _first_offer_for_role(context, WorkforceDefinition.ROLE_RESEARCH)
	_expect(research_offer != null, "The starting workforce market contains no Research Assistant.", failures)
	if research_offer == null:
		return
	var hired: OperationResult = workforce.hire_candidate(campaign, research_offer.offer_id)
	_expect(hired.success, "The starting Research Assistant could not be hired: %s" % hired.message, failures)
	_expect(campaign.workforce_count(&"worker.research.basic") == 1, "Hiring did not add one Research Assistant.", failures)

	var research: ResearchService = context["research"] as ResearchService
	var started: OperationResult = research.start_candidate(campaign, &"research.organised_study")
	_expect(started.success, "Organised Study could not begin: %s" % started.message, failures)
	if not started.success:
		return
	var project: ResearchProjectState = started.data as ResearchProjectState
	research.set_requested_workers_candidate(campaign, project.project_id, 1)
	var completed: Array[Dictionary] = research.advance_candidate(campaign, 8 * 1440)
	_expect(completed.size() == 1, "Organised Study did not complete exactly once.", failures)
	_expect(campaign.has_completed_research(&"research.organised_study"), "Completed Research was not recorded permanently.", failures)

	var offers_before_refresh: Array[WorkforceOfferState] = workforce.offers(campaign)
	_expect(not _offers_contain(offers_before_refresh, &"worker.research.skilled"), "Research incorrectly replaced the current monthly worker pool immediately.", failures)
	campaign.campaign_tick = 30 * 1440
	_expect(workforce.refresh_market_if_due_candidate(campaign), "The next monthly workforce refresh did not occur.", failures)
	_expect(_offers_contain(workforce.offers(campaign), &"worker.research.skilled"), "Completed Research did not unlock Skilled Researcher candidates at monthly refresh.", failures)


static func _test_level_one_heart_runs_one_project_per_position(failures: Array[String]) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	campaign.add_workforce(&"worker.research.basic", 2)
	var research: ResearchService = context["research"] as ResearchService
	var first: OperationResult = research.start_candidate(campaign, &"research.organised_study")
	var second: OperationResult = research.start_candidate(campaign, &"research.skilled_craftspeople")
	_expect(first.success and second.success, "Two valid Research projects could not be queued at the starting Heart.", failures)
	if not first.success or not second.success:
		return
	var first_project: ResearchProjectState = first.data as ResearchProjectState
	var second_project: ResearchProjectState = second.data as ResearchProjectState
	research.set_requested_workers_candidate(campaign, first_project.project_id, 1)
	research.set_requested_workers_candidate(campaign, second_project.project_id, 1)
	var allocation: Dictionary = (context["research_resolver"] as ResearchAssignmentResolver).resolve(campaign)
	_expect(int(allocation.get("slots", 0)) == 2, "Heart I should expose one concurrent project slot per Research position.", failures)
	_expect(int(allocation.get("assigned", 0)) == 2, "Heart I did not assign one worker to each queued Research project.", failures)
	_expect(int(research.project_snapshot(campaign, first_project).get("workers_assigned", 0)) == 1, "The first queued Research project did not receive its worker.", failures)
	_expect(int(research.project_snapshot(campaign, second_project).get("workers_assigned", 0)) == 1, "The second queued Research project did not receive its worker.", failures)


static func _test_best_research_workers_and_priority(failures: Array[String]) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	var heart = _heart(campaign)
	if heart == null:
		failures.append("The starting Fifth-God Heart is missing.")
		return
	heart.level = 3
	campaign.add_workforce(&"worker.research.skilled", 1)
	campaign.add_workforce(&"worker.research.basic", 1)
	var research: ResearchService = context["research"] as ResearchService
	var first: OperationResult = research.start_candidate(campaign, &"research.organised_study")
	var second: OperationResult = research.start_candidate(campaign, &"research.skilled_craftspeople")
	_expect(first.success and second.success, "Two Research projects could not be queued for priority testing.", failures)
	if not first.success or not second.success:
		return
	var first_project: ResearchProjectState = first.data as ResearchProjectState
	var second_project: ResearchProjectState = second.data as ResearchProjectState
	research.set_requested_workers_candidate(campaign, first_project.project_id, 2)
	research.set_requested_workers_candidate(campaign, second_project.project_id, 2)
	var first_snapshot: Dictionary = research.project_snapshot(campaign, first_project)
	var second_snapshot: Dictionary = research.project_snapshot(campaign, second_project)
	_expect(int(first_snapshot.get("workers_assigned", 0)) == 2, "Highest-priority Research did not receive the best available workers first.", failures)
	_expect(int(first_snapshot.get("time_remaining_days", 0)) == 3, "Skilled plus basic Research workers produced the wrong estimate.", failures)
	_expect(bool(second_snapshot.get("paused", false)), "Lower-priority Research should pause when no workers remain.", failures)
	var moved: OperationResult = research.set_priority_candidate(campaign, second_project.project_id, -1)
	_expect(moved.success, "Research priority could not be changed.", failures)
	first_snapshot = research.project_snapshot(campaign, first_project)
	second_snapshot = research.project_snapshot(campaign, second_project)
	_expect(int(second_snapshot.get("workers_assigned", 0)) == 2, "Newly prioritised Research did not receive the best workers.", failures)
	_expect(bool(first_snapshot.get("paused", false)), "Deprioritised Research did not release its workers.", failures)


static func _test_captive_source_shop_and_production_unlocks(failures: Array[String]) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	campaign.add_workforce(&"worker.research.skilled", 1)
	campaign.add_workforce(&"worker.research.basic", 1)
	var shop = context["shop"]
	var production: ProductionService = context["production"] as ProductionService
	var before_shop: Array[Dictionary] = shop.starting_catalogue_entries(campaign)
	_expect(not _shop_contains(before_shop, &"item.raiders_axe"), "Military contact goods were visible before their Research unlock.", failures)
	var locked_recipe: OperationResult = production.preview_start(campaign, &"production.raiders_axe", 1, &"")
	_expect(not locked_recipe.success, "Research-gated Production recipe was available before Research.", failures)

	var captive := CampaignCaptiveState.new()
	captive.captive_id = &"captive.stage_5_4c.officer"
	captive.source_character_id = &"enemy.officer"
	captive.source_definition_id = &"character_template.life.patrol_leader"
	captive.display_name = "Captured Patrol Leader"
	captive.captured_mission_id = &"mission.stage_5_4c"
	captive.holding_location_id = &"stronghold.prison"
	captive.assigned_prison_id = &"facility.test.prison"
	captive.status = CampaignCaptiveState.STATUS_HELD
	captive.current_hp = 10
	captive.maximum_hp = 10
	campaign.captives_by_id[captive.captive_id] = captive
	var captive_service: CaptiveService = context["captive_service"] as CaptiveService
	var source_preview: OperationResult = captive_service.preview_interrogate_for_campaign(campaign, captive)
	_expect(source_preview.success, "The authored patrol-leader Research source was not recognised.", failures)
	if source_preview.success:
		campaign.add_research_source(StringName((source_preview.data as Dictionary).get("research_source_id", "")))
		captive.interrogation_completed = true
	_expect(campaign.has_research_source(&"source.research.life_officer"), "Captive interrogation did not reveal the authored officer source.", failures)

	var research: ResearchService = context["research"] as ResearchService
	var contact_project: OperationResult = research.start_candidate(campaign, &"research.military_supply_contacts")
	_expect(contact_project.success, "Military Supply Contacts could not begin after its captive source was revealed: %s" % contact_project.message, failures)
	if contact_project.success:
		var project: ResearchProjectState = contact_project.data as ResearchProjectState
		research.set_requested_workers_candidate(campaign, project.project_id, 2)
		research.advance_candidate(campaign, 4 * 1440)
	_expect(campaign.has_shop_contact(&"contact.military_fence"), "Completed contact Research did not unlock the military fence.", failures)
	_expect(_shop_contains(shop.starting_catalogue_entries(campaign), &"item.raiders_axe"), "Unlocked military-fence goods did not appear in the Shop.", failures)

	var weapon_project: OperationResult = research.start_candidate(campaign, &"research.common_weapon_patterns")
	_expect(weapon_project.success, "Common Weapon Patterns could not begin.", failures)
	if weapon_project.success:
		var project: ResearchProjectState = weapon_project.data as ResearchProjectState
		research.set_requested_workers_candidate(campaign, project.project_id, 2)
		research.advance_candidate(campaign, 4 * 1440)
	_expect(campaign.has_completed_research(&"research.common_weapon_patterns"), "Weapon-pattern Research did not complete.", failures)
	_expect(production.preview_start(campaign, &"production.raiders_axe", 1, &"").success, "Completed Research did not unlock the Raider's Axe Production recipe.", failures)


static func _test_permanent_knowledge_pause_and_save_round_trip(failures: Array[String]) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	campaign.add_workforce(&"worker.research.basic", 1)
	var research: ResearchService = context["research"] as ResearchService
	var completed_start: OperationResult = research.start_candidate(campaign, &"research.organised_study")
	if not completed_start.success:
		failures.append("Organised Study could not begin for permanence testing.")
		return
	var completed_project: ResearchProjectState = completed_start.data as ResearchProjectState
	research.set_requested_workers_candidate(campaign, completed_project.project_id, 1)
	research.advance_candidate(campaign, 8 * 1440)
	_expect(campaign.has_completed_research(&"research.organised_study"), "Baseline Research was not learned.", failures)

	var active_start: OperationResult = research.start_candidate(campaign, &"research.skilled_craftspeople")
	_expect(active_start.success, "Second Research could not begin for facility-pause testing.", failures)
	if not active_start.success:
		return
	var active_project: ResearchProjectState = active_start.data as ResearchProjectState
	research.set_requested_workers_candidate(campaign, active_project.project_id, 1)
	var heart = _heart(campaign)
	heart.condition = StrongholdFacilityState.CONDITION_DISABLED
	var paused: Dictionary = research.project_snapshot(campaign, active_project)
	_expect(bool(paused.get("paused", false)), "Research did not pause when the required Heart became disabled.", failures)
	_expect(campaign.has_completed_research(&"research.organised_study"), "Disabling infrastructure erased completed Research.", failures)

	var restored := CampaignState.from_dictionary(campaign.to_dictionary())
	_expect(restored.has_completed_research(&"research.organised_study"), "Save round-trip lost completed Research.", failures)
	_expect(restored.get_research_project(active_project.project_id) != null, "Save round-trip lost active Research.", failures)
	_expect(restored.has_capability(&"capability.research.organised"), "Save round-trip lost a learned organisational capability.", failures)
	_expect(restored.workforce_count(&"worker.research.basic") == 1, "Save round-trip changed Research workforce ownership.", failures)


static func _build_context() -> Dictionary:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var registry = StrongholdDefinitionRegistryScript.new()
	registry.configure()
	var reservation_service = StrategicReservationServiceScript.new()
	var inventory := InventoryService.new()
	inventory.configure(reservation_service, catalogue, registry)
	var personnel := PersonnelCapacityService.new()
	personnel.configure(registry)
	var workforce_catalogue := WorkforceCatalogue.new()
	var workforce_service := WorkforceService.new()
	workforce_service.configure(workforce_catalogue, personnel)
	var production_catalogue := ProductionCatalogue.new()
	production_catalogue.configure(catalogue)
	var production_resolver := WorkforceAssignmentResolver.new()
	production_resolver.configure(workforce_catalogue, production_catalogue, registry)
	var production := ProductionService.new()
	production.configure(catalogue, production_catalogue, production_resolver, reservation_service, inventory, registry)
	var research_catalogue := ResearchCatalogue.new()
	var research_resolver := ResearchAssignmentResolver.new()
	research_resolver.configure(workforce_catalogue, research_catalogue, registry)
	var research := ResearchService.new()
	research.configure(research_catalogue, research_resolver, reservation_service)
	var shop := ShopService.new()
	shop.configure(catalogue, inventory, reservation_service)

	var campaign := CampaignState.new()
	campaign.campaign_id = &"campaign.stage_5_4c.test"
	campaign.campaign_tick = 0
	campaign.resources = CampaignResourceBalances.new()
	campaign.resources.set_amount(&"gold", 2000)
	campaign.resources.set_amount(&"wood", 500)
	campaign.resources.set_amount(&"metal", 500)
	campaign.resources.set_amount(&"food", 500)
	campaign.resources.set_amount(&"textiles", 500)
	campaign.resources.set_amount(&"magic", 100)
	campaign.roster_capacity = 30
	campaign.stronghold = registry.create_initial_state()
	var protagonist := PersistentCharacterState.new()
	protagonist.character_id = &"character.stage_5_4c.protagonist"
	protagonist.display_name = "Protagonist"
	protagonist.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
	protagonist.roster_role = PersistentCharacterState.ROLE_PLAYER
	campaign.add_character(protagonist)
	campaign.protagonist_character_id = protagonist.character_id

	var prison_capacity := PrisonCapacityServiceScript.new()
	prison_capacity.configure(registry)
	var captive_policy := CaptivePolicyRegistryScript.new()
	var store := CampaignStateStore.new()
	store.configure(campaign, null, catalogue)
	var captive_service = CaptiveServiceScript.new()
	captive_service.configure(store, prison_capacity, captive_policy, null, catalogue)
	return {
		"campaign": campaign,
		"catalogue": catalogue,
		"registry": registry,
		"reservation": reservation_service,
		"inventory": inventory,
		"personnel": personnel,
		"workforce_catalogue": workforce_catalogue,
		"workforce_service": workforce_service,
		"production_catalogue": production_catalogue,
		"production": production,
		"research_catalogue": research_catalogue,
		"research_resolver": research_resolver,
		"research": research,
		"shop": shop,
		"captive_service": captive_service,
	}


static func _heart(campaign: CampaignState):
	if campaign == null or campaign.stronghold == null:
		return null
	for facility: StrongholdFacilityState in campaign.stronghold.get_facilities():
		if facility != null and facility.definition_id == &"facility.fifth_god_heart":
			return facility
	return null


static func _first_offer_for_role(context: Dictionary, role_id: StringName) -> WorkforceOfferState:
	var workforce: WorkforceService = context["workforce_service"] as WorkforceService
	var campaign: CampaignState = context["campaign"] as CampaignState
	var catalogue: WorkforceCatalogue = context["workforce_catalogue"] as WorkforceCatalogue
	for offer: WorkforceOfferState in workforce.offers(campaign):
		var definition_value: WorkforceDefinition = catalogue.definition(offer.worker_definition_id)
		if definition_value != null and definition_value.role_id == role_id:
			return offer
	return null


static func _offers_contain(offers: Array[WorkforceOfferState], worker_definition_id: StringName) -> bool:
	for offer: WorkforceOfferState in offers:
		if offer.worker_definition_id == worker_definition_id:
			return true
	return false


static func _shop_contains(entries: Array[Dictionary], definition_id: StringName) -> bool:
	for entry: Dictionary in entries:
		if StringName(entry.get("definition_id", "")) == definition_id:
			return true
	return false


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
