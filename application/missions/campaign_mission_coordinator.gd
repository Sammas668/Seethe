class_name CampaignMissionCoordinator
extends RefCounted

const StrategicReservationServiceScript = preload(
	"res://application/inventory/strategic_reservation_service.gd"
)

const AUTHORED_MISSION_FACTORY_SCRIPT: Script = preload(
	"res://bootstrap/debug/authored_mission_factory.gd"
)
const CAMPAIGN_CHANGE_SET_SCRIPT: Script = preload(
	"res://application/campaign/transactions/campaign_change_set.gd"
)

var _campaign_store: CampaignStateStore
var _repository: CampaignRepository
var _catalogue: ContentCatalogue
var _commit_service: CampaignResultCommitService
var _reservation_service: StrategicReservationServiceScript
var _transport_service: SquadTransportService
var _stable_bay_service: StableBayService


func configure(
		campaign_store: CampaignStateStore,
		repository: CampaignRepository,
		catalogue: ContentCatalogue,
		reservation_service: StrategicReservationServiceScript = null,
		transport_service: SquadTransportService = null,
		stable_bay_service: StableBayService = null
) -> void:
	_campaign_store = campaign_store
	_repository = repository
	_catalogue = catalogue
	_reservation_service = (
		reservation_service
		if reservation_service != null
		else StrategicReservationServiceScript.new()
	)
	_transport_service = transport_service
	_stable_bay_service = stable_bay_service
	_commit_service = CampaignResultCommitService.new()
	_commit_service.configure(_campaign_store, _catalogue)


func register_and_create_session(
		mission_instance_id: StringName,
		selected_character_ids: Array[StringName]
) -> OperationResult:
	var campaign: CampaignState = _current_campaign()
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	if campaign.campaign_status != CampaignStatus.ACTIVE:
		return OperationResult.fail(
			&"campaign_busy",
			"The campaign cannot register another mission in its current state."
		)
	var active_mission: ActiveMissionState = campaign.get_active_mission(
		mission_instance_id
	)
	if active_mission == null:
		return OperationResult.fail(&"mission_missing", "The selected mission is unavailable.")
	if active_mission.status not in [
		ActiveMissionState.STATUS_AVAILABLE,
		ActiveMissionState.STATUS_BRIEFING,
	]:
		return OperationResult.fail(
			&"mission_not_registerable",
			"The selected mission is already registered or resolved."
		)
	var definition: MissionDefinition = MissionDefinitionRegistry.definition(
		active_mission.mission_definition_id
	)
	if definition == null:
		return OperationResult.fail(
			&"mission_definition_missing",
			"The selected mission definition could not be loaded."
		)
	var deployment_validation: OperationResult = _validate_deployment_selection(
		campaign,
		definition,
		selected_character_ids
	)
	if not deployment_validation.success:
		return deployment_validation
	var reserved_item_ids: Array[StringName] = []
	if deployment_validation.data is Dictionary:
		for raw_item_id: Variant in (deployment_validation.data as Dictionary).get("item_ids", []):
			var item_id := StringName(raw_item_id)
			if not item_id.is_empty():
				reserved_item_ids.append(item_id)
	if _repository == null or not _repository.save_safe_checkpoint(campaign):
		return OperationResult.fail(
			&"safe_checkpoint_failed",
			"The pre-mission safe checkpoint could not be written."
		)

	var post_registration_revision: int = campaign.revision + 1
	var mission_seed: int = _mission_seed(campaign, active_mission)
	var setup: MissionSetupSnapshot = AUTHORED_MISSION_FACTORY_SCRIPT.build_registered_setup(
		campaign,
		definition,
		selected_character_ids,
		active_mission.mission_instance_id,
		post_registration_revision,
		mission_seed,
		_catalogue
	)
	if setup == null or not setup.verify_integrity():
		return OperationResult.fail(
			&"mission_setup_registration_failed",
			"The immutable mission setup could not be created."
		)
	var persisted_setup: MissionSetupSnapshot = _json_stable_setup_copy(setup)
	if persisted_setup == null:
		return OperationResult.fail(
			&"mission_setup_persistence_failed",
			"The immutable mission setup could not survive campaign JSON serialization."
		)
	var reservation_id := StringName("reservation.mission.%s" % mission_instance_id)

	var changes: CampaignChangeSet = CAMPAIGN_CHANGE_SET_SCRIPT.new() as CampaignChangeSet
	changes.configure(&"mission_setup_registered", campaign.revision)
	changes.stage(
		func(candidate: CampaignState) -> OperationResult:
			var candidate_mission: ActiveMissionState = candidate.get_active_mission(
				mission_instance_id
			)
			if candidate_mission == null:
				return OperationResult.fail(
					&"mission_registration_target_missing",
					"The active mission disappeared before registration."
				)
			var reserved: OperationResult = _reservation_service.reserve_deployment_candidate(
				candidate,
				reservation_id,
				mission_instance_id,
				mission_instance_id,
				definition.display_name,
				selected_character_ids,
				reserved_item_ids
			)
			if not reserved.success:
				return reserved
			var registered := ActiveMissionState.from_dictionary(
				candidate_mission.to_dictionary()
			)
			registered.status = ActiveMissionState.STATUS_IN_TACTICAL
			registered.selected_character_ids = selected_character_ids.duplicate()
			registered.registered_setup_dictionary = persisted_setup.to_dictionary()
			registered.setup_hash = persisted_setup.finalized_setup_hash()
			registered.mission_seed = mission_seed
			registered.source_campaign_revision = post_registration_revision
			registered.deployment_reservation_id = reservation_id
			if not candidate.upsert_active_mission(registered):
				return OperationResult.fail(
					&"mission_registration_failed",
					"The active mission could not store its immutable setup."
				)
			candidate.campaign_status = CampaignStatus.IN_TACTICAL
			return OperationResult.ok(candidate)
	)
	var committed: OperationResult = _campaign_store.commit(changes)
	if not committed.success:
		return committed
	return restart_registered_mission(mission_instance_id)


