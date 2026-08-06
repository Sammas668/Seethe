class_name CaptivePolicyDefinition
extends RefCounted

var policy_id: StringName = &"captive_policy.default"
var cell_cost: int = 1
var containment_profile_id: StringName = &"containment.standard_humanoid"
var containment_tags: Array[StringName] = [&"humanoid", &"ordinary_cell"]
var ransom_allowed: bool = false
var ransom_value: int = 0
var ransom_faction_id: StringName = &""
var release_allowed: bool = true
var release_notoriety_delta: int = 0
var available_action_ids: Array[StringName] = [&"release"]


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if policy_id.is_empty():
		errors.append("Captive policy has no ID.")
	if cell_cost <= 0:
		errors.append("Captive policy %s has invalid cell cost." % policy_id)
	if ransom_value < 0:
		errors.append("Captive policy %s has negative ransom value." % policy_id)
	return errors
