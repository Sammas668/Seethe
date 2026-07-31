class_name TacticalSandboxFactory
extends RefCounted

const MOVEMENT_TEST_MAP: TacticalMapDefinition = preload(
	"res://content/missions/farm_storehouse/movement_test_map.tres"
)
const MISSION_SETUP_BUILDER_SCRIPT = preload(
	"res://application/missions/mission_setup_builder.gd"
)
const CAMPAIGN_STATE_STORE_SCRIPT: Script = preload(
	"res://application/campaign/campaign_state_store.gd"
)
const CAMPAIGN_CHANGE_SET_SCRIPT: Script = preload(
	"res://application/campaign/transactions/campaign_change_set.gd"
)

const SANDBOX_MISSION_ID: StringName = &"mission.sandbox.farm_storehouse"
const MARAUDER_ID: StringName = &"character.reaver.marauder.0001"
const ARCHER_ID: StringName = &"character.prototype.archer.0001"
const SCOUT_ID: StringName = &"character.prototype.scout.0001"
const ENEMY_ID: StringName = &"character.example.enemy_guard.0001"
const ENEMY_TWO_ID: StringName = &"character.example.enemy_guard.0002"
const NEUTRAL_ID: StringName = &"character.example.neutral_farmhand.0001"
const PRACTICE_DUMMY_ID: StringName = &"character.example.practice_dummy.0001"
const GUARD_SQUAD_A_ID: StringName = &"squad.settlement_watch.a"
const GUARD_SQUAD_B_ID: StringName = &"squad.settlement_watch.b"

const MARAUDER_TEMPLATE_ID: StringName = &"character_template.reaver.marauder_tier_1"
const ARCHER_TEMPLATE_ID: StringName = &"character_template.prototype.archer"
const SCOUT_TEMPLATE_ID: StringName = &"character_template.prototype.scout"
const ENEMY_TEMPLATE_ID: StringName = &"character_template.prototype.enemy_guard"
const ENEMY_ARCHER_TEMPLATE_ID: StringName = &"character_template.prototype.enemy_archer"
const NEUTRAL_TEMPLATE_ID: StringName = &"character_template.prototype.neutral_farmhand"
const PRACTICE_DUMMY_TEMPLATE_ID: StringName = &"character_template.prototype.practice_dummy"

const HAKON_PORTRAIT_ID: StringName = &"portrait.hakon_rusk"


