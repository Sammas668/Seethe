class_name SquadTravelService
extends RefCounted

var _region_registry: RegionDefinitionRegistry
var _notoriety_service := SubregionNotorietyService.new()
var _retaliation_service := RegionalRetaliationService.new()
var _transport_service: SquadTransportService
var _stable_bay_service: StableBayService
var _loadout_service: LoadoutService
var _prison_capacity_service: PrisonCapacityService


func configure(
		region_registry: RegionDefinitionRegistry,
		transport_service: SquadTransportService = null,
		stable_bay_service: StableBayService = null,
		loadout_service: LoadoutService = null,
		prison_capacity_service: PrisonCapacityService = null
) -> void:
	_region_registry = region_registry
	_transport_service = transport_service
	_stable_bay_service = stable_bay_service
	_loadout_service = loadout_service
	_prison_capacity_service = prison_capacity_service


func advance_candidate(candidate: CampaignState) -> Dictionary:
	var result: Dictionary = {
		"arrived_mission_ids": [],
		"returned_operation_ids": [],
		"report_ids": [],
		"raid_ids": [],
	}
	if candidate == null:
		return result
	var region: RegionMapDefinition = (
		_region_registry.definition(candidate.current_region_id)
		if _region_registry != null
		else null
	)
	if region == null:
		return result
	_notoriety_service.ensure_region_states(candidate, region)
	for operation: SquadTravelOperationState in candidate.get_squad_travel_operations():
		if operation == null or operation.status not in [
			SquadTravelOperationState.STATUS_TRAVELLING,
			SquadTravelOperationState.STATUS_RETURNING,
		]:
			continue
		for entry: TravelExposureEntry in operation.exposure_entries:
			if entry == null or entry.applied or candidate.campaign_tick < entry.completion_tick:
				continue
			var application: Dictionary = _apply_exposure_entry(candidate, region, operation, entry)
			var report_id := StringName(application.get("report_id", ""))
			var raid_id := StringName(application.get("raid_id", ""))
			if not report_id.is_empty():
				(result["report_ids"] as Array).append(report_id)
			if not raid_id.is_empty():
				(result["raid_ids"] as Array).append(raid_id)
		if operation.status == SquadTravelOperationState.STATUS_RETURNING:
			if candidate.campaign_tick < operation.return_arrival_tick:
				continue
			operation.status = SquadTravelOperationState.STATUS_RESOLVED
			operation.revision += 1
			if not operation.reservation_id.is_empty():
				candidate.release_strategic_reservation(operation.reservation_id)
			for raw_item: Variant in candidate.get_items():
				var returning_item: CampaignItemState = raw_item as CampaignItemState
				if (
					returning_item != null
					and returning_item.location != null
					and returning_item.location.location_type == CampaignItemLocationState.LOCATION_RETURN_TRANSIT
					and returning_item.location.owner_id == operation.operation_id
				):
					returning_item.location = CampaignItemLocationState.stronghold_storage()
					returning_item.revision += 1
			if _prison_capacity_service != null:
				_prison_capacity_service.admit_returning_candidate(candidate, operation.operation_id)
			else:
				var captive_transit_id := StringName("return_transit.%s" % operation.operation_id)
				for captive: CampaignCaptiveState in candidate.get_captives():
					if captive.holding_location_id == captive_transit_id:
						captive.holding_location_id = &"stronghold.awaiting_admission"
			# Auto-replenishment is deliberately deferred until after this arrival
			# state has been validated and persisted. A malformed replacement plan
			# must never prevent the squad, transport or recovered cargo from
			# completing the return journey.
			if _transport_service != null:
				_transport_service.release_transport_candidate(candidate, operation.transport_instance_ids)
			else:
				for transport_id: StringName in operation.transport_instance_ids:
					var asset: TransportState = candidate.get_transport(transport_id)
					if asset != null:
						asset.status = TransportState.STATUS_AVAILABLE
						asset.reserved_mission_id = &""
						asset.current_journey_id = &""
						asset.revision += 1
			if _stable_bay_service != null:
				_stable_bay_service.release_after_return_candidate(candidate, operation.stable_bay_id)
			candidate.campaign_status = CampaignStatus.ACTIVE
			candidate.revision += 1
			(result["returned_operation_ids"] as Array).append(operation.operation_id)
			continue
		if candidate.campaign_tick < operation.arrival_tick:
			continue
		if (
			operation.arrival_event_id.is_empty()
			or operation.last_resolved_arrival_event_id == operation.arrival_event_id
			or candidate.resolved_strategic_event_ids.has(operation.arrival_event_id)
		):
			continue
		operation.status = SquadTravelOperationState.STATUS_IN_TACTICAL
		if _stable_bay_service != null:
			_stable_bay_service.mark_at_mission_candidate(candidate, operation.stable_bay_id)
		if _transport_service != null:
			_transport_service.mark_transport_deployed_candidate(candidate, operation.transport_instance_ids)
		operation.last_resolved_arrival_event_id = operation.arrival_event_id
		operation.revision += 1
		candidate.resolved_strategic_event_ids[operation.arrival_event_id] = true
		var mission: ActiveMissionState = candidate.get_active_mission(operation.mission_instance_id)
		if mission != null:
			mission.status = ActiveMissionState.STATUS_IN_TACTICAL
			candidate.campaign_status = CampaignStatus.IN_TACTICAL
			(result["arrived_mission_ids"] as Array).append(mission.mission_instance_id)
		candidate.revision += 1
	return result


