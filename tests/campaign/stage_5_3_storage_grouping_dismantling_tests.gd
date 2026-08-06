class_name Stage53StorageGroupingDismantlingTests
extends RefCounted

const ReservationServiceScript = preload(
	"res://application/inventory/strategic_reservation_service.gd"
)
const QueryServiceScript = preload(
	"res://application/inventory/strategic_storage_query_service.gd"
)
const DismantlingServiceScript = preload(
	"res://application/inventory/dismantling_service.gd"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_group_counts_are_mutually_exclusive(failures)
	_test_exact_dismantling_conserves_identity_and_resources(failures)
	_test_reserved_item_rejects_dismantling(failures)
	return failures


static func _test_group_counts_are_mutually_exclusive(
		failures: Array[String]
) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	var query = context["query"]
	var groups: Array[Dictionary] = query.build_groups(campaign)
	var mace_group: Dictionary = {}
	for group: Dictionary in groups:
		if StringName(group.get("definition_id", &"")) == &"item.mace":
			mace_group = group
			break
	_expect(not mace_group.is_empty(), "The Mace group must exist.", failures)
	_expect(int(mace_group.get("total_count", 0)) == 2, "The Mace group must count both exact items.", failures)
	_expect(int(mace_group.get("available_count", 0)) == 1, "One Mace must be available.", failures)
	_expect(int(mace_group.get("assigned_count", 0)) == 0, "The reserved carried Mace must not also count as assigned.", failures)
	_expect(int(mace_group.get("reserved_count", 0)) == 1, "One exact Mace must count as reserved.", failures)
	_expect(
		int(mace_group.get("total_count", 0))
		== int(mace_group.get("available_count", 0))
		+ int(mace_group.get("assigned_count", 0))
		+ int(mace_group.get("reserved_count", 0)),
		"Storage presentation counts must be mutually exclusive.",
		failures
	)


static func _test_exact_dismantling_conserves_identity_and_resources(
		failures: Array[String]
) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	var service = context["dismantling"]
	var metal_before: int = campaign.resources.metal
	var wood_before: int = campaign.resources.wood
	var result: OperationResult = service.dismantle_candidate(
		campaign,
		&"instance.storage.mace"
	)
	_expect(result.success, "An available exact Mace must dismantle.", failures)
	_expect(campaign.get_item(&"instance.storage.mace") == null, "Dismantling must consume the exact item.", failures)
	_expect(campaign.resources.metal == metal_before + 3, "Mace dismantling must grant 3 Metal.", failures)
	_expect(campaign.resources.wood == wood_before + 1, "Mace dismantling must grant 1 Wood.", failures)
	var repeated: OperationResult = service.dismantle_candidate(
		campaign,
		&"instance.storage.mace"
	)
	_expect(not repeated.success, "The same exact item cannot dismantle twice.", failures)
	_expect(campaign.resources.metal == metal_before + 3, "Repeated dismantling must not duplicate Metal.", failures)
	_expect(campaign.resources.wood == wood_before + 1, "Repeated dismantling must not duplicate Wood.", failures)


static func _test_reserved_item_rejects_dismantling(
		failures: Array[String]
) -> void:
	var context: Dictionary = _build_context()
	var campaign: CampaignState = context["campaign"] as CampaignState
	var service = context["dismantling"]
	var result: OperationResult = service.preview_dismantle(
		campaign,
		&"instance.deployed.mace"
	)
	_expect(not result.success, "Reserved deployment equipment must not dismantle.", failures)
	_expect(campaign.get_item(&"instance.deployed.mace") != null, "Rejected dismantling must retain the exact item.", failures)


static func _build_context() -> Dictionary:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var reservation = ReservationServiceScript.new()
	var inventory := InventoryService.new()
	inventory.configure(reservation)
	var dismantling = DismantlingServiceScript.new()
	dismantling.configure(catalogue, inventory, reservation)
	var query = QueryServiceScript.new()
	query.configure(catalogue, reservation)
	var campaign := CampaignState.new()
	campaign.resources = CampaignResourceBalances.new()
	var character := PersistentCharacterState.new()
	character.character_id = &"character.storage.test"
	character.template_id = &"character_template.reaver.marauder_tier_1"
	character.display_name = "Hakon Test"
	character.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
	character.roster_role = PersistentCharacterState.ROLE_PLAYER
	campaign.add_character(character)
	var available := CampaignItemState.new(
		&"instance.storage.mace",
		&"item.mace",
		1,
		1.0,
		CampaignItemLocationState.stronghold_storage()
	)
	campaign.add_item(available)
	var deployed := CampaignItemState.new(
		&"instance.deployed.mace",
		&"item.mace",
		1,
		1.0,
		CampaignItemLocationState.character_slot(
			character.character_id,
			CampaignItemLocationState.CONTAINER_PRIMARY_HAND
		)
	)
	campaign.add_item(deployed)
	reservation.reserve_deployment_candidate(
		campaign,
		&"reservation.storage.test",
		&"operation.storage.test",
		&"mission.storage.test",
		"Farm Raid",
		[character.character_id],
		[deployed.item_id]
	)
	return {
		"campaign": campaign,
		"query": query,
		"dismantling": dismantling,
	}


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
