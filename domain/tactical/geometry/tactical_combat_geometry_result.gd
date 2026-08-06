class_name TacticalCombatGeometryResult
extends RefCounted

const COVER_NONE: StringName = &"none"
const COVER_LIGHT: StringName = &"light"
const COVER_HEAVY: StringName = &"heavy"
const COVER_TOTAL: StringName = &"total"

var has_line_of_sight: bool = false
var has_line_of_effect: bool = false
var clear_exposure_samples: int = 0
var total_exposure_samples: int = 5
var cover_category: StringName = COVER_TOTAL
var cover_ac_bonus: int = 0
var cover_reflex_bonus: int = 0
var primary_cover_source_id: StringName = &""
var primary_cover_source_kind: StringName = &""
var blocking_sight_source_id: StringName = &""
var blocking_effect_source_id: StringName = &""
var attack_origin: Vector2 = Vector2.ZERO
var target_sample_points: Array[Vector2] = []
var geometry_revision: int = 0


func configure_cover_from_samples() -> void:
	if clear_exposure_samples >= total_exposure_samples:
		cover_category = COVER_NONE
		cover_ac_bonus = 0
		cover_reflex_bonus = 0
	elif clear_exposure_samples >= 3:
		cover_category = COVER_LIGHT
		cover_ac_bonus = 2
		cover_reflex_bonus = 1
	elif clear_exposure_samples >= 1:
		cover_category = COVER_HEAVY
		cover_ac_bonus = 4
		cover_reflex_bonus = 2
	else:
		cover_category = COVER_TOTAL
		cover_ac_bonus = 0
		cover_reflex_bonus = 0


func cover_label() -> String:
	match cover_category:
		COVER_LIGHT:
			return "Light Cover"
		COVER_HEAVY:
			return "Heavy Cover"
		COVER_TOTAL:
			return "Total Cover"
		_:
			return "Exposed"
