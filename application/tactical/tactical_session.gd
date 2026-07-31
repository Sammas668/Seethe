class_name TacticalSession
extends RefCounted

const EVENT_JOURNAL_SCRIPT: Script = preload(
	"res://application/tactical/events/tactical_event_journal.gd"
)
const TACTICAL_SCREEN_FACADE_SCRIPT: Script = preload(
	"res://application/tactical/facades/tactical_screen_facade.gd"
)
const ATTACK_PREVIEW_QUERY_SCRIPT: Script = preload(
	"res://application/tactical/combat/attack_preview_query.gd"
)
const ATTACK_HANDLER_SCRIPT: Script = preload(
	"res://application/tactical/combat/attack_handler.gd"
)
const TACTICAL_DICE_ROLLER_SCRIPT: Script = preload(
	"res://application/tactical/combat/tactical_dice_roller.gd"
)
const ENEMY_TURN_HANDLER_SCRIPT: Script = preload(
	"res://application/tactical/ai/enemy_turn_handler.gd"
)
const VISIBILITY_SERVICE_SCRIPT: Script = preload(
	"res://application/tactical/visibility/tactical_visibility_service.gd"
)
const DETECTION_SERVICE_SCRIPT: Script = preload(
	"res://application/tactical/awareness/tactical_detection_service.gd"
)
const STEALTH_HANDLER_SCRIPT: Script = preload(
	"res://application/tactical/awareness/stealth_handler.gd"
)
const INITIATIVE_HANDLER_SCRIPT: Script = preload(
	"res://application/tactical/initiative/initiative_turn_handler.gd"
)
const FACING_HANDLER_SCRIPT: Script = preload(
	"res://application/tactical/facing/facing_handler.gd"
)
const LIFE_STATE_HANDLER_SCRIPT: Script = preload(
	"res://application/tactical/life/tactical_life_state_handler.gd"
)
const BODY_ACTION_HANDLER_SCRIPT: Script = preload(
	"res://application/tactical/body/tactical_body_action_handler.gd"
)
const RESOLVE_TACTICAL_MISSION_HANDLER_SCRIPT: Script = preload(
	"res://application/tactical/extraction/resolve_tactical_mission_handler.gd"
)
const TACTICAL_OPENING_HANDLER_SCRIPT: Script = preload(
	"res://application/tactical/environment/tactical_opening_handler.gd"
)
const TACTICAL_STRUCTURE_ATTACK_HANDLER_SCRIPT: Script = preload(
	"res://application/tactical/environment/tactical_structure_attack_handler.gd"
)
const TACTICAL_GEOMETRY_CACHE_SERVICE_SCRIPT: Script = preload(
	"res://application/tactical/queries/tactical_geometry_cache_service.gd"
)
const TACTICAL_REACTION_SERVICE_SCRIPT: Script = preload(
	"res://application/tactical/reactions/tactical_reaction_service.gd"
)

var state_store: TacticalStateStore
var map_definition: TacticalMapDefinition
var content_catalogue: ContentCatalogue
var mission_setup: MissionSetupSnapshot
var character_resolution_service: CharacterResolutionService
var event_journal: RefCounted
var movement_handler: TacticalCommandHandler
var spend_action_handler: SpendActionHandler
var sprint_handler: SprintMoveHandler
var end_phase_handler: EndPhaseHandler
var inventory_transfer_handler: TacticalInventoryTransferHandler
var attack_preview_query: RefCounted
var geometry_cache_service: TacticalGeometryCacheService
var attack_handler: RefCounted
var combat_dice_roller: RefCounted
var enemy_turn_handler: RefCounted
var visibility_service: RefCounted
var detection_service: TacticalDetectionService
var stealth_handler: StealthHandler
var initiative_handler: InitiativeTurnHandler
var facing_handler: FacingHandler
var life_state_handler
var body_action_handler: TacticalBodyActionHandler
var mission_resolution_handler: ResolveTacticalMissionHandler
var opening_handler: TacticalOpeningHandler
var structure_attack_handler: TacticalStructureAttackHandler
var reaction_service: TacticalReactionService
var campaign_store: RefCounted
var player_unit_order: Array[StringName] = []
var screen_facade


