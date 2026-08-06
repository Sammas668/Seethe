class_name Stage53CPersistentHealthRecoveryTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_legacy_full_health_resolution(failures)
	_test_nonlethal_recovers_in_half_the_time(failures)
	_test_injured_deployment_and_unconscious_lock(failures)
	_test_health_round_trip(failures)
	_test_mission_result_round_trip(failures)
	return failures


static func _test_legacy_full_health_resolution(failures: Array[String]) -> void:
	var character := PersistentCharacterState.new()
	_expect(
		character.resolved_current_hp(32) == 32,
		"Legacy/uninitialised characters must resolve at full HP.",
		failures
	)
	_expect(
		character.resolved_nonlethal_damage() == 0,
		"Legacy/uninitialised characters must resolve with no nonlethal damage.",
		failures
	)


static func _test_nonlethal_recovers_in_half_the_time(
		failures: Array[String]
) -> void:
	var character := PersistentCharacterState.new()
	character.set_persistent_health(31, 1, 32)
	character.apply_strategic_recovery(180, 32, 4, 8)
	_expect(
		character.current_hp == 31,
		"Lethal damage must not heal after only half of its required time.",
		failures
	)
	_expect(
		character.nonlethal_damage == 0,
		"Equivalent nonlethal damage must heal in half the lethal recovery time.",
		failures
	)
	character.apply_strategic_recovery(180, 32, 4, 8)
	_expect(
		character.current_hp == 32,
		"Lethal damage must heal after its complete recovery time.",
		failures
	)


static func _test_injured_deployment_and_unconscious_lock(
		failures: Array[String]
) -> void:
	var character := PersistentCharacterState.new()
	character.set_persistent_health(9, 3, 32)
	_expect(
		character.can_deploy_with_health(32),
		"A conscious injured character must remain deployable.",
		failures
	)
	_expect(
		character.health_condition_id(32) == &"gravely_wounded",
		"A conscious character at or below half HP must be Gravely Wounded.",
		failures
	)
	character.set_persistent_health(9, 9, 32)
	_expect(
		not character.can_deploy_with_health(32),
		"A character whose nonlethal damage reaches current HP must be unconscious and unavailable.",
		failures
	)


static func _test_health_round_trip(failures: Array[String]) -> void:
	var character := PersistentCharacterState.new()
	character.character_id = &"character.test.persistent_health"
	character.template_id = &"character_template.test"
	character.display_name = "Persistent Test"
	character.set_persistent_health(17, 6, 32)
	character.lethal_recovery_units = 720
	character.nonlethal_recovery_units = 360
	var restored := PersistentCharacterState.from_dictionary(
		character.to_dictionary()
	)
	_expect(restored.health_initialized, "Health initialisation must survive save/load.", failures)
	_expect(restored.current_hp == 17, "Current HP must survive save/load.", failures)
	_expect(restored.nonlethal_damage == 6, "Nonlethal damage must survive save/load.", failures)
	_expect(restored.lethal_recovery_units == 720, "Lethal recovery progress must survive save/load.", failures)
	_expect(restored.nonlethal_recovery_units == 360, "Nonlethal recovery progress must survive save/load.", failures)


static func _test_mission_result_round_trip(failures: Array[String]) -> void:
	var result := MissionCharacterResult.new()
	result.character_id = &"character.test.result"
	result.was_deployed = true
	result.current_hp = 12
	result.nonlethal_damage = 5
	result.outcome_state = MissionCharacterResult.OUTCOME_EXTRACTED_WOUNDED
	var restored := MissionCharacterResult.from_dictionary(result.to_dictionary())
	_expect(restored.current_hp == 12, "Mission results must preserve final lethal HP.", failures)
	_expect(restored.nonlethal_damage == 5, "Mission results must preserve final nonlethal damage.", failures)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
