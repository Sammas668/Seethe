class_name MissionAuthoritySnapshot
extends RefCounted

var mission_id: StringName = &""
var source_setup_hash: String = ""
var resolution_revision: int = 0
var generated_item_provenance_entries: Array[Dictionary] = []
var authority_snapshot_hash: String = ""
var _finalized: bool = false


static func from_tactical_state(
		state: TacticalState,
		setup: MissionSetupSnapshot
) -> MissionAuthoritySnapshot:
	var result := MissionAuthoritySnapshot.new()
	if state == null or setup == null or not setup.verify_integrity():
		return result
	result.mission_id = setup.mission_id
	result.source_setup_hash = setup.finalized_setup_hash()
	result.resolution_revision = state.revision
	for provenance: TacticalGeneratedItemProvenance in state.generated_item_provenance_records():
		result.generated_item_provenance_entries.append(provenance.to_dictionary())
	result.generated_item_provenance_entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("provenance_id", "")) < String(b.get("provenance_id", ""))
	)
	result._finalized = true
	result.authority_snapshot_hash = CanonicalDataHasher.sha256_hex(
		result._canonical_dictionary()
	)
	return result


func is_finalized() -> bool:
	return _finalized and authority_snapshot_hash.length() == 64


func verify_integrity() -> bool:
	return (
		is_finalized()
		and CanonicalDataHasher.sha256_hex(_canonical_dictionary())
		== authority_snapshot_hash
	)


func provenance(provenance_id: StringName) -> TacticalGeneratedItemProvenance:
	for entry: Dictionary in generated_item_provenance_entries:
		if StringName(entry.get("provenance_id", "")) == provenance_id:
			return TacticalGeneratedItemProvenance.from_dictionary(entry)
	return null


func provenance_for_item(item_id: StringName) -> TacticalGeneratedItemProvenance:
	for entry: Dictionary in generated_item_provenance_entries:
		if StringName(entry.get("generated_item_id", "")) == item_id:
			return TacticalGeneratedItemProvenance.from_dictionary(entry)
	return null


func to_dictionary() -> Dictionary:
	return {
		"mission_id": String(mission_id),
		"source_setup_hash": source_setup_hash,
		"resolution_revision": resolution_revision,
		"generated_item_provenance_entries": generated_item_provenance_entries.duplicate(true),
		"authority_snapshot_hash": authority_snapshot_hash,
		"finalized": _finalized,
	}


static func from_dictionary(data: Dictionary) -> MissionAuthoritySnapshot:
	var result := MissionAuthoritySnapshot.new()
	result.mission_id = StringName(data.get("mission_id", ""))
	result.source_setup_hash = String(data.get("source_setup_hash", ""))
	result.resolution_revision = maxi(0, int(data.get("resolution_revision", 0)))
	var entries: Variant = data.get("generated_item_provenance_entries", [])
	if entries is Array:
		for entry: Variant in entries as Array:
			if entry is Dictionary:
				result.generated_item_provenance_entries.append(
					(entry as Dictionary).duplicate(true)
				)
	result.authority_snapshot_hash = String(data.get("authority_snapshot_hash", ""))
	result._finalized = bool(data.get("finalized", false))
	return result


func _canonical_dictionary() -> Dictionary:
	return {
		"mission_id": String(mission_id),
		"source_setup_hash": source_setup_hash,
		"resolution_revision": resolution_revision,
		"generated_item_provenance_entries": generated_item_provenance_entries.duplicate(true),
	}
