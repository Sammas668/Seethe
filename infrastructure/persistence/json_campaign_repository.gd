class_name JsonCampaignRepository
extends CampaignRepository

var save_path: String = DEFAULT_SAVE_PATH
var persistence_enabled: bool = true
var _loaded_current_was_corrupt: bool = false
var _loaded_save_was_migrated: bool = false
var _catalogue: ContentCatalogue


func _init(
		save_path_value: String = DEFAULT_SAVE_PATH,
		persistence_enabled_value: bool = true,
		catalogue_value: ContentCatalogue = null
) -> void:
	save_path = save_path_value
	persistence_enabled = persistence_enabled_value
	_catalogue = catalogue_value


func backup_path() -> String:
	return "%s.bak" % save_path


func temporary_path() -> String:
	return "%s.tmp" % save_path


func load_campaign() -> CampaignState:
	last_load_error = ""
	recovered_from_backup = false
	load_failed = false
	preserved_corrupt_path = ""
	_loaded_current_was_corrupt = false
	_loaded_save_was_migrated = false

	if not persistence_enabled:
		return CampaignState.new()
	if not FileAccess.file_exists(save_path):
		return CampaignState.new()

	var current_result: Dictionary = _read_campaign_file(save_path)
	if bool(current_result.get("success", false)):
		var current_campaign: CampaignState = current_result.get("campaign") as CampaignState
		_loaded_save_was_migrated = bool(current_result.get("migrated", false))
		if _loaded_save_was_migrated and current_campaign != null:
			if not save_campaign(current_campaign):
				push_warning(
					"The legacy Marauder loadout was repaired in memory but could not be persisted."
				)
		return current_campaign

	_loaded_current_was_corrupt = true
	last_load_error = String(current_result.get("message", "Campaign save is invalid."))
	preserved_corrupt_path = _preserve_corrupt_file(save_path)

	if FileAccess.file_exists(backup_path()):
		var backup_result: Dictionary = _read_campaign_file(backup_path())
		if bool(backup_result.get("success", false)):
			recovered_from_backup = true
			var backup_campaign: CampaignState = backup_result.get("campaign") as CampaignState
			_loaded_save_was_migrated = bool(backup_result.get("migrated", false))
			push_warning(
				"Campaign save was invalid; recovered the last valid backup. "
				+ "The damaged file was preserved at %s."
				% preserved_corrupt_path
			)
			return backup_campaign
		last_load_error += " Backup recovery also failed: %s" % String(
			backup_result.get("message", "invalid backup")
		)

	load_failed = true
	push_error(
		"%s The damaged save was preserved and will not be overwritten."
		% last_load_error
	)
	return null


func save_campaign(campaign: CampaignState) -> bool:
	if campaign == null:
		return false
	if not persistence_enabled:
		return true
	if load_failed:
		push_error(
			"Campaign save was not written because the previous load failed. "
			+ "Resolve or remove the damaged save first."
		)
		return false

	var validation_errors: Array[String] = campaign.validate_campaign()
	if _catalogue != null:
		validation_errors.append_array(
			CampaignItemValidator.validate_campaign(campaign, _catalogue)
		)
	if not validation_errors.is_empty():
		push_error(
			"Campaign save rejected by validation: %s" % validation_errors[0]
		)
		return false

	var serialized: String = JSON.stringify(campaign.to_dictionary(), "  ")
	if serialized.is_empty():
		push_error("Campaign serialization produced no data.")
		return false

	_remove_if_exists(temporary_path())
	if not _write_text_file(temporary_path(), serialized):
		push_error("Could not write the temporary Seethe campaign save.")
		return false

	var temporary_result: Dictionary = _read_campaign_file(temporary_path())
	if not bool(temporary_result.get("success", false)):
		_remove_if_exists(temporary_path())
		push_error(
			"Temporary campaign save failed verification: %s"
			% String(temporary_result.get("message", "unknown error"))
		)
		return false

	var current_global: String = ProjectSettings.globalize_path(save_path)
	var backup_global: String = ProjectSettings.globalize_path(backup_path())
	var temporary_global: String = ProjectSettings.globalize_path(temporary_path())
	var moved_current_to_backup: bool = false

	if FileAccess.file_exists(save_path):
		if _loaded_current_was_corrupt:
			if preserved_corrupt_path.is_empty():
				preserved_corrupt_path = _preserve_corrupt_file(save_path)
			if DirAccess.remove_absolute(current_global) != OK:
				_remove_if_exists(temporary_path())
				push_error("Could not remove the damaged current campaign save.")
				return false
		else:
			_remove_if_exists(backup_path())
			if DirAccess.rename_absolute(current_global, backup_global) != OK:
				_remove_if_exists(temporary_path())
				push_error("Could not rotate the previous campaign save to backup.")
				return false
			moved_current_to_backup = true

	if DirAccess.rename_absolute(temporary_global, current_global) != OK:
		if moved_current_to_backup:
			DirAccess.rename_absolute(backup_global, current_global)
		_remove_if_exists(temporary_path())
		push_error("Could not atomically replace the campaign save.")
		return false

	var final_result: Dictionary = _read_campaign_file(save_path)
	if not bool(final_result.get("success", false)):
		_preserve_corrupt_file(save_path)
		_remove_if_exists(save_path)
		if moved_current_to_backup and FileAccess.file_exists(backup_path()):
			DirAccess.rename_absolute(backup_global, current_global)
		push_error("Final campaign save failed verification; backup was restored.")
		return false

	_loaded_current_was_corrupt = false
	recovered_from_backup = false
	return true


func clear_save() -> bool:
	if not persistence_enabled:
		return true
	var success: bool = true
	for path: String in [save_path, backup_path(), temporary_path()]:
		if FileAccess.file_exists(path):
			success = (
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
				and success
			)
	return success


func _read_campaign_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"success": false,
			"message": "Could not open %s." % path,
		}
	var text: String = file.get_as_text()
	file = null
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {
			"success": false,
			"message": "%s does not contain a valid campaign object." % path,
		}
	var campaign: CampaignState = CampaignState.from_dictionary(
		parsed as Dictionary
	)
	var migrated: bool = MarauderLoadoutMigration.repair_existing_marauders(
		campaign
	)
	var validation_errors: Array[String] = campaign.validate_campaign()
	if _catalogue != null:
		validation_errors.append_array(
			CampaignItemValidator.validate_campaign(campaign, _catalogue)
		)
	if not validation_errors.is_empty():
		return {
			"success": false,
			"message": "%s failed campaign validation: %s"
			% [path, validation_errors[0]],
		}
	return {
		"success": true,
		"campaign": campaign,
		"migrated": migrated,
		"message": "",
	}


func _write_text_file(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file = null
	return true


func _preserve_corrupt_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var candidate: String = "%s.corrupt" % path
	var suffix: int = 1
	while FileAccess.file_exists(candidate):
		candidate = "%s.corrupt.%03d" % [path, suffix]
		suffix += 1
	if _copy_file(path, candidate):
		return candidate
	return ""


func _copy_file(source_path: String, target_path: String) -> bool:
	var source: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false
	var bytes: PackedByteArray = source.get_buffer(source.get_length())
	source = null
	var target: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if target == null:
		return false
	target.store_buffer(bytes)
	target.flush()
	target = null
	return true


func _remove_if_exists(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
