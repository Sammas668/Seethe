class_name MissionCharacterOutcomeService
extends RefCounted

# Stage 5.3G owns the immutable per-character contribution record used by the
# mission summary and by PersistentCharacterState.history_entries. It is built
# before the tactical scene is retired and can be reconciled again after the
# player confirms which captives and optional cargo are actually returning.


static func populate(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		state: TacticalState,
		event_journal: RefCounted = null
) -> void:
	if result == null or setup == null:
		return
	_initialize_character_records(result)
	_apply_combat_contributions(result, setup, state, event_journal)
	_apply_first_aid_contributions(result, setup, event_journal)
	_rebuild_capture_contributions(result)
	refresh_history(result, setup)


static func needs_lifecycle_migration(result: MissionResult) -> bool:
	if result == null or result.extracted_zone_id.is_empty():
		return false
	for character_result: MissionCharacterResult in result.get_character_results():
		if not character_result.was_deployed:
			continue
		if character_result.mission_statistics.is_empty():
			return true
		if character_result.completed_objective_ids != result.completed_objective_ids:
			return true
		if character_result.failed_objective_ids != result.failed_objective_ids:
			return true
		if character_result.history_entry.strip_edges().is_empty():
			return true
		if character_result.xp_awarded > 0 and character_result.xp_award_breakdown.is_empty():
			return true
	return false


static func reconcile_after_recovery_selection(
		result: MissionResult,
		setup: MissionSetupSnapshot
) -> void:
	if result == null or setup == null:
		return
	for character_result: MissionCharacterResult in result.get_character_results():
		character_result.completed_objective_ids = result.completed_objective_ids.duplicate()
		character_result.failed_objective_ids = result.failed_objective_ids.duplicate()
		character_result.mission_statistics["objectives_completed"] = (
			result.completed_objective_ids.size()
		)
		character_result.mission_statistics["objectives_failed"] = (
			result.failed_objective_ids.size()
		)
		character_result.mission_statistics["captures"] = 0
	_rebuild_capture_contributions(result)
	refresh_history(result, setup)


static func refresh_history(
		result: MissionResult,
		setup: MissionSetupSnapshot
) -> void:
	if result == null or setup == null:
		return
	for character_result: MissionCharacterResult in result.get_character_results():
		if not character_result.was_deployed:
			character_result.history_entry = ""
			continue
		var clauses: Array[String] = []
		clauses.append(
			"Mission %s ended in %s. %s."
			% [
				result.mission_id,
				MissionOutcome.display_name(result.mission_outcome),
				MissionCharacterResult.outcome_display_name(
					character_result.outcome_state
				),
			]
		)
		if not character_result.completed_objective_ids.is_empty():
			clauses.append(
				"Completed objectives: %s."
				% _objective_list(character_result.completed_objective_ids)
			)
		if not character_result.failed_objective_ids.is_empty():
			clauses.append(
				"Failed objectives: %s."
				% _objective_list(character_result.failed_objective_ids)
			)
		var kills: int = character_result.statistic(&"kills")
		var incapacitations: int = character_result.statistic(&"incapacitations")
		var captures: int = character_result.statistic(&"captures")
		var stabilisations: int = character_result.statistic(&"allies_stabilised")
		if kills > 0:
			clauses.append("Kills: %d." % kills)
		if incapacitations > 0:
			clauses.append("Hostiles incapacitated: %d." % incapacitations)
		if captures > 0:
			clauses.append("Captures secured: %d." % captures)
		if stabilisations > 0:
			clauses.append("Allies stabilised: %d." % stabilisations)
		if character_result.xp_awarded > 0:
			clauses.append("Gained %d XP." % character_result.xp_awarded)
		character_result.history_entry = " ".join(clauses)


