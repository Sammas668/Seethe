class_name SquadRoutePlanningService
extends RefCounted

const MAXIMUM_DETOUR_MULTIPLIER: float = 2.0


func preview_route(
	campaign: CampaignState,
	region: RegionMapDefinition,
	mission: ActiveMissionState,
	waypoints: Array[RegionHexCoord]
) -> SquadRoutePlan:
	var started_usec: int = RuntimeStallAttribution.begin()
	if campaign == null or region == null or mission == null:
		RuntimeStallAttribution.end(&"squad_route_calculation", started_usec, "missing_input")
		return null
	var stronghold: RegionSiteDefinition = region.site(region.fifth_god_ruin_site_id)
	var destination_site: RegionSiteDefinition = region.site(mission.site_id)
	if stronghold == null or destination_site == null or stronghold.coord == null or destination_site.coord == null:
		RuntimeStallAttribution.end(&"squad_route_calculation", started_usec, "missing_endpoint")
		return null
	var clean_waypoints: Array[RegionHexCoord] = []
	var seen_waypoints: Dictionary = {}
	for waypoint: RegionHexCoord in waypoints:
		if waypoint == null:
			continue
		if seen_waypoints.has(waypoint.key()):
			RuntimeStallAttribution.end(&"squad_route_calculation", started_usec, "duplicate_waypoint")
			return null
		var hex: RegionHexDefinition = region.hex_at_offset(waypoint.offset_col, waypoint.offset_row)
		if hex == null or not hex.playable or hex.terrain_type == RegionTerrainType.LAKE:
			RuntimeStallAttribution.end(&"squad_route_calculation", started_usec, "invalid_waypoint")
			return null
		seen_waypoints[waypoint.key()] = true
		clean_waypoints.append(waypoint.duplicate_coord())
	var fastest_leg: AgentTravelPlan = RegionBoundaryPathfinder.build_plan(
		region,
		&"squad.fastest",
		stronghold.coord,
		destination_site.coord,
		campaign.campaign_tick,
		0
	)
	if fastest_leg == null:
		RuntimeStallAttribution.end(&"squad_route_calculation", started_usec, "no_fastest_route")
		return null
	var checkpoints: Array[RegionHexCoord] = [stronghold.coord.duplicate_coord()]
	checkpoints.append_array(clean_waypoints)
	checkpoints.append(destination_site.coord.duplicate_coord())
	var route := SquadRoutePlan.new()
	route.route_id = StringName("squad_route.preview.%s" % mission.mission_instance_id)
	route.mission_instance_id = mission.mission_instance_id
	route.origin_hex = stronghold.coord.duplicate_coord()
	route.destination_hex = destination_site.coord.duplicate_coord()
	route.waypoint_hexes = clean_waypoints
	route.start_tick = campaign.campaign_tick
	route.fastest_route_minutes = fastest_leg.total_minutes()
	var elapsed: float = 0.0
	var used_segments: Dictionary = {}
	for index: int in range(checkpoints.size() - 1):
		var leg: AgentTravelPlan = RegionBoundaryPathfinder.build_plan(
			region,
			&"squad.route",
			checkpoints[index],
			checkpoints[index + 1],
			campaign.campaign_tick,
			index + 1
		)
		if leg == null:
			RuntimeStallAttribution.end(&"squad_route_calculation", started_usec, "leg_unreachable")
			return null
		for point_index: int in range(leg.route_points.size()):
			if index > 0 and point_index == 0:
				continue
			var point: Vector2 = leg.route_points[point_index]
			if not route.route_points.is_empty():
				var segment_key: StringName = _segment_key(route.route_points[-1], point)
				if used_segments.has(segment_key):
					RuntimeStallAttribution.end(&"squad_route_calculation", started_usec, "repeated_segment")
					return null
				used_segments[segment_key] = true
			route.route_points.append(point)
			var leg_time: float = leg.cumulative_minutes[point_index] if point_index < leg.cumulative_minutes.size() else 0.0
			route.cumulative_minutes.append(elapsed + leg_time)
		elapsed += leg.total_minutes()
	if route.total_minutes() > route.fastest_route_minutes * MAXIMUM_DETOUR_MULTIPLIER + 0.001:
		RuntimeStallAttribution.end(&"squad_route_calculation", started_usec, "detour_limit")
		return null
	route.arrival_tick = route.start_tick + maxi(1, ceili(route.total_minutes()))
	RuntimeStallAttribution.end(&"squad_route_calculation", started_usec, "waypoints=%d" % clean_waypoints.size())
	return route


func _segment_key(first: Vector2, second: Vector2) -> StringName:
	var a: String = "%d,%d" % [roundi(first.x * 100000.0), roundi(first.y * 100000.0)]
	var b: String = "%d,%d" % [roundi(second.x * 100000.0), roundi(second.y * 100000.0)]
	if b < a:
		var swap: String = a
		a = b
		b = swap
	return StringName("%s|%s" % [a, b])
