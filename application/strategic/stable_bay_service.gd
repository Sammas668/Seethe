class_name StableBayService
extends RefCounted

const STABLES_DEFINITION_ID: StringName = &"facility.stables"
const WALKING_ID: StringName = &"transport.walking"
const CONDITION_OPERATIONAL: StringName = &"operational"
const CONDITION_UPGRADING: StringName = &"upgrading"
const CONDITION_UNDER_CONSTRUCTION: StringName = &"under_construction"
const WALKING_FORMATION_CAPACITY: int = 6

var _transport_service: SquadTransportService
var _stronghold_registry


func configure(transport_service: SquadTransportService, stronghold_registry_value = null) -> void:
	_transport_service = transport_service
	_stronghold_registry = stronghold_registry_value


# One exact constructed Stable facility creates one housing/expedition record.
# Stable level no longer creates invisible additional bays.
func ensure_campaign_bays(campaign: CampaignState) -> bool:
	if campaign == null or campaign.stronghold == null:
		return false
	var stable_facilities: Array = _stable_facilities(campaign)
	var existing: Array[StableBayState] = campaign.get_stable_bays()
	var claimed_bay_ids: Dictionary = {}
	var changed: bool = false

	for index: int in range(stable_facilities.size()):
		var facility = stable_facilities[index]
		var facility_id: StringName = facility.instance_id
		var bay: StableBayState = bay_for_facility(campaign, facility_id)
		if bay == null:
			for candidate: StableBayState in existing:
				if claimed_bay_ids.has(candidate.bay_id):
					continue
				if candidate.stable_facility_id.is_empty():
					bay = candidate
					break
		if bay == null:
			bay = StableBayState.new()
			bay.bay_id = StringName("stable.housing.%04d" % (index + 1))
			while campaign.get_stable_bay(bay.bay_id) != null:
				bay.bay_id = StringName("stable.housing.%04d" % (campaign.stable_bays_by_id.size() + 1))
			campaign.stable_bays_by_id[bay.bay_id] = bay
			existing.append(bay)
			changed = true
		if bay.stable_facility_id != facility_id:
			bay.stable_facility_id = facility_id
			bay.revision += 1
			changed = true
		if bay.bay_index != index:
			bay.bay_index = index
			bay.revision += 1
			changed = true
		claimed_bay_ids[bay.bay_id] = true
		if not bay.transport_asset_id.is_empty():
			var asset: TransportState = campaign.get_transport(bay.transport_asset_id)
			if asset != null:
				if asset.assigned_bay_id != bay.bay_id or asset.housed_stable_id != facility_id:
					asset.assigned_bay_id = bay.bay_id
					asset.housed_stable_id = facility_id
					if not asset.is_reserved():
						asset.status = TransportState.STATUS_ASSIGNED
					asset.revision += 1
					changed = true

	# Old saves could contain extra level-generated bays. Keep an active legacy
	# bay until its expedition returns, but release and remove inactive extras.
	var remove_ids: Array[StringName] = []
	for bay: StableBayState in existing:
		if claimed_bay_ids.has(bay.bay_id):
			continue
		if bay.is_active():
			if bay.stable_facility_id.is_empty() and not stable_facilities.is_empty():
				bay.stable_facility_id = stable_facilities[0].instance_id
				bay.revision += 1
				changed = true
			continue
		_release_orphaned_bay(campaign, bay)
		remove_ids.append(bay.bay_id)
		changed = true
	for bay_id: StringName in remove_ids:
		campaign.stable_bays_by_id.erase(bay_id)

	if changed:
		campaign.revision += 1
	return changed


func expedition_bay_capacity(campaign: CampaignState) -> int:
	return _stable_facilities(campaign).size() if campaign != null else 0


func stable_is_operational(campaign: CampaignState) -> bool:
	for facility in _stable_facilities(campaign):
		if facility.condition in [CONDITION_OPERATIONAL, CONDITION_UPGRADING]:
			return true
	return false


