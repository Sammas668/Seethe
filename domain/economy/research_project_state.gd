class_name ResearchProjectState
extends RefCounted

const STATUS_QUEUED: StringName = &"queued"
const STATUS_ACTIVE: StringName = &"active"
const STATUS_PAUSED: StringName = &"paused"
const STATUS_COMPLETE: StringName = &"complete"
const STATUS_APPLIED: StringName = &"applied"
const STATUS_CANCELLED: StringName = &"cancelled"

var project_id: StringName = &""
var research_id: StringName = &""
var priority: int = 0
var requested_worker_count: int = 1
var completed_work: int = 0
var total_work_required: int = 1
var work_accumulator_minutes: int = 0
var created_tick: int = 0
var status: StringName = STATUS_QUEUED
var pause_reason: String = ""
var applied: bool = false
var revision: int = 0


func is_open() -> bool:
	return status in [STATUS_QUEUED, STATUS_ACTIVE, STATUS_PAUSED, STATUS_COMPLETE] and not applied


func remaining_work() -> int:
	return maxi(0, total_work_required - completed_work)


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if project_id.is_empty():
		errors.append("Research project has no ID.")
	if research_id.is_empty():
		errors.append("Research project %s has no Research definition ID." % project_id)
	if priority < 0:
		errors.append("Research project %s has negative priority." % project_id)
	if requested_worker_count < 0:
		errors.append("Research project %s requests a negative worker count." % project_id)
	if total_work_required <= 0:
		errors.append("Research project %s has non-positive total work." % project_id)
	if completed_work < 0 or completed_work > total_work_required:
		errors.append("Research project %s has invalid completed work." % project_id)
	if work_accumulator_minutes < 0 or work_accumulator_minutes >= 1440:
		errors.append("Research project %s has invalid partial-day work." % project_id)
	if status not in [STATUS_QUEUED, STATUS_ACTIVE, STATUS_PAUSED, STATUS_COMPLETE, STATUS_APPLIED, STATUS_CANCELLED]:
		errors.append("Research project %s has invalid status %s." % [project_id, status])
	if applied and status != STATUS_APPLIED:
		errors.append("Research project %s is applied without APPLIED status." % project_id)
	if status == STATUS_APPLIED and not applied:
		errors.append("Research project %s has APPLIED status without its applied guard." % project_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"project_id": String(project_id),
		"research_id": String(research_id),
		"priority": priority,
		"requested_worker_count": requested_worker_count,
		"completed_work": completed_work,
		"total_work_required": total_work_required,
		"work_accumulator_minutes": work_accumulator_minutes,
		"created_tick": created_tick,
		"status": String(status),
		"pause_reason": pause_reason,
		"applied": applied,
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> ResearchProjectState:
	var result := ResearchProjectState.new()
	result.project_id = StringName(data.get("project_id", ""))
	result.research_id = StringName(data.get("research_id", ""))
	result.priority = maxi(0, int(data.get("priority", 0)))
	result.requested_worker_count = maxi(0, int(data.get("requested_worker_count", 1)))
	result.completed_work = maxi(0, int(data.get("completed_work", 0)))
	result.total_work_required = maxi(1, int(data.get("total_work_required", 1)))
	result.work_accumulator_minutes = maxi(0, int(data.get("work_accumulator_minutes", 0)))
	result.created_tick = maxi(0, int(data.get("created_tick", 0)))
	result.status = StringName(data.get("status", STATUS_QUEUED))
	result.pause_reason = String(data.get("pause_reason", ""))
	result.applied = bool(data.get("applied", false))
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result
