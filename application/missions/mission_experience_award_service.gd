class_name MissionExperienceAwardService
extends RefCounted

# Authoritative mission-return XP. The award is outcome/objective based so
# support, capture and recovery troops progress without needing the final hit.
# Only surviving persistent player characters physically extracted from the
# mission receive it. The complete calculation is stored on the immutable
# MissionCharacterResult and validated again before campaign commitment.


static func apply_awards(result: MissionResult, setup: MissionSetupSnapshot) -> void:
	if result == null or setup == null:
		return
	var plan: Dictionary = award_plan(result)
	var award: int = int(plan.get("amount", 0))
	var breakdown: Array[String] = []
	for raw_line: Variant in plan.get("breakdown", []) as Array:
		breakdown.append(String(raw_line))

	for character_result: MissionCharacterResult in result.get_character_results():
		var eligible: bool = _eligible_for_award(character_result, setup)
		character_result.xp_awarded = award if eligible else 0
		character_result.xp_award_breakdown = breakdown.duplicate() if eligible else []


static func award_plan(result: MissionResult) -> Dictionary:
	var amount: int = 0
	var breakdown: Array[String] = []
	if result == null:
		return {"amount": 0, "breakdown": breakdown}

	match result.mission_outcome:
		MissionOutcome.VICTORY:
			amount += 100
			breakdown.append("Victory: 100 XP")
		MissionOutcome.WITHDRAWAL:
			amount += 50
			breakdown.append("Survived withdrawal: 50 XP")
		_:
			pass

	var objective_xp: int = result.completed_objective_ids.size() * 25
	if objective_xp > 0:
		amount += objective_xp
		breakdown.append(
			"Completed objectives: %d XP" % objective_xp
		)

	var kill_xp: int = mini(
		50,
		maxi(0, int(result.mission_statistics.get("enemies_killed", 0))) * 5
	)
	if kill_xp > 0:
		amount += kill_xp
		breakdown.append("Hostiles killed: %d XP" % kill_xp)

	var incapacitation_xp: int = mini(
		50,
		maxi(0, int(result.mission_statistics.get("enemies_incapacitated", 0))) * 5
	)
	if incapacitation_xp > 0:
		amount += incapacitation_xp
		breakdown.append("Hostiles incapacitated: %d XP" % incapacitation_xp)

	var captive_xp: int = mini(
		30,
		maxi(0, int(result.mission_statistics.get("captives_taken", 0))) * 10
	)
	if captive_xp > 0:
		amount += captive_xp
		breakdown.append("Captives returned: %d XP" % captive_xp)

	var support_xp: int = mini(
		25,
		maxi(0, int(result.mission_statistics.get("allies_stabilised", 0))) * 5
	)
	if support_xp > 0:
		amount += support_xp
		breakdown.append("Allies stabilised: %d XP" % support_xp)

	return {
		"amount": amount,
		"breakdown": breakdown,
	}


static func validate_awards(
		result: MissionResult,
		setup: MissionSetupSnapshot
) -> Array[String]:
	var errors: Array[String] = []
	if result == null or setup == null:
		return errors
	var plan: Dictionary = award_plan(result)
	var expected_amount: int = int(plan.get("amount", 0))
	var expected_breakdown: Array[String] = []
	for raw_line: Variant in plan.get("breakdown", []) as Array:
		expected_breakdown.append(String(raw_line))
	for character_result: MissionCharacterResult in result.get_character_results():
		var eligible: bool = _eligible_for_award(character_result, setup)
		var expected_character_award: int = expected_amount if eligible else 0
		if character_result.xp_awarded != expected_character_award:
			errors.append(
				"Character %s mission XP %d does not match the authoritative award %d."
				% [
					character_result.character_id,
					character_result.xp_awarded,
					expected_character_award,
				]
			)
		if eligible and character_result.xp_award_breakdown != expected_breakdown:
			errors.append(
				"Character %s mission XP breakdown does not match the authoritative award plan."
				% character_result.character_id
			)
		if not eligible and not character_result.xp_award_breakdown.is_empty():
			errors.append(
				"Character %s has an XP breakdown despite being ineligible for mission XP."
				% character_result.character_id
			)
	return errors


static func _eligible_for_award(
		character_result: MissionCharacterResult,
		setup: MissionSetupSnapshot
) -> bool:
	if character_result == null or setup == null:
		return false
	var mission_character: PersistentCharacterState = setup.get_character(
		character_result.character_id
	)
	return (
		mission_character != null
		and mission_character.persistence_scope
		== PersistentCharacterState.PERSISTENCE_CAMPAIGN
		and mission_character.roster_role == PersistentCharacterState.ROLE_PLAYER
		and character_result.was_deployed
		and character_result.survived
		and character_result.extracted
		and not character_result.captured
	)