func stable_bay_is_operational(campaign: CampaignState, bay: StableBayState) -> bool:
	if campaign == null or campaign.stronghold == null or bay == null:
		return false
	var facility = campaign.stronghold.get_facility(bay.stable_facility_id)
	return facility != null and facility.condition in [CONDITION_OPERATIONAL, CONDITION_UPGRADING]


func bay_for_facility(campaign: CampaignState, facility_instance_id: StringName) -> StableBayState:
	if campaign == null or facility_instance_id.is_empty():
		return null
	for bay: StableBayState in campaign.get_stable_bays():
		if bay.stable_facility_id == facility_instance_id:
			return bay
	return null


func first_empty_stable(campaign: CampaignState) -> StableBayState:
	for bay: StableBayState in supported_bays(campaign):
		if bay.is_vacant_for_transport() and stable_bay_is_operational(campaign, bay):
			return bay
	return null


func supported_bays(campaign: CampaignState) -> Array[StableBayState]:
	ensure_campaign_bays(campaign)
	var facility_ids: Dictionary = {}
	for facility in _stable_facilities(campaign):
		facility_ids[facility.instance_id] = true
	var result: Array[StableBayState] = []
	for bay: StableBayState in campaign.get_stable_bays():
		if facility_ids.has(bay.stable_facility_id) or bay.is_active():
			result.append(bay)
	result.sort_custom(func(a: StableBayState, b: StableBayState) -> bool: return a.bay_index < b.bay_index)
	return result


func ready_bays(campaign: CampaignState) -> Array[StableBayState]:
	var result: Array[StableBayState] = []
	for bay: StableBayState in supported_bays(campaign):
		if (
			bay.status == StableBayState.STATUS_READY
			and stable_bay_is_operational(campaign, bay)
			and formation_validation(campaign, bay).success
		):
			result.append(bay)
	return result


func ensure_starting_assignment(campaign: CampaignState) -> bool:
	if campaign == null:
		return false
	ensure_campaign_bays(campaign)
	var bays: Array[StableBayState] = supported_bays(campaign)
	var first_squad: CampaignSquadState = campaign.get_squad(SquadManagementService.FIRST_SQUAD_ID)
	if bays.is_empty() or first_squad == null:
		return false
	var first_bay: StableBayState = bays[0]
	var changed: bool = false
	var starter: TransportState = campaign.get_transport(SquadTransportService.STARTER_TRANSPORT_ID)
	if starter != null and first_bay.transport_asset_id.is_empty():
		var housed: OperationResult = assign_transport_asset(campaign, first_bay.bay_id, starter.transport_id)
		changed = changed or housed.success
	if first_bay.assigned_squad_id.is_empty() and first_squad.assigned_stable_bay_id.is_empty():
		for operation: SquadTravelOperationState in campaign.get_squad_travel_operations():
			if operation != null and operation.is_active():
				return changed
		var assigned: OperationResult = assign_squad(campaign, first_bay.bay_id, first_squad.squad_id)
		changed = changed or assigned.success
	return changed


func assign_squad(campaign: CampaignState, bay_id: StringName, squad_id: StringName) -> OperationResult:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	var squad: CampaignSquadState = campaign.get_squad(squad_id) if campaign != null else null
	if bay == null or squad == null:
		return OperationResult.fail(&"stable_assignment_missing", "The Stable or squad no longer exists.")
	if bay.is_active() or squad.is_active():
		return OperationResult.fail(&"expedition_active", "An active expedition cannot be reassigned.")
	for other_bay: StableBayState in campaign.get_stable_bays():
		if other_bay.bay_id != bay_id and other_bay.assigned_squad_id == squad_id:
			return OperationResult.fail(&"squad_already_stabled", "This squad is already assigned to another Stable.")
	if not bay.assigned_squad_id.is_empty():
		var previous: CampaignSquadState = campaign.get_squad(bay.assigned_squad_id)
		if previous != null:
			previous.assigned_stable_bay_id = &""
			previous.revision += 1
	bay.assigned_squad_id = squad_id
	bay.is_walking = bay.transport_asset_id.is_empty()
	if bay.is_walking:
		bay.transport_method_id = WALKING_ID
	else:
		var asset: TransportState = campaign.get_transport(bay.transport_asset_id)
		if asset != null:
			bay.transport_method_id = asset.definition_id
	bay.status = StableBayState.STATUS_READY
	bay.formation_character_ids_by_slot.clear()
	_auto_arrange(campaign, bay)
	bay.revision += 1
	squad.assigned_stable_bay_id = bay_id
	squad.revision += 1
	campaign.revision += 1
	return OperationResult.ok(bay, "%s assigned to Stable %d." % [squad.display_name, bay.bay_index + 1])


