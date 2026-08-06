class_name CampaignSession
extends RefCounted

const StrongholdDefinitionRegistryScript = preload("res://application/stronghold/stronghold_definition_registry.gd")
const StrongholdConnectivityServiceScript = preload("res://application/stronghold/stronghold_connectivity_service.gd")
const StrongholdConstructionServiceScript = preload("res://application/stronghold/stronghold_construction_service.gd")
const StrongholdFacilityDefinitionScript = preload("res://domain/stronghold/stronghold_facility_definition.gd")
const StrongholdDefinitionScript = preload("res://domain/stronghold/stronghold_definition.gd")
const StrongholdStateScript = preload("res://domain/stronghold/stronghold_state.gd")
const StrongholdProjectStateScript = preload("res://domain/stronghold/stronghold_project_state.gd")
const InventoryServiceScript = preload("res://application/inventory/inventory_service.gd")
const DismantlingServiceScript = preload("res://application/inventory/dismantling_service.gd")
const ShopServiceScript = preload("res://application/inventory/shop_service.gd")
const StrategicStorageQueryServiceScript = preload(
	"res://application/inventory/strategic_storage_query_service.gd"
)
const StrategicReservationServiceScript = preload(
	"res://application/inventory/strategic_reservation_service.gd"
)
const StrategicEquipmentServiceScript = preload("res://application/inventory/strategic_equipment_service.gd")
const LoadoutServiceScript = preload("res://application/inventory/loadout_service.gd")
const CharacterProgressionServiceScript = preload("res://application/characters/character_progression_service.gd")
const StrategicRecoveryServiceScript = preload("res://application/characters/strategic_recovery_service.gd")
const SquadTransportServiceScript = preload("res://application/strategic/squad_transport_service.gd")
const SquadManagementServiceScript = preload("res://application/strategic/squad_management_service.gd")
const StableBayServiceScript = preload("res://application/strategic/stable_bay_service.gd")
const MissionRecoverySelectionServiceScript = preload("res://application/missions/mission_recovery_selection_service.gd")
const PrisonCapacityServiceScript = preload("res://application/campaign/prison_capacity_service.gd")
const CaptivePolicyRegistryScript = preload("res://application/campaign/captive_policy_registry.gd")
const CaptiveServiceScript = preload("res://application/campaign/captive_service.gd")
const PersonnelCapacityServiceScript = preload("res://application/economy/personnel_capacity_service.gd")
const WorkforceCatalogueScript = preload("res://application/economy/workforce_catalogue.gd")
const WorkforceServiceScript = preload("res://application/economy/workforce_service.gd")
const ProductionCatalogueScript = preload("res://application/economy/production_catalogue.gd")
const WorkforceAssignmentResolverScript = preload("res://application/economy/workforce_assignment_resolver.gd")
const ProductionServiceScript = preload("res://application/economy/production_service.gd")
const ResearchCatalogueScript = preload("res://application/economy/research_catalogue.gd")
const ResearchAssignmentResolverScript = preload("res://application/economy/research_assignment_resolver.gd")
const ResearchServiceScript = preload("res://application/economy/research_service.gd")


signal campaign_changed(reason: StringName)
signal campaign_loaded
signal campaign_unloaded
signal agent_mission_discovered(mission_instance_id: StringName)
signal mission_expired(mission_instance_id: StringName)
signal squad_arrived(mission_instance_id: StringName)
signal squad_returned(operation_id: StringName, replenishment_message: String)
signal travel_notoriety_applied(report_id: StringName)
signal raid_operation_created(operation_id: StringName)
signal stronghold_project_completed(facility_instance_id: StringName, project_kind: StringName)
signal recruitment_project_completed(character_id: StringName)
signal prestige_project_completed(character_id: StringName, stage_id: StringName)
signal production_project_completed(project_id: StringName, recipe_id: StringName)
signal research_project_completed(project_id: StringName, research_id: StringName)

const CLOCK_AUTOSAVE_REAL_SECONDS: float = 12.0

var catalogue: ContentCatalogue
var repository: JsonCampaignRepository
var state_store: CampaignStateStore
var mission_coordinator: CampaignMissionCoordinator
var strategic_clock: StrategicClockService
var new_campaign_service: NewCampaignService
var region_registry: RegionDefinitionRegistry
var stronghold_registry: StrongholdDefinitionRegistryScript
var stronghold_connectivity_service: StrongholdConnectivityServiceScript
var stronghold_construction_service: StrongholdConstructionServiceScript
var inventory_service: InventoryServiceScript
var dismantling_service: DismantlingServiceScript
var shop_service: ShopServiceScript
var strategic_storage_query_service: StrategicStorageQueryServiceScript
var strategic_reservation_service: StrategicReservationServiceScript
var strategic_equipment_service: StrategicEquipmentServiceScript
var loadout_service: LoadoutServiceScript
var character_progression_service: CharacterProgressionServiceScript
var strategic_recovery_service: StrategicRecoveryServiceScript
var troop_career_service: TroopCareerService
var henchman_recruitment_service: HenchmanRecruitmentService
var troop_prestige_service: TroopPrestigeService
var squad_transport_service: SquadTransportServiceScript
var squad_management_service: SquadManagementServiceScript
var stable_bay_service: StableBayServiceScript
var mission_recovery_selection_service: MissionRecoverySelectionServiceScript
var prison_capacity_service: PrisonCapacityServiceScript
var captive_policy_registry: CaptivePolicyRegistryScript
var captive_service: CaptiveServiceScript
var personnel_capacity_service: PersonnelCapacityServiceScript
var workforce_catalogue: WorkforceCatalogueScript
var workforce_service: WorkforceServiceScript
var production_catalogue: ProductionCatalogueScript
var workforce_assignment_resolver: WorkforceAssignmentResolverScript
var production_service: ProductionServiceScript
var research_catalogue: ResearchCatalogueScript
var research_assignment_resolver: ResearchAssignmentResolverScript
var research_service: ResearchServiceScript
var agent_service: AgentService
var mission_lifecycle_service: MissionLifecycleService
var squad_visibility_service: SquadVisibilityService
var squad_route_planning_service: SquadRoutePlanningService
var travel_notoriety_service: TravelNotorietyService
var subregion_notoriety_service: SubregionNotorietyService
var regional_retaliation_service: RegionalRetaliationService
var squad_travel_service: SquadTravelService
var _clock_state_dirty: bool = false
var _clock_autosave_elapsed: float = 0.0
var _last_persisted_campaign_tick: int = 0


func configure(save_path: String = CampaignRepository.DEFAULT_SAVE_PATH) -> void:
	catalogue = SandboxContentCatalogueFactory.create_catalogue()
	repository = JsonCampaignRepository.new(save_path, true, catalogue)
	state_store = CampaignStateStore.new()
	strategic_clock = StrategicClockService.new()
	region_registry = RegionDefinitionRegistry.new()
	var region_errors: Array[String] = region_registry.configure()
	if not region_errors.is_empty():
		push_error("Region registry invalid: %s" % region_errors[0])
	stronghold_registry = StrongholdDefinitionRegistryScript.new()
	var stronghold_errors: Array[String] = stronghold_registry.configure()
	if not stronghold_errors.is_empty():
		push_error("Stronghold registry invalid: %s" % stronghold_errors[0])
	stronghold_connectivity_service = StrongholdConnectivityServiceScript.new()
	stronghold_construction_service = StrongholdConstructionServiceScript.new()
	personnel_capacity_service = PersonnelCapacityServiceScript.new()
	personnel_capacity_service.configure(stronghold_registry)
	workforce_catalogue = WorkforceCatalogueScript.new()
	workforce_service = WorkforceServiceScript.new()
	workforce_service.configure(workforce_catalogue, personnel_capacity_service)
	strategic_reservation_service = StrategicReservationServiceScript.new()
	inventory_service = InventoryServiceScript.new()
	inventory_service.configure(
		strategic_reservation_service,
		catalogue,
		stronghold_registry
	)
	dismantling_service = DismantlingServiceScript.new()
	dismantling_service.configure(
		catalogue,
		inventory_service,
		strategic_reservation_service
	)
	shop_service = ShopServiceScript.new()
	shop_service.configure(
		catalogue,
		inventory_service,
		strategic_reservation_service
	)
	strategic_storage_query_service = StrategicStorageQueryServiceScript.new()
	strategic_storage_query_service.configure(catalogue, strategic_reservation_service)
	production_catalogue = ProductionCatalogueScript.new()
	production_catalogue.configure(catalogue)
	workforce_assignment_resolver = WorkforceAssignmentResolverScript.new()
	workforce_assignment_resolver.configure(workforce_catalogue, production_catalogue, stronghold_registry)
	production_service = ProductionServiceScript.new()
	production_service.configure(catalogue, production_catalogue, workforce_assignment_resolver, strategic_reservation_service, inventory_service, stronghold_registry)
	research_catalogue = ResearchCatalogueScript.new()
	research_assignment_resolver = ResearchAssignmentResolverScript.new()
	research_assignment_resolver.configure(workforce_catalogue, research_catalogue, stronghold_registry)
	research_service = ResearchServiceScript.new()
	research_service.configure(research_catalogue, research_assignment_resolver, strategic_reservation_service)
	strategic_equipment_service = StrategicEquipmentServiceScript.new()
	strategic_equipment_service.configure(
		catalogue,
		inventory_service,
		strategic_reservation_service
	)
	loadout_service = LoadoutServiceScript.new()
	loadout_service.configure(
		catalogue,
		strategic_equipment_service,
		strategic_reservation_service,
		inventory_service
	)
	character_progression_service = CharacterProgressionServiceScript.new()
	character_progression_service.configure(catalogue)
	troop_career_service = TroopCareerService.new()
	troop_career_service.configure(catalogue)
	henchman_recruitment_service = HenchmanRecruitmentService.new()
	henchman_recruitment_service.configure(catalogue, personnel_capacity_service)
	troop_prestige_service = TroopPrestigeService.new()
	troop_prestige_service.configure(catalogue, troop_career_service)
	strategic_recovery_service = StrategicRecoveryServiceScript.new()
	strategic_recovery_service.configure(catalogue, stronghold_registry)
	squad_transport_service = SquadTransportServiceScript.new()
	squad_transport_service.configure(stronghold_registry)
	squad_management_service = SquadManagementServiceScript.new()
	stable_bay_service = StableBayServiceScript.new()
	stable_bay_service.configure(squad_transport_service, stronghold_registry)
	prison_capacity_service = PrisonCapacityServiceScript.new()
	prison_capacity_service.configure(stronghold_registry)
	captive_policy_registry = CaptivePolicyRegistryScript.new()
	mission_recovery_selection_service = MissionRecoverySelectionServiceScript.new()
	mission_recovery_selection_service.configure(catalogue, prison_capacity_service)
	captive_service = CaptiveServiceScript.new()
	captive_service.configure(
		state_store, prison_capacity_service, captive_policy_registry, region_registry, catalogue
	)
	new_campaign_service = NewCampaignService.new()
	new_campaign_service.configure(catalogue, region_registry, stronghold_registry)
	agent_service = AgentService.new()
	agent_service.configure(state_store, region_registry)
	mission_lifecycle_service = MissionLifecycleService.new()
	squad_visibility_service = SquadVisibilityService.new()
	squad_route_planning_service = SquadRoutePlanningService.new()
	travel_notoriety_service = TravelNotorietyService.new()
	subregion_notoriety_service = SubregionNotorietyService.new()
	regional_retaliation_service = RegionalRetaliationService.new()
	squad_travel_service = SquadTravelService.new()
	squad_travel_service.configure(
		region_registry, squad_transport_service, stable_bay_service, loadout_service, prison_capacity_service
	)
	mission_coordinator = CampaignMissionCoordinator.new()


func has_saved_campaign() -> bool:
	return repository != null and repository.has_campaign()


func has_safe_checkpoint() -> bool:
	return repository != null and repository.has_safe_checkpoint()


func current_campaign() -> CampaignState:
	return state_store.current_campaign() if state_store != null else null


func current_region_definition() -> RegionMapDefinition:
	var campaign: CampaignState = current_campaign()
	if campaign == null or region_registry == null:
		return null
	return region_registry.definition(campaign.current_region_id)


func current_region_site(site_id: StringName) -> RegionSiteDefinition:
	var region: RegionMapDefinition = current_region_definition()
	return region.site(site_id) if region != null else null


func create_new_campaign(seed_value: int = -1) -> OperationResult:
	if repository == null:
		return OperationResult.fail(&"campaign_session_unconfigured", "Campaign session is not configured.")
	var campaign: CampaignState = new_campaign_service.create_campaign(seed_value)
	if campaign != null and loadout_service != null:
		loadout_service.ensure_authored_templates(campaign)
	if campaign != null and strategic_recovery_service != null:
		strategic_recovery_service.ensure_campaign_health(campaign)
	if campaign != null and squad_management_service != null:
		squad_management_service.ensure_campaign_squads(campaign)
	if campaign != null and stable_bay_service != null:
		stable_bay_service.ensure_campaign_bays(campaign)
	if campaign != null and prison_capacity_service != null:
		prison_capacity_service.ensure_campaign_captives(campaign, captive_policy_registry)
	if campaign != null:
		TroopCareerMigration.migrate(campaign, catalogue)
		if henchman_recruitment_service != null:
			henchman_recruitment_service.ensure_market_candidate(campaign)
		if workforce_service != null:
			workforce_service.ensure_market_candidate(campaign)
	if campaign == null:
		return OperationResult.fail(&"new_campaign_failed", "The new campaign could not be created.")
	# A failed prior load deliberately blocks writes. New Campaign is the explicit
	# recovery path, but the replacement campaign is fully assembled first.
	if repository.load_failed and not repository.clear_save():
		return OperationResult.fail(&"campaign_clear_failed", "The damaged campaign save could not be replaced.")
	if not repository.save_campaign(campaign):
		return OperationResult.fail(&"new_campaign_save_failed", "The new campaign could not be saved.")
	repository.clear_safe_checkpoint()
	_bind_campaign(campaign)
	campaign_loaded.emit()
	return OperationResult.ok(campaign, "New campaign created and saved.")


