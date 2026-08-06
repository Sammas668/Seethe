class_name LoadoutService
extends RefCounted

const StrategicReservationServiceScript = preload(
	"res://application/inventory/strategic_reservation_service.gd"
)

var _catalogue: ContentCatalogue
var _equipment_service: StrategicEquipmentService
var _reservation_service: StrategicReservationServiceScript
var _inventory_service: InventoryService


func configure(
		catalogue: ContentCatalogue,
		equipment_service: StrategicEquipmentService,
		reservation_service: StrategicReservationServiceScript = null,
		inventory_service: InventoryService = null
) -> void:
	_catalogue = catalogue
	_equipment_service = equipment_service
	_reservation_service = reservation_service
	_inventory_service = inventory_service


func ensure_authored_templates(campaign: CampaignState) -> bool:
	if campaign == null or _catalogue == null:
		return false
	var changed: bool = false
	for character: PersistentCharacterState in campaign.get_characters():
		var template: CharacterTemplateDefinition = _catalogue.character_template(character.template_id)
		if template == null or template.default_loadout_entries.is_empty():
			continue
		var authored_id := StringName("loadout.authored.%s.standard" % String(template.id))
		if campaign.get_loadout_template(authored_id) == null:
			var authored := _template_from_default_loadout(template, authored_id)
			campaign.loadout_templates_by_id[authored.template_id] = authored
			changed = true
		var troop_key := StringName(template.troop_type.to_snake_case())
		if StringName(campaign.default_loadout_template_by_troop_type.get(troop_key, &"")).is_empty():
			campaign.default_loadout_template_by_troop_type[troop_key] = authored_id
			changed = true
		if character.preferred_loadout_template_id.is_empty():
			character.preferred_loadout_template_id = authored_id
			character.revision += 1
			changed = true
	if changed:
		campaign.revision += 1
	return changed


func compatible_templates(
		campaign: CampaignState,
		character_id: StringName
) -> Array[LoadoutTemplateState]:
	var result: Array[LoadoutTemplateState] = []
	if campaign == null or _catalogue == null:
		return result
	var character: PersistentCharacterState = campaign.get_character(character_id)
	if character == null:
		return result
	var character_template: CharacterTemplateDefinition = _catalogue.character_template(character.template_id)
	for loadout_template: LoadoutTemplateState in campaign.get_loadout_templates():
		if loadout_template.is_compatible_with(character_template):
			result.append(loadout_template)
	return result


func capture_current_loadout(
		campaign: CampaignState,
		character_id: StringName,
		display_name: String,
		template_id: StringName = &"",
		is_authored: bool = false
) -> LoadoutTemplateState:
	if campaign == null or _catalogue == null:
		return null
	var character: PersistentCharacterState = campaign.get_character(character_id)
	if character == null:
		return null
	var character_template: CharacterTemplateDefinition = _catalogue.character_template(character.template_id)
	var result := LoadoutTemplateState.new()
	result.template_id = template_id if not template_id.is_empty() else campaign.next_loadout_template_id()
	result.display_name = display_name.strip_edges() if not display_name.strip_edges().is_empty() else "%s Loadout" % character.display_name
	result.description = "Saved from %s's current equipment." % character.display_name
	result.is_authored = is_authored
	result.source_definition_id = character.template_id if is_authored else &""
	if character_template != null:
		result.allowed_troop_type_ids.append(StringName(character_template.troop_type.to_snake_case()))
	for raw_item: Variant in campaign.items_for_character(character_id):
		var item: CampaignItemState = raw_item as CampaignItemState
		if item == null or item.location == null:
			continue
		var rule := LoadoutItemRule.new()
		rule.rule_id = StringName("rule.%s" % String(item.item_id))
		rule.item_definition_id = item.definition_id
		rule.quantity = item.quantity
		rule.preferred_container_id = item.location.container_id
		rule.preferred_grid_position = item.location.grid_position
		rule.fixed_position = item.location.container_id in [
			CampaignItemLocationState.CONTAINER_BELT,
			CampaignItemLocationState.CONTAINER_BACKPACK,
		]
		rule.preferred_is_rotated = item.location.is_rotated
		rule.allow_rotation = true
		rule.required = true
		rule.allow_substitution = true
		result.rules.append(rule)
	return result


