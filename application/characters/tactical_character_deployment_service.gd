class_name TacticalCharacterDeploymentService
extends RefCounted

const MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY: String = "mission_outbound_origin_item_id"

var _catalogue: ContentCatalogue
var _resolution_service: CharacterResolutionService


func _init(
		catalogue: ContentCatalogue,
		resolution_service: CharacterResolutionService
) -> void:
	_catalogue = catalogue
	_resolution_service = resolution_service


# Initial mission assembly may commit directly before a live TacticalSession exists.
# Runtime reinforcements and summons must use RuntimeSpawnHandler instead.
func deploy_character_for_assembly(
		state: TacticalState,
		character: PersistentCharacterState,
		grid_position: Vector2i,
		map_definition: TacticalMapDefinition,
		active_modifier_ids: Array[StringName] = [],
		item_states: Array[CampaignItemState] = []
) -> TacticalUnitState:
	return deploy_character(
		state,
		character,
		grid_position,
		map_definition,
		active_modifier_ids,
		item_states
	)


func deploy_character(
		state: TacticalState,
		character: PersistentCharacterState,
		grid_position: Vector2i,
		map_definition: TacticalMapDefinition,
		active_modifier_ids: Array[StringName] = [],
		item_states: Array[CampaignItemState] = []
) -> TacticalUnitState:
	var prepared: OperationResult = prepare_deployment(
		state,
		character,
		grid_position,
		map_definition,
		active_modifier_ids,
		item_states
	)
	if not prepared.success:
		push_error(prepared.message)
		return null
	var plan: TacticalCharacterDeploymentPlan = (
		prepared.data as TacticalCharacterDeploymentPlan
	)
	var committed: OperationResult = commit_deployment(
		state,
		plan,
		map_definition
	)
	if not committed.success:
		push_error(committed.message)
		return null
	return committed.data as TacticalUnitState


func prepare_deployment(
		state: TacticalState,
		character: PersistentCharacterState,
		grid_position: Vector2i,
		map_definition: TacticalMapDefinition,
		active_modifier_ids: Array[StringName] = [],
		item_states: Array[CampaignItemState] = []
) -> OperationResult:
	if state == null or character == null or _catalogue == null:
		return OperationResult.fail(
			&"deployment_input_missing",
			"A tactical state, character and content catalogue are required."
		)
	if map_definition != null:
		state.configure_knowledge_grid(map_definition.grid_size)

	var snapshot: ResolvedCharacterSnapshot = (
		_resolution_service.resolve_character(
			character,
			active_modifier_ids,
			item_states
		)
	)
	if snapshot.template_id.is_empty():
		return OperationResult.fail(
			&"deployment_resolution_failed",
			"Could not resolve persistent character %s."
			% character.character_id
		)

	var plan: TacticalCharacterDeploymentPlan = TacticalCharacterDeploymentPlan.new()
	plan.expected_state_revision = state.revision
	plan.character_id = character.character_id
	plan.unit = _build_unit(
		character,
		snapshot,
		grid_position,
		active_modifier_ids
	)

	for campaign_item: CampaignItemState in item_states:
		if (
			campaign_item == null
			or campaign_item.location == null
			or not campaign_item.location.belongs_to_character(character.character_id)
		):
			return OperationResult.fail(
				&"deployment_item_owner_invalid",
				"Character %s was given an item it does not own."
				% character.character_id
			)
		var tactical_item: TacticalItemInstanceState = _build_loadout_item(
			plan.unit,
			campaign_item
		)
		if tactical_item == null:
			return OperationResult.fail(
				&"deployment_loadout_invalid",
				"Could not prepare item %s for %s."
				% [campaign_item.item_id, character.character_id]
			)
		plan.items.append(tactical_item)

	var plan_errors: Array[String] = plan.validate_plan()
	if not plan_errors.is_empty():
		return OperationResult.fail(
			&"deployment_plan_invalid",
			plan_errors[0]
		)

	var validation_state: TacticalState = state.shallow_copy_for_assembly_validation()
	if not validation_state.add_unit(plan.unit, map_definition, false):
		return OperationResult.fail(
			&"deployment_position_invalid",
			"Could not place character %s at %s."
			% [character.character_id, grid_position]
		)
	for item: TacticalItemInstanceState in plan.items:
		if not validation_state.add_item(item, map_definition, false):
			return OperationResult.fail(
				&"deployment_item_invalid",
				"Character %s has an invalid or conflicting item %s."
				% [character.character_id, item.item_id]
			)

	var invariant_errors: Array[String] = validation_state.validate_all(
		map_definition
	)
	if not invariant_errors.is_empty():
		return OperationResult.fail(
			&"deployment_invariant_failed",
			invariant_errors[0]
		)
	return OperationResult.ok(plan, "Deployment plan is valid.")