func register_squad_for_travel(
		mission_instance_id: StringName,
		selected_character_ids: Array[StringName],
		route_plan: SquadRoutePlan,
		visibility_snapshot: SquadVisibilitySnapshot,
		exposure_entries: Array[TravelExposureEntry],
		transport_data: Dictionary
) -> OperationResult:
	var campaign: CampaignState = _current_campaign()
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	if campaign.campaign_status != CampaignStatus.ACTIVE:
		return OperationResult.fail(&"campaign_busy", "The campaign cannot dispatch a squad in its current state.")
	var stable_bay_id := StringName(transport_data.get("stable_bay_id", ""))
	var campaign_squad_id := StringName(transport_data.get("campaign_squad_id", ""))
	var transport_asset_id := StringName(transport_data.get("transport_asset_id", ""))
	if stable_bay_id.is_empty() or campaign_squad_id.is_empty():
		return OperationResult.fail(&"no_stable_bay", "Prepare this squad in a Stable expedition bay before dispatch.")
	var stable_bay: StableBayState = campaign.get_stable_bay(stable_bay_id)
	if stable_bay == null or stable_bay.assigned_squad_id != campaign_squad_id:
		return OperationResult.fail(&"stable_assignment_changed", "The Stable assignment changed before dispatch.")
	if _stable_bay_service == null:
		return OperationResult.fail(&"stable_service_missing", "Stable expedition validation is unavailable.")
	var formation_validation: OperationResult = _stable_bay_service.formation_validation(campaign, stable_bay)
	if not formation_validation.success:
		return formation_validation
	if not _stable_bay_service.stable_is_operational(campaign):
		return OperationResult.fail(&"stable_disabled", "The Stables must be operational before a squad can depart.")
	var active_mission: ActiveMissionState = campaign.get_active_mission(mission_instance_id)
	if active_mission == null or not active_mission.is_available():
		return OperationResult.fail(&"mission_not_available", "The selected mission is no longer available.")
	if active_mission.can_expire() and campaign.campaign_tick >= active_mission.expiry_tick:
		return OperationResult.fail(&"mission_expired", "The selected mission has expired.")
	if route_plan == null or visibility_snapshot == null:
		return OperationResult.fail(&"squad_plan_missing", "A valid route and visibility plan are required.")
	if transport_data.is_empty() or StringName(transport_data.get("id", "")).is_empty():
		return OperationResult.fail(&"squad_transport_missing", "A travel method must be prepared in the Stable.")
	if not bool(transport_data.get("availability_valid", false)):
		return OperationResult.fail(&"squad_transport_unavailable", String(transport_data.get("validation_message", "The prepared expedition is unavailable.")))
	if not bool(transport_data.get("capacity_valid", false)):
		return OperationResult.fail(&"squad_transport_capacity", String(transport_data.get("validation_message", "The squad exceeds passenger capacity.")))
	if route_plan.mission_instance_id != mission_instance_id:
		return OperationResult.fail(&"route_mission_mismatch", "The selected route belongs to another mission.")
	var route_errors: Array[String] = route_plan.validate_state()
	if not route_errors.is_empty():
		return OperationResult.fail(&"route_invalid", route_errors[0])
	var visibility_errors: Array[String] = visibility_snapshot.validate_state()
	if not visibility_errors.is_empty():
		return OperationResult.fail(&"visibility_invalid", visibility_errors[0])
	var definition: MissionDefinition = MissionDefinitionRegistry.definition(active_mission.mission_definition_id)
	if definition == null:
		return OperationResult.fail(&"mission_definition_missing", "The selected mission definition could not be loaded.")
	var deployment_validation: OperationResult = _validate_deployment_selection(campaign, definition, selected_character_ids)
	if not deployment_validation.success:
		return deployment_validation
	var reserved_item_ids: Array[StringName] = []
	if deployment_validation.data is Dictionary:
		for raw_item_id: Variant in (deployment_validation.data as Dictionary).get("item_ids", []):
			var item_id := StringName(raw_item_id)
			if not item_id.is_empty():
				reserved_item_ids.append(item_id)
	var desired_loadout_entries_by_character_id: Dictionary = _desired_loadout_snapshot(
		campaign,
		selected_character_ids
	)
	var transport_instance_ids: Array[StringName] = []
	if not transport_asset_id.is_empty():
		transport_instance_ids.append(transport_asset_id)
	if _repository == null or not _repository.save_safe_checkpoint(campaign):
		return OperationResult.fail(&"safe_checkpoint_failed", "The pre-dispatch safe checkpoint could not be written.")

	var post_registration_revision: int = campaign.revision + 1
	var mission_seed: int = _mission_seed(campaign, active_mission)
	var deployment_context: Dictionary = {
		"campaign_squad_id": String(campaign_squad_id),
		"stable_bay_id": String(stable_bay_id),
		"transport_method_id": StringName(transport_data.get("id", "transport.walking")),
		"transport_asset_id": String(transport_asset_id),
		"formation_character_ids_by_slot": transport_data.get("formation_character_ids_by_slot", {}),
	}
	var setup: MissionSetupSnapshot = AUTHORED_MISSION_FACTORY_SCRIPT.build_registered_setup(
		campaign,
		definition,
		selected_character_ids,
		active_mission.mission_instance_id,
		post_registration_revision,
		mission_seed,
		_catalogue,
		deployment_context
	)
	if setup == null or not setup.verify_integrity():
		return OperationResult.fail(&"mission_setup_registration_failed", "The immutable mission setup could not be created.")
	var persisted_setup: MissionSetupSnapshot = _json_stable_setup_copy(setup)
	if persisted_setup == null:
		return OperationResult.fail(
			&"mission_setup_persistence_failed",
			"The immutable mission setup could not survive campaign JSON serialization."
		)
	var operation_id := StringName("squad_travel.%s.%04d" % [campaign.campaign_id, campaign.next_squad_operation_sequence])
	var reservation_id := StringName("reservation.%s" % operation_id)
	var committed_route := SquadRoutePlan.from_dictionary(route_plan.to_dictionary())
	committed_route.route_id = StringName("%s.route" % operation_id)
	committed_route.start_tick = campaign.campaign_tick
	committed_route.arrival_tick = campaign.campaign_tick + maxi(1, ceili(committed_route.total_minutes()))
	var committed_visibility := SquadVisibilitySnapshot.from_dictionary(visibility_snapshot.to_dictionary())
	committed_visibility.snapshot_id = StringName("%s.visibility" % operation_id)
	committed_visibility.created_tick = campaign.campaign_tick
	var committed_entries: Array[TravelExposureEntry] = []
	for source_entry: TravelExposureEntry in exposure_entries:
		if source_entry == null:
			continue
		var entry := TravelExposureEntry.from_dictionary(source_entry.to_dictionary())
		entry.entry_id = StringName("%s.exposure.%03d" % [operation_id, committed_entries.size()])
		entry.completion_tick = committed_route.start_tick + ceili(entry.end_route_minutes)
		entry.applied = false
		committed_entries.append(entry)

	var changes: CampaignChangeSet = CAMPAIGN_CHANGE_SET_SCRIPT.new() as CampaignChangeSet
	changes.configure(&"squad_dispatched", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		var candidate_mission: ActiveMissionState = candidate.get_active_mission(mission_instance_id)
		if candidate_mission == null or not candidate_mission.is_available():
			return OperationResult.fail(&"mission_dispatch_conflict", "The mission changed before dispatch.")
		if candidate_mission.can_expire() and candidate.campaign_tick >= candidate_mission.expiry_tick:
			return OperationResult.fail(&"mission_expired", "The mission expired before dispatch.")
		var candidate_bay: StableBayState = candidate.get_stable_bay(stable_bay_id)
		if candidate_bay == null or candidate_bay.assigned_squad_id != campaign_squad_id:
			return OperationResult.fail(&"stable_assignment_changed", "The Stable assignment changed before dispatch.")
		var bay_departure: OperationResult = _stable_bay_service.mark_departed_candidate(candidate, stable_bay_id, operation_id)
		if not bay_departure.success:
			return bay_departure
		var reserved: OperationResult = _reservation_service.reserve_deployment_candidate(
			candidate, reservation_id, operation_id, mission_instance_id, definition.display_name,
			selected_character_ids, reserved_item_ids
		)
		if not reserved.success:
			return reserved
		if _transport_service != null and not transport_instance_ids.is_empty():
			var transport_reserved: OperationResult = _transport_service.reserve_transport_candidate(
				candidate, transport_instance_ids, mission_instance_id, operation_id
			)
			if not transport_reserved.success:
				return transport_reserved
		var operation := SquadTravelOperationState.new()
		operation.operation_id = operation_id
		operation.mission_instance_id = mission_instance_id
		operation.campaign_squad_id = campaign_squad_id
		operation.stable_bay_id = stable_bay_id
		operation.transport_asset_id = transport_asset_id
		operation.formation_character_ids_by_slot = (transport_data.get("formation_character_ids_by_slot", {}) as Dictionary).duplicate(true)
		operation.route_plan = SquadRoutePlan.from_dictionary(committed_route.to_dictionary())
		operation.visibility_snapshot = SquadVisibilitySnapshot.from_dictionary(committed_visibility.to_dictionary())
		for committed_entry: TravelExposureEntry in committed_entries:
			operation.exposure_entries.append(TravelExposureEntry.from_dictionary(committed_entry.to_dictionary()))
		operation.character_ids = selected_character_ids.duplicate()
		operation.reserved_item_ids = reserved_item_ids.duplicate()
		operation.desired_loadout_entries_by_character_id = (
			desired_loadout_entries_by_character_id.duplicate(true)
		)
		operation.transport_id = StringName(transport_data.get("id", "transport.walking"))
		operation.transport_instance_ids = transport_instance_ids.duplicate()
		operation.transport_display_name = String(transport_data.get("transport_display_name", transport_data.get("display_name", "Walking")))
		operation.transport_assigned_count = 0 if bool(transport_data.get("is_walking", false)) else 1
		operation.transport_passenger_capacity = maxi(0, int(transport_data.get("total_passenger_capacity", 0)))
		operation.transport_strategic_speed_multiplier = maxf(0.01, float(transport_data.get("strategic_speed_multiplier", 1.0)))
		operation.transport_terrain_multiplier = maxf(0.01, float(transport_data.get("terrain_multiplier", 1.0)))
		operation.transport_cargo_capacity_lb = maxf(0.0, float(transport_data.get("total_cargo_capacity_lb", 0.0)))
		operation.transport_notoriety_modifier_percent = int(transport_data.get("journey_notoriety_modifier_percent", 0))
		operation.transport_stable_space = 1
		operation.transport_is_walking = bool(transport_data.get("is_walking", false))
		operation.transport_viability_label = "REMOVED"
		operation.transport_viability_explanation = "Road viability is not a transport rule."
		operation.origin_site_id = &"site.fifth_god_ruin"
		operation.destination_site_id = candidate_mission.site_id
		operation.started_tick = candidate.campaign_tick
		operation.arrival_tick = operation.route_plan.arrival_tick
		operation.status = SquadTravelOperationState.STATUS_TRAVELLING
		if _transport_service != null and not transport_instance_ids.is_empty():
			_transport_service.mark_transport_departed_candidate(candidate, transport_instance_ids)
		operation.arrival_event_id = StringName("squad_arrival.%s" % operation_id)
		operation.tactical_setup_registration_id = StringName("setup.%s" % mission_instance_id)
		operation.reservation_id = reservation_id
		var registered := ActiveMissionState.from_dictionary(candidate_mission.to_dictionary())
		registered.status = ActiveMissionState.STATUS_EN_ROUTE
		registered.selected_character_ids = selected_character_ids.duplicate()
		registered.campaign_squad_id = campaign_squad_id
		registered.stable_bay_id = stable_bay_id
		registered.transport_method_id = operation.transport_id
		registered.transport_asset_id = transport_asset_id
		registered.registered_setup_dictionary = persisted_setup.to_dictionary()
		registered.setup_hash = persisted_setup.finalized_setup_hash()
		registered.mission_seed = mission_seed
		registered.source_campaign_revision = post_registration_revision
		registered.travel_operation_id = operation_id
		registered.deployment_reservation_id = reservation_id
		registered.remaining_availability_at_dispatch = registered.remaining_minutes(candidate.campaign_tick)
		registered.expiry_suspended_tick = candidate.campaign_tick
		if not candidate.upsert_active_mission(registered):
			return OperationResult.fail(&"mission_registration_failed", "The mission could not store its travel registration.")
		candidate.next_squad_operation_sequence += 1
		if not candidate.upsert_squad_travel_operation(operation):
			return OperationResult.fail(&"squad_operation_failed", "The squad travel operation could not be stored.")
		candidate.campaign_status = CampaignStatus.ACTIVE
		return OperationResult.ok(operation)
	)
	return _campaign_store.commit(changes)


