class_name PrisonCapacityService
extends RefCounted

const PRISON_DEFINITION_ID: StringName = &"facility.prison"

var _stronghold_registry: RefCounted


func configure(stronghold_registry: RefCounted) -> void:
	_stronghold_registry = stronghold_registry


func capacity_snapshot(campaign: CampaignState) -> Dictionary:
	var facilities: Array[Dictionary] = []
	var total_capacity: int = 0
	var held_cells: int = 0
	var incoming_cells: int = 0
	var held_by_prison: Dictionary = {}
	if campaign == null:
		return _empty_snapshot()
	for captive: CampaignCaptiveState in campaign.get_captives():
		if captive.status == &"held":
			held_cells += captive.cell_cost
			held_by_prison[captive.assigned_prison_id] = int(
				held_by_prison.get(captive.assigned_prison_id, 0)
			) + captive.cell_cost
		elif captive.status == &"incoming":
			incoming_cells += captive.cell_cost
	for facility in _prison_facilities(campaign):
		var capacity: int = _facility_capacity(campaign, facility)
		total_capacity += capacity
		facilities.append({
			"facility_id": facility.instance_id,
			"level": facility.level,
			"condition": String(facility.condition),
			"capacity": capacity,
			"held": int(held_by_prison.get(facility.instance_id, 0)),
			"available": maxi(0, capacity - int(held_by_prison.get(facility.instance_id, 0))),
		})
	return {
		"total_capacity": total_capacity,
		"held_cells": held_cells,
		"incoming_cells": incoming_cells,
		"available_capacity": maxi(0, total_capacity - held_cells - incoming_cells),
		"facilities": facilities,
		"has_prison": not facilities.is_empty(),
	}


func can_reserve(campaign: CampaignState, required_cells: int) -> OperationResult:
	var snapshot: Dictionary = capacity_snapshot(campaign)
	if required_cells <= 0:
		return OperationResult.ok(snapshot, "No Prison cells are required.")
	if not bool(snapshot.get("has_prison", false)):
		return OperationResult.fail(
			&"prison_missing",
			"No constructed Prison is available for returning captives."
		)
	var available: int = int(snapshot.get("available_capacity", 0))
	if required_cells > available:
		return OperationResult.fail(
			&"prison_capacity_exceeded",
			"Selected captives require %d Prison cell%s but only %d will be available."
			% [required_cells, "" if required_cells == 1 else "s", available]
		)
	return OperationResult.ok(snapshot, "The selected captives fit the projected Prison capacity.")


func can_remove_prison_facility(
		campaign: CampaignState,
		facility_instance_id: StringName
) -> OperationResult:
	if campaign == null or facility_instance_id.is_empty():
		return OperationResult.fail(&"prison_missing", "The selected Prison is unavailable.")
	var target = campaign.stronghold.get_facility(facility_instance_id) if campaign.stronghold != null else null
	if target == null or target.definition_id != PRISON_DEFINITION_ID:
		return OperationResult.ok({}, "The selected facility is not a Prison.")
	for captive: CampaignCaptiveState in campaign.get_captives():
		if captive.status == &"held" and captive.assigned_prison_id == facility_instance_id:
			return OperationResult.fail(
				&"prison_occupied",
				"This Prison still contains %s. Ransom or release its captives before demolition."
				% captive.display_name
			)
	var remaining_capacity: int = 0
	for facility in _prison_facilities(campaign):
		if facility.instance_id != facility_instance_id:
			remaining_capacity += _facility_capacity(campaign, facility)
	var required_cells: int = 0
	for captive: CampaignCaptiveState in campaign.get_captives():
		if captive.is_active_custody():
			required_cells += captive.cell_cost
	if required_cells > remaining_capacity:
		return OperationResult.fail(
			&"prison_capacity_reserved",
			"This Prison cannot be demolished while held or incoming captives require its cells."
		)
	return OperationResult.ok({}, "The empty Prison can be demolished.")


