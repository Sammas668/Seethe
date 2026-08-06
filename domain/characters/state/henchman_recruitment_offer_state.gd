class_name HenchmanRecruitmentOfferState
extends RefCounted

var offer_id: StringName = &""
var recruitment_definition_id: StringName = &""
var candidate_name: String = "Unnamed Recruit"
var portrait_id: StringName = &"portrait.reaver.marauder"
var generated_identity_seed: int = 0
var market_revision: int = 0


func to_dictionary() -> Dictionary:
	return {
		"offer_id": String(offer_id),
		"recruitment_definition_id": String(recruitment_definition_id),
		"candidate_name": candidate_name,
		"portrait_id": String(portrait_id),
		"generated_identity_seed": generated_identity_seed,
		"market_revision": market_revision,
	}


static func from_dictionary(data: Dictionary) -> HenchmanRecruitmentOfferState:
	var result := HenchmanRecruitmentOfferState.new()
	result.offer_id = StringName(data.get("offer_id", ""))
	result.recruitment_definition_id = StringName(data.get("recruitment_definition_id", ""))
	result.candidate_name = String(data.get("candidate_name", "Unnamed Recruit"))
	result.portrait_id = StringName(data.get("portrait_id", "portrait.reaver.marauder"))
	result.generated_identity_seed = int(data.get("generated_identity_seed", 0))
	result.market_revision = maxi(0, int(data.get("market_revision", 0)))
	return result
