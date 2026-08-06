class_name TacticalInvalidationContract
extends TacticalInvalidationFlags

## Explicit description of the authoritative tactical facts changed by one
## transaction. The diagnostic reason on TacticalChangeSet never determines
## invalidation behaviour.

var affected_unit_ids: Array[StringName] = []
var affected_item_ids: Array[StringName] = []
var moved_observer_ids: Array[StringName] = []
var affected_team_ids: Array[StringName] = []
var affected_geometry_regions: Array[Rect2i] = []
var pending_decision_changed: bool = false
var combat_events_changed: bool = false
var mission_state_changed: bool = false
var justification: String = ""


static func no_visual_change() -> TacticalInvalidationContract:
	return TacticalInvalidationContract.new()


static func token_status(unit_ids: Array = []) -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.token_status_changed = true
	contract.affected_unit_ids = _string_name_array(unit_ids)
	return contract


static func action_budget(unit_ids: Array = []) -> TacticalInvalidationContract:
	var contract := token_status(unit_ids)
	contract.action_budget_changed = true
	return contract


static func inventory(
		item_ids: Array = [],
		unit_ids: Array = []
) -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.inventory_changed = true
	contract.affected_item_ids = _string_name_array(item_ids)
	contract.affected_unit_ids = _string_name_array(unit_ids)
	return contract


static func inventory_and_budget(
		item_ids: Array = [],
		unit_ids: Array = []
) -> TacticalInvalidationContract:
	var contract := inventory(item_ids, unit_ids)
	contract.action_budget_changed = true
	contract.token_status_changed = true
	return contract


static func movement(
		unit_id: StringName,
		team_id: StringName = &""
) -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.occupancy_changed = true
	contract.visibility_changed = true
	contract.action_budget_changed = true
	contract.token_status_changed = true
	if not unit_id.is_empty():
		contract.affected_unit_ids.append(unit_id)
		contract.moved_observer_ids.append(unit_id)
	if not team_id.is_empty():
		contract.affected_team_ids.append(team_id)
	return contract


static func movement_cost(unit_id: StringName) -> TacticalInvalidationContract:
	return action_budget([unit_id])


static func observer_facing(
		unit_id: StringName,
		team_id: StringName = &""
) -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.visibility_changed = true
	contract.token_status_changed = true
	if not unit_id.is_empty():
		contract.affected_unit_ids.append(unit_id)
		contract.moved_observer_ids.append(unit_id)
	if not team_id.is_empty():
		contract.affected_team_ids.append(team_id)
	return contract


static func observer_capability(
		unit_ids: Array = [],
		team_ids: Array = []
) -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.visibility_changed = true
	contract.token_status_changed = true
	contract.affected_unit_ids = _string_name_array(unit_ids)
	contract.moved_observer_ids = contract.affected_unit_ids.duplicate()
	contract.affected_team_ids = _string_name_array(team_ids)
	return contract


static func initiative(unit_ids: Array = []) -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.initiative_changed = true
	contract.action_budget_changed = true
	contract.token_status_changed = true
	contract.affected_unit_ids = _string_name_array(unit_ids)
	return contract


static func life_state(
		unit_ids: Array = [],
		changes_occupancy: bool = false,
		changes_observer_capability: bool = false,
		team_ids: Array = []
) -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.token_status_changed = true
	contract.initiative_changed = true
	contract.occupancy_changed = changes_occupancy
	contract.visibility_changed = changes_observer_capability
	contract.affected_unit_ids = _string_name_array(unit_ids)
	if changes_observer_capability:
		contract.moved_observer_ids = contract.affected_unit_ids.duplicate()
		contract.affected_team_ids = _string_name_array(team_ids)
	return contract


static func attack(
		attacker_id: StringName,
		target_id: StringName,
		changes_inventory: bool = false
) -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.action_budget_changed = true
	contract.token_status_changed = true
	contract.combat_events_changed = true
	contract.inventory_changed = changes_inventory
	for raw_unit_id: Variant in [attacker_id, target_id]:
		var unit_id := StringName(raw_unit_id)
		if not unit_id.is_empty() and not contract.affected_unit_ids.has(unit_id):
			contract.affected_unit_ids.append(unit_id)
	return contract


