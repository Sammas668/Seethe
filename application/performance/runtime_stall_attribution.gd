class_name RuntimeStallAttribution
extends RefCounted

const SAMPLE_LIMIT: int = 120
const STALL_THRESHOLD_MS: float = 8.0

static var _latest_ms: Dictionary = {}
static var _peak_ms: Dictionary = {}
static var _totals_ms: Dictionary = {}
static var _counts: Dictionary = {}
static var _recent_stalls: Array[Dictionary] = []


static func begin() -> int:
	return Time.get_ticks_usec()


static func end(stage: StringName, started_usec: int, metadata: String = "") -> float:
	var elapsed_ms: float = maxf(0.0, float(Time.get_ticks_usec() - started_usec) / 1000.0)
	record(stage, elapsed_ms, metadata)
	return elapsed_ms


static func record(stage: StringName, elapsed_ms: float, metadata: String = "") -> void:
	if stage.is_empty():
		return
	_latest_ms[stage] = elapsed_ms
	_peak_ms[stage] = maxf(float(_peak_ms.get(stage, 0.0)), elapsed_ms)
	_totals_ms[stage] = float(_totals_ms.get(stage, 0.0)) + elapsed_ms
	_counts[stage] = int(_counts.get(stage, 0)) + 1
	if elapsed_ms < STALL_THRESHOLD_MS:
		return
	_recent_stalls.append({
		"stage": stage,
		"elapsed_ms": elapsed_ms,
		"metadata": metadata,
		"recorded_msec": Time.get_ticks_msec(),
	})
	while _recent_stalls.size() > SAMPLE_LIMIT:
		_recent_stalls.pop_front()


static func latest_ms(stage: StringName) -> float:
	return float(_latest_ms.get(stage, 0.0))


static func peak_ms(stage: StringName) -> float:
	return float(_peak_ms.get(stage, 0.0))


static func average_ms(stage: StringName) -> float:
	var count: int = int(_counts.get(stage, 0))
	if count <= 0:
		return 0.0
	return float(_totals_ms.get(stage, 0.0)) / float(count)


static func latest_stall() -> Dictionary:
	return _recent_stalls[-1].duplicate(true) if not _recent_stalls.is_empty() else {}


static func diagnostic_lines() -> Array[String]:
	var result: Array[String] = []
	for stage: StringName in [
		&"region_dynamic_draw",
		&"region_static_rebuild",
		&"region_hex_hit_test",
		&"agent_route_preview",
		&"campaign_clock_update",
		&"campaign_persistence",
	]:
		result.append(
			"%s: %.2f ms (peak %.2f)"
			% [String(stage).replace("_", " ").capitalize(), latest_ms(stage), peak_ms(stage)]
		)
	var stall: Dictionary = latest_stall()
	if not stall.is_empty():
		var metadata: String = String(stall.get("metadata", ""))
		result.append(
			"Last stall: %s %.2f ms%s"
			% [
				String(stall.get("stage", "unknown")),
				float(stall.get("elapsed_ms", 0.0)),
				" — %s" % metadata if not metadata.is_empty() else "",
			]
		)
	return result


static func clear() -> void:
	_latest_ms.clear()
	_peak_ms.clear()
	_totals_ms.clear()
	_counts.clear()
	_recent_stalls.clear()
