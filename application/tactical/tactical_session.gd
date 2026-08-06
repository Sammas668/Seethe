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
const MISSION_OBJECTIVE_SERVICE_SCRIPT: Script = preload(
	"res://application/missions/mission_objective_service.gd"
)
const TACTICAL_ABILITY_SERVICE_SCRIPT: Script = preload(
	"res://application/tactical/abilities/tactical_ability_service.gd"
)
const GRAPPLE_HANDLER_SCRIPT: Script = preload(
	"res://application/tactical/combat/grapple_handler.gd"
)

var state_store: TacticalStateStore
var map_definition: TacticalMapDefinition
var content_catalogue: ContentCatalogue
var mission_setup: MissionSetupSnapshot
var mission_definition: MissionDefinition
var mission_objective_service: MissionObjectiveService
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
var ability_service: TacticalAbilityService
var grapple_handler: GrappleHandler
var player_unit_order: Array[StringName] = []
var screen_facade


func _init(
		initial_state: TacticalState,
		map_definition_value: TacticalMapDefinition,
		unit_order_value: Array[StringName],
		content_catalogue_value: ContentCatalogue,
		mission_setup_value: MissionSetupSnapshot,
		resolution_service_value: CharacterResolutionService,
		mission_definition_value: MissionDefinition = null
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
	state_store.state_changed.connect(_on_session_state_changed)
	map_definition = map_definition_value
	content_catalogue = content_catalogue_value
	mission_setup = (
		mission_setup_value
		if mission_setup_value != null
		else MissionSetupSnapshot.new()
	)
	mission_definition = mission_definition_value
	if mission_setup.verify_integrity():
		if not initial_state.bind_mission_authority(
			mission_setup.mission_id,
			mission_setup.finalized_setup_hash()
		):
			push_error("TacticalSession could not bind mission authority.")
	else:
		push_error("TacticalSession requires an integrity-verified mission setup.")
	character_resolution_service = resolution_service_value
	if character_resolution_service == null:
		push_error(
			"TacticalSession requires a CharacterResolutionService supplied by composition."
		)

	event_journal = EVENT_JOURNAL_SCRIPT.new()
	player_unit_order.clear()
	for unit_id: StringName in unit_order_value:
		player_unit_order.append(unit_id)

	if mission_definition != null:
		mission_objective_service = MISSION_OBJECTIVE_SERVICE_SCRIPT.new() as MissionObjectiveService
		mission_objective_service.configure(
			state_store,
			map_definition,
			mission_definition,
			mission_setup,
			event_journal
		)

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
	if mission_setup != null and mission_setup.mission_seed >= 0:
		(combat_dice_roller as TacticalDiceRoller).set_seed(mission_setup.mission_seed)
	ability_service = TACTICAL_ABILITY_SERVICE_SCRIPT.new() as TacticalAbilityService
	ability_service.configure(
		state_store,
		map_definition,
		content_catalogue,
		event_journal,
		combat_dice_roller as TacticalDiceRoller
	)
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
		detection_service,
		visibility_service
	)
	grapple_handler = GRAPPLE_HANDLER_SCRIPT.new() as GrappleHandler
	grapple_handler.configure(
		state_store,
		map_definition,
		event_journal,
		combat_dice_roller as TacticalDiceRoller
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
		detection_service,
		visibility_service
	)
	enemy_turn_handler.call("configure_body_actions", body_action_handler)
	if enemy_turn_handler.has_method("configure_abilities"):
		enemy_turn_handler.call("configure_abilities", ability_service)
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
		reaction_service,
		ability_service,
		grapple_handler
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
	var player_units: Array[TacticalUnitState] = state.get_player_units()
	if player_units.is_empty():
		return

	# Campaign missions now bring their persistent squad identity into the
	# tactical layer. Preserve those memberships instead of replacing every
	# player's squad_id with the old team-wide fallback squad.
	var player_squads: Array[TacticalSquadState] = state.get_squads_for_team(
		&"player"
	)
	if player_squads.is_empty():
		var player_ids: Array[StringName] = []
		for unit: TacticalUnitState in player_units:
			player_ids.append(unit.unit_id)
		var fallback_squad := TacticalSquadState.new(
			TacticalSquadState.PLAYER_TEAM_SQUAD_ID,
			&"player",
			player_ids
		)
		fallback_squad.make_aware()
		state.add_squad(fallback_squad, false)
		return

	var primary_squad: TacticalSquadState = player_squads[0]
	for squad: TacticalSquadState in player_squads:
		squad.make_aware()

	for unit: TacticalUnitState in player_units:
		var assigned_squad: TacticalSquadState = state.get_squad(unit.squad_id)
		if assigned_squad == null or assigned_squad.team_id != &"player":
			primary_squad.add_member(unit.unit_id)
			unit.squad_id = primary_squad.squad_id
			continue
		assigned_squad.add_member(unit.unit_id)
		assigned_squad.make_aware()


