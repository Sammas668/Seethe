class_name AgentService
extends RefCounted

const STARTING_AGENT_ID: StringName = &"agent.scout.0001"
const STARTING_AGENT_NAME: String = "Ruin Scout"
const FARM_RAID_DEFINITION_ID: StringName = &"mission_definition.life.farm_storehouse_raid_01"
const FARM_SITE_ID: StringName = &"site.farm.starter_storehouse"
const MIN_DISCOVERY_DELAY_MINUTES: int = 8 * 60
const MAX_DISCOVERY_DELAY_MINUTES: int = 30 * 60
const MAX_ACTIVE_AGENT_MISSIONS: int = 2

var _state_store: CampaignStateStore
var _region_registry: RegionDefinitionRegistry
var _mission_lifecycle := MissionLifecycleService.new()


func configure(
	state_store: CampaignStateStore,
	region_registry: RegionDefinitionRegistry
) -> void:
	_state_store = state_store
	_region_registry = region_registry


func ensure_starting_agent(campaign: CampaignState) -> bool:
	if campaign == null or campaign.agents_by_id.has(STARTING_AGENT_ID):
		return false
	var region: RegionMapDefinition = _region(campaign.current_region_id)
	if region == null:
		return false
	var stronghold: RegionSiteDefinition = region.site(region.fifth_god_ruin_site_id)
	if stronghold == null or stronghold.coord == null:
		return false
	var agent := AgentState.new()
	agent.agent_id = STARTING_AGENT_ID
	agent.display_name = STARTING_AGENT_NAME
	agent.current_region_id = campaign.current_region_id
	agent.current_hex = stronghold.coord.duplicate_coord()
	agent.status = AgentState.STATUS_AT_STRONGHOLD
	campaign.agents_by_id[agent.agent_id] = agent
	campaign.revision += 1
	return true


func primary_agent(campaign: CampaignState = null) -> AgentState:
	var source: CampaignState = campaign
	if source == null and _state_store != null:
		source = _state_store.current_campaign()
	if source == null:
		return null
	return source.agents_by_id.get(STARTING_AGENT_ID) as AgentState


func preview_plan(destination: RegionHexCoord) -> AgentTravelPlan:
	var campaign: CampaignState = _state_store.current_campaign() if _state_store != null else null
	var agent: AgentState = primary_agent(campaign)
	if campaign == null or agent == null or not agent.is_available_for_dispatch():
		return null
	var region: RegionMapDefinition = _region(agent.current_region_id)
	if region == null:
		return null
	var next_sequence: int = agent.deployment_sequence + 1
	var plan: AgentTravelPlan = RegionBoundaryPathfinder.build_plan(
		region,
		agent.agent_id,
		agent.current_hex,
		destination,
		campaign.campaign_tick,
		next_sequence
	)
	if plan != null:
		plan.discovery_seed = _deployment_seed(campaign, agent, destination, next_sequence)
	return plan


func dispatch(destination: RegionHexCoord) -> OperationResult:
	var campaign: CampaignState = _state_store.current_campaign() if _state_store != null else null
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var agent: AgentState = primary_agent(campaign)
	if agent == null:
		return OperationResult.fail(&"agent_missing", "No Agent is available.")
	if not agent.is_available_for_dispatch():
		return OperationResult.fail(&"agent_in_transit", "The Agent is already travelling.")
	var plan: AgentTravelPlan = preview_plan(destination)
	if plan == null:
		return OperationResult.fail(&"agent_route_unavailable", "No valid boundary route reaches that tile.")
	var changes := CampaignChangeSet.new()
	changes.configure(&"agent_dispatched", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			var candidate_agent: AgentState = primary_agent(candidate)
			if candidate_agent == null or not candidate_agent.is_available_for_dispatch():
				return OperationResult.fail(&"agent_dispatch_conflict", "The Agent is no longer available.")
			candidate_agent.deployment_sequence += 1
			var committed_plan := AgentTravelPlan.from_dictionary(plan.to_dictionary())
			committed_plan.plan_id = StringName(
				"agent_travel.%s.%04d"
				% [candidate_agent.agent_id, candidate_agent.deployment_sequence]
			)
			candidate_agent.status = AgentState.STATUS_TRAVELLING
			candidate_agent.active_travel_plan = committed_plan
			candidate_agent.discovery_due_tick = -1
			candidate_agent.discovery_seed = committed_plan.discovery_seed
			candidate_agent.pending_discovery_event_id = &""
			candidate_agent.discovery_attempt_sequence = 0
			candidate.revision += 1
			return OperationResult.ok(candidate)
	)
	return _state_store.commit(changes)


