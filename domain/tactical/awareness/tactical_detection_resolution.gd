class_name TacticalDetectionResolution
extends RefCounted

var unit_id: StringName = &""
var tile_checks: Array[TacticalDetectionTileCheck] = []
var movement_stop_index: int = -1
var automatic_detection: bool = false
var roll_required: bool = false
var roll_value: int = 0
var stealth_bonus: int = 0
var roll_total: int = 0
var first_exposure_tile: Vector2i = Vector2i(-1, -1)
var observer_dc_by_id: Dictionary = {}
var observer_squad_by_id: Dictionary = {}
var detected_observer_ids: Array[StringName] = []
var detected_squad_ids: Array[StringName] = []
var newly_aware_squad_ids: Array[StringName] = []
var revealed_at_destination_squad_ids: Array[StringName] = []
var lost_sight_squad_ids: Array[StringName] = []
var last_seen_tile_by_squad_id: Dictionary = {}
var initiative_totals_by_unit_id: Dictionary = {}
var hostile_action: bool = false
var stealth_broken: bool = false
# Detection of a player by an enemy squad begins combat. Detection of a hidden
# enemy by the player team reveals that enemy without making the player team an
# "alert" source or rerolling initiative.
var alert_on_detection: bool = false
# The latest successful Stealth result becomes the stationary result used by
# passive facing checks until the hidden unit moves or enters Stealth again.
var persistent_stealth_roll_valid: bool = false
var persistent_stealth_roll_value: int = 0
var persistent_stealth_total: int = 0


func detected() -> bool:
	return not detected_squad_ids.is_empty()


func has_check() -> bool:
	return not tile_checks.is_empty() or automatic_detection or roll_required


func movement_interrupted() -> bool:
	return movement_stop_index > 0


func committed_path(planned_path: Array[Vector2i]) -> Array[Vector2i]:
	if not movement_interrupted() or movement_stop_index >= planned_path.size() - 1:
		return planned_path.duplicate()
	var result: Array[Vector2i] = []
	for index: int in range(0, movement_stop_index + 1):
		result.append(planned_path[index])
	return result


func has_state_changes() -> bool:
	return (
		detected()
		or not revealed_at_destination_squad_ids.is_empty()
		or not lost_sight_squad_ids.is_empty()
		or not last_seen_tile_by_squad_id.is_empty()
	)
