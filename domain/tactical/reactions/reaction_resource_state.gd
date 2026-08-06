class_name ReactionResourceState
extends RefCounted

const AVAILABLE: StringName = &"available"
const RESERVED: StringName = &"reserved"
const SPENT: StringName = &"spent"


static func is_valid(value: StringName) -> bool:
	return value in [AVAILABLE, RESERVED, SPENT]


static func display_label(value: StringName) -> String:
	match value:
		AVAILABLE:
			return "Ready"
		RESERVED:
			return "Reserved"
		SPENT:
			return "Spent"
	return "Unknown"