# Clears the squad while preserving the exact transport housed in this Stable.
func clear_bay(campaign: CampaignState, bay_id: StringName) -> OperationResult:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	if bay == null:
		return OperationResult.fail(&"stable_missing", "The Stable no longer exists.")
	if bay.is_active():
		return OperationResult.fail(&"expedition_active", "An active expedition cannot be cleared.")
	var squad: CampaignSquadState = campaign.get_squad(bay.assigned_squad_id)
	if squad != null:
		squad.assigned_stable_bay_id = &""
		squad.revision += 1
	bay.clear_squad_assignment()
	campaign.revision += 1
	return OperationResult.ok(bay, "Squad removed; the housed transport remains in this Stable.")


func assign_walking(campaign: CampaignState, bay_id: StringName) -> OperationResult:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	if bay == null or bay.assigned_squad_id.is_empty():
		return OperationResult.fail(&"stable_squad_missing", "Assign a squad to this Stable first.")
	if bay.is_active():
		return OperationResult.fail(&"expedition_active", "An active expedition cannot change travel method.")
	if not bay.transport_asset_id.is_empty():
		return OperationResult.fail(&"stable_transport_housed", "This Stable houses a transport. Move or remove that vehicle before preparing a walking expedition.")
	bay.transport_method_id = WALKING_ID
	bay.is_walking = true
	bay.installed_fitting_ids.clear()
	bay.status = StableBayState.STATUS_READY
	bay.formation_character_ids_by_slot.clear()
	_auto_arrange(campaign, bay)
	bay.revision += 1
	campaign.revision += 1
	return OperationResult.ok(bay, "Walking expedition prepared with six deployment positions.")


# Houses one exact transport in one exact constructed Stable. A squad is not
# required; it can be assigned before or after the vehicle is housed.
func assign_transport_asset(campaign: CampaignState, bay_id: StringName, transport_asset_id: StringName) -> OperationResult:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	var asset: TransportState = campaign.get_transport(transport_asset_id) if campaign != null else null
	if bay == null:
		return OperationResult.fail(&"stable_missing", "The selected Stable no longer exists.")
	if asset == null:
		return OperationResult.fail(&"transport_missing", "The transport asset no longer exists.")
	if bay.is_active() or asset.is_reserved():
		return OperationResult.fail(&"transport_reserved", "The Stable or transport is already supporting an active expedition.")
	if not bay.transport_asset_id.is_empty() and bay.transport_asset_id != transport_asset_id:
		return OperationResult.fail(&"stable_transport_occupied", "This Stable already houses a transport.")
	if not asset.assigned_bay_id.is_empty() and asset.assigned_bay_id != bay_id:
		return OperationResult.fail(&"transport_already_housed", "The selected transport is housed in another Stable.")
	var definition: SquadTransportDefinition = _transport_service.definition(asset.definition_id) if _transport_service != null else null
	if definition == null:
		return OperationResult.fail(&"transport_definition_missing", "The transport method is unavailable.")
	bay.transport_method_id = asset.definition_id
	bay.transport_asset_id = asset.transport_id
	bay.is_walking = false
	bay.installed_fitting_ids = asset.installed_fitting_ids.duplicate()
	bay.status = StableBayState.STATUS_READY if not bay.assigned_squad_id.is_empty() else StableBayState.STATUS_EMPTY
	bay.formation_character_ids_by_slot.clear()
	asset.housed_stable_id = bay.stable_facility_id
	asset.assigned_bay_id = bay_id
	asset.status = TransportState.STATUS_ASSIGNED
	asset.revision += 1
	if not bay.assigned_squad_id.is_empty():
		_auto_arrange(campaign, bay)
	bay.revision += 1
	campaign.revision += 1
	return OperationResult.ok(bay, "%s housed in Stable %d." % [definition.display_name, bay.bay_index + 1])


