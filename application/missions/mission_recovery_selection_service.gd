class_name MissionRecoverySelectionService
extends RefCounted

const DEFAULT_PERSON_WEIGHT_LB: float = 180.0

var _catalogue: ContentCatalogue
var _prison_capacity_service: PrisonCapacityService
var _captive_policy_registry := CaptivePolicyRegistry.new()


func configure(
	catalogue: ContentCatalogue,
	prison_capacity_service: PrisonCapacityService = null
) -> void:
	_catalogue = catalogue
	_prison_capacity_service = prison_capacity_service


func build_snapshot(
		envelope: MissionCommitEnvelope,
		transport_snapshot: Dictionary,
		campaign: CampaignState = null,
		_catalogue_override: ContentCatalogue = null
) -> Dictionary:
	var result: MissionResult = envelope.result if envelope != null else null
	if result == null:
		return {}
	var mandatory_ids: Dictionary = _mandatory_item_ids(result, envelope.setup)
	var optional_entries: Array[Dictionary] = []
	var mandatory_item_weight: float = 0.0
	var item_by_id: Dictionary = {}
	for entry: Dictionary in result.extracted_item_entries:
		var item := CampaignItemState.from_dictionary(entry)
		item_by_id[item.item_id] = item
		var weight: float = _item_weight(item)
		if _is_outbound_item(item, mandatory_ids):
			mandatory_ids[String(item.item_id)] = true
			mandatory_item_weight += weight
			continue
		var item_definition: ItemDefinition = _catalogue.item_definition(item.definition_id) if _catalogue != null else null
		var category: StringName = _cargo_category(item_definition)
		optional_entries.append({
			"item_id": item.item_id,
			"definition_id": item.definition_id,
			"display_name": _item_name(item),
			"quantity": item.quantity,
			"weight_lb": weight,
			"storage_space": _item_storage_space(item),
			"cargo_category": String(category),
			"special_space_requirement": item.quantity if category != &"ordinary" else 0,
			"is_unique": item_definition.has_tag(&"unique") if item_definition != null else false,
		})
	optional_entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var weight_compare: float = float(a.get("weight_lb", 0.0)) - float(b.get("weight_lb", 0.0))
			if not is_zero_approx(weight_compare):
				return weight_compare > 0.0
			return String(a.get("display_name", "")) < String(b.get("display_name", ""))
	)
	var personal_capacity: Dictionary = _personal_recovery_capacity_snapshot(
		result,
		campaign,
		item_by_id,
		envelope.setup
	)
	var uses_dedicated_transport: bool = _uses_dedicated_transport(transport_snapshot)
	var transport_cargo: float = float(transport_snapshot.get(
		"total_cargo_capacity_lb",
		transport_snapshot.get("cargo_capacity_lb", 0.0)
	))
	var captive_entries: Array[Dictionary] = []
	var captive_cell_total: int = 0
	for captive_result: MissionCaptiveResult in result.get_captive_results():
		var policy: CaptivePolicyDefinition = _captive_policy_registry.policy_for(
			captive_result.source_definition_id
		)
		var cell_cost: int = maxi(1, policy.cell_cost)
		captive_cell_total += cell_cost
		captive_entries.append({
			"captive_id": captive_result.character_id,
			"display_name": captive_result.display_name,
			"source_definition_id": captive_result.source_definition_id,
			"faction_id": captive_result.faction_id,
			"current_hp": captive_result.current_hp,
			"maximum_hp": captive_result.maximum_hp,
			"nonlethal_damage": captive_result.nonlethal_damage,
			"condition": String(captive_result.condition_at_extraction),
			"cell_cost": cell_cost,
			"ransom_allowed": policy.ransom_allowed,
			"ransom_value": policy.ransom_value,
			"release_notoriety_delta": policy.release_notoriety_delta,
		})
	var captive_count: int = captive_entries.size()
	var dedicated_captive_capacity: int = int(transport_snapshot.get("total_captive_capacity", 0))
	var manual_captives: int = maxi(0, captive_count - dedicated_captive_capacity)
	var mandatory_unallocated_item_weight: float = 0.0
	var personally_accounted_ids: Dictionary = personal_capacity.get("accounted_item_ids", {}) as Dictionary
	for raw_mandatory_id: Variant in mandatory_ids.keys():
		var mandatory_id := StringName(raw_mandatory_id)
		if personally_accounted_ids.has(mandatory_id):
			continue
		var mandatory_item: CampaignItemState = item_by_id.get(mandatory_id) as CampaignItemState
		if mandatory_item != null:
			mandatory_unallocated_item_weight += _item_weight(mandatory_item)
	# A dedicated transport already reserves passenger space for the deployed
	# squad and their personal mission equipment. Its cargo rating is therefore
	# the complete ordinary recovery allowance: survivor carrying limits are not
	# added, and recovered squad casualties do not also consume cargo. Walking is
	# the inverse case and continues to use the conscious survivors' remaining
	# maximum loads, with casualties carried manually.
	var recovered_squad_casualties: int = int(personal_capacity.get("carried_casualty_count", 0))
	var manual_casualties: int = 0 if uses_dedicated_transport else recovered_squad_casualties
	var mandatory_manual_burden: float = (
		float(manual_casualties + manual_captives)
		* DEFAULT_PERSON_WEIGHT_LB
		+ mandatory_unallocated_item_weight
	)
	var personal_recovery_capacity: float = (
		0.0
		if uses_dedicated_transport
		else float(personal_capacity.get("remaining_carry_capacity_lb", 0.0))
	)
	var gross_capacity: float = transport_cargo if uses_dedicated_transport else personal_recovery_capacity
	var optional_capacity: float = maxf(0.0, gross_capacity - mandatory_manual_burden)
	var prison_snapshot: Dictionary = (
		_prison_capacity_service.capacity_snapshot(campaign)
		if _prison_capacity_service != null and campaign != null
		else {
			"total_capacity": 0,
			"held_cells": 0,
			"incoming_cells": 0,
			"available_capacity": 0,
			"has_prison": false,
		}
	)
	return {
		"transport": transport_snapshot.duplicate(true),
		"uses_dedicated_transport": uses_dedicated_transport,
		"recovery_capacity_source": "transport" if uses_dedicated_transport else "survivors",
		"transport_cargo_capacity_lb": transport_cargo,
		"personal_remaining_carry_capacity_lb": personal_recovery_capacity,
		"gross_recovery_capacity_lb": gross_capacity,
		"mandatory_manual_burden_lb": mandatory_manual_burden,
		"mandatory_unallocated_item_weight_lb": mandatory_unallocated_item_weight,
		"cargo_capacity_lb": optional_capacity,
		"mandatory_item_weight_lb": mandatory_item_weight,
		"optional_entries": optional_entries,
		"mandatory_item_count": mandatory_ids.size(),
		"mandatory_item_ids": mandatory_ids.keys(),
		"captive_count": captive_count,
		"captive_entries": captive_entries,
		"captive_cell_total": captive_cell_total,
		"prison": prison_snapshot,
		"prison_available_capacity": int(prison_snapshot.get("available_capacity", 0)),
		"dedicated_captive_capacity": dedicated_captive_capacity,
		"manual_captive_count": manual_captives,
		"carried_casualty_count": recovered_squad_casualties,
		"manual_casualty_count": manual_casualties,
		"passenger_supported_casualty_count": (
			recovered_squad_casualties if uses_dedicated_transport else 0
		),
		"contributing_survivors": personal_capacity.get("contributors", []),
		"special_capacity": {
			"cage": int(transport_snapshot.get("total_cage_anchor_capacity", 0)),
			"monster": int(transport_snapshot.get("total_monster_capacity", 0)),
			"siege": int(transport_snapshot.get("total_siege_anchor_capacity", 0)),
			"oversized": int(transport_snapshot.get("total_oversized_cargo_capacity", 0)),
		},
	}