func load_campaign() -> OperationResult:
	if repository == null or not repository.has_campaign():
		return OperationResult.fail(&"campaign_save_missing", "No campaign save exists.")
	var campaign: CampaignState = repository.load_campaign()
	if campaign == null:
		return OperationResult.fail(
			&"campaign_load_failed",
			repository.last_load_error if not repository.last_load_error.is_empty() else "Campaign load failed."
		)
	var migrated: bool = false
	if TroopCareerMigration.migrate(campaign, catalogue):
		migrated = true
	if henchman_recruitment_service != null:
		if not henchman_recruitment_service.advance_candidate(campaign).is_empty():
			migrated = true
		if henchman_recruitment_service.ensure_market_candidate(campaign):
			migrated = true
	if workforce_service != null and workforce_service.ensure_market_candidate(campaign):
		migrated = true
	if agent_service != null and agent_service.ensure_starting_agent(campaign):
		migrated = true
	if _ensure_stage_51d_state(campaign):
		migrated = true
	if _ensure_stage_52a_state(campaign):
		migrated = true
	if (
		strategic_reservation_service != null
		and strategic_reservation_service.ensure_deployment_reservations(campaign)
	):
		migrated = true
	if loadout_service != null and loadout_service.ensure_authored_templates(campaign):
		migrated = true
	if strategic_recovery_service != null and strategic_recovery_service.ensure_campaign_health(campaign):
		migrated = true
	if squad_transport_service != null and squad_transport_service.ensure_campaign_transport_state(campaign):
		migrated = true
	var squads_created: bool = false
	var bays_created: bool = false
	if squad_management_service != null:
		squads_created = squad_management_service.ensure_campaign_squads(campaign)
		if squads_created:
			migrated = true
	if stable_bay_service != null:
		bays_created = stable_bay_service.ensure_campaign_bays(campaign)
		if bays_created:
			migrated = true
	if (
		stable_bay_service != null
		and (squads_created or bays_created)
		and stable_bay_service.ensure_starting_assignment(campaign)
	):
		migrated = true
	if (
		prison_capacity_service != null
		and prison_capacity_service.ensure_campaign_captives(campaign, captive_policy_registry)
	):
		migrated = true
	var stronghold_validation: Array[String] = _validate_stronghold_state(campaign)
	if not stronghold_validation.is_empty():
		return OperationResult.fail(
			&"stronghold_state_invalid",
			"The campaign stronghold is invalid: %s" % stronghold_validation[0]
		)
	if migrated:
		campaign.revision = maxi(0, campaign.revision)
		if not repository.save_campaign(campaign):
			return OperationResult.fail(
				&"campaign_migration_save_failed",
				"The Stage 5.2a campaign migration could not be saved."
			)
	_bind_campaign(campaign)
	campaign_loaded.emit()
	return OperationResult.ok(campaign, "Campaign loaded.")


func save_current() -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var result: OperationResult = state_store.persist_current(&"manual_save")
	if result.success:
		_mark_clock_state_persisted()
		return OperationResult.ok(campaign, "Campaign saved.")
	return result


