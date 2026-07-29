class_name Stage313MissionOwnershipTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_setup_snapshot_is_isolated(failures)
	_test_tactical_inventory_does_not_mutate_campaign(failures)
	_test_mission_result_records_outcomes(failures)
	_test_campaign_result_commits_exactly_once(failures)
	_test_deployment_is_atomic(failures)
	_test_ground_item_ids_avoid_character_item_collisions(failures)
	return failures


static func _campaign_fixture(character_id: StringName) -> Dictionary:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var template: CharacterTemplateDefinition = catalogue.character_template(
		TacticalSandboxFactory.MARAUDER_TEMPLATE_ID
	)
	var character: PersistentCharacterState = CharacterFactory.create_player_character(
		template,
		character_id,
		"Campaign Marauder"
	)
	var campaign: CampaignState = CampaignState.new()
	campaign.add_character(character)
	CharacterFactory.add_default_loadout_to_campaign(
		campaign,
		character,
		template
	)
	return {
		"catalogue": catalogue,
		"template": template,
		"character": character,
		"campaign": campaign,
	}


static func _test_setup_snapshot_is_isolated(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _campaign_fixture(&"character.test.setup_isolation")
	var campaign: CampaignState = fixture.get("campaign") as CampaignState
	var campaign_character: PersistentCharacterState = (
		fixture.get("character") as PersistentCharacterState
	)
	var ids: Array[StringName] = [campaign_character.character_id]
	var setup: MissionSetupSnapshot = MissionSetupBuilder.create_from_campaign(
		campaign,
		ids,
		&"mission.test.setup_isolation"
	)
	setup.mark_deployed(campaign_character.character_id)
	MissionSetupBuilder.finalize_setup(setup)
	var mission_character: PersistentCharacterState = setup.get_character(
		campaign_character.character_id
	)
	var mission_items: Array[CampaignItemState] = setup.items_for_character(
		campaign_character.character_id
	)
	_expect(mission_character != campaign_character, "Mission setup must clone campaign characters.", failures)
	_expect(not mission_items.is_empty(), "Mission setup must clone campaign-owned equipment.", failures)
	mission_character.award_xp(100)
	mission_items[0].condition = 0.25
	_expect(campaign_character.xp == 0, "Mission XP changes must not touch campaign state.", failures)
	_expect(campaign.items_for_character(campaign_character.character_id)[0].condition == 1.0, "Mission item changes must not touch campaign items.", failures)


static func _test_tactical_inventory_does_not_mutate_campaign(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _campaign_fixture(&"character.test.inventory_isolation")
	var catalogue: ContentCatalogue = fixture.get("catalogue") as ContentCatalogue
	var campaign: CampaignState = fixture.get("campaign") as CampaignState
	var character: PersistentCharacterState = fixture.get("character") as PersistentCharacterState
	var setup: MissionSetupSnapshot = MissionSetupBuilder.create_from_campaign(
		campaign,
		[character.character_id],
		&"mission.test.inventory_isolation"
	)
	setup.mark_deployed(character.character_id)
	MissionSetupBuilder.finalize_setup(setup)
	var state: TacticalState = TacticalState.new()
	var resolution_service: CharacterResolutionService = CharacterResolutionService.new()
	resolution_service.configure(catalogue)
	var unit: TacticalUnitState = TacticalCharacterDeploymentService.new(
		catalogue,
		resolution_service
	).deploy_character(
		state,
		setup.get_character(character.character_id),
		Vector2i(10, 10),
		TacticalSandboxFactory.MOVEMENT_TEST_MAP,
		[],
		setup.items_for_character(character.character_id)
	)
	_expect(unit != null, "Inventory-isolation fixture must deploy.", failures)
	if unit == null:
		return
	var original_campaign_item_count: int = campaign.get_items().size()
	var ground_item: TacticalItemInstanceState = TacticalItemInstanceState.new(
		&"item.test.isolated_loot",
		catalogue.item_definition(&"item.bandage"),
		1,
		1.0,
		TacticalItemLocationState.ground(Vector2i(10, 11))
	)
	state.add_item(ground_item, TacticalSandboxFactory.MOVEMENT_TEST_MAP)
	var destination: Vector2i = state.first_fit(
		unit,
		ground_item,
		TacticalInventoryState.KIND_BACKPACK
	)
	state.move_item(
		ground_item.item_id,
		TacticalItemLocationState.unit_grid(
			unit.unit_id,
			TacticalInventoryState.KIND_BACKPACK,
			destination
		)
	)
	_expect(campaign.get_items().size() == original_campaign_item_count, "Tactical inventory transfers must not mutate the campaign registry.", failures)
	_expect(campaign.get_item(ground_item.item_id) == null, "Mission loot must not enter CampaignState before result commit.", failures)


static func _test_mission_result_records_outcomes(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _result_fixture()
	var result: MissionResult = fixture.get("result") as MissionResult
	_expect(result != null, "Mission-result fixture must be valid.", failures)
	if result == null:
		return
	var character_result: MissionCharacterResult = result.get_character_result(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_expect(character_result != null, "MissionResult must record the Marauder.", failures)
	if character_result == null:
		return
	_expect(character_result.survived, "MissionResult must record survival.", failures)
	_expect(character_result.extracted, "MissionResult must record extraction.", failures)
	_expect(character_result.xp_awarded == 125, "MissionResult must record XP.", failures)
	_expect(character_result.injury_entries.has("Bruised ribs"), "MissionResult must record injuries.", failures)
	_expect(not character_result.equipment_item_ids.is_empty(), "MissionResult must record final equipment IDs.", failures)
	_expect(character_result.loot_item_ids.has(&"instance.ground.spear"), "MissionResult must identify acquired loot.", failures)
	_expect(not result.extracted_item_entries.is_empty(), "MissionResult must carry extracted item snapshots.", failures)


static func _test_campaign_result_commits_exactly_once(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _result_fixture()
	var result: MissionResult = fixture.get("result") as MissionResult
	var campaign: CampaignState = fixture.get("campaign") as CampaignState
	var setup: MissionSetupSnapshot = fixture.get("setup") as MissionSetupSnapshot
	var catalogue: ContentCatalogue = fixture.get("catalogue") as ContentCatalogue
	if result == null or campaign == null or setup == null or catalogue == null:
		_expect(false, "Commit fixture must be valid.", failures)
		return
	var character: PersistentCharacterState = campaign.get_character(
		TacticalSandboxFactory.MARAUDER_ID
	)
	var starting_xp: int = character.xp
	var store: CampaignStateStore = CampaignStateStore.new()
	store.configure(campaign, null, catalogue)
	var service: CampaignResultCommitService = CampaignResultCommitService.new()
	service.configure(store, catalogue)
	var first: OperationResult = service.commit_result(result, setup)
	var committed_campaign: CampaignState = store.current_campaign()
	var committed_character: PersistentCharacterState = committed_campaign.get_character(
		TacticalSandboxFactory.MARAUDER_ID
	)
	var history_after_first: int = committed_character.history_entries.size()
	var second: OperationResult = service.commit_result(result, setup)
	_expect(first.success, "The first result commit must succeed.", failures)
	_expect(second.success and second.code == &"already_applied", "A repeated result must be a no-op.", failures)
	_expect(committed_character.xp == starting_xp + 125, "XP must be applied exactly once.", failures)
	_expect(committed_character.history_entries.size() == history_after_first, "History must be applied exactly once.", failures)
	_expect(committed_campaign.has_applied_result(result.result_id), "CampaignState must persist the result ID.", failures)
	var spear: CampaignItemState = committed_campaign.get_item(&"instance.ground.spear")
	_expect(spear != null, "Extracted carried loot must enter CampaignState.", failures)
	if spear != null:
		_expect(spear.location.belongs_to_character(committed_character.character_id), "Extracted carried loot must be assigned to its character.", failures)


static func _test_deployment_is_atomic(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _campaign_fixture(&"character.test.atomic_deployment")
	var catalogue: ContentCatalogue = fixture.get("catalogue") as ContentCatalogue
	var character: PersistentCharacterState = fixture.get("character") as PersistentCharacterState
	var campaign: CampaignState = fixture.get("campaign") as CampaignState
	var items: Array[CampaignItemState] = campaign.items_for_character(character.character_id)
	if items.size() >= 2:
		items[1].item_id = items[0].item_id
	var state: TacticalState = TacticalState.new()
	var resolution_service: CharacterResolutionService = CharacterResolutionService.new()
	resolution_service.configure(catalogue)
	var unit: TacticalUnitState = TacticalCharacterDeploymentService.new(
		catalogue,
		resolution_service
	).deploy_character(
		state,
		character,
		Vector2i(12, 12),
		TacticalSandboxFactory.MOVEMENT_TEST_MAP,
		[],
		items
	)
	_expect(unit == null, "Invalid deployment must fail.", failures)
	_expect(state.get_units().is_empty(), "Failed deployment must not leave a partial unit.", failures)
	_expect(state.get_items().is_empty(), "Failed deployment must not leave partial items.", failures)


static func _test_ground_item_ids_avoid_character_item_collisions(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _campaign_fixture(&"character.test.item_collision")
	var campaign: CampaignState = fixture.get("campaign") as CampaignState
	var character: PersistentCharacterState = fixture.get("character") as PersistentCharacterState
	var first_item: CampaignItemState = campaign.items_for_character(character.character_id)[0]
	first_item.item_id = &"instance.ground.spear"
	campaign.items_by_id.clear()
	campaign.items_by_id[first_item.item_id] = first_item
	var setup: MissionSetupSnapshot = MissionSetupBuilder.create_from_campaign(
		campaign,
		[character.character_id],
		&"mission.test.item_collision"
	)
	var ground_id: StringName = setup.add_ground_item(
		&"instance.ground.spear",
		&"item.training_spear",
		Vector2i(1, 1)
	)
	setup.mark_deployed(character.character_id)
	MissionSetupBuilder.finalize_setup(setup)
	_expect(ground_id != &"instance.ground.spear", "Ground-item IDs must avoid deployed item IDs.", failures)
	_expect(setup.validate_snapshot().is_empty(), "Collision-safe setup must validate.", failures)


static func _result_fixture() -> Dictionary:
	var fixture: Dictionary = _campaign_fixture(TacticalSandboxFactory.MARAUDER_ID)
	var catalogue: ContentCatalogue = fixture.get("catalogue") as ContentCatalogue
	var campaign: CampaignState = fixture.get("campaign") as CampaignState
	var character: PersistentCharacterState = fixture.get("character") as PersistentCharacterState
	var setup: MissionSetupSnapshot = MissionSetupBuilder.create_from_campaign(
		campaign,
		[character.character_id],
		&"mission.test.result"
	)
	setup.add_ground_item(
		&"instance.ground.spear",
		&"item.training_spear",
		Vector2i(10, 11)
	)
	setup.mark_deployed(character.character_id)
	MissionSetupBuilder.finalize_setup(setup)
	var state: TacticalState = TacticalState.new()
	var resolution_service: CharacterResolutionService = CharacterResolutionService.new()
	resolution_service.configure(catalogue)
	var unit: TacticalUnitState = TacticalCharacterDeploymentService.new(
		catalogue,
		resolution_service
	).deploy_character(
		state,
		setup.get_character(character.character_id),
		Vector2i(10, 10),
		TacticalSandboxFactory.MOVEMENT_TEST_MAP,
		[],
		setup.items_for_character(character.character_id)
	)
	if unit == null:
		return {}
	var ground_campaign_item: CampaignItemState = setup.get_item(
		&"instance.ground.spear"
	)
	var spear: TacticalItemInstanceState = TacticalItemInstanceState.new(
		ground_campaign_item.item_id,
		catalogue.item_definition(ground_campaign_item.definition_id),
		ground_campaign_item.quantity,
		ground_campaign_item.condition,
		TacticalItemLocationState.ground(Vector2i(10, 11))
	)
	if not state.add_item(spear, TacticalSandboxFactory.MOVEMENT_TEST_MAP):
		return {}
	var destination: Vector2i = state.first_fit(
		unit,
		spear,
		TacticalInventoryState.KIND_BACKPACK
	)
	if destination.x < 0:
		return {}
	state.move_item(
		spear.item_id,
		TacticalItemLocationState.unit_grid(
			unit.unit_id,
			TacticalInventoryState.KIND_BACKPACK,
			destination
		)
	)
	var session: TacticalSession = TacticalSession.new(
		state,
		TacticalSandboxFactory.MOVEMENT_TEST_MAP,
		setup.player_unit_order(),
		catalogue,
		setup,
		resolution_service
	)
	var xp: Dictionary = {}
	xp[character.character_id] = 125
	var injuries: Dictionary = {}
	injuries[character.character_id] = ["Bruised ribs"]
	var result: MissionResult = session.build_mission_result(
		&"result.test.result.0001",
		[character.character_id],
		xp,
		injuries
	)
	return {
		"session": session,
		"result": result,
		"campaign": campaign,
		"setup": setup,
		"catalogue": catalogue,
	}


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