func filter_envelope(
		envelope: MissionCommitEnvelope,
		selected_optional_item_ids: Array[StringName],
		selected_captive_ids: Array[StringName] = []
) -> OperationResult:
	if envelope == null or envelope.result == null:
		return OperationResult.fail(&"mission_recovery_missing", "No tactical result is awaiting recovery selection.")
	var filtered_result := MissionResult.from_dictionary(envelope.result.to_dictionary())
	var selected_captives: Dictionary = {}
	for captive_id: StringName in selected_captive_ids:
		if not captive_id.is_empty():
			selected_captives[String(captive_id)] = true
	for raw_captive_id: Variant in filtered_result.captive_results_by_character_id.keys():
		if not selected_captives.has(String(raw_captive_id)):
			filtered_result.captive_results_by_character_id.erase(raw_captive_id)
	filtered_result.mission_statistics["captives_taken"] = filtered_result.get_captive_results().size()
	var mandatory_ids: Dictionary = _mandatory_item_ids(filtered_result, envelope.setup)
	var selected: Dictionary = {}
	for item_id: StringName in selected_optional_item_ids:
		if not item_id.is_empty():
			selected[String(item_id)] = true
	var kept_entries: Array[Dictionary] = []
	var dropped_ids: Dictionary = {}
	for entry: Dictionary in filtered_result.extracted_item_entries:
		var item := CampaignItemState.from_dictionary(entry)
		var item_id: StringName = item.item_id if item != null else StringName(entry.get("item_id", ""))
		if _is_outbound_item(item, mandatory_ids) or selected.has(String(item_id)):
			kept_entries.append(entry.duplicate(true))
		else:
			dropped_ids[item_id] = true
			if not filtered_result.abandoned_item_ids.has(item_id):
				filtered_result.abandoned_item_ids.append(item_id)
	filtered_result.extracted_item_entries = kept_entries
	for character_result: MissionCharacterResult in filtered_result.get_character_results():
		character_result.equipment_item_ids = _without_ids(character_result.equipment_item_ids, dropped_ids)
		character_result.loot_item_ids = _without_ids(character_result.loot_item_ids, dropped_ids)
	for captive_result: MissionCaptiveResult in filtered_result.get_captive_results():
		captive_result.equipment_item_ids = _without_ids(captive_result.equipment_item_ids, dropped_ids)
	var kept_provenance_ids: Array[StringName] = []
	for provenance_id: StringName in filtered_result.generated_item_provenance_ids:
		var provenance: TacticalGeneratedItemProvenance = (
			envelope.authority_snapshot.provenance(provenance_id)
			if envelope.authority_snapshot != null
			else null
		)
		if provenance == null or not dropped_ids.has(provenance.generated_item_id):
			kept_provenance_ids.append(provenance_id)
	filtered_result.generated_item_provenance_ids = kept_provenance_ids
	filtered_result.mission_statistics["items_extracted"] = filtered_result.extracted_item_entries.size()
	filtered_result.mission_statistics["items_abandoned"] = filtered_result.abandoned_item_ids.size()
	# Recovery selection is part of the immutable mission result, not a later
	# side transaction. Captive-dependent contribution and XP lines are rebuilt
	# before the filtered envelope is saved or committed.
	MissionCharacterOutcomeService.reconcile_after_recovery_selection(
		filtered_result,
		envelope.setup
	)
	MissionExperienceAwardService.apply_awards(filtered_result, envelope.setup)
	MissionCharacterOutcomeService.refresh_history(filtered_result, envelope.setup)
	var filtered_envelope := MissionCommitEnvelope.new(
		envelope.setup,
		filtered_result,
		envelope.authority_snapshot
	)
	var errors: Array[String] = filtered_envelope.validate_envelope()
	errors.append_array(filtered_result.validate_result())
	errors.append_array(
		MissionExperienceAwardService.validate_awards(
			filtered_result,
			envelope.setup
		)
	)
	if not errors.is_empty():
		return OperationResult.fail(&"mission_recovery_envelope_invalid", errors[0])
	return OperationResult.ok(filtered_envelope, "Recovery selection applied to the pending mission result.")


