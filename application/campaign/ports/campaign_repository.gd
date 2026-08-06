class_name CampaignRepository
extends RefCounted

const DEFAULT_SAVE_PATH: String = "user://seethe_campaign.json"

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


func has_campaign() -> bool:
	return false


func save_safe_checkpoint(_campaign: CampaignState) -> bool:
	push_error("CampaignRepository.save_safe_checkpoint() must be implemented by infrastructure.")
	return false


func load_safe_checkpoint() -> CampaignState:
	push_error("CampaignRepository.load_safe_checkpoint() must be implemented by infrastructure.")
	return null


func has_safe_checkpoint() -> bool:
	return false


func clear_safe_checkpoint() -> bool:
	return true


func save_pending_mission_recovery(_data: Dictionary) -> bool:
	return false


func load_pending_mission_recovery() -> Dictionary:
	return {}


func has_pending_mission_recovery() -> bool:
	return false


func clear_pending_mission_recovery() -> bool:
	return true