func set_formation_slot(campaign: CampaignState, bay_id: StringName, slot_id: StringName, character_id: StringName) -> OperationResult:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	if bay == null or bay.is_active():
		return OperationResult.fail(&"stable_locked", "This formation cannot be changed now.")
	var squad: CampaignSquadState = campaign.get_squad(bay.assigned_squad_id)
	if squad == null:
		return OperationResult.fail(&"character_not_in_squad", "Assign a squad before editing the formation.")
	var capacity: int = _formation_capacity(campaign, bay)
	if not _valid_slot_ids(capacity).has(slot_id):
		return OperationResult.fail(&"formation_slot_invalid", "That deployment position does not exist for this travel method.")
	if character_id.is_empty():
		bay.formation_character_ids_by_slot.erase(slot_id)
		bay.revision += 1
		campaign.revision += 1
		return OperationResult.ok(bay, "Deployment position cleared.")
	if not squad.member_character_ids.has(character_id):
		return OperationResult.fail(&"character_not_in_squad", "Only members of the assigned squad can occupy this position.")
	var character: PersistentCharacterState = campaign.get_character(character_id)
	if character == null or not _can_deploy_character(character):
		return OperationResult.fail(&"character_unavailable", "This squad member cannot currently deploy.")

	var source_slot: StringName = _slot_for_character(bay, character_id)
	var target_character := StringName(bay.formation_character_ids_by_slot.get(slot_id, ""))
	if source_slot == slot_id:
		return OperationResult.ok(bay, "Formation unchanged.")
	if not source_slot.is_empty():
		if target_character.is_empty():
			bay.formation_character_ids_by_slot.erase(source_slot)
		else:
			bay.formation_character_ids_by_slot[source_slot] = target_character
	# Dragging a reserve onto an occupied position replaces the old occupant;
	# dragging between occupied positions swaps the two characters.
	bay.formation_character_ids_by_slot[slot_id] = character_id
	bay.revision += 1
	campaign.revision += 1
	return OperationResult.ok(bay, "Formation updated.")


func remove_formation_character(campaign: CampaignState, bay_id: StringName, character_id: StringName) -> OperationResult:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	if bay == null or bay.is_active():
		return OperationResult.fail(&"stable_locked", "This formation cannot be changed now.")
	var source_slot: StringName = _slot_for_character(bay, character_id)
	if source_slot.is_empty():
		return OperationResult.ok(bay, "Squad member is already in reserve.")
	bay.formation_character_ids_by_slot.erase(source_slot)
	bay.revision += 1
	campaign.revision += 1
	return OperationResult.ok(bay, "Squad member moved to reserve.")


func clear_formation(campaign: CampaignState, bay_id: StringName) -> OperationResult:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	if bay == null or bay.is_active():
		return OperationResult.fail(&"stable_locked", "This formation cannot be changed now.")
	bay.formation_character_ids_by_slot.clear()
	bay.revision += 1
	campaign.revision += 1
	return OperationResult.ok(bay, "Deployment formation cleared.")


func auto_arrange_formation(campaign: CampaignState, bay_id: StringName) -> OperationResult:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	if bay == null or bay.is_active():
		return OperationResult.fail(&"stable_locked", "This formation cannot be changed now.")
	if bay.assigned_squad_id.is_empty():
		return OperationResult.fail(&"no_squad_assigned", "Assign a squad before arranging its formation.")
	_auto_arrange(campaign, bay)
	bay.revision += 1
	campaign.revision += 1
	return OperationResult.ok(bay, "Deployment formation auto-assigned.")