func selected_weight(snapshot: Dictionary, selected_item_ids: Array[StringName]) -> float:
	var selected: Dictionary = {}
	for item_id: StringName in selected_item_ids:
		selected[String(item_id)] = true
	var total: float = 0.0
	for raw_entry: Variant in snapshot.get("optional_entries", []):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		if selected.has(String(entry.get("item_id", ""))):
			total += float(entry.get("weight_lb", 0.0))
	return total


func selected_special_usage(snapshot: Dictionary, selected_item_ids: Array[StringName]) -> Dictionary:
	var selected: Dictionary = {}
	for item_id: StringName in selected_item_ids:
		selected[String(item_id)] = true
	var usage: Dictionary = {
		"cage": 0,
		"monster": 0,
		"siege": 0,
		"oversized": 0,
	}
	for raw_entry: Variant in snapshot.get("optional_entries", []):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		if not selected.has(String(entry.get("item_id", ""))):
			continue
		var category := StringName(entry.get("cargo_category", "ordinary"))
		if usage.has(category):
			usage[category] = int(usage.get(category, 0)) + int(entry.get("special_space_requirement", 0))
	return usage


func validate_selection(
		snapshot: Dictionary,
		selected_optional_item_ids: Array[StringName],
		selected_captive_ids: Array[StringName] = []
) -> OperationResult:
	var selected_captive_lookup: Dictionary = {}
	for captive_id: StringName in selected_captive_ids:
		if not captive_id.is_empty():
			selected_captive_lookup[String(captive_id)] = true
	var selected_captive_count: int = 0
	var selected_captive_cells: int = 0
	for raw_entry: Variant in snapshot.get("captive_entries", []):
		if not raw_entry is Dictionary:
			continue
		var captive_entry: Dictionary = raw_entry as Dictionary
		if selected_captive_lookup.has(String(captive_entry.get("captive_id", ""))):
			selected_captive_count += 1
			selected_captive_cells += maxi(1, int(captive_entry.get("cell_cost", 1)))
	var prison: Dictionary = snapshot.get("prison", {}) as Dictionary
	var available_cells: int = int(prison.get("available_capacity", 0))
	if selected_captive_cells > 0 and not bool(prison.get("has_prison", false)):
		return OperationResult.fail(
			&"prison_missing",
			"No constructed Prison is available for the selected captive%s."
			% ("" if selected_captive_count == 1 else "s")
		)
	if selected_captive_cells > available_cells:
		return OperationResult.fail(
			&"prison_capacity_exceeded",
			"Selected captives require %d Prison cells but only %d will be available."
			% [selected_captive_cells, available_cells]
		)
	var dedicated_captive_capacity: int = int(snapshot.get("dedicated_captive_capacity", 0))
	var manual_captives: int = maxi(0, selected_captive_count - dedicated_captive_capacity)
	var gross_capacity: float = float(snapshot.get("gross_recovery_capacity_lb", 0.0))
	var base_mandatory_burden: float = float(snapshot.get("mandatory_unallocated_item_weight_lb", 0.0))
	base_mandatory_burden += float(int(snapshot.get(
		"manual_casualty_count",
		snapshot.get("carried_casualty_count", 0)
	))) * DEFAULT_PERSON_WEIGHT_LB
	var capacity: float = maxf(0.0, gross_capacity - base_mandatory_burden - float(manual_captives) * DEFAULT_PERSON_WEIGHT_LB)
	var selected_cargo_weight: float = selected_weight(snapshot, selected_optional_item_ids)
	if selected_cargo_weight > capacity + 0.001:
		var uses_dedicated_transport: bool = bool(snapshot.get("uses_dedicated_transport", false))
		return OperationResult.fail(
			&"mission_recovery_over_capacity",
			(
				"Selected recovered cargo weighs %.1f lb but only %.1f lb remains in the assigned transport after mandatory cargo burdens."
				if uses_dedicated_transport
				else "Selected recovered cargo weighs %.1f lb but only %.1f lb remains after survivor carrying capacity and mandatory burdens."
			)
			% [selected_cargo_weight, capacity]
		)
	var usage: Dictionary = selected_special_usage(snapshot, selected_optional_item_ids)
	var capacity_by_category: Dictionary = snapshot.get("special_capacity", {}) as Dictionary
	# Monsters and siege engines require authored specialist support. Cages and
	# oversized furniture may instead use the ordinary recovery allowance when
	# their normal item weight fits. That allowance comes from survivor maximum
	# load while Walking, or solely from dedicated cargo when transport is used.
	for category: StringName in [&"monster", &"siege"]:
		var used: int = int(usage.get(category, 0))
		var maximum: int = int(capacity_by_category.get(category, 0))
		if used > maximum:
			return OperationResult.fail(
				&"mission_recovery_special_capacity",
				"Selected %s cargo requires %d specialist space but the assigned transport supports %d."
				% [String(category).replace("_", " "), used, maximum]
			)
	var manual_special_usage: Dictionary = {}
	for category: StringName in [&"cage", &"oversized"]:
		manual_special_usage[category] = maxi(
			0,
			int(usage.get(category, 0)) - int(capacity_by_category.get(category, 0))
		)
	return OperationResult.ok({
		"selected_weight_lb": selected_cargo_weight,
		"effective_cargo_capacity_lb": capacity,
		"selected_captive_count": selected_captive_count,
		"selected_captive_cells": selected_captive_cells,
		"manual_captive_count": manual_captives,
		"special_usage": usage,
		"manual_special_usage": manual_special_usage,
	}, "Recovery selection fits transport, carrying and Prison capacity.")


