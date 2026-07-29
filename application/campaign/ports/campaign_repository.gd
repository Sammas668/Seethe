class_name CampaignRepository
extends RefCounted

const DEFAULT_SAVE_PATH: String = "user://seethe_stage_3_12_character_roster.json"

var last_load_error: String = ""
var recovered_from_backup: bool = false
var load_failed: bool = false
var preserved_corrupt_path: String = ""


func load_campaign() -> CampaignState:
	push_error("CampaignRepository.load_campaign() must be implemented by infrastructure.")
	return null


func save_campaign(_campaign: CampaignState) -> bool:
	push_error("CampaignRepository.save_campaign() must be implemented by infrastructure.")
	return false


func clear_save() -> bool:
	push_error("CampaignRepository.clear_save() must be implemented by infrastructure.")
	return false
