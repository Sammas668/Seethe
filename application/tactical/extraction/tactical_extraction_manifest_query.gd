class_name TacticalExtractionManifestQuery
extends RefCounted


static func build_manifest(
		state: TacticalState,
		map_definition: TacticalMapDefinition,
		setup: MissionSetupSnapshot,
		zone_id: StringName
) -> TacticalExtractionManifest:
	var manifest := TacticalExtractionManifest.new()
	manifest.zone_id = zone_id
	if state == null or map_definition == null or setup == null:
		manifest.rejection_reasons.append("Extraction data is unavailable.")
		return manifest
	manifest.source_tactical_revision = state.revision
	if state.mission_resolution_locked:
		manifest.rejection_reasons.append("Mission resolution is already in progress.")
		return manifest

	var zone: TacticalExtractionZoneDefinition = setup.extraction_zone(zone_id)
	var zone_state: TacticalExtractionZoneState = state.extraction_zone_state(zone_id)
	if zone == null or zone_state == null:
		manifest.rejection_reasons.append("The extraction zone does not exist.")
		return manifest
	if zone.permitted_faction_id != &"player":
		manifest.rejection_reasons.append(
			"The extraction zone does not permit the player faction."
		)
	if not zone_state.enabled:
		manifest.rejection_reasons.append("The extraction zone is disabled.")
	if zone_state.contested:
		manifest.rejection_reasons.append("The extraction route is currently contested.")

	manifest.required_objectives_complete = (
		TacticalMissionObjectiveQuery.required_objective_complete(
			state, map_definition
		)
	)

	_collect_standing_friendlies(state, zone, manifest)
	_collect_body_extraction(state, zone, manifest)
	_collect_items(state, zone, manifest)
	_collect_abandoned_units(state, manifest)
	_collect_captives(state, zone, manifest)
	_build_warnings(state, manifest)

	manifest.protagonist_extracted = _protagonist_is_extracted(
		state, setup, manifest
	)
	var protagonist: TacticalUnitState = state.get_unit(
		setup.protagonist_character_id
	)
	if protagonist != null and protagonist.is_dead():
		manifest.mission_outcome = MissionOutcome.CAMPAIGN_DEFEAT
		manifest.rejection_reasons.append(
			"The protagonist is dead. Campaign defeat must resolve."
		)
	elif not TacticalMissionObjectiveQuery.player_force_can_continue(state):
		manifest.mission_outcome = MissionOutcome.DEFEAT
		manifest.rejection_reasons.append(
			"No conscious player-controlled character can continue the mission."
		)
	elif (
		setup.requires_protagonist_extraction
		and not manifest.protagonist_extracted
	):
		manifest.rejection_reasons.append(
			"The protagonist must be physically extracted."
		)
	elif (
		manifest.extracted_friendly_unit_ids.is_empty()
		and manifest.extracted_friendly_body_item_ids.is_empty()
	):
		manifest.rejection_reasons.append(
			"No friendly character or body is in the extraction manifest."
		)

	manifest.extraction_is_legal = manifest.rejection_reasons.is_empty()
	if manifest.mission_outcome in [
		MissionOutcome.CAMPAIGN_DEFEAT, MissionOutcome.DEFEAT
	]:
		# A wiped force receives no unexplained automatic evacuation. Anything
		# merely lying in the zone remains on the battlefield unless an authored
		# autonomous transport system later says otherwise.
		_clear_extraction_for_defeat(state, manifest)
		_finalize_manifest(state, manifest)
		return manifest
	if manifest.extraction_is_legal:
		manifest.mission_outcome = (
			MissionOutcome.VICTORY
			if manifest.required_objectives_complete
			else MissionOutcome.WITHDRAWAL
		)
		if (
			manifest.mission_outcome == MissionOutcome.WITHDRAWAL
			and not setup.allows_withdrawal
		):
			manifest.extraction_is_legal = false
			manifest.rejection_reasons.append(
				"This mission does not permit withdrawal."
			)
	_finalize_manifest(state, manifest)
	return manifest


static func _collect_standing_friendlies(
		state: TacticalState,
		zone: TacticalExtractionZoneDefinition,
		manifest: TacticalExtractionManifest
) -> void:
	if not zone.allows_characters:
		return
	for unit: TacticalUnitState in state.get_player_units():
		if unit == null or unit.requires_body_item() or unit.is_dead():
			continue
		if zone.contains_complete_footprint(unit.grid_position, unit.footprint):
			manifest.extracted_friendly_unit_ids.append(unit.unit_id)


static func _collect_body_extraction(
		state: TacticalState,
		zone: TacticalExtractionZoneDefinition,
		manifest: TacticalExtractionManifest
) -> void:
	if not zone.allows_bodies:
		return
	var extracted_body_ids: Dictionary = {}
	var changed: bool = true
	while changed:
		changed = false
		for item: TacticalItemInstanceState in state.get_items():
			if item == null or not item.is_body() or extracted_body_ids.has(item.item_id):
				continue
			if _body_is_physically_extracted(
				state, zone, manifest, extracted_body_ids, item
			):
				extracted_body_ids[item.item_id] = true
				changed = true

	for raw_body_id: Variant in extracted_body_ids.keys():
		var body_id: StringName = StringName(raw_body_id)
		var body: TacticalItemInstanceState = state.get_item(body_id)
		var linked: TacticalUnitState = state.body_unit_for_item(body_id)
		if body == null or linked == null:
			continue
		if linked.team_id == &"player":
			manifest.extracted_friendly_body_item_ids.append(body_id)
		else:
			manifest.recovered_enemy_body_item_ids.append(body_id)


