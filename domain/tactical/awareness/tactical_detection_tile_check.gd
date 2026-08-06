class_name TacticalDetectionTileCheck
extends RefCounted

var tile: Vector2i = Vector2i(-1, -1)
var path_index: int = -1
var automatic_detection: bool = false
var roll_required: bool = false
var roll_value: int = 0
var stealth_bonus: int = 0
var roll_total: int = 0
var observer_dc_by_id: Dictionary = {}
var observer_squad_by_id: Dictionary = {}
var detected_observer_ids: Array[StringName] = []
var detected_squad_ids: Array[StringName] = []


func detected() -> bool:
	return not detected_squad_ids.is_empty()


func required_natural_roll(detection_dc: int) -> int:
	return detection_dc - stealth_bonus


func required_roll_label(detection_dc: int) -> String:
	var required: int = required_natural_roll(detection_dc)
	if required <= 1:
		return "1+"
	if required > 20:
		return "Impossible on d20"
	return "%d+" % required