static func create_session(
		persist_roster: bool = true,
		campaign_save_path: String = CampaignRepository.DEFAULT_SAVE_PATH
) -> TacticalSession:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var repository: CampaignRepository = JsonCampaignRepository.new(
		campaign_save_path,
		persist_roster,
		catalogue
	)
	var campaign: CampaignState = repository.load_campaign()
	var campaign_save_available: bool = campaign != null
	if campaign == null:
		push_error(
			"Campaign save could not be loaded safely. "
			+ "The sandbox will run in memory without overwriting it."
		)
		campaign = CampaignState.new()
	var campaign_store: RefCounted = CAMPAIGN_STATE_STORE_SCRIPT.new() as RefCounted
	campaign_store.call(
		"configure",
		campaign,
		repository if campaign_save_available else null,
		catalogue
	)
	var bootstrap_change: RefCounted = CAMPAIGN_CHANGE_SET_SCRIPT.new() as RefCounted
	bootstrap_change.set("reason", &"sandbox_campaign_initialized")
	bootstrap_change.set("expected_revision", campaign.revision)
	bootstrap_change.call(
		"stage",
		func(candidate: CampaignState) -> bool:
			_ensure_sandbox_campaign(candidate, catalogue)
			return true
	)
	var bootstrap_result_value: Variant = campaign_store.call(
		"commit",
		bootstrap_change
	)
	var bootstrap_result: OperationResult = bootstrap_result_value as OperationResult
	if bootstrap_result == null or not bootstrap_result.success:
		push_error(
			"Sandbox campaign initialization failed: %s"
			% (bootstrap_result.message if bootstrap_result != null else "no result")
		)
	var current_campaign_value: Variant = campaign_store.call("current_campaign")
	campaign = current_campaign_value as CampaignState
	if campaign == null:
		campaign = CampaignState.new()

	var player_ids: Array[StringName] = [
		MARAUDER_ID,
		ARCHER_ID,
		SCOUT_ID,
	]
	var setup: MissionSetupSnapshot = MISSION_SETUP_BUILDER_SCRIPT.create_from_campaign(
		campaign,
		player_ids,
		SANDBOX_MISSION_ID
	)
	MISSION_SETUP_BUILDER_SCRIPT.configure_mission_definition(
		setup, MOVEMENT_TEST_MAP, MARAUDER_ID
	)
	_add_non_player_mission_characters(setup, catalogue)
	_add_sandbox_ground_items(setup)
	var intended_participants: Array[StringName] = [
		MARAUDER_ID,
		ARCHER_ID,
		SCOUT_ID,
		ENEMY_ID,
		ENEMY_TWO_ID,
		NEUTRAL_ID,
		PRACTICE_DUMMY_ID,
	]
	MISSION_SETUP_BUILDER_SCRIPT.mark_intended_participants(
		setup,
		intended_participants
	)
	var setup_finalized: OperationResult = (
		MISSION_SETUP_BUILDER_SCRIPT.finalize_setup(setup)
	)
	if not setup_finalized.success:
		push_error("Stage 4.0 mission setup invalid: %s" % setup_finalized.message)

	var resolution_service: CharacterResolutionService = (
		CharacterResolutionService.new()
	)
	resolution_service.configure(catalogue)
	var deployment_service: TacticalCharacterDeploymentService = (
		TacticalCharacterDeploymentService.new(
			catalogue,
			resolution_service
		)
	)
	var state: TacticalState = TacticalState.new()
	# Stage 4.3.3 extraction-zone invariants must exist before assembly
	# deployment validates the state. TacticalSession is constructed only
	# after every mission character has been deployed.
	state.configure_extraction_zones(MOVEMENT_TEST_MAP)
	state.configure_environment(MOVEMENT_TEST_MAP)
	state.configure_knowledge_grid(MOVEMENT_TEST_MAP.grid_size)

	_deploy_or_error(
		deployment_service,
		state,
		setup,
		MARAUDER_ID,
		MOVEMENT_TEST_MAP.get_player_starting_tile(0, Vector2i(2, 2))
	)
	_deploy_or_error(
		deployment_service,
		state,
		setup,
		ARCHER_ID,
		MOVEMENT_TEST_MAP.get_player_starting_tile(1, Vector2i(2, 4))
	)
	_deploy_or_error(
		deployment_service,
		state,
		setup,
		SCOUT_ID,
		MOVEMENT_TEST_MAP.get_player_starting_tile(2, Vector2i(4, 2))
	)
	_deploy_or_error(
		deployment_service,
		state,
		setup,
		PRACTICE_DUMMY_ID,
		Vector2i(3, 2)
	)
	_deploy_or_error(
		deployment_service,
		state,
		setup,
		ENEMY_ID,
		Vector2i(7, 4)
	)
	_deploy_or_error(
		deployment_service,
		state,
		setup,
		ENEMY_TWO_ID,
		Vector2i(7, 6)
	)
	_deploy_or_error(
		deployment_service,
		state,
		setup,
		NEUTRAL_ID,
		Vector2i(18, 16)
	)
	_configure_active_enemy(state)
	_configure_guard_squads(state)
	_configure_training_dummy(state)
	_instantiate_ground_items(catalogue, state, setup)

	var session: TacticalSession = TacticalSession.new(
		state,
		MOVEMENT_TEST_MAP,
		setup.player_unit_order(),
		catalogue,
		setup,
		resolution_service,
		campaign_store
	)
	var errors: Array[String] = session.validate_session()
	if not errors.is_empty():
		push_error("Stage 4.0 sandbox fixture invalid: %s" % errors[0])
	return session