func _on_session_state_changed(_reason: StringName) -> void:
	var pending_units: Array[TacticalUnitState] = []
	for unit: TacticalUnitState in state_store.state.get_units():
		if (
			unit != null
			and unit.character_resolution_refresh_pending
			and not unit.persistent_character_id.is_empty()
		):
			pending_units.append(unit)
	if pending_units.is_empty():
		return
	var contract := TacticalInvalidationContract.no_visual_change()
	for unit: TacticalUnitState in pending_units:
		contract.token_status_changed = true
		contract.action_budget_changed = true
		contract.affected_unit_ids.append(unit.unit_id)
	var changes := TacticalChangeSet.new(
		&"character_effect_expired",
		state_store.state.revision,
		contract
	)
	changes.deferred_deduplication_key = &"character_effect_resolution_refresh"
	for unit: TacticalUnitState in pending_units:
		var character: PersistentCharacterState = mission_setup.get_character(
			unit.persistent_character_id
		)
		if character == null:
			continue
		var snapshot: Dictionary = _character_resolution_runtime_snapshot(unit)
		changes.stage(
			Callable(self, "_refresh_expired_character_effect").bind(unit, character),
			Callable(self, "_restore_character_resolution_runtime").bind(unit, snapshot),
			"An expired character effect could not refresh the resolved sheet.",
			&"character_effect_refresh_failed"
		)
	state_store.commit_after_notifications(changes, map_definition)


func _refresh_expired_character_effect(
		unit: TacticalUnitState,
		character: PersistentCharacterState
) -> bool:
	character_resolution_service.refresh_tactical_unit(
		unit,
		character,
		_tactical_items_for_unit(unit.unit_id)
	)
	state_store.state.refresh_unit_encumbrance(unit.unit_id)
	unit.character_resolution_refresh_pending = false
	return unit.resolved_character != null


func _character_resolution_runtime_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"resolved": unit.resolved_character,
		"sheet": unit.character_sheet,
		"maximum_hp": unit.maximum_hp,
		"current_hp": unit.current_hp,
		"armour_class": unit.armour_class,
		"base_armour_class": unit.base_armour_class,
		"maximum_weight_lb": unit.inventory.maximum_weight_lb,
		"budget_maximum": unit.action_budget.maximum_turn_capacity_feet,
		"budget_remaining": unit.action_budget.remaining_turn_capacity_feet,
		"budget_spent": unit.action_budget.normal_capacity_spent_feet,
		"carried_weight_lb": unit.carried_weight_lb,
		"load_category": unit.load_category,
		"sprint_distance_feet": unit.sprint_distance_feet,
		"fast_movement_active": unit.fast_movement_active,
		"refresh_pending": unit.character_resolution_refresh_pending,
	}


