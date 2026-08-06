class_name Stage317CombatFoundationTests
extends RefCounted


class RecordingRepository:
	extends RefCounted

	var saved_campaign: CampaignState
	var should_save: bool = true

	func save_campaign(candidate: CampaignState) -> bool:
		if not should_save:
			return false
		saved_campaign = CampaignState.from_dictionary(candidate.to_dictionary())
		return true


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_campaign_candidate_commit(failures)
	_test_finalized_setup_rejects_mutation(failures)
	_test_equipment_instances_drive_armour_class(failures)
	return failures


static func _test_campaign_candidate_commit(failures: Array[String]) -> void:
	var campaign: CampaignState = CampaignState.new()
	var original_revision: int = campaign.revision
	var repository: RecordingRepository = RecordingRepository.new()
	var store: CampaignStateStore = CampaignStateStore.new()
	store.configure(campaign, repository, null)
	var changes: CampaignChangeSet = CampaignChangeSet.new()
	changes.configure(&"test_campaign_commit", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> bool:
			var character: PersistentCharacterState = PersistentCharacterState.new()
			character.character_id = &"character.test.stage317"
			character.template_id = TacticalSandboxFactory.MARAUDER_TEMPLATE_ID
			character.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
			return candidate.add_character(character)
	)
	var committed: OperationResult = store.commit(changes)
	_expect(committed.success, "Campaign candidate must commit.", failures)
	_expect(campaign.get_character(&"character.test.stage317") == null, "Live root must not mutate before replacement.", failures)
	_expect(store.current_campaign() != campaign, "CampaignStateStore must replace the root.", failures)
	_expect(store.current_campaign().revision == original_revision + 1, "Campaign commit must increment revision once.", failures)
	_expect(repository.saved_campaign != null, "Candidate must save before root replacement.", failures)


static func _test_finalized_setup_rejects_mutation(failures: Array[String]) -> void:
	var campaign: CampaignState = CampaignState.new()
	var character: PersistentCharacterState = PersistentCharacterState.new()
	character.character_id = &"character.test.finalized"
	character.template_id = TacticalSandboxFactory.MARAUDER_TEMPLATE_ID
	character.team_id = &"player"
	character.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
	campaign.add_character(character)
	var setup: MissionSetupSnapshot = MissionSetupBuilder.create_from_campaign(
		campaign,
		[character.character_id],
		&"mission.test.finalized"
	)
	setup.mark_deployed(character.character_id)
	var finalized: OperationResult = MissionSetupBuilder.finalize_setup(setup)
	_expect(finalized.success and setup.is_finalized(), "Mission setup must finalize.", failures)
	_expect(not setup.add_character_copy(character), "Finalized setup must reject characters.", failures)
	_expect(setup.add_ground_item(&"late.item", &"item.bandage", Vector2i.ZERO).is_empty(), "Finalized setup must reject items.", failures)
	var returned: PersistentCharacterState = setup.get_character(character.character_id)
	returned.display_name = "Mutated copy"
	_expect(setup.get_character(character.character_id).display_name != "Mutated copy", "Finalized setup getters must not expose mutable authority.", failures)


static func _test_equipment_instances_drive_armour_class(failures: Array[String]) -> void:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var template: CharacterTemplateDefinition = catalogue.character_template(
		TacticalSandboxFactory.MARAUDER_TEMPLATE_ID
	)
	var character: PersistentCharacterState = CharacterFactory.create_player_character(
		template,
		&"character.test.equipment",
		"Equipment Marauder"
	)
	var buckler: CampaignItemState = CampaignItemState.new(
		&"instance.test.buckler",
		&"item.buckler",
		1,
		0.75,
		CampaignItemLocationState.character_slot(
			character.character_id,
			CampaignItemLocationState.CONTAINER_SECONDARY_HAND
		),
		{"armour_class": 1}
	)
	var resolver: CharacterResolutionService = CharacterResolutionService.new()
	resolver.configure(catalogue)
	var equipped: ResolvedCharacterSnapshot = resolver.resolve_character(
		character,
		[],
		[buckler]
	)
	_expect(equipped.stat_value(&"armour_class") == 16, "Equipped buckler instance and modifier must raise AC 14 to 16.", failures)
	_expect(equipped.equipped_item_ids.has(buckler.item_id), "Resolved snapshot must preserve equipped item identity.", failures)
	buckler.set_location(
		CampaignItemLocationState.character_slot(
			character.character_id,
			CampaignItemLocationState.CONTAINER_BACKPACK,
			Vector2i.ZERO
		)
	)
	var stowed: ResolvedCharacterSnapshot = resolver.resolve_character(
		character,
		[],
		[buckler]
	)
	_expect(stowed.stat_value(&"armour_class") == 14, "Stowed defensive items must not modify AC.", failures)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