func advance_candidate(candidate: CampaignState) -> bool:
	if candidate == null:
		return false
	var agent: AgentState = primary_agent(candidate)
	if agent == null:
		return false
	var changed: bool = false
	if (
		agent.status == AgentState.STATUS_TRAVELLING
		and agent.active_travel_plan != null
		and candidate.campaign_tick >= agent.active_travel_plan.arrival_tick
	):
		var completed_plan: AgentTravelPlan = agent.active_travel_plan
		if agent.last_resolved_arrival_plan_id != completed_plan.plan_id:
			agent.current_hex = completed_plan.destination_hex.duplicate_coord()
			agent.status = AgentState.STATUS_DEPLOYED
			agent.last_resolved_arrival_plan_id = completed_plan.plan_id
			agent.discovery_seed = completed_plan.discovery_seed
			agent.discovery_attempt_sequence = 0
			agent.active_travel_plan = null
			_schedule_discovery(candidate, agent)
			candidate.revision += 1
			changed = true
		else:
			agent.active_travel_plan = null
			agent.status = AgentState.STATUS_DEPLOYED
			changed = true
	if (
		agent.status == AgentState.STATUS_DEPLOYED
		and agent.discovery_due_tick >= 0
		and candidate.campaign_tick >= agent.discovery_due_tick
	):
		var event_id: StringName = agent.pending_discovery_event_id
		if not event_id.is_empty() and event_id != agent.last_resolved_discovery_event_id:
			var region: RegionMapDefinition = _region(agent.current_region_id)
			_create_eligible_mission(candidate, agent, region)
			agent.last_resolved_discovery_event_id = event_id
		agent.discovery_attempt_sequence += 1
		_schedule_discovery(candidate, agent)
		candidate.revision += 1
		changed = true
	return changed


func agent_map_position(campaign: CampaignState = null) -> Vector2:
	var source: CampaignState = campaign
	if source == null and _state_store != null:
		source = _state_store.current_campaign()
	var agent: AgentState = primary_agent(source)
	if source == null or agent == null or agent.current_hex == null:
		return Vector2.ZERO
	if agent.status == AgentState.STATUS_TRAVELLING and agent.active_travel_plan != null:
		return agent.active_travel_plan.map_position_at_tick(source.campaign_tick)
	return RegionBoundaryPathfinder.map_center(agent.current_hex)