func _desired_loadout_snapshot(
		campaign: CampaignState,
		character_ids: Array[StringName]
) -> Dictionary:
	var result: Dictionary = {}
	if campaign == null:
		return result
	for character_id: StringName in character_ids:
		var entries: Array[Dictionary] = []
		for raw_item: Variant in campaign.items_for_character(character_id):
			var item: CampaignItemState = raw_item as CampaignItemState
			if item == null or item.location == null:
				continue
			entries.append({
				"definition_id": String(item.definition_id),
				"quantity": item.quantity,
				"container_id": String(item.location.container_id),
				"grid_position": [
					item.location.grid_position.x,
					item.location.grid_position.y,
				],
				"is_rotated": item.location.is_rotated,
			})
		result[String(character_id)] = entries
	return result


func _json_stable_setup_copy(setup: MissionSetupSnapshot) -> MissionSetupSnapshot:
	if setup == null or not setup.verify_integrity():
		return null
	var serialized: String = JSON.stringify(setup.to_dictionary())
	if serialized.is_empty():
		return null
	var parsed: Variant = JSON.parse_string(serialized)
	if not parsed is Dictionary:
		return null
	var restored: MissionSetupSnapshot = MissionSetupSnapshot.from_dictionary(
		parsed as Dictionary
	)
	return restored if restored != null and restored.verify_integrity() else null


