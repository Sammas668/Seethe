class_name SquadTransportService
extends RefCounted

const STABLES_DEFINITION_ID: StringName = &"facility.stables"
const WALKING_ID: StringName = &"transport.walking"
const STARTER_TRANSPORT_DEFINITION_ID: StringName = &"transport.pack_beast_train"
const STARTER_TRANSPORT_ID: StringName = &"transport.asset.pack_beast_train.0001"
const STARTER_RESEARCH_ID: StringName = &"research.transport.pack_beasts"
const TRANSPORT_DISMANTLE_RECOVERY_PERCENT: int = 50

var _definitions_by_id: Dictionary = {}
var _stronghold_registry


func _init() -> void:
	_register_defaults()


func configure(stronghold_registry_value = null) -> void:
	_stronghold_registry = stronghold_registry_value


func ensure_campaign_transport_state(campaign: CampaignState) -> bool:
	if campaign == null:
		return false
	var changed: bool = false
	if not campaign.has_completed_research(STARTER_RESEARCH_ID):
		campaign.completed_research_ids[STARTER_RESEARCH_ID] = true
		changed = true
	if campaign.get_transports().is_empty():
		var starter := TransportState.new()
		starter.transport_id = STARTER_TRANSPORT_ID
		starter.definition_id = STARTER_TRANSPORT_DEFINITION_ID
		starter.housed_stable_id = &""
		starter.status = TransportState.STATUS_AVAILABLE
		starter.custom_name = "First Pack Train"
		starter.history_entries.append("Authored starting transport at the Fifth-God ruin.")
		campaign.transports_by_id[starter.transport_id] = starter
		campaign.next_transport_sequence = maxi(campaign.next_transport_sequence, 2)
		changed = true
	for asset: TransportState in campaign.get_transports():
		if asset.status in [
			TransportState.STATUS_DAMAGED,
			TransportState.STATUS_UNDER_REPAIR,
			TransportState.STATUS_UNSUPPORTED,
			TransportState.STATUS_LOST,
			TransportState.STATUS_DESTROYED,
		]:
			asset.status = TransportState.STATUS_AVAILABLE
			asset.condition = 100
			asset.support_enabled = true
			asset.revision += 1
			changed = true
	if changed:
		campaign.revision += 1
	return changed