func replenish_preferred_loadout_candidate(
		campaign: CampaignState,
		character_id: StringName,
		desired_loadout_entries: Array = []
) -> OperationResult:
	if campaign == null or _catalogue == null or _equipment_service == null:
		return OperationResult.fail(
			&"loadout_replenishment_unavailable",
			"Loadout replenishment services are unavailable."
		)
	var character: PersistentCharacterState = campaign.get_character(character_id)
	if character == null or character.is_dead:
		return OperationResult.no_change([], "No living returning character requires replenishment.")
	var ordered_rules: Array[LoadoutItemRule] = []
	if not desired_loadout_entries.is_empty():
		ordered_rules = _loadout_rules_from_snapshot(desired_loadout_entries)
	else:
		var template_id: StringName = character.preferred_loadout_template_id
		var template: LoadoutTemplateState = campaign.get_loadout_template(template_id)
		if template == null:
			return OperationResult.no_change([], "The character has no saved loadout to replenish.")
		ordered_rules = template.rules.duplicate()
	if ordered_rules.is_empty():
		return OperationResult.no_change([], "The returning character had no desired equipment plan.")
	var replenished: Array[Dictionary] = []
	var missing: Array[Dictionary] = []
	var claimed_character_items: Dictionary = {}
	ordered_rules.sort_custom(
		func(a: LoadoutItemRule, b: LoadoutItemRule) -> bool:
			return _container_priority(a.preferred_container_id) < _container_priority(b.preferred_container_id)
	)
	for rule: LoadoutItemRule in ordered_rules:
		if rule == null:
			continue
		var current_item: CampaignItemState = _current_item_for_replenishment_rule(
			campaign,
			character_id,
			rule,
			claimed_character_items
		)
		var current_quantity: int = current_item.quantity if current_item != null else 0
		if current_item != null:
			claimed_character_items[current_item.item_id] = true
		if current_quantity >= rule.quantity:
			continue
		var needed: int = rule.quantity - current_quantity
		var added: int = 0
		var storage_candidates: Array[CampaignItemState] = _storage_candidates_for_replenishment_rule(
			campaign,
			rule
		)
		if current_item != null:
			var matching_stack_candidates: Array[CampaignItemState] = []
			for candidate: CampaignItemState in storage_candidates:
				if candidate.definition_id == current_item.definition_id:
					matching_stack_candidates.append(candidate)
			storage_candidates = matching_stack_candidates
		for storage_item: CampaignItemState in storage_candidates:
			if needed <= 0:
				break
			var current_definition: ItemDefinition = (
				_catalogue.item_definition(current_item.definition_id)
				if current_item != null
				else null
			)
			if (
				current_item != null
				and storage_item.definition_id == current_item.definition_id
				and current_definition != null
				and current_definition.stackable
			):
				var transfer: int = mini(needed, storage_item.quantity)
				current_item.quantity += transfer
				current_item.revision += 1
				storage_item.quantity -= transfer
				storage_item.revision += 1
				if storage_item.quantity <= 0:
					campaign.remove_item(storage_item.item_id)
				needed -= transfer
				added += transfer
				continue
			if current_item != null:
				continue
			if _fixed_slot_occupied_by_other_item(
				campaign,
				character_id,
				rule.preferred_container_id,
				&""
			):
				break
			var assignment_item: CampaignItemState = storage_item
			var definition: ItemDefinition = _catalogue.item_definition(storage_item.definition_id)
			var transfer_quantity: int = mini(needed, storage_item.quantity)
			if definition != null and definition.stackable and storage_item.quantity > transfer_quantity:
				assignment_item = storage_item.clone()
				assignment_item.item_id = campaign.unique_item_id(
					StringName("%s.restock.%s" % [storage_item.item_id, character_id])
				)
				assignment_item.quantity = transfer_quantity
				assignment_item.location = CampaignItemLocationState.stronghold_storage()
				assignment_item.revision += 1
				storage_item.quantity -= transfer_quantity
				storage_item.revision += 1
				campaign.upsert_item(assignment_item)
			var requested_position: Vector2i = (
				rule.preferred_grid_position if rule.fixed_position else Vector2i(-1, -1)
			)
			var equipped: OperationResult = _equipment_service.equip_candidate_at_position(
				campaign,
				assignment_item.item_id,
				character_id,
				rule.preferred_container_id,
				requested_position,
				rule.preferred_is_rotated if rule.fixed_position else false
			)
			if (
				not equipped.success
				and rule.preferred_container_id in [
					CampaignItemLocationState.CONTAINER_BELT,
					CampaignItemLocationState.CONTAINER_BACKPACK,
				]
			):
				equipped = _equipment_service.equip_candidate_at_position(
					campaign,
					assignment_item.item_id,
					character_id,
					rule.preferred_container_id,
					Vector2i(-1, -1),
					false
				)
			if not equipped.success:
				if assignment_item.item_id != storage_item.item_id:
					campaign.remove_item(assignment_item.item_id)
					storage_item.quantity += transfer_quantity
					storage_item.revision += 1
				break
			current_item = campaign.get_item(assignment_item.item_id) as CampaignItemState
			if current_item != null:
				claimed_character_items[current_item.item_id] = true
			needed -= transfer_quantity
			added += transfer_quantity
		if added > 0:
			replenished.append({
				"definition_id": String(rule.item_definition_id),
				"container_id": String(rule.preferred_container_id),
				"quantity": added,
			})
		if needed > 0:
			missing.append({
				"definition_id": String(rule.item_definition_id),
				"container_id": String(rule.preferred_container_id),
				"quantity": needed,
				"label": _rule_display_name(rule),
			})
	if not replenished.is_empty():
		character.revision += 1
		campaign.revision += 1
	return OperationResult.ok(
		{
			"character_id": character_id,
			"replenished": replenished,
			"missing": missing,
		},
		"Saved loadout replenished from stronghold storage."
		if missing.is_empty()
		else "Available replacements were equipped; some saved loadout items remain missing."
	)


