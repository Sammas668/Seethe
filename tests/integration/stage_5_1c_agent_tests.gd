class_name Stage51cAgentTests
extends RefCounted

const TEST_SAVE_PATH: String = "user://stage_5_1c_agent_tests.json"
const FARM_HEX: Vector2i = Vector2i(10, 10)


static func run() -> Array[String]:
	var failures: Array[String] = []
	var session := CampaignSession.new()
	session.configure(TEST_SAVE_PATH)
	session.repository.clear_save()
	var created: OperationResult = session.create_new_campaign(5103)
	_expect(created.success, "Stage 5.1c New Campaign failed: %s" % created.message, failures)
	if not created.success:
		return failures
	var campaign: CampaignState = session.current_campaign()
	var agent: AgentState = session.primary_agent()
	_expect(agent != null, "Starter Agent is missing.", failures)
	_expect(campaign.first_actionable_mission() == null, "Farm Raid began visible before Agent discovery.", failures)
	if agent == null:
		session.repository.clear_save()
		return failures
	var region: RegionMapDefinition = session.current_region_definition()
	var stronghold: RegionSiteDefinition = region.site(region.fifth_god_ruin_site_id)
	_expect(stronghold != null, "Starter stronghold is missing.", failures)
	if stronghold != null:
		_expect(agent.current_hex.key() == stronghold.coord.key(), "Agent did not begin at the stronghold.", failures)

	var destination := RegionHexCoord.from_offset(FARM_HEX.x, FARM_HEX.y)
	var preview: AgentTravelPlan = session.preview_agent_route(destination)
	_expect(preview != null, "Agent could not preview a route to the starter farm.", failures)
	if preview == null:
		session.repository.clear_save()
		return failures
	_expect(preview.route_points.size() > 3, "Agent route does not follow multiple hex-boundary points.", failures)
	_expect(preview.arrival_tick > campaign.campaign_tick, "Agent route has no strategic travel duration.", failures)
	_expect(preview.to_dictionary().has("discovery_seed"), "Agent route does not carry its deterministic discovery seed.", failures)
	_expect(preview.direction_at_tick(preview.start_tick + 1).length_squared() > 0.0, "Agent route cannot provide token-facing direction.", failures)
	var fractional_position: Vector2 = preview.map_position_at_time(float(preview.start_tick) + 0.25)
	_expect(
		fractional_position.distance_to(preview.route_points[0]) > 0.0001
		and fractional_position.distance_to(preview.map_position_at_tick(preview.start_tick + 1)) > 0.0001,
		"Agent travel plan does not support smooth fractional-time interpolation.",
		failures
	)
	_expect(
		preview.direction_at_time(float(preview.start_tick) + 0.25).length_squared() > 0.0,
		"Agent fractional-time route cannot provide token-facing direction.",
		failures
	)
	var origin_centre: Vector2 = RegionBoundaryPathfinder.map_center(stronghold.coord)
	var destination_centre: Vector2 = RegionBoundaryPathfinder.map_center(destination)
	_expect(
		preview.route_points[0].distance_to(origin_centre) < 0.001,
		"Agent route does not begin at the origin hex centre.",
		failures
	)
	_expect(
		preview.route_points[-1].distance_to(destination_centre) < 0.001,
		"Agent route does not finish at the destination hex centre.",
		failures
	)
	_expect(
		preview.cumulative_minutes.size() == preview.route_points.size()
		and preview.cumulative_minutes[1] >= 8.0,
		"Agent centre-to-boundary departure is too short to render visibly.",
		failures
	)
	var departure_mid_tick: int = preview.start_tick + maxi(
		1,
		floori(preview.cumulative_minutes[1] * 0.5)
	)
	var departure_midpoint: Vector2 = preview.map_position_at_tick(departure_mid_tick)
	_expect(
		departure_midpoint.distance_to(origin_centre) > 0.001
		and departure_midpoint.distance_to(preview.route_points[1]) > 0.001,
		"Agent does not interpolate from the hex centre to its first boundary node.",
		failures
	)
	_expect(
		preview.map_position_at_tick(preview.arrival_tick).distance_to(destination_centre) < 0.001,
		"Agent travel plan does not end at the exact destination centre.",
		failures
	)
	var lake_preview: AgentTravelPlan = session.preview_agent_route(RegionHexCoord.from_offset(6, 2))
	_expect(lake_preview == null, "Agent can be dispatched onto a lake tile.", failures)

	var dispatched: OperationResult = session.dispatch_agent(destination)
	_expect(dispatched.success, "Agent dispatch failed: %s" % dispatched.message, failures)
	agent = session.primary_agent()
	_expect(agent.status == AgentState.STATUS_TRAVELLING, "Agent did not enter travelling state.", failures)
	_expect(agent.discovery_due_tick == -1, "Agent discovery was scheduled before arrival.", failures)
	_expect(agent.pending_discovery_event_id.is_empty(), "Agent retained a discovery event while travelling.", failures)
	var saved_plan: Dictionary = agent.active_travel_plan.to_dictionary() if agent.active_travel_plan != null else {}
	var committed_plan_id: StringName = agent.active_travel_plan.plan_id if agent.active_travel_plan != null else &""
	var loaded: OperationResult = session.load_campaign()
	_expect(loaded.success, "Agent journey failed save/load: %s" % loaded.message, failures)
	agent = session.primary_agent()
	_expect(
		agent != null and agent.active_travel_plan != null and agent.active_travel_plan.to_dictionary() == saved_plan,
		"Saved Agent route changed after reload.",
		failures
	)
	if agent == null or agent.active_travel_plan == null:
		session.repository.clear_save()
		return failures

	session.set_clock_speed(StrategicClockService.SPEED_VERY_FAST)
	var minutes_to_arrival: int = agent.active_travel_plan.arrival_tick - session.current_campaign().campaign_tick
	var arrival_result: OperationResult = session.process_strategic_time(float(minutes_to_arrival + 1) / 20.0)
	_expect(arrival_result.success, "Agent journey could not reach arrival.", failures)
	agent = session.primary_agent()
	_expect(agent.status == AgentState.STATUS_DEPLOYED, "Agent did not settle on the destination tile.", failures)
	_expect(agent.current_hex.key() == destination.key(), "Agent settled on the wrong tile.", failures)
	_expect(
		session.agent_map_position().distance_to(destination_centre) < 0.001,
		"Deployed Agent is not positioned at the destination hex centre.",
		failures
	)
	_expect(agent.last_resolved_arrival_plan_id == committed_plan_id, "Agent arrival was not recorded against the committed plan.", failures)
	_expect(agent.discovery_due_tick > session.current_campaign().campaign_tick, "Hidden mission timing was not scheduled.", failures)
	_expect(not agent.pending_discovery_event_id.is_empty(), "Hidden discovery was scheduled without a stable event ID.", failures)
	var saved_discovery_due_tick: int = agent.discovery_due_tick
	var saved_discovery_event_id: StringName = agent.pending_discovery_event_id
	var saved_discovery_seed: int = agent.discovery_seed
	var deployed_reload: OperationResult = session.load_campaign()
	_expect(deployed_reload.success, "Deployed Agent failed save/load: %s" % deployed_reload.message, failures)
	agent = session.primary_agent()
	_expect(agent.discovery_due_tick == saved_discovery_due_tick, "Hidden discovery timing changed after reload.", failures)
	_expect(agent.pending_discovery_event_id == saved_discovery_event_id, "Hidden discovery event ID changed after reload.", failures)
	_expect(agent.discovery_seed == saved_discovery_seed, "Hidden discovery seed changed after reload.", failures)

	var discovered_ids: Array[StringName] = []
	session.agent_mission_discovered.connect(
		func(mission_instance_id: StringName) -> void:
			discovered_ids.append(mission_instance_id)
	)
	var minutes_to_discovery: int = agent.discovery_due_tick - session.current_campaign().campaign_tick
	session.set_clock_speed(StrategicClockService.SPEED_VERY_FAST)
	var discovery_result: OperationResult = session.process_strategic_time(float(minutes_to_discovery + 1) / 20.0)
	_expect(discovery_result.success, "Hidden Agent discovery event failed.", failures)
	var mission: ActiveMissionState = session.current_campaign().first_actionable_mission()
	_expect(mission != null, "Agent discovery produced no mission.", failures)
	if mission != null:
		_expect(mission.site_id == &"site.farm.starter_storehouse", "Agent mission appeared on the wrong tile.", failures)
	_expect(discovered_ids.size() == 1, "Mission discovery did not emit exactly one popup event.", failures)
	_expect(session.strategic_clock.speed == StrategicClockService.SPEED_PAUSED, "Mission discovery did not pause strategic time.", failures)
	agent = session.primary_agent()
	_expect(agent.last_resolved_discovery_event_id == saved_discovery_event_id, "Discovery event was not recorded as resolved exactly once.", failures)
	_expect(agent.pending_discovery_event_id != saved_discovery_event_id, "Resolved discovery event remained pending.", failures)

	var mission_count: int = session.current_campaign().get_active_missions().size()
	session.set_clock_speed(StrategicClockService.SPEED_VERY_FAST)
	session.process_strategic_time(200.0)
	_expect(
		session.current_campaign().get_active_missions().size() == mission_count,
		"Agent generated a duplicate Farm Raid.",
		failures
	)
	session.repository.clear_save()
	return failures


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
