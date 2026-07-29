class_name TacticalCharacterSheetState
extends RefCounted

# Compatibility adapter for presentation code written before Stage 3.10.
# The authoritative values live in ResolvedCharacterSnapshot.
var resolved_snapshot: ResolvedCharacterSnapshot


func configure_from_snapshot(snapshot: ResolvedCharacterSnapshot) -> void:
	resolved_snapshot = snapshot


func level() -> int:
	return resolved_snapshot.level if resolved_snapshot != null else 1


func class_name_text() -> String:
	return (
		resolved_snapshot.class_name_text
		if resolved_snapshot != null
		else "Unassigned"
	)


func archetype_name() -> String:
	return resolved_snapshot.archetype_name if resolved_snapshot != null else "None"


func troop_type() -> String:
	return resolved_snapshot.troop_type if resolved_snapshot != null else "Individual"


func ability_line(abbreviation: String) -> String:
	if resolved_snapshot == null:
		return "%s  10  (+0)" % abbreviation
	return resolved_snapshot.ability_line(abbreviation)


func stat_value(stat_id: StringName, fallback: int = 0) -> int:
	if resolved_snapshot == null:
		return fallback
	return resolved_snapshot.stat_value(stat_id, fallback)


func innate_action_ids() -> Array[StringName]:
	if resolved_snapshot == null:
		return []
	return resolved_snapshot.innate_action_ids


func defence_profile_id() -> StringName:
	return resolved_snapshot.defence_profile_id if resolved_snapshot != null else &""


func ability_entries() -> Array[String]:
	return resolved_snapshot.ability_entries if resolved_snapshot != null else []


func condition_entries() -> Array[String]:
	return resolved_snapshot.condition_entries if resolved_snapshot != null else []


func injury_entries() -> Array[String]:
	return resolved_snapshot.injury_entries if resolved_snapshot != null else []


func skill_entries() -> Array[String]:
	var result: Array[String] = []
	if resolved_snapshot == null:
		return result
	var names: Array[String] = []
	for key: Variant in resolved_snapshot.skill_bonuses.keys():
		names.append(String(key))
	names.sort()
	for skill_name: String in names:
		result.append(
			"%s %+d"
			% [skill_name, int(resolved_snapshot.skill_bonuses.get(skill_name, 0))]
		)
	return result


func list_or_none(entries: Array[String], empty_text: String = "None") -> String:
	if entries.is_empty():
		return empty_text
	return "\n".join(PackedStringArray(entries))