func restart_registered_mission(
		mission_instance_id: StringName = &""
) -> OperationResult:
	var campaign: CampaignState = _current_campaign()
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var active_mission: ActiveMissionState = null
	if not mission_instance_id.is_empty():
		active_mission = campaign.get_active_mission(mission_instance_id)
	else:
		active_mission = campaign.first_actionable_mission()
	if active_mission == null or not active_mission.is_registered():
		return OperationResult.fail(
			&"registered_mission_missing",
			"No registered mission is available to restart."
		)
	var setup: MissionSetupSnapshot = active_mission.setup_snapshot()
	if setup == null:
		return OperationResult.fail(
			&"registered_setup_invalid",
			"The registered mission setup failed integrity verification."
		)
	var definition: MissionDefinition = MissionDefinitionRegistry.definition(
		active_mission.mission_definition_id
	)
	if definition == null:
		return OperationResult.fail(
			&"mission_definition_missing",
			"The registered mission definition could not be loaded."
		)
	var session: TacticalSession = AUTHORED_MISSION_FACTORY_SCRIPT.create_session_from_setup(
		definition,
		setup,
		_catalogue
	)
	if session == null:
		return OperationResult.fail(
			&"tactical_session_failed",
			"The registered tactical mission could not be assembled."
		)
	return OperationResult.ok(session, "Registered mission assembled from immutable setup.")