func commit_deployment(
		state: TacticalState,
		plan: TacticalCharacterDeploymentPlan,
		map_definition: TacticalMapDefinition
) -> OperationResult:
	if state == null or plan == null:
		return OperationResult.fail(
			&"deployment_plan_missing",
			"No deployment plan was supplied."
		)
	if state.revision != plan.expected_state_revision:
		return OperationResult.fail(
			&"deployment_plan_stale",
			"The tactical state changed before deployment could commit."
		)

	var added_item_ids: Array[StringName] = []
	if not state.add_unit(plan.unit, map_definition, false):
		return OperationResult.fail(
			&"deployment_commit_unit_failed",
			"The deployment unit could not be committed."
		)

	for item: TacticalItemInstanceState in plan.items:
		if not state.add_item(item, map_definition, false):
			_rollback_deployment(state, plan.unit.unit_id, added_item_ids)
			state.revision = plan.expected_state_revision
			return OperationResult.fail(
				&"deployment_commit_item_failed",
				"Deployment rolled back because item %s could not be committed."
				% item.item_id
			)
		added_item_ids.append(item.item_id)

	var invariant_errors: Array[String] = state.validate_all(map_definition)
	if not invariant_errors.is_empty():
		_rollback_deployment(state, plan.unit.unit_id, added_item_ids)
		state.revision = plan.expected_state_revision
		return OperationResult.fail(
			&"deployment_commit_invariant_failed",
			"Deployment rolled back: %s" % invariant_errors[0]
		)

	state.revision = plan.expected_state_revision + 1
	return OperationResult.ok(plan.unit, "Character deployed atomically.")


func _build_unit(
		character: PersistentCharacterState,
		snapshot: ResolvedCharacterSnapshot,
		grid_position: Vector2i,
		active_modifier_ids: Array[StringName]
) -> TacticalUnitState:
	var unit: TacticalUnitState = TacticalUnitState.new(
		character.character_id,
		character.display_name,
		grid_position,
		snapshot.stat_value(&"turn_capacity", 30),
		character.team_id,
		snapshot.stat_value(&"maximum_hp", 1),
		snapshot.stat_value(&"armour_class", 10)
	)
	unit.persistent_character_id = character.character_id
	unit.faction_id = character.faction_id
	unit.roster_role = character.roster_role
	unit.persistence_scope = character.persistence_scope
	unit.active_character_modifier_ids = active_modifier_ids.duplicate()
	unit.footprint = snapshot.footprint
	unit.configure_inventory(
		TacticalInventoryState.new(
			float(snapshot.stat_value(&"maximum_weight_lb", 60))
		)
	)
	unit.configure_resolved_character(snapshot, false)
	unit.restore_damage_state(
		character.resolved_current_hp(unit.maximum_hp),
		character.resolved_nonlethal_damage()
	)
	return unit


func _build_loadout_item(
		unit: TacticalUnitState,
		campaign_item: CampaignItemState
) -> TacticalItemInstanceState:
	if campaign_item == null or campaign_item.location == null:
		return null
	var definition: ItemDefinition = _catalogue.item_definition(
		campaign_item.definition_id
	)
	if definition == null or campaign_item.item_id.is_empty():
		return null

	var container_kind: StringName = campaign_item.location.container_id
	if container_kind == CampaignItemLocationState.CONTAINER_WORN_UTILITY:
		container_kind = CampaignItemLocationState.CONTAINER_BACKPACK
	var tactical_location: TacticalItemLocationState = (
		TacticalItemLocationState.unit_slot(unit.unit_id, container_kind)
	)
	if container_kind in [
		TacticalInventoryState.KIND_BELT,
		TacticalInventoryState.KIND_BACKPACK,
	]:
		tactical_location = TacticalItemLocationState.unit_grid(
			unit.unit_id,
			container_kind,
			campaign_item.location.grid_position,
			campaign_item.location.is_rotated
		)

	var deployment_condition: float = campaign_item.condition
	if (
		definition.can_equip_in_slot(CampaignItemLocationState.CONTAINER_ARMOUR)
		or not definition.defence_profile_id.is_empty()
	):
		deployment_condition = 1.0
	var tactical_modifiers: Dictionary = campaign_item.persistent_modifiers.duplicate(true)
	# Preserve lineage even when a tactical action splits a stack into another
	# exact item ID (for example, attaching one rope from a stack to a captive).
	# Mission recovery uses this marker to distinguish outbound equipment from
	# genuinely recovered loot. It is stripped again during campaign commit.
	tactical_modifiers[MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY] = String(campaign_item.item_id)
	return TacticalItemInstanceState.new(
		campaign_item.item_id,
		definition,
		campaign_item.quantity,
		deployment_condition,
		tactical_location,
		tactical_modifiers
	)


func _rollback_deployment(
		state: TacticalState,
		unit_id: StringName,
		item_ids: Array[StringName]
) -> void:
	for item_id: StringName in item_ids:
		state.remove_item(item_id, false)
	state.remove_unit(unit_id, false)
	state.rebuild_unit_occupancy()
	state.rebuild_ground_item_index()
