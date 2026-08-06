class_name Stage51aRegionAuthoringTests
extends RefCounted


static func run() -> Array[String]:
	var failures: Array[String] = []
	var runtime: RegionMapDefinition = LifeStarterRegionFactory.create_definition()
	_expect(runtime != null, "Runtime region failed to load for authoring tests.", failures)
	if runtime == null:
		return failures
	var document := RegionAuthoringDocument.from_runtime(runtime)
	_expect(document != null and document.region != null, "Runtime region did not import into an authoring document.", failures)
	if document == null or document.region == null:
		return failures
	_expect(document.region.width == 20 and document.region.height == 15, "Authoring import changed the region dimensions.", failures)
	var snapshot: String = document.snapshot_text()
	_expect(not snapshot.is_empty(), "Authoring document did not create a deterministic snapshot.", failures)
	_expect(not document.to_dictionary().has("reference_overlay"), "Removed reference-overlay data remains in the authoring format.", failures)
	var telluria: RegionSiteDefinition = document.region.site(&"site.settlement.telluria")
	_expect(telluria != null, "Telluria is missing from the authoring document.", failures)
	if telluria != null:
		var original_size: int = telluria.footprint.size()
		var add_result: bool = document.toggle_settlement_footprint(telluria.id, 11, 7, true)
		_expect(add_result, "Authoring document could not add a settlement footprint hex.", failures)
		_expect(telluria.footprint.size() == original_size + 1, "Settlement footprint edit did not persist.", failures)
		var symbol_result: bool = document.assign_district(
			telluria.id,
			11,
			7,
			RegionSymbolCatalogue.GUILD_HOUSE
		)
		_expect(symbol_result, "Authoring document could not assign a deterministic district symbol.", failures)
		var district: RegionSiteDefinition = document.district_at_offset(11, 7)
		_expect(district != null and district.icon_id == RegionSymbolCatalogue.GUILD_HOUSE, "District symbol assignment was not deterministic.", failures)
	var first := RegionHexCoord.from_offset(0, 1)
	var second: RegionHexCoord = first.neighbours()[0]
	var road_added: bool = document.add_or_replace_edge(true, first, second, 0, RegionRoadType.LOCAL_ROAD)
	_expect(road_added, "Authoring document could not add an adjacent road edge.", failures)
	var border_added: bool = document.add_or_replace_edge(false, first, second, 0, &"subregion_border")
	_expect(border_added, "Authoring document could not add an independent border edge.", failures)
	_expect(document.remove_edge(true, first, second), "Authoring document could not remove the road edge.", failures)
	var border_still_present: bool = false
	for edge: RegionMapEdgeDefinition in document.region.all_border_edges():
		if edge.touches_offset(first.offset_col, first.offset_row) and edge.touches_offset(second.offset_col, second.offset_row):
			border_still_present = true
			break
	_expect(border_still_present, "Removing a road also removed the independent border.", failures)
	var boundary_owner := RegionHexCoord.from_offset(0, 0)
	_expect(
		document.add_or_replace_edge(true, boundary_owner, null, 3, RegionRoadType.PRIMARY_ROAD),
		"Authoring document could not add a road ending at the region boundary.",
		failures
	)
	_expect(
		document.remove_edge(true, boundary_owner, null, 3),
		"Authoring document could not remove a boundary road edge.",
		failures
	)
	var legacy_payload: Dictionary = document.to_dictionary()
	(legacy_payload["region"] as Dictionary)["routes"] = [{
		"id": "route.test.hidden",
		"route_class": "hidden_track",
		"ordered_hexes": [[15, 10], [16, 10]],
	}]
	(legacy_payload["region"] as Dictionary)["stronghold_approach_route_ids"] = ["route.test.hidden"]
	var migrated := RegionAuthoringDocument.from_dictionary(legacy_payload)
	_expect(migrated != null and not (migrated.to_dictionary()["region"] as Dictionary).has("routes"), "Legacy hidden routes were not removed during authoring migration.", failures)
	_expect(not (migrated.to_dictionary()["region"] as Dictionary).has("stronghold_approach_route_ids"), "Legacy stronghold route IDs survived migration.", failures)
	var subregion_hex: RegionHexDefinition = document.region.hex_at_offset(0, 1)
	if subregion_hex != null:
		var original_subregion: StringName = subregion_hex.subregion_id
		var replacement: StringName = &"subregion.life.north_west_telluria" if original_subregion != &"subregion.life.north_west_telluria" else &"subregion.life.telluria_proper"
		if document.region.subregions_by_id.has(replacement):
			_expect(document.paint_subregion(0, 1, replacement), "Subregion paint did not update a playable hex.", failures)
	_expect(document.restore_snapshot(snapshot), "Authoring snapshot could not be restored.", failures)
	_expect(document.region.site(&"site.settlement.telluria").footprint.size() == runtime.site(&"site.settlement.telluria").footprint.size(), "Snapshot restore did not restore the settlement footprint.", failures)
	var validation: Array[Dictionary] = RegionValidationService.validate(document)
	_expect(not validation.is_empty(), "Authoring validation returned no status messages.", failures)
	var save_path: String = "user://stage_5_1a_region_authoring_test.json"
	var recovery_path: String = RegionAuthoringSerializer.recovery_path_for(save_path)
	var save_result: OperationResult = RegionAuthoringSerializer.save_working_document(save_path, document)
	_expect(save_result.success, "Authoring working-document save failed: %s" % save_result.message, failures)
	if save_result.success:
		var load_result: OperationResult = RegionAuthoringSerializer.load_document(save_path)
		_expect(load_result.success, "Authoring document reload failed: %s" % load_result.message, failures)
		if load_result.success:
			var loaded: RegionAuthoringDocument = load_result.data as RegionAuthoringDocument
			_expect(loaded != null and loaded.region.id == document.region.id, "Reloaded authoring document changed region identity.", failures)
		var autosave_result: OperationResult = RegionAuthoringSerializer.autosave(document, save_path)
		_expect(autosave_result.success, "Authoring recovery save failed: %s" % autosave_result.message, failures)
		_expect(FileAccess.file_exists(recovery_path), "Recovery copy was not written beside the active working file.", failures)
		RegionAuthoringSerializer.discard_recovery(save_path)
		_expect(not FileAccess.file_exists(recovery_path), "Recovery copy was not removed after discard.", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	return failures


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