func _uses_dedicated_transport(transport_snapshot: Dictionary) -> bool:
	if transport_snapshot.is_empty():
		return false
	if transport_snapshot.has("is_walking"):
		return not bool(transport_snapshot.get("is_walking", false))
	var definition_id := StringName(transport_snapshot.get(
		"id",
		transport_snapshot.get("transport_definition_id", "")
	))
	if definition_id == &"transport.walking":
		return false
	# Current snapshots identify an assigned asset explicitly. The definition-ID
	# fallback preserves the same rule for legacy pending-recovery snapshots.
	return (
		int(transport_snapshot.get("assigned_count", 0)) > 0
		or not String(transport_snapshot.get("transport_asset_id", "")).is_empty()
		or not definition_id.is_empty()
	)


func _personal_recovery_capacity_snapshot(
		result: MissionResult,
		campaign: CampaignState,
		item_by_id: Dictionary,
		setup: MissionSetupSnapshot = null
) -> Dictionary:
	var remaining_total: float = 0.0
	var casualty_count: int = 0
	var contributors: Array[Dictionary] = []
	var accounted_item_ids: Dictionary = {}
	if _catalogue == null or (campaign == null and setup == null):
		return {
			"remaining_carry_capacity_lb": 0.0,
			"carried_casualty_count": 0,
			"contributors": contributors,
			"accounted_item_ids": accounted_item_ids,
		}
	var resolution_service := CharacterResolutionService.new()
	resolution_service.configure(_catalogue)
	# Recovery is post-mission hauling, not normal combat movement. Every conscious
	# extracting survivor may contribute unused capacity up to their resolved
	# maximum carried load. Medium and heavy encumbrance are therefore legal on the
	# return journey; only exceeding maximum load is forbidden. Outbound equipment
	# already consumes that allowance. Newly stolen items listed in loot_item_ids
	# remain optional cargo and are charged exactly once when selected.
	var mandatory_origin_ids: Dictionary = _mandatory_item_ids(result, setup)
	for character_result: MissionCharacterResult in result.get_character_results():
		if not character_result.was_deployed or not character_result.extracted:
			continue
		if character_result.is_dead_outcome():
			if character_result.body_recovered:
				casualty_count += 1
			continue
		if not character_result.survived:
			continue
		var conscious: bool = (
			character_result.current_hp > 0
			and character_result.nonlethal_damage < character_result.current_hp
		)
		if not conscious:
			casualty_count += 1
			continue
		# Use the immutable deployed character/loadout first. The live campaign can
		# legitimately have changed presentation state while the result is pending,
		# but the mission setup is the authoritative source for who departed and
		# what their resolved carrying limits were.
		var character: PersistentCharacterState = (
			setup.get_character(character_result.character_id)
			if setup != null
			else null
		)
		var resolution_items: Array = (
			setup.items_for_character(character_result.character_id)
			if setup != null and character != null
			else []
		)
		if character == null and campaign != null:
			character = campaign.get_character(character_result.character_id)
			if character != null:
				resolution_items = campaign.items_for_character(character.character_id)
		if character == null:
			continue
		var resolved: ResolvedCharacterSnapshot = resolution_service.resolve_character(
			character,
			[],
			resolution_items
		)
		var maximum_load: float = float(resolved.stat_value(&"maximum_weight_lb", 0))
		var light_limit: float = float(resolved.stat_value(&"light_load_max_lb", 0))
		if maximum_load <= 0.0:
			var template: CharacterTemplateDefinition = _catalogue.character_template(
				character.template_id
			)
			if template != null:
				maximum_load = maxf(0.0, template.maximum_weight_lb)
				if light_limit <= 0.0:
					light_limit = floor(maximum_load / 3.0)
		var mandatory_carried: float = 0.0
		for item_id: StringName in character_result.equipment_item_ids:
			var item: CampaignItemState = item_by_id.get(item_id) as CampaignItemState
			if item == null or not _is_outbound_item(item, mandatory_origin_ids):
				continue
			mandatory_carried += _item_weight(item)
			accounted_item_ids[item_id] = true
		var remaining: float = maxf(0.0, maximum_load - mandatory_carried)
		remaining_total += remaining
		contributors.append({
			"character_id": String(character.character_id),
			"display_name": character.display_name,
			"maximum_load_lb": maximum_load,
			"light_load_limit_lb": light_limit,
			"mandatory_carried_lb": mandatory_carried,
			"remaining_lb": remaining,
		})
	return {
		"remaining_carry_capacity_lb": remaining_total,
		"carried_casualty_count": casualty_count,
		"contributors": contributors,
		"accounted_item_ids": accounted_item_ids,
	}


