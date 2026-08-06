class_name MissionOutcome
extends RefCounted

const IN_PROGRESS: StringName = &"in_progress"
const VICTORY: StringName = &"victory"
const WITHDRAWAL: StringName = &"withdrawal"
const DEFEAT: StringName = &"defeat"
const CAMPAIGN_DEFEAT: StringName = &"campaign_defeat"


static func is_final(value: StringName) -> bool:
	return value in [VICTORY, WITHDRAWAL, DEFEAT, CAMPAIGN_DEFEAT]


static func display_name(value: StringName) -> String:
	match value:
		VICTORY:
			return "VICTORY"
		WITHDRAWAL:
			return "WITHDRAWAL"
		DEFEAT:
			return "TACTICAL DEFEAT"
		CAMPAIGN_DEFEAT:
			return "CAMPAIGN DEFEAT"
		_:
			return "IN PROGRESS"
