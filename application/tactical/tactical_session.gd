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
var attack_handler: RefCounted
var combat_dice_roller: RefCounted
var enemy_turn_handler: RefCounted
var player_unit_order: Array[StringName] = []
var screen_facade


func _init(
		initial_state: TacticalState,
		map_definition_value: TacticalMapDefinition,
		unit_order_value: Array[StringName],
		content_catalogue_value: ContentCatalogue,
		mission_setup_value: MissionSetupSnapshot,
		resolution_service_value: CharacterResolutionService
) -> void:
	state_store = TacticalStateStore.new(initial_state)
	map_definition = map_definition_value
	content_catalogue = content_catalogue_value
	mission_setup = (
		mission_setup_value
		if mission_setup_value != null
		else MissionSetupSnapshot.new()
	)
	character_resolution_service = resolution_service_value
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
	combat_dice_roller = TACTICAL_DICE_ROLLER_SCRIPT.new() as RefCounted
	attack_preview_query = ATTACK_PREVIEW_QUERY_SCRIPT.new() as RefCounted
	attack_preview_query.call(
		"configure",
		state_store,
		map_definition,
		content_catalogue
	)
	attack_handler = ATTACK_HANDLER_SCRIPT.new() as RefCounted
	attack_handler.call(
		"configure",
		state_store,
		map_definition,
		content_catalogue,
		event_journal,
		attack_preview_query,
		combat_dice_roller
	)
	enemy_turn_handler = ENEMY_TURN_HANDLER_SCRIPT.new() as RefCounted
	enemy_turn_handler.call(
		"configure",
		state_store,
		map_definition,
		content_catalogue,
		event_journal,
		attack_preview_query,
		attack_handler
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
		enemy_turn_handler
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
	var errors := state_store.state.validate_all(map_definition)
	if content_catalogue == null:
		errors.append("TacticalSession has no ContentCatalogue.")
		return errors

	errors.append_array(content_catalogue.validate_catalogue())
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
