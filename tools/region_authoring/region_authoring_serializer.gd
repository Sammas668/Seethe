class_name RegionAuthoringSerializer
extends RefCounted

const DEFAULT_DIRECTORY: String = "user://region_authoring/life_starter"
const DEFAULT_WORKING_PATH: String = DEFAULT_DIRECTORY + "/working.json"
const DEFAULT_AUTOSAVE_PATH: String = DEFAULT_DIRECTORY + "/recovery.json"
const BACKUP_DIRECTORY: String = DEFAULT_DIRECTORY + "/backups"
const EDITOR_STATE_PATH: String = "user://region_authoring/editor_state.json"
const MAX_BACKUPS: int = 20


static func save_working_document(path: String, document: RegionAuthoringDocument) -> OperationResult:
	var normalised_path: String = _normalise_json_path(path)
	var result: OperationResult = save_document(normalised_path, document)
	if not result.success:
		return result
	remember_last_document_path(normalised_path)
	discard_recovery(normalised_path)
	return OperationResult.ok(document, "Region saved to %s." % display_path(normalised_path))


static func save_document(path: String, document: RegionAuthoringDocument) -> OperationResult:
	if document == null or document.region == null:
		return OperationResult.fail(&"authoring_document_missing", "No region authoring document is loaded.")
	var normalised_path: String = _normalise_json_path(path)
	var directory: String = normalised_path.get_base_dir()
	if not _ensure_directory(directory):
		return OperationResult.fail(&"authoring_directory_failed", "Could not create the authoring save directory.")
	var temporary_path: String = normalised_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return OperationResult.fail(&"authoring_save_open_failed", "Could not open the authoring save file for writing.")
	file.store_string(JSON.stringify(document.to_dictionary(), "\t", false))
	file.flush()
	file.close()
	var temporary_check: OperationResult = load_document(temporary_path)
	if not temporary_check.success:
		_remove_file_if_present(temporary_path)
		return OperationResult.fail(&"authoring_save_verify_failed", "The temporary authoring save could not be verified.")
	var rotated_path: String = ""
	if FileAccess.file_exists(normalised_path):
		rotated_path = _rotate_backup(normalised_path)
		if rotated_path.is_empty():
			_remove_file_if_present(temporary_path)
			return OperationResult.fail(&"authoring_backup_failed", "Could not preserve the previous authoring save.")
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(normalised_path)
	) != OK:
		_restore_rotated_file(rotated_path, normalised_path)
		_remove_file_if_present(temporary_path)
		return OperationResult.fail(&"authoring_save_replace_failed", "Could not replace the authoring save file.")
	var final_check: OperationResult = load_document(normalised_path)
	if not final_check.success:
		_remove_file_if_present(normalised_path)
		_restore_rotated_file(rotated_path, normalised_path)
		return OperationResult.fail(
			&"authoring_save_final_verify_failed",
			"The final authoring save failed verification; the previous save was restored."
		)
	return OperationResult.ok(document, "Region authoring document saved.")


