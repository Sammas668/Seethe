class_name Stage51dMissionRoutesNotorietyTests
extends RefCounted

const TEST_SAVE_PATH: String = "user://stage_5_1d_mission_routes_notoriety_tests.json"
const FARM_HEX: Vector2i = Vector2i(10, 10)


static func run() -> Array[String]:
	var failures: Array[String] = []
	var session := CampaignSession.new()
	session.configure(TEST_SAVE_PATH)
	session.repository.clear_save()
	var created: OperationResult = session.create_new_campaign(5104)
	_expect(created.success, "Stage 5.1d New Campaign failed: %s" % created.message, failures)
	if not created.success:
		return failures
	var campaign: CampaignState = session.current_campaign()
	var region: RegionMapDefinition = session.current_region_definition()
	_expect(campaign.get_subregion_notoriety_states(region.id).size() == 4, "Starter region did not create four local Notoriety meters.", failures)
	_expect(campaign.regional_notoriety_total(region.id) == 0, "Starter regional retaliation total was not zero.", failures)

	var destination := RegionHexCoord.from_offset(FARM_HEX.x, FARM_HEX.y)
	var dispatched_agent: OperationResult = session.dispatch_agent(destination)
	_expect(dispatched_agent.success, "Agent dispatch failed: %s" % dispatched_agent.message, failures)
	if not dispatched_agent.success:
		session.repository.clear_save()
		return failures
	var agent: AgentState = session.primary_agent()
	session.set_clock_speed(StrategicClockService.SPEED_VERY_FAST)
	var arrival_minutes: int = agent.active_travel_plan.arrival_tick - campaign.campaign_tick + 1
	session.process_strategic_time(float(arrival_minutes) / 20.0)
	agent = session.primary_agent()
	var discovery_minutes: int = agent.discovery_due_tick - session.current_campaign().campaign_tick + 1
	session.set_clock_speed(StrategicClockService.SPEED_VERY_FAST)
	session.process_strategic_time(float(discovery_minutes) / 20.0)
	campaign = session.current_campaign()
	var mission: ActiveMissionState = campaign.first_actionable_mission()
	_expect(mission != null, "Agent discovery produced no Stage 5.1d mission.", failures)
	if mission == null:
		session.repository.clear_save()
		return failures
	_expect(mission.is_available(), "Discovered mission did not enter AVAILABLE state.", failures)
	_expect(mission.expiry_tick > campaign.campaign_tick, "Discovered mission has no future expiry tick.", failures)
	_expect(session.strategic_speed() == StrategicClockService.SPEED_PAUSED, "Discovery did not pause mission planning.", failures)
	var paused_tick: int = campaign.campaign_tick
	session.process_strategic_time(30.0)
	_expect(session.current_campaign().campaign_tick == paused_tick, "Mission expiry advanced while strategic time was paused.", failures)

	var definition: MissionDefinition = MissionDefinitionRegistry.definition(mission.mission_definition_id)
	_expect(definition != null, "Farm Raid definition is unavailable.", failures)
	if definition == null:
		session.repository.clear_save()
		return failures
	var selected: Array[StringName] = definition.player_character_ids.duplicate()
	var visibility: SquadVisibilitySnapshot = session.squad_visibility(selected)
	_expect(visibility != null and visibility.validate_state().is_empty(), "Squad visibility snapshot is invalid.", failures)
	_expect(visibility != null and visibility.total_visibility > 0, "Squad visibility was not calculated.", failures)
	var preview: Dictionary = session.preview_squad_operation(mission.mission_instance_id, selected, [])
	var route: SquadRoutePlan = preview.get("route") as SquadRoutePlan
	var entries: Array = preview.get("entries", []) as Array
	_expect(route != null and route.validate_state().is_empty(), "Fastest squad route is invalid.", failures)
	_expect(route != null and route.route_points[0].distance_to(RegionBoundaryPathfinder.map_center(route.origin_hex)) < 0.001, "Squad route does not start at the stronghold centre.", failures)
	_expect(route != null and route.route_points[-1].distance_to(RegionBoundaryPathfinder.map_center(route.destination_hex)) < 0.001, "Squad route does not end at the mission centre.", failures)
	_expect(visibility != null and float(preview.get("projected_total", -1)) >= 0.0, "Travel Notoriety projection is missing.", failures)

	var dispatched: OperationResult = session.dispatch_squad(mission.mission_instance_id, selected, [])
	_expect(dispatched.success, "Squad dispatch failed: %s" % dispatched.message, failures)
	if not dispatched.success:
		session.repository.clear_save()
		return failures
	campaign = session.current_campaign()
	mission = campaign.get_active_mission(mission.mission_instance_id)
	var operation: SquadTravelOperationState = campaign.current_squad_travel_operation()
	_expect(mission.status == ActiveMissionState.STATUS_EN_ROUTE, "Dispatched mission did not enter EN_ROUTE state.", failures)
	_expect(mission.expiry_suspended_tick == campaign.campaign_tick, "Dispatch did not suspend mission expiry.", failures)
	_expect(not mission.can_expire(), "Dispatched mission can still expire.", failures)
	_expect(operation != null and operation.status == SquadTravelOperationState.STATUS_TRAVELLING, "Squad travel operation was not created.", failures)
	_expect(operation != null and operation.character_ids == selected, "Committed squad differs from preview selection.", failures)
	var saved_operation: Dictionary = operation.to_dictionary() if operation != null else {}
	var reloaded: OperationResult = session.load_campaign()
	_expect(reloaded.success, "Squad travel failed save/load: %s" % reloaded.message, failures)
	operation = session.current_campaign().current_squad_travel_operation()
	_expect(operation != null and operation.to_dictionary() == saved_operation, "Committed squad route changed after reload.", failures)

	var arrived_ids: Array[StringName] = []
	session.squad_arrived.connect(func(mission_id: StringName) -> void: arrived_ids.append(mission_id))
	session.set_clock_speed(StrategicClockService.SPEED_VERY_FAST)
	var travel_minutes: int = operation.arrival_tick - session.current_campaign().campaign_tick + 1
	var travel_result: OperationResult = session.process_strategic_time(float(travel_minutes) / 20.0)
	_expect(travel_result.success, "Squad travel could not reach the mission.", failures)
	campaign = session.current_campaign()
	operation = campaign.get_squad_travel_operation(operation.operation_id)
	mission = campaign.get_active_mission(mission.mission_instance_id)
	_expect(operation.status == SquadTravelOperationState.STATUS_IN_TACTICAL, "Squad did not enter tactical state on arrival.", failures)
	_expect(mission.status == ActiveMissionState.STATUS_IN_TACTICAL, "Mission did not enter tactical state on squad arrival.", failures)
	_expect(arrived_ids.size() == 1, "Squad arrival did not emit exactly once.", failures)
	var applied_total: int = 0
	for raw_report: Variant in campaign.travel_notoriety_reports_by_id.values():
		var report: TravelNotorietyReport = raw_report as TravelNotorietyReport
		if report != null:
			applied_total += report.applied_delta
	_expect(campaign.regional_notoriety_total(region.id) == applied_total, "Regional retaliation total does not equal itemised travel reports.", failures)

	var retaliation := RegionalRetaliationService.new()
	var local_states: Array[SubregionNotorietyState] = campaign.get_subregion_notoriety_states(region.id)
	if not local_states.is_empty():
		local_states[0].value = 100
	if local_states.size() > 1:
		local_states[1].value = 49
	var old_total: int = campaign.regional_notoriety_total(region.id)
	if local_states.size() > 1:
		local_states[1].value = 50
	var new_total: int = campaign.regional_notoriety_total(region.id)
	var raid: RaidOperationState = retaliation.create_if_threshold_crossed(campaign, region, old_total, new_total)
	_expect(raid != null, "Crossing the cumulative threshold did not create a raid operation.", failures)
	var duplicate_raid: RaidOperationState = retaliation.create_if_threshold_crossed(campaign, region, old_total, new_total)
	_expect(duplicate_raid == null, "Threshold crossing created a duplicate active raid.", failures)

	session.repository.clear_save()
	return failures


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