func _mandatory_item_ids(
		result: MissionResult,
		setup: MissionSetupSnapshot = null
) -> Dictionary:
	# All keys in this set are normalized Strings. Godot JSON round trips can
	# deserialize Dictionary keys as String even when the live mission used
	# StringName. Mixing the two key types made exact outbound items fail the
	# mandatory check and appear as optional recovered cargo.
	var mandatory: Dictionary = {}

	# The immutable player deployment loadout is the primary authority. Only
	# items owned by characters in the player unit order count as outbound;
	# authored enemy equipment and mission-ground loot remain optional.
	if setup != null:
		for character_id: StringName in setup.player_unit_order():
			for setup_item: CampaignItemState in setup.items_for_character(character_id):
				if setup_item != null and not setup_item.item_id.is_empty():
					mandatory[String(setup_item.item_id)] = true

	# Every recorded deployment-item outcome also identifies an outbound item.
	# Include the key regardless of outcome. Consumed/lost items are absent from
	# extracted_item_entries, while any surviving entry with the same exact ID
	# must return automatically rather than becoming selectable loot.
	for raw_item_id: Variant in result.item_outcomes_by_id.keys():
		var item_id_text: String = String(raw_item_id)
		if not item_id_text.is_empty():
			mandatory[item_id_text] = true

	# Character manifests cover legacy/interrupted results. A carried item is
	# automatic equipment unless the same character result explicitly classed it
	# as newly acquired loot.
	for character_result: MissionCharacterResult in result.get_character_results():
		var loot_ids: Dictionary = {}
		for loot_id: StringName in character_result.loot_item_ids:
			loot_ids[String(loot_id)] = true
		for item_id: StringName in character_result.equipment_item_ids:
			var item_id_text: String = String(item_id)
			if not item_id_text.is_empty() and not loot_ids.has(item_id_text):
				mandatory[item_id_text] = true

	# Restraints already committed to a recovered captive are required extraction
	# equipment and are never presented as optional loot.
	for captive: MissionCaptiveResult in result.get_captive_results():
		if not captive.restraint_item_id.is_empty():
			mandatory[String(captive.restraint_item_id)] = true
	return mandatory


