class_name ReactionDecisionResolution
extends RefCounted

var request_id: StringName = &""
var choice: StringName = &""
var resolved_by_controller_id: StringName = &""
var candidate_selected: bool = false
var reaction_state_changed: bool = false
var attack_result: OperationResult
var continuation_result: OperationResult