func definitions() -> Array[SquadTransportDefinition]:
	var result: Array[SquadTransportDefinition] = []
	for raw_definition: Variant in _definitions_by_id.values():
		var transport_definition: SquadTransportDefinition = raw_definition as SquadTransportDefinition
		if transport_definition != null:
			result.append(SquadTransportDefinition.from_dictionary(transport_definition.to_dictionary()))
	result.sort_custom(
		func(a: SquadTransportDefinition, b: SquadTransportDefinition) -> bool:
			if a.is_walking != b.is_walking:
				return a.is_walking
			if a.stable_bays_required != b.stable_bays_required:
				return a.stable_bays_required < b.stable_bays_required
			return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	return result


func definition(transport_definition_id: StringName) -> SquadTransportDefinition:
	var source: SquadTransportDefinition = _definitions_by_id.get(transport_definition_id) as SquadTransportDefinition
	return SquadTransportDefinition.from_dictionary(source.to_dictionary()) if source != null else null


func unlocked_definitions(campaign: CampaignState) -> Array[SquadTransportDefinition]:
	var result: Array[SquadTransportDefinition] = []
	for transport_definition: SquadTransportDefinition in definitions():
		if transport_definition.is_walking:
			continue
		if transport_definition.research_unlock_id.is_empty() or (
			campaign != null and campaign.has_completed_research(transport_definition.research_unlock_id)
		):
			result.append(transport_definition)
	return result


# One exact constructed Stable houses one exact transport. Stable level no
# longer creates invisible transport capacity.
func stable_space_capacity(campaign: CampaignState) -> int:
	if campaign == null or campaign.stronghold == null:
		return 0
	var total: int = 0
	for facility in campaign.stronghold.get_facilities():
		if (
			facility != null
			and facility.definition_id == STABLES_DEFINITION_ID
			and facility.condition != &"under_construction"
		):
			total += 1
	return total


func support_snapshot(campaign: CampaignState) -> Dictionary:
	var asset_entries: Array[Dictionary] = []
	if campaign != null:
		for asset: TransportState in campaign.get_transports():
			var transport_definition: SquadTransportDefinition = definition(asset.definition_id)
			if transport_definition == null:
				continue
			asset_entries.append({
				"transport_id": String(asset.transport_id),
				"definition_id": String(asset.definition_id),
				"display_name": asset.custom_name if not asset.custom_name.is_empty() else transport_definition.display_name,
				"type_name": transport_definition.display_name,
				"status": String(asset.status),
				"assigned_bay_id": String(asset.assigned_bay_id),
				"supported": true,
				"available": asset.is_available_for_bay(),
				"stable_space_required": transport_definition.stable_bays_required,
				"stable_bays_required": transport_definition.stable_bays_required,
				"reserved_mission_id": String(asset.reserved_mission_id),
			})
	asset_entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("display_name", "")).naturalnocasecmp_to(String(b.get("display_name", ""))) < 0
	)
	var housed_count: int = 0
	for entry: Dictionary in asset_entries:
		if not String(entry.get("assigned_bay_id", "")).is_empty():
			housed_count += 1
	return {
		"capacity": stable_space_capacity(campaign),
		"used": housed_count,
		"over_capacity": housed_count > stable_space_capacity(campaign),
		"assets": asset_entries,
	}


func available_transport_choices(campaign: CampaignState) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var walking: SquadTransportDefinition = definition(WALKING_ID)
	var walking_data: Dictionary = walking.to_dictionary()
	walking_data["available_instances"] = 0
	walking_data["available_instance_ids"] = []
	walking_data["owned_instances"] = 0
	walking_data["is_available"] = true
	choices.append(walking_data)
	var by_definition: Dictionary = {}
	if campaign != null:
		for asset: TransportState in campaign.get_transports():
			if not by_definition.has(asset.definition_id):
				by_definition[asset.definition_id] = {"owned": 0, "available_ids": []}
			var group: Dictionary = by_definition[asset.definition_id] as Dictionary
			group["owned"] = int(group.get("owned", 0)) + 1
			if asset.is_available_for_bay():
				(group["available_ids"] as Array).append(String(asset.transport_id))
			by_definition[asset.definition_id] = group
	for transport_definition: SquadTransportDefinition in unlocked_definitions(campaign):
		var group: Dictionary = by_definition.get(transport_definition.id, {}) as Dictionary
		if int(group.get("owned", 0)) <= 0:
			continue
		var available_ids: Array = group.get("available_ids", []) as Array
		var data: Dictionary = transport_definition.to_dictionary()
		data["available_instances"] = available_ids.size()
		data["available_instance_ids"] = available_ids.duplicate()
		data["owned_instances"] = int(group.get("owned", 0))
		data["is_available"] = not available_ids.is_empty()
		choices.append(data)
	return choices


func default_transport_id(_campaign: CampaignState) -> StringName:
	return WALKING_ID