static func _ensure_sandbox_campaign(
		campaign: CampaignState,
		catalogue: ContentCatalogue
) -> void:
	var marauder: PersistentCharacterState = campaign.get_character(MARAUDER_ID)
	if marauder == null:
		marauder = CharacterFactory.create_player_character(
			catalogue.character_template(MARAUDER_TEMPLATE_ID),
			MARAUDER_ID,
			"Hakon Rusk"
		)
		campaign.add_character(marauder)
	_ensure_character_items(
		campaign,
		marauder,
		catalogue.character_template(MARAUDER_TEMPLATE_ID),
		{
			&"item.raiders_axe": &"instance.marauder.axe",
			&"item.mace": &"instance.marauder.mace",
			&"item.reaver_dagger": &"instance.marauder.dagger",
			&"item.manacles": &"instance.marauder.manacles",
			&"item.rope": &"instance.marauder.rope",
			&"item.rations": &"instance.marauder.rations",
		}
	)

	if marauder != null and marauder.portrait_override_id.is_empty():
		marauder.set_portrait_override_id(HAKON_PORTRAIT_ID)

	var archer: PersistentCharacterState = campaign.get_character(ARCHER_ID)
	if archer == null:
		archer = CharacterFactory.create_player_character(
			catalogue.character_template(ARCHER_TEMPLATE_ID),
			ARCHER_ID,
			"Elira Venn"
		)
		campaign.add_character(archer)
	_ensure_character_items(
		campaign,
		archer,
		catalogue.character_template(ARCHER_TEMPLATE_ID),
		{
			&"item.training_shortbow": &"instance.archer.shortbow",
			&"item.bandage": &"instance.archer.bandage",
			&"item.smoke_pellet": &"instance.archer.smoke",
			&"item.dagger": &"instance.archer.dagger",
			&"item.buckler": &"instance.archer.buckler",
			&"item.spare_arrows": &"instance.archer.arrows",
		}
	)

	var scout: PersistentCharacterState = campaign.get_character(SCOUT_ID)
	if scout == null:
		scout = CharacterFactory.create_player_character(
			catalogue.character_template(SCOUT_TEMPLATE_ID),
			SCOUT_ID,
			"Mara Quill"
		)
		campaign.add_character(scout)
	_ensure_character_items(
		campaign,
		scout,
		catalogue.character_template(SCOUT_TEMPLATE_ID),
		{
			&"item.training_spear": &"instance.scout.spear",
			&"item.knife": &"instance.scout.knife",
			&"item.lockpicks": &"instance.scout.lockpicks",
			&"item.bandage": &"instance.scout.bandage",
			&"item.rope": &"instance.scout.rope",
			&"item.empty_sack": &"instance.scout.sack",
			&"item.sling": &"instance.scout.sling",
		}
	)


static func _ensure_character_items(
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition,
		instance_id_by_definition_id: Dictionary
) -> void:
	if campaign == null or character == null or template == null:
		return
	if not campaign.items_for_character(character.character_id).is_empty():
		return
	CharacterFactory.add_default_loadout_to_campaign(
		campaign,
		character,
		template,
		instance_id_by_definition_id
	)


static func _add_non_player_mission_characters(
		setup: MissionSetupSnapshot,
		catalogue: ContentCatalogue
) -> void:
	var enemy_template: CharacterTemplateDefinition = catalogue.character_template(
		ENEMY_TEMPLATE_ID
	)
	var enemy_archer_template: CharacterTemplateDefinition = catalogue.character_template(
		ENEMY_ARCHER_TEMPLATE_ID
	)
	var neutral_template: CharacterTemplateDefinition = catalogue.character_template(
		NEUTRAL_TEMPLATE_ID
	)
	var enemy: PersistentCharacterState = CharacterFactory.create_enemy_character(
		enemy_template,
		ENEMY_ID,
		"Generated Settlement Guard",
		&"faction.settlement_watch"
	)
	var enemy_two: PersistentCharacterState = CharacterFactory.create_enemy_character(
		enemy_archer_template,
		ENEMY_TWO_ID,
		"Generated Settlement Archer",
		&"faction.settlement_watch"
	)
	var neutral: PersistentCharacterState = CharacterFactory.create_neutral_character(
		neutral_template,
		NEUTRAL_ID,
		"Generated Farmhand",
		&"faction.local_civilians"
	)
	var dummy_template: CharacterTemplateDefinition = catalogue.character_template(
		PRACTICE_DUMMY_TEMPLATE_ID
	)
	var dummy: PersistentCharacterState = CharacterFactory.create_enemy_character(
		dummy_template,
		PRACTICE_DUMMY_ID,
		"Training Dummy",
		&"faction.training_target"
	)
	MISSION_SETUP_BUILDER_SCRIPT.add_isolated_character(setup, enemy, enemy_template)
	MISSION_SETUP_BUILDER_SCRIPT.add_isolated_character(
		setup,
		enemy_two,
		enemy_archer_template
	)
	MISSION_SETUP_BUILDER_SCRIPT.add_isolated_character(setup, neutral, neutral_template)
	MISSION_SETUP_BUILDER_SCRIPT.add_isolated_character(setup, dummy, dummy_template)


static func _configure_active_enemy(state: TacticalState) -> void:
	if state == null:
		return
	for guard_id: StringName in [ENEMY_ID, ENEMY_TWO_ID]:
		var guard: TacticalUnitState = state.get_unit(guard_id)
		if guard == null:
			push_error("Settlement Guard %s was not deployed." % guard_id)
			continue
		guard.configure_tactical_control(
			TacticalUnitState.CONTROLLER_AI,
			TacticalUnitState.TURN_BEHAVIOR_STANDARD,
			true,
			true
		)


