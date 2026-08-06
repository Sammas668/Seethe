class_name TacticalCharacterDeploymentPlan
extends RefCounted

var expected_state_revision: int = 0
var character_id: StringName = &""
var unit: TacticalUnitState
var items: Array[TacticalItemInstanceState] = []


func validate_plan() -> Array[String]:
	var errors: Array[String] = []
	if character_id.is_empty():
		errors.append("Deployment plan has no character ID.")
	if unit == null:
		errors.append("Deployment plan has no tactical unit.")
	elif unit.unit_id != character_id:
		errors.append("Deployment plan unit ID does not match its character ID.")
	var item_ids: Dictionary = {}
	for item: TacticalItemInstanceState in items:
		if item == null or item.item_id.is_empty():
			errors.append("Deployment plan contains an invalid item.")
			continue
		if item_ids.has(item.item_id):
			errors.append("Deployment plan duplicates item ID %s." % item.item_id)
		item_ids[item.item_id] = true
	return errors