func toggle_fitting(campaign: CampaignState, bay_id: StringName, fitting_id: StringName) -> OperationResult:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	if bay == null or bay.is_active() or bay.is_walking:
		return OperationResult.fail(&"fitting_unavailable", "This transport cannot change fittings now.")
	var asset: TransportState = campaign.get_transport(bay.transport_asset_id)
	if asset == null:
		return OperationResult.fail(&"transport_missing", "The housed transport no longer exists.")
	var definition: SquadTransportDefinition = _transport_service.definition(asset.definition_id) if _transport_service != null else null
	var slot_type: StringName = _fitting_slot_type(fitting_id)
	if definition == null or slot_type.is_empty() or not definition.fitting_slot_types.has(slot_type):
		return OperationResult.fail(&"fitting_incompatible", "This transport has no compatible fitting slot.")
	if asset.installed_fitting_ids.has(fitting_id):
		asset.installed_fitting_ids.erase(fitting_id)
	else:
		asset.installed_fitting_ids.append(fitting_id)
	bay.installed_fitting_ids = asset.installed_fitting_ids.duplicate()
	_trim_formation_to_capacity(campaign, bay)
	asset.revision += 1
	bay.revision += 1
	campaign.revision += 1
	return OperationResult.ok(bay, "Transport fittings updated.")


func formation_validation(campaign: CampaignState, bay: StableBayState) -> OperationResult:
	if campaign == null or bay == null or bay.assigned_squad_id.is_empty():
		return OperationResult.fail(&"no_squad_assigned", "Assign a squad to the Stable.")
	var squad: CampaignSquadState = campaign.get_squad(bay.assigned_squad_id)
	if squad == null or squad.member_character_ids.is_empty():
		return OperationResult.fail(&"squad_empty", "The assigned squad has no members.")
	var capacity: int = _formation_capacity(campaign, bay)
	var placed: Array[StringName] = bay.occupied_character_ids()
	if placed.is_empty():
		return OperationResult.fail(&"formation_empty", "Place at least one squad member into the deployment formation.")
	if placed.size() > capacity:
		return OperationResult.fail(&"passenger_capacity_exceeded", "The expedition exceeds its %d deployment positions." % capacity)
	var valid_slots: Array[StringName] = _valid_slot_ids(capacity)
	for raw_slot_id: Variant in bay.formation_character_ids_by_slot.keys():
		if not valid_slots.has(StringName(raw_slot_id)):
			return OperationResult.fail(&"formation_slot_invalid", "The formation contains a position unavailable to this travel method.")
	for character_id: StringName in placed:
		if not squad.member_character_ids.has(character_id):
			return OperationResult.fail(&"character_not_in_squad", "The formation contains someone outside the assigned squad.")
		var character: PersistentCharacterState = campaign.get_character(character_id)
		if character == null:
			return OperationResult.fail(&"character_missing", "The formation contains a missing character record.")
		if character.is_dead:
			return OperationResult.fail(&"character_dead", "%s must be removed from the deployment formation." % character.display_name)
		if not _can_deploy_character(character):
			return OperationResult.fail(&"character_unconscious", "%s is unconscious and cannot deploy." % character.display_name)
	return OperationResult.ok(bay, "Formation ready: %d / %d deployed." % [placed.size(), capacity])


func bay_transport_snapshot(campaign: CampaignState, bay: StableBayState) -> Dictionary:
	if bay == null or _transport_service == null:
		return {}
	var deployed_count: int = bay.occupied_character_ids().size()
	var data: Dictionary
	if bay.is_walking:
		data = _transport_service.transport_choice_snapshot(campaign, WALKING_ID, 0, deployed_count)
		data["availability_valid"] = stable_bay_is_operational(campaign, bay)
		data["validation_message"] = "Walking uses this constructed Stable and has six fixed deployment positions."
	else:
		data = _transport_service.asset_assignment_snapshot(campaign, bay.transport_asset_id, deployed_count)
	data["stable_bay_id"] = String(bay.bay_id)
	data["stable_facility_id"] = String(bay.stable_facility_id)
	data["campaign_squad_id"] = String(bay.assigned_squad_id)
	data["installed_fitting_ids"] = _string_array(bay.installed_fitting_ids)
	_apply_fitting_effects(data, bay.installed_fitting_ids)
	return data


