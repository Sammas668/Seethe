extends RefCounted

# Deliberately parser-isolated. This service is preloaded very early by
# CampaignSession, InventoryService, StrategicEquipmentService, LoadoutService
# and CampaignMissionCoordinator. Keep custom campaign/domain classes out of
# this script's parse boundary and use duck-typed campaign objects instead.
const OperationResultScript = preload("res://core/results/operation_result.gd")
const StrategicReservationStateScript = preload(
	"res://domain/campaign/strategic_reservation_state.gd"
)

const PURPOSE_DEPLOYMENT: StringName = &"deployment"
const STATUS_ACTIVE: StringName = &"active"
const STATUS_CANCELLED: StringName = &"cancelled"
const LOCATION_CHARACTER_EQUIPMENT: StringName = &"character_equipment"
const LOCATION_CHARACTER_INVENTORY: StringName = &"character_inventory"
const MISSION_STATUS_CANCELLED: StringName = &"cancelled"
const OPERATION_STATUS_CANCELLED: StringName = &"cancelled"


func reserve_deployment_candidate(
		campaign,
		reservation_id: StringName,
		owner_id: StringName,
		mission_instance_id: StringName,
		display_name: String,
		character_ids: Array[StringName],
		item_ids: Array[StringName]
):
	if campaign == null:
		return OperationResultScript.fail(&"campaign_missing", "No campaign is loaded.")
	if reservation_id.is_empty() or owner_id.is_empty():
		return OperationResultScript.fail(
			&"reservation_identity_missing",
			"The deployment reservation has no valid identity."
		)
	var existing = campaign.get_strategic_reservation(reservation_id)
	if existing != null:
		if existing.is_active():
			var expected_items: Array[StringName] = []
			for item_id: StringName in item_ids:
				if not expected_items.has(item_id):
					expected_items.append(item_id)
			if (
				existing.purpose == PURPOSE_DEPLOYMENT
				and existing.owner_id == owner_id
				and existing.mission_instance_id == mission_instance_id
				and existing.character_ids == character_ids
				and existing.item_ids == expected_items
			):
				return OperationResultScript.no_change(existing, "Deployment is already reserved.")
			return OperationResultScript.fail(
				&"reservation_conflict",
				"The deployment reservation ID already belongs to another squad or item set."
			)
		return OperationResultScript.fail(
			&"reservation_closed",
			"A closed reservation cannot be reused."
		)
	if character_ids.is_empty():
		return OperationResultScript.fail(&"squad_empty", "Select at least one character.")
	var selected_characters: Dictionary = {}
	for character_id: StringName in character_ids:
		if selected_characters.has(character_id):
			return OperationResultScript.fail(
				&"duplicate_character",
				"A character was selected more than once."
			)
		selected_characters[character_id] = true
		var character = campaign.get_character(character_id)
		if character == null or character.is_dead:
			return OperationResultScript.fail(
				&"character_unavailable",
				"A selected character is unavailable."
			)
		var availability = validate_character_available(campaign, character_id)
		if not availability.success:
			return availability
	var seen_items: Dictionary = {}
	for item_id: StringName in item_ids:
		if seen_items.has(item_id):
			continue
		seen_items[item_id] = true
		var item = campaign.get_item(item_id)
		if item == null or item.location == null:
			return OperationResultScript.fail(
				&"reservation_item_missing",
				"A deployment item no longer exists."
			)
		if not selected_characters.has(item.location.owner_id):
			return OperationResultScript.fail(
				&"reservation_item_owner_mismatch",
				"A deployment item is no longer carried by the selected squad."
			)
		var item_availability = validate_item_available(campaign, item_id)
		if not item_availability.success:
			return item_availability
	var reservation = StrategicReservationStateScript.new()
	reservation.reservation_id = reservation_id
	reservation.purpose = PURPOSE_DEPLOYMENT
	reservation.owner_id = owner_id
	reservation.mission_instance_id = mission_instance_id
	reservation.display_name = (
		display_name.strip_edges()
		if not display_name.strip_edges().is_empty()
		else "Mission deployment"
	)
	reservation.character_ids = character_ids.duplicate()
	reservation.item_ids.clear()
	for item_id: StringName in item_ids:
		if not reservation.item_ids.has(item_id):
			reservation.item_ids.append(item_id)
	reservation.created_tick = campaign.campaign_tick
	if not campaign.upsert_strategic_reservation(reservation):
		return OperationResultScript.fail(
			&"reservation_commit_failed",
			"The deployment reservation could not be stored."
		)
	return OperationResultScript.ok(
		reservation,
		"Squad and exact equipment reserved for deployment."
	)


