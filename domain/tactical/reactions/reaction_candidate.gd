class_name ReactionCandidate
extends RefCounted

const KIND_ATTACK_OF_OPPORTUNITY: StringName = &"attack_of_opportunity"
const KIND_OVERWATCH: StringName = &"overwatch"
const KIND_BRACE: StringName = &"brace"

const TIMING_BEFORE_ENTRY: StringName = &"before_entry"
const TIMING_AFTER_ENTRY: StringName = &"after_entry"

var reaction_kind: StringName = &""
var source_unit_id: StringName = &""
var target_unit_id: StringName = &""
var attack_action_id: StringName = &""
var triggering_event_id: StringName = &""
var triggering_action_name: String = "Movement"
var movement_action_id: StringName = &""
var trigger_origin: Vector2i = Vector2i(-1, -1)
var trigger_destination: Vector2i = Vector2i(-1, -1)
var target_position: Vector2i = Vector2i(-1, -1)
var path_index: int = -1
var timing_kind: StringName = TIMING_BEFORE_ENTRY
var predicted_hit_chance: int = 0
var predicted_damage_text: String = ""
var attack_modifier: int = 0
var legal: bool = false
var invalidity_reason: String = ""
var priority_key: Array = []
var player_decision_required: bool = false


func icon_kind() -> StringName:
	return reaction_kind
