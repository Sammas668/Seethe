class_name TacticalState
extends RefCounted

const TacticalKnowledgeState: Script = preload(
	"res://domain/tactical/knowledge/tactical_knowledge_state.gd"
)
const TEAM_RELATIONS_SCRIPT: Script = preload(
	"res://domain/tactical/tactical_team_relations.gd"
)
const BODY_DROP_OFFSETS := [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
]

var phase_state: TacticalPhaseState = TacticalPhaseState.new()
var environment_state: TacticalEnvironmentState = TacticalEnvironmentState.new()
var knowledge_state = TacticalKnowledgeState.new()
var units_by_id: Dictionary = {}
var squads_by_id: Dictionary = {}
var items_by_id: Dictionary = {}
var unit_id_by_cell: Dictionary = {}
var body_unit_ids_by_cell: Dictionary = {}
var ground_item_ids_by_cell: Dictionary = {}
var extraction_zone_states_by_id: Dictionary = {}
var mission_resolution_locked: bool = false
var resolved_mission_result_id: StringName = &""
var revision: int = 0
var occupancy_revision: int = 0
var visibility_blocker_revision: int = 0


func configure_knowledge_grid(grid_size: Vector2i) -> void:
	knowledge_state.configure(grid_size)


func configure_environment(map_definition: TacticalMapDefinition) -> void:
	environment_state.configure_from_map(map_definition)


func geometry_revision() -> int:
	return environment_state.geometry_revision if environment_state != null else 0


func spatial_occupancy_revision() -> int:
	return occupancy_revision


func spatial_visibility_blocker_revision() -> int:
	return visibility_blocker_revision


func mark_tile_explored(team_id: StringName, tile: Vector2i) -> bool:
	return knowledge_state.mark_explored(team_id, tile)


func is_tile_explored(team_id: StringName, tile: Vector2i) -> bool:
	return knowledge_state.is_explored(team_id, tile)


func explored_tile_count(team_id: StringName) -> int:
	return knowledge_state.explored_tile_count(team_id)


func knowledge_snapshot() -> Dictionary:
	return knowledge_state.snapshot()


func restore_knowledge_snapshot(snapshot_value: Dictionary) -> void:
	knowledge_state.restore(snapshot_value)


func configure_extraction_zones(
		map_definition: TacticalMapDefinition
) -> void:
	extraction_zone_states_by_id.clear()
	if map_definition == null:
		return
	for definition: TacticalExtractionZoneDefinition in map_definition.extraction_zones:
		if definition == null or definition.zone_id.is_empty():
			continue
		extraction_zone_states_by_id[definition.zone_id] = (
			TacticalExtractionZoneState.new(
				definition.zone_id, definition.enabled_from_start, false
			)
		)


func extraction_zone_state(
		zone_id: StringName
) -> TacticalExtractionZoneState:
	return extraction_zone_states_by_id.get(zone_id) as TacticalExtractionZoneState


func set_extraction_zone_enabled(
		zone_id: StringName,
		enabled: bool
) -> bool:
	var zone: TacticalExtractionZoneState = extraction_zone_state(zone_id)
	if zone == null or zone.enabled == enabled:
		return false
	zone.enabled = enabled
	revision += 1
	return true


func set_extraction_zone_contested(
		zone_id: StringName,
		contested: bool
) -> bool:
	var zone: TacticalExtractionZoneState = extraction_zone_state(zone_id)
	if zone == null or zone.contested == contested:
		return false
	zone.contested = contested
	revision += 1
	return true


func lock_mission_resolution(result_id: StringName) -> bool:
	if mission_resolution_locked or result_id.is_empty():
		return false
	mission_resolution_locked = true
	resolved_mission_result_id = result_id
	return true


func can_accept_tactical_commands() -> bool:
	return not mission_resolution_locked


func unlock_mission_resolution_for_failed_commit() -> void:
	mission_resolution_locked = false
	resolved_mission_result_id = &""


func add_unit(
		unit_state: TacticalUnitState,
		map_definition: TacticalMapDefinition = null,
		increment_revision: bool = true
) -> bool:
	if unit_state == null or unit_state.unit_id.is_empty():
		return false
	if units_by_id.has(unit_state.unit_id):
		return false
	if not can_place_unit(
		unit_state,
		unit_state.grid_position,
		map_definition,
		unit_state.unit_id
	):
		return false

	units_by_id[unit_state.unit_id] = unit_state
	var occupancy_errors := rebuild_unit_occupancy()
	if not occupancy_errors.is_empty():
		units_by_id.erase(unit_state.unit_id)
		rebuild_unit_occupancy()
		return false

	if increment_revision:
		revision += 1
	return true


func remove_unit(
		unit_id: StringName,
		increment_revision: bool = true
) -> bool:
	if not units_by_id.has(unit_id):
		return false
	var was_active: bool = phase_state.is_active_unit(unit_id)
	var was_last_active_slot: bool = (
		was_active
		and phase_state.active_initiative_index
		== phase_state.initiative_order.size() - 1
	)
	var unit: TacticalUnitState = get_unit(unit_id)
	if unit != null and not unit.squad_id.is_empty():
		var squad: TacticalSquadState = get_squad(unit.squad_id)
		if squad != null:
			squad.member_unit_ids.erase(unit_id)
	phase_state.remove_initiative_participant(unit_id)
	units_by_id.erase(unit_id)
	rebuild_unit_occupancy()
	if was_active and phase_state.is_initiative_combat():
		if phase_state.initiative_order.is_empty():
			if phase_state.has_pending_initiative_participants():
				phase_state.round_number += 1
				phase_state.contact_round_active = false
				_prepare_new_initiative_round()
			else:
				end_initiative_combat()
		elif was_last_active_slot:
			phase_state.round_number += 1
			phase_state.contact_round_active = false
			_prepare_new_initiative_round()
		if phase_state.is_initiative_combat():
			if should_end_initiative_combat():
				end_initiative_combat()
			else:
				_sync_phase_to_active_initiative_unit()
	if increment_revision:
		revision += 1
	return true


func get_unit(unit_id: StringName) -> TacticalUnitState:
	return units_by_id.get(unit_id) as TacticalUnitState


func get_units() -> Array[TacticalUnitState]:
	var result: Array[TacticalUnitState] = []
	for value: Variant in units_by_id.values():
		var unit := value as TacticalUnitState
		if unit != null:
			result.append(unit)
	result.sort_custom(func(a: TacticalUnitState, b: TacticalUnitState) -> bool:
		return String(a.unit_id) < String(b.unit_id)
	)
	return result


func get_player_units() -> Array[TacticalUnitState]:
	var result: Array[TacticalUnitState] = []
	for unit: TacticalUnitState in get_units():
		if unit.team_id == &"player":
			result.append(unit)
	return result


func get_enemy_units() -> Array[TacticalUnitState]:
	var result: Array[TacticalUnitState] = []
	for unit: TacticalUnitState in get_units():
		if unit.team_id == &"enemy":
			result.append(unit)
	return result


func get_enemy_turn_units() -> Array[TacticalUnitState]:
	var result: Array[TacticalUnitState] = []
	for unit: TacticalUnitState in get_enemy_units():
		if unit.should_receive_enemy_turn():
			result.append(unit)
	return result


func add_squad(
		squad: TacticalSquadState,
		increment_revision: bool = true
) -> bool:
	if squad == null or squad.squad_id.is_empty():
		return false
	if squads_by_id.has(squad.squad_id):
		return false
	for unit_id: StringName in squad.member_unit_ids:
		var unit: TacticalUnitState = get_unit(unit_id)
		if unit == null or unit.team_id != squad.team_id:
			return false
	squads_by_id[squad.squad_id] = squad
	for unit_id: StringName in squad.member_unit_ids:
		get_unit(unit_id).squad_id = squad.squad_id
	if increment_revision:
		revision += 1
	return true


func get_squad(squad_id: StringName) -> TacticalSquadState:
	return squads_by_id.get(squad_id) as TacticalSquadState


func get_squads() -> Array[TacticalSquadState]:
	var result: Array[TacticalSquadState] = []
	for value: Variant in squads_by_id.values():
		var squad: TacticalSquadState = value as TacticalSquadState
		if squad != null:
			result.append(squad)
	result.sort_custom(
		func(a: TacticalSquadState, b: TacticalSquadState) -> bool:
			return String(a.squad_id) < String(b.squad_id)
	)
	return result