func release_reservation_candidate(campaign, reservation_id: StringName, cancelled: bool = false):
	if campaign == null:
		return OperationResultScript.fail(&"campaign_missing", "No campaign is loaded.")
	var reservation = campaign.get_strategic_reservation(reservation_id)
	if reservation == null:
		return OperationResultScript.no_change(null, "No deployment reservation remains.")
	if not reservation.is_active():
		return OperationResultScript.no_change(
			reservation,
			"The deployment reservation is already closed."
		)
	reservation.release(campaign.campaign_tick, cancelled)
	campaign.revision += 1
	return OperationResultScript.ok(
		reservation,
		"Deployment reservation cancelled." if cancelled else "Deployment reservation released."
	)


func release_for_mission_candidate(
		campaign,
		mission_instance_id: StringName,
		cancelled: bool = false
):
	if campaign == null:
		return OperationResultScript.fail(&"campaign_missing", "No campaign is loaded.")
	var released_ids: Array[StringName] = []
	for reservation in campaign.get_strategic_reservations():
		if reservation.is_active() and reservation.mission_instance_id == mission_instance_id:
			reservation.release(campaign.campaign_tick, cancelled)
			released_ids.append(reservation.reservation_id)
	if released_ids.is_empty():
		return OperationResultScript.no_change(null, "No deployment reservation remains.")
	campaign.revision += 1
	return OperationResultScript.ok(released_ids, "Deployment reservations released.")


func validate_character_available(campaign, character_id: StringName):
	var availability: Dictionary = character_availability(campaign, character_id)
	if bool(availability.get("available", false)):
		return OperationResultScript.ok(character_id)
	return OperationResultScript.fail(
		&"character_deployment_reserved",
		String(availability.get("reason", "The character is unavailable."))
	)


func validate_item_available(campaign, item_id: StringName):
	var availability: Dictionary = item_availability(campaign, item_id)
	if bool(availability.get("available", false)):
		return OperationResultScript.ok(item_id)
	return OperationResultScript.fail(
		&"item_deployment_reserved",
		String(availability.get("reason", "The item is unavailable."))
	)


func character_availability(campaign, character_id: StringName) -> Dictionary:
	if campaign == null:
		return {"available": false, "reason": "No campaign is loaded.", "reservation_id": ""}
	var character = campaign.get_character(character_id)
	if character == null:
		return {
			"available": false,
			"reason": "The selected character no longer exists.",
			"reservation_id": "",
		}
	# Prestige is a character-owned strategic commitment even though it is not
	# a deployment reservation. Check it here so mission selection, loadout
	# actions and every other availability caller see the same authoritative lock.
	if campaign.has_method("get_prestige_projects"):
		for prestige_project in campaign.get_prestige_projects():
			if (
				prestige_project != null
				and prestige_project.character_id == character_id
				and not prestige_project.applied
				and prestige_project.status != TroopPrestigeProjectState.STATUS_CANCELLED
			):
				return {
					"available": false,
					"reason": "%s is undertaking Prestige training and cannot deploy until it is complete." % character.display_name,
					"reservation_id": String(prestige_project.project_id),
					"purpose": "prestige_training",
					"mission_instance_id": "",
					"display_name": "Prestige Training",
				}
	var reservation = campaign.active_reservation_for_character(character_id)
	if reservation == null:
		return {
			"available": true,
			"reason": "",
			"reservation_id": "",
			"purpose": "",
			"mission_instance_id": "",
			"display_name": "",
		}
	return {
		"available": false,
		"reason": "%s is deployed on %s. Unavailable until the squad returns." % [
			character.display_name,
			reservation.display_name,
		],
		"reservation_id": String(reservation.reservation_id),
		"purpose": String(reservation.purpose),
		"mission_instance_id": String(reservation.mission_instance_id),
		"display_name": reservation.display_name,
	}


