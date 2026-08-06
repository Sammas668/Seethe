class_name EnemyPlanDependencyStamp
extends RefCounted

## Typed, allocation-light validation record for a warmed enemy plan.
## Capture may scan/sort revealed targets while the plan is prepared. Handoff
## validation performs only direct revision and actor/target field comparisons.

var unit_id: StringName = &""
var mode: StringName = &""
var geometry_revision: int = -1
var occupancy_revision: int = -1
var visibility_blocker_revision: int = -1
var perception_revision: int = -1
var actor_position: Vector2i = Vector2i(-1, -1)
var assigned_task_position: Vector2i = Vector2i(-1, -1)
var ai_profile_id: StringName = &""
var forecast_capacity_feet: int = 0
var forecast_diagonal_steps: int = 0
var maximum_capacity_feet: int = 0
var actor_life_state_id: StringName = &""
var actor_current_hp: int = 0
var actor_nonlethal_damage: int = 0
var actor_can_take_actions: bool = false
var squad_id: StringName = &""
var squad_awareness: StringName = &""
var squad_search_rounds_remaining: int = 0

var target_unit_ids: Array[StringName] = []
var target_positions: Array[Vector2i] = []
var target_life_state_ids: Array[StringName] = []
var target_current_hp: PackedInt32Array = PackedInt32Array()
var target_armour_class: PackedInt32Array = PackedInt32Array()
var target_stealth_enabled: Array[bool] = []


static func capture(
		state: TacticalState,
		unit: TacticalUnitState,
		forecast_capacity: int,
		forecast_diagonal: int,
		mode_value: StringName,
		perception_revision_value: int
) -> EnemyPlanDependencyStamp:
	if state == null or unit == null:
		return null
	var result := EnemyPlanDependencyStamp.new()
	var squad: TacticalSquadState = state.get_squad(unit.squad_id)
	result.unit_id = unit.unit_id
	result.mode = mode_value
	result.geometry_revision = state.geometry_revision()
	result.occupancy_revision = state.spatial_occupancy_revision()
	result.visibility_blocker_revision = state.spatial_visibility_blocker_revision()
	result.perception_revision = perception_revision_value
	result.actor_position = unit.grid_position
	result.assigned_task_position = unit.assigned_task_position
	result.ai_profile_id = unit.ai_profile_id
	result.forecast_capacity_feet = forecast_capacity
	result.forecast_diagonal_steps = forecast_diagonal
	result.maximum_capacity_feet = unit.action_budget.maximum_turn_capacity_feet
	result.actor_life_state_id = unit.life_state_id()
	result.actor_current_hp = unit.current_hp
	result.actor_nonlethal_damage = unit.nonlethal_damage
	result.actor_can_take_actions = unit.can_take_actions()
	result.squad_id = unit.squad_id
	result.squad_awareness = squad.awareness if squad != null else &""
	result.squad_search_rounds_remaining = (
		squad.search_rounds_remaining if squad != null else 0
	)

	var hostiles: Array[TacticalUnitState] = []
	for other: TacticalUnitState in state.get_units():
		if (
			other != null
			and other.team_id != unit.team_id
			and not other.is_defeated()
			and other.is_revealed_to_squad(unit.squad_id)
		):
			hostiles.append(other)
	hostiles.sort_custom(
		func(a: TacticalUnitState, b: TacticalUnitState) -> bool:
			return String(a.unit_id) < String(b.unit_id)
	)
	for hostile: TacticalUnitState in hostiles:
		result.target_unit_ids.append(hostile.unit_id)
		result.target_positions.append(hostile.grid_position)
		result.target_life_state_ids.append(hostile.life_state_id())
		result.target_current_hp.append(hostile.current_hp)
		result.target_armour_class.append(hostile.armour_class)
		result.target_stealth_enabled.append(hostile.stealth_enabled)
	return result


func matches(
		state: TacticalState,
		unit: TacticalUnitState,
		forecast_capacity: int,
		forecast_diagonal: int,
		mode_value: StringName,
		perception_revision_value: int
) -> bool:
	if state == null or unit == null:
		return false
	if (
		unit.unit_id != unit_id
		or mode_value != mode
		or state.geometry_revision() != geometry_revision
		or state.spatial_occupancy_revision() != occupancy_revision
		or state.spatial_visibility_blocker_revision() != visibility_blocker_revision
		or perception_revision_value != perception_revision
		or unit.grid_position != actor_position
		or unit.assigned_task_position != assigned_task_position
		or unit.ai_profile_id != ai_profile_id
		or forecast_capacity != forecast_capacity_feet
		or forecast_diagonal != forecast_diagonal_steps
		or unit.action_budget.maximum_turn_capacity_feet != maximum_capacity_feet
		or unit.life_state_id() != actor_life_state_id
		or unit.current_hp != actor_current_hp
		or unit.nonlethal_damage != actor_nonlethal_damage
		or unit.can_take_actions() != actor_can_take_actions
		or unit.squad_id != squad_id
	):
		return false
	var squad: TacticalSquadState = state.get_squad(unit.squad_id)
	var current_squad_awareness: StringName = (
		squad.awareness if squad != null else &""
	)
	var current_search_rounds: int = (
		squad.search_rounds_remaining if squad != null else 0
	)
	if (
		current_squad_awareness != squad_awareness
		or current_search_rounds != squad_search_rounds_remaining
	):
		return false
	for index: int in range(target_unit_ids.size()):
		var hostile: TacticalUnitState = state.get_unit(target_unit_ids[index])
		if hostile == null:
			return false
		if (
			hostile.grid_position != target_positions[index]
			or hostile.life_state_id() != target_life_state_ids[index]
			or hostile.current_hp != target_current_hp[index]
			or hostile.armour_class != target_armour_class[index]
			or hostile.stealth_enabled != target_stealth_enabled[index]
		):
			return false
	return true
