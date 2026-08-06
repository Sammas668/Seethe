class_name CharacterPermanentGrantState
extends RefCounted

var grant_id: StringName = &""
var grant_type: StringName = &""
var source_type: StringName = &""
var source_id: StringName = &""
var acquired_level: int = 1
var acquired_tick: int = 0


func to_dictionary() -> Dictionary:
	return {
		"grant_id": String(grant_id),
		"grant_type": String(grant_type),
		"source_type": String(source_type),
		"source_id": String(source_id),
		"acquired_level": acquired_level,
		"acquired_tick": acquired_tick,
	}


static func from_dictionary(data: Dictionary) -> CharacterPermanentGrantState:
	var result := CharacterPermanentGrantState.new()
	result.grant_id = StringName(data.get("grant_id", ""))
	result.grant_type = StringName(data.get("grant_type", ""))
	result.source_type = StringName(data.get("source_type", ""))
	result.source_id = StringName(data.get("source_id", ""))
	result.acquired_level = maxi(1, int(data.get("acquired_level", 1)))
	result.acquired_tick = maxi(0, int(data.get("acquired_tick", 0)))
	return result