func item_availability(campaign, item_id: StringName) -> Dictionary:
	if campaign == null:
		return {"available": false, "reason": "No campaign is loaded.", "reservation_id": ""}
	var item = campaign.get_item(item_id)
	if item == null:
		return {
			"available": false,
			"reason": "The selected item no longer exists.",
			"reservation_id": "",
		}
	var reservation = campaign.active_reservation_for_item(item_id)
	if reservation == null:
		return {
			"available": true,
			"reason": "",
			"reservation_id": "",
			"purpose": "",
			"mission_instance_id": "",
			"display_name": "",
		}
	var owner_name: String = "the deployed squad"
	if item.location != null and not item.location.owner_id.is_empty():
		var owner = campaign.get_character(item.location.owner_id)
		if owner != null:
			owner_name = owner.display_name
	var reason_text: String = "Deployed with %s. Reserved for %s. Unavailable until the squad returns." % [
		owner_name,
		reservation.display_name,
	]
	if reservation.purpose == StrategicReservationStateScript.PURPOSE_PRODUCTION_INPUT:
		reason_text = "Reserved for Production: %s. Unavailable until the project completes or is cancelled." % reservation.display_name
	return {
		"available": false,
		"reason": reason_text,
		"reservation_id": String(reservation.reservation_id),
		"purpose": String(reservation.purpose),
		"mission_instance_id": String(reservation.mission_instance_id),
		"display_name": reservation.display_name,
	}


func validate_location_change(campaign, item_id: StringName, target_location):
	if campaign == null:
		return OperationResultScript.fail(&"campaign_missing", "No campaign is loaded.")
	var item = campaign.get_item(item_id)
	if item == null:
		return OperationResultScript.fail(&"item_missing", "The selected item no longer exists.")
	var current_data: Dictionary = item.location.to_dictionary() if item.location != null else {}
	var target_data: Dictionary = target_location.to_dictionary() if target_location != null else {}
	if current_data == target_data:
		return OperationResultScript.no_change(item_id, "The exact item location is unchanged.")
	if campaign.active_reservation_for_item(item_id) != null:
		return validate_item_available(campaign, item_id)
	if (
		target_location != null
		and target_location.location_type in [
			LOCATION_CHARACTER_EQUIPMENT,
			LOCATION_CHARACTER_INVENTORY,
		]
	):
		var character_result = validate_character_available(campaign, target_location.owner_id)
		if not character_result.success:
			return character_result
	return OperationResultScript.ok(item_id)


func ensure_deployment_reservations(campaign) -> bool:
	if campaign == null:
		return false
	var changed: bool = false
	for operation in campaign.get_squad_travel_operations():
		if operation == null:
			continue
		var mission = campaign.get_active_mission(operation.mission_instance_id)
		var reservation_id: StringName = operation.reservation_id
		if reservation_id.is_empty():
			reservation_id = StringName("reservation.%s" % operation.operation_id)
			operation.reservation_id = reservation_id
			operation.revision += 1
			changed = true
		if mission != null and mission.deployment_reservation_id != reservation_id:
			mission.deployment_reservation_id = reservation_id
			mission.revision += 1
			changed = true
		var existing = campaign.get_strategic_reservation(reservation_id)
		if operation.is_active():
			if existing == null:
				existing = StrategicReservationStateScript.new()
				existing.reservation_id = reservation_id
				campaign.strategic_reservations_by_id[reservation_id] = existing
				changed = true
			if _synchronise_active_deployment_reservation(
				existing,
				operation.operation_id,
				operation.mission_instance_id,
				_mission_display_name(mission),
				operation.character_ids,
				operation.reserved_item_ids,
				operation.started_tick
			):
				changed = true
		elif existing != null and existing.is_active():
			existing.release(
				campaign.campaign_tick,
				operation.status == OPERATION_STATUS_CANCELLED
			)
			changed = true
	for mission in campaign.get_active_missions():
		if mission == null or not mission.is_registered():
			continue
		if not mission.travel_operation_id.is_empty():
			continue
		var reservation_id: StringName = mission.deployment_reservation_id
		if reservation_id.is_empty():
			reservation_id = StringName("reservation.mission.%s" % mission.mission_instance_id)
			mission.deployment_reservation_id = reservation_id
			mission.revision += 1
			changed = true
		var item_ids: Array[StringName] = []
		for character_id: StringName in mission.selected_character_ids:
			for item_id: StringName in campaign.item_ids_for_character(character_id):
				if not item_ids.has(item_id):
					item_ids.append(item_id)
		var existing = campaign.get_strategic_reservation(reservation_id)
		var reservation_created_tick: int = (
			existing.created_tick if existing != null else campaign.campaign_tick
		)
		if existing == null:
			existing = StrategicReservationStateScript.new()
			existing.reservation_id = reservation_id
			campaign.strategic_reservations_by_id[reservation_id] = existing
			changed = true
		if _synchronise_active_deployment_reservation(
			existing,
			mission.mission_instance_id,
			mission.mission_instance_id,
			_mission_display_name(mission),
			mission.selected_character_ids,
			item_ids,
			reservation_created_tick
		):
			changed = true
	for reservation in campaign.get_strategic_reservations():
		if not reservation.is_active() or reservation.purpose != PURPOSE_DEPLOYMENT:
			continue
		var mission = campaign.get_active_mission(reservation.mission_instance_id)
		if mission == null or not mission.is_registered():
			reservation.release(
				campaign.campaign_tick,
				mission != null and mission.status == MISSION_STATUS_CANCELLED
			)
			changed = true
	if changed:
		campaign.revision += 1
	return changed