func bay_summary(campaign: CampaignState, bay: StableBayState) -> Dictionary:
	var squad: CampaignSquadState = campaign.get_squad(bay.assigned_squad_id) if campaign != null else null
	var transport: Dictionary = bay_transport_snapshot(campaign, bay)
	var formation: OperationResult = formation_validation(campaign, bay)
	return {
		"bay_id": String(bay.bay_id),
		"stable_facility_id": String(bay.stable_facility_id),
		"bay_index": bay.bay_index,
		"status": String(bay.status),
		"squad_id": String(bay.assigned_squad_id),
		"squad_name": squad.display_name if squad != null else "Unassigned",
		"member_count": squad.member_character_ids.size() if squad != null else 0,
		"deployed_count": bay.occupied_character_ids().size(),
		"transport": transport,
		"formation_ready": formation.success,
		"formation_message": formation.message,
		"operational": stable_bay_is_operational(campaign, bay),
	}


func mark_departed_candidate(campaign: CampaignState, bay_id: StringName, operation_id: StringName) -> OperationResult:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	if bay == null:
		return OperationResult.fail(&"stable_missing", "The assigned Stable no longer exists.")
	var validation: OperationResult = formation_validation(campaign, bay)
	if not validation.success:
		return validation
	if not stable_bay_is_operational(campaign, bay):
		return OperationResult.fail(&"stable_disabled", "This Stable must be operational before its squad can depart.")
	bay.status = StableBayState.STATUS_TRAVELLING_OUT
	bay.active_operation_id = operation_id
	bay.revision += 1
	var squad: CampaignSquadState = campaign.get_squad(bay.assigned_squad_id)
	if squad != null:
		squad.current_operation_id = operation_id
		squad.revision += 1
	return OperationResult.ok(bay)


func mark_at_mission_candidate(campaign: CampaignState, bay_id: StringName) -> void:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	if bay != null:
		bay.status = StableBayState.STATUS_AT_MISSION
		bay.revision += 1


func mark_returning_candidate(campaign: CampaignState, bay_id: StringName) -> void:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	if bay != null:
		bay.status = StableBayState.STATUS_RETURNING
		bay.revision += 1


func release_after_return_candidate(campaign: CampaignState, bay_id: StringName) -> void:
	var bay: StableBayState = campaign.get_stable_bay(bay_id) if campaign != null else null
	if bay == null:
		return
	bay.status = StableBayState.STATUS_READY if not bay.assigned_squad_id.is_empty() else StableBayState.STATUS_EMPTY
	bay.active_operation_id = &""
	bay.revision += 1
	var squad: CampaignSquadState = campaign.get_squad(bay.assigned_squad_id)
	if squad != null:
		squad.current_operation_id = &""
		squad.revision += 1


func _auto_arrange(campaign: CampaignState, bay: StableBayState) -> void:
	var squad: CampaignSquadState = campaign.get_squad(bay.assigned_squad_id) if campaign != null else null
	if squad == null:
		return
	bay.formation_character_ids_by_slot.clear()
	var capacity: int = _formation_capacity(campaign, bay)
	var index: int = 0
	for character_id: StringName in squad.member_character_ids:
		if index >= capacity:
			break
		var character: PersistentCharacterState = campaign.get_character(character_id)
		if character == null or not _can_deploy_character(character):
			continue
		bay.formation_character_ids_by_slot[StringName("slot.%02d" % (index + 1))] = character_id
		index += 1


