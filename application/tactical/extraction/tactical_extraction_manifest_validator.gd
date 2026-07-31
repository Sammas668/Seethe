class_name TacticalExtractionManifestValidator
extends RefCounted


static func validate(
		manifest: TacticalExtractionManifest,
		state: TacticalState
) -> Array[String]:
	var errors: Array[String] = []
	if manifest == null:
		errors.append("Extraction manifest is missing.")
		return errors
	if state == null:
		errors.append("Extraction manifest validation requires TacticalState.")
		return errors
	if manifest.source_tactical_revision != state.revision:
		errors.append(
			"Extraction manifest revision %d does not match tactical revision %d."
			% [manifest.source_tactical_revision, state.revision]
		)

	_validate_unique_ids(
		manifest.extracted_friendly_unit_ids,
		"extracted friendly unit",
		errors
	)
	_validate_unique_ids(
		manifest.extracted_friendly_body_item_ids,
		"extracted friendly body",
		errors
	)
	_validate_unique_ids(
		manifest.recovered_enemy_body_item_ids,
		"recovered enemy body",
		errors
	)
	_validate_unique_ids(
		manifest.captured_enemy_unit_ids,
		"captured enemy",
		errors
	)
	_validate_unique_ids(manifest.extracted_item_ids, "extracted item", errors)
	_validate_unique_ids(manifest.abandoned_item_ids, "abandoned item", errors)
	_validate_unique_ids(
		manifest.abandoned_friendly_unit_ids,
		"abandoned friendly unit",
		errors
	)
	_validate_unique_ids(
		manifest.abandoned_friendly_body_item_ids,
		"abandoned friendly body",
		errors
	)

	_validate_no_overlap(
		manifest.extracted_item_ids,
		manifest.abandoned_item_ids,
		"item",
		errors
	)
	_validate_no_overlap(
		manifest.extracted_friendly_unit_ids,
		manifest.abandoned_friendly_unit_ids,
		"friendly unit",
		errors
	)
	_validate_no_overlap(
		manifest.extracted_friendly_body_item_ids,
		manifest.abandoned_friendly_body_item_ids,
		"friendly body",
		errors
	)

	_validate_friendly_partition(manifest, state, errors)
	_validate_item_partition(manifest, state, errors)
	_validate_enemy_recovery(manifest, state, errors)
	_validate_defeat_recovery(manifest, errors)
	return errors


static func _validate_friendly_partition(
		manifest: TacticalExtractionManifest,
		state: TacticalState,
		errors: Array[String]
) -> void:
	for unit: TacticalUnitState in state.get_player_units():
		if unit == null:
			continue
		if unit.requires_body_item():
			var body: TacticalItemInstanceState = state.body_item_for_unit(unit.unit_id)
			if body == null:
				errors.append(
					"Downed friendly %s has no body item in the extraction manifest."
					% unit.unit_id
				)
				continue
			var body_outcomes: int = int(
				manifest.extracted_friendly_body_item_ids.has(body.item_id)
			) + int(
				manifest.abandoned_friendly_body_item_ids.has(body.item_id)
			)
			if body_outcomes != 1:
				errors.append(
					"Friendly body %s must have exactly one extracted or abandoned outcome."
					% body.item_id
				)
			continue
		var standing_outcomes: int = int(
			manifest.extracted_friendly_unit_ids.has(unit.unit_id)
		) + int(
			manifest.abandoned_friendly_unit_ids.has(unit.unit_id)
		)
		if standing_outcomes != 1:
			errors.append(
				"Friendly unit %s must have exactly one extracted or abandoned outcome."
				% unit.unit_id
			)


static func _validate_item_partition(
		manifest: TacticalExtractionManifest,
		state: TacticalState,
		errors: Array[String]
) -> void:
	for item: TacticalItemInstanceState in state.get_items():
		if item == null or item.is_body() or item.location == null:
			continue
		if (
			item.location.location_type
			== TacticalItemLocationState.LOCATION_DESTROYED
		):
			continue
		var outcomes: int = int(manifest.extracted_item_ids.has(item.item_id)) + int(
			manifest.abandoned_item_ids.has(item.item_id)
		)
		if outcomes != 1:
			errors.append(
				"Tactical item %s must have exactly one extracted or abandoned outcome."
				% item.item_id
			)


static func _validate_enemy_recovery(
		manifest: TacticalExtractionManifest,
		state: TacticalState,
		errors: Array[String]
) -> void:
	for body_id: StringName in manifest.recovered_enemy_body_item_ids:
		var unit: TacticalUnitState = state.body_unit_for_item(body_id)
		if unit == null:
			errors.append("Recovered enemy body %s has no linked unit." % body_id)
			continue
		if not unit.is_dead() and not unit.is_unconscious() and not unit.restrained:
			errors.append(
				"Conscious unrestrained enemy %s cannot be recovered."
				% unit.unit_id
			)

	for unit_id: StringName in manifest.captured_enemy_unit_ids:
		var captive: TacticalUnitState = state.get_unit(unit_id)
		if captive == null:
			errors.append("Captured enemy %s is missing." % unit_id)
			continue
		if captive.is_dead() or not captive.restrained or not captive.captive:
			errors.append(
				"Captured enemy %s must be living, Restrained and marked Captive."
				% unit_id
			)
		var body: TacticalItemInstanceState = state.body_item_for_unit(unit_id)
		if (
			body == null
			or not manifest.recovered_enemy_body_item_ids.has(body.item_id)
		):
			errors.append(
				"Captured enemy %s has no physically recovered body item."
				% unit_id
			)


static func _validate_defeat_recovery(
		manifest: TacticalExtractionManifest,
		errors: Array[String]
) -> void:
	if manifest.mission_outcome not in [
		MissionOutcome.DEFEAT,
		MissionOutcome.CAMPAIGN_DEFEAT,
	]:
		return
	if (
		not manifest.extracted_friendly_unit_ids.is_empty()
		or not manifest.extracted_friendly_body_item_ids.is_empty()
		or not manifest.recovered_enemy_body_item_ids.is_empty()
		or not manifest.captured_enemy_unit_ids.is_empty()
		or not manifest.extracted_item_ids.is_empty()
	):
		errors.append("Defeat manifests cannot recover characters, bodies, captives or items.")


static func _validate_unique_ids(
		values: Array[StringName],
		label: String,
		errors: Array[String]
) -> void:
	var seen: Dictionary = {}
	for value: StringName in values:
		if value.is_empty():
			errors.append("Extraction manifest contains an empty %s ID." % label)
		elif seen.has(value):
			errors.append("Extraction manifest duplicates %s %s." % [label, value])
		else:
			seen[value] = true


static func _validate_no_overlap(
		extracted: Array[StringName],
		abandoned: Array[StringName],
		label: String,
		errors: Array[String]
) -> void:
	var extracted_ids: Dictionary = {}
	for value: StringName in extracted:
		extracted_ids[value] = true
	for value: StringName in abandoned:
		if extracted_ids.has(value):
			errors.append(
				"Extraction manifest marks %s %s as both extracted and abandoned."
				% [label, value]
			)