func _synchronise_active_deployment_reservation(
		reservation,
		owner_id: StringName,
		mission_instance_id: StringName,
		display_name: String,
		character_ids: Array[StringName],
		item_ids: Array[StringName],
		created_tick: int
) -> bool:
	if reservation == null:
		return false
	var changed: bool = false
	var unique_character_ids: Array[StringName] = []
	for character_id: StringName in character_ids:
		if not unique_character_ids.has(character_id):
			unique_character_ids.append(character_id)
	var unique_item_ids: Array[StringName] = []
	for item_id: StringName in item_ids:
		if not unique_item_ids.has(item_id):
			unique_item_ids.append(item_id)
	var resolved_display_name: String = display_name.strip_edges()
	if resolved_display_name.is_empty():
		resolved_display_name = "Mission deployment"
	if reservation.purpose != PURPOSE_DEPLOYMENT:
		reservation.purpose = PURPOSE_DEPLOYMENT
		changed = true
	if reservation.owner_id != owner_id:
		reservation.owner_id = owner_id
		changed = true
	if reservation.mission_instance_id != mission_instance_id:
		reservation.mission_instance_id = mission_instance_id
		changed = true
	if reservation.display_name != resolved_display_name:
		reservation.display_name = resolved_display_name
		changed = true
	if reservation.character_ids != unique_character_ids:
		reservation.character_ids = unique_character_ids
		changed = true
	if reservation.item_ids != unique_item_ids:
		reservation.item_ids = unique_item_ids
		changed = true
	if reservation.created_tick != maxi(0, created_tick):
		reservation.created_tick = maxi(0, created_tick)
		changed = true
	if not reservation.is_active():
		reservation.status = STATUS_ACTIVE
		reservation.released_tick = -1
		changed = true
	if changed:
		reservation.revision += 1
	return changed


func _mission_display_name(mission) -> String:
	if mission == null:
		return "Mission deployment"
	# Avoid preloading the mission registry through this early service boundary.
	# The mission definition ID remains a stable, player-readable fallback.
	return String(mission.mission_definition_id).replace("_", " ").capitalize()


func reserved_resource_amount(campaign, resource_id: StringName, excluding_reservation_id: StringName = &"") -> int:
	if campaign == null or resource_id.is_empty():
		return 0
	var total: int = 0
	for reservation in campaign.get_strategic_reservations():
		if reservation == null or not reservation.is_active():
			continue
		if not excluding_reservation_id.is_empty() and reservation.reservation_id == excluding_reservation_id:
			continue
		total += maxi(0, int(reservation.resource_quantities.get(resource_id, 0)))
	return total


func available_resource_amount(campaign, resource_id: StringName, excluding_reservation_id: StringName = &"") -> int:
	if campaign == null or campaign.resources == null:
		return 0
	return maxi(
		0,
		campaign.resources.amount(resource_id)
		- reserved_resource_amount(campaign, resource_id, excluding_reservation_id)
	)


