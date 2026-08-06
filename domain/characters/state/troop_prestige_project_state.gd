class_name TroopPrestigeProjectState
extends RefCounted

const STATUS_QUEUED: StringName = &"queued"
const STATUS_ACTIVE: StringName = &"active"
const STATUS_PAUSED: StringName = &"paused"
const STATUS_COMPLETE: StringName = &"complete"
const STATUS_APPLIED: StringName = &"applied"
const STATUS_CANCELLED: StringName = &"cancelled"

var project_id: StringName = &""
var character_id: StringName = &""
var career_id: StringName = &""
var source_stage_id: StringName = &""
var target_stage_id: StringName = &""
var host_facility_id: StringName = &""
var started_tick: int = 0
var completion_tick: int = 0
var paused_at_tick: int = 0
var status: StringName = STATUS_ACTIVE
var applied: bool = false
var revision: int = 0


func remaining_ticks(campaign_tick: int) -> int:
	var reference_tick: int = paused_at_tick if status == STATUS_PAUSED and paused_at_tick > 0 else campaign_tick
	return maxi(0, completion_tick - reference_tick)


func to_dictionary() -> Dictionary:
	return {
		"project_id": String(project_id),
		"character_id": String(character_id),
		"career_id": String(career_id),
		"source_stage_id": String(source_stage_id),
		"target_stage_id": String(target_stage_id),
		"host_facility_id": String(host_facility_id),
		"started_tick": started_tick,
		"completion_tick": completion_tick,
		"paused_at_tick": paused_at_tick,
		"status": String(status),
		"applied": applied,
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> TroopPrestigeProjectState:
	var result := TroopPrestigeProjectState.new()
	result.project_id = StringName(data.get("project_id", ""))
	result.character_id = StringName(data.get("character_id", ""))
	result.career_id = StringName(data.get("career_id", ""))
	result.source_stage_id = StringName(data.get("source_stage_id", ""))
	result.target_stage_id = StringName(data.get("target_stage_id", ""))
	result.host_facility_id = StringName(data.get("host_facility_id", ""))
	result.started_tick = maxi(0, int(data.get("started_tick", 0)))
	result.completion_tick = maxi(result.started_tick + 1, int(data.get("completion_tick", result.started_tick + 1)))
	result.paused_at_tick = maxi(0, int(data.get("paused_at_tick", 0)))
	result.status = StringName(data.get("status", STATUS_ACTIVE))
	result.applied = bool(data.get("applied", false))
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result
