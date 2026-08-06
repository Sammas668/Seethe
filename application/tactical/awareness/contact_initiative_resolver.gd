class_name ContactInitiativeResolver
extends RefCounted

var _state_store: TacticalStateStore
var _dice_roller: TacticalDiceRoller


func configure(
		state_store: TacticalStateStore,
		dice_roller: TacticalDiceRoller
) -> void:
	_state_store = state_store
	_dice_roller = dice_roller


func finalize_resolution(
		unit: TacticalUnitState,
		resolution: TacticalDetectionResolution
) -> void:
	if (
		unit == null
		or resolution == null
		or not resolution.detected()
		or not resolution.alert_on_detection
	):
		return
	_add_new_awareness(resolution)
	var resolutions: Array[TacticalDetectionResolution] = [resolution]
	_roll_contact_participants(
		_detected_squad_ids_for_resolutions(resolutions),
		resolution
	)


func finalize_batch(resolutions: Array[TacticalDetectionResolution]) -> void:
	var alert_resolution: TacticalDetectionResolution = null
	for resolution: TacticalDetectionResolution in resolutions:
		if (
			resolution == null
			or not resolution.detected()
			or not resolution.alert_on_detection
		):
			continue
		_add_new_awareness(resolution)
		if alert_resolution == null:
			alert_resolution = resolution
	if alert_resolution == null:
		return
	_roll_contact_participants(
		_detected_squad_ids_for_resolutions(resolutions),
		alert_resolution
	)


func _squad_has_initiative_participant(squad: TacticalSquadState) -> bool:
	if squad == null:
		return false
	for member_id: StringName in squad.member_unit_ids:
		if (
			_state_store.state.phase_state.initiative_order.has(member_id)
			or _state_store.state.phase_state.pending_initiative_unit_ids.has(
				member_id
			)
		):
			return true
	return false


func _add_new_awareness(resolution: TacticalDetectionResolution) -> void:
	for squad_id: StringName in resolution.detected_squad_ids:
		var squad: TacticalSquadState = _state_store.state.get_squad(squad_id)
		if (
			squad != null
			and squad.team_id == &"enemy"
			and not squad.is_aware()
			and not resolution.newly_aware_squad_ids.has(squad_id)
		):
			resolution.newly_aware_squad_ids.append(squad_id)


func _detected_squad_ids_for_resolutions(
		resolutions: Array[TacticalDetectionResolution]
) -> Array[StringName]:
	var result: Array[StringName] = []
	for resolution: TacticalDetectionResolution in resolutions:
		if resolution == null or not resolution.alert_on_detection:
			continue
		for squad_id: StringName in resolution.detected_squad_ids:
			if not result.has(squad_id):
				result.append(squad_id)
	return result


func _roll_contact_participants(
		detected_squad_ids: Array[StringName],
		result_owner: TacticalDetectionResolution
) -> void:
	if result_owner == null:
		return
	var participant_ids: Array[StringName] = []
	for player: TacticalUnitState in _state_store.state.get_player_units():
		if player.participates_in_initiative():
			participant_ids.append(player.unit_id)
	for squad: TacticalSquadState in _state_store.state.get_squads():
		var joins_from_detection: bool = detected_squad_ids.has(squad.squad_id)
		var already_in_combat: bool = _squad_has_initiative_participant(squad)
		# Awareness is persistent after combat, but it is not a map-wide combat
		# membership flag. Only the detecting squad and squads already involved in
		# this combat may contribute participants.
		if not joins_from_detection and not already_in_combat:
			continue
		for member: TacticalUnitState in _state_store.state.get_units_in_squad(
			squad.squad_id
		):
			if member.participates_in_initiative() and not participant_ids.has(member.unit_id):
				participant_ids.append(member.unit_id)
	for participant_id: StringName in participant_ids:
		if (
			_state_store.state.phase_state.initiative_order.has(participant_id)
			or _state_store.state.phase_state.pending_initiative_unit_ids.has(
				participant_id
			)
		):
			continue
		var participant: TacticalUnitState = _state_store.state.get_unit(
			participant_id
		)
		if participant == null:
			continue
		result_owner.initiative_totals_by_unit_id[participant_id] = (
			_dice_roller.roll_die(20) + participant.initiative_modifier()
		)
