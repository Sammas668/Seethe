class_name AuthoredMissionFactory
extends RefCounted

const MISSION_SETUP_BUILDER_SCRIPT: Script = preload(
	"res://application/missions/mission_setup_builder.gd"
)


static func build_registered_setup(
		campaign: CampaignState,
		mission_definition: MissionDefinition,
		selected_player_ids: Array[StringName],
		mission_instance_id: StringName,
		source_campaign_revision: int,
		mission_seed: int,
		catalogue: ContentCatalogue,
		deployment_context: Dictionary = {}
) -> MissionSetupSnapshot:
	if campaign == null or mission_definition == null or catalogue == null:
		return null
	var definition_errors: Array[String] = mission_definition.validate_definition()
	if not definition_errors.is_empty():
		push_error("Authored mission is invalid: %s" % definition_errors[0])
		return null
	var player_ids: Array[StringName] = selected_player_ids.duplicate()
	if player_ids.is_empty():
		player_ids = mission_definition.player_character_ids.duplicate()
	var formation_by_slot: Dictionary = deployment_context.get("formation_character_ids_by_slot", {}) as Dictionary
	if not formation_by_slot.is_empty():
		player_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return _formation_order_for_character(formation_by_slot, a) < _formation_order_for_character(formation_by_slot, b)
		)
	if not player_ids.has(mission_definition.protagonist_character_id):
		push_error("The authored mission requires its protagonist in the selected squad.")
		return null
	if player_ids.size() > mission_definition.maximum_player_deployment:
		push_error("The selected squad exceeds the mission deployment limit.")
		return null
	for character_id: StringName in player_ids:
		var character: PersistentCharacterState = campaign.get_character(character_id)
		if character == null or character.is_dead or character.team_id != &"player":
			push_error("Selected campaign character %s is unavailable." % character_id)
			return null

	var setup: MissionSetupSnapshot = MISSION_SETUP_BUILDER_SCRIPT.create_from_campaign(
		campaign,
		player_ids,
		mission_instance_id,
		source_campaign_revision,
		mission_seed
	)
	if not MISSION_SETUP_BUILDER_SCRIPT.configure_authored_mission(
		setup,
		mission_definition,
		mission_definition.protagonist_character_id
	):
		push_error("Authored mission setup could not bind its definition.")
		return null
	if not deployment_context.is_empty():
		var slot_by_character: Dictionary = {}
		for raw_slot_id: Variant in formation_by_slot.keys():
			var character_id := StringName(formation_by_slot.get(raw_slot_id, ""))
			if not character_id.is_empty():
				slot_by_character[character_id] = StringName(raw_slot_id)
		setup.configure_deployment_context(
			StringName(deployment_context.get("campaign_squad_id", "")),
			StringName(deployment_context.get("stable_bay_id", "")),
			StringName(deployment_context.get("transport_method_id", "transport.walking")),
			StringName(deployment_context.get("transport_asset_id", "")),
			slot_by_character
		)
		var player_anchors: Array[MissionCharacterPlacementDefinition] = _player_deployment_anchors(mission_definition)
		if player_ids.size() > player_anchors.size():
			push_error("The authored map has too few player deployment anchors for this Stable formation.")
			return null
		for index: int in range(player_ids.size()):
			var anchor: MissionCharacterPlacementDefinition = player_anchors[index]
			setup.configure_tactical_start(player_ids[index], anchor.grid_position, anchor.facing)
	_add_non_player_characters(setup, mission_definition, catalogue)
	_add_ground_items(setup, mission_definition)
	var participant_ids: Array[StringName] = player_ids.duplicate()
	for placement: MissionCharacterPlacementDefinition in mission_definition.character_placements:
		if placement == null or placement.team_id == &"player":
			continue
		participant_ids.append(placement.character_id)
	if not MISSION_SETUP_BUILDER_SCRIPT.mark_intended_participants(setup, participant_ids):
		push_error("Authored mission participant manifest is invalid.")
		return null
	var finalized: OperationResult = MISSION_SETUP_BUILDER_SCRIPT.finalize_setup(setup)
	if not finalized.success:
		push_error("Authored mission setup invalid: %s" % finalized.message)
		return null
	return setup