func current_operation(campaign: CampaignState) -> SquadTravelOperationState:
	if campaign == null:
		return null
	for operation: SquadTravelOperationState in campaign.get_squad_travel_operations():
		if operation != null and operation.is_active():
			return operation
	return null


func squad_map_position(campaign: CampaignState, campaign_time: float = -1.0) -> Vector2:
	var operation: SquadTravelOperationState = current_operation(campaign)
	if campaign == null or operation == null or operation.route_plan == null:
		return Vector2.INF
	var time_value: float = float(campaign.campaign_tick) if campaign_time < 0.0 else campaign_time
	return operation.map_position_at_time(time_value)


func _apply_exposure_entry(
	campaign: CampaignState,
	region: RegionMapDefinition,
	operation: SquadTravelOperationState,
	entry: TravelExposureEntry
) -> Dictionary:
	var old_regional_total: int = _notoriety_service.regional_total(campaign, region.id)
	var local: SubregionNotorietyState = _notoriety_service.state(
		campaign,
		region.id,
		entry.subregion_id
	)
	if local == null:
		entry.applied = true
		return {}
	var report := TravelNotorietyReport.new()
	report.report_id = StringName(
		"travel_report.%s.%04d" % [campaign.campaign_id, campaign.next_notoriety_report_sequence]
	)
	campaign.next_notoriety_report_sequence += 1
	report.source_travel_operation_id = operation.operation_id
	report.subregion_id = entry.subregion_id
	report.exposure_entry_ids = [entry.entry_id]
	report.base_subtotal = entry.base_subtotal
	var pre_transport: int = entry.pre_transport_subtotal if entry.pre_transport_subtotal > 0 else entry.applied_subtotal
	report.visibility_adjustment = maxi(0, pre_transport - entry.base_subtotal)
	report.transport_modifier_percent = entry.transport_modifier_percent
	report.transport_adjustment = entry.transport_adjustment
	report.old_local_value = local.value
	report.old_regional_total = old_regional_total
	report.created_tick = campaign.campaign_tick
	report.line_items.append({
		"label": entry.report_text,
		"value": entry.base_subtotal,
	})
	if report.visibility_adjustment > 0:
		report.line_items.append({
			"label": "%s-visibility squad" % String(entry.visibility_category).capitalize(),
			"value": report.visibility_adjustment,
		})
	if report.transport_modifier_percent != 0 or report.transport_adjustment != 0:
		report.line_items.append({
			"label": "Transport modifier (%+d%%)" % report.transport_modifier_percent,
			"value": report.transport_adjustment,
		})
	var applied: int = local.apply_delta(entry.applied_subtotal, report.report_id)
	report.applied_delta = applied
	report.new_local_value = local.value
	entry.applied = true
	operation.revision += 1
	var new_regional_total: int = _notoriety_service.regional_total(campaign, region.id)
	report.new_regional_total = new_regional_total
	var raid: RaidOperationState = _retaliation_service.create_if_threshold_crossed(
		campaign,
		region,
		old_regional_total,
		new_regional_total
	)
	if raid != null:
		report.created_raid_operation_id = raid.operation_id
	campaign.travel_notoriety_reports_by_id[report.report_id] = report
	campaign.revision += 1
	return {
		"report_id": report.report_id,
		"raid_id": report.created_raid_operation_id,
	}
