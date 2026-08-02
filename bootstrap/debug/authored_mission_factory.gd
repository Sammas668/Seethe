class_name AuthoredMissionFactory
extends RefCounted

const MISSION_SETUP_BUILDER_SCRIPT: Script = preload(
	"res://application/missions/mission_setup_builder.gd"
)
const CAMPAIGN_STATE_STORE_SCRIPT: Script = preload(
	"res://application/campaign/campaign_state_store.gd"
)
const CAMPAIGN_CHANGE_SET_SCRIPT: Script = preload(
	"res://application/campaign/transactions/campaign_change_set.gd"
)


static func create_session(
		mission_definition: MissionDefinition,
		selected_player_ids: Array[StringName] = [],
		persist_roster: bool = true,
		campaign_save_path: String = CampaignRepository.DEFAULT_SAVE_PATH
) -> TacticalSession:
	if mission_definition == null:
		push_error("Authored mission factory requires a MissionDefinition.")
		return null
	var definition_errors: Array[String] = mission_definition.validate_definition()
	if not definition_errors.is_empty():
		push_error("Authored mission is invalid: %s" % definition_errors[0])
		return null
	var map_definition: TacticalMapDefinition = mission_definition.map_definition
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var repository: CampaignRepository = JsonCampaignRepository.new(
		campaign_save_path,
		persist_roster,
		catalogue
	)
	var campaign: CampaignState = repository.load_campaign()
	var campaign_save_available: bool = campaign != null
	if campaign == null:
		campaign = CampaignState.new()
	var campaign_store: RefCounted = CAMPAIGN_STATE_STORE_SCRIPT.new() as RefCounted
	campaign_store.call(
		"configure",
		campaign,
		repository if campaign_save_available else null,
		catalogue
	)
	var bootstrap_change: RefCounted = CAMPAIGN_CHANGE_SET_SCRIPT.new() as RefCounted
	bootstrap_change.set("reason", &"authored_mission_campaign_initialized")
	bootstrap_change.set("expected_revision", campaign.revision)
	bootstrap_change.call(
		"stage",
		func(candidate: CampaignState) -> bool:
			TacticalSandboxFactory._ensure_sandbox_campaign(candidate, catalogue)
			return true
	)
	var bootstrap_result: OperationResult = campaign_store.call(
		"commit", bootstrap_change
	) as OperationResult
	if bootstrap_result == null or not bootstrap_result.success:
		push_error(
			"Authored mission campaign initialization failed: %s"
			% (bootstrap_result.message if bootstrap_result != null else "no result")
		)
		return null
	campaign = campaign_store.call("current_campaign") as CampaignState
	if campaign == null:
		return null

	var player_ids: Array[StringName] = selected_player_ids.duplicate()
	if player_ids.is_empty():
		player_ids = mission_definition.player_character_ids.duplicate()
	if not player_ids.has(mission_definition.protagonist_character_id):
		push_error("The authored mission requires its protagonist in the selected squad.")
		return null
	var setup: MissionSetupSnapshot = MISSION_SETUP_BUILDER_SCRIPT.create_from_campaign(
		campaign,
		player_ids,
		mission_definition.mission_instance_id
	)
	if not MISSION_SETUP_BUILDER_SCRIPT.configure_authored_mission(
		setup,
		mission_definition,
		mission_definition.protagonist_character_id
	):
		push_error("Authored mission setup could not bind its definition.")
		return null
	_add_non_player_characters(setup, mission_definition, catalogue)
	_add_ground_items(setup, mission_definition)
	var participant_ids: Array[StringName] = []
	for placement: MissionCharacterPlacementDefinition in mission_definition.character_placements:
		if placement == null:
			continue
		if placement.team_id == &"player" and not player_ids.has(placement.character_id):
			continue
		participant_ids.append(placement.character_id)
	if not MISSION_SETUP_BUILDER_SCRIPT.mark_intended_participants(setup, participant_ids):
		push_error("Authored mission participant manifest is invalid.")
		return null
	var finalized: OperationResult = MISSION_SETUP_BUILDER_SCRIPT.finalize_setup(setup)
	if not finalized.success:
		push_error("Authored mission setup invalid: %s" % finalized.message)
		return null

	var resolution_service := CharacterResolutionService.new()
	resolution_service.configure(catalogue)
	var deployment_service := TacticalCharacterDeploymentService.new(
		catalogue,
		resolution_service
	)
	var state := TacticalState.new()
	state.configure_extraction_zones(map_definition)
	state.configure_environment(map_definition)
	state.configure_knowledge_grid(map_definition.grid_size)
	if not state.configure_mission_runtime(
		mission_definition, setup.finalized_setup_hash()
	):
		push_error("Authored mission runtime state could not be configured.")
		return null

	for placement: MissionCharacterPlacementDefinition in mission_definition.character_placements:
		if placement == null:
			continue
		if placement.team_id == &"player" and not player_ids.has(placement.character_id):
			continue
		var character: PersistentCharacterState = setup.get_character(placement.character_id)
		if character == null:
			push_error("Mission character %s is missing from setup." % placement.character_id)
			return null
		var unit: TacticalUnitState = deployment_service.deploy_character(
			state,
			character,
			placement.grid_position,
			map_definition,
			[],
			setup.items_for_character(placement.character_id)
		)
		if unit == null:
			push_error("Could not deploy authored character %s." % placement.character_id)
			return null
		unit.set_facing(placement.facing)
		_configure_deployed_unit_control(unit, placement)
	_configure_squads(state, mission_definition)
	_instantiate_ground_items(catalogue, state, setup, map_definition)

	var session := TacticalSession.new(
		state,
		map_definition,
		setup.player_unit_order(),
		catalogue,
		setup,
		resolution_service,
		campaign_store,
		mission_definition
	)
	var errors: Array[String] = session.validate_session()
	if not errors.is_empty():
		push_error("Stage 4.6 authored mission session invalid: %s" % errors[0])
		return null
	return session


