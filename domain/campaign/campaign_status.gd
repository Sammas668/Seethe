class_name CampaignStatus
extends RefCounted

const UNINITIALIZED: StringName = &"uninitialized"
const ACTIVE: StringName = &"active"
const MISSION_REGISTERED: StringName = &"mission_registered"
const IN_TACTICAL: StringName = &"in_tactical"
const DEFEATED: StringName = &"defeated"


static func is_valid(value: StringName) -> bool:
	return value in [
		UNINITIALIZED,
		ACTIVE,
		MISSION_REGISTERED,
		IN_TACTICAL,
		DEFEATED,
	]
