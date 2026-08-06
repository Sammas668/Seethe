class_name EnemyTurnInstrumentation
extends RefCounted


const SLOW_ACTIVATION_HISTORY_LIMIT: int = 12

var active_breakdown: Dictionary = {}
var _activation_timing_samples: int = 0
var _activation_total_usec: int = 0
var _activation_max_usec: int = 0
var _last_activation_timing: Dictionary = {}
var _slow_activation_history: Array[Dictionary] = []
var _activation_sample_serial: int = 0


func begin_activation(initial_breakdown: Dictionary) -> void:
	active_breakdown = initial_breakdown.duplicate(true)


func snapshot() -> Dictionary:
	return {
		"samples": _activation_timing_samples,
		"total_usec": _activation_total_usec,
		"average_usec": (
			_activation_total_usec / _activation_timing_samples
			if _activation_timing_samples > 0
			else 0
		),
		"maximum_usec": _activation_max_usec,
		"last": _last_activation_timing.duplicate(true),
		"slowest": _slow_activation_history.duplicate(true),
	}


func record_presentation_timing(presentation_usec: int) -> void:
	if _last_activation_timing.is_empty():
		return
	var safe_presentation_usec: int = maxi(0, presentation_usec)
	var accumulated_presentation_usec: int = (
		int(_last_activation_timing.get("presentation_usec", 0))
		+ safe_presentation_usec
	)
	var simulation_usec: int = int(
		_last_activation_timing.get(
			"simulation_usec",
			_last_activation_timing.get("total_usec", 0)
		)
	)
	_last_activation_timing["presentation_usec"] = accumulated_presentation_usec
	_last_activation_timing["total"] = simulation_usec + accumulated_presentation_usec
	_last_activation_timing["total_with_presentation_usec"] = (
		simulation_usec + accumulated_presentation_usec
	)
	var sample_serial: int = int(_last_activation_timing.get("sample_serial", -1))
	for index: int in range(_slow_activation_history.size()):
		if int(_slow_activation_history[index].get("sample_serial", -2)) != sample_serial:
			continue
		_slow_activation_history[index] = _last_activation_timing.duplicate(true)
		break
	_sort_slow_activation_history()


func record_activation_elapsed(
		unit_id: StringName,
		elapsed_usec: int,
		result: OperationResult,
		mode: StringName,
		planning_yield_count: int,
		planning_max_slices_per_frame: int,
		hidden_planning_frames: int,
		destination_visibility_yield_count: int
) -> void:
	var safe_elapsed_usec: int = maxi(0, elapsed_usec)
	_activation_timing_samples += 1
	_activation_total_usec += safe_elapsed_usec
	_activation_max_usec = maxi(_activation_max_usec, safe_elapsed_usec)
	active_breakdown["total"] = safe_elapsed_usec
	active_breakdown["total_usec"] = safe_elapsed_usec
	active_breakdown["simulation_usec"] = safe_elapsed_usec
	active_breakdown["unit_id"] = unit_id
	active_breakdown["mode"] = mode
	active_breakdown["result_code"] = (
		result.code if result != null else &"missing_result"
	)
	active_breakdown["success"] = result.success if result != null else false
	active_breakdown["planning_yield_count"] = planning_yield_count
	active_breakdown["planning_max_slices_per_frame"] = planning_max_slices_per_frame
	active_breakdown["hidden_planning_frames"] = hidden_planning_frames
	active_breakdown["destination_visibility_yield_count"] = (
		destination_visibility_yield_count
	)
	_activation_sample_serial += 1
	active_breakdown["sample_serial"] = _activation_sample_serial
	_last_activation_timing = active_breakdown.duplicate(true)
	_slow_activation_history.append(_last_activation_timing.duplicate(true))
	_sort_slow_activation_history()


func _sort_slow_activation_history() -> void:
	_slow_activation_history.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var total_a: int = int(a.get("total", 0))
			var total_b: int = int(b.get("total", 0))
			if total_a != total_b:
				return total_a > total_b
			return String(a.get("unit_id", &"")) < String(b.get("unit_id", &""))
	)
	while _slow_activation_history.size() > SLOW_ACTIVATION_HISTORY_LIMIT:
		_slow_activation_history.pop_back()
