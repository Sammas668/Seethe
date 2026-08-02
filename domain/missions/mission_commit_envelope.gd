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