func _init(
		initial_state: TacticalState,
		map_definition_value: TacticalMapDefinition,
		unit_order_value: Array[StringName],
		content_catalogue_value: ContentCatalogue,
		mission_setup_value: MissionSetupSnapshot,
		resolution_service_value: CharacterResolutionService,
		campaign_store_value: RefCounted = null
) -> void:
	_ensure_player_perception_squad(initial_state)
	initial_state.configure_extraction_zones(map_definition_value)
	initial_state.configure_environment(map_definition_value)
	initial_state.configure_knowledge_grid(
		map_definition_value.grid_size
		if map_definition_value != null
		else Vector2i.ZERO
	)
	initial_state.synchronise_body_items(map_definition_value)
	state_store = TacticalStateStore.new(initial_state)
	map_definition = map_definition_value
	content_catalogue = content_catalogue_value
	mission_setup = (
		mission_setup_value
		if mission_setup_value != null
		else MissionSetupSnapshot.new()
	)
	character_resolution_service = resolution_service_value
	campaign_store = campaign_store_value
	if character_resolution_service == null:
		push_error(
			"TacticalSession requires a CharacterResolutionService supplied by composition."
		)

	event_journal = EVENT_JOURNAL_SCRIPT.new()
	player_unit_order.clear()
	for unit_id: StringName in unit_order_value:
		player_unit_order.append(unit_id)

	movement_handler = TacticalCommandHandler.new(
		state_store,
		map_definition,
		event_journal
	)
	spend_action_handler = SpendActionHandler.new(
		state_store,
		event_journal
	)
	sprint_handler = SprintMoveHandler.new(
		state_store,
		map_definition,
		event_journal
	)
	end_phase_handler = EndPhaseHandler.new(
		state_store,
		event_journal
	)
	inventory_transfer_handler = TacticalInventoryTransferHandler.new(
		state_store,
		map_definition,
		event_journal
	)
	visibility_service = VISIBILITY_SERVICE_SCRIPT.new() as RefCounted
	visibility_service.call("configure", state_store, map_definition)
	combat_dice_roller = TACTICAL_DICE_ROLLER_SCRIPT.new() as RefCounted
	life_state_handler = LIFE_STATE_HANDLER_SCRIPT.new()
	life_state_handler.configure(
		state_store,
		map_definition,
		event_journal,
		combat_dice_roller as TacticalDiceRoller
	)
	body_action_handler = BODY_ACTION_HANDLER_SCRIPT.new() as TacticalBodyActionHandler
	body_action_handler.configure(
		state_store, map_definition, event_journal, life_state_handler
	)
	detection_service = DETECTION_SERVICE_SCRIPT.new() as TacticalDetectionService
	detection_service.configure(
		state_store,
		map_definition,
		event_journal,
		combat_dice_roller as TacticalDiceRoller,
		visibility_service
	)
	movement_handler.configure_detection(
		detection_service,
		combat_dice_roller as TacticalDiceRoller
	)
	sprint_handler.configure_detection(
		detection_service,
		combat_dice_roller as TacticalDiceRoller
	)
	stealth_handler = STEALTH_HANDLER_SCRIPT.new() as StealthHandler
	stealth_handler.configure(
		state_store,
		map_definition,
		event_journal,
		detection_service,
		combat_dice_roller as TacticalDiceRoller
	)
	facing_handler = FACING_HANDLER_SCRIPT.new() as FacingHandler
	facing_handler.configure(
		state_store,
		map_definition,
		event_journal,
		detection_service
	)
	initiative_handler = INITIATIVE_HANDLER_SCRIPT.new() as InitiativeTurnHandler
	initiative_handler.configure(
		state_store,
		map_definition,
		event_journal,
		life_state_handler
	)
	geometry_cache_service = (
		TACTICAL_GEOMETRY_CACHE_SERVICE_SCRIPT.new()
		as TacticalGeometryCacheService
	)
	geometry_cache_service.configure(state_store, map_definition)
	attack_preview_query = ATTACK_PREVIEW_QUERY_SCRIPT.new() as RefCounted
	attack_preview_query.call(
		"configure",
		state_store,
		map_definition,
		content_catalogue,
		visibility_service,
		geometry_cache_service
	)
	attack_handler = ATTACK_HANDLER_SCRIPT.new() as RefCounted
	attack_handler.call(
		"configure",
		state_store,
		map_definition,
		content_catalogue,
		event_journal,
		attack_preview_query,
		combat_dice_roller,
		detection_service
	)
	reaction_service = TACTICAL_REACTION_SERVICE_SCRIPT.new() as TacticalReactionService
	reaction_service.configure(
		state_store,
		map_definition,
		content_catalogue,
		event_journal,
		attack_preview_query,
		attack_handler,
		visibility_service
	)
	movement_handler.configure_reactions(reaction_service)
	sprint_handler.configure_reactions(reaction_service)
	enemy_turn_handler = ENEMY_TURN_HANDLER_SCRIPT.new() as RefCounted
	enemy_turn_handler.call(
		"configure",
		state_store,
		map_definition,
		content_catalogue,
		event_journal,
		attack_preview_query,
		attack_handler,
		detection_service
	)
	enemy_turn_handler.call("configure_body_actions", body_action_handler)
	if enemy_turn_handler.has_method("configure_reactions"):
		enemy_turn_handler.call("configure_reactions", reaction_service)
	mission_resolution_handler = (
		RESOLVE_TACTICAL_MISSION_HANDLER_SCRIPT.new()
		as ResolveTacticalMissionHandler
	)
	mission_resolution_handler.configure(
		state_store,
		map_definition,
		mission_setup,
		campaign_store,
		content_catalogue,
		event_journal
	)
	opening_handler = TACTICAL_OPENING_HANDLER_SCRIPT.new() as TacticalOpeningHandler
	opening_handler.configure(
		state_store,
		map_definition,
		event_journal,
		combat_dice_roller as TacticalDiceRoller,
		visibility_service,
		detection_service
	)
	structure_attack_handler = TACTICAL_STRUCTURE_ATTACK_HANDLER_SCRIPT.new() as TacticalStructureAttackHandler
	structure_attack_handler.configure(
		state_store,
		map_definition,
		content_catalogue,
		event_journal,
		combat_dice_roller as TacticalDiceRoller
	)
	screen_facade = TACTICAL_SCREEN_FACADE_SCRIPT.new()
	screen_facade.configure(
		state_store,
		map_definition,
		content_catalogue,
		event_journal,
		movement_handler,
		spend_action_handler,
		sprint_handler,
		end_phase_handler,
		inventory_transfer_handler,
		player_unit_order,
		Callable(self, "set_character_modifier_active"),
		attack_preview_query,
		attack_handler,
		combat_dice_roller,
		enemy_turn_handler,
		visibility_service,
		detection_service,
		stealth_handler,
		initiative_handler,
		facing_handler,
		life_state_handler,
		body_action_handler,
		mission_setup,
		mission_resolution_handler,
		opening_handler,
		structure_attack_handler,
		geometry_cache_service,
		reaction_service
	)

	event_journal.call(
		"record_event",
		&"phase_started",
		state_store.state.phase_state.round_number,
		state_store.state.phase_state.current_phase,
		"Round %d — Player Phase."
		% state_store.state.phase_state.round_number,
		{
			"category": &"events",
			"details": [
				"All friendly units are ready.",
				"Normal capacity, Quick Actions and Reactions are available.",
			],
		}
	)


