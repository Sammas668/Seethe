class_name PendingMovementReactionState
extends RefCounted

var movement_action_id: StringName = &""
var mover_unit_id: StringName = &""
var full_path: Array[Vector2i] = []
var committed_prefix: Array[Vector2i] = []
var trigger_path_index: int = -1
var movement_mode: StringName = &"normal"
var candidate: ReactionCandidate
var request: ReactionDecisionRequest
var continuation_kind: StringName = &""
var continuation_payload: Dictionary = {}
var suppressed_candidate_keys: Dictionary = {}