func _restore_character_resolution_runtime(
		unit: TacticalUnitState,
		snapshot: Dictionary
) -> void:
	unit.resolved_character = snapshot.get("resolved") as ResolvedCharacterSnapshot
	unit.character_sheet = snapshot.get("sheet") as TacticalCharacterSheetState
	unit.maximum_hp = int(snapshot.get("maximum_hp", unit.maximum_hp))
	unit.current_hp = int(snapshot.get("current_hp", unit.current_hp))
	unit.armour_class = int(snapshot.get("armour_class", unit.armour_class))
	unit.base_armour_class = int(snapshot.get("base_armour_class", unit.base_armour_class))
	unit.inventory.maximum_weight_lb = float(
		snapshot.get("maximum_weight_lb", unit.inventory.maximum_weight_lb)
	)
	unit.action_budget.maximum_turn_capacity_feet = int(
		snapshot.get("budget_maximum", unit.action_budget.maximum_turn_capacity_feet)
	)
	unit.action_budget.remaining_turn_capacity_feet = int(
		snapshot.get("budget_remaining", unit.action_budget.remaining_turn_capacity_feet)
	)
	unit.action_budget.normal_capacity_spent_feet = int(
		snapshot.get("budget_spent", unit.action_budget.normal_capacity_spent_feet)
	)
	unit.carried_weight_lb = float(snapshot.get("carried_weight_lb", unit.carried_weight_lb))
	unit.load_category = StringName(snapshot.get("load_category", unit.load_category))
	unit.sprint_distance_feet = int(snapshot.get("sprint_distance_feet", unit.sprint_distance_feet))
	unit.fast_movement_active = bool(snapshot.get("fast_movement_active", unit.fast_movement_active))
	unit.character_resolution_refresh_pending = bool(
		snapshot.get("refresh_pending", false)
	)


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
	var previous_ability_uses: Dictionary = unit.ability_uses_remaining.duplicate(true)
	var previous_rage_rounds: int = unit.rage_rounds_remaining
	var previous_fatigued: bool = unit.fatigued_after_rage
	var previous_refresh_pending: bool = unit.character_resolution_refresh_pending
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"character_resolved",
		state_store.state.revision,
		TacticalInvalidationContract.character_resolution(
			unit.unit_id, unit.team_id
		)
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
			previous_modifier_ids,
			previous_ability_uses,
			previous_rage_rounds,
			previous_fatigued,
			previous_refresh_pending
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
	if modifier_id == &"effect.rage":
		if active:
			if not unit.begin_rage():
				return false
		else:
			unit.end_rage()
	else:
		unit.set_character_modifier_active(modifier_id, active)
	character_resolution_service.refresh_tactical_unit(
		unit,
		character,
		_tactical_items_for_unit(unit.unit_id)
	)
	state_store.state.refresh_unit_encumbrance(unit.unit_id)
	return unit.resolved_character != null


func _restore_character_modifiers(
		unit: TacticalUnitState,
		character: PersistentCharacterState,
		previous_modifier_ids: Array[StringName],
		previous_ability_uses: Dictionary,
		previous_rage_rounds: int,
		previous_fatigued: bool,
		previous_refresh_pending: bool
) -> void:
	unit.active_character_modifier_ids = previous_modifier_ids.duplicate()
	unit.restore_ability_resources(previous_ability_uses)
	unit.rage_rounds_remaining = previous_rage_rounds
	unit.fatigued_after_rage = previous_fatigued
	unit.character_resolution_refresh_pending = previous_refresh_pending
	character_resolution_service.refresh_tactical_unit(
		unit,
		character,
		_tactical_items_for_unit(unit.unit_id)
	)
	state_store.state.refresh_unit_encumbrance(unit.unit_id)


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
	if mission_definition != null:
		errors.append_array(mission_definition.validate_definition())
		if state_store.state.mission_runtime_state == null:
			errors.append("Authored TacticalSession has no MissionRuntimeState.")
		elif state_store.state.mission_runtime_state.mission_definition_id != mission_definition.mission_definition_id:
			errors.append("MissionRuntimeState does not match the authored MissionDefinition.")
	if content_catalogue == null:
		errors.append("TacticalSession has no ContentCatalogue.")
		return errors
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
