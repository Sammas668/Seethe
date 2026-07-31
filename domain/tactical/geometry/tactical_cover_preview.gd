class_name TacticalCoverPreview
extends RefCounted

var mover_unit_id: StringName = &""
var destination: Vector2i = Vector2i(-1, -1)
var results_by_enemy_id: Dictionary = {}
var exposed_count: int = 0
var light_count: int = 0
var heavy_count: int = 0
var total_count: int = 0


func add_result(enemy_id: StringName, geometry: TacticalCombatGeometryResult) -> void:
	if geometry == null:
		return
	results_by_enemy_id[enemy_id] = geometry
	match geometry.cover_category:
		TacticalCombatGeometryResult.COVER_LIGHT:
			light_count += 1
		TacticalCombatGeometryResult.COVER_HEAVY:
			heavy_count += 1
		TacticalCombatGeometryResult.COVER_TOTAL:
			total_count += 1
		_:
			exposed_count += 1


func worst_category() -> StringName:
	if exposed_count > 0:
		return TacticalCombatGeometryResult.COVER_NONE
	if light_count > 0:
		return TacticalCombatGeometryResult.COVER_LIGHT
	if heavy_count > 0:
		return TacticalCombatGeometryResult.COVER_HEAVY
	if total_count > 0:
		return TacticalCombatGeometryResult.COVER_TOTAL
	return TacticalCombatGeometryResult.COVER_NONE


func worst_label() -> String:
	if results_by_enemy_id.is_empty():
		return "NO VISIBLE THREATS"
	match worst_category():
		TacticalCombatGeometryResult.COVER_LIGHT:
			return "LIGHT COVER"
		TacticalCombatGeometryResult.COVER_HEAVY:
			return "HEAVY COVER"
		TacticalCombatGeometryResult.COVER_TOTAL:
			return "TOTAL COVER"
		_:
			return "EXPOSED"


func compact_breakdown() -> String:
	var parts: Array[String] = []
	if exposed_count > 0:
		parts.append("%d exposed" % exposed_count)
	if light_count > 0:
		parts.append("%d light" % light_count)
	if heavy_count > 0:
		parts.append("%d heavy" % heavy_count)
	if total_count > 0:
		parts.append("%d total" % total_count)
	return " · ".join(PackedStringArray(parts))


func summary_text() -> String:
	var detail: String = compact_breakdown()
	return worst_label() if detail.is_empty() else "%s · %s" % [worst_label(), detail]
