class_name Stage54BManufacturingPersonnelRepairTests
extends RefCounted

const StrongholdDefinitionRegistryScript = preload(
	"res://application/stronghold/stronghold_definition_registry.gd"
)
const StrongholdConstructionServiceScript = preload(
	"res://application/stronghold/stronghold_construction_service.gd"
)
const StrategicReservationServiceScript = preload(
	"res://application/inventory/strategic_reservation_service.gd"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_personnel_capacity_and_workforce_market(failures)
	_test_level_one_workshop_runs_one_project_per_position(failures)
	_test_best_worker_priority_and_time_estimate(failures)
	_test_manufacturing_and_same_id_repair(failures)
	_test_save_round_trip_and_cancellation(failures)
	return failures


static func _test_personnel_capacity_and_workforce_market(failures: Array[String]) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	var personnel: PersonnelCapacityService = context["personnel"] as PersonnelCapacityService
	var workforce: WorkforceService = context["workforce_service"] as WorkforceService
	var before: Dictionary = personnel.snapshot(campaign)
	_expect(int(before.get("maximum", 0)) == 12, "Legacy accommodation was not preserved as base personnel capacity.", failures)
	_expect(int(before.get("troops", 0)) == 1, "The protagonist should be exempt while the persistent troop consumes personnel capacity.", failures)
	_expect(workforce.ensure_market_candidate(campaign), "The first monthly workforce market was not generated.", failures)
	var offers: Array[WorkforceOfferState] = workforce.offers(campaign)
	var manufacturing_offers: Array[WorkforceOfferState] = []
	for offer: WorkforceOfferState in offers:
		var offer_definition: WorkforceDefinition = (context["workforce_catalogue"] as WorkforceCatalogue).definition(offer.worker_definition_id)
		if offer_definition != null and offer_definition.role_id == WorkforceDefinition.ROLE_MANUFACTURING:
			manufacturing_offers.append(offer)
	_expect(manufacturing_offers.size() == 3, "The basic Manufacturing workforce market should begin with three offers.", failures)
	if manufacturing_offers.is_empty():
		return
	var gold_before: int = campaign.resources.amount(&"gold")
	var hired: OperationResult = workforce.hire_candidate(campaign, manufacturing_offers[0].offer_id)
	_expect(hired.success, "A valid Manufacturing worker could not be hired: %s" % hired.message, failures)
	_expect(campaign.workforce_count(&"worker.manufacturing.basic") == 1, "Hiring did not add one basic Manufacturing worker.", failures)
	_expect(campaign.resources.amount(&"gold") < gold_before, "Hiring did not charge Gold.", failures)
	var after_hire: Dictionary = personnel.snapshot(campaign)
	_expect(int(after_hire.get("manufacturing_workers", 0)) == 1, "Personnel snapshot did not include the hired Manufacturing worker.", failures)
	_expect(int(after_hire.get("used", 0)) == 2, "Troop and Manufacturing worker did not share personnel capacity.", failures)

	var quarters = _construct_operational_facility(context, &"facility.living_quarters")
	_expect(quarters != null, "Living Quarters could not be constructed for the capacity test.", failures)
	var after_quarters: Dictionary = personnel.snapshot(campaign)
	_expect(int(after_quarters.get("maximum", 0)) == 20, "Living Quarters I did not add its authored eight personnel capacity.", failures)


static func _test_level_one_workshop_runs_one_project_per_position(failures: Array[String]) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	var workshop = _construct_operational_facility(context, &"facility.workshop")
	_expect(workshop != null, "Workshop could not be constructed for level-one concurrency testing.", failures)
	if workshop == null:
		return
	campaign.add_workforce(&"worker.manufacturing.basic", 3)
	_add_resources(campaign)
	var production: ProductionService = context["production"] as ProductionService
	var starts: Array[OperationResult] = [
		production.start_candidate(campaign, &"production.mace", 1, &""),
		production.start_candidate(campaign, &"production.rope", 1, &""),
		production.start_candidate(campaign, &"production.manacles", 1, &""),
	]
	for result: OperationResult in starts:
		_expect(result.success, "A level-one Workshop project could not be queued: %s" % result.message, failures)
		if not result.success:
			return
		var project: ProductionProjectState = result.data as ProductionProjectState
		production.set_requested_workers_candidate(campaign, project.project_id, 1)
	var allocation: Dictionary = (context["resolver"] as WorkforceAssignmentResolver).resolve(campaign)
	_expect(int(allocation.get("slots", 0)) == 3, "Workshop I should expose one concurrent project slot per worker position.", failures)
	_expect(int(allocation.get("assigned", 0)) == 3, "Workshop I did not assign one worker to each of three queued projects.", failures)
	for result: OperationResult in starts:
		var project: ProductionProjectState = result.data as ProductionProjectState
		var snapshot: Dictionary = production.project_snapshot(campaign, project)
		_expect(int(snapshot.get("workers_assigned", 0)) == 1, "A queued Workshop I project did not receive its requested worker.", failures)


static func _test_best_worker_priority_and_time_estimate(failures: Array[String]) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	var workshop = _construct_operational_facility(context, &"facility.workshop")
	_expect(workshop != null, "Workshop could not be constructed for allocation testing.", failures)
	if workshop == null:
		return
	# Level II supports six concurrent project slots and six worker positions.
	workshop.level = 2
	campaign.add_workforce(&"worker.manufacturing.master", 1)
	campaign.add_workforce(&"worker.manufacturing.skilled", 1)
	campaign.add_workforce(&"worker.manufacturing.basic", 2)
	_add_resources(campaign)
	var production: ProductionService = context["production"] as ProductionService
	var first: OperationResult = production.start_candidate(campaign, &"production.mace", 1, &"")
	var second: OperationResult = production.start_candidate(campaign, &"production.rope", 1, &"")
	_expect(first.success and second.success, "Two valid Production projects could not be queued.", failures)
	if not first.success or not second.success:
		return
	var first_project: ProductionProjectState = first.data as ProductionProjectState
	var second_project: ProductionProjectState = second.data as ProductionProjectState
	production.set_requested_workers_candidate(campaign, first_project.project_id, 2)
	production.set_requested_workers_candidate(campaign, second_project.project_id, 2)
	var first_snapshot: Dictionary = production.project_snapshot(campaign, first_project)
	var second_snapshot: Dictionary = production.project_snapshot(campaign, second_project)
	_expect(int(first_snapshot.get("workers_assigned", 0)) == 2, "Highest-priority project did not receive its requested workers.", failures)
	_expect(int(first_snapshot.get("time_remaining_days", 0)) == 2, "Master plus Skilled workers did not produce the expected two-day Mace estimate.", failures)
	_expect(int(second_snapshot.get("time_remaining_days", 0)) == 1, "The lower-priority Rope estimate was not calculated from the remaining ordinary workers.", failures)
	var moved: OperationResult = production.set_priority_candidate(campaign, second_project.project_id, -1)
	_expect(moved.success, "Project priority could not be changed.", failures)
	first_snapshot = production.project_snapshot(campaign, first_project)
	second_snapshot = production.project_snapshot(campaign, second_project)
	_expect(int(second_snapshot.get("time_remaining_days", 0)) == 1, "The newly prioritised project did not receive the best workers.", failures)
	_expect(int(first_snapshot.get("time_remaining_days", 0)) == 3, "The deprioritised project did not fall back to the remaining workers.", failures)


static func _test_manufacturing_and_same_id_repair(failures: Array[String]) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	var workshop = _construct_operational_facility(context, &"facility.workshop")
	_expect(workshop != null, "Workshop could not be constructed for manufacturing.", failures)
	if workshop == null:
		return
	campaign.add_workforce(&"worker.manufacturing.skilled", 1)
	campaign.add_workforce(&"worker.manufacturing.basic", 1)
	_add_resources(campaign)
	var production: ProductionService = context["production"] as ProductionService
	var metal_before: int = campaign.resources.amount(&"metal")
	var started: OperationResult = production.start_candidate(campaign, &"production.mace", 1, &"")
	_expect(started.success, "Mace manufacturing could not begin: %s" % started.message, failures)
	if not started.success:
		return
	var project: ProductionProjectState = started.data as ProductionProjectState
	production.set_requested_workers_candidate(campaign, project.project_id, 2)
	var completed: Array[Dictionary] = production.advance_candidate(campaign, 2 * 1440)
	_expect(completed.size() == 1, "The Mace project did not complete exactly once at its work boundary.", failures)
	_expect(campaign.resources.amount(&"metal") == metal_before - 4, "Mace completion did not consume the exact Metal cost once.", failures)
	var output_ids: Array = completed[0].get("output_item_ids", []) as Array if not completed.is_empty() else []
	_expect(output_ids.size() == 1, "Mace manufacturing did not create one stable output item.", failures)
	if output_ids.is_empty():
		return
	var item_id := StringName(output_ids[0])
	var item: CampaignItemState = campaign.get_item(item_id) as CampaignItemState
	_expect(item != null and item.definition_id == &"item.mace", "Manufactured output is not the expected Mace.", failures)
	_expect(item != null and item.location != null and item.location.is_stronghold_storage(), "Manufactured Mace did not enter Storage.", failures)
	var repeated: Array[Dictionary] = production.advance_candidate(campaign, 10 * 1440)
	_expect(repeated.is_empty(), "An applied Production project created duplicate output.", failures)

	item.condition = 0.0
	item.revision += 1
	var repair_recipe: ProductionRecipeDefinition = (context["production_catalogue"] as ProductionCatalogue).repair_recipe_for_item(
		item,
		(context["catalogue"] as ContentCatalogue).item_definition(item.definition_id)
	)
	_expect(repair_recipe != null, "Destroyed Mace has no repair recipe.", failures)
	if repair_recipe == null:
		return
	var repair_started: OperationResult = production.start_candidate(campaign, repair_recipe.recipe_id, 1, item_id)
	_expect(repair_started.success, "Destroyed Mace repair could not be queued: %s" % repair_started.message, failures)
	if not repair_started.success:
		return
	var repair_project: ProductionProjectState = repair_started.data as ProductionProjectState
	production.set_requested_workers_candidate(campaign, repair_project.project_id, 2)
	var repair_completed: Array[Dictionary] = production.advance_candidate(campaign, 1440)
	_expect(repair_completed.size() == 1, "The repair did not complete exactly once.", failures)
	var repaired: CampaignItemState = campaign.get_item(item_id) as CampaignItemState
	_expect(repaired == item, "Repair replaced the persistent item object instead of restoring it.", failures)
	_expect(repaired != null and repaired.item_id == item_id, "Repair changed the persistent item ID.", failures)
	_expect(repaired != null and repaired.condition == 1.0, "Repair did not restore the Mace to full serviceability.", failures)


static func _test_save_round_trip_and_cancellation(failures: Array[String]) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	var workshop = _construct_operational_facility(context, &"facility.workshop")
	if workshop == null:
		failures.append("Workshop could not be constructed for save/cancellation testing.")
		return
	campaign.add_workforce(&"worker.manufacturing.basic", 2)
	_add_resources(campaign)
	var production: ProductionService = context["production"] as ProductionService
	var textiles_before: int = campaign.resources.amount(&"textiles")
	var started: OperationResult = production.start_candidate(campaign, &"production.rope", 3, &"")
	_expect(started.success, "Rope batch could not be queued.", failures)
	if not started.success:
		return
	var project: ProductionProjectState = started.data as ProductionProjectState
	production.set_requested_workers_candidate(campaign, project.project_id, 1)
	production.advance_candidate(campaign, 720)
	var work_before_save: int = project.completed_work
	var accumulator_before_save: int = project.work_accumulator_minutes
	var restored := CampaignState.from_dictionary(campaign.to_dictionary())
	var restored_project: ProductionProjectState = restored.get_production_project(project.project_id)
	_expect(restored_project != null, "Save round-trip lost the active Production project.", failures)
	if restored_project != null:
		_expect(restored_project.completed_work == work_before_save, "Save round-trip changed completed Production work.", failures)
		_expect(restored_project.work_accumulator_minutes == accumulator_before_save, "Save round-trip lost partial-day Production progress.", failures)
		_expect(restored.workforce_count(&"worker.manufacturing.basic") == 2, "Save round-trip changed workforce ownership.", failures)
	var cancelled: OperationResult = production.cancel_candidate(campaign, project.project_id)
	_expect(cancelled.success, "Active Production project could not be cancelled.", failures)
	_expect(campaign.resources.amount(&"textiles") == textiles_before, "Cancellation consumed or duplicated reserved Textiles.", failures)
	_expect(campaign.get_strategic_reservation(project.reservation_id) != null, "Cancellation unexpectedly deleted reservation history.", failures)
	_expect(not campaign.get_strategic_reservation(project.reservation_id).is_active(), "Cancellation did not close the input reservation.", failures)


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
	var resolver := WorkforceAssignmentResolver.new()
	resolver.configure(workforce_catalogue, production_catalogue, registry)
	var production := ProductionService.new()
	production.configure(catalogue, production_catalogue, resolver, reservation_service, inventory, registry)
	var construction = StrongholdConstructionServiceScript.new()

	var campaign := CampaignState.new()
	campaign.campaign_id = &"campaign.stage_5_4b.test"
	campaign.campaign_tick = 0
	campaign.resources = CampaignResourceBalances.new()
	campaign.resources.set_amount(&"gold", 1000)
	campaign.roster_capacity = 12
	campaign.stronghold = registry.create_initial_state()
	var protagonist := PersistentCharacterState.new()
	protagonist.character_id = &"character.stage_5_4b.protagonist"
	protagonist.display_name = "Protagonist"
	protagonist.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
	protagonist.roster_role = PersistentCharacterState.ROLE_PLAYER
	campaign.add_character(protagonist)
	campaign.protagonist_character_id = protagonist.character_id
	var troop := PersistentCharacterState.new()
	troop.character_id = &"character.stage_5_4b.troop"
	troop.display_name = "Troop"
	troop.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
	troop.roster_role = PersistentCharacterState.ROLE_PLAYER
	campaign.add_character(troop)
	return {
		"campaign": campaign,
		"catalogue": catalogue,
		"registry": registry,
		"construction": construction,
		"reservation": reservation_service,
		"inventory": inventory,
		"personnel": personnel,
		"workforce_catalogue": workforce_catalogue,
		"workforce_service": workforce_service,
		"production_catalogue": production_catalogue,
		"resolver": resolver,
		"production": production,
	}


static func _construct_operational_facility(context: Dictionary, definition_id: StringName):
	var campaign: CampaignState = context["campaign"] as CampaignState
	var registry = context["registry"]
	var construction = context["construction"]
	var definition = registry.starting_definition()
	for plot in campaign.stronghold.get_plots():
		var preview: OperationResult = construction.preview_build(definition, campaign.stronghold, definition_id, plot.coord)
		if not preview.success:
			continue
		var started: OperationResult = construction.construct_candidate(definition, campaign.stronghold, definition_id, plot.coord, campaign.campaign_tick)
		if not started.success:
			continue
		var facility = (started.data as Dictionary).get("facility")
		var project = (started.data as Dictionary).get("project")
		construction.advance_candidate(definition, campaign.stronghold, project.completion_tick)
		return facility
	return null


static func _add_resources(campaign: CampaignState) -> void:
	campaign.resources.set_amount(&"wood", 100)
	campaign.resources.set_amount(&"metal", 100)
	campaign.resources.set_amount(&"textiles", 100)
	campaign.resources.set_amount(&"gold", 1000)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