func transport_choice_snapshot(
		campaign: CampaignState,
		transport_definition_id: StringName,
		_requested_count: int = 1,
		character_count: int = 0
) -> Dictionary:
	var resolved_id: StringName = transport_definition_id if not transport_definition_id.is_empty() else WALKING_ID
	var transport_definition: SquadTransportDefinition = definition(resolved_id)
	if transport_definition == null:
		return {}
	if transport_definition.is_walking:
		var walking_data: Dictionary = transport_definition.to_dictionary()
		walking_data["assigned_count"] = 0
		walking_data["transport_instance_ids"] = []
		walking_data["transport_asset_id"] = ""
		walking_data["total_passenger_capacity"] = 6
		walking_data["total_cargo_capacity_lb"] = 0.0
		walking_data["total_stable_space"] = 1
		walking_data["total_stable_bays"] = 1
		walking_data["availability_valid"] = true
		walking_data["capacity_valid"] = character_count <= 6
		walking_data["validation_message"] = "Walking uses one constructed Stable, has six fixed deployment positions, and relies on survivors’ remaining carrying capacity up to maximum load."
		return walking_data
	var available_id: StringName = &""
	if campaign != null:
		for asset: TransportState in campaign.get_transports():
			if asset.definition_id == resolved_id and asset.is_available_for_bay():
				available_id = asset.transport_id
				break
	return _snapshot_for_asset(campaign, available_id, character_count)


func asset_assignment_snapshot(
		campaign: CampaignState,
		transport_asset_id: StringName,
		character_count: int = 0
) -> Dictionary:
	return _snapshot_for_asset(campaign, transport_asset_id, character_count, true)


func _snapshot_for_asset(
		campaign: CampaignState,
		transport_asset_id: StringName,
		character_count: int,
		allow_assigned: bool = false
) -> Dictionary:
	var asset: TransportState = campaign.get_transport(transport_asset_id) if campaign != null else null
	if asset == null:
		return {}
	var transport_definition: SquadTransportDefinition = definition(asset.definition_id)
	if transport_definition == null:
		return {}
	var available: bool = (
		asset.status in [TransportState.STATUS_AVAILABLE, TransportState.STATUS_ASSIGNED]
		if allow_assigned
		else asset.is_available_for_bay()
	)
	var capacity_valid: bool = character_count <= transport_definition.passenger_capacity
	var data: Dictionary = transport_definition.to_dictionary()
	data["assigned_count"] = 1
	data["transport_instance_ids"] = [String(asset.transport_id)]
	data["transport_asset_id"] = String(asset.transport_id)
	data["transport_display_name"] = asset.custom_name if not asset.custom_name.is_empty() else transport_definition.display_name
	data["total_passenger_capacity"] = transport_definition.passenger_capacity
	data["total_cargo_capacity_lb"] = transport_definition.cargo_capacity_lb
	data["total_captive_capacity"] = transport_definition.captive_capacity
	data["total_cage_anchor_capacity"] = transport_definition.cage_anchor_capacity
	data["total_monster_capacity"] = transport_definition.monster_capacity
	data["total_siege_anchor_capacity"] = transport_definition.siege_anchor_capacity
	data["total_oversized_cargo_capacity"] = transport_definition.oversized_cargo_capacity
	data["total_stable_space"] = transport_definition.stable_bays_required
	data["total_stable_bays"] = transport_definition.stable_bays_required
	data["availability_valid"] = available
	data["capacity_valid"] = capacity_valid
	data["validation_message"] = (
		"The selected transport is already deployed."
		if not available
		else "Passenger capacity %d is below the squad size %d." % [transport_definition.passenger_capacity, character_count]
		if not capacity_valid
		else "Transport assignment is available. Passenger capacity carries the squad and personal equipment; recovered assets use dedicated cargo capacity."
	)
	return data


func apply_transport_to_route(
		route: SquadRoutePlan,
		transport_definition: SquadTransportDefinition,
		exposure_entries: Array[TravelExposureEntry] = []
) -> SquadRoutePlan:
	if route == null or transport_definition == null:
		return null
	var result := SquadRoutePlan.from_dictionary(route.to_dictionary())
	var terrain_multiplier: float = terrain_multiplier_for_entries(transport_definition, exposure_entries)
	var time_multiplier: float = terrain_multiplier / maxf(0.01, transport_definition.strategic_speed_multiplier)
	for index: int in range(result.cumulative_minutes.size()):
		result.cumulative_minutes[index] = float(result.cumulative_minutes[index]) * time_multiplier
	result.fastest_route_minutes *= time_multiplier
	result.arrival_tick = result.start_tick + maxi(1, ceili(result.total_minutes()))
	return result


