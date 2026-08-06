extends RefCounted

# Parser-isolated read model for the Storage screen. It never mutates campaign
# state and deliberately uses duck-typed campaign/domain objects.
const LOCATION_STRONGHOLD_STORAGE: StringName = &"stronghold_storage"
const LOCATION_CHARACTER_EQUIPMENT: StringName = &"character_equipment"
const LOCATION_CHARACTER_INVENTORY: StringName = &"character_inventory"
const LOCATION_MISSION_GROUND: StringName = &"mission_ground"
const LOCATION_UNASSIGNED: StringName = &"unassigned"
const LOCATION_LOST: StringName = &"lost"

const STATE_AVAILABLE: StringName = &"available"
const STATE_ASSIGNED: StringName = &"assigned"
const STATE_RESERVED: StringName = &"reserved"

const LOCATION_FILTER_ALL: StringName = &"all"
const LOCATION_FILTER_STORAGE: StringName = &"storage"
const LOCATION_FILTER_EQUIPPED: StringName = &"equipped"

var _catalogue
var _reservation_service


func configure(catalogue, reservation_service = null) -> void:
	_catalogue = catalogue
	_reservation_service = reservation_service


func build_groups(
		campaign,
		category_filter: StringName = &"all",
		availability_filter: StringName = &"all",
		search_text: String = "",
		sort_id: StringName = &"name",
		location_filter: StringName = LOCATION_FILTER_ALL
) -> Array[Dictionary]:
	var groups_by_definition: Dictionary = {}
	if campaign == null or _catalogue == null:
		var empty: Array[Dictionary] = []
		return empty
	for item in campaign.get_items():
		if item == null or item.location == null:
			continue
		if item.location.location_type in [
			LOCATION_MISSION_GROUND,
			LOCATION_UNASSIGNED,
			LOCATION_LOST,
		]:
			continue
		if not _location_matches_filter(item.location.location_type, location_filter):
			continue
		var definition = _catalogue.item_definition(item.definition_id)
		if definition == null:
			continue
		var category_id: StringName = category_for_definition(definition)
		if category_filter != &"all" and category_id != category_filter:
			continue
		var definition_key: String = String(item.definition_id)
		if not groups_by_definition.has(definition_key):
			groups_by_definition[definition_key] = {
				"definition_id": item.definition_id,
				"display_name": definition.display_name,
				"description": definition.description,
				"category_id": category_id,
				"unit_weight": definition.weight_lb,
				"is_armour": _is_armour_definition(definition),
				"total_count": 0,
				"available_count": 0,
				"assigned_count": 0,
				"reserved_count": 0,
				"stored_count": 0,
				"stored_space": 0,
				"single_item_storage_space": definition.storage_space_for_quantity(1),
				"record_count": 0,
				"owner_ids": {},
				"owner_count": 0,
				"location_filter": location_filter,
				"combined_weight": 0.0,
				"instances": [],
				"visible_instances": [],
			}
		var group: Dictionary = groups_by_definition[definition_key] as Dictionary
		var instance: Dictionary = _build_instance(campaign, item, definition)
		var quantity: int = maxi(1, int(item.quantity))
		group["total_count"] = int(group["total_count"]) + quantity
		group["record_count"] = int(group["record_count"]) + 1
		group["combined_weight"] = float(group["combined_weight"]) + definition.weight_lb * float(quantity)
		if item.location.location_type in [LOCATION_CHARACTER_EQUIPMENT, LOCATION_CHARACTER_INVENTORY]:
			var owner_ids: Dictionary = group.get("owner_ids", {}) as Dictionary
			owner_ids[item.location.owner_id] = true
			group["owner_ids"] = owner_ids
			group["owner_count"] = owner_ids.size()
		if item.location.location_type == LOCATION_STRONGHOLD_STORAGE:
			group["stored_count"] = int(group["stored_count"]) + quantity
			group["stored_space"] = int(group["stored_space"]) + int(instance.get("current_storage_space", 0))
		match StringName(instance.get("state", STATE_AVAILABLE)):
			STATE_RESERVED:
				group["reserved_count"] = int(group["reserved_count"]) + quantity
			STATE_ASSIGNED:
				group["assigned_count"] = int(group["assigned_count"]) + quantity
			_:
				group["available_count"] = int(group["available_count"]) + quantity
		var instances: Array = group["instances"] as Array
		instances.append(instance)
		groups_by_definition[definition_key] = group

	var normalized_search: String = search_text.strip_edges().to_lower()
	var result: Array[Dictionary] = []
	for raw_group: Variant in groups_by_definition.values():
		var group: Dictionary = raw_group as Dictionary
		var instances: Array = group.get("instances", []) as Array
		instances.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_rank: int = _state_rank(StringName(a.get("state", STATE_AVAILABLE)))
			var b_rank: int = _state_rank(StringName(b.get("state", STATE_AVAILABLE)))
			if a_rank != b_rank:
				return a_rank < b_rank
			return String(a.get("item_id", "")) < String(b.get("item_id", ""))
		)
		group["instances"] = instances
		var visible_instances: Array = []
		for raw_instance: Variant in instances:
			var instance: Dictionary = raw_instance as Dictionary
			if availability_filter != &"all" and StringName(instance.get("state", &"")) != availability_filter:
				continue
			if not normalized_search.is_empty() and not _instance_matches_search(group, instance, definition_tags(group), normalized_search):
				continue
			visible_instances.append(instance)
		if visible_instances.is_empty():
			continue
		group["visible_instances"] = visible_instances
		result.append(group)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match sort_id:
			&"total":
				if int(a.get("total_count", 0)) != int(b.get("total_count", 0)):
					return int(a.get("total_count", 0)) > int(b.get("total_count", 0))
			&"available":
				if int(a.get("available_count", 0)) != int(b.get("available_count", 0)):
					return int(a.get("available_count", 0)) > int(b.get("available_count", 0))
		return String(a.get("display_name", "")).naturalnocasecmp_to(String(b.get("display_name", ""))) < 0
	)
	return result