func _ensure_player_perception_squad(state: TacticalState) -> void:
	if state == null:
		return
	var player_ids: Array[StringName] = []
	for unit: TacticalUnitState in state.get_player_units():
		player_ids.append(unit.unit_id)
	if player_ids.is_empty():
		return
	var squad: TacticalSquadState = state.get_squad(
		TacticalSquadState.PLAYER_TEAM_SQUAD_ID
	)
	if squad == null:
		squad = TacticalSquadState.new(
			TacticalSquadState.PLAYER_TEAM_SQUAD_ID,
			&"player",
			player_ids
		)
		squad.make_aware()
		state.add_squad(squad, false)
	else:
		for unit_id: StringName in player_ids:
			squad.add_member(unit_id)
			var unit: TacticalUnitState = state.get_unit(unit_id)
			if unit != null:
				unit.squad_id = squad.squad_id
		squad.make_aware()


func navigation_for(unit_id: StringName) -> TacticalNavigationSnapshot:
	return TacticalNavigationSnapshot.new(
		map_definition,
		state_store.state,
		unit_id
	)


func mission_character(
		character_id: StringName
) -> PersistentCharacterState:
	return mission_setup.get_character(character_id)


func set_character_modifier_active(
		unit_id: StringName,
		modifier_id: StringName,
		active: bool
) -> bool:
	var unit: TacticalUnitState = state_store.state.get_unit(unit_id)
	if unit == null or unit.persistent_character_id.is_empty():
		return false
	var character: PersistentCharacterState = mission_setup.get_character(
		unit.persistent_character_id
	)
	if character == null:
		return false

	var previous_modifier_ids: Array[StringName] = (
		unit.active_character_modifier_ids.duplicate()
	)
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"character_resolved",
		state_store.state.revision
	)
	changes.stage(
		Callable(self, "_apply_character_modifier").bind(
			unit,
			character,
			modifier_id,
			active
		),
		Callable(self, "_restore_character_modifiers").bind(
			unit,
			character,
			previous_modifier_ids
		),
		"The character modifier could not be resolved.",
		&"character_resolution_failed"
	)
	var committed: OperationResult = state_store.commit(
		changes,
		map_definition
	)
	return committed.success


func _apply_character_modifier(
		unit: TacticalUnitState,
		character: PersistentCharacterState,
		modifier_id: StringName,
		active: bool
) -> bool:
	unit.set_character_modifier_active(modifier_id, active)
	character_resolution_service.refresh_tactical_unit(
		unit,
		character,
		_tactical_items_for_unit(unit.unit_id)
	)
	return unit.resolved_character != null


