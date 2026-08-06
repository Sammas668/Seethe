class_name StrongholdPlotState
extends RefCounted

const StrongholdDefinitionScript = preload("res://domain/stronghold/stronghold_definition.gd")
const StrongholdPlotDefinitionScript = preload("res://domain/stronghold/stronghold_plot_definition.gd")


const DAMAGE_INTACT: StringName = &"intact"
const DAMAGE_RUINED: StringName = &"ruined"
const DAMAGE_DAMAGED: StringName = &"damaged"

var coord: Vector2i = Vector2i.ZERO
var current_state: StringName = StrongholdPlotDefinitionScript.AVAILABLE
var facility_id: StringName = &""
var project_id: StringName = &""
var damage_state: StringName = DAMAGE_INTACT
var revision: int = 0


func key() -> StringName:
	return StrongholdDefinitionScript.coord_key(coord)


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if current_state not in StrongholdPlotDefinitionScript.ALL_STATES:
		errors.append("Stronghold plot state %s has invalid state %s." % [key(), current_state])
	if current_state in [StrongholdPlotDefinitionScript.FIXED_HEART, StrongholdPlotDefinitionScript.FIXED_ENTRANCE] and facility_id.is_empty():
		errors.append("Fixed stronghold plot %s has no facility identity." % key())
	if current_state == StrongholdPlotDefinitionScript.OCCUPIED and facility_id.is_empty():
		errors.append("Occupied stronghold plot %s has no facility identity." % key())
	if current_state != StrongholdPlotDefinitionScript.OCCUPIED and not project_id.is_empty():
		errors.append("Stronghold plot %s references a project before construction is supported." % key())
	return errors


func to_dictionary() -> Dictionary:
	return {
		"coord": [coord.x, coord.y],
		"current_state": String(current_state),
		"facility_id": String(facility_id),
		"project_id": String(project_id),
		"damage_state": String(damage_state),
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> StrongholdPlotState:
	var result := StrongholdPlotState.new()
	var raw_coord: Variant = data.get("coord", [0, 0])
	if raw_coord is Array and (raw_coord as Array).size() >= 2:
		result.coord = Vector2i(int((raw_coord as Array)[0]), int((raw_coord as Array)[1]))
	result.current_state = StringName(data.get("current_state", StrongholdPlotDefinitionScript.AVAILABLE))
	result.facility_id = StringName(data.get("facility_id", ""))
	result.project_id = StringName(data.get("project_id", ""))
	result.damage_state = StringName(data.get("damage_state", DAMAGE_INTACT))
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result
