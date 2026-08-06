class_name HenchmanRecruitmentProjectState
extends RefCounted

const STATUS_ACTIVE: StringName = &"active"
const STATUS_COMPLETE: StringName = &"complete"
const STATUS_APPLIED: StringName = &"applied"
const STATUS_CANCELLED: StringName = &"cancelled"

var project_id: StringName = &""
var offer_id: StringName = &""
var recruitment_definition_id: StringName = &""
var base_class_id: StringName = &""
var career_id: StringName = &""
var candidate_name: String = "Unnamed Recruit"
var portrait_id: StringName = &""
var started_tick: int = 0
var completion_tick: int = 0
var generated_identity_seed: int = 0
var result_character_id: StringName = &""
var status: StringName = STATUS_ACTIVE
var applied: bool = false
var revision: int = 0


func remaining_ticks(campaign_tick: int) -> int:
	return maxi(0, completion_tick - campaign_tick)


func to_dictionary() -> Dictionary:
	return {
		"project_id": String(project_id),
		"offer_id": String(offer_id),
		"recruitment_definition_id": String(recruitment_definition_id),
		"base_class_id": String(base_class_id),
		"career_id": String(career_id),
		"candidate_name": candidate_name,
		"portrait_id": String(portrait_id),
		"started_tick": started_tick,
		"completion_tick": completion_tick,
		"generated_identity_seed": generated_identity_seed,
		"result_character_id": String(result_character_id),
		"status": String(status),
		"applied": applied,
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> HenchmanRecruitmentProjectState:
	var result := HenchmanRecruitmentProjectState.new()
	result.project_id = StringName(data.get("project_id", ""))
	result.offer_id = StringName(data.get("offer_id", ""))
	result.recruitment_definition_id = StringName(data.get("recruitment_definition_id", ""))
	result.base_class_id = StringName(data.get("base_class_id", ""))
	result.career_id = StringName(data.get("career_id", ""))
	result.candidate_name = String(data.get("candidate_name", "Unnamed Recruit"))
	result.portrait_id = StringName(data.get("portrait_id", ""))
	result.started_tick = maxi(0, int(data.get("started_tick", 0)))
	result.completion_tick = maxi(result.started_tick + 1, int(data.get("completion_tick", result.started_tick + 1)))
	result.generated_identity_seed = int(data.get("generated_identity_seed", 0))
	result.result_character_id = StringName(data.get("result_character_id", ""))
	result.status = StringName(data.get("status", STATUS_ACTIVE))
	result.applied = bool(data.get("applied", false))
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result
