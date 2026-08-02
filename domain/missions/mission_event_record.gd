class_name MissionEventRecord
extends RefCounted

var event_id: StringName = &""
var event_kind: StringName = &""
var tactical_revision: int = 0
var round_number: int = 0
var actor_id: StringName = &""
var target_id: StringName = &""
var item_ids: Array[StringName] = []
var position: Vector2i = Vector2i(-1, -1)
var quantity: int = 0
var tags: Array[StringName] = []
var metadata: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"event_id": String(event_id),
		"event_kind": String(event_kind),
		"tactical_revision": tactical_revision,
		"round_number": round_number,
		"actor_id": String(actor_id),
		"target_id": String(target_id),
		"item_ids": _strings(item_ids),
		"position": position,
		"quantity": quantity,
		"tags": _strings(tags),
		"metadata": metadata.duplicate(true),
	}


static func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result
