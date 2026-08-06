class_name SubregionNotorietyService
extends RefCounted


func ensure_region_states(campaign: CampaignState, region: RegionMapDefinition) -> bool:
	if campaign == null or region == null:
		return false
	var changed: bool = false
	if not campaign.subregion_notoriety_by_region.has(region.id):
		campaign.subregion_notoriety_by_region[region.id] = {}
		changed = true
	var region_states: Dictionary = campaign.subregion_notoriety_by_region[region.id] as Dictionary
	for raw_subregion_id: Variant in region.subregions_by_id.keys():
		var subregion_id := StringName(raw_subregion_id)
		if region_states.has(subregion_id):
			continue
		var state := SubregionNotorietyState.new()
		state.region_id = region.id
		state.subregion_id = subregion_id
		region_states[subregion_id] = state
		changed = true
	campaign.subregion_notoriety_by_region[region.id] = region_states
	if changed:
		campaign.revision += 1
	return changed


func state(
	campaign: CampaignState,
	region_id: StringName,
	subregion_id: StringName
) -> SubregionNotorietyState:
	if campaign == null:
		return null
	var region_states: Dictionary = campaign.subregion_notoriety_by_region.get(region_id, {}) as Dictionary
	return region_states.get(subregion_id) as SubregionNotorietyState


func regional_total(campaign: CampaignState, region_id: StringName) -> int:
	if campaign == null:
		return 0
	var total: int = 0
	var region_states: Dictionary = campaign.subregion_notoriety_by_region.get(region_id, {}) as Dictionary
	for raw_state: Variant in region_states.values():
		var local: SubregionNotorietyState = raw_state as SubregionNotorietyState
		if local != null:
			total += local.value
	return total
