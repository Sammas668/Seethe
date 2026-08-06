class_name RegionalRetaliationService
extends RefCounted

const DEFAULT_RAID_THRESHOLD: int = 150
const RAID_PREPARATION_MINUTES: int = 72 * 60

var _notoriety_service := SubregionNotorietyService.new()


func threshold_for_region(_region_id: StringName) -> int:
	return DEFAULT_RAID_THRESHOLD


func active_raid(campaign: CampaignState, region_id: StringName) -> RaidOperationState:
	if campaign == null:
		return null
	for raw_raid: Variant in campaign.raid_operations_by_id.values():
		var raid: RaidOperationState = raw_raid as RaidOperationState
		if raid != null and raid.origin_region_id == region_id and raid.is_active():
			return raid
	return null


func create_if_threshold_crossed(
	campaign: CampaignState,
	region: RegionMapDefinition,
	old_total: int,
	new_total: int
) -> RaidOperationState:
	if campaign == null or region == null:
		return null
	var threshold: int = threshold_for_region(region.id)
	if old_total >= threshold or new_total < threshold:
		return null
	if active_raid(campaign, region.id) != null:
		return null
	var origin_subregion: StringName = _highest_subregion(campaign, region)
	if origin_subregion.is_empty():
		return null
	var raid := RaidOperationState.new()
	raid.operation_id = StringName("raid.%s.%04d" % [campaign.campaign_id, campaign.next_raid_sequence])
	campaign.next_raid_sequence += 1
	raid.origin_region_id = region.id
	raid.origin_subregion_id = origin_subregion
	raid.origin_settlement_id = _origin_site(region, origin_subregion)
	var approach_suffix: String = String(origin_subregion).replace("subregion.", "")
	raid.approach_id = StringName("approach.%s" % approach_suffix)
	raid.created_tick = campaign.campaign_tick
	raid.departure_tick = campaign.campaign_tick
	raid.arrival_tick = campaign.campaign_tick + RAID_PREPARATION_MINUTES
	raid.status = RaidOperationState.STATUS_PREPARING
	campaign.raid_operations_by_id[raid.operation_id] = raid
	campaign.revision += 1
	return raid


func _highest_subregion(campaign: CampaignState, region: RegionMapDefinition) -> StringName:
	var best: StringName = &""
	var best_value: int = -1
	var region_states: Dictionary = campaign.subregion_notoriety_by_region.get(region.id, {}) as Dictionary
	var ids: Array = region_states.keys()
	ids.sort()
	for raw_id: Variant in ids:
		var subregion_id := StringName(raw_id)
		var local: SubregionNotorietyState = region_states.get(subregion_id) as SubregionNotorietyState
		if local != null and local.value > best_value:
			best_value = local.value
			best = subregion_id
	return best


func _origin_site(region: RegionMapDefinition, subregion_id: StringName) -> StringName:
	var military: RegionSiteDefinition = region.site(region.military_site_id)
	if military != null and military.subregion_id == subregion_id:
		return military.id
	var candidates: Array[RegionSiteDefinition] = []
	for site: RegionSiteDefinition in region.all_sites():
		if site.site_type == &"settlement" and site.subregion_id == subregion_id:
			candidates.append(site)
	candidates.sort_custom(
		func(a: RegionSiteDefinition, b: RegionSiteDefinition) -> bool:
			if a.label_priority != b.label_priority:
				return a.label_priority > b.label_priority
			return String(a.id) < String(b.id)
	)
	return candidates[0].id if not candidates.is_empty() else region.main_settlement_site_id