static func body_action(
		actor_id: StringName,
		target_id: StringName,
		item_ids: Array = [],
		changes_inventory: bool = true,
		changes_occupancy: bool = false,
		changes_observer_capability: bool = false,
		target_team_id: StringName = &""
) -> TacticalInvalidationContract:
	var contract := life_state(
		[actor_id, target_id],
		changes_occupancy,
		changes_observer_capability,
		[target_team_id] if not target_team_id.is_empty() else []
	)
	contract.action_budget_changed = true
	contract.inventory_changed = changes_inventory
	contract.affected_item_ids = _string_name_array(item_ids)
	return contract


static func environment_interaction(
		unit_id: StringName,
		affects_inventory: bool = false
) -> TacticalInvalidationContract:
	var contract := geometry([], true, affects_inventory)
	contract.action_budget_changed = true
	contract.token_status_changed = true
	if not unit_id.is_empty():
		contract.affected_unit_ids.append(unit_id)
	return contract


static func spawn(
		unit_id: StringName,
		team_id: StringName = &""
) -> TacticalInvalidationContract:
	var contract := movement(unit_id, team_id)
	contract.action_budget_changed = false
	return contract


static func character_resolution(
		unit_id: StringName,
		team_id: StringName = &""
) -> TacticalInvalidationContract:
	var contract := observer_capability([unit_id], [team_id] if not team_id.is_empty() else [])
	contract.occupancy_changed = true
	contract.token_status_changed = true
	contract.inventory_changed = true
	return contract


static func mission_state() -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.mission_state_changed = true
	return contract


static func pending_decision(unit_ids: Array = []) -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.pending_decision_changed = true
	contract.token_status_changed = true
	contract.affected_unit_ids = _string_name_array(unit_ids)
	return contract


static func geometry(
		regions: Array = [],
		affects_visibility: bool = true,
		affects_inventory: bool = false
) -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.geometry_changed = true
	contract.environment_visuals_changed = true
	contract.visibility_changed = affects_visibility
	contract.inventory_changed = affects_inventory
	for value: Variant in regions:
		if value is Rect2i:
			contract.affected_geometry_regions.append(value)
	if contract.affected_geometry_regions.is_empty():
		contract.justification = "Geometry source IDs are carried by the transaction payload."
	return contract


static func exploration(team_ids: Array = []) -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.exploration_changed = true
	contract.affected_team_ids = _string_name_array(team_ids)
	return contract


static func full_refresh_contract(reason_text: String) -> TacticalInvalidationContract:
	var contract := TacticalInvalidationContract.new()
	contract.occupancy_changed = true
	contract.visibility_changed = true
	contract.exploration_changed = true
	contract.geometry_changed = true
	contract.environment_visuals_changed = true
	contract.inventory_changed = true
	contract.initiative_changed = true
	contract.token_status_changed = true
	contract.action_budget_changed = true
	contract.pending_decision_changed = true
	contract.combat_events_changed = true
	contract.justification = reason_text.strip_edges()
	return contract


func duplicate_contract() -> TacticalInvalidationContract:
	var result := TacticalInvalidationContract.new()
	result.occupancy_changed = occupancy_changed
	result.visibility_changed = visibility_changed
	result.exploration_changed = exploration_changed
	result.geometry_changed = geometry_changed
	result.environment_visuals_changed = environment_visuals_changed
	result.inventory_changed = inventory_changed
	result.initiative_changed = initiative_changed
	result.token_status_changed = token_status_changed
	result.action_budget_changed = action_budget_changed
	result.affected_unit_ids = affected_unit_ids.duplicate()
	result.affected_item_ids = affected_item_ids.duplicate()
	result.moved_observer_ids = moved_observer_ids.duplicate()
	result.affected_team_ids = affected_team_ids.duplicate()
	result.affected_geometry_regions = affected_geometry_regions.duplicate()
	result.pending_decision_changed = pending_decision_changed
	result.combat_events_changed = combat_events_changed
	result.mission_state_changed = mission_state_changed
	result.justification = justification
	return result


func duplicate_flags() -> TacticalInvalidationFlags:
	return duplicate_contract()


func has_explicit_scope_for_movement() -> bool:
	return not moved_observer_ids.is_empty()


func validate_contract() -> Array[String]:
	var errors: Array[String] = []
	if visibility_changed and not geometry_changed and moved_observer_ids.is_empty() and affected_team_ids.is_empty():
		errors.append("Visibility invalidation has no observer or team scope.")
	if geometry_changed and affected_geometry_regions.is_empty() and justification.is_empty():
		errors.append("Geometry invalidation has no affected region or justification.")
	return errors


static func _string_name_array(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		var item := StringName(value)
		if not item.is_empty() and not result.has(item):
			result.append(item)
	return result