static func load_document(path: String) -> OperationResult:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return OperationResult.fail(&"authoring_open_failed", "Could not open %s." % display_path(path))
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var error: Error = json.parse(text)
	if error != OK or not (json.data is Dictionary):
		return OperationResult.fail(
			&"authoring_parse_failed",
			"The authoring document is not valid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		)
	var document := RegionAuthoringDocument.from_dictionary(json.data as Dictionary)
	if document.region == null:
		return OperationResult.fail(&"authoring_region_missing", "The authoring document has no region definition.")
	return OperationResult.ok(document, "Region authoring document opened from %s." % display_path(path))


static func autosave(document: RegionAuthoringDocument, working_path: String = DEFAULT_WORKING_PATH) -> OperationResult:
	var recovery_path: String = recovery_path_for(working_path)
	var result: OperationResult = save_document(recovery_path, document)
	if not result.success:
		return result
	return OperationResult.ok(document, "Recovery copy saved to %s." % display_path(recovery_path))


static func preferred_working_path() -> String:
	var state: Dictionary = _load_editor_state()
	var saved_path: String = String(state.get("last_document_path", "")).strip_edges()
	if not saved_path.is_empty():
		return saved_path
	return DEFAULT_WORKING_PATH


static func remember_last_document_path(path: String) -> void:
	var normalised_path: String = _normalise_json_path(path)
	var state: Dictionary = _load_editor_state()
	state["last_document_path"] = normalised_path
	state["updated_at_unix"] = int(Time.get_unix_time_from_system())
	_write_editor_state(state)


static func recovery_path_for(working_path: String) -> String:
	var normalised_path: String = _normalise_json_path(working_path)
	if normalised_path == DEFAULT_WORKING_PATH:
		return DEFAULT_AUTOSAVE_PATH
	return normalised_path + ".recovery"


static func has_recoverable_autosave(working_path: String = DEFAULT_WORKING_PATH) -> bool:
	var recovery_path: String = recovery_path_for(working_path)
	if not FileAccess.file_exists(recovery_path):
		return false
	if not FileAccess.file_exists(working_path):
		return true
	return FileAccess.get_modified_time(recovery_path) > FileAccess.get_modified_time(working_path)


static func discard_recovery(working_path: String = DEFAULT_WORKING_PATH) -> void:
	_remove_file_if_present(recovery_path_for(working_path))


static func document_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


static func display_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return "%s (%s)" % [path, ProjectSettings.globalize_path(path)]
	return path


static func open_document_directory(working_path: String = DEFAULT_WORKING_PATH) -> Error:
	var directory: String = _normalise_json_path(working_path).get_base_dir()
	if not _ensure_directory(directory):
		return ERR_CANT_CREATE
	return OS.shell_open(ProjectSettings.globalize_path(directory))


static func _normalise_json_path(path: String) -> String:
	var normalised: String = path.strip_edges()
	if normalised.is_empty():
		normalised = DEFAULT_WORKING_PATH
	if not normalised.to_lower().ends_with(".json") and not normalised.to_lower().ends_with(".json.recovery"):
		normalised += ".json"
	return normalised


static func _rotate_backup(path: String) -> String:
	var backup_directory: String = _backup_directory_for(path)
	if not _ensure_directory(backup_directory):
		return ""
	var timestamp: int = int(Time.get_unix_time_from_system())
	var source_name: String = path.get_file().replace(".json", "").replace(".", "_")
	if source_name.is_empty():
		source_name = "region"
	var backup_path: String = "%s/%s_%d.json" % [backup_directory, source_name, timestamp]
	var suffix: int = 1
	while FileAccess.file_exists(backup_path):
		backup_path = "%s/%s_%d_%d.json" % [backup_directory, source_name, timestamp, suffix]
		suffix += 1
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(path),
		ProjectSettings.globalize_path(backup_path)
	) != OK:
		return ""
	_prune_backups(backup_directory, MAX_BACKUPS)
	return backup_path


static func _backup_directory_for(path: String) -> String:
	if path.begins_with("user://") and path.get_base_dir() == DEFAULT_DIRECTORY:
		return BACKUP_DIRECTORY
	return path.get_base_dir() + "/Seethe_Region_Backups"


static func _restore_rotated_file(rotated_path: String, destination_path: String) -> void:
	if rotated_path.is_empty() or not FileAccess.file_exists(rotated_path):
		return
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(rotated_path),
		ProjectSettings.globalize_path(destination_path)
	)


static func _prune_backups(directory_path: String, limit: int) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	var names: Array[String] = []
	for file_name: String in directory.get_files():
		if file_name.ends_with(".json"):
			names.append(file_name)
	names.sort()
	while names.size() > limit:
		directory.remove(names.pop_front())


static func _load_editor_state() -> Dictionary:
	if not FileAccess.file_exists(EDITOR_STATE_PATH):
		return {}
	var file := FileAccess.open(EDITOR_STATE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


static func _write_editor_state(state: Dictionary) -> void:
	if not _ensure_directory(EDITOR_STATE_PATH.get_base_dir()):
		return
	var file := FileAccess.open(EDITOR_STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(state, "\t", false))
	file.flush()
	file.close()


static func _remove_file_if_present(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _ensure_directory(path: String) -> bool:
	if path.is_empty():
		return false
	var absolute: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute):
		return true
	return DirAccess.make_dir_recursive_absolute(absolute) == OK