static func _body_is_physically_extracted(
		state: TacticalState,
		zone: TacticalExtractionZoneDefinition,
		manifest: TacticalExtractionManifest,
		extracted_body_ids: Dictionary,
		body: TacticalItemInstanceState
) -> bool:
	if body.location == null:
		return false
	var linked_unit: TacticalUnitState = state.body_unit_for_item(body.item_id)
	if not _enemy_body_is_eligible_for_withdrawal(linked_unit):
		return false
	var ground_cell: Vector2i = state.body_ground_cell(body)
	if ground_cell.x >= 0:
		return zone.contains_tile(ground_cell)
	if body.location.location_type != TacticalItemLocationState.LOCATION_UNIT_INVENTORY:
		return false
	var owner_id: StringName = body.location.owner_id
	if manifest.extracted_friendly_unit_ids.has(owner_id):
		return true
	var owner_body: TacticalItemInstanceState = state.body_item_for_unit(owner_id)
	return owner_body != null and extracted_body_ids.has(owner_body.item_id)


static func _enemy_body_is_eligible_for_withdrawal(
		unit: TacticalUnitState
) -> bool:
	if unit == null or unit.team_id == &"player":
		return true
	# A hostile character is never swept into extraction merely because its
	# body item is inside the zone or packed in an extracting character. Living
	# enemies must be unconscious or physically restrained. Dead enemy bodies
	# remain ordinary recoverable bodies when the player deliberately brings
	# them into the withdrawal zone.
	return unit.is_dead() or unit.is_unconscious() or unit.restrained


static func _collect_items(
		state: TacticalState,
		zone: TacticalExtractionZoneDefinition,
		manifest: TacticalExtractionManifest
) -> void:
	var extracted_owners: Dictionary = {}
	for unit_id: StringName in manifest.extracted_friendly_unit_ids:
		extracted_owners[unit_id] = true
	for body_id: StringName in manifest.extracted_friendly_body_item_ids:
		var friendly_body: TacticalItemInstanceState = state.get_item(body_id)
		if friendly_body != null:
			extracted_owners[friendly_body.linked_unit_id] = true
	for body_id: StringName in manifest.recovered_enemy_body_item_ids:
		var enemy_body: TacticalItemInstanceState = state.get_item(body_id)
		if enemy_body != null:
			extracted_owners[enemy_body.linked_unit_id] = true

	for item: TacticalItemInstanceState in state.get_items():
		if item == null or item.is_body() or item.location == null:
			continue
		if item.location.location_type == TacticalItemLocationState.LOCATION_DESTROYED:
			continue
		var extracted: bool = false
		match item.location.location_type:
			TacticalItemLocationState.LOCATION_TACTICAL_GROUND:
				extracted = zone.allows_items and zone.contains_tile(
					item.location.map_position
				)
			TacticalItemLocationState.LOCATION_TACTICAL_CONTAINER:
				extracted = zone.allows_items and zone.contains_tile(
					item.location.map_position
				)
			TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT, \
			TacticalItemLocationState.LOCATION_UNIT_INVENTORY, \
			TacticalItemLocationState.LOCATION_BODY_ATTACHMENT:
				extracted = extracted_owners.has(item.location.owner_id)
		if extracted:
			manifest.extracted_item_ids.append(item.item_id)
		else:
			manifest.abandoned_item_ids.append(item.item_id)


static func _collect_abandoned_units(
		state: TacticalState,
		manifest: TacticalExtractionManifest
) -> void:
	for unit: TacticalUnitState in state.get_player_units():
		if unit == null:
			continue
		if unit.requires_body_item():
			var body: TacticalItemInstanceState = state.body_item_for_unit(unit.unit_id)
			if (
				body != null
				and not manifest.extracted_friendly_body_item_ids.has(body.item_id)
			):
				manifest.abandoned_friendly_body_item_ids.append(body.item_id)
		elif not manifest.extracted_friendly_unit_ids.has(unit.unit_id):
			manifest.abandoned_friendly_unit_ids.append(unit.unit_id)


static func _collect_captives(
		state: TacticalState,
		zone: TacticalExtractionZoneDefinition,
		manifest: TacticalExtractionManifest
) -> void:
	for body_id: StringName in manifest.recovered_enemy_body_item_ids:
		var body: TacticalItemInstanceState = state.get_item(body_id)
		var unit: TacticalUnitState = state.body_unit_for_item(body_id)
		if body == null or unit == null or unit.is_dead():
			continue
		if zone.allows_captives and unit.restrained and unit.captive:
			manifest.captured_enemy_unit_ids.append(unit.unit_id)
		else:
			manifest.unsecured_enemy_unit_ids.append(unit.unit_id)