func reserved_output_storage_space(campaign, excluding_reservation_id: StringName = &"") -> int:
	if campaign == null:
		return 0
	var total: int = 0
	for reservation in campaign.get_strategic_reservations():
		if reservation == null or not reservation.is_active():
			continue
		if not excluding_reservation_id.is_empty() and reservation.reservation_id == excluding_reservation_id:
			continue
		total += maxi(0, int(reservation.output_storage_space))
	return total


func reserve_production_candidate(
		campaign,
		reservation_id: StringName,
		owner_id: StringName,
		display_name: String,
		resource_quantities: Dictionary,
		item_ids: Array[StringName],
		output_storage_space: int
):
	if campaign == null:
		return OperationResultScript.fail(&"campaign_missing", "No campaign is loaded.")
	if reservation_id.is_empty() or owner_id.is_empty():
		return OperationResultScript.fail(&"reservation_identity_missing", "The Production reservation has no valid identity.")
	if campaign.get_strategic_reservation(reservation_id) != null:
		return OperationResultScript.fail(&"reservation_conflict", "That Production reservation already exists.")
	for raw_resource_id: Variant in resource_quantities.keys():
		var resource_id := StringName(raw_resource_id)
		var required: int = int(resource_quantities[raw_resource_id])
		if required <= 0:
			continue
		var available: int = available_resource_amount(campaign, resource_id)
		if available < required:
			return OperationResultScript.fail(
				&"production_resource_unavailable",
				"Requires %d %s; only %d is unreserved." % [required, String(resource_id).capitalize(), available]
			)
	for item_id: StringName in item_ids:
		var item_result = validate_item_available(campaign, item_id)
		if not item_result.success:
			return item_result
	var reservation = StrategicReservationStateScript.new()
	reservation.reservation_id = reservation_id
	reservation.purpose = StrategicReservationStateScript.PURPOSE_PRODUCTION_INPUT
	reservation.owner_id = owner_id
	reservation.display_name = display_name
	reservation.item_ids = item_ids.duplicate()
	for raw_resource_id: Variant in resource_quantities.keys():
		var amount: int = int(resource_quantities[raw_resource_id])
		if amount > 0:
			reservation.resource_quantities[StringName(raw_resource_id)] = amount
	reservation.output_storage_space = maxi(0, output_storage_space)
	reservation.created_tick = campaign.campaign_tick
	if not campaign.upsert_strategic_reservation(reservation):
		return OperationResultScript.fail(&"reservation_commit_failed", "The Production inputs could not be reserved.")
	return OperationResultScript.ok(reservation, "Production inputs reserved.")


func reserve_research_candidate(
		campaign,
		reservation_id: StringName,
		owner_id: StringName,
		display_name: String,
		resource_quantities: Dictionary
):
	if campaign == null:
		return OperationResultScript.fail(&"campaign_missing", "No campaign is loaded.")
	if reservation_id.is_empty() or owner_id.is_empty():
		return OperationResultScript.fail(&"reservation_identity_missing", "The Research reservation has no valid identity.")
	if campaign.get_strategic_reservation(reservation_id) != null:
		return OperationResultScript.fail(&"reservation_conflict", "That Research reservation already exists.")
	for raw_resource_id: Variant in resource_quantities.keys():
		var resource_id := StringName(raw_resource_id)
		var required: int = int(resource_quantities[raw_resource_id])
		if required <= 0:
			continue
		var available: int = available_resource_amount(campaign, resource_id)
		if available < required:
			return OperationResultScript.fail(
				&"research_resource_unavailable",
				"Requires %d %s; only %d is unreserved." % [required, String(resource_id).capitalize(), available]
			)
	var reservation = StrategicReservationStateScript.new()
	reservation.reservation_id = reservation_id
	reservation.purpose = StrategicReservationStateScript.PURPOSE_RESEARCH_INPUT
	reservation.owner_id = owner_id
	reservation.display_name = display_name
	for raw_resource_id: Variant in resource_quantities.keys():
		var amount: int = int(resource_quantities[raw_resource_id])
		if amount > 0:
			reservation.resource_quantities[StringName(raw_resource_id)] = amount
	reservation.created_tick = campaign.campaign_tick
	if not campaign.upsert_strategic_reservation(reservation):
		return OperationResultScript.fail(&"reservation_commit_failed", "The Research inputs could not be reserved.")
	return OperationResultScript.ok(reservation, "Research inputs reserved.")
