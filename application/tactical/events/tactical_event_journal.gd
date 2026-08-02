extends RefCounted

signal event_added(event: Dictionary)
signal journal_cleared

const EVENT_RECORD_SCRIPT: Script = preload(
	"res://domain/tactical/events/tactical_event_record.gd"
)

const FILTER_ALL: StringName = &"all"
const FILTER_ROLLS: StringName = &"rolls"
const FILTER_COMBAT: StringName = &"combat"
const FILTER_EVENTS: StringName = &"events"

var _events: Array[Dictionary] = []
var _next_sequence_number: int = 1


func record_event(
		event_type: StringName,
		round_number: int,
		phase_id: StringName,
		summary: String,
		options: Dictionary = {}
) -> Dictionary:
	var event: Dictionary = EVENT_RECORD_SCRIPT.create(
		event_type,
		round_number,
		phase_id,
		summary,
		options
	)
	return append_event(event)


func append_event(event: Dictionary) -> Dictionary:
	if event.is_empty():
		return {}

	var stored := event.duplicate(true)
	var sequence := _next_sequence_number
	_next_sequence_number += 1

	stored["sequence_number"] = sequence
	stored["event_id"] = StringName("event.%06d" % sequence)
	_events.append(stored)

	var emitted_copy := stored.duplicate(true)
	event_added.emit(emitted_copy)
	return emitted_copy


func event_count(include_hidden: bool = true) -> int:
	if include_hidden:
		return _events.size()

	var count := 0
	for event: Dictionary in _events:
		if _is_player_visible(event):
			count += 1
	return count


func events(
		filter_id: StringName = FILTER_ALL,
		include_hidden: bool = false
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for event: Dictionary in _events:
		if not include_hidden and not _is_player_visible(event):
			continue
		if not _matches_filter(event, filter_id):
			continue
		result.append(event.duplicate(true))

	return result


func recent_events(
		limit: int = 3,
		filter_id: StringName = FILTER_ALL,
		include_hidden: bool = false
) -> Array[Dictionary]:
	if limit <= 0 or _events.is_empty():
		return []

	# Read backwards and stop as soon as the requested visible entries are found.
	# The previous implementation deep-copied the entire mission journal on every
	# collapsed-log update before discarding all but the last three records.
	var reverse_result: Array[Dictionary] = []
	for index: int in range(_events.size() - 1, -1, -1):
		var event: Dictionary = _events[index]
		if not include_hidden and not _is_player_visible(event):
			continue
		if not _matches_filter(event, filter_id):
			continue
		reverse_result.append(event.duplicate(true))
		if reverse_result.size() >= limit:
			break

	var result: Array[Dictionary] = []
	for index: int in range(reverse_result.size() - 1, -1, -1):
		result.append(reverse_result[index])
	return result


func latest_event(
		filter_id: StringName = FILTER_ALL,
		include_hidden: bool = false
) -> Dictionary:
	var matching := recent_events(1, filter_id, include_hidden)
	if matching.is_empty():
		return {}
	return matching[0].duplicate(true)


func clear() -> void:
	_events.clear()
	_next_sequence_number = 1
	journal_cleared.emit()


func _is_player_visible(event: Dictionary) -> bool:
	return StringName(event.get("visibility", &"player")) == &"player"


func _matches_filter(
		event: Dictionary,
		filter_id: StringName
) -> bool:
	if filter_id == FILTER_ALL:
		return true

	var category := StringName(event.get("category", &"events"))
	if filter_id == FILTER_ROLLS:
		var rolls: Array = event.get("roll_records", [])
		return category == FILTER_ROLLS or not rolls.is_empty()
	if filter_id == FILTER_COMBAT:
		return category == FILTER_COMBAT
	if filter_id == FILTER_EVENTS:
		return category == FILTER_EVENTS

	return category == filter_id
