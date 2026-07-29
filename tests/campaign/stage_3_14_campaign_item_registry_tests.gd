class_name Stage314CampaignItemRegistryTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_campaign_owns_all_persistent_items(failures)
	_test_equipment_is_derived_from_locations(failures)
	_test_stronghold_and_loadout_share_registry(failures)
	_test_stage_3_12_save_migration(failures)
	return failures


static func _test_campaign_owns_all_persistent_items(
		failures: Array[String]
) -> void:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var template: CharacterTemplateDefinition = catalogue.character_template(
		TacticalSandboxFactory.MARAUDER_TEMPLATE_ID
	)
	var character: PersistentCharacterState = CharacterFactory.create_player_character(
		template,
		&"character.test.registry_owner",
		"Registry Marauder"
	)
	var campaign: CampaignState = CampaignState.new()
	campaign.add_character(character)
	CharacterFactory.add_default_loadout_to_campaign(campaign, character, template)
	_expect(not campaign.items_by_id.is_empty(), "CampaignState must own generated items.", failures)
	_expect(not character.to_dictionary().has("loadout_entries"), "Characters must not serialize duplicate item data.", failures)


static func _test_equipment_is_derived_from_locations(
		failures: Array[String]
) -> void:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var template: CharacterTemplateDefinition = catalogue.character_template(
		TacticalSandboxFactory.MARAUDER_TEMPLATE_ID
	)
	var character: PersistentCharacterState = CharacterFactory.create_player_character(
		template,
		&"character.test.location_owner",
		"Location Marauder"
	)
	var campaign: CampaignState = CampaignState.new()
	campaign.add_character(character)
	CharacterFactory.add_default_loadout_to_campaign(campaign, character, template)

	var resolver: CharacterResolutionService = CharacterResolutionService.new(catalogue)
	var equipped_snapshot: ResolvedCharacterSnapshot = resolver.resolve_character(
		character,
		[],
		campaign.items_for_character(character.character_id)
	)
	_expect(
		equipped_snapshot.granted_action_ids.has(&"action.raiders_axe_attack"),
		"Resolved equipment actions must come from character-owned campaign items.",
		failures
	)

	var axe_item: CampaignItemState = null
	for item: CampaignItemState in campaign.items_for_character(character.character_id):
		if item.definition_id == &"item.raiders_axe":
			axe_item = item
			break
	_expect(axe_item != null, "The test Marauder must own an axe item.", failures)
	if axe_item == null:
		return

	campaign.move_item_to_stronghold(axe_item.item_id)
	var stored_snapshot: ResolvedCharacterSnapshot = resolver.resolve_character(
		character,
		[],
		campaign.items_for_character(character.character_id)
	)
	_expect(
		not stored_snapshot.granted_action_ids.has(&"action.raiders_axe_attack"),
		"Moving an item to stronghold storage must immediately remove its derived action.",
		failures
	)


static func _test_stronghold_and_loadout_share_registry(
		failures: Array[String]
) -> void:
	var campaign: CampaignState = CampaignState.new()
	var character: PersistentCharacterState = PersistentCharacterState.new()
	character.character_id = &"character.test.shared_registry"
	character.template_id = &"character_template.test"
	character.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
	campaign.add_character(character)
	var item: CampaignItemState = CampaignItemState.new(
		&"item.test.shared_registry",
		&"item.rope",
		1,
		0.8,
		CampaignItemLocationState.stronghold_storage()
	)
	campaign.add_item(item)
	_expect(campaign.items_in_stronghold().has(item), "Stronghold storage must use CampaignState.items_by_id.", failures)
	campaign.assign_item_to_character(
		item.item_id,
		character.character_id,
		TacticalInventoryState.KIND_BELT,
		Vector2i.ZERO
	)
	_expect(campaign.items_for_character(character.character_id).has(item), "The same item instance must move into a character loadout.", failures)
	_expect(campaign.get_item(item.item_id) == item, "Storage transfer must not replace item identity.", failures)


static func _test_stage_3_12_save_migration(
		failures: Array[String]
) -> void:
	var legacy_character: Dictionary = {
		"character_id": "character.test.legacy",
		"template_id": "character_template.reaver.marauder_tier_1",
		"display_name": "Legacy Marauder",
		"faction_id": "faction.fifth_god",
		"team_id": "player",
		"roster_role": "player",
		"persistence_scope": "campaign",
		"loadout_entries": [
			{
				"instance_id": "legacy.axe",
				"definition_id": "item.raiders_axe",
				"container_kind": "main_hand",
				"grid_position": [0, 0],
				"quantity": 1,
				"condition": 0.75,
			},
		],
	}
	var legacy_save: Dictionary = {
		"save_version": 2,
		"revision": 7,
		"characters": [legacy_character],
		"campaign_loot_entries": [
			{
				"instance_id": "legacy.loot.rope",
				"definition_id": "item.rope",
				"container_kind": "backpack",
				"grid_position": [2, 1],
				"quantity": 1,
				"condition": 1.0,
			},
		],
	}
	var migrated: CampaignState = CampaignState.from_dictionary(legacy_save)
	var character: PersistentCharacterState = migrated.get_character(
		&"character.test.legacy"
	)
	_expect(migrated.save_version == CampaignState.CURRENT_SAVE_VERSION, "Legacy saves must migrate to the current schema.", failures)
	_expect(character != null, "Legacy characters must survive migration.", failures)
	_expect(migrated.items_for_character(&"character.test.legacy").size() == 1, "Legacy loadout entries must become campaign items.", failures)
	_expect(migrated.items_in_stronghold().size() == 1, "Legacy campaign loot must become stronghold storage items.", failures)
	if character != null:
		_expect(not character.to_dictionary().has("loadout_entries"), "Migrated characters must not retain duplicate item records.", failures)
	var serialized: Dictionary = migrated.to_dictionary()
	_expect(not serialized.has("campaign_loot_entries"), "Migrated saves must not retain a parallel loot list.", failures)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