func terrain_multiplier_for_entries(
		transport_definition: SquadTransportDefinition,
		exposure_entries: Array[TravelExposureEntry]
) -> float:
	if transport_definition == null or exposure_entries.is_empty():
		return 1.0
	var weighted_total: float = 0.0
	var weight: int = 0
	for entry: TravelExposureEntry in exposure_entries:
		if entry == null:
			continue
		var quantity: int = maxi(1, entry.quantity)
		weighted_total += transport_definition.terrain_multiplier(entry.geographic_category) * float(quantity)
		weight += quantity
	return weighted_total / float(weight) if weight > 0 else 1.0


func notoriety_snapshot(entries: Array[TravelExposureEntry], modifier_percent: int) -> Dictionary:
	var base_total: int = 0
	for entry: TravelExposureEntry in entries:
		if entry == null:
			continue
		var has_transport_breakdown: bool = (
			entry.pre_transport_subtotal > 0
			or entry.transport_modifier_percent != 0
			or entry.transport_adjustment != 0
		)
		base_total += entry.pre_transport_subtotal if has_transport_breakdown else entry.applied_subtotal
	var final_total: int = maxi(0, roundi(float(base_total) * (1.0 + float(modifier_percent) / 100.0)))
	return {
		"base_total": base_total,
		"modifier_percent": modifier_percent,
		"adjustment": final_total - base_total,
		"final_total": final_total,
	}


func apply_notoriety_modifier_to_entries(
		entries: Array[TravelExposureEntry],
		modifier_percent: int
) -> Dictionary:
	var snapshot: Dictionary = notoriety_snapshot(entries, modifier_percent)
	var base_total: int = int(snapshot.get("base_total", 0))
	var final_total: int = int(snapshot.get("final_total", 0))
	var assigned_total: int = 0
	var last_valid: TravelExposureEntry = null
	for entry: TravelExposureEntry in entries:
		if entry == null:
			continue
		last_valid = entry
		entry.pre_transport_subtotal = entry.applied_subtotal
		entry.transport_modifier_percent = modifier_percent
		var adjusted: int = roundi(float(entry.pre_transport_subtotal) * float(final_total) / float(base_total)) if base_total > 0 else 0
		entry.applied_subtotal = maxi(0, adjusted)
		entry.transport_adjustment = entry.applied_subtotal - entry.pre_transport_subtotal
		assigned_total += entry.applied_subtotal
	if last_valid != null and assigned_total != final_total:
		last_valid.applied_subtotal = maxi(0, last_valid.applied_subtotal + final_total - assigned_total)
		last_valid.transport_adjustment = last_valid.applied_subtotal - last_valid.pre_transport_subtotal
	return snapshot


