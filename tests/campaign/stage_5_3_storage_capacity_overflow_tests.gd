class_name Stage53StorageCapacityOverflowTests
extends RefCounted

const StrongholdDefinitionRegistryScript = preload(
	"res://application/stronghold/stronghold_definition_registry.gd"
)
const DismantlingServiceScript = preload(
	"res://application/inventory/dismantling_service.gd"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_location_and_bundle_derived_usage(failures)
	_test_facility_state_capacity(failures)
	_test_optional_intake_and_mandatory_overflow(failures)
	_test_dismantling_previews_released_space(failures)
	return failures


static func _test_location_and_bundle_derived_usage(
		failures: Array[String]
) -> void:
	var context: Dictionary = _build_context()
	var inventory: InventoryService = context["inventory"] as InventoryService
	var campaign: CampaignState = context["campaign"] as CampaignState
	var snapshot: Dictionary = inventory.storage_capacity_snapshot(campaign)
	_expect(int(snapshot.get("maximum", 0)) == 100, "The Heart must provide 100 starting capacity.", failures)
	_expect(int(snapshot.get("used", 0)) == 8, "Stored Mace, Grain Crate and 21-arrow bundle must use 8 space.", failures)
	_expect(int(snapshot.get("free", 0)) == 92, "Initial test storage must have 92 free space.", failures)
	_expect(
		inventory.storage_space_for_item(campaign.get_item(&"item.test.arrows")) == 2,
		"Twenty-one arrows must occupy two authored bundles.",
		failures
	)
	_expect(
		inventory.storage_space_for_item(campaign.get_item(&"item.test.assigned_spear")) == 3,
		"An assigned spear retains a three-space return requirement.",
		failures
	)
	_expect(
		int(snapshot.get("used", 0))
		< inventory.storage_space_for_item(campaign.get_item(&"item.test.assigned_spear")) + 8,
		"Assigned equipment must not be included in used Stronghold Storage capacity.",
		failures
	)


static func _test_facility_state_capacity(failures: Array[String]) -> void:
	var context: Dictionary = _build_context()
	var inventory: InventoryService = context["inventory"] as InventoryService
	var campaign: CampaignState = context["campaign"] as CampaignState
	var storehouse := StrongholdFacilityState.new()
	storehouse.instance_id = &"facility.storehouse.test"
	storehouse.definition_id = &"facility.storehouse"
	storehouse.level = 1
	storehouse.condition = StrongholdFacilityState.CONDITION_OPERATIONAL
	campaign.stronghold.facilities_by_id[storehouse.instance_id] = storehouse
	_expect(inventory.maximum_storage_space(campaign) == 180, "Heart plus Level I Storehouse must provide 180 capacity.", failures)
	storehouse.condition = StrongholdFacilityState.CONDITION_DAMAGED
	_expect(inventory.maximum_storage_space(campaign) == 140, "A damaged Level I Storehouse must contribute half capacity.", failures)
	storehouse.condition = StrongholdFacilityState.CONDITION_UPGRADING
	_expect(inventory.maximum_storage_space(campaign) == 180, "An upgrading Storehouse must retain its completed level capacity.", failures)
	storehouse.level = 2
	storehouse.condition = StrongholdFacilityState.CONDITION_OPERATIONAL
	_expect(inventory.maximum_storage_space(campaign) == 240, "Heart plus Level II Storehouse must provide 240 capacity.", failures)
	storehouse.condition = StrongholdFacilityState.CONDITION_UNDER_CONSTRUCTION
	_expect(inventory.maximum_storage_space(campaign) == 100, "A Storehouse under construction must contribute zero.", failures)
	storehouse.condition = StrongholdFacilityState.CONDITION_DISABLED
	_expect(inventory.maximum_storage_space(campaign) == 100, "A disabled Storehouse must contribute zero.", failures)


static func _test_optional_intake_and_mandatory_overflow(
		failures: Array[String]
) -> void:
	var context: Dictionary = _build_context()
	var inventory: InventoryService = context["inventory"] as InventoryService
	var campaign: CampaignState = context["campaign"] as CampaignState
	campaign.add_item(CampaignItemState.new(
		&"item.test.table.stored",
		&"item.storehouse_table",
		1,
		1.0,
		CampaignItemLocationState.stronghold_storage()
	))
	campaign.add_item(CampaignItemState.new(
		&"item.test.crate.stored.two",
		&"item.grain_crate",
		1,
		1.0,
		CampaignItemLocationState.stronghold_storage()
	))
	# Fill the expanded starting vaults to 98 / 100 so the same intake case
	# still verifies a capacity-required rejection and mandatory overflow.
	for index: int in range(20):
		campaign.add_item(CampaignItemState.new(
			StringName("item.test.capacity.filler.%02d" % index),
			&"item.grain_crate",
			1,
			1.0,
			CampaignItemLocationState.stronghold_storage()
		))
	var incoming := CampaignItemState.new(
		&"item.test.table.incoming",
		&"item.storehouse_table",
		1,
		1.0,
		CampaignItemLocationState.character_slot(
			&"character.storage.capacity",
			CampaignItemLocationState.CONTAINER_BACKPACK
		)
	)
	campaign.add_item(incoming)
	var intake_ids: Array[StringName] = [incoming.item_id]
	var rejected: OperationResult = inventory.validate_storage_intake(
		campaign,
		intake_ids,
		InventoryService.INTAKE_REQUIRE_CAPACITY
	)
	_expect(not rejected.success, "Optional intake must reject a six-space table when only two space remains.", failures)
	var accepted: OperationResult = inventory.move_item_to_stronghold_candidate(
		campaign,
		incoming.item_id,
		CampaignItemLocationState.DEFAULT_STRONGHOLD_STORAGE_ID,
		InventoryService.INTAKE_ALLOW_OVERFLOW
	)
	_expect(accepted.success, "Mandatory intake must be allowed to create overflow.", failures)
	var snapshot: Dictionary = inventory.storage_capacity_snapshot(campaign)
	_expect(int(snapshot.get("used", 0)) == 104, "Mandatory intake must preserve the exact item and derive 104 used space.", failures)
	_expect(int(snapshot.get("overflow", 0)) == 4, "Mandatory intake must expose four space of overflow.", failures)
	_expect(campaign.get_item(incoming.item_id) != null, "Overflow must never delete the incoming exact item.", failures)


static func _test_dismantling_previews_released_space(
		failures: Array[String]
) -> void:
	var context: Dictionary = _build_context()
	var inventory: InventoryService = context["inventory"] as InventoryService
	var campaign: CampaignState = context["campaign"] as CampaignState
	var catalogue: ContentCatalogue = context["catalogue"] as ContentCatalogue
	var dismantling = DismantlingServiceScript.new()
	dismantling.configure(catalogue, inventory)
	var before: Dictionary = inventory.storage_capacity_snapshot(campaign)
	var preview: OperationResult = dismantling.preview_dismantle(
		campaign,
		&"item.test.crate"
	)
	_expect(preview.success, "A stored Grain Crate must have a dismantling preview.", failures)
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	_expect(int(data.get("storage_space_released", 0)) == 4, "Grain Crate dismantling must preview four released Storage Space.", failures)
	_expect(
		int(data.get("storage_used_after", -1)) == int(before.get("used", 0)) - 4,
		"Dismantling preview must derive storage after exact-item consumption.",
		failures
	)


static func _build_context() -> Dictionary:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var registry = StrongholdDefinitionRegistryScript.new()
	registry.configure()
	var inventory := InventoryService.new()
	inventory.configure(null, catalogue, registry)
	var campaign := CampaignState.new()
	campaign.resources = CampaignResourceBalances.new()
	campaign.stronghold = registry.create_initial_state()
	var character := PersistentCharacterState.new()
	character.character_id = &"character.storage.capacity"
	character.template_id = &"character_template.reaver.marauder_tier_1"
	character.display_name = "Capacity Tester"
	character.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
	character.roster_role = PersistentCharacterState.ROLE_PLAYER
	campaign.add_character(character)
	campaign.add_item(CampaignItemState.new(
		&"item.test.mace",
		&"item.mace",
		1,
		1.0,
		CampaignItemLocationState.stronghold_storage()
	))
	campaign.add_item(CampaignItemState.new(
		&"item.test.crate",
		&"item.grain_crate",
		1,
		1.0,
		CampaignItemLocationState.stronghold_storage()
	))
	campaign.add_item(CampaignItemState.new(
		&"item.test.arrows",
		&"item.sanctuary.padded_arrows",
		21,
		1.0,
		CampaignItemLocationState.stronghold_storage()
	))
	campaign.add_item(CampaignItemState.new(
		&"item.test.assigned_spear",
		&"item.training_spear",
		1,
		1.0,
		CampaignItemLocationState.character_slot(
			character.character_id,
			CampaignItemLocationState.CONTAINER_PRIMARY_HAND
		)
	))
	return {
		"catalogue": catalogue,
		"registry": registry,
		"inventory": inventory,
		"campaign": campaign,
	}


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