static func _protagonist_is_extracted(
		state: TacticalState,
		setup: MissionSetupSnapshot,
		manifest: TacticalExtractionManifest
) -> bool:
	var protagonist_id: StringName = setup.protagonist_character_id
	if protagonist_id.is_empty():
		return not setup.requires_protagonist_extraction
	if manifest.extracted_friendly_unit_ids.has(protagonist_id):
		return true
	var body: TacticalItemInstanceState = state.body_item_for_unit(protagonist_id)
	return body != null and manifest.extracted_friendly_body_item_ids.has(body.item_id)


static func _build_warnings(
		state: TacticalState,
		manifest: TacticalExtractionManifest
) -> void:
	for unit_id: StringName in manifest.abandoned_friendly_unit_ids:
		var unit: TacticalUnitState = state.get_unit(unit_id)
		if unit != null:
			manifest.warning_lines.append("%s will be left behind." % unit.display_name)
	for body_id: StringName in manifest.abandoned_friendly_body_item_ids:
		var unit: TacticalUnitState = state.body_unit_for_item(body_id)
		if unit != null:
			manifest.warning_lines.append("%s's body will be left behind." % unit.display_name)
	for unit_id: StringName in manifest.unsecured_enemy_unit_ids:
		var unit: TacticalUnitState = state.get_unit(unit_id)
		if unit != null:
			manifest.warning_lines.append(
				"%s is not restrained and will not count as a captive."
				% unit.display_name
			)
	if not manifest.abandoned_item_ids.is_empty():
		manifest.warning_lines.append(
			"%d persistent item(s) will be abandoned."
			% manifest.abandoned_item_ids.size()
		)
	if not manifest.required_objectives_complete:
		manifest.warning_lines.append(
			"The primary objective is incomplete; this will be a withdrawal."
		)


static func _clear_extraction_for_defeat(
		state: TacticalState,
		manifest: TacticalExtractionManifest
) -> void:
	for body_id: StringName in manifest.extracted_friendly_body_item_ids:
		if not manifest.abandoned_friendly_body_item_ids.has(body_id):
			manifest.abandoned_friendly_body_item_ids.append(body_id)
	for unit_id: StringName in manifest.extracted_friendly_unit_ids:
		if not manifest.abandoned_friendly_unit_ids.has(unit_id):
			manifest.abandoned_friendly_unit_ids.append(unit_id)
	for item_id: StringName in manifest.extracted_item_ids:
		if not manifest.abandoned_item_ids.has(item_id):
			manifest.abandoned_item_ids.append(item_id)
	for body_id: StringName in manifest.recovered_enemy_body_item_ids:
		var enemy: TacticalUnitState = state.body_unit_for_item(body_id)
		if enemy != null and not manifest.unsecured_enemy_unit_ids.has(enemy.unit_id):
			manifest.unsecured_enemy_unit_ids.append(enemy.unit_id)
	manifest.extracted_friendly_unit_ids.clear()
	manifest.extracted_friendly_body_item_ids.clear()
	manifest.recovered_enemy_body_item_ids.clear()
	manifest.captured_enemy_unit_ids.clear()
	manifest.extracted_item_ids.clear()
	manifest.protagonist_extracted = false
	manifest.extraction_is_legal = false
	manifest.warning_lines.clear()
	_build_warnings(state, manifest)


static func _finalize_manifest(
		state: TacticalState,
		manifest: TacticalExtractionManifest
) -> void:
	_normalize_manifest(manifest)
	var integrity_errors: Array[String] = (
		TacticalExtractionManifestValidator.validate(manifest, state)
	)
	for error: String in integrity_errors:
		if not manifest.rejection_reasons.has(error):
			manifest.rejection_reasons.append(error)
	if not integrity_errors.is_empty():
		manifest.extraction_is_legal = false


static func _normalize_manifest(manifest: TacticalExtractionManifest) -> void:
	if manifest == null:
		return
	_sort_unique_string_names(manifest.extracted_friendly_unit_ids)
	_sort_unique_string_names(manifest.extracted_friendly_body_item_ids)
	_sort_unique_string_names(manifest.captured_enemy_unit_ids)
	_sort_unique_string_names(manifest.recovered_enemy_body_item_ids)
	_sort_unique_string_names(manifest.extracted_item_ids)
	_sort_unique_string_names(manifest.abandoned_item_ids)
	_sort_unique_string_names(manifest.abandoned_friendly_unit_ids)
	_sort_unique_string_names(manifest.abandoned_friendly_body_item_ids)
	_sort_unique_string_names(manifest.unsecured_enemy_unit_ids)


static func _sort_unique_string_names(values: Array[StringName]) -> void:
	var seen: Dictionary = {}
	var normalized: Array[StringName] = []
	for value: StringName in values:
		if value.is_empty() or seen.has(value):
			continue
		seen[value] = true
		normalized.append(value)
	normalized.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	values.clear()
	values.append_array(normalized)