static func _configure_guard_squads(state: TacticalState) -> void:
	if state == null:
		return
	var guard: TacticalUnitState = state.get_unit(ENEMY_ID)
	var archer: TacticalUnitState = state.get_unit(ENEMY_TWO_ID)
	var dummy: TacticalUnitState = state.get_unit(PRACTICE_DUMMY_ID)
	var watch_members: Array[StringName] = []
	if guard != null:
		guard.set_facing(Vector2i(0, 1))
		watch_members.append(guard.unit_id)
	if archer != null:
		archer.set_facing(Vector2i(0, 1))
		watch_members.append(archer.unit_id)
	if not watch_members.is_empty():
		# The generated melee guard and archer are one authored settlement-watch
		# squad. Detection by either member therefore alerts both members, while
		# revelation remains specific to the player character actually seen.
		state.add_squad(
			TacticalSquadState.new(
				GUARD_SQUAD_A_ID,
				&"enemy",
				watch_members
			),
			false
		)
	if dummy != null:
		# Keep a separate authored enemy squad in the sandbox so squad-limited
		# awareness can still be tested without separating the guard and archer.
		state.add_squad(
			TacticalSquadState.new(
				GUARD_SQUAD_B_ID,
				&"enemy",
				[PRACTICE_DUMMY_ID]
			),
			false
		)


static func _configure_training_dummy(state: TacticalState) -> void:
	if state == null:
		return
	var dummy: TacticalUnitState = state.get_unit(PRACTICE_DUMMY_ID)
	if dummy == null:
		push_error("Training Dummy was not deployed.")
		return
	dummy.configure_tactical_control(
		TacticalUnitState.CONTROLLER_AI,
		TacticalUnitState.TURN_BEHAVIOR_AUTO_PASS,
		true,
		false
	)



static func _add_sandbox_ground_items(setup: MissionSetupSnapshot) -> void:
	setup.add_ground_item(
		&"instance.ground.spear",
		&"item.training_spear",
		Vector2i(5, 2),
		1,
		1.0,
		"Ground"
	)
	setup.add_ground_item(
		&"instance.ground.grain_crate",
		&"item.grain_crate",
		Vector2i(2, 3),
		1,
		1.0,
		"Ground"
	)
	setup.add_ground_item(
		&"instance.ground.bandages",
		&"item.bandage",
		Vector2i(3, 4),
		2,
		1.0,
		"Ground"
	)
	setup.add_ground_item(
		&"instance.ground.healing_potion",
		&"item.minor_healing_potion",
		Vector2i(4, 4),
		1,
		1.0,
		"Ground"
	)


static func _instantiate_ground_items(
		catalogue: ContentCatalogue,
		state: TacticalState,
		setup: MissionSetupSnapshot
) -> void:
	for campaign_item: CampaignItemState in setup.mission_ground_items():
		var definition: ItemDefinition = catalogue.item_definition(
			campaign_item.definition_id
		)
		if definition == null or campaign_item.location == null:
			push_error("Could not resolve sandbox item %s." % campaign_item.item_id)
			continue
		var item: TacticalItemInstanceState = TacticalItemInstanceState.new(
			campaign_item.item_id,
			definition,
			campaign_item.quantity,
			campaign_item.condition,
			TacticalItemLocationState.ground(
				campaign_item.location.map_position,
				campaign_item.location.source_label
			),
			campaign_item.persistent_modifiers
		)
		if not state.add_item(item, MOVEMENT_TEST_MAP):
			push_error("Could not add sandbox item %s." % item.item_id)


static func _deploy_or_error(
		deployment_service: TacticalCharacterDeploymentService,
		state: TacticalState,
		setup: MissionSetupSnapshot,
		character_id: StringName,
		grid_position: Vector2i
) -> void:
	var character: PersistentCharacterState = setup.get_character(character_id)
	if character == null:
		push_error("Could not find mission character for deployment.")
		return
	var deployed_unit: TacticalUnitState = deployment_service.deploy_character(
		state,
		character,
		grid_position,
		MOVEMENT_TEST_MAP,
		[],
		setup.items_for_character(character_id)
	)
	if deployed_unit == null:
		push_error(
			"Could not deploy mission character %s."
			% character.character_id
		)
		return
