class_name Stage315IntegrityTests
extends RefCounted


class TransactionHarness:
	extends RefCounted

	var unit: TacticalUnitState
	var amount: int = 0

	func _init(unit_value: TacticalUnitState, amount_value: int) -> void:
		unit = unit_value
		amount = amount_value

	func apply() -> bool:
		unit.action_budget.spend_normal_capacity(amount)
		return true

	func rollback() -> void:
		unit.action_budget.remaining_turn_capacity_feet += amount
		unit.action_budget.normal_capacity_spent_feet -= amount

	func reject() -> String:
		return "Forced transaction validation failure."


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_mission_result_context_validation(failures)
	_test_campaign_revision_conflict(failures)
	_test_save_backup_and_corruption_guard(failures)
	_test_tactical_change_set_rolls_back(failures)
	return failures


static func _fixture() -> Dictionary:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var template: CharacterTemplateDefinition = catalogue.character_template(
		TacticalSandboxFactory.MARAUDER_TEMPLATE_ID
	)
	var character: PersistentCharacterState = CharacterFactory.create_player_character(
		template,
		&"character.test.stage315",
		"Stage 3.15 Marauder"
	)
	var campaign: CampaignState = CampaignState.new()
	campaign.add_character(character)
	CharacterFactory.add_default_loadout_to_campaign(
		campaign,
		character,
		template
	)
	var setup: MissionSetupSnapshot = MissionSetupBuilder.create_from_campaign(
		campaign,
		[character.character_id],
		&"mission.test.stage315"
	)
	setup.mark_deployed(character.character_id)
	MissionSetupBuilder.finalize_setup(setup)
	var state: TacticalState = TacticalState.new()
	var resolution_service: CharacterResolutionService = CharacterResolutionService.new()
	resolution_service.configure(catalogue)
	var deployment: TacticalCharacterDeploymentService = (
		TacticalCharacterDeploymentService.new(
			catalogue,
			resolution_service
		)
	)
	var unit: TacticalUnitState = deployment.deploy_character(
		state,
		setup.get_character(character.character_id),
		Vector2i(8, 8),
		TacticalSandboxFactory.MOVEMENT_TEST_MAP,
		[],
		setup.items_for_character(character.character_id)
	)
	var result: MissionResult = MissionResultBuilder.build_result(
		&"result.test.stage315",
		setup,
		state,
		[character.character_id],
		{},
		{},
		[],
		true
	)
	return {
		"catalogue": catalogue,
		"character": character,
		"campaign": campaign,
		"setup": setup,
		"state": state,
		"unit": unit,
		"result": result,
	}


