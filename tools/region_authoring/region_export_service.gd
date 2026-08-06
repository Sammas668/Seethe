class_name RegionExportService
extends RefCounted

const EXPORT_DIRECTORY: String = "user://region_authoring/exports"


static func export_bundle(
	document: RegionAuthoringDocument,
	preview_image: Image,
	validation_messages: Array[Dictionary],
	requested_path: String = ""
) -> OperationResult:
	if document == null or document.region == null:
		return OperationResult.fail(&"region_export_missing", "No region document is loaded.")
	if RegionValidationService.has_errors(validation_messages):
		return OperationResult.fail(&"region_export_invalid", "The region has validation errors and cannot be exported.")
	if not _ensure_directory(EXPORT_DIRECTORY):
		return OperationResult.fail(&"region_export_directory_failed", "Could not create the region export directory.")
	var timestamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-")
	var root_name: String = "Seethe_%s_Region_Authoring_%s" % [String(document.region.id).replace(".", "_"), timestamp]
	var temporary_directory: String = EXPORT_DIRECTORY + "/" + root_name
	var absolute_temporary: String = ProjectSettings.globalize_path(temporary_directory)
	if DirAccess.dir_exists_absolute(absolute_temporary):
		_remove_directory_recursive(absolute_temporary)
	if DirAccess.make_dir_recursive_absolute(absolute_temporary) != OK:
		return OperationResult.fail(&"region_export_temp_failed", "Could not create the temporary export directory.")
	var files: Dictionary = _build_runtime_files(document)
	files["authoring_document.json"] = JSON.stringify(document.to_dictionary(), "\t", false)
	files["validation_report.txt"] = _validation_report(validation_messages)
	for relative_path: String in files.keys():
		if not _write_text(temporary_directory + "/" + relative_path, String(files[relative_path])):
			_remove_directory_recursive(absolute_temporary)
			return OperationResult.fail(&"region_export_write_failed", "Could not write %s." % relative_path)
	if preview_image != null and not preview_image.is_empty():
		preview_image.save_png(temporary_directory + "/rendered_preview.png")
	var checksums: Dictionary = _checksums_for_directory(temporary_directory)
	_write_text(temporary_directory + "/checksums.txt", _checksums_text(checksums))
	var manifest: Dictionary = {
		"format_version": RegionAuthoringDocument.FORMAT_VERSION,
		"region_id": String(document.region.id),
		"exported_at": Time.get_datetime_string_from_system(true, true),
		"game_build_version": "Stage 5.1a Region Authoring Tool",
		"validation_status": "valid",
		"file_list": _sorted_file_names(temporary_directory),
		"checksums": checksums,
	}
	_write_text(temporary_directory + "/manifest.json", JSON.stringify(manifest, "\t", false))
	var output_path: String = requested_path
	if output_path.is_empty():
		output_path = EXPORT_DIRECTORY + "/" + root_name + ".zip"
	elif not output_path.to_lower().ends_with(".zip"):
		output_path += ".zip"
	var zip_result: Error = _zip_directory(temporary_directory, output_path)
	if zip_result != OK:
		_remove_directory_recursive(absolute_temporary)
		return OperationResult.fail(&"region_export_zip_failed", "Could not create the region export ZIP.")
	_remove_directory_recursive(absolute_temporary)
	return OperationResult.ok(output_path, "Region authoring bundle exported to %s." % output_path)


static func export_runtime_files(document: RegionAuthoringDocument, directory: String) -> OperationResult:
	if document == null or document.region == null:
		return OperationResult.fail(&"runtime_export_missing", "No region document is loaded.")
	if not _ensure_directory(directory):
		return OperationResult.fail(&"runtime_export_directory_failed", "Could not create the runtime export directory.")
	var files: Dictionary = _build_runtime_files(document)
	for relative_path: String in files.keys():
		if not _write_text(directory + "/" + relative_path, String(files[relative_path])):
			return OperationResult.fail(&"runtime_export_write_failed", "Could not write %s." % relative_path)
	return OperationResult.ok(directory, "Runtime region data exported to %s." % directory)


static func _build_runtime_files(document: RegionAuthoringDocument) -> Dictionary:
	var region: RegionMapDefinition = document.region
	var metadata: Dictionary = {
		"id": String(region.id),
		"display_name": region.display_name,
		"width": region.width,
		"height": region.height,
		"hex_orientation": String(region.hex_orientation),
		"main_settlement_site_id": String(region.main_settlement_site_id),
		"fifth_god_ruin_site_id": String(region.fifth_god_ruin_site_id),
		"military_site_id": String(region.military_site_id),
		"religious_site_ids": _string_name_array(region.religious_site_ids),
		"mission_site_ids": _string_name_array(region.mission_site_ids),
		"aliases": _string_name_array(region.aliases),
		"subregions": _subregions_array(region.subregions_by_id),
		"label_offsets": _label_offsets_dictionary(document.label_offsets_by_site_id),
	}
	return {
		"life_starter_region.json": JSON.stringify(metadata, "\t", false),
		"life_starter_region_hexes.csv": _hexes_csv(region),
		"life_starter_region_sites.json": JSON.stringify({"sites": _sites_array(region)}, "\t", false),
		"life_starter_region_road_edges.json": JSON.stringify({"road_edges": _edges_array(region.all_road_edges(), true)}, "\t", false),
		"life_starter_region_border_edges.json": JSON.stringify({"border_edges": _edges_array(region.all_border_edges(), false)}, "\t", false),
	}


