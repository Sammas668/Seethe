class_name ProductionProjectState
extends RefCounted

const STATUS_QUEUED: StringName = &"queued"
const STATUS_ACTIVE: StringName = &"active"
const STATUS_PAUSED: StringName = &"paused"
const STATUS_COMPLETE: StringName = &"complete"
const STATUS_APPLIED: StringName = &"applied"
const STATUS_CANCELLED: StringName = &"cancelled"

var project_id: StringName = &""
var recipe_id: StringName = &""
var project_type: StringName = &"manufacture_item"
var target_item_id: StringName = &""
var quantity: int = 1
var priority: int = 0
var requested_worker_count: int = 1
var assigned_worker_count: int = 0
var completed_work: int = 0
var total_work_required: int = 1
# Rating-minutes carried between strategic clock updates. 1 Work = 1440
# rating-minutes, allowing minute-by-minute strategic time without lost progress.
var work_accumulator_minutes: int = 0
var host_facility_id: StringName = &""
var reservation_id: StringName = &""
var output_storage_space: int = 0
var created_tick: int = 0
var last_progress_tick: int = 0
var status: StringName = STATUS_QUEUED
var pause_reason: String = ""
var applied: bool = false
var revision: int = 0


func remaining_work() -> int:
	return maxi(0, total_work_required - completed_work)


func is_open() -> bool:
	return status in [STATUS_QUEUED, STATUS_ACTIVE, STATUS_PAUSED]


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if project_id.is_empty():
		errors.append("Production project has no ID.")
	if recipe_id.is_empty():
		errors.append("Production project %s has no recipe." % project_id)
	if quantity <= 0:
		errors.append("Production project %s has invalid quantity." % project_id)
	if requested_worker_count < 0 or assigned_worker_count < 0:
		errors.append("Production project %s has a negative worker count." % project_id)
	if total_work_required <= 0 or completed_work < 0 or completed_work > total_work_required:
		errors.append("Production project %s has invalid work progress." % project_id)
	if work_accumulator_minutes < 0:
		errors.append("Production project %s has negative partial progress." % project_id)
	if status not in [STATUS_QUEUED, STATUS_ACTIVE, STATUS_PAUSED, STATUS_COMPLETE, STATUS_APPLIED, STATUS_CANCELLED]:
		errors.append("Production project %s has invalid status %s." % [project_id, status])
	if applied and status != STATUS_APPLIED:
		errors.append("Applied production project %s is not in APPLIED state." % project_id)
	if project_type == &"repair_item" and target_item_id.is_empty():
		errors.append("Repair project %s has no target item." % project_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"project_id": String(project_id),
		"recipe_id": String(recipe_id),
		"project_type": String(project_type),
		"target_item_id": String(target_item_id),
		"quantity": quantity,
		"priority": priority,
		"requested_worker_count": requested_worker_count,
		"assigned_worker_count": assigned_worker_count,
		"completed_work": completed_work,
		"total_work_required": total_work_required,
		"work_accumulator_minutes": work_accumulator_minutes,
		"host_facility_id": String(host_facility_id),
		"reservation_id": String(reservation_id),
		"output_storage_space": output_storage_space,
		"created_tick": created_tick,
		"last_progress_tick": last_progress_tick,
		"status": String(status),
		"pause_reason": pause_reason,
		"applied": applied,
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> ProductionProjectState:
	var result := ProductionProjectState.new()
	result.project_id = StringName(data.get("project_id", ""))
	result.recipe_id = StringName(data.get("recipe_id", ""))
	result.project_type = StringName(data.get("project_type", "manufacture_item"))
	result.target_item_id = StringName(data.get("target_item_id", ""))
	result.quantity = maxi(1, int(data.get("quantity", 1)))
	result.priority = maxi(0, int(data.get("priority", 0)))
	result.requested_worker_count = maxi(0, int(data.get("requested_worker_count", 1)))
	result.assigned_worker_count = maxi(0, int(data.get("assigned_worker_count", 0)))
	result.total_work_required = maxi(1, int(data.get("total_work_required", 1)))
	result.completed_work = clampi(int(data.get("completed_work", 0)), 0, result.total_work_required)
	result.work_accumulator_minutes = maxi(0, int(data.get("work_accumulator_minutes", 0)))
	result.host_facility_id = StringName(data.get("host_facility_id", ""))
	result.reservation_id = StringName(data.get("reservation_id", ""))
	result.output_storage_space = maxi(0, int(data.get("output_storage_space", 0)))
	result.created_tick = maxi(0, int(data.get("created_tick", 0)))
	result.last_progress_tick = maxi(result.created_tick, int(data.get("last_progress_tick", result.created_tick)))
	result.status = StringName(data.get("status", STATUS_QUEUED))
	result.pause_reason = String(data.get("pause_reason", ""))
	result.applied = bool(data.get("applied", false))
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result
