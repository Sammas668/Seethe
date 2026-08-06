class_name MissionCommitEnvelope
extends RefCounted

var setup: MissionSetupSnapshot
var result: MissionResult
var authority_snapshot: MissionAuthoritySnapshot


func _init(
		setup_value: MissionSetupSnapshot = null,
		result_value: MissionResult = null,
		authority_value: MissionAuthoritySnapshot = null
) -> void:
	setup = setup_value
	result = result_value
	authority_snapshot = authority_value


func validate_envelope() -> Array[String]:
	var errors: Array[String] = []
	if setup == null or result == null:
		errors.append("Mission commit envelope is missing setup or result.")
		return errors
	if not setup.verify_integrity():
		errors.append("Mission commit envelope contains an invalid setup snapshot.")
	if result.source_setup_hash != setup.finalized_setup_hash():
		errors.append("Mission result does not match the setup hash.")
	if authority_snapshot != null:
		if not authority_snapshot.verify_integrity():
			errors.append("Mission authority snapshot failed integrity verification.")
		elif authority_snapshot.mission_id != setup.mission_id:
			errors.append("Mission authority snapshot belongs to another mission.")
		elif authority_snapshot.source_setup_hash != setup.finalized_setup_hash():
			errors.append("Mission authority snapshot uses another setup hash.")
	return errors


func to_dictionary() -> Dictionary:
	return {
		"setup": setup.to_dictionary() if setup != null else {},
		"result": result.to_dictionary() if result != null else {},
		"authority_snapshot": (
			authority_snapshot.to_dictionary() if authority_snapshot != null else {}
		),
	}


static func from_dictionary(data: Dictionary) -> MissionCommitEnvelope:
	var setup_value: MissionSetupSnapshot = null
	var result_value: MissionResult = null
	var authority_value: MissionAuthoritySnapshot = null
	var raw_setup: Variant = data.get("setup", {})
	if raw_setup is Dictionary and not (raw_setup as Dictionary).is_empty():
		setup_value = MissionSetupSnapshot.from_dictionary(raw_setup as Dictionary)
	var raw_result: Variant = data.get("result", {})
	if raw_result is Dictionary and not (raw_result as Dictionary).is_empty():
		result_value = MissionResult.from_dictionary(raw_result as Dictionary)
	var raw_authority: Variant = data.get("authority_snapshot", {})
	if raw_authority is Dictionary and not (raw_authority as Dictionary).is_empty():
		authority_value = MissionAuthoritySnapshot.from_dictionary(raw_authority as Dictionary)
	return MissionCommitEnvelope.new(setup_value, result_value, authority_value)