func group_snapshot(
		campaign,
		definition_id: StringName,
		location_filter: StringName = LOCATION_FILTER_ALL
) -> Dictionary:
	for group: Dictionary in build_groups(campaign, &"all", &"all", "", &"name", location_filter):
		if StringName(group.get("definition_id", &"")) == definition_id:
			return group
	return {}


func instance_snapshot(campaign, item_id: StringName) -> Dictionary:
	if campaign == null:
		return {}
	var item = campaign.get_item(item_id)
	if item == null or item.location == null:
		return {}
	var definition = _catalogue.item_definition(item.definition_id) if _catalogue != null else null
	if definition == null:
		return {}
	return _build_instance(campaign, item, definition)


func category_for_definition(definition) -> StringName:
	if definition == null:
		return &"other"
	# All removable facility objects are Furniture. The legacy installation tag
	# remains accepted so existing or prototype content migrates without creating
	# a separate player-facing inventory category.
	if definition.has_tag(&"furniture") or definition.has_tag(&"installation") or (
		definition.has_tag(&"bulky") and definition.has_tag(&"loot")
	):
		return &"furniture"
	if definition.has_tag(&"salvage"):
		return &"salvage"
	if definition.has_tag(&"ammunition"):
		return &"ammunition"
	if definition.has_tag(&"consumable") or definition.has_tag(&"medical"):
		return &"consumables"
	if definition.has_tag(&"weapon") or not definition.equipment_slot_ids.is_empty() or not definition.defence_profile_id.is_empty():
		return &"equipment"
	return &"other"