static func create_session_from_setup(
		mission_definition: MissionDefinition,
		setup: MissionSetupSnapshot,
		catalogue: ContentCatalogue
) -> TacticalSession:
	if mission_definition == null or setup == null or catalogue == null:
		push_error("Authored tactical assembly requires definition, setup and catalogue.")
		return null
	if not setup.verify_integrity():
		push_error("Authored tactical assembly requires an immutable verified setup.")
		return null
	if setup.mission_definition_id != mission_definition.mission_definition_id:
		push_error("Registered setup belongs to another mission definition.")
		return null
	var map_definition: TacticalMapDefinition = mission_definition.map_definition
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

	var selected_player_ids: Array[StringName] = setup.player_unit_order()
	var player_anchors: Array[MissionCharacterPlacementDefinition] = _player_deployment_anchors(mission_definition)
	if selected_player_ids.size() > player_anchors.size():
		push_error("The authored map has too few player deployment anchors for this Stable formation.")
		return null
	for index: int in range(selected_player_ids.size()):
		var character_id: StringName = selected_player_ids[index]
		var anchor: MissionCharacterPlacementDefinition = player_anchors[index]
		var start: Dictionary = setup.tactical_start(character_id)
		var start_position: Vector2i = anchor.grid_position
		var start_facing: Vector2i = anchor.facing
		if not start.is_empty():
			start_position = _vector2i_from(start.get("grid_position", [anchor.grid_position.x, anchor.grid_position.y]), anchor.grid_position)
			start_facing = _vector2i_from(start.get("facing", [anchor.facing.x, anchor.facing.y]), anchor.facing)
		var character: PersistentCharacterState = setup.get_character(character_id)
		if character == null:
			push_error("Mission character %s is missing from setup." % character_id)
			return null
		var unit: TacticalUnitState = deployment_service.deploy_character(
			state, character, start_position, map_definition, [], setup.items_for_character(character_id)
		)
		if unit == null:
			push_error("Could not deploy prepared character %s." % character_id)
			return null
		unit.set_facing(start_facing)
		_configure_deployed_unit_control(unit, anchor)
	for placement: MissionCharacterPlacementDefinition in mission_definition.character_placements:
		if placement == null or placement.team_id == &"player":
			continue
		var character: PersistentCharacterState = setup.get_character(placement.character_id)
		if character == null:
			push_error("Mission character %s is missing from setup." % placement.character_id)
			return null
		var unit: TacticalUnitState = deployment_service.deploy_character(
			state, character, placement.grid_position, map_definition, [], setup.items_for_character(placement.character_id)
		)
		if unit == null:
			push_error("Could not deploy authored character %s." % placement.character_id)
			return null
		unit.set_facing(placement.facing)
		_configure_deployed_unit_control(unit, placement)
	_configure_squads(state, mission_definition, setup)
	_instantiate_ground_items(catalogue, state, setup, map_definition)

	var session := TacticalSession.new(
		state,
		map_definition,
		setup.player_unit_order(),
		catalogue,
		setup,
		resolution_service,
		mission_definition
	)
	var errors: Array[String] = session.validate_session()
	if not errors.is_empty():
		push_error("Stage 5.0 authored mission session invalid: %s" % errors[0])
		return null
	return session


# Compatibility entry point retained for development fixtures. Production
# campaign flow calls build_registered_setup() and create_session_from_setup().
static func create_session(
		mission_definition: MissionDefinition,
		selected_player_ids: Array[StringName] = [],
		_persist_roster: bool = false,
		_campaign_save_path: String = CampaignRepository.DEFAULT_SAVE_PATH
) -> TacticalSession:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var campaign := CampaignState.new()
	TacticalSandboxFactory._ensure_sandbox_campaign(campaign, catalogue)
	var instance_id: StringName = mission_definition.mission_instance_id
	var setup := build_registered_setup(
		campaign,
		mission_definition,
		selected_player_ids,
		instance_id,
		campaign.revision,
		1,
		catalogue
	)
	if setup == null:
		push_error("Authored mission campaign initialization failed: setup could not be built.")
		return null
	return create_session_from_setup(mission_definition, setup, catalogue)



static func _player_deployment_anchors(
		mission_definition: MissionDefinition
) -> Array[MissionCharacterPlacementDefinition]:
	var result: Array[MissionCharacterPlacementDefinition] = []
	if mission_definition == null:
		return result
	for placement: MissionCharacterPlacementDefinition in mission_definition.character_placements:
		if placement != null and placement.team_id == &"player":
			result.append(placement)
	return result


static func _vector2i_from(raw_value: Variant, fallback: Vector2i) -> Vector2i:
	if raw_value is Vector2i:
		return raw_value
	if raw_value is Array and (raw_value as Array).size() >= 2:
		return Vector2i(int((raw_value as Array)[0]), int((raw_value as Array)[1]))
	if raw_value is Dictionary:
		return Vector2i(int((raw_value as Dictionary).get("x", fallback.x)), int((raw_value as Dictionary).get("y", fallback.y)))
	return fallback


static func _formation_order_for_character(formation_by_slot: Dictionary, character_id: StringName) -> int:
	for raw_slot_id: Variant in formation_by_slot.keys():
		if StringName(formation_by_slot.get(raw_slot_id, "")) != character_id:
			continue
		var slot_text: String = String(raw_slot_id)
		var suffix: String = slot_text.get_slice(".", slot_text.get_slice_count(".") - 1)
		return suffix.to_int() if suffix.is_valid_int() else 9999
	return 9999

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
		definition: MissionDefinition,
		setup: MissionSetupSnapshot
) -> void:
	var player_squad_id: StringName = setup.campaign_squad_id()
	if player_squad_id.is_empty():
		player_squad_id = &"squad.player.deployment"
	state.add_squad(TacticalSquadState.new(player_squad_id, &"player", setup.player_unit_order()), false)
	var members_by_squad: Dictionary = {}
	var team_by_squad: Dictionary = {}
	for placement: MissionCharacterPlacementDefinition in definition.character_placements:
		if placement == null or placement.team_id == &"player" or placement.squad_id.is_empty():
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