func _formation_capacity(campaign: CampaignState, bay: StableBayState) -> int:
	if bay == null or bay.is_walking:
		return WALKING_FORMATION_CAPACITY
	var data: Dictionary = bay_transport_snapshot(campaign, bay)
	return maxi(0, int(data.get("total_passenger_capacity", 0)))


func _valid_slot_ids(capacity: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for index: int in range(maxi(0, capacity)):
		result.append(StringName("slot.%02d" % (index + 1)))
	return result


func _trim_formation_to_capacity(campaign: CampaignState, bay: StableBayState) -> void:
	var valid_slots: Array[StringName] = _valid_slot_ids(_formation_capacity(campaign, bay))
	var remove_slots: Array[StringName] = []
	for raw_slot_id: Variant in bay.formation_character_ids_by_slot.keys():
		var slot_id := StringName(raw_slot_id)
		if not valid_slots.has(slot_id):
			remove_slots.append(slot_id)
	for slot_id: StringName in remove_slots:
		bay.formation_character_ids_by_slot.erase(slot_id)


func _slot_for_character(bay: StableBayState, character_id: StringName) -> StringName:
	for raw_slot: Variant in bay.formation_character_ids_by_slot.keys():
		if StringName(bay.formation_character_ids_by_slot.get(raw_slot, "")) == character_id:
			return StringName(raw_slot)
	return &""


func _release_orphaned_bay(campaign: CampaignState, bay: StableBayState) -> void:
	var squad: CampaignSquadState = campaign.get_squad(bay.assigned_squad_id)
	if squad != null and squad.assigned_stable_bay_id == bay.bay_id:
		squad.assigned_stable_bay_id = &""
		squad.revision += 1
	var asset: TransportState = campaign.get_transport(bay.transport_asset_id)
	if asset != null and not asset.is_reserved():
		asset.assigned_bay_id = &""
		asset.housed_stable_id = &""
		asset.status = TransportState.STATUS_AVAILABLE
		asset.revision += 1
	bay.clear_assignment()


func _stable_facilities(campaign: CampaignState) -> Array:
	var result: Array = []
	if campaign == null or campaign.stronghold == null:
		return result
	for facility in campaign.stronghold.get_facilities():
		if (
			facility != null
			and facility.definition_id == STABLES_DEFINITION_ID
			and facility.condition != CONDITION_UNDER_CONSTRUCTION
		):
			result.append(facility)
	return result


func _fitting_slot_type(fitting_id: StringName) -> StringName:
	match fitting_id:
		&"fitting.covered_canopy":
			return &"covering"
		&"fitting.cargo_racks":
			return &"cargo"
		&"fitting.captive_cage":
			return &"specialist"
		&"fitting.medical_litter":
			return &"utility"
	return &""


func _apply_fitting_effects(data: Dictionary, fitting_ids: Array[StringName]) -> void:
	for fitting_id: StringName in fitting_ids:
		match fitting_id:
			&"fitting.covered_canopy":
				data["journey_notoriety_modifier_percent"] = int(data.get("journey_notoriety_modifier_percent", 0)) - 20
			&"fitting.cargo_racks":
				data["total_cargo_capacity_lb"] = float(data.get("total_cargo_capacity_lb", 0.0)) + 300.0
			&"fitting.captive_cage":
				data["total_captive_capacity"] = int(data.get("total_captive_capacity", 0)) + 2
				data["total_cage_anchor_capacity"] = int(data.get("total_cage_anchor_capacity", 0)) + 1
			&"fitting.medical_litter":
				data["total_passenger_capacity"] = maxi(0, int(data.get("total_passenger_capacity", 0)) - 1)
				data["medical_litter_capacity"] = int(data.get("medical_litter_capacity", 0)) + 1


func _can_deploy_character(character: PersistentCharacterState) -> bool:
	if character == null or character.is_dead:
		return false
	if not character.health_initialized:
		return true
	return character.current_hp > 0 and character.nonlethal_damage < maxi(1, character.current_hp)


func _string_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result