func commit_tactical_envelope(envelope: MissionCommitEnvelope) -> OperationResult:
	if envelope == null or envelope.result == null or envelope.setup == null:
		return OperationResult.fail(
			&"mission_handoff_missing",
			"The tactical mission returned no complete result envelope."
		)
	var envelope_errors: Array[String] = envelope.validate_envelope()
	if not envelope_errors.is_empty():
		return OperationResult.fail(
			&"mission_handoff_invalid",
			envelope_errors[0]
		)
	var campaign: CampaignState = _current_campaign()
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	if campaign.has_applied_result(envelope.result.result_id):
		return OperationResult.new(
			true,
			&"already_applied",
			"The tactical result was already committed; no campaign state changed.",
			envelope.result
		)
	if campaign.has_resolved_mission(envelope.result.mission_id):
		return OperationResult.new(
			true,
			&"mission_already_resolved",
			"The mission was already resolved; no campaign state changed.",
			envelope.result
		)
	var active_mission: ActiveMissionState = campaign.get_active_mission(
		envelope.result.mission_id
	)
	if active_mission == null or not active_mission.is_registered():
		return OperationResult.fail(
			&"active_mission_mismatch",
			"The tactical result does not belong to a registered active mission."
		)
	if active_mission.setup_hash != envelope.setup.finalized_setup_hash():
		return OperationResult.fail(
			&"active_mission_setup_mismatch",
			"The tactical result uses a different immutable setup."
		)
	var committed: OperationResult = _commit_service.commit_envelope(
		envelope,
		_catalogue
	)
	if not committed.success:
		return committed
	var result_code: StringName = committed.code
	if envelope.result.mission_outcome == MissionOutcome.CAMPAIGN_DEFEAT:
		result_code = &"campaign_defeat"
	return OperationResult.new(
		true,
		result_code,
		"Mission result committed exactly once.",
		envelope.result
	)