static func _configure_deployed_unit_control(
		unit: TacticalUnitState,
		placement: MissionCharacterPlacementDefinition
) -> void:
	if unit == null or placement == null:
		return
	var controller: StringName = TacticalUnitState.CONTROLLER_WORLD
	var behavior: StringName = TacticalUnitState.TURN_BEHAVIOR_NONE
	var receives_enemy_turn: bool = false
	match placement.team_id:
		&"player":
			controller = TacticalUnitState.CONTROLLER_PLAYER
			behavior = TacticalUnitState.TURN_BEHAVIOR_STANDARD
		&"enemy":
			controller = TacticalUnitState.CONTROLLER_AI
			behavior = (
				TacticalUnitState.TURN_BEHAVIOR_AUTO_PASS
				if placement.auto_pass_turn
				else TacticalUnitState.TURN_BEHAVIOR_STANDARD
			)
			receives_enemy_turn = true
		_:
			controller = TacticalUnitState.CONTROLLER_WORLD
			behavior = TacticalUnitState.TURN_BEHAVIOR_NONE
	unit.configure_tactical_control(
		controller,
		behavior,
		receives_enemy_turn,
		placement.counts_for_victory
	)
	if not placement.ai_profile_override_id.is_empty():
		unit.ai_profile_id = placement.ai_profile_override_id


static func _add_non_player_characters(
		setup: MissionSetupSnapshot,
		definition: MissionDefinition,
		catalogue: ContentCatalogue
) -> void:
	for placement: MissionCharacterPlacementDefinition in definition.character_placements:
		if placement == null or placement.team_id == &"player":
			continue
		var template: CharacterTemplateDefinition = catalogue.character_template(
			placement.template_id
		)
		if template == null:
			push_error("Missing character template %s." % placement.template_id)
			continue
		var character: PersistentCharacterState
		if placement.team_id == &"neutral":
			character = CharacterFactory.create_neutral_character(
				template,
				placement.character_id,
				placement.display_name,
				placement.faction_id
			)
		else:
			character = CharacterFactory.create_enemy_character(
				template,
				placement.character_id,
				placement.display_name,
				placement.faction_id
			)
		MISSION_SETUP_BUILDER_SCRIPT.add_isolated_character(
			setup, character, template
		)


static func _add_ground_items(
		setup: MissionSetupSnapshot,
		definition: MissionDefinition
) -> void:
	for placement: MissionGroundItemPlacementDefinition in definition.ground_item_placements:
		if placement == null:
			continue
		setup.add_ground_item(
			placement.instance_id,
			placement.definition_id,
			placement.grid_position,
			placement.quantity,
			placement.condition,
			placement.source_label
		)


static func _configure_squads(
		state: TacticalState,
		definition: MissionDefinition
) -> void:
	var members_by_squad: Dictionary = {}
	var team_by_squad: Dictionary = {}
	for placement: MissionCharacterPlacementDefinition in definition.character_placements:
		if placement == null or placement.squad_id.is_empty():
			continue
		var members: Array[StringName] = []
		for raw_id: Variant in members_by_squad.get(placement.squad_id, []):
			members.append(StringName(raw_id))
		members.append(placement.character_id)
		members_by_squad[placement.squad_id] = members
		team_by_squad[placement.squad_id] = placement.team_id
	for raw_squad_id: Variant in members_by_squad.keys():
		var squad_id := StringName(raw_squad_id)
		var member_ids: Array[StringName] = []
		for raw_member_id: Variant in members_by_squad.get(squad_id, []):
			member_ids.append(StringName(raw_member_id))
		state.add_squad(
			TacticalSquadState.new(
				squad_id,
				StringName(team_by_squad.get(squad_id, &"enemy")),
				member_ids
			),
			false
		)


static func _instantiate_ground_items(
		catalogue: ContentCatalogue,
		state: TacticalState,
		setup: MissionSetupSnapshot,
		map_definition: TacticalMapDefinition
) -> void:
	for campaign_item: CampaignItemState in setup.mission_ground_items():
		var definition: ItemDefinition = catalogue.item_definition(
			campaign_item.definition_id
		)
		if definition == null or campaign_item.location == null:
			push_error("Could not resolve authored mission item %s." % campaign_item.item_id)
			continue
		var item := TacticalItemInstanceState.new(
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
		if not state.add_item(item, map_definition):
			push_error("Could not add authored mission item %s." % item.item_id)