func preview_strategic_equip(
		item_id: StringName,
		character_id: StringName,
		container_id: StringName
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if strategic_equipment_service == null:
		return OperationResult.fail(&"equipment_service_missing", "Strategic equipment service is unavailable.")
	return strategic_equipment_service.preview_equip(
		campaign,
		item_id,
		character_id,
		container_id
	)


func equip_strategic_item(
		item_id: StringName,
		character_id: StringName,
		container_id: StringName
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or strategic_equipment_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var preview: OperationResult = strategic_equipment_service.preview_equip(
		campaign,
		item_id,
		character_id,
		container_id
	)
	if not preview.success:
		return preview
	var changes := CampaignChangeSet.new()
	changes.configure(&"strategic_equipment_changed", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return strategic_equipment_service.equip_candidate(
				candidate,
				item_id,
				character_id,
				container_id
			)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(current_campaign().get_item(item_id), preview.message)


func preview_strategic_place(
		item_id: StringName,
		character_id: StringName,
		container_id: StringName,
		grid_position: Vector2i,
		is_rotated: bool = false
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if strategic_equipment_service == null:
		return OperationResult.fail(&"equipment_service_missing", "Strategic equipment service is unavailable.")
	return strategic_equipment_service.preview_equip_at_position(
		campaign,
		item_id,
		character_id,
		container_id,
		grid_position,
		is_rotated
	)


func place_strategic_item(
		item_id: StringName,
		character_id: StringName,
		container_id: StringName,
		grid_position: Vector2i,
		is_rotated: bool = false
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or strategic_equipment_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var preview: OperationResult = strategic_equipment_service.preview_equip_at_position(
		campaign,
		item_id,
		character_id,
		container_id,
		grid_position,
		is_rotated
	)
	if not preview.success:
		return preview
	var changes := CampaignChangeSet.new()
	changes.configure(&"strategic_spatial_inventory_changed", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return strategic_equipment_service.equip_candidate_at_position(
				candidate,
				item_id,
				character_id,
				container_id,
				grid_position,
				is_rotated
			)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(current_campaign().get_item(item_id), preview.message)


func auto_pack_strategic_container(
		character_id: StringName,
		container_id: StringName
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or strategic_equipment_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var preview: OperationResult = strategic_equipment_service.preview_auto_pack(
		campaign,
		character_id,
		container_id
	)
	if not preview.success:
		return preview
	if preview.commit_status == OperationResult.STATUS_NO_CHANGE:
		return preview
	var changes := CampaignChangeSet.new()
	changes.configure(&"strategic_inventory_auto_packed", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return strategic_equipment_service.auto_pack_candidate(
				candidate,
				character_id,
				container_id
			)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(preview.data, preview.message)


func return_strategic_container_to_storage(
		character_id: StringName,
		container_id: StringName
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or strategic_equipment_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var preview: OperationResult = strategic_equipment_service.preview_return_container_to_storage(
		campaign,
		character_id,
		container_id
	)
	if not preview.success or preview.commit_status == OperationResult.STATUS_NO_CHANGE:
		return preview
	var changes := CampaignChangeSet.new()
	changes.configure(&"strategic_inventory_returned", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return strategic_equipment_service.return_container_to_storage_candidate(
				candidate,
				character_id,
				container_id
			)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(preview.data, preview.message)


func strategic_loadout_status(character_id: StringName) -> Dictionary:
	if strategic_equipment_service == null:
		return {"ready": false, "blocking": ["Equipment service unavailable."], "warnings": []}
	return strategic_equipment_service.loadout_status(current_campaign(), character_id)


func preview_strategic_unequip(item_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if strategic_equipment_service == null:
		return OperationResult.fail(&"equipment_service_missing", "Strategic equipment service is unavailable.")
	return strategic_equipment_service.preview_return_to_storage(campaign, item_id)


func unequip_strategic_item(item_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or strategic_equipment_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var preview: OperationResult = strategic_equipment_service.preview_return_to_storage(
		campaign,
		item_id
	)
	if not preview.success:
		return preview
	if preview.commit_status == OperationResult.STATUS_NO_CHANGE:
		return preview
	var changes := CampaignChangeSet.new()
	changes.configure(&"strategic_equipment_changed", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return strategic_equipment_service.return_to_storage_candidate(candidate, item_id)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(current_campaign().get_item(item_id), preview.message)


func set_item_protected(item_id: StringName, protected_value: bool) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var existing: CampaignItemState = campaign.get_item(item_id) as CampaignItemState
	if existing == null:
		return OperationResult.fail(&"item_missing", "The selected item no longer exists.")
	if strategic_reservation_service != null:
		var availability: OperationResult = strategic_reservation_service.validate_item_available(
			campaign,
			item_id
		)
		if not availability.success:
			return availability
	if existing.is_protected == protected_value:
		return OperationResult.no_change(existing, "Item protection is already set.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"item_protection_changed", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			if inventory_service == null:
				return OperationResult.fail(&"inventory_service_missing", "Inventory service is unavailable.")
			return inventory_service.set_item_protected_candidate(
				candidate,
				item_id,
				protected_value
			)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(
		current_campaign().get_item(item_id),
		"Item protected from automatic use." if protected_value else "Item protection removed."
	)


func loadout_templates_for_character(
		character_id: StringName
) -> Array[LoadoutTemplateState]:
	if loadout_service == null:
		var empty: Array[LoadoutTemplateState] = []
		return empty
	return loadout_service.compatible_templates(current_campaign(), character_id)


func preview_apply_loadout_template(
		character_id: StringName,
		template_id: StringName
) -> OperationResult:
	if loadout_service == null:
		return OperationResult.fail(&"loadout_service_missing", "Loadout service is unavailable.")
	return loadout_service.preview_apply_template(current_campaign(), character_id, template_id)


func apply_loadout_template(
		character_id: StringName,
		template_id: StringName
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or loadout_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var preview: OperationResult = loadout_service.preview_apply_template(
		campaign,
		character_id,
		template_id
	)
	if not preview.success:
		return preview
	var changes := CampaignChangeSet.new()
	changes.configure(&"loadout_template_applied", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return loadout_service.apply_template_candidate(
				candidate,
				character_id,
				template_id
			)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(preview.data, "Loadout template applied.")


func save_current_loadout_as_template(
		character_id: StringName,
		display_name: String
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or loadout_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var candidate_template: LoadoutTemplateState = loadout_service.capture_current_loadout(
		campaign,
		character_id,
		display_name
	)
	if candidate_template == null:
		return OperationResult.fail(&"loadout_capture_failed", "The current loadout could not be captured.")
	var template_data: Dictionary = candidate_template.to_dictionary()
	var changes := CampaignChangeSet.new()
	changes.configure(&"loadout_template_created", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			var created := LoadoutTemplateState.from_dictionary(template_data)
			if candidate.get_loadout_template(created.template_id) != null:
				return OperationResult.fail(&"loadout_template_exists", "That loadout template already exists.")
			if not candidate.upsert_loadout_template(created):
				return OperationResult.fail(&"loadout_template_create_failed", "The loadout template could not be saved.")
			var character: PersistentCharacterState = candidate.get_character(character_id)
			if character != null:
				character.preferred_loadout_template_id = created.template_id
				character.revision += 1
			return OperationResult.ok(created)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(current_campaign().get_loadout_template(candidate_template.template_id), "Loadout template saved.")


func update_loadout_template_from_character(
		character_id: StringName,
		template_id: StringName
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or loadout_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var existing: LoadoutTemplateState = campaign.get_loadout_template(template_id)
	if existing == null:
		return OperationResult.fail(&"loadout_template_missing", "The selected template no longer exists.")
	if existing.is_authored:
		return OperationResult.fail(&"authored_template_locked", "Authored templates cannot be overwritten; save a copy instead.")
	var captured: LoadoutTemplateState = loadout_service.capture_current_loadout(
		campaign,
		character_id,
		existing.display_name,
		template_id,
		false
	)
	captured.description = existing.description
	captured.substitution_policy = existing.substitution_policy
	var data: Dictionary = captured.to_dictionary()
	var changes := CampaignChangeSet.new()
	changes.configure(&"loadout_template_updated", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			var updated := LoadoutTemplateState.from_dictionary(data)
			if not candidate.upsert_loadout_template(updated):
				return OperationResult.fail(&"loadout_template_update_failed", "The template could not be updated.")
			return OperationResult.ok(updated)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(current_campaign().get_loadout_template(template_id), "Loadout template updated.")


func create_blank_loadout_template(
		character_id: StringName,
		display_name: String
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or loadout_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var candidate_template: LoadoutTemplateState = loadout_service.create_blank_template(
		campaign, character_id, display_name
	)
	if candidate_template == null:
		return OperationResult.fail(&"loadout_template_create_failed", "The blank template could not be created.")
	var data: Dictionary = candidate_template.to_dictionary()
	var changes := CampaignChangeSet.new()
	changes.configure(&"loadout_template_created", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		var created := LoadoutTemplateState.from_dictionary(data)
		if not candidate.upsert_loadout_template(created):
			return OperationResult.fail(&"loadout_template_create_failed", "The blank template could not be saved.")
		var character: PersistentCharacterState = candidate.get_character(character_id)
		if character != null:
			character.preferred_loadout_template_id = created.template_id
			character.revision += 1
		return OperationResult.ok(created)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(current_campaign().get_loadout_template(candidate_template.template_id), "Blank loadout template created.")


func duplicate_loadout_template(
		template_id: StringName,
		display_name: String
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or loadout_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var duplicate: LoadoutTemplateState = loadout_service.duplicate_template(campaign, template_id, display_name)
	if duplicate == null:
		return OperationResult.fail(&"loadout_template_missing", "The selected template no longer exists.")
	var data: Dictionary = duplicate.to_dictionary()
	var changes := CampaignChangeSet.new()
	changes.configure(&"loadout_template_duplicated", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		var created := LoadoutTemplateState.from_dictionary(data)
		if not candidate.upsert_loadout_template(created):
			return OperationResult.fail(&"loadout_template_create_failed", "The template copy could not be saved.")
		return OperationResult.ok(created)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(current_campaign().get_loadout_template(duplicate.template_id), "Loadout template duplicated.")


func delete_loadout_template(template_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var existing: LoadoutTemplateState = campaign.get_loadout_template(template_id)
	if existing == null:
		return OperationResult.fail(&"loadout_template_missing", "The selected template no longer exists.")
	if existing.is_authored:
		return OperationResult.fail(&"authored_template_locked", "Authored templates cannot be deleted.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"loadout_template_deleted", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		if not candidate.remove_loadout_template(template_id):
			return OperationResult.fail(&"loadout_template_delete_failed", "The template could not be deleted.")
		return OperationResult.ok(template_id)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(template_id, "Loadout template deleted.")


func set_loadout_template_substitution_policy(
		template_id: StringName,
		policy: StringName
) -> OperationResult:
	var valid_policies: Array[StringName] = [
		LoadoutTemplateState.POLICY_STRICT,
		LoadoutTemplateState.POLICY_EQUIVALENT,
		LoadoutTemplateState.POLICY_BEST_AVAILABLE,
		LoadoutTemplateState.POLICY_CONSERVE_VALUABLE,
	]
	if policy not in valid_policies:
		return OperationResult.fail(&"loadout_policy_invalid", "The selected substitution policy is invalid.")
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var existing: LoadoutTemplateState = campaign.get_loadout_template(template_id)
	if existing == null:
		return OperationResult.fail(&"loadout_template_missing", "The selected template no longer exists.")
	if existing.is_authored:
		return OperationResult.fail(&"authored_template_locked", "Duplicate the authored template before changing its policy.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"loadout_template_policy_changed", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		var updated: LoadoutTemplateState = candidate.get_loadout_template(template_id)
		if updated == null:
			return OperationResult.fail(&"loadout_template_missing", "The selected template no longer exists.")
		updated.substitution_policy = policy
		updated.template_version += 1
		candidate.revision += 1
		return OperationResult.ok(updated)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(current_campaign().get_loadout_template(template_id), "Template substitution policy updated.")


func current_loadout_matches_template(
		character_id: StringName,
		template_id: StringName
) -> bool:
	return (
		loadout_service != null
		and loadout_service.current_loadout_matches_template(
			current_campaign(), character_id, template_id
		)
	)


func capture_strategic_item_locations() -> Dictionary:
	var snapshot: Dictionary = {}
	var campaign: CampaignState = current_campaign()
	if campaign == null:
		return snapshot
	for raw_item: Variant in campaign.get_items():
		var item: CampaignItemState = raw_item as CampaignItemState
		if item != null and item.location != null:
			snapshot[String(item.item_id)] = item.location.to_dictionary()
	return snapshot


func restore_strategic_item_locations(
		location_snapshot: Dictionary,
		reason: StringName = &"strategic_loadout_restored"
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	if location_snapshot.is_empty():
		return OperationResult.no_change(null, "No equipment snapshot is available.")
	var snapshot_copy: Dictionary = location_snapshot.duplicate(true)
	var changes := CampaignChangeSet.new()
	changes.configure(reason, campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		for raw_item_id: Variant in snapshot_copy.keys():
			var item_id := StringName(raw_item_id)
			var item: CampaignItemState = candidate.get_item(item_id) as CampaignItemState
			if item == null:
				return OperationResult.fail(&"snapshot_item_missing", "An item in the saved loadout no longer exists.")
			var raw_location: Variant = snapshot_copy[raw_item_id]
			if not raw_location is Dictionary:
				return OperationResult.fail(&"snapshot_location_invalid", "A saved item location is invalid.")
			var target_location := CampaignItemLocationState.from_dictionary(
				raw_location as Dictionary
			)
			var definition: ItemDefinition = (
				catalogue.item_definition(item.definition_id)
				if catalogue != null
				else null
			)
			if definition != null and definition.fixed_inventory_fixture:
				if (
					item.location == null
					or not target_location.belongs_to_character(item.location.owner_id)
					or target_location.container_id != item.location.container_id
					or target_location.grid_position != item.location.grid_position
					or target_location.is_rotated != item.location.is_rotated
				):
					return OperationResult.fail(
						&"fixed_inventory_fixture",
						"Raider's Sack is a permanent Marauder Belt fixture and cannot be moved by loadout restore."
					)
			if strategic_reservation_service != null:
				var availability: OperationResult = strategic_reservation_service.validate_location_change(
					candidate,
					item_id,
					target_location
				)
				if not availability.success:
					return availability
			if (
				inventory_service != null
				and target_location.is_stronghold_storage()
				and (item.location == null or not item.location.is_stronghold_storage())
			):
				var intake_ids: Array[StringName] = [item_id]
				var capacity_check: OperationResult = inventory_service.validate_storage_intake(
					candidate,
					intake_ids,
					InventoryServiceScript.INTAKE_REQUIRE_CAPACITY,
					current_stronghold_definition(),
					catalogue
				)
				if not capacity_check.success:
					return capacity_check
			item.location = target_location
			item.revision += 1
		var errors: Array[String] = CampaignItemValidator.validate_campaign(candidate, catalogue)
		if not errors.is_empty():
			return OperationResult.fail(&"snapshot_restore_invalid", errors[0])
		return OperationResult.ok(snapshot_copy)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(snapshot_copy, "Loadout restored.")


func return_all_strategic_items(character_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or strategic_equipment_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"strategic_loadout_cleared", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		var item_ids: Array[StringName] = candidate.item_ids_for_character(character_id)
		var movable_item_ids: Array[StringName] = []
		for item_id: StringName in item_ids:
			var item: CampaignItemState = candidate.get_item(item_id) as CampaignItemState
			var definition: ItemDefinition = (
				catalogue.item_definition(item.definition_id)
				if item != null and catalogue != null
				else null
			)
			if definition != null and definition.fixed_inventory_fixture:
				continue
			movable_item_ids.append(item_id)
		if movable_item_ids.is_empty():
			return OperationResult.no_change(null, "The character is not carrying any items.")
		for item_id: StringName in movable_item_ids:
			var result: OperationResult = strategic_equipment_service.return_to_storage_candidate(candidate, item_id)
			if not result.success:
				return result
		return OperationResult.ok(movable_item_ids)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(character_id, "All movable equipment returned to stronghold storage.")


func apply_loadout_template_to_characters(
		character_ids: Array[StringName],
		template_id: StringName
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or loadout_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var preview: OperationResult = loadout_service.preview_apply_template_to_many(campaign, character_ids, template_id)
	if not preview.success:
		return preview
	var changes := CampaignChangeSet.new()
	changes.configure(&"bulk_loadout_template_applied", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return loadout_service.apply_template_to_many_candidate(candidate, character_ids, template_id)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(preview.data, "Loadout template applied to compatible characters.")


func next_level_preview(character_id: StringName) -> Dictionary:
	var campaign: CampaignState = current_campaign()
	if campaign == null or character_progression_service == null:
		return {"eligible": false, "reason": "Progression service unavailable."}
	var character: PersistentCharacterState = campaign.get_character(character_id)
	if character == null:
		return {"eligible": false, "reason": "Character unavailable."}
	var template: CharacterTemplateDefinition = catalogue.character_template(character.template_id)
	return character_progression_service.next_level_preview(character, template)


func level_up_character(
		character_id: StringName,
		expected_level: int,
		selected_talent_id: StringName = &""
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or character_progression_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	if strategic_reservation_service != null:
		var availability: OperationResult = strategic_reservation_service.validate_character_available(
			campaign,
			character_id
		)
		if not availability.success:
			return availability
	var changes := CampaignChangeSet.new()
	changes.configure(&"character_levelled_up", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return character_progression_service.apply_level_candidate(
				candidate,
				character_id,
				expected_level,
				selected_talent_id
			)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	return OperationResult.ok(current_campaign().get_character(character_id), committed.message)


func personnel_capacity_snapshot() -> Dictionary:
	return personnel_capacity_service.snapshot(current_campaign()) if personnel_capacity_service != null else {}


func workforce_market() -> Array[Dictionary]:
	var campaign: CampaignState = current_campaign()
	var result: Array[Dictionary] = []
	if campaign == null or workforce_service == null:
		return result
	for offer: WorkforceOfferState in workforce_service.offers(campaign):
		result.append(workforce_service.preview_offer(campaign, offer.offer_id))
	return result


func workforce_market_status() -> Dictionary:
	return workforce_service.market_status(current_campaign()) if workforce_service != null else {}


func workforce_definitions() -> Array[WorkforceDefinition]:
	return workforce_catalogue.definitions() if workforce_catalogue != null else []


func hire_workforce(offer_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or workforce_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"workforce_hired", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return workforce_service.hire_candidate(candidate, offer_id)
	)
	return state_store.commit(changes)


func dismiss_workforce(worker_definition_id: StringName, quantity: int = 1) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or workforce_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"workforce_dismissed", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return workforce_service.dismiss_candidate(candidate, worker_definition_id, quantity)
	)
	return state_store.commit(changes)


func production_available_recipes() -> Array[Dictionary]:
	return production_service.available_recipe_entries(current_campaign()) if production_service != null else []


func production_projects() -> Array[Dictionary]:
	var campaign: CampaignState = current_campaign()
	var result: Array[Dictionary] = []
	if campaign == null or production_service == null:
		return result
	for project: ProductionProjectState in campaign.get_production_projects():
		if not project.is_open():
			continue
		result.append(production_service.project_snapshot(campaign, project))
	return result


func workforce_assignment_snapshot() -> Dictionary:
	return workforce_assignment_resolver.resolve(current_campaign()) if workforce_assignment_resolver != null else {}


func preview_production_project(recipe_id: StringName, quantity: int = 1, target_item_id: StringName = &"") -> OperationResult:
	return production_service.preview_start(current_campaign(), recipe_id, quantity, target_item_id) if production_service != null else OperationResult.fail(&"production_unavailable", "Production is unavailable.")


func begin_production_project(recipe_id: StringName, quantity: int = 1, target_item_id: StringName = &"") -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or production_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"production_project_started", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return production_service.start_candidate(candidate, recipe_id, quantity, target_item_id)
	)
	return state_store.commit(changes)


func set_production_workers(project_id: StringName, requested_count: int) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or production_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"production_workers_changed", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return production_service.set_requested_workers_candidate(candidate, project_id, requested_count)
	)
	return state_store.commit(changes)


func move_production_priority(project_id: StringName, direction: int) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or production_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"production_priority_changed", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return production_service.set_priority_candidate(candidate, project_id, direction)
	)
	return state_store.commit(changes)


func cancel_production_project(project_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or production_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"production_project_cancelled", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return production_service.cancel_candidate(candidate, project_id)
	)
	return state_store.commit(changes)


func repair_recipe_for_item(item_id: StringName) -> ProductionRecipeDefinition:
	var campaign: CampaignState = current_campaign()
	var item: CampaignItemState = campaign.get_item(item_id) as CampaignItemState if campaign != null else null
	var definition: ItemDefinition = catalogue.item_definition(item.definition_id) if item != null and catalogue != null else null
	return production_catalogue.repair_recipe_for_item(item, definition) if production_catalogue != null else null


func research_entries() -> Array[Dictionary]:
	return research_service.project_entries(current_campaign()) if research_service != null else []


func research_projects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var campaign: CampaignState = current_campaign()
	if campaign == null or research_service == null:
		return result
	for project: ResearchProjectState in campaign.get_research_projects():
		if project != null and project.is_open():
			result.append(research_service.project_snapshot(campaign, project))
	return result


func research_assignment_snapshot() -> Dictionary:
	return research_assignment_resolver.resolve(current_campaign()) if research_assignment_resolver != null else {}


func preview_research_project(research_id: StringName) -> OperationResult:
	return research_service.preview_start(current_campaign(), research_id) if research_service != null else OperationResult.fail(&"research_unavailable", "Research is unavailable.")


func begin_research_project(research_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or research_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"research_project_started", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return research_service.start_candidate(candidate, research_id)
	)
	return state_store.commit(changes)


func set_research_workers(project_id: StringName, requested_count: int) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or research_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"research_workers_changed", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return research_service.set_requested_workers_candidate(candidate, project_id, requested_count)
	)
	return state_store.commit(changes)


func move_research_priority(project_id: StringName, direction: int) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or research_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"research_priority_changed", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return research_service.set_priority_candidate(candidate, project_id, direction)
	)
	return state_store.commit(changes)


func cancel_research_project(project_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or research_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"research_project_cancelled", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return research_service.cancel_candidate(candidate, project_id)
	)
	return state_store.commit(changes)


func recruitment_market() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var campaign := current_campaign()
	if campaign == null or henchman_recruitment_service == null:
		return result
	for offer: HenchmanRecruitmentOfferState in henchman_recruitment_service.offers(campaign):
		result.append(henchman_recruitment_service.preview_offer(campaign, offer.offer_id))
	return result


func recruitment_market_status() -> Dictionary:
	var campaign := current_campaign()
	if campaign == null or henchman_recruitment_service == null:
		return {}
	return henchman_recruitment_service.market_status(campaign)


func refresh_recruitment_market() -> OperationResult:
	return OperationResult.fail(
		&"recruitment_market_monthly",
		"Recruitment candidates refresh automatically every 30 campaign days."
	)


func begin_henchman_recruitment(offer_id: StringName) -> OperationResult:
	var campaign := current_campaign()
	if campaign == null or state_store == null or henchman_recruitment_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var hired_character_id_holder: Dictionary = {"value": &""}
	var hired_message_holder: Dictionary = {"value": ""}
	var changes := CampaignChangeSet.new()
	changes.configure(&"henchman_recruited", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		var result: OperationResult = henchman_recruitment_service.start_candidate(candidate, offer_id)
		if result.success:
			var character: PersistentCharacterState = result.data as PersistentCharacterState
			if character != null:
				hired_character_id_holder["value"] = character.character_id
			hired_message_holder["value"] = result.message
		return result
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	var hired_character_id := StringName(hired_character_id_holder.get("value", &""))
	var hired_character: PersistentCharacterState = current_campaign().get_character(hired_character_id)
	return OperationResult.ok(
		hired_character,
		String(hired_message_holder.get("value", "The recruit joined the Roster immediately."))
	)


func prestige_options(character_id: StringName) -> Array[Dictionary]:
	var campaign := current_campaign()
	return troop_prestige_service.options(campaign, character_id) if campaign != null and troop_prestige_service != null else []


func active_prestige_project(character_id: StringName) -> TroopPrestigeProjectState:
	var campaign := current_campaign()
	return troop_prestige_service.active_project_for_character(campaign, character_id) if campaign != null and troop_prestige_service != null else null


func begin_troop_prestige(character_id: StringName, stage_id: StringName) -> OperationResult:
	var campaign := current_campaign()
	if campaign == null or state_store == null or troop_prestige_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"troop_prestige_started", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return troop_prestige_service.start_candidate(candidate, character_id, stage_id)
	)
	return state_store.commit(changes)


func restore_safe_checkpoint() -> OperationResult:
	if repository == null or not repository.has_safe_checkpoint():
		return OperationResult.fail(&"safe_checkpoint_missing", "No safe checkpoint exists.")
	var restored: CampaignState = repository.load_safe_checkpoint()
	if restored == null:
		return OperationResult.fail(&"safe_checkpoint_invalid", "The safe checkpoint could not be loaded.")
	restored.campaign_status = CampaignStatus.ACTIVE
	for mission: ActiveMissionState in restored.get_active_missions():
		if mission.is_registered():
			mission.status = ActiveMissionState.STATUS_AVAILABLE
			mission.registered_setup_dictionary.clear()
			mission.setup_hash = ""
			mission.selected_character_ids.clear()
	if agent_service != null:
		agent_service.ensure_starting_agent(restored)
	_ensure_stage_51d_state(restored)
	_ensure_stage_52a_state(restored)
	TroopCareerMigration.migrate(restored, catalogue)
	if henchman_recruitment_service != null:
		henchman_recruitment_service.advance_candidate(restored)
		henchman_recruitment_service.ensure_market_candidate(restored)
	if strategic_reservation_service != null:
		strategic_reservation_service.ensure_deployment_reservations(restored)
	if loadout_service != null:
		loadout_service.ensure_authored_templates(restored)
	if strategic_recovery_service != null:
		strategic_recovery_service.ensure_campaign_health(restored)
	var stronghold_validation: Array[String] = _validate_stronghold_state(restored)
	if not stronghold_validation.is_empty():
		return OperationResult.fail(
			&"safe_checkpoint_stronghold_invalid",
			"The safe checkpoint stronghold is invalid: %s" % stronghold_validation[0]
		)
	if not repository.save_campaign(restored):
		return OperationResult.fail(&"safe_checkpoint_restore_failed", "The restored campaign could not be saved.")
	_bind_campaign(restored)
	campaign_loaded.emit()
	return OperationResult.ok(restored, "Last safe campaign state restored.")


func set_clock_speed(speed: int) -> void:
	if strategic_clock == null:
		return
	strategic_clock.set_speed(speed)
	if speed == StrategicClockService.SPEED_PAUSED:
		_flush_clock_state(&"clock_paused")


func pause_clock(persist_state: bool = true) -> void:
	if strategic_clock != null:
		strategic_clock.pause()
	if persist_state:
		_flush_clock_state(&"clock_paused")


func strategic_speed() -> int:
	return strategic_clock.speed if strategic_clock != null else StrategicClockService.SPEED_PAUSED


func process_strategic_time(real_delta: float) -> OperationResult:
	var started_usec: int = RuntimeStallAttribution.begin()
	var campaign: CampaignState = current_campaign()
	if campaign == null or strategic_clock == null:
		RuntimeStallAttribution.end(&"campaign_clock_update", started_usec, "no_campaign")
		return OperationResult.new(true, &"no_change", "No campaign time advanced.")
	var tick_delta: int = strategic_clock.consume_tick_delta(real_delta)
	if tick_delta <= 0:
		RuntimeStallAttribution.end(&"campaign_clock_update", started_usec, "paused_or_fractional")
		return OperationResult.new(true, &"no_change", "No campaign time advanced.")
	var previous_mission_ids: Dictionary = {}
	var previous_mission_statuses: Dictionary = {}
	for mission: ActiveMissionState in campaign.get_active_missions():
		previous_mission_ids[mission.mission_instance_id] = true
		previous_mission_statuses[mission.mission_instance_id] = mission.status
	var previous_report_ids: Dictionary = campaign.travel_notoriety_reports_by_id.duplicate()
	var previous_raid_ids: Dictionary = campaign.raid_operations_by_id.duplicate()
	var previous_agent: AgentState = agent_service.primary_agent(campaign) if agent_service != null else null
	var previous_agent_status: StringName = previous_agent.status if previous_agent != null else &""
	var previous_plan_id: StringName = (
		previous_agent.active_travel_plan.plan_id
		if previous_agent != null and previous_agent.active_travel_plan != null
		else &""
	)
	var previous_operation: SquadTravelOperationState = campaign.current_squad_travel_operation()
	var previous_operation_status: StringName = previous_operation.status if previous_operation != null else &""
	var previous_operation_id: StringName = previous_operation.operation_id if previous_operation != null else &""
	var previous_stronghold_projects: Dictionary = {}
	if campaign.stronghold != null:
		for project: StrongholdProjectStateScript in campaign.stronghold.get_projects():
			previous_stronghold_projects[project.project_id] = project.to_dictionary()
	var travel_advance_result_holder: Dictionary = {"value": {}}
	var recruitment_completion_holder: Dictionary = {"value": []}
	var recruitment_market_refresh_holder: Dictionary = {"value": false}
	var prestige_completion_holder: Dictionary = {"value": []}
	var workforce_market_refresh_holder: Dictionary = {"value": false}
	var production_completion_holder: Dictionary = {"value": []}
	var research_completion_holder: Dictionary = {"value": []}
	var changes := CampaignChangeSet.new()
	changes.configure(&"strategic_clock_advanced", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			if not candidate.advance_campaign_tick(tick_delta):
				return OperationResult.fail(
					&"strategic_clock_rejected",
					"The campaign clock could not advance."
				)
			if agent_service != null:
				agent_service.advance_candidate(candidate)
			if mission_lifecycle_service != null:
				mission_lifecycle_service.advance_candidate(candidate)
			if squad_travel_service != null:
				travel_advance_result_holder["value"] = squad_travel_service.advance_candidate(candidate)
			if stronghold_construction_service != null and candidate.stronghold != null:
				var stronghold_definition: StrongholdDefinitionScript = (
					stronghold_registry.definition(candidate.stronghold.definition_id)
					if stronghold_registry != null
					else null
				)
				stronghold_construction_service.advance_candidate(
					stronghold_definition,
					candidate.stronghold,
					candidate.campaign_tick
				)
			if henchman_recruitment_service != null:
				recruitment_market_refresh_holder["value"] = henchman_recruitment_service.refresh_market_if_due_candidate(candidate)
				recruitment_completion_holder["value"] = henchman_recruitment_service.advance_candidate(candidate)
			if troop_prestige_service != null:
				prestige_completion_holder["value"] = troop_prestige_service.advance_candidate(candidate)
			if workforce_service != null:
				workforce_market_refresh_holder["value"] = workforce_service.refresh_market_if_due_candidate(candidate)
			if production_service != null:
				production_completion_holder["value"] = production_service.advance_candidate(candidate, tick_delta)
			if research_service != null:
				research_completion_holder["value"] = research_service.advance_candidate(candidate, tick_delta)
			if strategic_recovery_service != null:
				strategic_recovery_service.advance_candidate(candidate, tick_delta)
			var travel_result: Dictionary = travel_advance_result_holder.get("value", {}) as Dictionary
			if not (travel_result.get("returned_operation_ids", []) as Array).is_empty():
				var return_errors: Array[String] = candidate.validate_campaign()
				if catalogue != null:
					return_errors.append_array(
						CampaignItemValidator.validate_campaign(candidate, catalogue)
					)
				if not return_errors.is_empty():
					return OperationResult.fail(
						&"return_arrival_invalid",
						"The squad could not complete its return: %s" % return_errors[0]
					)
			return OperationResult.ok(candidate)
	)
	var committed: OperationResult = state_store.commit_runtime(changes)
	if not committed.success:
		RuntimeStallAttribution.end(&"campaign_clock_update", started_usec, "commit_failed")
		return committed
	_clock_state_dirty = true
	_clock_autosave_elapsed += maxf(0.0, real_delta)
	var updated: CampaignState = current_campaign()
	var reached_safe_boundary: bool = false
	var discovered_mission_id: StringName = &""
	var arrived_mission_id: StringName = &""
	var travel_advance_result: Dictionary = travel_advance_result_holder.get("value", {}) as Dictionary
	var returned_operation_ids: Array[StringName] = []
	for raw_operation_id: Variant in travel_advance_result.get("returned_operation_ids", []):
		var returned_operation_id := StringName(raw_operation_id)
		if not returned_operation_id.is_empty():
			returned_operation_ids.append(returned_operation_id)
	var expired_mission_ids: Array[StringName] = []
	var new_report_ids: Array[StringName] = []
	var new_raid_ids: Array[StringName] = []
	var completed_stronghold_projects: Array[Dictionary] = []
	var completed_recruits: Array = recruitment_completion_holder.get("value", []) as Array
	var recruitment_market_refreshed: bool = bool(recruitment_market_refresh_holder.get("value", false))
	var completed_prestiges: Array = prestige_completion_holder.get("value", []) as Array
	var workforce_market_refreshed: bool = bool(workforce_market_refresh_holder.get("value", false))
	var completed_production: Array = production_completion_holder.get("value", []) as Array
	var completed_research: Array = research_completion_holder.get("value", []) as Array
	if recruitment_market_refreshed or workforce_market_refreshed or not completed_production.is_empty() or not completed_research.is_empty() or not completed_recruits.is_empty() or not completed_prestiges.is_empty():
		reached_safe_boundary = true
	if updated != null:
		if not returned_operation_ids.is_empty():
			reached_safe_boundary = true
		var updated_agent: AgentState = agent_service.primary_agent(updated) if agent_service != null else null
		if (
			previous_agent_status == AgentState.STATUS_TRAVELLING
			and updated_agent != null
			and updated_agent.status == AgentState.STATUS_DEPLOYED
			and not previous_plan_id.is_empty()
			and updated_agent.last_resolved_arrival_plan_id == previous_plan_id
		):
			reached_safe_boundary = true
		for mission: ActiveMissionState in updated.get_active_missions():
			if not previous_mission_ids.has(mission.mission_instance_id):
				discovered_mission_id = mission.mission_instance_id
				reached_safe_boundary = true
			elif (
				StringName(previous_mission_statuses.get(mission.mission_instance_id, &""))
				!= ActiveMissionState.STATUS_EXPIRED
				and mission.status == ActiveMissionState.STATUS_EXPIRED
			):
				expired_mission_ids.append(mission.mission_instance_id)
				reached_safe_boundary = true
		for raw_report_id: Variant in updated.travel_notoriety_reports_by_id.keys():
			var report_id := StringName(raw_report_id)
			if not previous_report_ids.has(report_id):
				new_report_ids.append(report_id)
				reached_safe_boundary = true
		for raw_raid_id: Variant in updated.raid_operations_by_id.keys():
			var raid_id := StringName(raw_raid_id)
			if not previous_raid_ids.has(raid_id):
				new_raid_ids.append(raid_id)
				reached_safe_boundary = true
		if updated.stronghold != null:
			for raw_project_id: Variant in previous_stronghold_projects.keys():
				var project_id := StringName(raw_project_id)
				if updated.stronghold.projects_by_id.has(project_id):
					continue
				var completed_entry: Dictionary = previous_stronghold_projects[project_id]
				completed_stronghold_projects.append(completed_entry.duplicate(true))
				reached_safe_boundary = true
		if not previous_operation_id.is_empty():
			var updated_operation: SquadTravelOperationState = updated.get_squad_travel_operation(previous_operation_id)
			if (
				previous_operation_status == SquadTravelOperationState.STATUS_TRAVELLING
				and updated_operation != null
				and updated_operation.status == SquadTravelOperationState.STATUS_IN_TACTICAL
			):
				arrived_mission_id = updated_operation.mission_instance_id
				reached_safe_boundary = true
	if reached_safe_boundary or _clock_autosave_elapsed >= CLOCK_AUTOSAVE_REAL_SECONDS:
		var persistence_reason: StringName = &"coarse_clock_autosave"
		if not returned_operation_ids.is_empty():
			persistence_reason = &"squad_returned"
		elif not arrived_mission_id.is_empty():
			persistence_reason = &"squad_arrived"
		elif not discovered_mission_id.is_empty():
			persistence_reason = &"mission_discovered"
		elif not new_raid_ids.is_empty():
			persistence_reason = &"raid_created"
		elif not new_report_ids.is_empty():
			persistence_reason = &"travel_notoriety_applied"
		elif not expired_mission_ids.is_empty():
			persistence_reason = &"mission_expired"
		elif not completed_recruits.is_empty():
			persistence_reason = &"recruitment_project_completed"
		elif recruitment_market_refreshed:
			persistence_reason = &"recruitment_market_monthly_refresh"
		elif not completed_prestiges.is_empty():
			persistence_reason = &"prestige_project_completed"
		elif not completed_production.is_empty():
			persistence_reason = &"production_project_completed"
		elif not completed_research.is_empty():
			persistence_reason = &"research_project_completed"
		elif workforce_market_refreshed:
			persistence_reason = &"workforce_market_monthly_refresh"
		elif not completed_stronghold_projects.is_empty():
			persistence_reason = &"stronghold_project_completed"
		elif reached_safe_boundary:
			persistence_reason = &"agent_arrived"
		var persisted: OperationResult = _flush_clock_state(persistence_reason)
		if not persisted.success:
			RuntimeStallAttribution.end(&"campaign_clock_update", started_usec, "persistence_failed")
			return persisted
	for report_id: StringName in new_report_ids:
		travel_notoriety_applied.emit(report_id)
	for raid_id: StringName in new_raid_ids:
		raid_operation_created.emit(raid_id)
	for mission_id: StringName in expired_mission_ids:
		mission_expired.emit(mission_id)
	for project_entry: Dictionary in completed_stronghold_projects:
		stronghold_project_completed.emit(
			StringName(project_entry.get("facility_instance_id", "")),
			StringName(project_entry.get("project_kind", ""))
		)
	for raw_character_id: Variant in completed_recruits:
		recruitment_project_completed.emit(StringName(raw_character_id))
	for raw_completion: Variant in completed_prestiges:
		if raw_completion is Dictionary:
			prestige_project_completed.emit(StringName(raw_completion.get("character_id", "")), StringName(raw_completion.get("stage_id", "")))
	for raw_completion: Variant in completed_production:
		if raw_completion is Dictionary:
			production_project_completed.emit(StringName(raw_completion.get("project_id", "")), StringName(raw_completion.get("recipe_id", "")))
	for raw_completion: Variant in completed_research:
		if raw_completion is Dictionary:
			research_project_completed.emit(StringName(raw_completion.get("project_id", "")), StringName(raw_completion.get("research_id", "")))
	if not discovered_mission_id.is_empty():
		strategic_clock.pause()
		agent_mission_discovered.emit(discovered_mission_id)
	if not returned_operation_ids.is_empty():
		strategic_clock.pause()
		for returned_operation_id: StringName in returned_operation_ids:
			var replenishment: OperationResult = _replenish_returned_operation(
				returned_operation_id
			)
			var replenishment_message: String = (
				replenishment.message
				if replenishment != null
				else "The squad returned, but automatic loadout replenishment produced no result."
			)
			if replenishment == null or not replenishment.success:
				push_warning(replenishment_message)
			squad_returned.emit(returned_operation_id, replenishment_message)
	if not arrived_mission_id.is_empty():
		strategic_clock.pause()
		squad_arrived.emit(arrived_mission_id)
	RuntimeStallAttribution.end(&"campaign_clock_update", started_usec, "ticks=%d" % tick_delta)
	return committed


func _replenish_returned_operation(operation_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or operation_id.is_empty():
		return OperationResult.no_change([], "No returned expedition required replenishment.")
	var operation: SquadTravelOperationState = campaign.get_squad_travel_operation(operation_id)
	if operation == null or operation.status != SquadTravelOperationState.STATUS_RESOLVED:
		return OperationResult.no_change([], "The returned expedition is not ready for replenishment.")
	if loadout_service == null:
		return OperationResult.no_change([], "The squad returned; automatic replenishment is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"returned_squad_replenished", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			var candidate_operation: SquadTravelOperationState = (
				candidate.get_squad_travel_operation(operation_id)
			)
			if candidate_operation == null:
				return OperationResult.fail(
					&"return_operation_missing",
					"The returned expedition could not be found for replenishment."
				)
			var replenished_characters: int = 0
			var missing_entries: int = 0
			for character_id: StringName in candidate_operation.character_ids:
				var applied: OperationResult = loadout_service.replenish_preferred_loadout_candidate(
					candidate,
					character_id,
					candidate_operation.desired_loadout_entries(character_id)
				)
				if applied == null or not applied.success:
					return OperationResult.fail(
						&"return_replenishment_failed",
						applied.message if applied != null else "A returning loadout could not be replenished."
					)
				var payload: Dictionary = applied.data as Dictionary if applied.data is Dictionary else {}
				if not (payload.get("replenished", []) as Array).is_empty():
					replenished_characters += 1
				missing_entries += (payload.get("missing", []) as Array).size()
			return OperationResult.ok({
				"replenished_characters": replenished_characters,
				"missing_entries": missing_entries,
			}, "Returned squad reached the lair. Automatic replacements were applied where available.")
	)
	return state_store.commit(changes)


func preview_agent_route(destination: RegionHexCoord) -> AgentTravelPlan:
	return agent_service.preview_plan(destination) if agent_service != null else null


func dispatch_agent(destination: RegionHexCoord) -> OperationResult:
	if agent_service == null:
		return OperationResult.fail(&"agent_service_missing", "Agent service is unavailable.")
	var result: OperationResult = agent_service.dispatch(destination)
	if result.success:
		_mark_clock_state_persisted()
	return result


func primary_agent() -> AgentState:
	return agent_service.primary_agent() if agent_service != null else null


func agent_map_position() -> Vector2:
	return agent_service.agent_map_position() if agent_service != null else Vector2.ZERO


func mission_at_site(site_id: StringName) -> ActiveMissionState:
	var campaign: CampaignState = current_campaign()
	if campaign == null:
		return null
	for mission: ActiveMissionState in campaign.get_active_missions():
		if mission.site_id == site_id and mission.is_actionable():
			return mission
	return null


func character_visibility(character_id: StringName) -> CharacterVisibilitySnapshot:
	return (
		squad_visibility_service.character_snapshot(current_campaign(), character_id, catalogue)
		if squad_visibility_service != null
		else null
	)


func squad_visibility(character_ids: Array[StringName]) -> SquadVisibilitySnapshot:
	var campaign: CampaignState = current_campaign()
	if campaign == null or squad_visibility_service == null:
		return null
	return squad_visibility_service.build_snapshot(
		campaign,
		character_ids,
		catalogue,
		campaign.campaign_tick,
		&"visibility.preview"
	)


func strategic_character_availability(character_id: StringName) -> Dictionary:
	var campaign := current_campaign()
	if troop_prestige_service != null and campaign != null:
		var prestige_project := troop_prestige_service.active_project_for_character(campaign, character_id)
		if prestige_project != null:
			return {"available": false, "reason": "Prestige training is active.", "reservation_id": String(prestige_project.project_id)}
	if strategic_reservation_service == null:
		return {"available": true, "reason": "", "reservation_id": ""}
	return strategic_reservation_service.character_availability(
		current_campaign(),
		character_id
	)


func strategic_recovery_snapshot(character_id: StringName) -> Dictionary:
	var campaign: CampaignState = current_campaign()
	var character: PersistentCharacterState = (
		campaign.get_character(character_id) if campaign != null else null
	)
	if strategic_recovery_service == null or character == null:
		return {}
	return strategic_recovery_service.recovery_snapshot(campaign, character)


func strategic_item_availability(item_id: StringName) -> Dictionary:
	if strategic_reservation_service == null:
		return {"available": true, "reason": "", "reservation_id": ""}
	return strategic_reservation_service.item_availability(
		current_campaign(),
		item_id
	)


func storage_capacity_snapshot() -> Dictionary:
	if inventory_service == null:
		return {
			"used": 0,
			"maximum": 0,
			"free": 0,
			"overflow": 0,
			"usage_ratio": 0.0,
			"is_over_capacity": false,
			"capacity_sources": [],
			"usage_by_category": {},
		}
	return inventory_service.storage_capacity_snapshot(
		current_campaign(),
		current_stronghold_definition(),
		catalogue
	)


func preview_storage_intake(
		item_ids: Array[StringName],
		allow_overflow: bool = false
) -> OperationResult:
	if inventory_service == null:
		return OperationResult.fail(&"inventory_service_missing", "Inventory service is unavailable.")
	return inventory_service.validate_storage_intake(
		current_campaign(),
		item_ids,
		InventoryServiceScript.INTAKE_ALLOW_OVERFLOW
		if allow_overflow
		else InventoryServiceScript.INTAKE_REQUIRE_CAPACITY,
		current_stronghold_definition(),
		catalogue
	)


func storage_group_snapshots(
		category_filter: StringName = &"all",
		availability_filter: StringName = &"all",
		search_text: String = "",
		sort_id: StringName = &"name",
		location_filter: StringName = &"all"
) -> Array[Dictionary]:
	if strategic_storage_query_service == null:
		var empty: Array[Dictionary] = []
		return empty
	return strategic_storage_query_service.build_groups(
		current_campaign(),
		category_filter,
		availability_filter,
		search_text,
		sort_id,
		location_filter
	)


func storage_group_snapshot(
		definition_id: StringName,
		location_filter: StringName = &"all"
) -> Dictionary:
	if strategic_storage_query_service == null:
		return {}
	return strategic_storage_query_service.group_snapshot(
		current_campaign(),
		definition_id,
		location_filter
	)


func storage_instance_snapshot(item_id: StringName) -> Dictionary:
	if strategic_storage_query_service == null:
		return {}
	return strategic_storage_query_service.instance_snapshot(
		current_campaign(),
		item_id
	)


func preview_dismantle_item(item_id: StringName) -> OperationResult:
	if dismantling_service == null:
		return OperationResult.fail(
			&"dismantling_service_missing",
			"Dismantling is unavailable."
		)
	return dismantling_service.preview_dismantle(current_campaign(), item_id)


func dismantle_item(item_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or dismantling_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var preview: OperationResult = dismantling_service.preview_dismantle(
		campaign,
		item_id
	)
	if not preview.success:
		return preview
	var changes := CampaignChangeSet.new()
	changes.configure(&"item_dismantled", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return dismantling_service.dismantle_candidate(candidate, item_id)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var yields: Dictionary = data.get("resource_yields", {}) as Dictionary
	var parts: Array[String] = []
	for raw_resource_id: Variant in yields.keys():
		parts.append("+%d %s" % [
			int(yields[raw_resource_id]),
			String(raw_resource_id).capitalize(),
		])
	parts.sort()
	var completion_message: String = "%s dismantled: %s." % [
		String(data.get("item_name", "Item")),
		", ".join(parts),
	]
	var storage_before: int = int(data.get("storage_used_before", 0))
	var storage_after: int = int(data.get("storage_used_after", storage_before))
	var storage_maximum: int = int(data.get("storage_maximum", 0))
	if storage_before > storage_maximum and storage_after <= storage_maximum:
		completion_message += " Storage is no longer over capacity."
	return OperationResult.committed(
		data,
		completion_message,
		current_campaign().revision
	)



func campaign_squads() -> Array[CampaignSquadState]:
	var campaign: CampaignState = current_campaign()
	return campaign.get_squads() if campaign != null else []


func create_campaign_squad(display_name: String) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or squad_management_service == null:
		return OperationResult.fail(&"squad_service_missing", "Squad management is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"squad_created", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return squad_management_service.create_squad(candidate, display_name)
	)
	return state_store.commit(changes)


func rename_campaign_squad(squad_id: StringName, display_name: String) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or squad_management_service == null:
		return OperationResult.fail(&"squad_service_missing", "Squad management is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"squad_renamed", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return squad_management_service.rename_squad(candidate, squad_id, display_name)
	)
	return state_store.commit(changes)


func disband_campaign_squad(squad_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or squad_management_service == null:
		return OperationResult.fail(&"squad_service_missing", "Squad management is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"squad_disbanded", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return squad_management_service.disband_squad(candidate, squad_id)
	)
	return state_store.commit(changes)


func assign_character_to_squad(character_id: StringName, squad_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or squad_management_service == null:
		return OperationResult.fail(&"squad_service_missing", "Squad management is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"squad_membership_changed", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return squad_management_service.assign_character(candidate, character_id, squad_id)
	)
	return state_store.commit(changes)


func stable_bays() -> Array[StableBayState]:
	var campaign: CampaignState = current_campaign()
	return stable_bay_service.supported_bays(campaign) if campaign != null and stable_bay_service != null else []


func ready_stable_bays() -> Array[StableBayState]:
	var campaign: CampaignState = current_campaign()
	return stable_bay_service.ready_bays(campaign) if campaign != null and stable_bay_service != null else []


func stable_bay_summary(bay_id: StringName) -> Dictionary:
	var campaign: CampaignState = current_campaign()
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	return stable_bay_service.bay_summary(campaign, bay) if stable_bay_service != null and bay != null else {}


func stable_bay_for_facility(facility_instance_id: StringName) -> StableBayState:
	var campaign: CampaignState = current_campaign()
	if campaign == null or stable_bay_service == null:
		return null
	stable_bay_service.ensure_campaign_bays(campaign)
	return stable_bay_service.bay_for_facility(campaign, facility_instance_id)


func stable_bay_is_operational(bay_id: StringName) -> bool:
	var campaign: CampaignState = current_campaign()
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	return stable_bay_service != null and stable_bay_service.stable_bay_is_operational(campaign, bay)


func stable_is_operational() -> bool:
	return stable_bay_service != null and stable_bay_service.stable_is_operational(current_campaign())


func assign_squad_to_stable_bay(bay_id: StringName, squad_id: StringName) -> OperationResult:
	return _commit_stable_bay_change(&"stable_squad_assigned", func(candidate: CampaignState) -> OperationResult:
		return stable_bay_service.assign_squad(candidate, bay_id, squad_id)
	)


func clear_stable_bay(bay_id: StringName) -> OperationResult:
	return _commit_stable_bay_change(&"stable_bay_cleared", func(candidate: CampaignState) -> OperationResult:
		return stable_bay_service.clear_bay(candidate, bay_id)
	)


func assign_walking_to_stable_bay(bay_id: StringName) -> OperationResult:
	return _commit_stable_bay_change(&"stable_walking_assigned", func(candidate: CampaignState) -> OperationResult:
		return stable_bay_service.assign_walking(candidate, bay_id)
	)


func assign_transport_to_stable_bay(bay_id: StringName, transport_asset_id: StringName) -> OperationResult:
	return _commit_stable_bay_change(&"stable_transport_assigned", func(candidate: CampaignState) -> OperationResult:
		return stable_bay_service.assign_transport_asset(candidate, bay_id, transport_asset_id)
	)


func set_stable_formation_slot(bay_id: StringName, slot_id: StringName, character_id: StringName) -> OperationResult:
	return _commit_stable_bay_change(&"stable_formation_changed", func(candidate: CampaignState) -> OperationResult:
		return stable_bay_service.set_formation_slot(candidate, bay_id, slot_id, character_id)
	)


func remove_stable_formation_character(bay_id: StringName, character_id: StringName) -> OperationResult:
	return _commit_stable_bay_change(&"stable_formation_reserve_changed", func(candidate: CampaignState) -> OperationResult:
		return stable_bay_service.remove_formation_character(candidate, bay_id, character_id)
	)


func clear_stable_formation(bay_id: StringName) -> OperationResult:
	return _commit_stable_bay_change(&"stable_formation_cleared", func(candidate: CampaignState) -> OperationResult:
		return stable_bay_service.clear_formation(candidate, bay_id)
	)


func auto_arrange_stable_formation(bay_id: StringName) -> OperationResult:
	return _commit_stable_bay_change(&"stable_formation_auto_arranged", func(candidate: CampaignState) -> OperationResult:
		return stable_bay_service.auto_arrange_formation(candidate, bay_id)
	)


func toggle_stable_transport_fitting(bay_id: StringName, fitting_id: StringName) -> OperationResult:
	return _commit_stable_bay_change(&"stable_fitting_changed", func(candidate: CampaignState) -> OperationResult:
		return stable_bay_service.toggle_fitting(candidate, bay_id, fitting_id)
	)


func _commit_stable_bay_change(reason: StringName, callback: Callable) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or stable_bay_service == null:
		return OperationResult.fail(&"stable_service_missing", "Stable management is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(reason, campaign.revision)
	changes.stage(callback)
	return state_store.commit(changes)

func preview_squad_route(
	mission_instance_id: StringName,
	waypoints: Array[RegionHexCoord]
) -> SquadRoutePlan:
	var campaign: CampaignState = current_campaign()
	var mission: ActiveMissionState = (
		campaign.get_active_mission(mission_instance_id) if campaign != null else null
	)
	if campaign == null or mission == null or squad_route_planning_service == null:
		return null
	return squad_route_planning_service.preview_route(
		campaign,
		current_region_definition(),
		mission,
		waypoints
	)


func available_squad_transports() -> Array[Dictionary]:
	return (
		squad_transport_service.available_transport_choices(current_campaign())
		if squad_transport_service != null
		else []
	)


func stable_transport_snapshot() -> Dictionary:
	return (
		squad_transport_service.support_snapshot(current_campaign())
		if squad_transport_service != null
		else {}
	)


func transport_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if squad_transport_service == null:
		return result
	var campaign: CampaignState = current_campaign()
	for transport_definition: SquadTransportDefinition in squad_transport_service.definitions():
		var data: Dictionary = transport_definition.to_dictionary()
		var research_complete: bool = transport_definition.research_unlock_id.is_empty()
		if campaign != null and not research_complete:
			research_complete = campaign.has_completed_research(transport_definition.research_unlock_id)
		data["research_complete"] = research_complete
		data["acquisition_cost_text"] = squad_transport_service.acquisition_cost_text(transport_definition)
		result.append(data)
	return result


func acquire_transport(
		transport_definition_id: StringName,
		target_stable_bay_id: StringName = &""
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or squad_transport_service == null or stable_bay_service == null:
		return OperationResult.fail(&"transport_service_missing", "Transport acquisition is unavailable.")
	stable_bay_service.ensure_campaign_bays(campaign)
	var changes := CampaignChangeSet.new()
	changes.configure(&"transport_acquired", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			stable_bay_service.ensure_campaign_bays(candidate)
			return squad_transport_service.acquire_transport_candidate(
				candidate,
				transport_definition_id,
				target_stable_bay_id
			)
	)
	return state_store.commit(changes)


func shop_buy_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if shop_service == null:
		return result
	return shop_service.starting_catalogue_entries(current_campaign())


func shop_sell_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if shop_service == null:
		return result
	return shop_service.sell_storage_entries(current_campaign())


func preview_shop_buy(definition_id: StringName, quantity: int = 1) -> OperationResult:
	if shop_service == null:
		return OperationResult.fail(&"shop_service_missing", "The Shop is unavailable.")
	return shop_service.preview_buy(current_campaign(), definition_id, quantity)


func buy_shop_item(definition_id: StringName, quantity: int = 1) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or shop_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var preview: OperationResult = shop_service.preview_buy(campaign, definition_id, quantity)
	if not preview.success:
		return preview
	var changes := CampaignChangeSet.new()
	changes.configure(&"shop_purchase", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return shop_service.buy_candidate(candidate, definition_id, quantity)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	return OperationResult.ok(
		data,
		"Purchased %d × %s for %d Gold." % [
			int(data.get("quantity", quantity)),
			String(data.get("display_name", definition_id)),
			int(data.get("total_gold", 0)),
		]
	)


func preview_shop_sell(item_id: StringName, quantity: int = 1) -> OperationResult:
	if shop_service == null:
		return OperationResult.fail(&"shop_service_missing", "The Shop is unavailable.")
	return shop_service.preview_sell(current_campaign(), item_id, quantity)


func sell_shop_item(item_id: StringName, quantity: int = 1) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or shop_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var preview: OperationResult = shop_service.preview_sell(campaign, item_id, quantity)
	if not preview.success:
		return preview
	var changes := CampaignChangeSet.new()
	changes.configure(&"shop_sale", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return shop_service.sell_candidate(candidate, item_id, quantity)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	return OperationResult.ok(
		data,
		"Sold %d × %s for %d Gold." % [
			int(data.get("quantity", quantity)),
			String(data.get("display_name", "Item")),
			int(data.get("total_gold", 0)),
		]
	)


func preview_shop_sell_resource(resource_id: StringName, lot_quantity: int = 1) -> OperationResult:
	if shop_service == null:
		return OperationResult.fail(&"shop_service_missing", "The Shop is unavailable.")
	return shop_service.preview_sell_resource(current_campaign(), resource_id, lot_quantity)


func sell_shop_resource(resource_id: StringName, lot_quantity: int = 1) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or state_store == null or shop_service == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var preview: OperationResult = shop_service.preview_sell_resource(
		campaign,
		resource_id,
		lot_quantity
	)
	if not preview.success:
		return preview
	var changes := CampaignChangeSet.new()
	changes.configure(&"shop_resource_sale", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return shop_service.sell_resource_candidate(candidate, resource_id, lot_quantity)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	return OperationResult.ok(
		data,
		"Sold %d %s for %d Gold." % [
			int(data.get("resource_amount", 0)),
			String(data.get("display_name", resource_id)),
			int(data.get("total_gold", 0)),
		]
	)


func dismantle_transport(transport_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or squad_transport_service == null:
		return OperationResult.fail(&"transport_service_missing", "Transport dismantling is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"transport_dismantled", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return squad_transport_service.dismantle_transport_candidate(candidate, transport_id)
	)
	return state_store.commit(changes)


# Compatibility entry point for older callers.
func sell_transport(transport_id: StringName) -> OperationResult:
	return dismantle_transport(transport_id)


func rename_transport(transport_id: StringName, display_name: String) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or squad_transport_service == null:
		return OperationResult.fail(&"transport_service_missing", "Transport management is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"transport_renamed", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		return squad_transport_service.rename_transport_candidate(candidate, transport_id, display_name)
	)
	return state_store.commit(changes)


func set_transport_support(transport_id: StringName, enabled: bool) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or squad_transport_service == null:
		return OperationResult.fail(&"transport_service_missing", "Stable transport support is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"transport_support_changed", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return squad_transport_service.set_transport_support_candidate(candidate, transport_id, enabled)
	)
	return state_store.commit(changes)


func default_squad_transport_id() -> StringName:
	return (
		squad_transport_service.default_transport_id(current_campaign())
		if squad_transport_service != null
		else &"transport.walking"
	)


func squad_transport_snapshot(
		transport_id: StringName,
		assigned_count: int = 1,
		character_count: int = 0
) -> Dictionary:
	if squad_transport_service == null:
		return {}
	return squad_transport_service.transport_choice_snapshot(
		current_campaign(),
		transport_id,
		assigned_count,
		character_count
	)


func preview_squad_operation(
		mission_instance_id: StringName,
		character_ids: Array[StringName],
		waypoints: Array[RegionHexCoord],
		transport_id: StringName = &"transport.walking",
		transport_count: int = 1
) -> Dictionary:
	var base_route: SquadRoutePlan = preview_squad_route(mission_instance_id, waypoints)
	var visibility: SquadVisibilitySnapshot = squad_visibility(character_ids)
	var resolved_transport_id: StringName = (
		transport_id if not transport_id.is_empty() else &"transport.walking"
	)
	var transport_data: Dictionary = (
		squad_transport_service.transport_choice_snapshot(
			current_campaign(),
			resolved_transport_id,
			transport_count,
			character_ids.size()
		)
		if squad_transport_service != null
		else {}
	)
	var transport_definition: SquadTransportDefinition = (
		squad_transport_service.definition(resolved_transport_id)
		if squad_transport_service != null
		else null
	)
	var preliminary_entries: Array[TravelExposureEntry] = []
	if base_route != null and visibility != null and travel_notoriety_service != null:
		preliminary_entries = travel_notoriety_service.build_exposure_entries(
			current_region_definition(),
			base_route,
			visibility,
			&"squad_travel.preview.pre_transport"
		)
	var route: SquadRoutePlan = (
		squad_transport_service.apply_transport_to_route(
			base_route,
			transport_definition,
			preliminary_entries
		)
		if base_route != null and transport_definition != null and squad_transport_service != null
		else base_route
	)
	var entries: Array[TravelExposureEntry] = []
	if route != null and visibility != null and travel_notoriety_service != null:
		entries = travel_notoriety_service.build_exposure_entries(
			current_region_definition(),
			route,
			visibility,
			&"squad_travel.preview"
		)
	var modifier_percent: int = int(transport_data.get("journey_notoriety_modifier_percent", 0))
	var notoriety: Dictionary = (
		squad_transport_service.apply_notoriety_modifier_to_entries(entries, modifier_percent)
		if squad_transport_service != null
		else {
			"base_total": travel_notoriety_service.projected_total(entries) if travel_notoriety_service != null else 0,
			"modifier_percent": 0,
			"adjustment": 0,
			"final_total": travel_notoriety_service.projected_total(entries) if travel_notoriety_service != null else 0,
		}
	)
	if transport_definition != null and squad_transport_service != null:
		transport_data["terrain_multiplier"] = squad_transport_service.terrain_multiplier_for_entries(
			transport_definition,
			preliminary_entries
		)
	return {
		"route": route,
		"visibility": visibility,
		"entries": entries,
		"transport": transport_data,
		"notoriety": notoriety,
		"projected_total": int(notoriety.get("final_total", 0)),
		"projected_by_subregion": (
			travel_notoriety_service.projected_by_subregion(entries)
			if travel_notoriety_service != null
			else {}
		),
	}


func dispatch_squad(
		mission_instance_id: StringName,
		character_ids: Array[StringName],
		waypoints: Array[RegionHexCoord],
		transport_id: StringName = &"transport.walking",
		transport_count: int = 1
) -> OperationResult:
	pause_clock()
	var preview: Dictionary = preview_squad_operation(
		mission_instance_id,
		character_ids,
		waypoints,
		transport_id,
		transport_count
	)
	var route: SquadRoutePlan = preview.get("route") as SquadRoutePlan
	var visibility: SquadVisibilitySnapshot = preview.get("visibility") as SquadVisibilitySnapshot
	var transport_data: Dictionary = preview.get("transport", {}) as Dictionary
	var entries: Array[TravelExposureEntry] = []
	var raw_entries: Variant = preview.get("entries", [])
	if raw_entries is Array:
		for raw_entry: Variant in raw_entries as Array:
			var entry: TravelExposureEntry = raw_entry as TravelExposureEntry
			if entry != null:
				entries.append(entry)
	if route == null:
		return OperationResult.fail(&"squad_route_invalid", "No valid route reaches the mission.")
	if visibility == null:
		return OperationResult.fail(&"squad_visibility_invalid", "The selected squad has no valid visibility profile.")
	if transport_data.is_empty():
		return OperationResult.fail(&"squad_transport_invalid", "The selected travel method is unavailable.")
	if not bool(transport_data.get("availability_valid", false)):
		return OperationResult.fail(
			&"squad_transport_unavailable",
			String(transport_data.get("validation_message", "The selected transport is unavailable."))
		)
	if not bool(transport_data.get("capacity_valid", false)):
		return OperationResult.fail(
			&"squad_transport_capacity",
			String(transport_data.get("validation_message", "The selected squad exceeds transport passenger capacity."))
		)
	var result: OperationResult = mission_coordinator.register_squad_for_travel(
		mission_instance_id,
		character_ids,
		route,
		visibility,
		entries,
		transport_data
	)
	if result.success:
		_mark_clock_state_persisted()
	return result



func preview_stable_bay_operation(
		mission_instance_id: StringName,
		bay_id: StringName,
		waypoints: Array[RegionHexCoord]
) -> Dictionary:
	var campaign: CampaignState = current_campaign()
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	if bay == null or stable_bay_service == null:
		return {}
	var formation: OperationResult = stable_bay_service.formation_validation(campaign, bay)
	if not formation.success:
		return {"validation_message": formation.message, "stable_bay_id": String(bay_id)}
	var character_ids: Array[StringName] = []
	for character_id: StringName in bay.occupied_character_ids():
		var character: PersistentCharacterState = campaign.get_character(character_id)
		if character == null or character.is_dead:
			continue
		if character.health_initialized and (
			character.current_hp <= 0
			or character.nonlethal_damage >= maxi(1, character.current_hp)
		):
			continue
		character_ids.append(character_id)
	var base_route: SquadRoutePlan = preview_squad_route(mission_instance_id, waypoints)
	var visibility: SquadVisibilitySnapshot = squad_visibility(character_ids)
	var transport_data: Dictionary = stable_bay_service.bay_transport_snapshot(campaign, bay)
	transport_data["stable_bay_id"] = String(bay.bay_id)
	transport_data["campaign_squad_id"] = String(bay.assigned_squad_id)
	transport_data["transport_asset_id"] = String(bay.transport_asset_id)
	transport_data["formation_character_ids_by_slot"] = bay.formation_character_ids_by_slot.duplicate(true)
	transport_data["availability_valid"] = stable_bay_service.stable_bay_is_operational(campaign, bay)
	transport_data["capacity_valid"] = formation.success
	if not bool(transport_data.get("availability_valid", false)):
		transport_data["validation_message"] = "This Stable must be operational before its squad can depart."
	var transport_id := StringName(transport_data.get("id", bay.transport_method_id))
	var transport_definition: SquadTransportDefinition = (
		squad_transport_service.definition(transport_id)
		if squad_transport_service != null
		else null
	)
	var preliminary_entries: Array[TravelExposureEntry] = []
	if base_route != null and visibility != null and travel_notoriety_service != null:
		preliminary_entries = travel_notoriety_service.build_exposure_entries(
			current_region_definition(), base_route, visibility, &"squad_travel.preview.pre_transport"
		)
	var route: SquadRoutePlan = (
		squad_transport_service.apply_transport_to_route(base_route, transport_definition, preliminary_entries)
		if base_route != null and transport_definition != null and squad_transport_service != null
		else base_route
	)
	var entries: Array[TravelExposureEntry] = []
	if route != null and visibility != null and travel_notoriety_service != null:
		entries = travel_notoriety_service.build_exposure_entries(
			current_region_definition(), route, visibility, &"squad_travel.preview"
		)
	var modifier_percent: int = int(transport_data.get("journey_notoriety_modifier_percent", 0))
	var notoriety: Dictionary = (
		squad_transport_service.apply_notoriety_modifier_to_entries(entries, modifier_percent)
		if squad_transport_service != null
		else {}
	)
	if transport_definition != null and squad_transport_service != null:
		transport_data["terrain_multiplier"] = squad_transport_service.terrain_multiplier_for_entries(
			transport_definition, preliminary_entries
		)
	return {
		"route": route,
		"visibility": visibility,
		"entries": entries,
		"transport": transport_data,
		"notoriety": notoriety,
		"character_ids": character_ids,
		"stable_bay_id": String(bay.bay_id),
		"campaign_squad_id": String(bay.assigned_squad_id),
		"projected_total": int(notoriety.get("final_total", 0)),
	}


func dispatch_stable_bay(
		mission_instance_id: StringName,
		bay_id: StringName,
		waypoints: Array[RegionHexCoord]
) -> OperationResult:
	pause_clock()
	var preview: Dictionary = preview_stable_bay_operation(mission_instance_id, bay_id, waypoints)
	var route: SquadRoutePlan = preview.get("route") as SquadRoutePlan
	var visibility: SquadVisibilitySnapshot = preview.get("visibility") as SquadVisibilitySnapshot
	var transport_data: Dictionary = preview.get("transport", {}) as Dictionary
	var character_ids: Array[StringName] = []
	for raw_character_id: Variant in preview.get("character_ids", []) as Array:
		var character_id := StringName(raw_character_id)
		if not character_id.is_empty():
			character_ids.append(character_id)
	var entries: Array[TravelExposureEntry] = []
	for raw_entry: Variant in preview.get("entries", []) as Array:
		var entry: TravelExposureEntry = raw_entry as TravelExposureEntry
		if entry != null:
			entries.append(entry)
	if route == null:
		return OperationResult.fail(&"route_not_confirmed", "No valid route reaches the mission.")
	if visibility == null or character_ids.is_empty():
		return OperationResult.fail(&"squad_unavailable", "The prepared squad has no deployable members.")
	if transport_data.is_empty() or not bool(transport_data.get("availability_valid", false)):
		return OperationResult.fail(&"stable_disabled", String(transport_data.get("validation_message", "The Stable expedition is unavailable.")))
	if not bool(transport_data.get("capacity_valid", false)):
		return OperationResult.fail(&"formation_incomplete", String(transport_data.get("validation_message", "The Stable formation is incomplete.")))
	var result: OperationResult = mission_coordinator.register_squad_for_travel(
		mission_instance_id, character_ids, route, visibility, entries, transport_data
	)
	if result.success:
		_mark_clock_state_persisted()
	return result

func current_mission_transport_snapshot() -> Dictionary:
	return _transport_snapshot_for_operation(current_squad_operation())


func _transport_snapshot_for_operation(
		operation: SquadTravelOperationState
) -> Dictionary:
	if operation != null:
		var transport_definition: SquadTransportDefinition = (
			squad_transport_service.definition(operation.transport_id)
			if squad_transport_service != null
			else null
		)
		# One exact transport asset represents the complete expedition method.
		# Walking has no asset count but still has a valid six-person formation.
		var count: int = 0 if operation.transport_is_walking else maxi(1, operation.transport_assigned_count)
		return {
			"id": String(operation.transport_id),
			"display_name": operation.transport_display_name,
			"assigned_count": count,
			"transport_instance_ids": _name_array(operation.transport_instance_ids),
			"transport_asset_id": String(operation.transport_asset_id),
			"total_passenger_capacity": operation.transport_passenger_capacity,
			"strategic_speed_multiplier": operation.transport_strategic_speed_multiplier,
			"terrain_multiplier": operation.transport_terrain_multiplier,
			"total_cargo_capacity_lb": operation.transport_cargo_capacity_lb,
			"cargo_capacity_lb": operation.transport_cargo_capacity_lb,
			"journey_notoriety_modifier_percent": operation.transport_notoriety_modifier_percent,
			"total_stable_space": operation.transport_stable_space,
			"is_walking": operation.transport_is_walking,
			"total_captive_capacity": transport_definition.captive_capacity * count if transport_definition != null else 0,
			"total_cage_anchor_capacity": transport_definition.cage_anchor_capacity * count if transport_definition != null else 0,
			"total_monster_capacity": transport_definition.monster_capacity * count if transport_definition != null else 0,
			"total_siege_anchor_capacity": transport_definition.siege_anchor_capacity * count if transport_definition != null else 0,
			"total_oversized_cargo_capacity": transport_definition.oversized_cargo_capacity * count if transport_definition != null else 0,
		}
	return squad_transport_snapshot(&"transport.walking", 0, 0)


func _squad_operation_for_mission(
		mission_instance_id: StringName
) -> SquadTravelOperationState:
	var campaign: CampaignState = current_campaign()
	if campaign == null or mission_instance_id.is_empty():
		return null
	var matched_operation: SquadTravelOperationState
	for operation: SquadTravelOperationState in campaign.get_squad_travel_operations():
		if operation.mission_instance_id != mission_instance_id:
			continue
		if operation.is_active():
			return operation
		matched_operation = operation
	# A result can be raised during the same frame that an operation changes
	# status. Retain the exact matching operation snapshot rather than falling
	# back to a zero-cargo Walking placeholder.
	return matched_operation


func save_pending_mission_recovery(
		envelope: MissionCommitEnvelope,
		selected_optional_item_ids: Array[StringName] = [],
		selected_captive_ids: Array[StringName] = [],
		selection_initialized: bool = false
) -> OperationResult:
	if repository == null or not repository.has_method("save_pending_mission_recovery"):
		return OperationResult.fail(&"pending_recovery_repository_missing", "Pending recovery persistence is unavailable.")
	if envelope == null or not envelope.validate_envelope().is_empty():
		return OperationResult.fail(&"pending_recovery_invalid", "The pending mission recovery result is invalid.")
	var selected_ids: Array[String] = []
	for item_id: StringName in selected_optional_item_ids:
		selected_ids.append(String(item_id))
	selected_ids.sort()
	var selected_captives: Array[String] = []
	for captive_id: StringName in selected_captive_ids:
		selected_captives.append(String(captive_id))
	selected_captives.sort()
	var data: Dictionary = {
		"campaign_id": String(current_campaign().campaign_id) if current_campaign() != null else "",
		"envelope": envelope.to_dictionary(),
		"selected_optional_item_ids": selected_ids,
		"selected_captive_ids": selected_captives,
		"selection_initialized": selection_initialized,
	}
	if not bool(repository.call("save_pending_mission_recovery", data)):
		return OperationResult.fail(&"pending_recovery_save_failed", "The pending mission recovery could not be saved.")
	return OperationResult.ok(data, "Pending mission recovery saved.")


func load_pending_mission_recovery() -> Dictionary:
	if repository == null or not repository.has_method("load_pending_mission_recovery"):
		return {}
	var raw_value: Variant = repository.call("load_pending_mission_recovery")
	if not raw_value is Dictionary:
		return {}
	var data: Dictionary = raw_value as Dictionary
	var campaign: CampaignState = current_campaign()
	if campaign == null or StringName(data.get("campaign_id", "")) != campaign.campaign_id:
		clear_pending_mission_recovery()
		return {}
	var raw_envelope: Variant = data.get("envelope", {})
	if not raw_envelope is Dictionary:
		clear_pending_mission_recovery()
		return {}
	var envelope := MissionCommitEnvelope.from_dictionary(raw_envelope as Dictionary)
	if envelope == null or not envelope.validate_envelope().is_empty():
		clear_pending_mission_recovery()
		return {}
	# Stage 5.3G preserves pending-recovery saves created before per-character
	# contribution provenance and XP breakdowns existed. The immutable setup and
	# result contain enough authority to normalise objectives, selected captives,
	# XP and history without reopening the retired tactical scene.
	if MissionCharacterOutcomeService.needs_lifecycle_migration(envelope.result):
		MissionCharacterOutcomeService.reconcile_after_recovery_selection(
			envelope.result,
			envelope.setup
		)
		MissionExperienceAwardService.apply_awards(envelope.result, envelope.setup)
		MissionCharacterOutcomeService.refresh_history(envelope.result, envelope.setup)
		var migration_errors: Array[String] = envelope.result.validate_result()
		migration_errors.append_array(
			MissionExperienceAwardService.validate_awards(
				envelope.result,
				envelope.setup
			)
		)
		if not migration_errors.is_empty():
			clear_pending_mission_recovery()
			return {}
		data["envelope"] = envelope.to_dictionary()
		repository.call("save_pending_mission_recovery", data)
	var selected_ids: Array[StringName] = []
	for raw_item_id: Variant in data.get("selected_optional_item_ids", []) as Array:
		var item_id := StringName(raw_item_id)
		if not item_id.is_empty():
			selected_ids.append(item_id)
	var selected_captives: Array[StringName] = []
	for raw_captive_id: Variant in data.get("selected_captive_ids", []) as Array:
		var captive_id := StringName(raw_captive_id)
		if not captive_id.is_empty():
			selected_captives.append(captive_id)
	return {
		"envelope": envelope,
		"selected_optional_item_ids": selected_ids,
		"selected_captive_ids": selected_captives,
		"selection_initialized": bool(data.get("selection_initialized", false)),
	}


func clear_pending_mission_recovery() -> bool:
	if repository == null or not repository.has_method("clear_pending_mission_recovery"):
		return true
	return bool(repository.call("clear_pending_mission_recovery"))


func build_mission_recovery_snapshot(envelope: MissionCommitEnvelope) -> Dictionary:
	if mission_recovery_selection_service == null or envelope == null or envelope.result == null:
		return {}
	# Recovery must use the expedition that produced this exact mission result.
	# Using the first active operation breaks as soon as several Stables have
	# squads away at once and can incorrectly produce a zero-capacity manifest.
	var operation: SquadTravelOperationState = _squad_operation_for_mission(
		envelope.result.mission_id
	)
	var transport_snapshot: Dictionary = _transport_snapshot_for_operation(operation)
	if operation == null and envelope.setup != null and squad_transport_service != null:
		var setup_transport_asset_id: StringName = envelope.setup.transport_asset_id()
		var deployed_count: int = envelope.setup.player_unit_order().size()
		if not setup_transport_asset_id.is_empty():
			transport_snapshot = squad_transport_service.asset_assignment_snapshot(
				current_campaign(),
				setup_transport_asset_id,
				deployed_count
			)
		else:
			transport_snapshot = squad_transport_snapshot(
				envelope.setup.transport_method_id(),
				0,
				deployed_count
			)
	var snapshot: Dictionary = mission_recovery_selection_service.build_snapshot(
		envelope,
		transport_snapshot,
		current_campaign(),
		catalogue
	)
	if operation != null and squad_transport_service != null:
		snapshot["projected_return_minutes"] = ceili(operation.route_plan.total_minutes()) if operation.route_plan != null else 0
		snapshot["return_notoriety"] = squad_transport_service.notoriety_snapshot(
			operation.exposure_entries,
			operation.transport_notoriety_modifier_percent
		)
	return snapshot


func validate_mission_recovery_selection(
		snapshot: Dictionary,
		selected_optional_item_ids: Array[StringName],
		selected_captive_ids: Array[StringName] = []
) -> OperationResult:
	if mission_recovery_selection_service == null:
		return OperationResult.fail(&"mission_recovery_service_missing", "Mission recovery selection is unavailable.")
	return mission_recovery_selection_service.validate_selection(
		snapshot, selected_optional_item_ids, selected_captive_ids
	)


func prepare_mission_recovery_envelope(
		envelope: MissionCommitEnvelope,
		selected_optional_item_ids: Array[StringName],
		selected_captive_ids: Array[StringName] = []
) -> OperationResult:
	if mission_recovery_selection_service == null:
		return OperationResult.fail(&"mission_recovery_service_missing", "Mission recovery selection is unavailable.")
	var snapshot: Dictionary = build_mission_recovery_snapshot(envelope)
	var validation: OperationResult = mission_recovery_selection_service.validate_selection(
		snapshot,
		selected_optional_item_ids,
		selected_captive_ids
	)
	if not validation.success:
		return validation
	return mission_recovery_selection_service.filter_envelope(
		envelope,
		selected_optional_item_ids,
		selected_captive_ids
	)


func prison_snapshot() -> Dictionary:
	return captive_service.prison_snapshot(current_campaign()) if captive_service != null else {}


func release_captive(captive_id: StringName) -> OperationResult:
	return captive_service.release_captive(captive_id) if captive_service != null else OperationResult.fail(
		&"captive_service_missing", "Captive management is unavailable."
	)


func ransom_captive(captive_id: StringName) -> OperationResult:
	return captive_service.ransom_captive(captive_id) if captive_service != null else OperationResult.fail(
		&"captive_service_missing", "Captive management is unavailable."
	)


func preview_release_captive(captive_id: StringName) -> OperationResult:
	return captive_service.preview_release(captive_id) if captive_service != null else OperationResult.fail(
		&"captive_service_missing", "Captive management is unavailable."
	)


func preview_ransom_captive(captive_id: StringName) -> OperationResult:
	return captive_service.preview_ransom(captive_id) if captive_service != null else OperationResult.fail(
		&"captive_service_missing", "Captive management is unavailable."
	)


func preview_interrogate_captive(captive_id: StringName) -> OperationResult:
	return captive_service.preview_interrogate(captive_id) if captive_service != null else OperationResult.fail(
		&"captive_service_missing", "Captive management is unavailable."
	)


func interrogate_captive(captive_id: StringName) -> OperationResult:
	return captive_service.interrogate_captive(captive_id) if captive_service != null else OperationResult.fail(
		&"captive_service_missing", "Captive management is unavailable."
	)


func cancel_squad_deployment(mission_instance_id: StringName) -> OperationResult:
	pause_clock()
	if mission_coordinator == null:
		return OperationResult.fail(&"mission_coordinator_missing", "Mission coordinator is unavailable.")
	return mission_coordinator.cancel_squad_deployment(mission_instance_id)


func current_squad_operation() -> SquadTravelOperationState:
	var campaign: CampaignState = current_campaign()
	return campaign.current_squad_travel_operation() if campaign != null else null


func regional_notoriety_total() -> int:
	var campaign: CampaignState = current_campaign()
	if campaign == null or subregion_notoriety_service == null:
		return 0
	return subregion_notoriety_service.regional_total(campaign, campaign.current_region_id)


func regional_retaliation_threshold() -> int:
	var campaign: CampaignState = current_campaign()
	return (
		regional_retaliation_service.threshold_for_region(campaign.current_region_id)
		if campaign != null and regional_retaliation_service != null
		else 150
	)


func local_notoriety_states() -> Array[SubregionNotorietyState]:
	var campaign: CampaignState = current_campaign()
	return (
		campaign.get_subregion_notoriety_states(campaign.current_region_id)
		if campaign != null
		else []
	)


func current_stronghold_definition() -> StrongholdDefinitionScript:
	if stronghold_registry == null:
		return null
	var campaign: CampaignState = current_campaign()
	if campaign != null and campaign.stronghold != null:
		return stronghold_registry.definition(campaign.stronghold.definition_id)
	return stronghold_registry.starting_definition()


func current_stronghold_state() -> StrongholdStateScript:
	var campaign: CampaignState = current_campaign()
	return campaign.stronghold if campaign != null else null


func current_stronghold_connectivity() -> Dictionary:
	if stronghold_connectivity_service == null:
		return {}
	return stronghold_connectivity_service.build_snapshot(
		current_stronghold_definition(),
		current_stronghold_state()
	)


func current_stronghold_build_catalogue() -> Array[StrongholdFacilityDefinitionScript]:
	var result: Array[StrongholdFacilityDefinitionScript] = []
	if stronghold_construction_service == null:
		return result
	return stronghold_construction_service.build_catalogue(current_stronghold_definition())


func preview_stronghold_build(
	facility_definition_id: StringName,
	origin: Vector2i
) -> OperationResult:
	if stronghold_construction_service == null:
		return OperationResult.fail(&"stronghold_construction_unavailable", "Stronghold construction is unavailable.")
	return stronghold_construction_service.preview_build(
		current_stronghold_definition(),
		current_stronghold_state(),
		facility_definition_id,
		origin
	)


func construct_stronghold_facility(
	facility_definition_id: StringName,
	origin: Vector2i
) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	var definition: StrongholdDefinitionScript = current_stronghold_definition()
	if campaign == null or definition == null or stronghold_construction_service == null:
		return OperationResult.fail(&"stronghold_missing", "Stronghold construction is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"stronghold_facility_construction_started", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return stronghold_construction_service.construct_candidate(
				definition,
				candidate.stronghold,
				facility_definition_id,
				origin,
				candidate.campaign_tick
			)
	)
	var committed: OperationResult = state_store.commit(changes)
	if not committed.success:
		return committed
	var built_plot = current_stronghold_state().get_plot(origin)
	var built_instance_id: StringName = built_plot.facility_id if built_plot != null else &""
	var built_facility = current_stronghold_state().get_facility(built_instance_id)
	var project = (
		current_stronghold_state().get_project(built_facility.active_project_id)
		if built_facility != null
		else null
	)
	return OperationResult.committed(
		{
			"facility_instance_id": built_instance_id,
			"project_id": project.project_id if project != null else &"",
			"completion_tick": project.completion_tick if project != null else campaign.campaign_tick,
		},
		"Facility construction started.",
		current_campaign().revision
	)


func upgrade_stronghold_facility(facility_instance_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	var definition: StrongholdDefinitionScript = current_stronghold_definition()
	if campaign == null or definition == null or stronghold_construction_service == null:
		return OperationResult.fail(&"stronghold_missing", "Stronghold upgrading is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"stronghold_facility_upgrade_started", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return stronghold_construction_service.upgrade_candidate(
				definition,
				candidate.stronghold,
				facility_instance_id,
				candidate.campaign_tick
			)
	)
	return state_store.commit(changes)


func cancel_stronghold_project(project_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	var definition: StrongholdDefinitionScript = current_stronghold_definition()
	if campaign == null or definition == null or stronghold_construction_service == null:
		return OperationResult.fail(&"stronghold_missing", "Stronghold project cancellation is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"stronghold_project_cancelled", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			return stronghold_construction_service.cancel_project_candidate(
				definition,
				candidate.stronghold,
				project_id
			)
	)
	return state_store.commit(changes)


func demolish_stronghold_facility(facility_instance_id: StringName) -> OperationResult:
	var campaign: CampaignState = current_campaign()
	var definition: StrongholdDefinitionScript = current_stronghold_definition()
	if campaign == null or definition == null or stronghold_construction_service == null:
		return OperationResult.fail(&"stronghold_missing", "Stronghold demolition is unavailable.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"stronghold_facility_demolished", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			if prison_capacity_service != null:
				var prison_guard: OperationResult = prison_capacity_service.can_remove_prison_facility(
					candidate, facility_instance_id
				)
				if not prison_guard.success:
					return prison_guard
			return stronghold_construction_service.demolish_candidate(
				definition, candidate.stronghold, facility_instance_id
			)
	)
	return state_store.commit(changes)


func register_mission_and_create_session(
		mission_instance_id: StringName,
		selected_character_ids: Array[StringName]
) -> OperationResult:
	pause_clock()
	return mission_coordinator.register_and_create_session(
		mission_instance_id,
		selected_character_ids
	)


func restart_registered_mission(mission_instance_id: StringName = &"") -> OperationResult:
	pause_clock()
	return mission_coordinator.restart_registered_mission(mission_instance_id)


func commit_tactical_envelope(envelope: MissionCommitEnvelope) -> OperationResult:
	pause_clock()
	var result: OperationResult = mission_coordinator.commit_tactical_envelope(envelope)
	if not result.success:
		return result
	var capacity: Dictionary = storage_capacity_snapshot()
	if bool(capacity.get("is_over_capacity", false)):
		result.message += (
			" Recovered objects exceeded Storage Capacity. No items were lost. "
			+ "Resolve the excess before acquiring additional stored objects."
		)
	return result


func latest_mission_result() -> MissionResult:
	var campaign: CampaignState = current_campaign()
	if campaign == null or campaign.latest_committed_result_id.is_empty():
		return null
	for raw_entry: Variant in campaign.mission_history_by_id.values():
		if not raw_entry is Dictionary:
			continue
		var result := MissionResult.from_dictionary(raw_entry as Dictionary)
		if result.result_id == campaign.latest_committed_result_id:
			return result
	return null


func _validate_stronghold_state(campaign: CampaignState) -> Array[String]:
	if campaign == null or stronghold_registry == null or stronghold_connectivity_service == null:
		return ["Stronghold services are unavailable."]
	var definition_value: StrongholdDefinitionScript = (
		stronghold_registry.definition(campaign.stronghold.definition_id)
		if campaign.stronghold != null
		else null
	)
	return stronghold_connectivity_service.validate_state(
		definition_value,
		campaign.stronghold
	)


func _ensure_stage_52a_state(campaign: CampaignState) -> bool:
	if campaign == null or stronghold_registry == null:
		return false
	return stronghold_registry.ensure_campaign_state(campaign)


func _ensure_stage_51d_state(campaign: CampaignState) -> bool:
	if campaign == null:
		return false
	var changed: bool = false
	var region: RegionMapDefinition = (
		region_registry.definition(campaign.current_region_id)
		if region_registry != null
		else null
	)
	if region != null and subregion_notoriety_service != null:
		if subregion_notoriety_service.ensure_region_states(campaign, region):
			changed = true
	if mission_lifecycle_service != null:
		for mission: ActiveMissionState in campaign.get_active_missions():
			if mission.is_available() and mission.expiry_tick < 0:
				mission_lifecycle_service.configure_new_mission(
					mission,
					campaign,
					mission.discovering_agent_id
				)
				changed = true
	return changed


func _bind_campaign(campaign: CampaignState) -> void:
	_ensure_stage_51d_state(campaign)
	TroopCareerMigration.migrate(campaign, catalogue)
	if henchman_recruitment_service != null:
		henchman_recruitment_service.ensure_market_candidate(campaign)
	if workforce_service != null:
		workforce_service.ensure_market_candidate(campaign)
	if strategic_recovery_service != null:
		strategic_recovery_service.ensure_campaign_health(campaign)
	if squad_transport_service != null:
		squad_transport_service.ensure_campaign_transport_state(campaign)
	if squad_management_service != null:
		squad_management_service.ensure_campaign_squads(campaign)
	if stable_bay_service != null:
		stable_bay_service.ensure_campaign_bays(campaign)
		stable_bay_service.ensure_starting_assignment(campaign)
	if strategic_reservation_service != null:
		strategic_reservation_service.ensure_deployment_reservations(campaign)
	state_store.configure(campaign, repository, catalogue)
	_clock_state_dirty = false
	_clock_autosave_elapsed = 0.0
	_last_persisted_campaign_tick = campaign.campaign_tick if campaign != null else 0
	if not state_store.state_changed.is_connected(_on_state_changed):
		state_store.state_changed.connect(_on_state_changed)
	mission_coordinator.configure(
		state_store,
		repository,
		catalogue,
		strategic_reservation_service,
		squad_transport_service,
		stable_bay_service
	)
	pause_clock()


func _flush_clock_state(reason: StringName) -> OperationResult:
	if not _clock_state_dirty:
		return OperationResult.new(true, &"no_change", "No deferred campaign clock state required persistence.")
	var result: OperationResult = state_store.persist_current(reason)
	if result.success:
		_mark_clock_state_persisted()
	return result


func _mark_clock_state_persisted() -> void:
	_clock_state_dirty = false
	_clock_autosave_elapsed = 0.0
	var campaign: CampaignState = current_campaign()
	_last_persisted_campaign_tick = campaign.campaign_tick if campaign != null else 0


func _on_state_changed(reason: StringName) -> void:
	campaign_changed.emit(reason)


func _name_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result
