class_name MissionLifecycleService
extends RefCounted

const DEFAULT_MINIMUM_AVAILABILITY_MINUTES: int = 60 * 48
const DEFAULT_MAXIMUM_AVAILABILITY_MINUTES: int = 60 * 84


func configure_new_mission(
	mission: ActiveMissionState,
	campaign: CampaignState,
	discovering_agent_id: StringName
) -> void:
	if mission == null or campaign == null:
		return
	mission.status = ActiveMissionState.STATUS_AVAILABLE
	mission.discovered_tick = campaign.campaign_tick
	mission.created_campaign_tick = campaign.campaign_tick
	mission.discovering_agent_id = discovering_agent_id
	mission.expiry_tick = campaign.campaign_tick + _availability_duration(campaign, mission)
	mission.expiry_event_id = StringName("mission_expiry.%s" % mission.mission_instance_id)
	mission.risk_rating = &"low"
	mission.opposition_information = &"estimated"
	mission.reward_preview = ["Grain", "Equipment", "Furnishings"]


func advance_candidate(candidate: CampaignState) -> Array[StringName]:
	var expired: Array[StringName] = []
	if candidate == null:
		return expired
	for mission: ActiveMissionState in candidate.get_active_missions():
		if not mission.can_expire():
			continue
		if candidate.campaign_tick < mission.expiry_tick:
			continue
		if (
			not mission.expiry_event_id.is_empty()
			and candidate.resolved_strategic_event_ids.has(mission.expiry_event_id)
		):
			continue
		mission.status = ActiveMissionState.STATUS_EXPIRED
		mission.last_resolved_expiry_event_id = mission.expiry_event_id
		if not mission.expiry_event_id.is_empty():
			candidate.resolved_strategic_event_ids[mission.expiry_event_id] = true
		candidate.revision += 1
		expired.append(mission.mission_instance_id)
	return expired


func _availability_duration(campaign: CampaignState, mission: ActiveMissionState) -> int:
	var span: int = DEFAULT_MAXIMUM_AVAILABILITY_MINUTES - DEFAULT_MINIMUM_AVAILABILITY_MINUTES + 1
	var seed_text: String = "%d:%s:%s:expiry" % [
		campaign.campaign_seed,
		mission.mission_instance_id,
		mission.mission_definition_id,
	]
	return DEFAULT_MINIMUM_AVAILABILITY_MINUTES + posmod(hash(seed_text), span)