static func _hexes_csv(region: RegionMapDefinition) -> String:
	var lines: PackedStringArray = ["offset_col,offset_row,playable,terrain,subregion,site_id,visual_variant"]
	for hex: RegionHexDefinition in region.all_hexes():
		lines.append("%d,%d,%s,%s,%s,%s,%d" % [
			hex.coord.offset_col,
			hex.coord.offset_row,
			"true" if hex.playable else "false",
			String(hex.terrain_type),
			String(hex.subregion_id),
			String(hex.site_id),
			hex.visual_variant,
		])
	return "\n".join(lines) + "\n"


static func _sites_array(region: RegionMapDefinition) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site: RegionSiteDefinition in region.all_sites():
		var footprint: Array = []
		for coord: RegionHexCoord in site.footprint:
			footprint.append([coord.offset_col, coord.offset_row])
		result.append({
			"id": String(site.id),
			"display_name": site.display_name,
			"site_type": String(site.site_type),
			"coord": [site.coord.offset_col, site.coord.offset_row] if site.coord != null else [],
			"footprint": footprint,
			"parent_settlement_id": String(site.parent_settlement_id),
			"subregion_id": String(site.subregion_id),
			"description": site.description,
			"tags": _string_name_array(site.tags),
			"icon_id": String(site.icon_id),
			"mission_definition_ids": _string_name_array(site.mission_definition_ids),
			"inspectable": site.inspectable,
			"label_priority": site.label_priority,
			"aliases": _string_name_array(site.aliases),
		})
	return result


static func _edges_array(edges: Array[RegionMapEdgeDefinition], is_road: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for edge: RegionMapEdgeDefinition in edges:
		var entry: Dictionary = {
			"id": String(edge.id),
			"coord": [edge.coord.offset_col, edge.coord.offset_row] if edge.coord != null else [],
			"neighbour_coord": [edge.neighbour_coord.offset_col, edge.neighbour_coord.offset_row] if edge.neighbour_coord != null else [],
			"edge_index": edge.edge_index,
		}
		entry["road_class" if is_road else "border_class"] = String(edge.style_id)
		result.append(entry)
	return result


static func _subregions_array(subregions: Dictionary) -> Array[Dictionary]:
	var keys: Array = subregions.keys()
	keys.sort()
	var result: Array[Dictionary] = []
	for raw_id: Variant in keys:
		result.append({"id": String(raw_id), "display_name": String(subregions[raw_id])})
	return result


static func _label_offsets_dictionary(offsets: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_id: Variant in offsets.keys():
		var offset: Vector2 = offsets[raw_id]
		result[String(raw_id)] = [offset.x, offset.y]
	return result


static func _string_name_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _validation_report(messages: Array[Dictionary]) -> String:
	var lines: PackedStringArray = ["SEETHE REGION AUTHORING VALIDATION REPORT", ""]
	for message: Dictionary in messages:
		lines.append("%s: %s" % [String(message.get("severity", "information")).to_upper(), String(message.get("message", ""))])
	return "\n".join(lines) + "\n"


static func _checksums_for_directory(directory: String) -> Dictionary:
	var result: Dictionary = {}
	for relative_path: String in _sorted_file_names(directory):
		if relative_path == "manifest.json" or relative_path == "checksums.txt":
			continue
		var absolute_file: String = directory + "/" + relative_path
		var file := FileAccess.open(absolute_file, FileAccess.READ)
		if file == null:
			continue
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(file.get_buffer(file.get_length()))
		result[relative_path] = context.finish().hex_encode()
	return result


static func _checksums_text(checksums: Dictionary) -> String:
	var keys: Array = checksums.keys()
	keys.sort()
	var lines: PackedStringArray = []
	for relative_path: Variant in keys:
		lines.append("%s  %s" % [checksums[relative_path], relative_path])
	return "\n".join(lines) + "\n"


static func _sorted_file_names(directory: String) -> Array[String]:
	var result: Array[String] = []
	_collect_files(directory, directory, result)
	result.sort()
	return result


static func _collect_files(root: String, current: String, result: Array[String]) -> void:
	var access := DirAccess.open(current)
	if access == null:
		return
	access.list_dir_begin()
	var entry: String = access.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var full_path: String = current + "/" + entry
			if access.current_is_dir():
				_collect_files(root, full_path, result)
			else:
				result.append(full_path.trim_prefix(root + "/"))
		entry = access.get_next()
	access.list_dir_end()


static func _zip_directory(directory: String, output_path: String) -> Error:
	var packer := ZIPPacker.new()
	var open_error: Error = packer.open(output_path)
	if open_error != OK:
		return open_error
	for relative_path: String in _sorted_file_names(directory):
		var file := FileAccess.open(directory + "/" + relative_path, FileAccess.READ)
		if file == null:
			packer.close()
			return ERR_FILE_CANT_READ
		var start_error: Error = packer.start_file(relative_path)
		if start_error != OK:
			packer.close()
			return start_error
		packer.write_file(file.get_buffer(file.get_length()))
		packer.close_file()
	return packer.close()


static func _write_text(path: String, content: String) -> bool:
	var directory: String = path.get_base_dir()
	if not _ensure_directory(directory):
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.close()
	return true


static func _ensure_directory(path: String) -> bool:
	var absolute: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute):
		return true
	return DirAccess.make_dir_recursive_absolute(absolute) == OK


static func _remove_directory_recursive(absolute_path: String) -> void:
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var access := DirAccess.open(absolute_path)
	if access == null:
		return
	access.list_dir_begin()
	var entry: String = access.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child: String = absolute_path.path_join(entry)
			if access.current_is_dir():
				_remove_directory_recursive(child)
			else:
				DirAccess.remove_absolute(child)
		entry = access.get_next()
	access.list_dir_end()
	DirAccess.remove_absolute(absolute_path)