func _loadout_rules_from_snapshot(entries: Array) -> Array[LoadoutItemRule]:
	var result: Array[LoadoutItemRule] = []
	for raw_entry: Variant in entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var definition_id := StringName(entry.get("definition_id", ""))
		var container_id := StringName(entry.get("container_id", ""))
		if definition_id.is_empty() or container_id.is_empty():
			continue
		var rule := LoadoutItemRule.new()
		rule.rule_id = StringName("return.replenish.%03d" % result.size())
		rule.item_definition_id = definition_id
		rule.quantity = maxi(1, int(entry.get("quantity", 1)))
		rule.preferred_container_id = container_id
		rule.preferred_grid_position = CampaignItemLocationState._vector_from_value(
			entry.get("grid_position", [-1, -1])
		)
		rule.fixed_position = container_id in [
			CampaignItemLocationState.CONTAINER_BELT,
			CampaignItemLocationState.CONTAINER_BACKPACK,
		]
		rule.preferred_is_rotated = bool(entry.get("is_rotated", false))
		rule.allow_rotation = true
		rule.required = true
		rule.allow_substitution = true
		result.append(rule)
	return result


func _current_item_for_replenishment_rule(
		campaign: CampaignState,
		character_id: StringName,
		rule: LoadoutItemRule,
		claimed_item_ids: Dictionary
) -> CampaignItemState:
	for raw_item: Variant in campaign.items_for_character(character_id):
		var item: CampaignItemState = raw_item as CampaignItemState
		if (
			item == null
			or item.location == null
			or claimed_item_ids.has(item.item_id)
			or item.location.container_id != rule.preferred_container_id
			or not _item_definition_matches_replenishment_rule(item, rule)
		):
			continue
		if (
			rule.fixed_position
			and item.location.container_id in [
				CampaignItemLocationState.CONTAINER_BELT,
				CampaignItemLocationState.CONTAINER_BACKPACK,
			]
			and (
				item.location.grid_position != rule.preferred_grid_position
				or item.location.is_rotated != rule.preferred_is_rotated
			)
		):
			continue
		return item
	return null


func _storage_candidates_for_replenishment_rule(
		campaign: CampaignState,
		rule: LoadoutItemRule
) -> Array[CampaignItemState]:
	var exact: Array[CampaignItemState] = []
	var substitutes: Array[CampaignItemState] = []
	for raw_item: Variant in campaign.get_items():
		var item: CampaignItemState = raw_item as CampaignItemState
		if (
			item == null
			or item.location == null
			or not item.location.is_stronghold_storage()
			or item.is_protected
			or campaign.active_reservation_for_item(item.item_id) != null
		):
			continue
		if not rule.exact_item_id.is_empty() and item.item_id == rule.exact_item_id:
			exact.append(item)
			continue
		if not _item_definition_matches_replenishment_rule(item, rule):
			continue
		if item.definition_id == rule.item_definition_id:
			exact.append(item)
		elif rule.allow_substitution:
			substitutes.append(item)
	var result: Array[CampaignItemState] = exact if not exact.is_empty() else substitutes
	result.sort_custom(
		func(a: CampaignItemState, b: CampaignItemState) -> bool:
			if a.quantity != b.quantity:
				return a.quantity < b.quantity
			return String(a.item_id) < String(b.item_id)
	)
	return result


func _item_definition_matches_replenishment_rule(
		item: CampaignItemState,
		rule: LoadoutItemRule
) -> bool:
	if item == null or rule == null:
		return false
	if not rule.exact_item_id.is_empty():
		if item.item_id == rule.exact_item_id:
			return true
		if not rule.allow_substitution:
			return false
	if item.definition_id == rule.item_definition_id:
		return true
	if not rule.allow_substitution:
		return false
	return _definition_is_equivalent(
		_catalogue.item_definition(item.definition_id),
		_catalogue.item_definition(rule.item_definition_id),
		rule
	)


