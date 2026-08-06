class_name WorkforceOfferState
extends RefCounted

var offer_id: StringName = &""
var worker_definition_id: StringName = &""
var market_revision: int = 0


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if offer_id.is_empty():
		errors.append("Workforce offer has no ID.")
	if worker_definition_id.is_empty():
		errors.append("Workforce offer %s has no worker definition." % offer_id)
	if market_revision < 0:
		errors.append("Workforce offer %s has an invalid market revision." % offer_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"offer_id": String(offer_id),
		"worker_definition_id": String(worker_definition_id),
		"market_revision": market_revision,
	}


static func from_dictionary(data: Dictionary) -> WorkforceOfferState:
	var result := WorkforceOfferState.new()
	result.offer_id = StringName(data.get("offer_id", ""))
	result.worker_definition_id = StringName(data.get("worker_definition_id", ""))
	result.market_revision = maxi(0, int(data.get("market_revision", 0)))
	return result
