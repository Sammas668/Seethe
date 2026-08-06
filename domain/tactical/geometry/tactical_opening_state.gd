class_name TacticalOpeningState
extends RefCounted

var opening_id: StringName = &""
var state_id: StringName = TacticalOpeningDefinition.STATE_CLOSED
var locked: bool = false
var barred: bool = false
var jammed: bool = false
var current_hp: int = 1
var salvage_generated: bool = false


func _init(
		definition: TacticalOpeningDefinition = null
) -> void:
	if definition == null:
		return
	opening_id = definition.opening_id
	state_id = definition.initial_state_id
	locked = state_id == TacticalOpeningDefinition.STATE_LOCKED
	barred = state_id == TacticalOpeningDefinition.STATE_BARRED
	jammed = state_id == TacticalOpeningDefinition.STATE_JAMMED
	current_hp = definition.maximum_hp


func is_open() -> bool:
	return state_id in [
		TacticalOpeningDefinition.STATE_OPEN,
		TacticalOpeningDefinition.STATE_BROKEN,
		TacticalOpeningDefinition.STATE_DESTROYED,
	]


func can_operate_normally() -> bool:
	return not locked and not barred and not jammed and state_id not in [
		TacticalOpeningDefinition.STATE_DAMAGED,
		TacticalOpeningDefinition.STATE_BROKEN,
		TacticalOpeningDefinition.STATE_DESTROYED,
	]


func snapshot() -> Dictionary:
	return {
		"opening_id": opening_id,
		"state_id": state_id,
		"locked": locked,
		"barred": barred,
		"jammed": jammed,
		"current_hp": current_hp,
		"salvage_generated": salvage_generated,
	}


func restore(snapshot_value: Dictionary) -> void:
	state_id = StringName(snapshot_value.get("state_id", state_id))
	locked = bool(snapshot_value.get("locked", locked))
	barred = bool(snapshot_value.get("barred", barred))
	jammed = bool(snapshot_value.get("jammed", jammed))
	current_hp = int(snapshot_value.get("current_hp", current_hp))
	salvage_generated = bool(snapshot_value.get("salvage_generated", salvage_generated))