func ensure_campaign_captives(campaign: CampaignState, policy_registry: CaptivePolicyRegistry = null) -> bool:
	if campaign == null:
		return false
	var changed: bool = false
	for captive: CampaignCaptiveState in campaign.get_captives():
		if policy_registry != null:
			var before: Dictionary = captive.to_dictionary()
			policy_registry.apply_to_captive(captive)
			if before != captive.to_dictionary():
				changed = true
		if captive.status == &"held" and captive.assigned_prison_id.is_empty():
			captive.status = &"incoming"
			captive.holding_location_id = &"stronghold.awaiting_admission"
			captive.revision += 1
			changed = true
	if admit_waiting_candidate(campaign):
		changed = true
	if changed:
		campaign.revision += 1
	return changed


func admit_returning_candidate(campaign: CampaignState, operation_id: StringName) -> bool:
	if campaign == null or operation_id.is_empty():
		return false
	var transit_id := StringName("return_transit.%s" % operation_id)
	return _admit_matching_candidate(campaign, func(captive: CampaignCaptiveState) -> bool:
		return captive.status == &"incoming" and captive.holding_location_id == transit_id
	)


func admit_waiting_candidate(campaign: CampaignState) -> bool:
	if campaign == null:
		return false
	return _admit_matching_candidate(campaign, func(captive: CampaignCaptiveState) -> bool:
		return captive.status == &"incoming" and captive.holding_location_id == &"stronghold.awaiting_admission"
	)


func _admit_matching_candidate(campaign: CampaignState, predicate: Callable) -> bool:
	var facilities: Array = _prison_facilities(campaign)
	if facilities.is_empty():
		return false
	var used: Dictionary = {}
	for held: CampaignCaptiveState in campaign.get_captives():
		if held.status == &"held":
			used[held.assigned_prison_id] = int(used.get(held.assigned_prison_id, 0)) + held.cell_cost
	var changed: bool = false
	for captive: CampaignCaptiveState in campaign.get_captives():
		if not predicate.call(captive):
			continue
		var assigned_id: StringName = &""
		for facility in facilities:
			var capacity: int = _facility_capacity(campaign, facility)
			var occupied: int = int(used.get(facility.instance_id, 0))
			if occupied + captive.cell_cost <= capacity:
				assigned_id = facility.instance_id
				break
		if assigned_id.is_empty():
			captive.holding_location_id = &"stronghold.awaiting_admission"
			continue
		captive.status = &"held"
		captive.assigned_prison_id = assigned_id
		captive.holding_location_id = StringName("prison.%s" % assigned_id)
		captive.admitted_at_tick = campaign.campaign_tick
		captive.history_entries.append("Admitted to Prison on campaign day %d." % (campaign.campaign_tick / 1440 + 1))
		captive.revision += 1
		used[assigned_id] = int(used.get(assigned_id, 0)) + captive.cell_cost
		changed = true
	return changed


func _prison_facilities(campaign: CampaignState) -> Array:
	var result: Array = []
	if campaign == null or campaign.stronghold == null:
		return result
	for facility in campaign.stronghold.get_facilities():
		if (
			facility != null
			and facility.definition_id == PRISON_DEFINITION_ID
			and facility.condition != StrongholdFacilityState.CONDITION_UNDER_CONSTRUCTION
		):
			result.append(facility)
	result.sort_custom(func(a, b) -> bool: return String(a.instance_id) < String(b.instance_id))
	return result


func _facility_capacity(campaign: CampaignState, facility) -> int:
	if campaign == null or facility == null or _stronghold_registry == null:
		return 0
	if facility.condition == StrongholdFacilityState.CONDITION_DISABLED:
		return 0
	var stronghold_definition = _stronghold_registry.definition(campaign.stronghold.definition_id)
	if stronghold_definition == null:
		return 0
	var definition = stronghold_definition.facility_definition(facility.definition_id)
	if definition == null:
		return 0
	var capacity: int = definition.prison_capacity_for_level(facility.level)
	if facility.condition == StrongholdFacilityState.CONDITION_DAMAGED:
		capacity = capacity / 2
	return maxi(0, capacity)


func _empty_snapshot() -> Dictionary:
	return {
		"total_capacity": 0,
		"held_cells": 0,
		"incoming_cells": 0,
		"available_capacity": 0,
		"facilities": [],
		"has_prison": false,
	}
