class_name AgentDiscoveryCandidate
extends RefCounted

var mission_definition_id: StringName = &""
var site_id: StringName = &""
var eligibility_priority: int = 0
var unique_or_repeatable: StringName = &"unique"
var required_tags: Array[StringName] = []
var exclusion_reasons: Array[StringName] = []


func is_eligible() -> bool:
	return (
		not mission_definition_id.is_empty()
		and not site_id.is_empty()
		and exclusion_reasons.is_empty()
	)


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if mission_definition_id.is_empty():
		errors.append("Agent discovery candidate has no mission definition ID.")
	if site_id.is_empty():
		errors.append("Agent discovery candidate has no site ID.")
	return errors
