class_name TacticalSquadState
extends RefCounted

const PLAYER_TEAM_SQUAD_ID: StringName = &"squad.player.team"

const AWARENESS_UNAWARE: StringName = &"unaware"
const AWARENESS_AWARE: StringName = &"aware"
const DEFAULT_SEARCH_ROUNDS: int = 2

var squad_id: StringName = &""
var team_id: StringName = &"enemy"
var member_unit_ids: Array[StringName] = []
var awareness: StringName = AWARENESS_UNAWARE
# Exact unit locations are known only while a squad can currently perceive the
# unit. This memory stores the final tile at which each hostile was seen so AI
# can search that point without reading a hidden unit's real position.
var last_seen_positions_by_unit_id: Dictionary = {}
# Searching is a bounded behaviour layered on top of binary awareness. It is
# not a third awareness state. A squad remains Aware after the search expires.
var search_rounds_remaining: int = 0


func _init(
		squad_id_value: StringName = &"",
		team_id_value: StringName = &"enemy",
		member_ids_value: Array[StringName] = []
) -> void:
	squad_id = squad_id_value
	team_id = team_id_value
	member_unit_ids = member_ids_value.duplicate()


func is_aware() -> bool:
	return awareness == AWARENESS_AWARE


func make_aware() -> void:
	awareness = AWARENESS_AWARE


func begin_search(rounds: int = DEFAULT_SEARCH_ROUNDS) -> void:
	if not is_aware():
		return
	search_rounds_remaining = maxi(search_rounds_remaining, maxi(1, rounds))


func cancel_search() -> void:
	search_rounds_remaining = 0


func is_searching() -> bool:
	return is_aware() and search_rounds_remaining > 0


func consume_search_round() -> void:
	if search_rounds_remaining > 0:
		search_rounds_remaining -= 1


func reset_to_unaware() -> void:
	awareness = AWARENESS_UNAWARE
	search_rounds_remaining = 0
	last_seen_positions_by_unit_id.clear()


func add_member(unit_id: StringName) -> void:
	if unit_id.is_empty() or member_unit_ids.has(unit_id):
		return
	member_unit_ids.append(unit_id)
	member_unit_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return str(a) < str(b)
	)


func remember_last_seen(unit_id: StringName, tile: Vector2i) -> void:
	if unit_id.is_empty():
		return
	last_seen_positions_by_unit_id[unit_id] = tile


func forget_last_seen(unit_id: StringName) -> void:
	last_seen_positions_by_unit_id.erase(unit_id)


func has_last_seen_position(unit_id: StringName) -> bool:
	return last_seen_positions_by_unit_id.has(unit_id)


func last_seen_position(
		unit_id: StringName,
		fallback: Vector2i = Vector2i(-1, -1)
) -> Vector2i:
	var value: Variant = last_seen_positions_by_unit_id.get(unit_id, fallback)
	return value if value is Vector2i else fallback


func last_seen_unit_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in last_seen_positions_by_unit_id.keys():
		result.append(StringName(value))
	result.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	return result


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if squad_id.is_empty():
		errors.append("Tactical squad has an empty ID.")
	if team_id.is_empty():
		errors.append("Tactical squad %s has an empty team ID." % squad_id)
	if awareness not in [AWARENESS_UNAWARE, AWARENESS_AWARE]:
		errors.append("Tactical squad %s has an unknown awareness state." % squad_id)
	if search_rounds_remaining < 0:
		errors.append("Tactical squad %s has negative search duration." % squad_id)
	if not is_aware() and search_rounds_remaining > 0:
		errors.append("Unaware tactical squad %s cannot be searching." % squad_id)
	var seen: Dictionary = {}
	for unit_id: StringName in member_unit_ids:
		if unit_id.is_empty():
			errors.append("Tactical squad %s contains an empty member ID." % squad_id)
		elif seen.has(unit_id):
			errors.append("Tactical squad %s repeats member %s." % [squad_id, unit_id])
		else:
			seen[unit_id] = true
	for remembered_value: Variant in last_seen_positions_by_unit_id.keys():
		var remembered_id := StringName(remembered_value)
		if remembered_id.is_empty():
			errors.append("Tactical squad %s remembers an empty unit ID." % squad_id)
		elif not (last_seen_positions_by_unit_id[remembered_value] is Vector2i):
			errors.append(
				"Tactical squad %s has an invalid last-seen tile for %s."
				% [squad_id, remembered_id]
			)
	return errors