func _restore_character_modifiers(
		unit: TacticalUnitState,
		character: PersistentCharacterState,
		previous_modifier_ids: Array[StringName]
) -> void:
	unit.active_character_modifier_ids = previous_modifier_ids.duplicate()
	character_resolution_service.refresh_tactical_unit(
		unit,
		character,
		_tactical_items_for_unit(unit.unit_id)
	)


func _tactical_items_for_unit(
		unit_id: StringName
) -> Array[TacticalItemInstanceState]:
	var result: Array[TacticalItemInstanceState] = []
	for item: TacticalItemInstanceState in state_store.state.get_items():
		if item.location == null or item.location.owner_id != unit_id:
			continue
		if item.location.location_type in [
			TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
			TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
		]:
			result.append(item)
	return result


func build_mission_result(
		result_id: StringName,
		extracted_character_ids: Array[StringName],
		xp_by_character_id: Dictionary = {},
		injuries_by_character_id: Dictionary = {},
		extracted_ground_item_ids: Array[StringName] = [],
		successful: bool = true
) -> MissionResult:
	return MissionResultBuilder.build_result(
		result_id,
		mission_setup,
		state_store.state,
		extracted_character_ids,
		xp_by_character_id,
		injuries_by_character_id,
		extracted_ground_item_ids,
		successful
	)


func validate_session() -> Array[String]:
	var errors: Array[String] = []
	if map_definition == null:
		errors.append("TacticalSession has no TacticalMapDefinition.")
	else:
		errors.append_array(state_store.state.validate_all(map_definition))
		errors.append_array(map_definition.validate_definition())
	if content_catalogue == null:
		errors.append("TacticalSession has no ContentCatalogue.")
		return errors
	if campaign_store == null:
		errors.append("TacticalSession has no campaign state store for mission resolution.")
	if mission_resolution_handler == null:
		errors.append("TacticalSession has no mission resolution handler.")

	errors.append_array(content_catalogue.validate_catalogue())
	if map_definition != null:
		for opening: TacticalOpeningDefinition in map_definition.openings:
			if (
				opening != null
				and not opening.salvage_item_definition_id.is_empty()
				and content_catalogue.item_definition(opening.salvage_item_definition_id) == null
			):
				errors.append(
					"Opening %s references unknown salvage definition %s."
					% [opening.opening_id, opening.salvage_item_definition_id]
				)
		for structure: TacticalStructureDefinition in map_definition.structures:
			if (
				structure != null
				and not structure.salvage_item_definition_id.is_empty()
				and content_catalogue.item_definition(structure.salvage_item_definition_id) == null
			):
				errors.append(
					"Structure %s references unknown salvage definition %s."
					% [structure.structure_id, structure.salvage_item_definition_id]
				)
	errors.append_array(mission_setup.validate_snapshot())
	if not mission_setup.is_finalized():
		errors.append("TacticalSession requires a finalized MissionSetupSnapshot.")
	for deployed_character_id: StringName in mission_setup.get_deployed_character_ids():
		if state_store.state.get_unit(deployed_character_id) == null:
			errors.append(
				"Finalized mission participant %s was not deployed."
				% deployed_character_id
			)

	for character: PersistentCharacterState in mission_setup.get_characters():
		var template := content_catalogue.character_template(
			character.template_id
		)
		if template == null:
			errors.append(
				"Mission character %s references unknown template %s."
				% [character.character_id, character.template_id]
			)
			continue
		errors.append_array(character.validate_state(template))

	for item: TacticalItemInstanceState in state_store.state.get_items():
		var catalogue_definition := content_catalogue.item_definition(
			item.definition_id
		)
		if catalogue_definition == null:
			errors.append(
				"Item instance %s references unknown definition %s."
				% [item.item_id, item.definition_id]
			)
		elif catalogue_definition != item.definition:
			errors.append(
				"Item instance %s does not use the catalogue definition resource."
				% item.item_id
			)

	for unit: TacticalUnitState in state_store.state.get_units():
		var snapshot := unit.resolved_character
		if snapshot == null or snapshot.template_id.is_empty():
			errors.append(
				"Unit %s has no resolved character snapshot." % unit.unit_id
			)
			continue
		if mission_setup.get_character(unit.persistent_character_id) == null:
			errors.append(
				"Unit %s does not belong to the mission setup snapshot."
				% unit.unit_id
			)
		if content_catalogue.character_template(snapshot.template_id) == null:
			errors.append(
				"Unit %s references unknown character template %s."
				% [unit.unit_id, snapshot.template_id]
			)
		if content_catalogue.defence_profile(snapshot.defence_profile_id) == null:
			errors.append(
				"Unit %s references unknown defence profile %s."
				% [unit.unit_id, snapshot.defence_profile_id]
			)
		for action_id: StringName in snapshot.innate_action_ids:
			if content_catalogue.action_definition(action_id) == null:
				errors.append(
					"Unit %s references unknown innate action %s."
					% [unit.unit_id, action_id]
				)

	return errors