func _is_outbound_item(
		item: CampaignItemState,
		mandatory_origin_ids: Dictionary
) -> bool:
	if item == null:
		return false
	if mandatory_origin_ids.has(String(item.item_id)):
		return true
	var origin_item_id: String = String(item.persistent_modifiers.get(
		TacticalCharacterDeploymentService.MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY,
		""
	))
	if not origin_item_id.is_empty() and mandatory_origin_ids.has(origin_item_id):
		return true
	# Compatibility for pending recovery files produced before lineage markers
	# were added. Tactical restraint splitting uses the original item ID as the
	# prefix of the attached exact item. Recognise only explicit split suffixes so
	# unrelated mission loot of the same definition is never hidden.
	var item_id_text: String = String(item.item_id)
	for raw_origin_id: Variant in mandatory_origin_ids.keys():
		var origin_text: String = String(raw_origin_id)
		if (
			item_id_text.begins_with("%s.attached." % origin_text)
			or item_id_text.begins_with("%s.split." % origin_text)
		):
			return true
	return false


func _without_ids(values: Array[StringName], removed: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: StringName in values:
		if not removed.has(value):
			result.append(value)
	return result


func _cargo_category(definition: ItemDefinition) -> StringName:
	if definition == null:
		return &"ordinary"
	if definition.has_tag(&"monster"):
		return &"monster"
	if definition.has_tag(&"siege") or definition.has_tag(&"siege_equipment"):
		return &"siege"
	if definition.has_tag(&"cage"):
		return &"cage"
	if definition.has_tag(&"oversized") or definition.has_tag(&"furniture"):
		return &"oversized"
	return &"ordinary"


func _item_weight(item: CampaignItemState) -> float:
	if item == null or _catalogue == null:
		return 0.0
	var definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
	return definition.weight_lb * float(item.quantity) if definition != null else 0.0


func _item_storage_space(item: CampaignItemState) -> int:
	if item == null or _catalogue == null:
		return 0
	var definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
	return definition.storage_space_for_quantity(item.quantity) if definition != null else 0


func _item_name(item: CampaignItemState) -> String:
	if item == null:
		return "Unknown item"
	var definition: ItemDefinition = _catalogue.item_definition(item.definition_id) if _catalogue != null else null
	return definition.display_name if definition != null else String(item.definition_id).replace("item.", "").replace("_", " ").capitalize()