func _fixed_slot_occupied_by_other_item(
		campaign: CampaignState,
		character_id: StringName,
		container_id: StringName,
		ignored_item_id: StringName
) -> bool:
	if container_id not in [
		CampaignItemLocationState.CONTAINER_PRIMARY_HAND,
		CampaignItemLocationState.CONTAINER_SECONDARY_HAND,
		CampaignItemLocationState.CONTAINER_ARMOUR,
	]:
		return false
	for raw_item: Variant in campaign.items_for_character(character_id):
		var item: CampaignItemState = raw_item as CampaignItemState
		if (
			item != null
			and item.item_id != ignored_item_id
			and item.location != null
			and item.location.container_id == container_id
		):
			return true
	return false


func preview_apply_template(
		campaign: CampaignState,
		character_id: StringName,
		template_id: StringName
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var plan: Dictionary = resolve_template_plan(campaign, character_id, template_id)
	if not (plan.get("blocking", []) as Array).is_empty():
		return OperationResult.new(
			false,
			&"loadout_template_incomplete",
			String((plan.get("blocking", []) as Array)[0]),
			plan,
			OperationResult.STATUS_REJECTED_BEFORE_COMMIT
		)
	var candidate := CampaignState.from_dictionary(campaign.to_dictionary())
	var applied: OperationResult = apply_template_candidate(candidate, character_id, template_id)
	if not applied.success:
		return OperationResult.new(
			false,
			&"loadout_template_invalid",
			applied.message,
			plan,
			OperationResult.STATUS_REJECTED_BEFORE_COMMIT
		)
	var errors: Array[String] = CampaignItemValidator.validate_campaign(candidate, _catalogue)
	if not errors.is_empty():
		return OperationResult.fail(&"loadout_template_invalid", errors[0])
	return OperationResult.pending(
		&"loadout_template_ready",
		plan,
		"Template can be applied."
	)


func apply_template_candidate(
		campaign: CampaignState,
		character_id: StringName,
		template_id: StringName
) -> OperationResult:
	if campaign == null or _equipment_service == null:
		return OperationResult.fail(&"loadout_service_unconfigured", "Loadout service is unavailable.")
	if _reservation_service != null:
		var availability: OperationResult = _reservation_service.validate_character_available(
			campaign,
			character_id
		)
		if not availability.success:
			return availability
	var plan: Dictionary = resolve_template_plan(campaign, character_id, template_id)
	var blocking: Array = plan.get("blocking", []) as Array
	if not blocking.is_empty():
		return OperationResult.fail(&"loadout_template_incomplete", String(blocking[0]))
	var character: PersistentCharacterState = campaign.get_character(character_id)
	if character == null:
		return OperationResult.fail(&"character_missing", "The selected character no longer exists.")
	var initial_storage: Dictionary = (
		_inventory_service.storage_capacity_snapshot(campaign)
		if _inventory_service != null
		else {}
	)
	var existing_ids: Array[StringName] = campaign.item_ids_for_character(character_id)
	for item_id: StringName in existing_ids:
		var existing_item: CampaignItemState = campaign.get_item(item_id) as CampaignItemState
		var existing_definition: ItemDefinition = (
			_catalogue.item_definition(existing_item.definition_id)
			if existing_item != null
			else null
		)
		if existing_definition != null and existing_definition.fixed_inventory_fixture:
			continue
		var returned: OperationResult = _equipment_service.return_to_storage_candidate(
			campaign,
			item_id,
			InventoryService.INTAKE_ALLOW_OVERFLOW
		)
		if not returned.success:
			return returned
	var assigned: Array = plan.get("assignments", []) as Array
	for raw_assignment: Variant in assigned:
		if not raw_assignment is Dictionary:
			continue
		var assignment: Dictionary = raw_assignment as Dictionary
		var item_id := StringName(assignment.get("item_id", ""))
		var container_id := StringName(assignment.get("container_id", ""))
		var position := CampaignItemLocationState._vector_from_value(
			assignment.get("grid_position", [-1, -1])
		)
		var rotated: bool = bool(assignment.get("is_rotated", false))
		var equipped: OperationResult = _equipment_service.equip_candidate_at_position(
			campaign,
			item_id,
			character_id,
			container_id,
			position,
			rotated
		)
		if not equipped.success:
			return equipped
	if _inventory_service != null:
		var final_storage: Dictionary = _inventory_service.storage_capacity_snapshot(campaign)
		var initial_overflow: int = int(initial_storage.get("overflow", 0))
		var final_overflow: int = int(final_storage.get("overflow", 0))
		if final_overflow > initial_overflow:
			return OperationResult.fail(
				&"loadout_storage_capacity_insufficient",
				"This loadout would leave the stronghold over capacity by %d. Free Storage Space or choose a different loadout." % final_overflow
			)
	character.preferred_loadout_template_id = template_id
	character.revision += 1
	return OperationResult.ok(
		plan,
		"%s applied to %s." % [String(plan.get("template_name", "Loadout")), character.display_name]
	)


func resolve_template_plan(
		campaign: CampaignState,
		character_id: StringName,
		template_id: StringName
) -> Dictionary:
	var assignments: Array[Dictionary] = []
	var outcomes: Array[Dictionary] = []
	var blocking: Array[String] = []
	var warnings: Array[String] = []
	if campaign == null or _catalogue == null:
		blocking.append("Campaign inventory is unavailable.")
		return {"assignments": assignments, "outcomes": outcomes, "blocking": blocking, "warnings": warnings}
	var character: PersistentCharacterState = campaign.get_character(character_id)
	var template: LoadoutTemplateState = campaign.get_loadout_template(template_id)
	if character == null:
		blocking.append("The selected character no longer exists.")
	elif template == null:
		blocking.append("The selected loadout template no longer exists.")
	else:
		var character_template: CharacterTemplateDefinition = _catalogue.character_template(character.template_id)
		if not template.is_compatible_with(character_template):
			blocking.append("This loadout template is not compatible with the selected troop type.")
	if blocking.is_empty() and _reservation_service != null:
		var availability: Dictionary = _reservation_service.character_availability(
			campaign,
			character_id
		)
		if not bool(availability.get("available", true)):
			blocking.append(String(availability.get("reason", "The character is deployed.")))
	var reserved_ids: Dictionary = {}
	if blocking.is_empty():
		var ordered_rules: Array[LoadoutItemRule] = template.rules.duplicate()
		ordered_rules.sort_custom(
			func(a: LoadoutItemRule, b: LoadoutItemRule) -> bool:
				return _container_priority(a.preferred_container_id) < _container_priority(b.preferred_container_id)
		)
		for rule: LoadoutItemRule in ordered_rules:
			var item: CampaignItemState = _resolve_item_for_rule(
				campaign,
				character_id,
				rule,
				template.substitution_policy,
				reserved_ids
			)
			if item == null:
				var missing_text: String = _rule_display_name(rule)
				if rule.required:
					blocking.append("Missing required item: %s." % missing_text)
				else:
					warnings.append("Optional item unavailable: %s." % missing_text)
				outcomes.append({"status": "missing", "label": missing_text, "required": rule.required})
				continue
			reserved_ids[item.item_id] = true
			var requested_position: Vector2i = rule.preferred_grid_position
			if not rule.fixed_position:
				requested_position = Vector2i(-1, -1)
			assignments.append({
				"item_id": String(item.item_id),
				"container_id": String(rule.preferred_container_id),
				"grid_position": [requested_position.x, requested_position.y],
				"is_rotated": rule.preferred_is_rotated if rule.fixed_position else false,
			})
			var substituted: bool = (
				not rule.item_definition_id.is_empty()
				and item.definition_id != rule.item_definition_id
			)
			outcomes.append({
				"status": "substituted" if substituted else "assigned",
				"label": _item_display_name(item),
				"container_id": String(rule.preferred_container_id),
			})
	return {
		"character_id": String(character_id),
		"template_id": String(template_id),
		"template_name": template.display_name if template != null else "Loadout",
		"assignments": assignments,
		"outcomes": outcomes,
		"blocking": blocking,
		"warnings": warnings,
	}


func preview_apply_template_to_many(
		campaign: CampaignState,
		character_ids: Array[StringName],
		template_id: StringName
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var candidate := CampaignState.from_dictionary(campaign.to_dictionary())
	var applied_ids: Array[StringName] = []
	for character_id: StringName in character_ids:
		var character: PersistentCharacterState = candidate.get_character(character_id)
		var template: LoadoutTemplateState = candidate.get_loadout_template(template_id)
		var character_template: CharacterTemplateDefinition = (
			_catalogue.character_template(character.template_id)
			if character != null and _catalogue != null
			else null
		)
		if character == null or template == null or not template.is_compatible_with(character_template):
			continue
		var result: OperationResult = apply_template_candidate(candidate, character_id, template_id)
		if not result.success:
			return OperationResult.fail(
				&"bulk_loadout_failed",
				"%s: %s" % [character.display_name, result.message]
			)
		applied_ids.append(character_id)
	if applied_ids.is_empty():
		return OperationResult.fail(&"no_compatible_characters", "No compatible active characters were selected.")
	var errors: Array[String] = CampaignItemValidator.validate_campaign(candidate, _catalogue)
	if not errors.is_empty():
		return OperationResult.fail(&"bulk_loadout_invalid", errors[0])
	return OperationResult.pending(
		&"bulk_loadout_ready",
		{"character_ids": applied_ids, "template_id": template_id},
		"Template can be applied to %d character%s." % [applied_ids.size(), "" if applied_ids.size() == 1 else "s"]
	)


func apply_template_to_many_candidate(
		campaign: CampaignState,
		character_ids: Array[StringName],
		template_id: StringName
) -> OperationResult:
	var applied_ids: Array[StringName] = []
	for character_id: StringName in character_ids:
		var character: PersistentCharacterState = campaign.get_character(character_id)
		var template: LoadoutTemplateState = campaign.get_loadout_template(template_id)
		var character_template: CharacterTemplateDefinition = (
			_catalogue.character_template(character.template_id)
			if character != null and _catalogue != null
			else null
		)
		if character == null or template == null or not template.is_compatible_with(character_template):
			continue
		var result: OperationResult = apply_template_candidate(campaign, character_id, template_id)
		if not result.success:
			return result
		applied_ids.append(character_id)
	if applied_ids.is_empty():
		return OperationResult.fail(&"no_compatible_characters", "No compatible active characters were selected.")
	return OperationResult.ok(applied_ids, "Loadout template applied to %d character%s." % [applied_ids.size(), "" if applied_ids.size() == 1 else "s"])


func current_loadout_matches_template(
		campaign: CampaignState,
		character_id: StringName,
		template_id: StringName
) -> bool:
	if campaign == null:
		return false
	var template: LoadoutTemplateState = campaign.get_loadout_template(template_id)
	var character: PersistentCharacterState = campaign.get_character(character_id)
	if template == null or character == null:
		return false
	var expected: Array[String] = []
	var exact_item_ids: Dictionary = {}
	for rule: LoadoutItemRule in template.rules:
		if rule == null:
			continue
		if not rule.exact_item_id.is_empty():
			exact_item_ids[rule.exact_item_id] = rule
		expected.append(_rule_signature(rule))
	var actual: Array[String] = []
	for raw_item: Variant in campaign.items_for_character(character_id):
		var item: CampaignItemState = raw_item as CampaignItemState
		if item == null or item.location == null:
			continue
		if exact_item_ids.has(item.item_id):
			var exact_rule: LoadoutItemRule = exact_item_ids[item.item_id] as LoadoutItemRule
			if not _item_matches_rule_location(item, exact_rule):
				return false
			exact_item_ids.erase(item.item_id)
		actual.append(_item_signature(item))
	if not exact_item_ids.is_empty():
		return false
	expected.sort()
	actual.sort()
	return expected == actual


func create_blank_template(
		campaign: CampaignState,
		character_id: StringName,
		display_name: String
) -> LoadoutTemplateState:
	if campaign == null or _catalogue == null:
		return null
	var character: PersistentCharacterState = campaign.get_character(character_id)
	if character == null:
		return null
	var character_template: CharacterTemplateDefinition = _catalogue.character_template(character.template_id)
	var result := LoadoutTemplateState.new()
	result.template_id = campaign.next_loadout_template_id()
	result.display_name = display_name.strip_edges()
	if result.display_name.is_empty():
		result.display_name = "Blank %s Loadout" % (character_template.troop_type if character_template != null else "Character")
	result.description = "Player-created blank loadout template."
	if character_template != null:
		result.allowed_troop_type_ids.append(StringName(character_template.troop_type.to_snake_case()))
	return result


func duplicate_template(
		campaign: CampaignState,
		template_id: StringName,
		display_name: String
) -> LoadoutTemplateState:
	if campaign == null:
		return null
	var source: LoadoutTemplateState = campaign.get_loadout_template(template_id)
	if source == null:
		return null
	var result: LoadoutTemplateState = source.clone()
	result.template_id = campaign.next_loadout_template_id()
	result.display_name = display_name.strip_edges()
	if result.display_name.is_empty():
		result.display_name = "%s Copy" % source.display_name
	result.description = "Player copy of %s." % source.display_name
	result.is_authored = false
	result.source_definition_id = &""
	result.template_version += 1
	return result


func _rule_signature(rule: LoadoutItemRule) -> String:
	return "%s|%s|%d|%d|%d|%s|%s" % [
		String(rule.item_definition_id),
		String(rule.preferred_container_id),
		rule.quantity,
		rule.preferred_grid_position.x if rule.fixed_position else -1,
		rule.preferred_grid_position.y if rule.fixed_position else -1,
		"rotated" if rule.fixed_position and rule.preferred_is_rotated else "normal",
		"fixed" if rule.fixed_position else "auto",
	]


func _item_signature(item: CampaignItemState) -> String:
	var location: CampaignItemLocationState = item.location
	var is_spatial: bool = location.container_id in [
		CampaignItemLocationState.CONTAINER_BELT,
		CampaignItemLocationState.CONTAINER_BACKPACK,
	]
	return "%s|%s|%d|%d|%d|%s|%s" % [
		String(item.definition_id),
		String(location.container_id),
		item.quantity,
		location.grid_position.x if is_spatial else -1,
		location.grid_position.y if is_spatial else -1,
		"rotated" if is_spatial and location.is_rotated else "normal",
		"fixed" if is_spatial else "auto",
	]


func _item_matches_rule_location(item: CampaignItemState, rule: LoadoutItemRule) -> bool:
	if item == null or item.location == null or rule == null:
		return false
	if item.definition_id != rule.item_definition_id or item.quantity != rule.quantity:
		return false
	if item.location.container_id != rule.preferred_container_id:
		return false
	if rule.fixed_position:
		return (
			item.location.grid_position == rule.preferred_grid_position
			and item.location.is_rotated == rule.preferred_is_rotated
		)
	return true


func _template_from_default_loadout(
		character_template: CharacterTemplateDefinition,
		template_id: StringName
) -> LoadoutTemplateState:
	var result := LoadoutTemplateState.new()
	result.template_id = template_id
	result.display_name = "%s — Standard" % character_template.troop_type
	if character_template.troop_type == "Marauder":
		result.display_name = "Marauder — Captor"
	result.description = "Authored standard equipment plan for %s." % character_template.troop_type
	result.is_authored = true
	result.source_definition_id = character_template.id
	result.allowed_troop_type_ids.append(StringName(character_template.troop_type.to_snake_case()))
	for raw_entry: Dictionary in character_template.default_loadout_entries:
		var rule := LoadoutItemRule.new()
		rule.rule_id = StringName("rule.%03d" % result.rules.size())
		rule.item_definition_id = StringName(raw_entry.get("definition_id", ""))
		rule.quantity = maxi(1, int(raw_entry.get("quantity", 1)))
		rule.preferred_container_id = StringName(raw_entry.get("container_kind", CampaignItemLocationState.CONTAINER_BACKPACK))
		rule.preferred_grid_position = CampaignItemLocationState._vector_from_value(raw_entry.get("grid_position", [-1, -1]))
		rule.fixed_position = rule.preferred_container_id in [CampaignItemLocationState.CONTAINER_BELT, CampaignItemLocationState.CONTAINER_BACKPACK]
		rule.preferred_is_rotated = bool(raw_entry.get("is_rotated", false))
		rule.allow_substitution = true
		result.rules.append(rule)
	return result


func _resolve_item_for_rule(
		campaign: CampaignState,
		character_id: StringName,
		rule: LoadoutItemRule,
		substitution_policy: StringName,
		reserved_ids: Dictionary
) -> CampaignItemState:
	if not rule.exact_item_id.is_empty():
		var exact: CampaignItemState = campaign.get_item(rule.exact_item_id) as CampaignItemState
		if _item_is_available_for_rule(
			exact, character_id, rule, substitution_policy, reserved_ids, true
		):
			return exact
		if not rule.allow_substitution or substitution_policy == LoadoutTemplateState.POLICY_STRICT:
			return null
	var exact_definition_candidates: Array[CampaignItemState] = []
	var substitute_candidates: Array[CampaignItemState] = []
	for raw_item: Variant in campaign.get_items():
		var item: CampaignItemState = raw_item as CampaignItemState
		if not _item_is_available_for_rule(
			item, character_id, rule, substitution_policy, reserved_ids, false
		):
			continue
		if not rule.item_definition_id.is_empty() and item.definition_id == rule.item_definition_id:
			exact_definition_candidates.append(item)
		else:
			substitute_candidates.append(item)
	var candidates: Array[CampaignItemState] = (
		exact_definition_candidates if not exact_definition_candidates.is_empty() else substitute_candidates
	)
	candidates.sort_custom(
		func(a: CampaignItemState, b: CampaignItemState) -> bool:
			return _candidate_precedes(a, b, substitution_policy, rule)
	)
	return candidates[0] if not candidates.is_empty() else null


func _item_is_available_for_rule(
		item: CampaignItemState,
		character_id: StringName,
		rule: LoadoutItemRule,
		substitution_policy: StringName,
		reserved_ids: Dictionary,
		exact_request: bool
) -> bool:
	if item == null or item.location == null or reserved_ids.has(item.item_id):
		return false
	if not (item.location.is_stronghold_storage() or item.location.belongs_to_character(character_id)):
		return false
	if item.quantity < rule.quantity:
		return false
	if item.is_protected and not exact_request:
		return false
	var definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
	if definition == null:
		return false
	if not _is_armour_definition(definition) and item.condition + 0.0001 < rule.minimum_condition:
		return false
	for tag: StringName in rule.required_tags:
		if not definition.has_tag(tag):
			return false
	if rule.item_definition_id.is_empty():
		return not rule.required_tags.is_empty()
	if definition.id == rule.item_definition_id:
		return true
	if not rule.allow_substitution or substitution_policy == LoadoutTemplateState.POLICY_STRICT:
		return false
	var preferred: ItemDefinition = _catalogue.item_definition(rule.item_definition_id)
	return _definition_is_equivalent(definition, preferred, rule)


func _definition_is_equivalent(
		candidate: ItemDefinition,
		preferred: ItemDefinition,
		rule: LoadoutItemRule
) -> bool:
	if candidate == null:
		return false
	if not rule.required_tags.is_empty():
		for tag: StringName in rule.required_tags:
			if not candidate.has_tag(tag):
				return false
		return true
	if preferred == null:
		return false
	if candidate.tactical_visual_category != preferred.tactical_visual_category:
		return false
	if candidate.handedness != preferred.handedness:
		return false
	if candidate.equipment_slot_ids != preferred.equipment_slot_ids:
		return false
	if preferred.can_equip_in_hand():
		return candidate.can_equip_in_hand()
	if preferred.belt_allowed != candidate.belt_allowed and rule.preferred_container_id == CampaignItemLocationState.CONTAINER_BELT:
		return false
	if preferred.backpack_allowed != candidate.backpack_allowed and rule.preferred_container_id == CampaignItemLocationState.CONTAINER_BACKPACK:
		return false
	return true


func _candidate_precedes(
		a: CampaignItemState,
		b: CampaignItemState,
		policy: StringName,
		rule: LoadoutItemRule
) -> bool:
	var a_def: ItemDefinition = _catalogue.item_definition(a.definition_id)
	var b_def: ItemDefinition = _catalogue.item_definition(b.definition_id)
	var a_preferred_score: int = _preferred_tag_score(a_def, rule)
	var b_preferred_score: int = _preferred_tag_score(b_def, rule)
	if a_preferred_score != b_preferred_score:
		return a_preferred_score > b_preferred_score
	var compare_condition: bool = not (
		_is_armour_definition(a_def)
		or _is_armour_definition(b_def)
	)
	if policy == LoadoutTemplateState.POLICY_BEST_AVAILABLE:
		if compare_condition and absf(a.condition - b.condition) > 0.001:
			return a.condition > b.condition
	elif policy == LoadoutTemplateState.POLICY_CONSERVE_VALUABLE:
		if a.is_protected != b.is_protected:
			return not a.is_protected
		if compare_condition and absf(a.condition - b.condition) > 0.001:
			return a.condition < b.condition
	var a_name: String = a_def.display_name if a_def != null else String(a.definition_id)
	var b_name: String = b_def.display_name if b_def != null else String(b.definition_id)
	var name_compare: int = a_name.naturalnocasecmp_to(b_name)
	if name_compare != 0:
		return name_compare < 0
	return String(a.item_id) < String(b.item_id)


func _is_armour_definition(definition: ItemDefinition) -> bool:
	return (
		definition != null
		and (
			definition.can_equip_in_slot(CampaignItemLocationState.CONTAINER_ARMOUR)
			or not definition.defence_profile_id.is_empty()
		)
	)


func _preferred_tag_score(definition: ItemDefinition, rule: LoadoutItemRule) -> int:
	if definition == null:
		return 0
	var result: int = 0
	for tag: StringName in rule.preferred_tags:
		if definition.has_tag(tag):
			result += 1
	return result


func _rule_display_name(rule: LoadoutItemRule) -> String:
	if not rule.exact_item_id.is_empty():
		return String(rule.exact_item_id)
	var definition: ItemDefinition = _catalogue.item_definition(rule.item_definition_id)
	if definition != null:
		return "%s%s" % [definition.display_name, " ×%d" % rule.quantity if rule.quantity > 1 else ""]
	if not rule.required_tags.is_empty():
		return " / ".join(_string_name_to_strings(rule.required_tags))
	return "Unspecified item"


func _item_display_name(item: CampaignItemState) -> String:
	var definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
	return definition.display_name if definition != null else String(item.definition_id)


func _container_priority(container_id: StringName) -> int:
	match container_id:
		CampaignItemLocationState.CONTAINER_ARMOUR:
			return 0
		CampaignItemLocationState.CONTAINER_PRIMARY_HAND:
			return 1
		CampaignItemLocationState.CONTAINER_SECONDARY_HAND:
			return 2
		CampaignItemLocationState.CONTAINER_BELT:
			return 3
		CampaignItemLocationState.CONTAINER_BACKPACK:
			return 4
		CampaignItemLocationState.CONTAINER_WORN_UTILITY:
			return 5
	return 6


func _string_name_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value).replace("_", " ").capitalize())
	return result