func _build_instance(campaign, item, definition) -> Dictionary:
	var reservation = campaign.active_reservation_for_item(item.item_id)
	var state: StringName = STATE_AVAILABLE
	if reservation != null and reservation.is_active():
		state = STATE_RESERVED
	elif item.location.location_type in [LOCATION_CHARACTER_EQUIPMENT, LOCATION_CHARACTER_INVENTORY]:
		state = STATE_ASSIGNED
	elif item.location.location_type != LOCATION_STRONGHOLD_STORAGE:
		state = STATE_ASSIGNED
	var owner_name: String = ""
	if item.location.location_type in [LOCATION_CHARACTER_EQUIPMENT, LOCATION_CHARACTER_INVENTORY]:
		var owner = campaign.get_character(item.location.owner_id)
		owner_name = owner.display_name if owner != null else String(item.location.owner_id)
	var availability: Dictionary = {}
	if _reservation_service != null:
		availability = _reservation_service.item_availability(campaign, item.item_id)
	var release_condition: String = ""
	if reservation != null:
		match reservation.purpose:
			&"deployment":
				release_condition = "Released when the squad returns."
			&"construction_input", &"upgrade_input":
				release_condition = "Released if the project is cancelled or completed."
			_:
				release_condition = "Released when the owning project resolves."
	return {
		"item_id": item.item_id,
		"definition_id": item.definition_id,
		"quantity": item.quantity,
		"condition": item.condition,
		"state": state,
		"location_type": item.location.location_type,
		"owner_id": item.location.owner_id,
		"owner_name": owner_name,
		"container_id": item.location.container_id,
		"location_text": _location_text(item.location, owner_name),
		"reservation_id": StringName(availability.get("reservation_id", "")),
		"reservation_name": String(availability.get("display_name", "")),
		"reservation_purpose": StringName(availability.get("purpose", "")),
		"reservation_reason": String(availability.get("reason", "")),
		"release_condition": release_condition,
		"weight": definition.weight_lb * float(maxi(1, int(item.quantity))),
		"storage_space_if_stored": definition.storage_space_for_quantity(maxi(1, int(item.quantity))),
		"current_storage_space": (
			definition.storage_space_for_quantity(maxi(1, int(item.quantity)))
			if item.location.location_type == LOCATION_STRONGHOLD_STORAGE
			else 0
		),
		"is_armour": _is_armour_definition(definition),
		"is_stackable": bool(definition.stackable),
	}


func _location_text(location, owner_name: String) -> String:
	if location == null:
		return "Unknown"
	match location.location_type:
		LOCATION_STRONGHOLD_STORAGE:
			return "Stronghold Storage"
		LOCATION_CHARACTER_EQUIPMENT, LOCATION_CHARACTER_INVENTORY:
			return "%s — %s" % [
				owner_name if not owner_name.is_empty() else String(location.owner_id),
				String(location.container_id).replace("_", " ").capitalize(),
			]
	return String(location.location_type).replace("_", " ").capitalize()


func _instance_matches_search(
		group: Dictionary,
		instance: Dictionary,
		tags: Array[String],
		search_text: String
) -> bool:
	var parts: Array[String] = [
		String(group.get("display_name", "")),
		String(group.get("definition_id", "")),
		String(group.get("category_id", "")),
		String(instance.get("owner_name", "")),
		String(instance.get("container_id", "")),
		String(instance.get("location_text", "")),
		String(instance.get("state", "")),
		String(instance.get("reservation_name", "")),
		String(instance.get("reservation_purpose", "")),
		String(instance.get("reservation_reason", "")),
	]
	parts.append_array(tags)
	return " ".join(parts).to_lower().contains(search_text)


func definition_tags(group: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if _catalogue == null:
		return result
	var definition = _catalogue.item_definition(StringName(group.get("definition_id", &"")))
	if definition == null:
		return result
	for tag: StringName in definition.equipment_tags:
		result.append(String(tag))
	return result


func _is_armour_definition(definition) -> bool:
	return definition != null and (
		not definition.defence_profile_id.is_empty()
		or definition.equipment_slot_ids.has(&"armour")
	)


func _state_rank(state: StringName) -> int:
	match state:
		STATE_AVAILABLE:
			return 0
		STATE_ASSIGNED:
			return 1
		STATE_RESERVED:
			return 2
	return 3


func _location_matches_filter(location_type: StringName, location_filter: StringName) -> bool:
	match location_filter:
		LOCATION_FILTER_STORAGE:
			return location_type == LOCATION_STRONGHOLD_STORAGE
		LOCATION_FILTER_EQUIPPED:
			return location_type in [LOCATION_CHARACTER_EQUIPMENT, LOCATION_CHARACTER_INVENTORY]
	return true