func eligible_discovery_candidates(
	campaign: CampaignState,
	agent: AgentState,
	region: RegionMapDefinition
) -> Array[AgentDiscoveryCandidate]:
	var result: Array[AgentDiscoveryCandidate] = []
	if campaign == null or agent == null or region == null:
		return result
	var farm_candidate := AgentDiscoveryCandidate.new()
	farm_candidate.mission_definition_id = FARM_RAID_DEFINITION_ID
	farm_candidate.site_id = FARM_SITE_ID
	farm_candidate.eligibility_priority = 100
	farm_candidate.unique_or_repeatable = &"unique"
	farm_candidate.required_tags = [&"FARM", &"MISSION_SOURCE"]
	if campaign.campaign_status != CampaignStatus.ACTIVE:
		farm_candidate.exclusion_reasons.append(&"CAMPAIGN_NOT_ACTIVE")
	if agent.status != AgentState.STATUS_DEPLOYED:
		farm_candidate.exclusion_reasons.append(&"AGENT_NOT_DEPLOYED")
	if campaign.get_active_missions().size() >= MAX_ACTIVE_AGENT_MISSIONS:
		farm_candidate.exclusion_reasons.append(&"ACTIVE_MISSION_LIMIT")
	if _mission_definition_already_used(campaign, FARM_RAID_DEFINITION_ID):
		farm_candidate.exclusion_reasons.append(&"UNIQUE_MISSION_ALREADY_USED")
	var farm: RegionSiteDefinition = region.site(FARM_SITE_ID)
	if farm == null or farm.coord == null:
		farm_candidate.exclusion_reasons.append(&"SITE_MISSING")
	elif _hex_distance(agent.current_hex, farm.coord) > agent.operating_radius():
		farm_candidate.exclusion_reasons.append(&"OUTSIDE_AGENT_RADIUS")
	result.append(farm_candidate)
	result.sort_custom(
		func(a: AgentDiscoveryCandidate, b: AgentDiscoveryCandidate) -> bool:
			if a.eligibility_priority != b.eligibility_priority:
				return a.eligibility_priority > b.eligibility_priority
			return String(a.site_id) < String(b.site_id)
	)
	return result


func _create_eligible_mission(
	campaign: CampaignState,
	agent: AgentState,
	region: RegionMapDefinition
) -> bool:
	for candidate: AgentDiscoveryCandidate in eligible_discovery_candidates(campaign, agent, region):
		if not candidate.is_eligible():
			continue
		var mission := ActiveMissionState.new()
		mission.mission_instance_id = campaign.next_mission_instance_id()
		mission.mission_definition_id = candidate.mission_definition_id
		mission.site_id = candidate.site_id
		mission.mission_seed = absi(hash("%d:%s:%s" % [
			campaign.campaign_seed,
			mission.mission_instance_id,
			mission.mission_definition_id,
		]))
		_mission_lifecycle.configure_new_mission(mission, campaign, agent.agent_id)
		if not campaign.upsert_active_mission(mission):
			continue
		agent.last_generated_site_id = candidate.site_id
		campaign.revision += 1
		return true
	return false


func _mission_definition_already_used(
	campaign: CampaignState,
	definition_id: StringName
) -> bool:
	for mission: ActiveMissionState in campaign.get_active_missions():
		if mission.mission_definition_id == definition_id:
			return true
	return false


func _schedule_discovery(campaign: CampaignState, agent: AgentState) -> void:
	if campaign == null or agent == null:
		return
	agent.pending_discovery_event_id = StringName(
		"agent_discovery.%s.%04d.%03d"
		% [agent.agent_id, agent.deployment_sequence, agent.discovery_attempt_sequence]
	)
	agent.discovery_due_tick = campaign.campaign_tick + _discovery_delay(agent)


func _discovery_delay(agent: AgentState) -> int:
	var span: int = MAX_DISCOVERY_DELAY_MINUTES - MIN_DISCOVERY_DELAY_MINUTES + 1
	var seed_text: String = "%d:%s:%d:%d" % [
		agent.discovery_seed,
		agent.agent_id,
		agent.deployment_sequence,
		agent.discovery_attempt_sequence,
	]
	return MIN_DISCOVERY_DELAY_MINUTES + posmod(hash(seed_text), span)


func _deployment_seed(
	campaign: CampaignState,
	agent: AgentState,
	destination: RegionHexCoord,
	deployment_sequence: int
) -> int:
	return hash("%d:%s:%d:%d,%d" % [
		campaign.campaign_seed,
		agent.agent_id,
		deployment_sequence,
		destination.offset_col,
		destination.offset_row,
	])


func _region(region_id: StringName) -> RegionMapDefinition:
	return _region_registry.definition(region_id) if _region_registry != null else null


func _hex_distance(first: RegionHexCoord, second: RegionHexCoord) -> int:
	if first == null or second == null:
		return 999999
	var dq: int = first.q - second.q
	var dr: int = first.r - second.r
	var ds: int = (-first.q - first.r) - (-second.q - second.r)
	return maxi(abs(dq), maxi(abs(dr), abs(ds)))
