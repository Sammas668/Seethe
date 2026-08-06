class_name MovementDetectionTilePreview
extends RefCounted

var tile: Vector2i = Vector2i(-1, -1)
var path_index: int = -1
var requires_roll: bool = false
var automatic_detection: bool = false
var avoid_detection_chance_percent: int = 100
var effective_detection_dc: int = 0
var primary_observer_id: StringName = &""
var relevant_observer_ids: Array[StringName] = []
var has_unknown_observers: bool = false


func has_detection_risk() -> bool:
	return automatic_detection or requires_roll


func display_percent() -> String:
	if has_unknown_observers:
		return "?"
	return "%d%%" % avoid_detection_chance_percent