static func _test_mission_result_context_validation(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _fixture()
	var result: MissionResult = fixture.get("result") as MissionResult
	var setup: MissionSetupSnapshot = fixture.get("setup") as MissionSetupSnapshot
	var campaign: CampaignState = fixture.get("campaign") as CampaignState
	var catalogue: ContentCatalogue = fixture.get("catalogue") as ContentCatalogue
	_expect(result != null, "Stage 3.15 result fixture must build.", failures)
	if result == null:
		return
	var valid_errors: Array[String] = MissionResultValidator.validate(
		result,
		setup,
		campaign,
		catalogue
	)
	_expect(valid_errors.is_empty(), "A valid mission result must pass contextual validation.", failures)

	result.extracted_item_entries.append(
		CampaignItemState.new(
			&"item.not.in.mission",
			&"item.rope",
			1,
			1.0,
			CampaignItemLocationState.stronghold_storage()
		).to_dictionary()
	)
	var invalid_errors: Array[String] = MissionResultValidator.validate(
		result,
		setup,
		campaign,
		catalogue
	)
	_expect(
		not invalid_errors.is_empty(),
		"MissionResultValidator must reject items outside the mission setup.",
		failures
	)


static func _test_campaign_revision_conflict(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _fixture()
	var result: MissionResult = fixture.get("result") as MissionResult
	var setup: MissionSetupSnapshot = fixture.get("setup") as MissionSetupSnapshot
	var campaign: CampaignState = fixture.get("campaign") as CampaignState
	var catalogue: ContentCatalogue = fixture.get("catalogue") as ContentCatalogue
	campaign.revision += 1
	var store: CampaignStateStore = CampaignStateStore.new()
	store.configure(campaign, null, catalogue)
	var service: CampaignResultCommitService = CampaignResultCommitService.new()
	service.configure(store, catalogue)
	var committed: OperationResult = service.commit_result(result, setup)
	_expect(
		not committed.success and committed.code == &"campaign_revision_conflict",
		"Mission results must not overwrite a changed campaign revision.",
		failures
	)


static func _test_save_backup_and_corruption_guard(
		failures: Array[String]
) -> void:
	var path: String = "user://seethe_stage_3_15_save_test.json"
	var repository: JsonCampaignRepository = JsonCampaignRepository.new(
		path,
		true
	)
	repository.clear_save()

	var first_campaign: CampaignState = CampaignState.new()
	var first_character: PersistentCharacterState = PersistentCharacterState.new()
	first_character.character_id = &"character.test.save.first"
	first_character.template_id = TacticalSandboxFactory.MARAUDER_TEMPLATE_ID
	first_character.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
	first_campaign.add_character(first_character)
	_expect(repository.save_campaign(first_campaign), "Initial campaign save must succeed.", failures)

	var second_character: PersistentCharacterState = PersistentCharacterState.new()
	second_character.character_id = &"character.test.save.second"
	second_character.template_id = TacticalSandboxFactory.MARAUDER_TEMPLATE_ID
	second_character.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
	first_campaign.add_character(second_character)
	_expect(repository.save_campaign(first_campaign), "Second save must create a backup.", failures)
	_expect(FileAccess.file_exists(repository.backup_path()), "A valid backup must exist after save rotation.", failures)

	var corrupt: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("{ definitely not valid json")
		corrupt.flush()
		corrupt = null

	var recovery_repository: JsonCampaignRepository = JsonCampaignRepository.new(
		path,
		true
	)
	var recovered: CampaignState = recovery_repository.load_campaign()
	_expect(recovered != null, "A corrupt current save must recover from backup.", failures)
	_expect(recovery_repository.recovered_from_backup, "Backup recovery must be reported.", failures)
	_expect(
		not recovery_repository.preserved_corrupt_path.is_empty()
		and FileAccess.file_exists(recovery_repository.preserved_corrupt_path),
		"The damaged save must be preserved separately.",
		failures
	)

	repository.clear_save()
	if not recovery_repository.preserved_corrupt_path.is_empty():
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(
				recovery_repository.preserved_corrupt_path
			)
		)


static func _test_tactical_change_set_rolls_back(
		failures: Array[String]
) -> void:
	var state: TacticalState = TacticalState.new()
	var unit: TacticalUnitState = TacticalUnitState.new(
		&"unit.test.transaction",
		"Transaction Unit",
		Vector2i.ZERO,
		30,
		&"player"
	)
	state.add_unit(unit, null, false)
	var store: TacticalStateStore = TacticalStateStore.new(state)
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	var revision_before: int = state.revision
	var harness: TransactionHarness = TransactionHarness.new(unit, 5)

	var rejected: TacticalChangeSet = TacticalChangeSet.new(
		&"test_rejected_change",
		revision_before
	)
	rejected.stage(
		Callable(harness, "apply"),
		Callable(harness, "rollback"),
		"Mutation failed."
	)
	rejected.require(
		Callable(harness, "reject"),
		"Forced rejection."
	)
	var rejected_result: OperationResult = store.commit(rejected)
	_expect(not rejected_result.success, "Rejected tactical changes must fail.", failures)
	_expect(
		unit.action_budget.remaining_turn_capacity_feet == capacity_before,
		"Rejected tactical changes must restore mutated state.",
		failures
	)
	_expect(state.revision == revision_before, "Rejected changes must preserve revision.", failures)

	var accepted: TacticalChangeSet = TacticalChangeSet.new(
		&"test_accepted_change",
		state.revision
	)
	accepted.stage(
		Callable(harness, "apply"),
		Callable(harness, "rollback"),
		"Mutation failed."
	)
	var accepted_result: OperationResult = store.commit(accepted)
	_expect(accepted_result.success, "Valid tactical changes must commit.", failures)
	_expect(
		unit.action_budget.remaining_turn_capacity_feet == capacity_before - 5,
		"Committed tactical changes must retain mutations.",
		failures
	)
	_expect(
		state.revision == revision_before + 1,
		"A committed change set must increment revision exactly once.",
		failures
	)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