func get_squads_for_team(team_id: StringName) -> Array[TacticalSquadState]:
	var result: Array[TacticalSquadState] = []
	for squad: TacticalSquadState in get_squads():
		if squad.team_id == team_id:
			result.append(squad)
	return result


func primary_squad_id_for_team(team_id: StringName) -> StringName:
	var squads: Array[TacticalSquadState] = get_squads_for_team(team_id)
	return squads[0].squad_id if not squads.is_empty() else &""


func get_units_in_squad(squad_id: StringName) -> Array[TacticalUnitState]:
	var result: Array[TacticalUnitState] = []
	var squad: TacticalSquadState = get_squad(squad_id)
	if squad == null:
		return result
	for unit_id: StringName in squad.member_unit_ids:
		var unit: TacticalUnitState = get_unit(unit_id)
		if unit != null:
			result.append(unit)
	return result


func is_squad_aware(squad_id: StringName) -> bool:
	var squad: TacticalSquadState = get_squad(squad_id)
	return squad != null and squad.is_aware()


func is_unit_revealed_to_squad(
		unit_id: StringName,
		squad_id: StringName
) -> bool:
	var unit: TacticalUnitState = get_unit(unit_id)
	if unit == null:
		return false
	return unit.is_revealed_to_squad(squad_id)


func is_unit_revealed_to_team(
		unit_id: StringName,
		observer_team_id: StringName
) -> bool:
	var unit: TacticalUnitState = get_unit(unit_id)
	if unit == null:
		return false
	if unit.team_id == observer_team_id:
		return true
	if not unit.stealth_enabled:
		return true
	for squad: TacticalSquadState in get_squads_for_team(observer_team_id):
		if unit.is_revealed_to_squad(squad.squad_id):
			return true
	return false


func active_initiative_unit() -> TacticalUnitState:
	return get_unit(phase_state.active_unit_id())


func can_unit_act(unit_id: StringName) -> bool:
	if mission_resolution_locked:
		return false
	var unit: TacticalUnitState = get_unit(unit_id)
	if unit == null or not unit.can_take_actions() or unit.action_budget.ended_activation:
		return false
	if phase_state.is_side_based():
		if phase_state.is_player_phase():
			return unit.is_player_controlled()
		if phase_state.is_enemy_phase():
			return unit.is_ai_controlled()
		return false
	return phase_state.is_active_unit(unit_id)


func can_player_unit_act(unit_id: StringName) -> bool:
	var unit: TacticalUnitState = get_unit(unit_id)
	return unit != null and unit.is_player_controlled() and can_unit_act(unit_id)


func can_ai_unit_act(unit_id: StringName) -> bool:
	var unit: TacticalUnitState = get_unit(unit_id)
	return unit != null and unit.is_ai_controlled() and can_unit_act(unit_id)


func begin_initiative_combat(
		participant_ids: Array[StringName],
		initiative_totals: Dictionary
) -> bool:
	if participant_ids.is_empty():
		return false
	var order: Array[StringName] = []
	for unit_id: StringName in participant_ids:
		var unit: TacticalUnitState = get_unit(unit_id)
		if (
			unit == null
			or not unit.participates_in_initiative()
			or order.has(unit_id)
		):
			continue
		order.append(unit_id)
	_sort_initiative_ids(order, initiative_totals)
	if order.is_empty():
		return false
	# Contact-round participants preserve capacity, Quick Actions and Reactions
	# already spent during the side-based phase. Only the ended marker is lifted.
	for unit_id: StringName in order:
		get_unit(unit_id).reactivate_without_refresh()
	for squad: TacticalSquadState in get_squads():
		if (
			squad.team_id == &"enemy"
			and squad.is_aware()
			and _squad_has_member_in_ids(squad, order)
			and not _squad_has_revealed_hostile(squad)
			and not squad.last_seen_unit_ids().is_empty()
		):
			squad.begin_search()
	phase_state.begin_initiative(order, initiative_totals)
	_sync_phase_to_active_initiative_unit()
	return true


func append_initiative_participants(
		participant_ids: Array[StringName],
		initiative_totals: Dictionary
) -> void:
	var eligible: Array[StringName] = []
	for unit_id: StringName in participant_ids:
		var unit: TacticalUnitState = get_unit(unit_id)
		if (
			unit == null
			or not unit.participates_in_initiative()
			or phase_state.initiative_order.has(unit_id)
			or phase_state.pending_initiative_unit_ids.has(unit_id)
		):
			continue
		eligible.append(unit_id)
	# Newly aware squads are visible in the turn-order HUD immediately but wait
	# until the following round before their first activation.
	phase_state.queue_initiative_participants(eligible, initiative_totals)


func advance_initiative_turn() -> bool:
	if not phase_state.is_initiative_combat():
		return false
	if phase_state.initiative_order.is_empty():
		end_initiative_combat()
		return true

	var wrapped: bool = phase_state.advance_initiative_index()
	if wrapped:
		_prepare_new_initiative_round()
	_advance_past_ineligible_slots()

	if should_end_initiative_combat():
		end_initiative_combat()
		return true
	_sync_phase_to_active_initiative_unit()
	return true


func skip_ineligible_active_initiative_unit() -> bool:
	if not phase_state.is_initiative_combat():
		return false
	var active: TacticalUnitState = active_initiative_unit()
	if active != null and active.can_take_actions():
		return true
	_advance_past_ineligible_slots()
	if should_end_initiative_combat():
		end_initiative_combat()
	else:
		_sync_phase_to_active_initiative_unit()
	return true


func should_end_initiative_combat() -> bool:
	if not phase_state.is_initiative_combat():
		return false
	if phase_state.has_pending_initiative_participants():
		return false
	# Keep initiative running while a current or pending participant is actively
	# Dying so allies have a fair rescue window and the death track advances.
	var tracked_ids: Array[StringName] = phase_state.initiative_order.duplicate()
	for pending_id: StringName in phase_state.pending_initiative_unit_ids:
		if not tracked_ids.has(pending_id):
			tracked_ids.append(pending_id)
	for tracked_id: StringName in tracked_ids:
		var tracked_unit: TacticalUnitState = get_unit(tracked_id)
		if tracked_unit != null and tracked_unit.is_dying():
			return false
	for squad: TacticalSquadState in get_squads():
		if (
			squad.team_id != &"enemy"
			or not squad.is_aware()
			or not _squad_has_initiative_participant(squad)
		):
			continue
		var has_living_member: bool = false
		for member: TacticalUnitState in get_units_in_squad(squad.squad_id):
			if member != null and member.can_take_actions():
				has_living_member = true
				break
		if not has_living_member:
			continue
		if _squad_has_revealed_hostile(squad):
			return false
		if squad.is_searching():
			return false
	return true


func end_initiative_combat() -> void:
	if not phase_state.is_initiative_combat():
		return
	phase_state.end_initiative(TacticalPhaseState.PLAYER_PHASE)
	# Returning to team turns begins a fresh Player Phase. Aware squads retain
	# their last-seen memory but no longer receive unit-by-unit combat turns.
	for unit: TacticalUnitState in get_player_units():
		unit.refresh_for_new_round()
	_sync_phase_to_active_initiative_unit()


func _activate_pending_for_new_round() -> void:
	var ids: Array[StringName] = []
	var totals: Dictionary = {}
	for unit_id: StringName in phase_state.initiative_order:
		var unit: TacticalUnitState = get_unit(unit_id)
		if unit == null or not unit.participates_in_initiative():
			continue
		ids.append(unit_id)
		totals[unit_id] = phase_state.initiative_total(unit_id)
	for unit_id: StringName in phase_state.pending_initiative_unit_ids:
		var unit: TacticalUnitState = get_unit(unit_id)
		if unit == null or not unit.participates_in_initiative() or ids.has(unit_id):
			continue
		ids.append(unit_id)
		totals[unit_id] = phase_state.pending_initiative_total(unit_id)
	_sort_initiative_ids(ids, totals)
	phase_state.activate_round_order(ids, totals)


func _advance_search_rounds() -> void:
	for squad: TacticalSquadState in get_squads():
		if (
			squad.team_id != &"enemy"
			or not squad.is_aware()
			or not _squad_has_initiative_participant(squad)
		):
			continue
		if _squad_has_revealed_hostile(squad):
			squad.cancel_search()
		elif squad.is_searching():
			squad.consume_search_round()