func cancel_squad_deployment(
		mission_instance_id: StringName
) -> OperationResult:
	var campaign: CampaignState = _current_campaign()
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var mission: ActiveMissionState = campaign.get_active_mission(mission_instance_id)
	if mission == null or mission.status != ActiveMissionState.STATUS_EN_ROUTE:
		return OperationResult.fail(
			&"deployment_not_cancellable",
			"Only a squad that has not yet begun travelling can be recalled."
		)
	var operation: SquadTravelOperationState = campaign.get_squad_travel_operation(
		mission.travel_operation_id
	)
	if (
		operation == null
		or operation.status != SquadTravelOperationState.STATUS_TRAVELLING
		or campaign.campaign_tick != operation.started_tick
	):
		return OperationResult.fail(
			&"deployment_already_underway",
			"The squad has already begun travelling and cannot be recalled here."
		)
	var changes: CampaignChangeSet = CAMPAIGN_CHANGE_SET_SCRIPT.new() as CampaignChangeSet
	changes.configure(&"squad_deployment_cancelled", campaign.revision)
	changes.stage(func(candidate: CampaignState) -> OperationResult:
		var candidate_mission: ActiveMissionState = candidate.get_active_mission(mission_instance_id)
		var candidate_operation: SquadTravelOperationState = candidate.get_squad_travel_operation(
			operation.operation_id
		)
		if candidate_mission == null or candidate_operation == null:
			return OperationResult.fail(&"deployment_missing", "The deployment no longer exists.")
		var released: OperationResult = _reservation_service.release_reservation_candidate(
			candidate,
			candidate_mission.deployment_reservation_id,
			true
		)
		if not released.success:
			return released
		if _transport_service != null:
			_transport_service.release_transport_candidate(
				candidate,
				candidate_operation.transport_instance_ids
			)
		if _stable_bay_service != null:
			_stable_bay_service.release_after_return_candidate(candidate, candidate_operation.stable_bay_id)
		candidate_operation.status = SquadTravelOperationState.STATUS_CANCELLED
		candidate_operation.revision += 1
		candidate_mission.status = ActiveMissionState.STATUS_AVAILABLE
		candidate_mission.registered_setup_dictionary.clear()
		candidate_mission.setup_hash = ""
		candidate_mission.selected_character_ids.clear()
		candidate_mission.campaign_squad_id = &""
		candidate_mission.stable_bay_id = &""
		candidate_mission.transport_method_id = &"transport.walking"
		candidate_mission.transport_asset_id = &""
		candidate_mission.travel_operation_id = &""
		candidate_mission.deployment_reservation_id = &""
		candidate_mission.source_campaign_revision = 0
		candidate_mission.mission_seed = 0
		if candidate_mission.remaining_availability_at_dispatch >= 0:
			candidate_mission.expiry_tick = (
				candidate.campaign_tick
				+ candidate_mission.remaining_availability_at_dispatch
			)
		candidate_mission.expiry_suspended_tick = -1
		candidate_mission.remaining_availability_at_dispatch = -1
		candidate.campaign_status = CampaignStatus.ACTIVE
		candidate.revision += 1
		return OperationResult.ok(candidate_operation, "Squad deployment cancelled.")
	)
	return _campaign_store.commit(changes)