static func _initialize_character_records(result: MissionResult) -> void:
	for character_result: MissionCharacterResult in result.get_character_results():
		character_result.mission_statistics = {
			"kills": 0,
			"incapacitations": 0,
			"captures": 0,
			"allies_stabilised": 0,
			"objectives_completed": result.completed_objective_ids.size(),
			"objectives_failed": result.failed_objective_ids.size(),
		}
		character_result.completed_objective_ids = result.completed_objective_ids.duplicate()
		character_result.failed_objective_ids = result.failed_objective_ids.duplicate()


static func _apply_combat_contributions(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		state: TacticalState,
		event_journal: RefCounted
) -> void:
	for event: Dictionary in _all_events(event_journal):
		if StringName(event.get("event_type", "")) != &"attack_resolved":
			continue
		var metadata: Dictionary = event.get("metadata", {}) as Dictionary
		if not bool(metadata.get("target_became_defeated", false)):
			continue
		var source_id := StringName(event.get("source_actor_id", ""))
		if not _is_deployed_player_character(setup, source_id):
			continue
		var source_result: MissionCharacterResult = result.get_character_result(source_id)
		if source_result == null:
			continue
		var target_ids: Array = event.get("target_actor_ids", []) as Array
		if target_ids.is_empty():
			continue
		var target_id := StringName(target_ids[0])
		var target: TacticalUnitState = state.get_unit(target_id) if state != null else null
		if target == null or target.team_id == &"player":
			continue
		var life_state := StringName(metadata.get("target_life_state", ""))
		if life_state == TacticalUnitState.LIFE_STATE_DEAD:
			_increment_stat(source_result, &"kills")
		else:
			_increment_stat(source_result, &"incapacitations")


static func _apply_first_aid_contributions(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		event_journal: RefCounted
) -> void:
	for event: Dictionary in _all_events(event_journal):
		if StringName(event.get("event_type", "")) != &"first_aid":
			continue
		var source_id := StringName(event.get("source_actor_id", ""))
		if not _is_deployed_player_character(setup, source_id):
			continue
		var succeeded: bool = false
		for raw_roll: Variant in event.get("roll_records", []) as Array:
			if (
				raw_roll is Dictionary
				and StringName((raw_roll as Dictionary).get("outcome", ""))
				== &"success"
			):
				succeeded = true
				break
		if succeeded:
			var source_result: MissionCharacterResult = result.get_character_result(source_id)
			if source_result != null:
				_increment_stat(source_result, &"allies_stabilised")


static func _rebuild_capture_contributions(result: MissionResult) -> void:
	for captive: MissionCaptiveResult in result.get_captive_results():
		if captive == null or captive.captor_character_id.is_empty():
			continue
		var captor_result: MissionCharacterResult = result.get_character_result(
			captive.captor_character_id
		)
		if captor_result != null:
			_increment_stat(captor_result, &"captures")


static func _increment_stat(
		character_result: MissionCharacterResult,
		stat_id: StringName,
		amount: int = 1
) -> void:
	if character_result == null or amount <= 0:
		return
	character_result.mission_statistics[stat_id] = (
		character_result.statistic(stat_id) + amount
	)


static func _is_deployed_player_character(
		setup: MissionSetupSnapshot,
		character_id: StringName
) -> bool:
	if setup == null or character_id.is_empty() or not setup.was_deployed(character_id):
		return false
	var character: PersistentCharacterState = setup.get_character(character_id)
	return (
		character != null
		and character.roster_role == PersistentCharacterState.ROLE_PLAYER
	)


static func _all_events(event_journal: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if event_journal == null or not event_journal.has_method("events"):
		return result
	var raw_events: Variant = event_journal.call("events", &"all", true)
	if not raw_events is Array:
		return result
	for raw_event: Variant in raw_events as Array:
		if raw_event is Dictionary:
			result.append((raw_event as Dictionary).duplicate(true))
	return result


static func _objective_list(values: Array[StringName]) -> String:
	var labels: Array[String] = []
	for value: StringName in values:
		labels.append(String(value).replace("_", " ").replace(".", " ").capitalize())
	return ", ".join(labels)