func _squad_has_member_in_ids(
		squad: TacticalSquadState,
		unit_ids: Array[StringName]
) -> bool:
	if squad == null:
		return false
	for member_id: StringName in squad.member_unit_ids:
		if unit_ids.has(member_id):
			return true
	return false


func _squad_has_initiative_participant(squad: TacticalSquadState) -> bool:
	if squad == null:
		return false
	for member_id: StringName in squad.member_unit_ids:
		if (
			phase_state.initiative_order.has(member_id)
			or phase_state.pending_initiative_unit_ids.has(member_id)
		):
			return true
	return false


func _squad_has_revealed_hostile(squad: TacticalSquadState) -> bool:
	if squad == null:
		return false
	for target: TacticalUnitState in get_units():
		if (
			target == null
			or not target.can_take_actions()
			or not TEAM_RELATIONS_SCRIPT.are_hostile(
				squad.team_id,
				target.team_id
			)
		):
			continue
		if target.is_revealed_to_squad(squad.squad_id):
			return true
	return false


func _prepare_new_initiative_round() -> void:
	_activate_pending_for_new_round()
	_advance_search_rounds()
	for unit_id: StringName in phase_state.initiative_order:
		var participant: TacticalUnitState = get_unit(unit_id)
		if participant != null:
			participant.refresh_for_new_round()


func _advance_past_ineligible_slots() -> void:
	if not phase_state.is_initiative_combat():
		return
	var safety: int = maxi(1, phase_state.initiative_order.size() + 1)
	while safety > 0 and not phase_state.initiative_order.is_empty():
		var active: TacticalUnitState = active_initiative_unit()
		if active != null and active.participates_in_initiative():
			return
		var wrapped: bool = phase_state.advance_initiative_index()
		if wrapped:
			_prepare_new_initiative_round()
			# The new-round order filters missing, defeated and incapacitated
			# participants, so a valid active unit or an empty order now exists.
			if phase_state.initiative_order.is_empty():
				return
		safety -= 1


func _sort_initiative_ids(
		unit_ids: Array[StringName],
		totals: Dictionary
) -> void:
	unit_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			var total_a: int = int(totals.get(a, 0))
			var total_b: int = int(totals.get(b, 0))
			if total_a != total_b:
				return total_a > total_b
			var unit_a: TacticalUnitState = get_unit(a)
			var unit_b: TacticalUnitState = get_unit(b)
			var modifier_a: int = (
				unit_a.initiative_modifier() if unit_a != null else 0
			)
			var modifier_b: int = (
				unit_b.initiative_modifier() if unit_b != null else 0
			)
			if modifier_a != modifier_b:
				return modifier_a > modifier_b
			var dexterity_a: int = _dexterity_score(unit_a)
			var dexterity_b: int = _dexterity_score(unit_b)
			if dexterity_a != dexterity_b:
				return dexterity_a > dexterity_b
			return String(a) < String(b)
	)


func _dexterity_score(unit: TacticalUnitState) -> int:
	if unit == null or unit.resolved_character == null:
		return 10
	return unit.resolved_character.ability_score("DEX")


func _sync_phase_to_active_initiative_unit() -> void:
	if phase_state.is_side_based():
		return
	var unit: TacticalUnitState = active_initiative_unit()
	if unit == null:
		phase_state.current_phase = TacticalPhaseState.WORLD_PHASE
	elif unit.is_player_controlled():
		phase_state.current_phase = TacticalPhaseState.PLAYER_PHASE
	elif unit.is_ai_controlled():
		phase_state.current_phase = TacticalPhaseState.ENEMY_PHASE
	else:
		phase_state.current_phase = TacticalPhaseState.WORLD_PHASE


