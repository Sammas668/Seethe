class_name TacticalStructureState
extends RefCounted

var structure_id: StringName = &""
var definition_id: StringName = &""
var current_hp: int = 1
var integrity_state_id: StringName = TacticalStructureDefinition.STATE_INTACT
var salvage_generated: bool = false


func _init(definition: TacticalStructureDefinition = null) -> void:
	if definition == null:
		return
	structure_id = definition.structure_id
	definition_id = definition.definition_id
	current_hp = definition.maximum_hp
	integrity_state_id = TacticalStructureDefinition.STATE_INTACT


func snapshot() -> Dictionary:
	return {
		"structure_id": structure_id,
		"definition_id": definition_id,
		"current_hp": current_hp,
		"integrity_state_id": integrity_state_id,
		"salvage_generated": salvage_generated,
	}


func restore(snapshot_value: Dictionary) -> void:
	current_hp = int(snapshot_value.get("current_hp", current_hp))
	integrity_state_id = StringName(snapshot_value.get(
		"integrity_state_id", integrity_state_id
	))
	salvage_generated = bool(snapshot_value.get("salvage_generated", salvage_generated))