func reserve_transport_candidate(
		campaign: CampaignState,
		transport_instance_ids: Array[StringName],
		mission_instance_id: StringName,
		operation_id: StringName
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	if transport_instance_ids.size() > 1:
		return OperationResult.fail(&"mixed_transport_not_supported", "One Stable bay uses one complete transport asset.")
	for transport_id: StringName in transport_instance_ids:
		var asset: TransportState = campaign.get_transport(transport_id)
		if asset == null or asset.status not in [TransportState.STATUS_AVAILABLE, TransportState.STATUS_ASSIGNED]:
			return OperationResult.fail(&"transport_unavailable", "The selected transport is no longer available.")
	for transport_id: StringName in transport_instance_ids:
		var asset: TransportState = campaign.get_transport(transport_id)
		asset.status = TransportState.STATUS_RESERVED
		asset.reserved_mission_id = mission_instance_id
		asset.current_journey_id = operation_id
		asset.revision += 1
	campaign.revision += 1
	return OperationResult.ok(transport_instance_ids, "Transport asset reserved.")


func mark_transport_departed_candidate(campaign: CampaignState, transport_instance_ids: Array[StringName]) -> void:
	_set_status(candidate_or_null(campaign), transport_instance_ids, TransportState.STATUS_TRAVELLING_OUT)


func mark_transport_deployed_candidate(campaign: CampaignState, transport_instance_ids: Array[StringName]) -> void:
	_set_status(candidate_or_null(campaign), transport_instance_ids, TransportState.STATUS_DEPLOYED)


func mark_transport_returning_candidate(campaign: CampaignState, transport_instance_ids: Array[StringName]) -> void:
	_set_status(candidate_or_null(campaign), transport_instance_ids, TransportState.STATUS_RETURNING)


func release_transport_candidate(campaign: CampaignState, transport_instance_ids: Array[StringName]) -> void:
	if campaign == null:
		return
	for transport_id: StringName in transport_instance_ids:
		var asset: TransportState = campaign.get_transport(transport_id)
		if asset == null:
			continue
		asset.status = TransportState.STATUS_ASSIGNED if not asset.assigned_bay_id.is_empty() else TransportState.STATUS_AVAILABLE
		asset.reserved_mission_id = &""
		asset.current_journey_id = &""
		asset.revision += 1
	campaign.revision += 1


func acquire_transport_candidate(
		campaign: CampaignState,
		transport_definition_id: StringName,
		target_stable_bay_id: StringName = &""
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var transport_definition: SquadTransportDefinition = definition(transport_definition_id)
	if transport_definition == null or transport_definition.is_walking:
		return OperationResult.fail(&"transport_definition_missing", "The selected transport cannot be acquired.")
	if not transport_definition.research_unlock_id.is_empty() and not campaign.has_completed_research(transport_definition.research_unlock_id):
		return OperationResult.fail(&"transport_research_locked", "Required Research has not been completed.")

	var target_bay: StableBayState = campaign.get_stable_bay(target_stable_bay_id) if not target_stable_bay_id.is_empty() else null
	if target_bay == null:
		for candidate: StableBayState in campaign.get_stable_bays():
			if candidate.is_vacant_for_transport():
				target_bay = candidate
				break
	if target_bay == null or not target_bay.is_vacant_for_transport():
		return OperationResult.fail(&"no_empty_stable", "Construct an empty Stable before acquiring another transport.")
	if campaign.stronghold == null or campaign.stronghold.get_facility(target_bay.stable_facility_id) == null:
		return OperationResult.fail(&"stable_missing", "The selected transport housing no longer exists.")
	var stable_facility = campaign.stronghold.get_facility(target_bay.stable_facility_id)
	if stable_facility.condition not in [&"operational", &"upgrading"]:
		return OperationResult.fail(&"stable_unavailable", "The selected Stable must be operational before it can receive a transport.")

	for raw_resource_id: Variant in transport_definition.acquisition_costs.keys():
		var resource_id := StringName(raw_resource_id)
		var required: int = maxi(0, int(transport_definition.acquisition_costs.get(raw_resource_id, 0)))
		if campaign.resources.amount(resource_id) < required:
			return OperationResult.fail(&"transport_cost_unmet", "Insufficient %s to acquire this transport." % String(resource_id).capitalize())
	for raw_resource_id: Variant in transport_definition.acquisition_costs.keys():
		var resource_id := StringName(raw_resource_id)
		campaign.resources.add(resource_id, -maxi(0, int(transport_definition.acquisition_costs.get(raw_resource_id, 0))))

	var transport_id := StringName("transport.asset.%04d" % campaign.next_transport_sequence)
	campaign.next_transport_sequence += 1
	var asset := TransportState.new()
	asset.transport_id = transport_id
	asset.definition_id = transport_definition.id
	asset.housed_stable_id = target_bay.stable_facility_id
	asset.assigned_bay_id = target_bay.bay_id
	asset.status = TransportState.STATUS_ASSIGNED
	asset.custom_name = "%s %d" % [transport_definition.display_name, campaign.next_transport_sequence - 1]
	asset.history_entries.append("Acquired and housed in Stable %d." % (target_bay.bay_index + 1))
	campaign.transports_by_id[asset.transport_id] = asset

	target_bay.transport_method_id = asset.definition_id
	target_bay.transport_asset_id = asset.transport_id
	target_bay.is_walking = false
	target_bay.installed_fitting_ids.clear()
	# Passenger positions are authored by transport layout, so changing from
	# Walking to a vehicle requires the player to confirm a fresh formation.
	target_bay.formation_character_ids_by_slot.clear()
	target_bay.status = (
		StableBayState.STATUS_READY
		if target_bay.has_squad()
		else StableBayState.STATUS_EMPTY
	)
	target_bay.revision += 1
	campaign.revision += 1
	return OperationResult.ok(asset, "%s acquired and housed in Stable %d." % [transport_definition.display_name, target_bay.bay_index + 1])


func transport_dismantle_yield(transport_definition: SquadTransportDefinition) -> Dictionary:
	var recovered_materials: Dictionary = {}
	if transport_definition == null:
		return recovered_materials
	for raw_resource_id: Variant in transport_definition.acquisition_costs.keys():
		var amount: int = floori(
			float(maxi(0, int(transport_definition.acquisition_costs.get(raw_resource_id, 0))))
			* float(TRANSPORT_DISMANTLE_RECOVERY_PERCENT)
			/ 100.0
		)
		if amount > 0:
			recovered_materials[StringName(raw_resource_id)] = amount
	return recovered_materials


func transport_dismantle_yield_text(transport_definition: SquadTransportDefinition) -> String:
	var recovered_materials: Dictionary = transport_dismantle_yield(transport_definition)
	if recovered_materials.is_empty():
		return "No recoverable materials"
	var entries: Array[String] = []
	for raw_resource_id: Variant in recovered_materials.keys():
		entries.append("%s %d" % [
			String(raw_resource_id).capitalize(),
			int(recovered_materials.get(raw_resource_id, 0)),
		])
	entries.sort()
	return ", ".join(PackedStringArray(entries))


func dismantle_transport_candidate(
		campaign: CampaignState,
		transport_id: StringName
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var asset: TransportState = campaign.get_transport(transport_id)
	if asset == null:
		return OperationResult.fail(&"transport_missing", "The selected transport no longer exists.")
	if asset.is_reserved() or not asset.current_journey_id.is_empty():
		return OperationResult.fail(&"transport_reserved", "A transport assigned to an active expedition cannot be dismantled.")
	var bay: StableBayState = (
		campaign.get_stable_bay(asset.assigned_bay_id)
		if not asset.assigned_bay_id.is_empty()
		else null
	)
	if bay != null and bay.is_active():
		return OperationResult.fail(&"stable_active", "A transport cannot be dismantled while its Stable expedition is active.")
	var transport_definition: SquadTransportDefinition = definition(asset.definition_id)
	if transport_definition == null:
		return OperationResult.fail(&"transport_definition_missing", "The transport definition could not be loaded.")
	var recovered_materials: Dictionary = transport_dismantle_yield(transport_definition)
	for raw_resource_id: Variant in recovered_materials.keys():
		campaign.resources.add(
			StringName(raw_resource_id),
			maxi(0, int(recovered_materials.get(raw_resource_id, 0)))
		)
	if bay != null and bay.transport_asset_id == asset.transport_id:
		bay.clear_transport_assignment()
	campaign.transports_by_id.erase(asset.transport_id)
	campaign.revision += 1
	var display_name: String = (
		asset.custom_name
		if not asset.custom_name.is_empty()
		else transport_definition.display_name
	)
	return OperationResult.ok(
		recovered_materials,
		"%s dismantled. Stable %d is now available for Walking or another transport. Recovered materials: %s."
		% [
			display_name,
			bay.bay_index + 1 if bay != null else 0,
			transport_dismantle_yield_text(transport_definition),
		]
	)


# Compatibility wrappers retained for older callers and saves. New UI and code should use dismantle terminology.
func transport_sale_refund(transport_definition: SquadTransportDefinition) -> Dictionary:
	return transport_dismantle_yield(transport_definition)


func transport_sale_refund_text(transport_definition: SquadTransportDefinition) -> String:
	return transport_dismantle_yield_text(transport_definition)


func sell_transport_candidate(
		campaign: CampaignState,
		transport_id: StringName
) -> OperationResult:
	return dismantle_transport_candidate(campaign, transport_id)


func rename_transport_candidate(
		campaign: CampaignState,
		transport_id: StringName,
		display_name: String
) -> OperationResult:
	var asset: TransportState = campaign.get_transport(transport_id) if campaign != null else null
	if asset == null:
		return OperationResult.fail(&"transport_missing", "The selected transport no longer exists.")
	if asset.is_reserved():
		return OperationResult.fail(&"transport_reserved", "A deployed transport cannot be renamed.")
	var cleaned: String = display_name.strip_edges()
	if cleaned.is_empty():
		return OperationResult.fail(&"transport_name_missing", "Enter a transport name.")
	asset.custom_name = cleaned
	asset.revision += 1
	campaign.revision += 1
	return OperationResult.ok(asset, "Transport renamed.")


# Compatibility command retained for old UI callers. Transport support toggles
# no longer exist; all owned assets are maintained without damage state.
func set_transport_support_candidate(
		campaign: CampaignState,
		transport_id: StringName,
		_enabled: bool
) -> OperationResult:
	var asset: TransportState = campaign.get_transport(transport_id) if campaign != null else null
	if asset == null:
		return OperationResult.fail(&"transport_missing", "The selected transport no longer exists.")
	return OperationResult.ok(asset, "Transport support is automatic; assign it to a Stable bay.")


func acquisition_cost_text(transport_definition: SquadTransportDefinition) -> String:
	if transport_definition == null or transport_definition.acquisition_costs.is_empty():
		return "No acquisition cost"
	var lines: Array[String] = []
	for raw_resource_id: Variant in transport_definition.acquisition_costs.keys():
		lines.append("%s %d" % [String(raw_resource_id).capitalize(), int(transport_definition.acquisition_costs.get(raw_resource_id, 0))])
	lines.sort()
	return ", ".join(PackedStringArray(lines))


func _set_status(campaign: CampaignState, transport_instance_ids: Array[StringName], status_value: StringName) -> void:
	if campaign == null:
		return
	for transport_id: StringName in transport_instance_ids:
		var asset: TransportState = campaign.get_transport(transport_id)
		if asset != null:
			asset.status = status_value
			asset.revision += 1
	campaign.revision += 1


func candidate_or_null(campaign: CampaignState) -> CampaignState:
	return campaign


func _register_defaults() -> void:
	_register({
		"id": "transport.walking",
		"display_name": "Walking Expedition",
		"description": "Uses one empty constructed Stable. Walking always has six fixed deployment positions and recovered cargo relies on survivors’ unused carrying capacity up to maximum load.",
		"passenger_capacity": 6,
		"strategic_speed_multiplier": 1.0,
		"cargo_capacity_lb": 0.0,
		"journey_notoriety_modifier_percent": 0,
		"stable_bays_required": 1,
		"deployment_layout_id": "layout.walking",
		"is_walking": true,
	})
	_register({
		"id": "transport.pack_beast_train",
		"display_name": "Pack Beast Train",
		"description": "A complete expedition train with reliable off-road movement. Its passenger allowance carries the squad and personal equipment; recovered assets use its dedicated cargo capacity.",
		"research_unlock_id": "research.transport.pack_beasts",
		"acquisition_costs": {"gold": 80, "food": 20},
		"passenger_capacity": 6,
		"strategic_speed_multiplier": 1.10,
		"cargo_capacity_lb": 500.0,
		"journey_notoriety_modifier_percent": 5,
		"oversized_cargo_capacity": 1,
		"stable_bays_required": 1,
		"deployment_layout_id": "layout.pack_train",
		"fitting_slot_types": ["covering", "cargo", "specialist", "utility"],
		"terrain_speed_modifiers": {"remote_track": 0.95, "local_road": 0.90, "primary_road": 0.85, "forest_off_road": 1.10, "deep_wilderness": 1.05},
	})
	_register({
		"id": "transport.covered_wagon",
		"display_name": "Wagon",
		"description": "A flexible wagon that carries the squad as passengers and provides a separate recovery-cargo allowance. It can be fitted for concealment, cargo or captives without requiring a road.",
		"research_unlock_id": "research.transport.covered_wagon",
		"acquisition_costs": {"gold": 160, "wood": 30, "metal": 10},
		"passenger_capacity": 6,
		"strategic_speed_multiplier": 1.0,
		"cargo_capacity_lb": 900.0,
		"journey_notoriety_modifier_percent": 0,
		"oversized_cargo_capacity": 2,
		"stable_bays_required": 1,
		"deployment_layout_id": "layout.wagon",
		"fitting_slot_types": ["covering", "cargo", "specialist", "utility"],
		"terrain_speed_modifiers": {"remote_track": 1.10, "local_road": 0.85, "primary_road": 0.75, "forest_off_road": 1.30, "deep_wilderness": 1.20},
	})
	_register({
		"id": "transport.mounted_troop",
		"display_name": "Mounted Troop",
		"description": "Fast passenger transport with little dedicated recovery-cargo space and a conspicuous regional footprint. Rider carrying capacity is not added to its cargo rating.",
		"research_unlock_id": "research.transport.mounted_troop",
		"acquisition_costs": {"gold": 220, "food": 35},
		"passenger_capacity": 6,
		"strategic_speed_multiplier": 1.50,
		"cargo_capacity_lb": 250.0,
		"journey_notoriety_modifier_percent": 30,
		"stable_bays_required": 1,
		"deployment_layout_id": "layout.mounted",
		"fitting_slot_types": ["cargo", "specialist", "utility"],
		"terrain_speed_modifiers": {"remote_track": 0.95, "local_road": 0.85, "primary_road": 0.80, "forest_off_road": 1.15, "deep_wilderness": 1.05},
	})
	_register({
		"id": "transport.siege_hauler",
		"display_name": "Siege Hauler",
		"description": "A slow heavy expedition transport. Passenger places carry the deployed squad and personal equipment; its large cargo rating carries recovered assets, siege engines and monsters.",
		"research_unlock_id": "research.transport.siege_hauler",
		"acquisition_costs": {"gold": 300, "wood": 50, "metal": 30},
		"passenger_capacity": 2,
		"strategic_speed_multiplier": 0.70,
		"cargo_capacity_lb": 2500.0,
		"journey_notoriety_modifier_percent": 50,
		"monster_capacity": 1,
		"siege_anchor_capacity": 1,
		"oversized_cargo_capacity": 4,
		"stable_bays_required": 1,
		"deployment_layout_id": "layout.siege_hauler",
		"fitting_slot_types": ["cargo", "specialist", "utility"],
		"terrain_speed_modifiers": {"remote_track": 1.30, "local_road": 0.90, "primary_road": 0.80, "forest_off_road": 1.55, "deep_wilderness": 1.40},
	})


func _register(data: Dictionary) -> void:
	var transport_definition := SquadTransportDefinition.from_dictionary(data)
	if transport_definition.validate_definition().is_empty():
		_definitions_by_id[transport_definition.id] = transport_definition