func occupied_cells_for_unit(
		unit: TacticalUnitState
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null:
		return result
	return occupied_cells_for_unit_at(unit, unit.grid_position)


func occupied_cells_for_unit_at(
		unit: TacticalUnitState,
		origin: Vector2i
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null:
		return result
	if unit.footprint.x <= 0 or unit.footprint.y <= 0:
		return result

	for y: int in range(unit.footprint.y):
		for x: int in range(unit.footprint.x):
			result.append(origin + Vector2i(x, y))
	return result


func can_place_unit(
		unit: TacticalUnitState,
		destination: Vector2i,
		map_definition: TacticalMapDefinition = null,
		except_unit_id: StringName = &""
) -> bool:
	if unit == null:
		return false
	if unit.footprint.x <= 0 or unit.footprint.y <= 0:
		return false

	for cell: Vector2i in occupied_cells_for_unit_at(unit, destination):
		if map_definition != null:
			if not map_definition.is_inside(cell):
				return false
			if map_definition.is_blocked(cell):
				return false
		var occupying_id := StringName(unit_id_by_cell.get(cell, &""))
		if not occupying_id.is_empty() and occupying_id != except_unit_id:
			return false
	return true


func rebuild_unit_occupancy() -> Array[String]:
	var previous_standing_signature: int = hash(unit_id_by_cell)
	var errors: Array[String] = []
	unit_id_by_cell.clear()
	body_unit_ids_by_cell.clear()

	for unit: TacticalUnitState in get_units():
		if not unit.blocks_standing_space():
			var body_item: TacticalItemInstanceState = body_item_for_unit(unit.unit_id)
			if body_item != null and body_item.location != null:
				var body_cell: Vector2i = body_ground_cell(body_item)
				if body_cell.x >= 0:
					var body_ids: Array[StringName] = []
					for existing: Variant in body_unit_ids_by_cell.get(body_cell, []):
						body_ids.append(StringName(existing))
					body_ids.append(unit.unit_id)
					body_unit_ids_by_cell[body_cell] = body_ids
			continue
		for cell: Vector2i in occupied_cells_for_unit(unit):
			if unit_id_by_cell.has(cell):
				errors.append(
					"Units %s and %s overlap at %s."
					% [unit_id_by_cell[cell], unit.unit_id, cell]
				)
				continue
			unit_id_by_cell[cell] = unit.unit_id

	var current_standing_signature: int = hash(unit_id_by_cell)
	if current_standing_signature != previous_standing_signature:
		occupancy_revision += 1
		visibility_blocker_revision += 1
	return errors


func set_unit_position(
		unit_id: StringName,
		destination: Vector2i,
		map_definition: TacticalMapDefinition = null,
		increment_revision: bool = true
) -> bool:
	var unit := get_unit(unit_id)
	if unit == null:
		return false
	if not can_place_unit(unit, destination, map_definition, unit_id):
		return false

	var previous_position := unit.grid_position
	unit.grid_position = destination
	var occupancy_errors := rebuild_unit_occupancy()
	if not occupancy_errors.is_empty():
		unit.grid_position = previous_position
		rebuild_unit_occupancy()
		return false

	if increment_revision:
		revision += 1
	return true


func get_unit_at_tile(
		tile: Vector2i,
		except_unit_id: StringName = &""
) -> TacticalUnitState:
	var unit_id := StringName(unit_id_by_cell.get(tile, &""))
	if unit_id.is_empty() or unit_id == except_unit_id:
		return null
	return get_unit(unit_id)


func body_item_for_unit(unit_id: StringName) -> TacticalItemInstanceState:
	var unit: TacticalUnitState = get_unit(unit_id)
	if unit == null or unit.body_item_id.is_empty():
		return null
	var item: TacticalItemInstanceState = get_item(unit.body_item_id)
	return item if item != null and item.is_body() else null


func body_unit_for_item(item_id: StringName) -> TacticalUnitState:
	var item: TacticalItemInstanceState = get_item(item_id)
	if item == null or not item.is_body():
		return null
	return get_unit(item.linked_unit_id)


func body_ground_cell(item: TacticalItemInstanceState) -> Vector2i:
	if item == null or item.location == null or not item.is_body():
		return Vector2i(-1, -1)
	if item.location.location_type == TacticalItemLocationState.LOCATION_TACTICAL_GROUND:
		return item.location.map_position
	if (
		item.location.location_type == TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT
		and item.location.transport_mode == &"dragging"
	):
		return item.location.map_position
	return Vector2i(-1, -1)


func should_body_token_be_visible(
		body_item: TacticalItemInstanceState
) -> bool:
	if body_item == null or body_item.location == null or not body_item.is_body():
		return false
	if (
		body_item.location.location_type
		== TacticalItemLocationState.LOCATION_TACTICAL_GROUND
	):
		return true
	return (
		body_item.location.location_type
		== TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT
		and body_item.location.transport_mode == &"dragging"
	)


func get_packed_body_items(
		carrier_unit_id: StringName
) -> Array[TacticalItemInstanceState]:
	var result: Array[TacticalItemInstanceState] = []
	if carrier_unit_id.is_empty():
		return result
	for item: TacticalItemInstanceState in get_items():
		if item == null or not item.is_body() or item.location == null:
			continue
		if item.location.owner_id != carrier_unit_id:
			continue
		if (
			item.location.location_type
			!= TacticalItemLocationState.LOCATION_UNIT_INVENTORY
		):
			continue
		result.append(item)
	result.sort_custom(
		func(a: TacticalItemInstanceState, b: TacticalItemInstanceState) -> bool:
			return String(a.item_id) < String(b.item_id)
	)
	return result


func dragged_body_cell_snapshot(unit_id: StringName) -> Dictionary:
	var result: Dictionary = {}
	for hand_kind: StringName in [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
	]:
		var item: TacticalItemInstanceState = get_hand_item(unit_id, hand_kind)
		if (
			item == null
			or not item.is_body()
			or item.location == null
			or item.location.transport_mode != &"dragging"
		):
			continue
		result[item.item_id] = item.location.map_position
	return result


func move_dragged_bodies_to_cell(
		unit_id: StringName,
		cell: Vector2i
) -> bool:
	var changed: bool = false
	for hand_kind: StringName in [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
	]:
		var item: TacticalItemInstanceState = get_hand_item(unit_id, hand_kind)
		if (
			item == null
			or not item.is_body()
			or item.location == null
			or item.location.transport_mode != &"dragging"
		):
			continue
		item.location.map_position = cell
		var body_unit: TacticalUnitState = get_unit(item.linked_unit_id)
		if body_unit != null:
			body_unit.grid_position = cell
		changed = true
	if changed:
		rebuild_unit_occupancy()
	return true


func restore_dragged_body_cells(snapshot: Dictionary) -> void:
	var changed: bool = false
	for item_id_value: Variant in snapshot.keys():
		var item_id := StringName(item_id_value)
		var item: TacticalItemInstanceState = get_item(item_id)
		if (
			item == null
			or not item.is_body()
			or item.location == null
			or item.location.transport_mode != &"dragging"
		):
			continue
		var cell: Vector2i = snapshot[item_id_value]
		item.location.map_position = cell
		var body_unit: TacticalUnitState = get_unit(item.linked_unit_id)
		if body_unit != null:
			body_unit.grid_position = cell
		changed = true
	if changed:
		rebuild_unit_occupancy()


func has_ground_body_at(tile: Vector2i) -> bool:
	return not body_unit_ids_by_cell.get(tile, []).is_empty()


func body_is_accessible_to_unit(
		body_item: TacticalItemInstanceState,
		actor: TacticalUnitState
) -> bool:
	if body_item == null or actor == null or not body_item.is_body():
		return false
	var cell: Vector2i = body_ground_cell(body_item)
	if cell.x < 0:
		return body_item.location.owner_id == actor.unit_id
	var minimum := actor.grid_position - Vector2i.ONE
	var maximum := actor.grid_position + actor.footprint
	return (
		cell.x >= minimum.x
		and cell.y >= minimum.y
		and cell.x <= maximum.x
		and cell.y <= maximum.y
	)


func effective_item_weight(item: TacticalItemInstanceState) -> float:
	if item == null:
		return 0.0
	if not item.is_body():
		return item.weight_lb
	var body_unit: TacticalUnitState = get_unit(item.linked_unit_id)
	if body_unit == null:
		return item.weight_lb
	var total: float = body_unit.body_weight_lb
	for carried: TacticalItemInstanceState in get_items():
		if carried.item_id == item.item_id or carried.location == null:
			continue
		if carried.location.owner_id != body_unit.unit_id:
			continue
		if carried.location.location_type in [
			TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
			TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
		]:
			total += carried.weight_lb
	return total


func item_counts_as_carried_by(
		item: TacticalItemInstanceState,
		unit_id: StringName,
		location_override: TacticalItemLocationState = null
) -> bool:
	if item == null:
		return false
	var location: TacticalItemLocationState = (
		location_override if location_override != null else item.location
	)
	if location == null or location.owner_id != unit_id:
		return false
	if location.location_type not in [
		TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
		TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
	]:
		return false
	# A body in a Hand is dragged along the floor. It occupies the Hand but does
	# not add its full mass to the carrier's packed/equipped load.
	return not (item.is_body() and location.transport_mode == &"dragging")


func maximum_drag_weight(unit: TacticalUnitState) -> float:
	if unit == null or unit.inventory == null:
		return 0.0
	# D&D 3.5-style push/drag capacity: five times maximum carried load.
	return unit.inventory.maximum_weight_lb * 5.0


func synchronise_body_items(
		map_definition: TacticalMapDefinition = null
) -> void:
	# Reconcile item representation from committed character state. This is
	# deterministic, so rollback can call it again after life-state restoration.
	# Body creation, carried-body drops and recovery all occur before invariants
	# inspect occupancy or item ownership.
	for unit: TacticalUnitState in get_units():
		var body_item: TacticalItemInstanceState = body_item_for_unit(unit.unit_id)
		if unit.requires_body_item():
			if body_item == null:
				var body_id := StringName("body.%s" % unit.unit_id)
				if items_by_id.has(body_id):
					body_item = get_item(body_id)
				else:
					body_item = TacticalItemInstanceState.create_body(
						unit,
						TacticalItemLocationState.ground(
							unit.grid_position,
							"Body"
						)
					)
					items_by_id[body_item.item_id] = body_item
				unit.body_item_id = body_item.item_id
			body_item.display_name_override = "%s's Body" % unit.display_name
			body_item.weight_override_lb = unit.body_weight_lb
			body_item.footprint_override = unit.body_inventory_footprint()

	_release_bodies_from_incapacitated_carriers(map_definition)

	for unit: TacticalUnitState in get_units():
		var body_item: TacticalItemInstanceState = body_item_for_unit(unit.unit_id)
		if unit.has_fallen_body_state() or unit.restrained:
			if body_item == null:
				continue
			body_item.display_name_override = "%s's Body" % unit.display_name
			body_item.weight_override_lb = unit.body_weight_lb
			body_item.footprint_override = unit.body_inventory_footprint()
			unit.set_awaiting_body_placement(false)
			var body_cell: Vector2i = body_ground_cell(body_item)
			if body_cell.x >= 0:
				unit.grid_position = body_cell
			continue

		# Healing can make the linked character conscious while its body item is
		# packed, dragged beneath another unit, or otherwise unable to stand. Keep
		# the body item authoritative until it reaches a legal ground cell.
		if body_item == null:
			unit.body_item_id = &""
			unit.set_awaiting_body_placement(false)
			continue
		var recovery_cell: Vector2i = body_ground_cell(body_item)
		if (
			recovery_cell.x >= 0
			and can_place_unit(unit, recovery_cell, map_definition, unit.unit_id)
		):
			unit.grid_position = recovery_cell
			items_by_id.erase(body_item.item_id)
			unit.body_item_id = &""
			unit.set_awaiting_body_placement(false)
		else:
			unit.set_awaiting_body_placement(true)
	rebuild_ground_item_index()
	rebuild_unit_occupancy()


func _release_bodies_from_incapacitated_carriers(
		map_definition: TacticalMapDefinition
) -> void:
	for carrier: TacticalUnitState in get_units():
		if carrier == null or not carrier.has_fallen_body_state():
			continue
		var used_drop_cells: Dictionary = {}
		_release_dragged_bodies_for_carrier(
			carrier,
			map_definition,
			used_drop_cells
		)
		for body_item: TacticalItemInstanceState in get_packed_body_items(
			carrier.unit_id
		):
			var drop_cell: Vector2i = _choose_body_drop_cell(
				body_item,
				carrier.grid_position,
				map_definition,
				used_drop_cells
			)
			_place_body_item_on_ground(body_item, drop_cell)
			used_drop_cells[drop_cell] = true


func _release_dragged_bodies_for_carrier(
		carrier: TacticalUnitState,
		map_definition: TacticalMapDefinition,
		used_drop_cells: Dictionary
) -> void:
	for hand_kind: StringName in [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
	]:
		var body_item: TacticalItemInstanceState = get_hand_item(
			carrier.unit_id,
			hand_kind
		)
		if (
			body_item == null
			or not body_item.is_body()
			or body_item.location == null
			or body_item.location.transport_mode != &"dragging"
		):
			continue
		var current_cell: Vector2i = body_item.location.map_position
		var release_cell: Vector2i = current_cell
		if not _body_can_rest_at(body_item, release_cell, map_definition):
			release_cell = _choose_body_drop_cell(
				body_item,
				carrier.grid_position,
				map_definition,
				used_drop_cells
			)
		_place_body_item_on_ground(body_item, release_cell)
		used_drop_cells[release_cell] = true


func _choose_body_drop_cell(
		body_item: TacticalItemInstanceState,
		carrier_cell: Vector2i,
		map_definition: TacticalMapDefinition,
		used_drop_cells: Dictionary
) -> Vector2i:
	var legal_cells: Array[Vector2i] = []
	for offset_value: Vector2i in BODY_DROP_OFFSETS:
		var candidate: Vector2i = carrier_cell + offset_value
		if _body_can_rest_at(body_item, candidate, map_definition):
			legal_cells.append(candidate)
	for candidate: Vector2i in legal_cells:
		if not used_drop_cells.has(candidate):
			return candidate
	if not legal_cells.is_empty():
		return legal_cells[0]
	# The carrier's own tile was legal immediately before incapacitation and is
	# the deterministic no-loss fallback. Bodies and standing units may share it.
	return carrier_cell


func _body_can_rest_at(
		body_item: TacticalItemInstanceState,
		origin: Vector2i,
		map_definition: TacticalMapDefinition
) -> bool:
	if body_item == null or origin.x < 0 or origin.y < 0:
		return false
	if map_definition == null:
		return true
	var linked_unit: TacticalUnitState = get_unit(body_item.linked_unit_id)
	var body_footprint: Vector2i = (
		linked_unit.footprint
		if linked_unit != null
		else Vector2i.ONE
	)
	for y: int in range(maxi(1, body_footprint.y)):
		for x: int in range(maxi(1, body_footprint.x)):
			var cell: Vector2i = origin + Vector2i(x, y)
			if not map_definition.is_inside(cell):
				return false
			if map_definition.is_blocked(cell):
				return false
	return true


func _place_body_item_on_ground(
		body_item: TacticalItemInstanceState,
		cell: Vector2i
) -> void:
	if body_item == null:
		return
	body_item.location = TacticalItemLocationState.ground(cell, "Body")
	var linked_unit: TacticalUnitState = get_unit(body_item.linked_unit_id)
	if linked_unit != null:
		linked_unit.grid_position = cell




func body_item_representation_snapshot() -> Dictionary:
	var body_items: Dictionary = {}
	for item: TacticalItemInstanceState in get_items():
		if not item.is_body():
			continue
		body_items[item.item_id] = {
			"item": item,
			"location": item.location.clone() if item.location != null else null,
		}
	var unit_body_ids: Dictionary = {}
	var unit_body_positions: Dictionary = {}
	var unit_awaiting_placement: Dictionary = {}
	for unit: TacticalUnitState in get_units():
		unit_body_ids[unit.unit_id] = unit.body_item_id
		unit_body_positions[unit.unit_id] = unit.grid_position
		unit_awaiting_placement[unit.unit_id] = unit.awaiting_body_placement
	return {
		"body_items": body_items,
		"unit_body_ids": unit_body_ids,
		"unit_body_positions": unit_body_positions,
		"unit_awaiting_placement": unit_awaiting_placement,
	}


func restore_body_item_representation(snapshot: Dictionary) -> void:
	var current_body_ids: Array[StringName] = []
	for item: TacticalItemInstanceState in get_items():
		if item.is_body():
			current_body_ids.append(item.item_id)
	for body_id: StringName in current_body_ids:
		items_by_id.erase(body_id)

	var body_items: Dictionary = snapshot.get("body_items", {})
	for key: Variant in body_items.keys():
		var entry: Dictionary = body_items[key]
		var item := entry.get("item") as TacticalItemInstanceState
		var location := entry.get("location") as TacticalItemLocationState
		if item == null:
			continue
		item.location = location.clone() if location != null else null
		items_by_id[item.item_id] = item

	var unit_body_ids: Dictionary = snapshot.get("unit_body_ids", {})
	var unit_body_positions: Dictionary = snapshot.get("unit_body_positions", {})
	var unit_awaiting_placement: Dictionary = snapshot.get(
		"unit_awaiting_placement",
		{}
	)
	for unit: TacticalUnitState in get_units():
		unit.body_item_id = StringName(unit_body_ids.get(unit.unit_id, &""))
		var restored_position: Vector2i = unit_body_positions.get(
			unit.unit_id,
			unit.grid_position
		)
		unit.grid_position = restored_position
		unit.set_awaiting_body_placement(bool(
			unit_awaiting_placement.get(
				unit.unit_id,
				unit.awaiting_body_placement
			)
		))
	rebuild_ground_item_index()
	rebuild_unit_occupancy()


func add_item(
		item_state: TacticalItemInstanceState,
		map_definition: TacticalMapDefinition = null,
		increment_revision: bool = true
) -> bool:
	if item_state == null or item_state.item_id.is_empty():
		return false
	if items_by_id.has(item_state.item_id):
		return false
	if item_state.definition == null or item_state.definition_id.is_empty():
		return false

	items_by_id[item_state.item_id] = item_state
	rebuild_ground_item_index()
	var errors := validate_item_invariants(map_definition)
	if not errors.is_empty():
		items_by_id.erase(item_state.item_id)
		rebuild_ground_item_index()
		return false

	if increment_revision:
		revision += 1
	return true


func remove_item(
		item_id: StringName,
		increment_revision: bool = true
) -> bool:
	if not items_by_id.has(item_id):
		return false
	items_by_id.erase(item_id)
	rebuild_ground_item_index()
	if increment_revision:
		revision += 1
	return true


func get_item(item_id: StringName) -> TacticalItemInstanceState:
	return items_by_id.get(item_id) as TacticalItemInstanceState


func get_items() -> Array[TacticalItemInstanceState]:
	var result: Array[TacticalItemInstanceState] = []
	for value: Variant in items_by_id.values():
		var item := value as TacticalItemInstanceState
		if item != null:
			result.append(item)
	result.sort_custom(func(a: TacticalItemInstanceState, b: TacticalItemInstanceState) -> bool:
		return String(a.item_id) < String(b.item_id)
	)
	return result


func move_item(
		item_id: StringName,
		target_location: TacticalItemLocationState,
		increment_revision: bool = true
) -> bool:
	var item := get_item(item_id)
	if item == null or target_location == null:
		return false
	item.location = target_location.clone()
	rebuild_ground_item_index()
	if increment_revision:
		revision += 1
	return true


func rebuild_ground_item_index() -> void:
	ground_item_ids_by_cell.clear()
	for item: TacticalItemInstanceState in get_items():
		if item.location == null:
			continue
		if item.location.location_type != TacticalItemLocationState.LOCATION_TACTICAL_GROUND:
			continue
		var cell := item.location.map_position
		var ids: Array[StringName] = []
		var existing_values: Array = ground_item_ids_by_cell.get(cell, [])
		for existing_value: Variant in existing_values:
			ids.append(StringName(existing_value))
		ids.append(item.item_id)
		ground_item_ids_by_cell[cell] = ids


func get_ground_items() -> Array[TacticalItemInstanceState]:
	var result: Array[TacticalItemInstanceState] = []
	for item: TacticalItemInstanceState in get_items():
		if (
			item.location != null
			and item.location.location_type
			== TacticalItemLocationState.LOCATION_TACTICAL_GROUND
		):
			result.append(item)
	return result


func get_accessible_ground_items(
		unit: TacticalUnitState
) -> Array[TacticalItemInstanceState]:
	var result: Array[TacticalItemInstanceState] = []
	if unit == null:
		return result

	for y: int in range(
		unit.grid_position.y - 1,
		unit.grid_position.y + unit.footprint.y + 1
	):
		for x: int in range(
			unit.grid_position.x - 1,
			unit.grid_position.x + unit.footprint.x + 1
		):
			var cell := Vector2i(x, y)
			var indexed_values: Array = ground_item_ids_by_cell.get(cell, [])
			for indexed_value: Variant in indexed_values:
				var item := get_item(StringName(indexed_value))
				if item != null:
					result.append(item)

	result.sort_custom(func(a: TacticalItemInstanceState, b: TacticalItemInstanceState) -> bool:
		if a.source_label == b.source_label:
			return a.display_name < b.display_name
		return a.source_label < b.source_label
	)
	return result


func item_is_accessible_to_unit(
		item: TacticalItemInstanceState,
		unit: TacticalUnitState
) -> bool:
	if item == null or unit == null or item.location == null:
		return false
	if item.location.location_type != TacticalItemLocationState.LOCATION_TACTICAL_GROUND:
		return false

	var minimum := unit.grid_position - Vector2i.ONE
	var maximum := unit.grid_position + unit.footprint
	var position := item.location.map_position
	return (
		position.x >= minimum.x
		and position.y >= minimum.y
		and position.x <= maximum.x
		and position.y <= maximum.y
	)


func get_unit_container_items(
		unit_id: StringName,
		container_kind: StringName
) -> Array[TacticalItemInstanceState]:
	var result: Array[TacticalItemInstanceState] = []
	for item: TacticalItemInstanceState in get_items():
		if item.location == null:
			continue
		if item.location.owner_id != unit_id:
			continue
		if item.location.container_kind != container_kind:
			continue
		if item.location.location_type not in [
			TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
			TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
		]:
			continue
		result.append(item)

	result.sort_custom(func(a: TacticalItemInstanceState, b: TacticalItemInstanceState) -> bool:
		if a.location.grid_position.y == b.location.grid_position.y:
			if a.location.grid_position.x == b.location.grid_position.x:
				return String(a.item_id) < String(b.item_id)
			return a.location.grid_position.x < b.location.grid_position.x
		return a.location.grid_position.y < b.location.grid_position.y
	)
	return result


func get_hand_item(
		unit_id: StringName,
		hand_kind: StringName
) -> TacticalItemInstanceState:
	var items := get_unit_container_items(unit_id, hand_kind)
	return items[0] if not items.is_empty() else null


func calculated_carried_weight(unit_id: StringName) -> float:
	var total := 0.0
	for item: TacticalItemInstanceState in get_items():
		if item_counts_as_carried_by(item, unit_id):
			total += effective_item_weight(item)
	return total


func hand_display_name(unit_id: StringName, hand_kind: StringName) -> String:
	var primary := get_hand_item(
		unit_id,
		TacticalInventoryState.KIND_PRIMARY_HAND
	)
	if (
		hand_kind == TacticalInventoryState.KIND_SECONDARY_HAND
		and primary != null
		and primary.two_handed
	):
		return "Reserved by %s" % primary.display_name

	var item := get_hand_item(unit_id, hand_kind)
	if item != null and item.is_body():
		return "Dragging %s" % item.display_name
	return item.display_name if item != null else "Empty"


func container_summary(unit_id: StringName, container_kind: StringName) -> String:
	var items := get_unit_container_items(unit_id, container_kind)
	if items.is_empty():
		return "Empty"
	var names: Array[String] = []
	for item: TacticalItemInstanceState in items:
		names.append(item.compact_display_name())
	return ", ".join(PackedStringArray(names))


func granted_action_ids_for_unit(unit_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var seen: Dictionary = {}
	var unit := get_unit(unit_id)
	if unit == null:
		return result

	for action_id: StringName in unit.resolved_character.innate_action_ids:
		if not seen.has(action_id):
			seen[action_id] = true
			result.append(action_id)

	for hand_kind: StringName in [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
	]:
		var item := get_hand_item(unit_id, hand_kind)
		if item == null or item.definition == null:
			continue
		for action_id: StringName in item.definition.granted_action_ids:
			if not seen.has(action_id):
				seen[action_id] = true
				result.append(action_id)

	return result


func can_place_item(
		unit: TacticalUnitState,
		item: TacticalItemInstanceState,
		container_kind: StringName,
		position: Vector2i,
		ignore_item_id: StringName = &""
) -> bool:
	if unit == null or item == null:
		return false
	if container_kind == TacticalInventoryState.KIND_BELT and not item.belt_allowed:
		return false
	if container_kind == TacticalInventoryState.KIND_BACKPACK and not item.backpack_allowed:
		return false
	if container_kind not in [
		TacticalInventoryState.KIND_BELT,
		TacticalInventoryState.KIND_BACKPACK,
	]:
		return false

	var width := unit.inventory.container_width(container_kind)
	var height := unit.inventory.container_height(container_kind)
	if position.x < 0 or position.y < 0:
		return false
	if position.x + item.footprint.x > width:
		return false
	if position.y + item.footprint.y > height:
		return false

	var proposed := Rect2i(position, item.footprint)
	for other: TacticalItemInstanceState in get_unit_container_items(
		unit.unit_id,
		container_kind
	):
		if other.item_id == ignore_item_id:
			continue
		var occupied := Rect2i(other.location.grid_position, other.footprint)
		if proposed.intersects(occupied):
			return false
	return true


func first_fit(
		unit: TacticalUnitState,
		item: TacticalItemInstanceState,
		container_kind: StringName,
		ignore_item_id: StringName = &""
) -> Vector2i:
	if unit == null or item == null:
		return Vector2i(-1, -1)
	var width := unit.inventory.container_width(container_kind)
	var height := unit.inventory.container_height(container_kind)
	for y: int in range(height):
		for x: int in range(width):
			var candidate := Vector2i(x, y)
			if can_place_item(
				unit,
				item,
				container_kind,
				candidate,
				ignore_item_id
			):
				return candidate
	return Vector2i(-1, -1)


func validate_unit_invariants(
		map_definition: TacticalMapDefinition
) -> Array[String]:
	var errors: Array[String] = []
	var occupied: Dictionary = {}

	for key: Variant in units_by_id.keys():
		var unit_id := StringName(key)
		var unit := get_unit(unit_id)
		if unit == null:
			errors.append("Unit registry contains a null entry: %s" % unit_id)
			continue
		if unit.unit_id != unit_id:
			errors.append("Unit registry key does not match unit ID: %s" % unit_id)
		if unit.footprint.x <= 0 or unit.footprint.y <= 0:
			errors.append("Unit %s has a non-positive footprint." % unit_id)
			continue
		if unit.inventory == null:
			errors.append("Unit %s has no inventory state." % unit_id)
		if unit.action_budget == null:
			errors.append("Unit %s has no action budget." % unit_id)
		if unit.nonlethal_damage < 0:
			errors.append("Unit %s has negative nonlethal damage." % unit_id)
		if unit.dying_successes < 0 or unit.dying_successes > 3:
			errors.append("Unit %s has an invalid Dying success count." % unit_id)
		if unit.dying_failures < 0 or unit.dying_failures > 3:
			errors.append("Unit %s has an invalid Dying failure count." % unit_id)
		if unit.combat_state not in [
			TacticalUnitState.COMBAT_STATE_ACTIVE,
			TacticalUnitState.COMBAT_STATE_DEFEATED,
		]:
			errors.append("Unit %s has an unknown combat state." % unit_id)
		if unit.is_dead() and unit.current_hp > unit.death_threshold_hp():
			# Three failed Dying checks may kill above the negative-Con threshold.
			if unit.dying_failures < 3:
				errors.append("Unit %s is Dead without threshold damage or three failures." % unit_id)
		if unit.is_stable_unconscious() and unit.current_hp >= 0:
			errors.append("Unit %s is Stable without negative HP." % unit_id)
		if unit.is_dying() and unit.stable:
			errors.append("Unit %s is both Dying and Stable." % unit_id)
		if unit.is_defeated() and unit.combat_state != TacticalUnitState.COMBAT_STATE_DEFEATED:
			errors.append("Unit %s is downed but lacks the compatibility Defeated state." % unit_id)
		if not unit.is_defeated() and unit.combat_state == TacticalUnitState.COMBAT_STATE_DEFEATED:
			errors.append("Unit %s is marked Defeated while still able to act." % unit_id)
		if unit.controller_type not in [
			TacticalUnitState.CONTROLLER_PLAYER,
			TacticalUnitState.CONTROLLER_AI,
			TacticalUnitState.CONTROLLER_WORLD,
		]:
			errors.append("Unit %s has an unknown controller type." % unit_id)
		if unit.turn_behavior not in [
			TacticalUnitState.TURN_BEHAVIOR_STANDARD,
			TacticalUnitState.TURN_BEHAVIOR_AUTO_PASS,
			TacticalUnitState.TURN_BEHAVIOR_NONE,
		]:
			errors.append("Unit %s has an unknown turn behaviour." % unit_id)
		if unit.is_player_controlled() and unit.team_id != &"player":
			errors.append("Unit %s is player-controlled but not on the player team." % unit_id)
		if unit.participates_in_enemy_turn and unit.team_id != &"enemy":
			errors.append("Unit %s receives Enemy Turns but is not on the enemy team." % unit_id)
		if unit.facing_direction == Vector2i.ZERO:
			errors.append("Unit %s has no facing direction." % unit_id)
		var reveal_seen: Dictionary = {}
		for reveal_squad_id: StringName in unit.revealed_to_squad_ids:
			if reveal_seen.has(reveal_squad_id):
				errors.append("Unit %s repeats revelation for squad %s." % [unit_id, reveal_squad_id])
			reveal_seen[reveal_squad_id] = true
			if get_squad(reveal_squad_id) == null:
				errors.append("Unit %s references missing revealing squad %s." % [unit_id, reveal_squad_id])

		if unit.blocks_standing_space():
			for cell: Vector2i in occupied_cells_for_unit(unit):
				if map_definition != null:
					if not map_definition.is_inside(cell):
						errors.append("Unit %s occupies out-of-bounds cell %s." % [unit_id, cell])
					elif map_definition.is_blocked(cell):
						errors.append("Unit %s occupies blocked cell %s." % [unit_id, cell])
				if occupied.has(cell):
					errors.append(
						"Units %s and %s overlap at %s."
						% [occupied[cell], unit_id, cell]
					)
				else:
					occupied[cell] = unit_id
		elif unit.requires_body_item() and body_item_for_unit(unit_id) == null:
			errors.append("Downed unit %s has no linked body item." % unit_id)
		if unit.has_fallen_body_state() and not get_packed_body_items(unit_id).is_empty():
			errors.append(
				"Downed unit %s still contains a packed body item." % unit_id
			)

	for cell: Variant in unit_id_by_cell.keys():
		var indexed_id := StringName(unit_id_by_cell[cell])
		if not occupied.has(cell):
			errors.append("Occupancy index contains stale cell %s." % cell)
		elif StringName(occupied[cell]) != indexed_id:
			errors.append("Occupancy index disagrees at cell %s." % cell)

	return errors


func validate_item_invariants(
		map_definition: TacticalMapDefinition = null
) -> Array[String]:
	var errors: Array[String] = []
	var occupied_by_unit_container: Dictionary = {}
	var valid_location_types := [
		TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
		TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
		TacticalItemLocationState.LOCATION_TACTICAL_GROUND,
		TacticalItemLocationState.LOCATION_TACTICAL_CONTAINER,
		TacticalItemLocationState.LOCATION_BODY_ATTACHMENT,
		TacticalItemLocationState.LOCATION_DESTROYED,
	]
	var valid_container_kinds := [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
		TacticalInventoryState.KIND_BELT,
		TacticalInventoryState.KIND_BACKPACK,
		TacticalItemLocationState.CONTAINER_GROUND,
		TacticalItemLocationState.CONTAINER_RESTRAINT,
	]

	for key: Variant in items_by_id.keys():
		var item_id := StringName(key)
		var item := get_item(item_id)
		if item == null:
			errors.append("Item registry contains a null entry: %s" % item_id)
			continue
		if item.item_id != item_id:
			errors.append("Item registry key does not match instance ID: %s" % item_id)
		if item.definition == null:
			errors.append("Item %s has no ItemDefinition." % item_id)
		else:
			if item.definition_id != item.definition.id:
				errors.append("Item %s has a mismatched definition ID." % item_id)
			if item.definition.id.is_empty():
				errors.append("Item %s uses a definition with an empty ID." % item_id)
			if item.quantity > 1 and not item.definition.stackable:
				errors.append("Non-stackable item %s has quantity %d." % [item_id, item.quantity])
			if item.quantity > item.definition.maximum_stack_size:
				errors.append(
					"Item %s exceeds maximum stack size %d."
					% [item_id, item.definition.maximum_stack_size]
				)
		if item.quantity < 1:
			errors.append("Item %s has an invalid quantity." % item_id)
		if item.condition < 0.0 or item.condition > 1.0:
			errors.append("Item %s has condition outside 0–1." % item_id)
		if item.is_body():
			var linked: TacticalUnitState = get_unit(item.linked_unit_id)
			if linked == null:
				errors.append("Body item %s references a missing character." % item_id)
			elif linked.body_item_id != item.item_id:
				errors.append("Body item %s disagrees with its linked character." % item_id)
			if item.quantity != 1:
				errors.append("Body item %s cannot stack." % item_id)
		if item.location == null:
			errors.append("Item %s has no location." % item_id)
			continue

		var location := item.location
		if location.location_type not in valid_location_types:
			errors.append(
				"Item %s has unknown location type %s."
				% [item_id, location.location_type]
			)
			continue
		if (
			not location.container_kind.is_empty()
			and location.container_kind not in valid_container_kinds
			and location.location_type
			!= TacticalItemLocationState.LOCATION_TACTICAL_CONTAINER
		):
			errors.append(
				"Item %s has unknown container kind %s."
				% [item_id, location.container_kind]
			)

		match location.location_type:
			TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT:
				var owner := get_unit(location.owner_id)
				if location.owner_id.is_empty() or owner == null:
					errors.append("Equipment item %s references a missing owner." % item_id)
					continue
				if location.container_kind not in [
					TacticalInventoryState.KIND_PRIMARY_HAND,
					TacticalInventoryState.KIND_SECONDARY_HAND,
				]:
					errors.append("Item %s uses an invalid equipment container." % item_id)
				if (
					item.definition != null
					and not item.definition.can_equip_in_hand()
					and not item.is_body()
				):
					errors.append("Item %s cannot legally be equipped in a hand." % item_id)
				if item.is_body() and item.location.transport_mode != &"dragging":
					errors.append("Body item %s in a Hand is not marked as dragging." % item_id)
				if item.quantity != 1:
					errors.append("Equipped item %s must have quantity 1." % item_id)
				if (
					location.container_kind
					== TacticalInventoryState.KIND_SECONDARY_HAND
					and item.two_handed
				):
					errors.append("Two-handed item %s is equipped in Secondary Hand." % item_id)

			TacticalItemLocationState.LOCATION_UNIT_INVENTORY:
				var inventory_owner := get_unit(location.owner_id)
				if location.owner_id.is_empty() or inventory_owner == null:
					errors.append("Inventory item %s references a missing owner." % item_id)
					continue
				if location.container_kind not in [
					TacticalInventoryState.KIND_BELT,
					TacticalInventoryState.KIND_BACKPACK,
				]:
					errors.append("Item %s uses an invalid inventory container." % item_id)
					continue
				if (
					location.container_kind == TacticalInventoryState.KIND_BELT
					and not item.belt_allowed
				):
					errors.append("Item %s is not allowed on the Belt." % item_id)
				if (
					location.container_kind == TacticalInventoryState.KIND_BACKPACK
					and not item.backpack_allowed
				):
					errors.append("Item %s is not allowed in the Backpack." % item_id)

				var width := inventory_owner.inventory.container_width(
					location.container_kind
				)
				var height := inventory_owner.inventory.container_height(
					location.container_kind
				)
				var rect := Rect2i(location.grid_position, item.footprint)
				var rect_end := rect.position + rect.size
				if rect.position.x < 0 or rect.position.y < 0:
					errors.append("Item %s has a negative grid position." % item_id)
				if rect_end.x > width or rect_end.y > height:
					errors.append("Item %s is outside its inventory grid." % item_id)
				for y: int in range(rect.position.y, rect_end.y):
					for x: int in range(rect.position.x, rect_end.x):
						var occupancy_key := "%s|%s|%d|%d" % [
							location.owner_id,
							location.container_kind,
							x,
							y,
						]
						if occupied_by_unit_container.has(occupancy_key):
							errors.append(
								"Items %s and %s overlap at %s."
								% [
									occupied_by_unit_container[occupancy_key],
									item_id,
									occupancy_key,
								]
							)
						else:
							occupied_by_unit_container[occupancy_key] = item_id

			TacticalItemLocationState.LOCATION_TACTICAL_GROUND:
				if not location.owner_id.is_empty():
					errors.append("Ground item %s still has an owner." % item_id)
				if location.container_kind != TacticalItemLocationState.CONTAINER_GROUND:
					errors.append("Ground item %s has an invalid container." % item_id)
				if map_definition != null and not map_definition.is_inside(location.map_position):
					errors.append("Ground item %s is outside the tactical map." % item_id)

			TacticalItemLocationState.LOCATION_TACTICAL_CONTAINER:
				if location.owner_id.is_empty():
					errors.append("Container item %s has no source object ID." % item_id)
				if location.container_kind.is_empty():
					errors.append("Container item %s has no container kind." % item_id)
				if map_definition != null and not map_definition.is_inside(location.map_position):
					errors.append("Container item %s is outside the tactical map." % item_id)

			TacticalItemLocationState.LOCATION_BODY_ATTACHMENT:
				var attachment_owner: TacticalUnitState = get_unit(location.owner_id)
				if attachment_owner == null:
					errors.append("Attached item %s references a missing body." % item_id)
				if location.container_kind != TacticalItemLocationState.CONTAINER_RESTRAINT:
					errors.append("Attached item %s uses an invalid attachment kind." % item_id)

			TacticalItemLocationState.LOCATION_DESTROYED:
				if not location.owner_id.is_empty():
					errors.append("Destroyed item %s still has an owner." % item_id)
				if not location.container_kind.is_empty():
					errors.append("Destroyed item %s still has a container." % item_id)

	for unit: TacticalUnitState in get_units():
		var primary_items := get_unit_container_items(
			unit.unit_id,
			TacticalInventoryState.KIND_PRIMARY_HAND
		)
		var secondary_items := get_unit_container_items(
			unit.unit_id,
			TacticalInventoryState.KIND_SECONDARY_HAND
		)
		if primary_items.size() > 1:
			errors.append("%s has more than one Primary Hand item." % unit.display_name)
		if secondary_items.size() > 1:
			errors.append("%s has more than one Secondary Hand item." % unit.display_name)
		var primary := primary_items[0] if not primary_items.is_empty() else null
		var secondary := secondary_items[0] if not secondary_items.is_empty() else null
		if primary != null and primary.two_handed and secondary != null:
			errors.append(
				"%s has a two-handed Primary item and an occupied Secondary Hand."
				% unit.display_name
			)
		if calculated_carried_weight(unit.unit_id) > unit.inventory.maximum_weight_lb + 0.001:
			errors.append("%s exceeds its carrying limit." % unit.display_name)

	return errors


func validate_squad_invariants() -> Array[String]:
	var errors: Array[String] = []
	for squad: TacticalSquadState in get_squads():
		errors.append_array(squad.validate_state())
		for member_id: StringName in squad.member_unit_ids:
			var member: TacticalUnitState = get_unit(member_id)
			if member == null:
				errors.append("Squad %s references missing member %s." % [squad.squad_id, member_id])
			elif member.squad_id != squad.squad_id:
				errors.append("Squad %s and member %s disagree about membership." % [squad.squad_id, member_id])
			elif member.team_id != squad.team_id:
				errors.append("Squad %s and member %s have different teams." % [squad.squad_id, member_id])
	return errors


func validate_phase_invariants() -> Array[String]:
	var errors: Array[String] = []
	if phase_state == null:
		errors.append("Tactical state has no phase state.")
		return errors
	if phase_state.round_number < 1:
		errors.append("Tactical round number must be at least 1.")
	if phase_state.current_phase not in [
		TacticalPhaseState.PLAYER_PHASE,
		TacticalPhaseState.ENEMY_PHASE,
		TacticalPhaseState.WORLD_PHASE,
	]:
		errors.append("Tactical state has an unknown phase.")
	if phase_state.tactical_mode not in [
		TacticalPhaseState.MODE_SIDE_BASED,
		TacticalPhaseState.MODE_INITIATIVE,
	]:
		errors.append("Tactical state has an unknown tactical mode.")
	if phase_state.is_initiative_combat():
		if phase_state.initiative_order.is_empty():
			errors.append("Initiative combat has no active-round participants.")
		elif (
			phase_state.active_initiative_index < 0
			or phase_state.active_initiative_index >= phase_state.initiative_order.size()
		):
			errors.append("Initiative combat has an invalid active index.")
		var seen_initiative_ids: Dictionary = {}
		for unit_id: StringName in phase_state.initiative_order:
			if get_unit(unit_id) == null:
				errors.append("Initiative references missing unit %s." % unit_id)
			elif seen_initiative_ids.has(unit_id):
				errors.append("Initiative repeats unit %s." % unit_id)
			seen_initiative_ids[unit_id] = true
		for unit_id: StringName in phase_state.pending_initiative_unit_ids:
			if get_unit(unit_id) == null:
				errors.append("Pending initiative references missing unit %s." % unit_id)
			elif seen_initiative_ids.has(unit_id):
				errors.append("Pending initiative repeats active unit %s." % unit_id)
			seen_initiative_ids[unit_id] = true
	else:
		if (
			not phase_state.initiative_order.is_empty()
			or not phase_state.pending_initiative_unit_ids.is_empty()
		):
			errors.append("Side-based play retains stale initiative participants.")
	return errors


func shallow_copy_for_assembly_validation() -> TacticalState:
	# This copy shares existing unit/item records and is safe only while mission
	# assembly validation adds new records without mutating existing ones.
	var result := TacticalState.new()
	result.phase_state = phase_state
	result.environment_state = environment_state
	result.restore_knowledge_snapshot(knowledge_snapshot())
	result.units_by_id = units_by_id.duplicate()
	result.squads_by_id = squads_by_id.duplicate()
	result.items_by_id = items_by_id.duplicate()
	result.extraction_zone_states_by_id = extraction_zone_states_by_id.duplicate()
	result.mission_resolution_locked = mission_resolution_locked
	result.resolved_mission_result_id = resolved_mission_result_id
	result.revision = revision
	result.rebuild_unit_occupancy()
	result.rebuild_ground_item_index()
	# Assembly validation must preserve the source spatial revisions. Rebuilding
	# the derived indexes above must not make the validation copy look like a new
	# spatial state to geometry caches.
	result.occupancy_revision = occupancy_revision
	result.visibility_blocker_revision = visibility_blocker_revision
	return result


func validate_all(
		map_definition: TacticalMapDefinition
) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(validate_unit_invariants(map_definition))
	errors.append_array(validate_item_invariants(map_definition))
	errors.append_array(validate_squad_invariants())
	errors.append_array(validate_phase_invariants())
	if map_definition != null:
		for zone_id: StringName in map_definition.extraction_zone_ids():
			if extraction_zone_state(zone_id) == null:
				errors.append("Tactical state is missing extraction zone %s." % zone_id)
	for raw_zone_id: Variant in extraction_zone_states_by_id.keys():
		var zone_id: StringName = StringName(raw_zone_id)
		var zone_state: TacticalExtractionZoneState = extraction_zone_state(zone_id)
		if zone_state == null or zone_state.zone_id != zone_id:
			errors.append("Tactical extraction-zone registry contains an invalid entry.")
	if mission_resolution_locked and resolved_mission_result_id.is_empty():
		errors.append("Tactical mission is locked without a result ID.")
	if environment_state == null:
		errors.append("Tactical state has no environment state.")
	else:
		errors.append_array(environment_state.validate_state(map_definition))
	if knowledge_state == null:
		errors.append("Tactical state has no knowledge state.")
	else:
		errors.append_array(
			knowledge_state.validate_state(
				map_definition.grid_size
				if map_definition != null
				else Vector2i.ZERO
			)
		)
	return errors