func _validate_deployment_selection(
		campaign: CampaignState,
		definition: MissionDefinition,
		selected_character_ids: Array[StringName]
) -> OperationResult:
	if selected_character_ids.is_empty():
		return OperationResult.fail(&"squad_empty", "Select at least one character.")
	if not selected_character_ids.has(definition.protagonist_character_id):
		return OperationResult.fail(&"protagonist_required", "The protagonist must deploy.")
	if selected_character_ids.size() > definition.maximum_player_deployment:
		return OperationResult.fail(
			&"deployment_capacity_exceeded",
			"The selected squad exceeds deployment capacity."
		)
	var reserved_item_ids: Array[StringName] = []
	var seen_character_ids: Dictionary = {}
	for character_id: StringName in selected_character_ids:
		if seen_character_ids.has(character_id):
			return OperationResult.fail(
				&"duplicate_character",
				"A character was selected more than once."
			)
		seen_character_ids[character_id] = true
		var character: PersistentCharacterState = campaign.get_character(character_id)
		if character == null or character.is_dead:
			return OperationResult.fail(
				&"character_unavailable",
				"A selected character is unavailable."
			)
		var maximum_hp: int = _resolved_character_maximum_hp(campaign, character)
		if character.is_missing_or_unrecovered():
			return OperationResult.fail(
				&"character_missing_unrecovered",
				"%s is missing and cannot deploy." % character.display_name
			)
		if not character.can_deploy_with_health(maximum_hp):
			return OperationResult.fail(
				&"character_unconscious",
				"%s is unconscious and cannot deploy until enough damage has healed."
				% character.display_name
			)
		var character_availability: OperationResult = _reservation_service.validate_character_available(
			campaign,
			character_id
		)
		if not character_availability.success:
			return character_availability
		for item_id: StringName in campaign.item_ids_for_character(character_id):
			var item_availability: OperationResult = _reservation_service.validate_item_available(
				campaign,
				item_id
			)
			if not item_availability.success:
				return item_availability
			if not reserved_item_ids.has(item_id):
				reserved_item_ids.append(item_id)
	return OperationResult.ok({"item_ids": reserved_item_ids})


func _resolved_character_maximum_hp(
		campaign: CampaignState,
		character: PersistentCharacterState
) -> int:
	if campaign == null or character == null or _catalogue == null:
		return 1
	var service := CharacterResolutionService.new()
	service.configure(_catalogue)
	var snapshot: ResolvedCharacterSnapshot = service.resolve_character(
		character,
		[],
		campaign.items_for_character(character.character_id)
	)
	return maxi(1, snapshot.stat_value(&"maximum_hp", 1))


func _current_campaign() -> CampaignState:
	return _campaign_store.current_campaign() if _campaign_store != null else null


func _mission_seed(
		campaign: CampaignState,
		mission: ActiveMissionState
) -> int:
	var seed_text: String = "%d:%s:%s" % [
		campaign.campaign_seed,
		mission.mission_instance_id,
		mission.mission_definition_id,
	]
	return absi(hash(seed_text))
