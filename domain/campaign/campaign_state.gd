class_name CampaignState
extends CharacterRosterState

const StrongholdStateScript = preload("res://domain/stronghold/stronghold_state.gd")
const StrategicReservationStateScript = preload(
	"res://domain/campaign/strategic_reservation_state.gd"
)


const CAMPAIGN_ITEM_STATE_SCRIPT = preload(
	"res://domain/campaign/campaign_item_state.gd"
)
const CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT = preload(
	"res://domain/campaign/campaign_item_location_state.gd"
)
const SHOP_TRANSACTION_STATE_SCRIPT = preload(
	"res://domain/economy/shop_transaction_state.gd"
)
const WORKFORCE_OFFER_STATE_SCRIPT = preload(
	"res://domain/economy/workforce_offer_state.gd"
)
const PRODUCTION_PROJECT_STATE_SCRIPT = preload(
	"res://domain/economy/production_project_state.gd"
)
const RESEARCH_PROJECT_STATE_SCRIPT = preload(
	"res://domain/economy/research_project_state.gd"
)

const CURRENT_SAVE_VERSION: int = 23

var items_by_id: Dictionary = {}
var captives_by_id: Dictionary = {}
# Stage 5.3E itemised Prison action records (release/ransom outcomes).
var captive_action_reports_by_id: Dictionary = {}
var next_captive_action_report_sequence: int = 1
var mission_history_by_id: Dictionary = {}
var applied_generated_item_provenance_ids: Dictionary = {}
# Stage 5.3 loadout templates describe desired equipment without owning items.
var loadout_templates_by_id: Dictionary = {}
var default_loadout_template_by_troop_type: Dictionary = {}
var next_loadout_template_sequence: int = 1

# Stage 5.3D persistent transport ownership and permanent Research knowledge.
var transports_by_id: Dictionary = {}
var completed_research_ids: Dictionary = {}
var next_transport_sequence: int = 1

# Stage 5.3D Xenonauts-style organisation. Squad membership, Stable bay
# assignment and deployment formation are authoritative campaign state.
var squads_by_id: Dictionary = {}
var stable_bays_by_id: Dictionary = {}
var next_squad_sequence: int = 1

# Shared strategic reservation authority. Deployment owns the first concrete
# reservation purpose; construction and production reuse the same records later.
var strategic_reservations_by_id: Dictionary = {}

# Stage 5.3F roster recruitment and individual linear Prestige projects.
var roster_capacity: int = 12
var recruitment_offers_by_id: Dictionary = {}
var recruitment_market_revision: int = 0
var recruitment_market_month_index: int = -1
var recruitment_projects_by_id: Dictionary = {}
var prestige_projects_by_id: Dictionary = {}
var next_recruitment_project_sequence: int = 1
var next_recruit_character_sequence: int = 1
var next_prestige_project_sequence: int = 1

# Stage 5.0 campaign-shell authority. These fields belong to the single
# CampaignState root and are never mirrored in presentation or tactical state.
var campaign_id: StringName = &""
var campaign_seed: int = 0
var campaign_status: StringName = CampaignStatus.UNINITIALIZED
var campaign_tick: int = 0
var protagonist_character_id: StringName = &""
var current_region_id: StringName = &""
# Stage 5.4A Storage-owned fungible resource balances. These remain part of
# the single CampaignState root but are presented and transacted through the
# Storage domain rather than a second economy inventory.
var resources: CampaignResourceBalances = CampaignResourceBalances.new()
var shop_transactions_by_id: Dictionary = {}
var next_shop_transaction_sequence: int = 1
var next_shop_item_sequence: int = 1

# Stage 5.4B XCOM-style aggregate personnel, monthly workforce market and
# persistent Manufacturing / repair projects.
var workforce_counts_by_definition_id: Dictionary = {}
var workforce_offers_by_id: Dictionary = {}
var workforce_market_revision: int = 0
var workforce_market_month_index: int = -1
var production_projects_by_id: Dictionary = {}
var next_production_project_sequence: int = 1
var next_production_item_sequence: int = 1

# Stage 5.4C permanent organisational knowledge, discovered Research sources,
# contact unlocks and active worker-driven Research projects.
var research_projects_by_id: Dictionary = {}
var research_reservation_ids_by_project_id: Dictionary = {}
var research_source_ids: Dictionary = {}
var unlocked_shop_contact_ids: Dictionary = {}
var unlocked_capability_ids: Dictionary = {}
var next_research_project_sequence: int = 1

var active_missions_by_id: Dictionary = {}
var next_mission_sequence: int = 1
var latest_committed_result_id: StringName = &""
var agents_by_id: Dictionary = {}

# Stage 5.2a authoritative fixed stronghold state. Static grid shape remains in
# StrongholdDefinition; only campaign-owned plot state is serialized here.
var stronghold: StrongholdStateScript

# Stage 5.1d strategic operations and visible Notoriety authority.
var squad_travel_operations_by_id: Dictionary = {}
var subregion_notoriety_by_region: Dictionary = {}
var travel_notoriety_reports_by_id: Dictionary = {}
var raid_operations_by_id: Dictionary = {}
var resolved_strategic_event_ids: Dictionary = {}
var next_squad_operation_sequence: int = 1
var next_notoriety_report_sequence: int = 1
var next_raid_sequence: int = 1


func _init() -> void:
	save_version = CURRENT_SAVE_VERSION




func active_roster_count() -> int:
	var count: int = 0
	for character: PersistentCharacterState in get_characters():
		if character.persistence_scope == PersistentCharacterState.PERSISTENCE_CAMPAIGN and not character.is_dead:
			count += 1
	return count


func workforce_count(worker_definition_id: StringName) -> int:
	return maxi(0, int(workforce_counts_by_definition_id.get(worker_definition_id, 0)))


func workforce_count_for_role(role_id: StringName) -> int:
	var total: int = 0
	for raw_definition_id: Variant in workforce_counts_by_definition_id.keys():
		var definition_id := StringName(raw_definition_id)
		var definition_text: String = String(definition_id)
		if (role_id == &"manufacturing" and definition_text.begins_with("worker.manufacturing.")) or (role_id == &"research" and definition_text.begins_with("worker.research.")):
			total += workforce_count(definition_id)
	return total


func add_workforce(worker_definition_id: StringName, delta: int) -> bool:
	if worker_definition_id.is_empty() or delta == 0:
		return false
	var next_value: int = workforce_count(worker_definition_id) + delta
	if next_value < 0:
		return false
	if next_value == 0:
		workforce_counts_by_definition_id.erase(worker_definition_id)
	else:
		workforce_counts_by_definition_id[worker_definition_id] = next_value
	revision += 1
	return true


func get_workforce_offers() -> Array[WorkforceOfferState]:
	var result: Array[WorkforceOfferState] = []
	for raw: Variant in workforce_offers_by_id.values():
		var offer: WorkforceOfferState = raw as WorkforceOfferState
		if offer != null:
			result.append(offer)
	result.sort_custom(func(a: WorkforceOfferState, b: WorkforceOfferState) -> bool:
		return String(a.offer_id) < String(b.offer_id)
	)
	return result


func get_workforce_offer(offer_id: StringName) -> WorkforceOfferState:
	return workforce_offers_by_id.get(offer_id) as WorkforceOfferState


func get_production_project(project_id: StringName) -> ProductionProjectState:
	return production_projects_by_id.get(project_id) as ProductionProjectState


func get_production_projects() -> Array[ProductionProjectState]:
	var result: Array[ProductionProjectState] = []
	for raw: Variant in production_projects_by_id.values():
		var project: ProductionProjectState = raw as ProductionProjectState
		if project != null:
			result.append(project)
	result.sort_custom(func(a: ProductionProjectState, b: ProductionProjectState) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority
		if a.created_tick != b.created_tick:
			return a.created_tick < b.created_tick
		return String(a.project_id) < String(b.project_id)
	)
	return result


func get_open_production_projects() -> Array[ProductionProjectState]:
	var result: Array[ProductionProjectState] = []
	for project: ProductionProjectState in get_production_projects():
		if project.is_open():
			result.append(project)
	return result


func allocate_production_project_id() -> StringName:
	var result := StringName("production_project.%04d" % next_production_project_sequence)
	next_production_project_sequence += 1
	return result


func allocate_production_item_id() -> StringName:
	var result := StringName("item.production.%04d" % next_production_item_sequence)
	next_production_item_sequence += 1
	return unique_item_id(result)


func next_production_priority() -> int:
	var highest: int = -1
	for project: ProductionProjectState in get_open_production_projects():
		highest = maxi(highest, project.priority)
	return highest + 1


func get_research_project(project_id: StringName) -> ResearchProjectState:
	return research_projects_by_id.get(project_id) as ResearchProjectState


func get_research_projects() -> Array[ResearchProjectState]:
	var result: Array[ResearchProjectState] = []
	for raw: Variant in research_projects_by_id.values():
		var project: ResearchProjectState = raw as ResearchProjectState
		if project != null:
			result.append(project)
	result.sort_custom(func(a: ResearchProjectState, b: ResearchProjectState) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority
		if a.created_tick != b.created_tick:
			return a.created_tick < b.created_tick
		return String(a.project_id) < String(b.project_id)
	)
	return result


func get_open_research_projects() -> Array[ResearchProjectState]:
	var result: Array[ResearchProjectState] = []
	for project: ResearchProjectState in get_research_projects():
		if project.is_open():
			result.append(project)
	return result


func research_project_for_definition(research_id: StringName) -> ResearchProjectState:
	for project: ResearchProjectState in get_open_research_projects():
		if project.research_id == research_id:
			return project
	return null


func allocate_research_project_id() -> StringName:
	var result := StringName("research_project.%04d" % next_research_project_sequence)
	next_research_project_sequence += 1
	return result


func next_research_priority() -> int:
	var highest: int = -1
	for project: ResearchProjectState in get_open_research_projects():
		highest = maxi(highest, project.priority)
	return highest + 1


func research_reservation_id(project_id: StringName) -> StringName:
	return StringName(research_reservation_ids_by_project_id.get(project_id, &""))


func has_research_source(source_id: StringName) -> bool:
	return not source_id.is_empty() and research_source_ids.has(source_id)


func add_research_source(source_id: StringName) -> bool:
	if source_id.is_empty() or research_source_ids.has(source_id):
		return false
	research_source_ids[source_id] = true
	revision += 1
	return true


func has_shop_contact(contact_id: StringName) -> bool:
	return not contact_id.is_empty() and unlocked_shop_contact_ids.has(contact_id)


func has_capability(capability_id: StringName) -> bool:
	return not capability_id.is_empty() and unlocked_capability_ids.has(capability_id)


func get_recruitment_offers() -> Array[HenchmanRecruitmentOfferState]:
	var result: Array[HenchmanRecruitmentOfferState] = []
	for offer: HenchmanRecruitmentOfferState in recruitment_offers_by_id.values():
		if offer != null:
			result.append(offer)
	result.sort_custom(
		func(a: HenchmanRecruitmentOfferState, b: HenchmanRecruitmentOfferState) -> bool:
			return String(a.offer_id) < String(b.offer_id)
	)
	return result


func get_recruitment_offer(offer_id: StringName) -> HenchmanRecruitmentOfferState:
	return recruitment_offers_by_id.get(offer_id) as HenchmanRecruitmentOfferState


func get_recruitment_projects() -> Array[HenchmanRecruitmentProjectState]:
	var result: Array[HenchmanRecruitmentProjectState] = []
	for project: HenchmanRecruitmentProjectState in recruitment_projects_by_id.values():
		if project != null:
			result.append(project)
	result.sort_custom(
		func(a, b) -> bool:
			return String(a.project_id) < String(b.project_id)
	)
	return result


func get_prestige_projects() -> Array[TroopPrestigeProjectState]:
	var result: Array[TroopPrestigeProjectState] = []
	for project: TroopPrestigeProjectState in prestige_projects_by_id.values():
		if project != null:
			result.append(project)
	result.sort_custom(
		func(a, b) -> bool:
			return String(a.project_id) < String(b.project_id)
	)
	return result


func allocate_recruitment_project_id() -> StringName:
	var result := StringName("recruitment_project.%04d" % next_recruitment_project_sequence)
	next_recruitment_project_sequence += 1
	return result


func allocate_recruit_character_id(_career_id: StringName = &"") -> StringName:
	var result := StringName("character.recruit.%04d" % next_recruit_character_sequence)
	next_recruit_character_sequence += 1
	return result


func allocate_prestige_project_id() -> StringName:
	var result := StringName("prestige_project.%04d" % next_prestige_project_sequence)
	next_prestige_project_sequence += 1
	return result


func upsert_captive(captive: CampaignCaptiveState) -> bool:
	if captive == null or captive.captive_id.is_empty():
		return false
	captives_by_id[captive.captive_id] = captive
	revision += 1
	return true


func get_captive(captive_id: StringName) -> CampaignCaptiveState:
	return captives_by_id.get(captive_id) as CampaignCaptiveState


func get_captives() -> Array[CampaignCaptiveState]:
	var result: Array[CampaignCaptiveState] = []
	for raw_value: Variant in captives_by_id.values():
		var captive: CampaignCaptiveState = raw_value as CampaignCaptiveState
		if captive != null:
			result.append(captive)
	result.sort_custom(
		func(a: CampaignCaptiveState, b: CampaignCaptiveState) -> bool:
			return String(a.captive_id) < String(b.captive_id)
	)
	return result


func has_resolved_mission(mission_id: StringName) -> bool:
	return not mission_id.is_empty() and mission_history_by_id.has(mission_id)


func record_mission_result(result: MissionResult) -> bool:
	if (
		result == null
		or result.mission_id.is_empty()
		or has_resolved_mission(result.mission_id)
	):
		return false
	mission_history_by_id[result.mission_id] = result.to_dictionary()
	revision += 1
	return true


func mission_history(mission_id: StringName) -> Dictionary:
	var raw: Variant = mission_history_by_id.get(mission_id, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func has_applied_generated_item_provenance(provenance_id: StringName) -> bool:
	return (
		not provenance_id.is_empty()
		and applied_generated_item_provenance_ids.has(provenance_id)
	)


func mark_generated_item_provenance_applied(provenance_id: StringName) -> bool:
	if provenance_id.is_empty() or has_applied_generated_item_provenance(provenance_id):
		return false
	applied_generated_item_provenance_ids[provenance_id] = true
	revision += 1
	return true


func get_loadout_template(template_id: StringName) -> LoadoutTemplateState:
	return loadout_templates_by_id.get(template_id) as LoadoutTemplateState


func get_loadout_templates() -> Array[LoadoutTemplateState]:
	var result: Array[LoadoutTemplateState] = []
	for raw_template: Variant in loadout_templates_by_id.values():
		var template: LoadoutTemplateState = raw_template as LoadoutTemplateState
		if template != null:
			result.append(template)
	result.sort_custom(
		func(a: LoadoutTemplateState, b: LoadoutTemplateState) -> bool:
			if a.is_authored != b.is_authored:
				return a.is_authored
			return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	return result


func upsert_loadout_template(template: LoadoutTemplateState) -> bool:
	if template == null or template.template_id.is_empty():
		return false
	loadout_templates_by_id[template.template_id] = template
	revision += 1
	return true


func remove_loadout_template(template_id: StringName) -> bool:
	var template: LoadoutTemplateState = get_loadout_template(template_id)
	if template == null or template.is_authored:
		return false
	loadout_templates_by_id.erase(template_id)
	for character: PersistentCharacterState in get_characters():
		if character.preferred_loadout_template_id == template_id:
			character.preferred_loadout_template_id = &""
			character.revision += 1
	revision += 1
	return true


func next_loadout_template_id() -> StringName:
	var candidate := StringName("loadout.player.%04d" % next_loadout_template_sequence)
	while loadout_templates_by_id.has(candidate):
		next_loadout_template_sequence += 1
		candidate = StringName("loadout.player.%04d" % next_loadout_template_sequence)
	next_loadout_template_sequence += 1
	return candidate


func get_transport(transport_id: StringName) -> TransportState:
	return transports_by_id.get(transport_id) as TransportState


func get_transports() -> Array[TransportState]:
	var result: Array[TransportState] = []
	for raw_transport: Variant in transports_by_id.values():
		var transport: TransportState = raw_transport as TransportState
		if transport != null:
			result.append(transport)
	result.sort_custom(
		func(a: TransportState, b: TransportState) -> bool:
			return String(a.transport_id) < String(b.transport_id)
	)
	return result


func upsert_transport(transport: TransportState) -> bool:
	if transport == null or transport.transport_id.is_empty():
		return false
	transports_by_id[transport.transport_id] = transport
	revision += 1
	return true


func get_squad(squad_id: StringName) -> CampaignSquadState:
	return squads_by_id.get(squad_id) as CampaignSquadState


func get_squads() -> Array[CampaignSquadState]:
	var result: Array[CampaignSquadState] = []
	for raw_squad: Variant in squads_by_id.values():
		var squad: CampaignSquadState = raw_squad as CampaignSquadState
		if squad != null:
			result.append(squad)
	result.sort_custom(
		func(a: CampaignSquadState, b: CampaignSquadState) -> bool:
			return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	return result


func upsert_squad(squad: CampaignSquadState) -> bool:
	if squad == null or squad.squad_id.is_empty():
		return false
	squads_by_id[squad.squad_id] = squad
	revision += 1
	return true


func next_squad_id() -> StringName:
	var candidate := StringName("squad.player.%04d" % next_squad_sequence)
	while squads_by_id.has(candidate):
		next_squad_sequence += 1
		candidate = StringName("squad.player.%04d" % next_squad_sequence)
	next_squad_sequence += 1
	return candidate


func squad_for_character(character_id: StringName) -> CampaignSquadState:
	for squad: CampaignSquadState in get_squads():
		if squad.member_character_ids.has(character_id):
			return squad
	return null


func get_stable_bay(bay_id: StringName) -> StableBayState:
	return stable_bays_by_id.get(bay_id) as StableBayState


func get_stable_bays() -> Array[StableBayState]:
	var result: Array[StableBayState] = []
	for raw_bay: Variant in stable_bays_by_id.values():
		var bay: StableBayState = raw_bay as StableBayState
		if bay != null:
			result.append(bay)
	result.sort_custom(
		func(a: StableBayState, b: StableBayState) -> bool:
			return a.bay_index < b.bay_index
	)
	return result


func upsert_stable_bay(bay: StableBayState) -> bool:
	if bay == null or bay.bay_id.is_empty():
		return false
	stable_bays_by_id[bay.bay_id] = bay
	revision += 1
	return true


func has_completed_research(research_id: StringName) -> bool:
	return not research_id.is_empty() and completed_research_ids.has(research_id)


func complete_research(research_id: StringName) -> bool:
	if research_id.is_empty() or has_completed_research(research_id):
		return false
	completed_research_ids[research_id] = true
	revision += 1
	return true


func upsert_strategic_reservation(
		reservation: StrategicReservationStateScript
) -> bool:
	if reservation == null or reservation.reservation_id.is_empty():
		return false
	strategic_reservations_by_id[reservation.reservation_id] = reservation
	revision += 1
	return true


func get_strategic_reservation(
		reservation_id: StringName
) -> StrategicReservationStateScript:
	return strategic_reservations_by_id.get(reservation_id) as StrategicReservationStateScript


func get_strategic_reservations() -> Array[StrategicReservationStateScript]:
	var result: Array[StrategicReservationStateScript] = []
	for raw_value: Variant in strategic_reservations_by_id.values():
		var reservation: StrategicReservationStateScript = raw_value as StrategicReservationStateScript
		if reservation != null:
			result.append(reservation)
	result.sort_custom(
		func(a: StrategicReservationStateScript, b: StrategicReservationStateScript) -> bool:
			return String(a.reservation_id) < String(b.reservation_id)
	)
	return result


func active_reservation_for_character(
		character_id: StringName
) -> StrategicReservationStateScript:
	for reservation: StrategicReservationStateScript in get_strategic_reservations():
		if reservation.contains_character(character_id):
			return reservation
	return null


func active_reservation_for_item(
		item_id: StringName
) -> StrategicReservationStateScript:
	for reservation: StrategicReservationStateScript in get_strategic_reservations():
		if reservation.contains_item(item_id):
			return reservation
	return null


func active_reservation_for_owner(
		owner_id: StringName
) -> StrategicReservationStateScript:
	for reservation: StrategicReservationStateScript in get_strategic_reservations():
		if reservation.is_active() and reservation.owner_id == owner_id:
			return reservation
	return null


func release_strategic_reservation(
		reservation_id: StringName,
		cancelled: bool = false
) -> bool:
	var reservation: StrategicReservationStateScript = get_strategic_reservation(
		reservation_id
	)
	if reservation == null or not reservation.release(campaign_tick, cancelled):
		return false
	revision += 1
	return true


func add_item(item) -> bool:
	if item == null or item.item_id.is_empty():
		return false
	if items_by_id.has(item.item_id):
		return false
	items_by_id[item.item_id] = item
	revision += 1
	return true


func upsert_item(item) -> bool:
	if item == null or item.item_id.is_empty():
		return false
	items_by_id[item.item_id] = item
	revision += 1
	return true


func remove_item(item_id: StringName) -> bool:
	if item_id.is_empty() or not items_by_id.has(item_id):
		return false
	items_by_id.erase(item_id)
	revision += 1
	return true


func get_item(item_id: StringName):
	return items_by_id.get(item_id)


func get_items() -> Array:
	var result: Array = []
	for value: Variant in items_by_id.values():
		var item = value
		if item != null:
			result.append(item)
	result.sort_custom(
		func(a, b) -> bool:
			return String(a.item_id) < String(b.item_id)
	)
	return result


func items_for_character(
		character_id: StringName
) -> Array:
	var result: Array = []
	for item in get_items():
		if item.location != null and item.location.belongs_to_character(character_id):
			result.append(item)
	return result


func item_ids_for_character(character_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for item in items_for_character(character_id):
		result.append(item.item_id)
	return result


func stronghold_storage_items(
		storage_id: StringName = CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.DEFAULT_STRONGHOLD_STORAGE_ID
) -> Array:
	var result: Array = []
	for item in get_items():
		if (
			item.location != null
			and item.location.location_type
			== CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.LOCATION_STRONGHOLD_STORAGE
			and item.location.owner_id == storage_id
		):
			result.append(item)
	return result


func items_in_stronghold(
		storage_id: StringName = CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.DEFAULT_STRONGHOLD_STORAGE_ID
) -> Array:
	# Compatibility alias for earlier Stage 3.14 callers.
	return stronghold_storage_items(storage_id)


func assign_item_to_character(
		item_id: StringName,
		character_id: StringName,
		container_id: StringName,
		grid_position: Vector2i = Vector2i.ZERO,
		is_rotated: bool = false
) -> bool:
	var item = get_item(item_id)
	if item == null or get_character(character_id) == null:
		return false
	item.set_location(
		CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.character_slot(
			character_id,
			container_id,
			grid_position,
			is_rotated
		)
	)
	revision += 1
	return true


func move_item_to_stronghold(
		item_id: StringName,
		storage_id: StringName = CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.DEFAULT_STRONGHOLD_STORAGE_ID,
		grid_position: Vector2i = Vector2i.ZERO
) -> bool:
	var item = get_item(item_id)
	if item == null:
		return false
	item.set_location(
		CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.stronghold_storage(storage_id, grid_position)
	)
	revision += 1
	return true


func unique_item_id(preferred_id: StringName) -> StringName:
	var base_text: String = String(preferred_id)
	if base_text.is_empty():
		base_text = "campaign.item"
	var candidate: StringName = StringName(base_text)
	if not items_by_id.has(candidate):
		return candidate
	var suffix: int = 1
	candidate = StringName("%s.%03d" % [base_text, suffix])
	while items_by_id.has(candidate):
		suffix += 1
		candidate = StringName("%s.%03d" % [base_text, suffix])
	return candidate


func allocate_shop_transaction_id() -> StringName:
	var result := StringName("shop_transaction.%06d" % next_shop_transaction_sequence)
	next_shop_transaction_sequence += 1
	while shop_transactions_by_id.has(result):
		result = StringName("shop_transaction.%06d" % next_shop_transaction_sequence)
		next_shop_transaction_sequence += 1
	revision += 1
	return result


func allocate_shop_item_id() -> StringName:
	var result := StringName("item.shop.%06d" % next_shop_item_sequence)
	next_shop_item_sequence += 1
	while items_by_id.has(result):
		result = StringName("item.shop.%06d" % next_shop_item_sequence)
		next_shop_item_sequence += 1
	revision += 1
	return result


func record_shop_transaction(transaction) -> bool:
	if transaction == null or transaction.transaction_id.is_empty():
		return false
	if shop_transactions_by_id.has(transaction.transaction_id):
		return false
	shop_transactions_by_id[transaction.transaction_id] = transaction
	revision += 1
	return true


func get_shop_transactions() -> Array:
	var result: Array = []
	for raw_transaction: Variant in shop_transactions_by_id.values():
		var transaction = raw_transaction
		if transaction != null:
			result.append(transaction)
	result.sort_custom(
		func(a, b) -> bool:
			if int(a.campaign_tick) != int(b.campaign_tick):
				return int(a.campaign_tick) < int(b.campaign_tick)
			return String(a.transaction_id) < String(b.transaction_id)
	)
	return result


func is_campaign_shell_initialized() -> bool:
	return not campaign_id.is_empty()


func next_mission_instance_id() -> StringName:
	var base_id: String = String(campaign_id)
	if base_id.is_empty():
		base_id = "campaign.uninitialized"
	var candidate := StringName("mission.%s.%04d" % [base_id, next_mission_sequence])
	while active_missions_by_id.has(candidate) or has_resolved_mission(candidate):
		next_mission_sequence += 1
		candidate = StringName("mission.%s.%04d" % [base_id, next_mission_sequence])
	next_mission_sequence += 1
	revision += 1
	return candidate


func upsert_active_mission(mission: ActiveMissionState) -> bool:
	if mission == null or mission.mission_instance_id.is_empty():
		return false
	active_missions_by_id[mission.mission_instance_id] = mission
	revision += 1
	return true


func get_active_mission(mission_instance_id: StringName) -> ActiveMissionState:
	return active_missions_by_id.get(mission_instance_id) as ActiveMissionState


func get_active_missions() -> Array[ActiveMissionState]:
	var result: Array[ActiveMissionState] = []
	for raw_value: Variant in active_missions_by_id.values():
		var mission: ActiveMissionState = raw_value as ActiveMissionState
		if mission != null:
			result.append(mission)
	result.sort_custom(
		func(a: ActiveMissionState, b: ActiveMissionState) -> bool:
			return String(a.mission_instance_id) < String(b.mission_instance_id)
	)
	return result


func first_actionable_mission() -> ActiveMissionState:
	for mission: ActiveMissionState in get_active_missions():
		if mission.status not in [
			ActiveMissionState.STATUS_RESOLVED,
			ActiveMissionState.STATUS_EXPIRED,
			ActiveMissionState.STATUS_CANCELLED,
		]:
			return mission
	return null


func get_agent(agent_id: StringName) -> AgentState:
	return agents_by_id.get(agent_id) as AgentState


func get_agents() -> Array[AgentState]:
	var result: Array[AgentState] = []
	for raw_agent: Variant in agents_by_id.values():
		var agent: AgentState = raw_agent as AgentState
		if agent != null:
			result.append(agent)
	result.sort_custom(
		func(a: AgentState, b: AgentState) -> bool:
			return String(a.agent_id) < String(b.agent_id)
	)
	return result


func upsert_agent(agent: AgentState) -> bool:
	if agent == null or agent.agent_id.is_empty():
		return false
	agents_by_id[agent.agent_id] = agent
	revision += 1
	return true


func upsert_squad_travel_operation(operation: SquadTravelOperationState) -> bool:
	if operation == null or operation.operation_id.is_empty():
		return false
	squad_travel_operations_by_id[operation.operation_id] = operation
	revision += 1
	return true


func get_squad_travel_operation(operation_id: StringName) -> SquadTravelOperationState:
	return squad_travel_operations_by_id.get(operation_id) as SquadTravelOperationState


func get_squad_travel_operations() -> Array[SquadTravelOperationState]:
	var result: Array[SquadTravelOperationState] = []
	for raw_value: Variant in squad_travel_operations_by_id.values():
		var operation: SquadTravelOperationState = raw_value as SquadTravelOperationState
		if operation != null:
			result.append(operation)
	result.sort_custom(
		func(a: SquadTravelOperationState, b: SquadTravelOperationState) -> bool:
			return String(a.operation_id) < String(b.operation_id)
	)
	return result


func current_squad_travel_operation() -> SquadTravelOperationState:
	for operation: SquadTravelOperationState in get_squad_travel_operations():
		if operation.is_active():
			return operation
	return null


func get_subregion_notoriety_states(region_id: StringName) -> Array[SubregionNotorietyState]:
	var result: Array[SubregionNotorietyState] = []
	var region_states: Dictionary = subregion_notoriety_by_region.get(region_id, {}) as Dictionary
	for raw_state: Variant in region_states.values():
		var state: SubregionNotorietyState = raw_state as SubregionNotorietyState
		if state != null:
			result.append(state)
	result.sort_custom(
		func(a: SubregionNotorietyState, b: SubregionNotorietyState) -> bool:
			return String(a.subregion_id) < String(b.subregion_id)
	)
	return result


func regional_notoriety_total(region_id: StringName) -> int:
	var total: int = 0
	for state: SubregionNotorietyState in get_subregion_notoriety_states(region_id):
		total += state.value
	return total


func active_raid_operation(region_id: StringName = &"") -> RaidOperationState:
	for raw_raid: Variant in raid_operations_by_id.values():
		var raid: RaidOperationState = raw_raid as RaidOperationState
		if raid == null or not raid.is_active():
			continue
		if region_id.is_empty() or raid.origin_region_id == region_id:
			return raid
	return null


func mark_active_mission_resolved(
		mission_instance_id: StringName,
		result_id: StringName
) -> bool:
	var mission: ActiveMissionState = get_active_mission(mission_instance_id)
	if mission == null:
		return false
	if mission.status == ActiveMissionState.STATUS_RESOLVED:
		return mission.committed_result_id == result_id
	mission.status = ActiveMissionState.STATUS_RESOLVED
	mission.committed_result_id = result_id
	var operation: SquadTravelOperationState = (
		get_squad_travel_operation(mission.travel_operation_id)
		if not mission.travel_operation_id.is_empty()
		else null
	)
	if operation != null and operation.route_plan != null:
		_begin_operation_return_journey(operation)
		for transport_id: StringName in operation.transport_instance_ids:
			var transport: TransportState = get_transport(transport_id)
			if transport != null:
				transport.status = TransportState.STATUS_RETURNING
				transport.revision += 1
	else:
		if not mission.deployment_reservation_id.is_empty():
			release_strategic_reservation(mission.deployment_reservation_id)
		for reservation: StrategicReservationStateScript in get_strategic_reservations():
			if reservation.is_active() and reservation.mission_instance_id == mission_instance_id:
				reservation.release(campaign_tick)
	latest_committed_result_id = result_id
	campaign_status = CampaignStatus.ACTIVE
	revision += 1
	return true


func _begin_operation_return_journey(operation: SquadTravelOperationState) -> void:
	var outward: SquadRoutePlan = operation.route_plan
	var duration: float = maxf(1.0, outward.total_minutes())
	var return_route := SquadRoutePlan.new()
	return_route.route_id = StringName("%s.return" % operation.operation_id)
	return_route.mission_instance_id = operation.mission_instance_id
	return_route.origin_hex = outward.destination_hex.duplicate_coord() if outward.destination_hex != null else null
	return_route.destination_hex = outward.origin_hex.duplicate_coord() if outward.origin_hex != null else null
	for index: int in range(outward.waypoint_hexes.size() - 1, -1, -1):
		var waypoint: RegionHexCoord = outward.waypoint_hexes[index]
		if waypoint != null:
			return_route.waypoint_hexes.append(waypoint.duplicate_coord())
	for index: int in range(outward.route_points.size() - 1, -1, -1):
		return_route.route_points.append(outward.route_points[index])
	return_route.cumulative_minutes.append(0.0)
	var elapsed: float = 0.0
	for index: int in range(outward.cumulative_minutes.size() - 1, 0, -1):
		var segment_duration: float = maxf(0.0, outward.cumulative_minutes[index] - outward.cumulative_minutes[index - 1])
		elapsed += segment_duration
		return_route.cumulative_minutes.append(elapsed)
	return_route.start_tick = campaign_tick
	return_route.arrival_tick = campaign_tick + maxi(1, ceili(duration))
	return_route.fastest_route_minutes = outward.fastest_route_minutes
	var return_entries: Array[TravelExposureEntry] = []
	for index: int in range(operation.exposure_entries.size() - 1, -1, -1):
		var source: TravelExposureEntry = operation.exposure_entries[index]
		if source == null:
			continue
		var entry := TravelExposureEntry.from_dictionary(source.to_dictionary())
		entry.entry_id = StringName("%s.return.exposure.%03d" % [operation.operation_id, return_entries.size()])
		entry.start_route_minutes = maxf(0.0, duration - source.end_route_minutes)
		entry.end_route_minutes = maxf(entry.start_route_minutes, duration - source.start_route_minutes)
		entry.completion_tick = campaign_tick + ceili(entry.end_route_minutes)
		entry.applied = false
		return_entries.append(entry)
	operation.route_plan = return_route
	operation.exposure_entries = return_entries
	operation.origin_site_id = operation.destination_site_id
	operation.destination_site_id = &"site.fifth_god_ruin"
	operation.return_started_tick = campaign_tick
	operation.return_arrival_tick = return_route.arrival_tick
	operation.arrival_tick = return_route.arrival_tick
	operation.arrival_event_id = StringName("squad_return_arrival.%s" % operation.operation_id)
	operation.last_resolved_arrival_event_id = &""
	var stable_bay: StableBayState = get_stable_bay(operation.stable_bay_id)
	if stable_bay != null:
		stable_bay.status = StableBayState.STATUS_RETURNING
		stable_bay.active_operation_id = operation.operation_id
		stable_bay.revision += 1
	operation.status = SquadTravelOperationState.STATUS_RETURNING
	operation.revision += 1


func advance_campaign_tick(delta_ticks: int) -> bool:
	if delta_ticks <= 0 or campaign_status != CampaignStatus.ACTIVE:
		return false
	campaign_tick += delta_ticks
	revision += 1
	return true


func set_resource_amount(resource_id: StringName, value: int) -> bool:
	if resources == null:
		resources = CampaignResourceBalances.new()
	if not resources.set_amount(resource_id, value):
		return false
	revision += 1
	return true


func validate_campaign() -> Array[String]:
	var errors: Array[String] = []
	var known_characters: Dictionary = characters_by_id
	for item in get_items():
		errors.append_array(item.validate_state())
		if item.location == null:
			continue
		if (
			item.location.location_type in [
				CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.LOCATION_CHARACTER_EQUIPMENT,
				CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.LOCATION_CHARACTER_INVENTORY,
			]
			and not known_characters.has(item.location.owner_id)
		):
			errors.append(
				"Campaign item %s references missing character %s."
				% [item.item_id, item.location.owner_id]
			)
	var active_reserved_characters: Dictionary = {}
	var active_reserved_items: Dictionary = {}
	for reservation: StrategicReservationStateScript in get_strategic_reservations():
		errors.append_array(reservation.validate_state())
		if not reservation.is_active():
			continue
		for character_id: StringName in reservation.character_ids:
			if get_character(character_id) == null:
				errors.append(
					"Strategic reservation %s references missing character %s."
					% [reservation.reservation_id, character_id]
				)
			elif active_reserved_characters.has(character_id):
				errors.append(
					"Character %s is held by more than one active reservation."
					% character_id
				)
			active_reserved_characters[character_id] = reservation.reservation_id
		for item_id: StringName in reservation.item_ids:
			var reserved_item: CampaignItemState = get_item(item_id) as CampaignItemState
			if reserved_item == null:
				errors.append(
					"Strategic reservation %s references missing item %s."
					% [reservation.reservation_id, item_id]
				)
			elif active_reserved_items.has(item_id):
				errors.append(
					"Item %s is held by more than one active reservation."
					% item_id
				)
			elif (
				reservation.purpose == StrategicReservationStateScript.PURPOSE_DEPLOYMENT
				and (
					reserved_item.location == null
					or not reservation.character_ids.has(reserved_item.location.owner_id)
				)
			):
				errors.append(
					"Deployment reservation %s no longer owns item %s through its squad."
					% [reservation.reservation_id, item_id]
				)
			active_reserved_items[item_id] = reservation.reservation_id
	for transport: TransportState in get_transports():
		errors.append_array(transport.validate_state())
	var character_squad_owner: Dictionary = {}
	for squad: CampaignSquadState in get_squads():
		errors.append_array(squad.validate_state(self))
		for character_id: StringName in squad.member_character_ids:
			if character_squad_owner.has(character_id):
				errors.append("Character %s belongs to more than one campaign squad." % character_id)
			else:
				character_squad_owner[character_id] = squad.squad_id
		if not squad.assigned_stable_bay_id.is_empty():
			var assigned_bay: StableBayState = get_stable_bay(squad.assigned_stable_bay_id)
			if assigned_bay == null or assigned_bay.assigned_squad_id != squad.squad_id:
				errors.append("Squad %s has a non-reciprocal Stable bay assignment." % squad.squad_id)
	var squad_bay_owner: Dictionary = {}
	var transport_bay_owner: Dictionary = {}
	var stable_facility_owner: Dictionary = {}
	for bay: StableBayState in get_stable_bays():
		errors.append_array(bay.validate_state(self))
		if not bay.stable_facility_id.is_empty():
			if stable_facility_owner.has(bay.stable_facility_id) and not bay.is_active():
				errors.append("Constructed Stable %s owns more than one inactive housing record." % bay.stable_facility_id)
			else:
				stable_facility_owner[bay.stable_facility_id] = bay.bay_id
		if not bay.assigned_squad_id.is_empty():
			if get_squad(bay.assigned_squad_id) == null:
				errors.append("Stable bay %s references missing squad %s." % [bay.bay_id, bay.assigned_squad_id])
			elif squad_bay_owner.has(bay.assigned_squad_id):
				errors.append("Squad %s occupies more than one Stable bay." % bay.assigned_squad_id)
			else:
				squad_bay_owner[bay.assigned_squad_id] = bay.bay_id
		if not bay.transport_asset_id.is_empty():
			var bay_transport: TransportState = get_transport(bay.transport_asset_id)
			if bay_transport == null:
				errors.append("Stable bay %s references missing transport %s." % [bay.bay_id, bay.transport_asset_id])
			elif transport_bay_owner.has(bay.transport_asset_id):
				errors.append("Transport %s occupies more than one Stable bay." % bay.transport_asset_id)
			else:
				transport_bay_owner[bay.transport_asset_id] = bay.bay_id
				if bay_transport.assigned_bay_id != bay.bay_id:
					errors.append("Transport %s has a non-reciprocal Stable bay assignment." % bay.transport_asset_id)
	for transport: TransportState in get_transports():
		if not transport.assigned_bay_id.is_empty():
			var assigned_transport_bay: StableBayState = get_stable_bay(transport.assigned_bay_id)
			if assigned_transport_bay == null or assigned_transport_bay.transport_asset_id != transport.transport_id:
				errors.append("Transport %s points to a Stable that does not house it." % transport.transport_id)
			elif transport.housed_stable_id != assigned_transport_bay.stable_facility_id:
				errors.append("Transport %s does not reference the exact Stable facility that houses it." % transport.transport_id)
	for captive: CampaignCaptiveState in get_captives():
		errors.append_array(captive.validate_state())
		if captive.status == &"held":
			var prison = stronghold.get_facility(captive.assigned_prison_id) if stronghold != null else null
			if prison == null or prison.definition_id != &"facility.prison":
				errors.append("Held captive %s references a missing or invalid Prison." % captive.captive_id)
		if (
			not captive.restraint_item_id.is_empty()
			and get_item(captive.restraint_item_id) == null
		):
			errors.append(
				"Campaign captive %s references missing restraint %s."
				% [captive.captive_id, captive.restraint_item_id]
			)
		for item_id: StringName in captive.equipment_item_ids:
			if get_item(item_id) == null:
				errors.append(
					"Campaign captive %s references missing item %s."
					% [captive.captive_id, item_id]
				)
	if is_campaign_shell_initialized():
		if campaign_seed < 0:
			errors.append("Campaign %s has an invalid seed." % campaign_id)
		if not CampaignStatus.is_valid(campaign_status):
			errors.append("Campaign %s has invalid status %s." % [campaign_id, campaign_status])
		if campaign_tick < 0:
			errors.append("Campaign %s has an invalid strategic tick." % campaign_id)
		if protagonist_character_id.is_empty():
			errors.append("Campaign %s has no protagonist." % campaign_id)
		elif get_character(protagonist_character_id) == null:
			errors.append("Campaign %s protagonist is missing from the roster." % campaign_id)
		if current_region_id.is_empty():
			errors.append("Campaign %s has no current region." % campaign_id)
		if resources == null:
			errors.append("Campaign %s has no resource balances." % campaign_id)
		else:
			errors.append_array(resources.validate_state())
		for shop_transaction in get_shop_transactions():
			errors.append_array(shop_transaction.validate_state())
		for mission: ActiveMissionState in get_active_missions():
			errors.append_array(mission.validate_state())
			if mission.is_registered():
				var mission_reservation: StrategicReservationStateScript = (
					get_strategic_reservation(mission.deployment_reservation_id)
				)
				if mission_reservation == null or not mission_reservation.is_active():
					errors.append(
						"Registered mission %s has no active deployment reservation."
						% mission.mission_instance_id
					)
				elif mission_reservation.mission_instance_id != mission.mission_instance_id:
					errors.append(
						"Registered mission %s is linked to another mission's reservation."
						% mission.mission_instance_id
					)
		if stronghold != null:
			errors.append_array(stronghold.validate_state())
		for agent: AgentState in get_agents():
			errors.append_array(agent.validate_state())
			if agent.current_region_id != current_region_id:
				errors.append(
					"Agent %s is assigned to unavailable region %s."
					% [agent.agent_id, agent.current_region_id]
				)
		var active_operation_by_transport: Dictionary = {}
		for operation: SquadTravelOperationState in get_squad_travel_operations():
			errors.append_array(operation.validate_state())
			var operation_transport_ids: Dictionary = {}
			if operation.transport_is_walking and not operation.transport_instance_ids.is_empty():
				errors.append(
					"Walking squad operation %s retains exact transport assets."
					% operation.operation_id
				)
			for transport_id: StringName in operation.transport_instance_ids:
				if operation_transport_ids.has(transport_id):
					errors.append(
						"Squad travel operation %s lists transport %s more than once."
						% [operation.operation_id, transport_id]
					)
					continue
				operation_transport_ids[transport_id] = true
				var transport: TransportState = get_transport(transport_id)
				if transport == null:
					errors.append(
						"Squad travel operation %s references missing transport %s."
						% [operation.operation_id, transport_id]
					)
					continue
				if operation.is_active():
					if active_operation_by_transport.has(transport_id):
						errors.append(
							"Transport %s is held by more than one active squad operation."
							% transport_id
						)
					else:
						active_operation_by_transport[transport_id] = operation.operation_id
					if transport.reserved_mission_id != operation.mission_instance_id:
						errors.append(
							"Transport %s is reserved for another mission instead of %s."
							% [transport_id, operation.mission_instance_id]
						)
					if transport.current_journey_id != operation.operation_id:
						errors.append(
							"Transport %s is linked to another journey instead of %s."
							% [transport_id, operation.operation_id]
						)
			if operation.is_active():
				var linked_reservation: StrategicReservationStateScript = (
					get_strategic_reservation(operation.reservation_id)
					if not operation.reservation_id.is_empty()
					else active_reservation_for_owner(operation.operation_id)
				)
				if linked_reservation == null or not linked_reservation.is_active():
					errors.append(
						"Active squad operation %s has no active deployment reservation."
						% operation.operation_id
					)
			if get_active_mission(operation.mission_instance_id) == null:
				errors.append(
					"Squad travel operation %s references missing mission %s."
					% [operation.operation_id, operation.mission_instance_id]
				)
		for transport: TransportState in get_transports():
			if not transport.is_reserved():
				continue
			if transport.current_journey_id.is_empty():
				errors.append(
					"Reserved transport %s has no active journey reference."
					% transport.transport_id
				)
				continue
			var referenced_operation: SquadTravelOperationState = get_squad_travel_operation(
				transport.current_journey_id
			)
			if referenced_operation == null or not referenced_operation.is_active():
				errors.append(
					"Reserved transport %s references a missing or inactive journey %s."
					% [transport.transport_id, transport.current_journey_id]
				)
			elif not referenced_operation.transport_instance_ids.has(transport.transport_id):
				errors.append(
					"Reserved transport %s is not owned by its referenced journey %s."
					% [transport.transport_id, transport.current_journey_id]
				)
		for local_state: SubregionNotorietyState in get_subregion_notoriety_states(current_region_id):
			errors.append_array(local_state.validate_state())
		for raw_raid: Variant in raid_operations_by_id.values():
			var raid: RaidOperationState = raw_raid as RaidOperationState
			if raid != null:
				errors.append_array(raid.validate_state())
	for raw_worker_definition_id: Variant in workforce_counts_by_definition_id.keys():
		if StringName(raw_worker_definition_id).is_empty() or int(workforce_counts_by_definition_id[raw_worker_definition_id]) < 0:
			errors.append("Campaign has an invalid workforce count.")
	for offer: WorkforceOfferState in get_workforce_offers():
		errors.append_array(offer.validate_state())
	for project: ProductionProjectState in get_production_projects():
		errors.append_array(project.validate_state())
		if not project.reservation_id.is_empty():
			var production_reservation = get_strategic_reservation(project.reservation_id)
			if project.is_open() and (production_reservation == null or not production_reservation.is_active()):
				errors.append("Open Production project %s has no active reservation." % project.project_id)
	for project: ResearchProjectState in get_research_projects():
		errors.append_array(project.validate_state())
		if project.project_id.is_empty() or project.research_id.is_empty():
			errors.append("Campaign contains an invalid Research project.")
		var research_reservation_id_value: StringName = research_reservation_id(project.project_id)
		var research_reservation = get_strategic_reservation(research_reservation_id_value)
		if project.is_open() and (research_reservation == null or not research_reservation.is_active()):
			errors.append("Open Research project %s has no active reservation." % project.project_id)
	return errors



func restore_from_dictionary(data: Dictionary) -> void:
	var restored: CampaignState = CampaignState.from_dictionary(data)
	characters_by_id = restored.characters_by_id
	items_by_id = restored.items_by_id
	captives_by_id = restored.captives_by_id
	captive_action_reports_by_id = restored.captive_action_reports_by_id
	next_captive_action_report_sequence = restored.next_captive_action_report_sequence
	mission_history_by_id = restored.mission_history_by_id
	applied_generated_item_provenance_ids = (
		restored.applied_generated_item_provenance_ids
	)
	loadout_templates_by_id = restored.loadout_templates_by_id
	default_loadout_template_by_troop_type = restored.default_loadout_template_by_troop_type
	next_loadout_template_sequence = restored.next_loadout_template_sequence
	transports_by_id = restored.transports_by_id
	completed_research_ids = restored.completed_research_ids
	next_transport_sequence = restored.next_transport_sequence
	squads_by_id = restored.squads_by_id
	stable_bays_by_id = restored.stable_bays_by_id
	next_squad_sequence = restored.next_squad_sequence
	strategic_reservations_by_id = restored.strategic_reservations_by_id
	roster_capacity = restored.roster_capacity
	recruitment_offers_by_id = restored.recruitment_offers_by_id
	recruitment_market_revision = restored.recruitment_market_revision
	recruitment_market_month_index = restored.recruitment_market_month_index
	recruitment_projects_by_id = restored.recruitment_projects_by_id
	prestige_projects_by_id = restored.prestige_projects_by_id
	next_recruitment_project_sequence = restored.next_recruitment_project_sequence
	next_recruit_character_sequence = restored.next_recruit_character_sequence
	next_prestige_project_sequence = restored.next_prestige_project_sequence
	save_version = restored.save_version
	revision = restored.revision
	applied_result_ids = restored.applied_result_ids
	campaign_id = restored.campaign_id
	campaign_seed = restored.campaign_seed
	campaign_status = restored.campaign_status
	campaign_tick = restored.campaign_tick
	protagonist_character_id = restored.protagonist_character_id
	current_region_id = restored.current_region_id
	resources = restored.resources
	shop_transactions_by_id = restored.shop_transactions_by_id
	next_shop_transaction_sequence = restored.next_shop_transaction_sequence
	next_shop_item_sequence = restored.next_shop_item_sequence
	workforce_counts_by_definition_id = restored.workforce_counts_by_definition_id
	workforce_offers_by_id = restored.workforce_offers_by_id
	workforce_market_revision = restored.workforce_market_revision
	workforce_market_month_index = restored.workforce_market_month_index
	production_projects_by_id = restored.production_projects_by_id
	next_production_project_sequence = restored.next_production_project_sequence
	next_production_item_sequence = restored.next_production_item_sequence
	research_projects_by_id = restored.research_projects_by_id
	research_reservation_ids_by_project_id = restored.research_reservation_ids_by_project_id
	research_source_ids = restored.research_source_ids
	unlocked_shop_contact_ids = restored.unlocked_shop_contact_ids
	unlocked_capability_ids = restored.unlocked_capability_ids
	next_research_project_sequence = restored.next_research_project_sequence
	active_missions_by_id = restored.active_missions_by_id
	next_mission_sequence = restored.next_mission_sequence
	latest_committed_result_id = restored.latest_committed_result_id
	agents_by_id = restored.agents_by_id
	stronghold = restored.stronghold
	squad_travel_operations_by_id = restored.squad_travel_operations_by_id
	subregion_notoriety_by_region = restored.subregion_notoriety_by_region
	travel_notoriety_reports_by_id = restored.travel_notoriety_reports_by_id
	raid_operations_by_id = restored.raid_operations_by_id
	resolved_strategic_event_ids = restored.resolved_strategic_event_ids
	next_squad_operation_sequence = restored.next_squad_operation_sequence
	next_notoriety_report_sequence = restored.next_notoriety_report_sequence
	next_raid_sequence = restored.next_raid_sequence


func to_dictionary() -> Dictionary:
	var base: Dictionary = super.to_dictionary()
	var serialized_items: Array[Dictionary] = []
	for item in get_items():
		if item.location != null and item.location.belongs_to_character(item.location.owner_id):
			var owner: PersistentCharacterState = get_character(item.location.owner_id)
			if (
				owner != null
				and owner.persistence_scope
				== PersistentCharacterState.PERSISTENCE_MISSION
			):
				continue
		serialized_items.append(item.to_dictionary())
	var serialized_captives: Array[Dictionary] = []
	for captive: CampaignCaptiveState in get_captives():
		serialized_captives.append(captive.to_dictionary())
	base["save_version"] = CURRENT_SAVE_VERSION
	base["items"] = serialized_items
	base["captives"] = serialized_captives
	base["captive_action_reports"] = captive_action_reports_by_id.duplicate(true)
	base["next_captive_action_report_sequence"] = next_captive_action_report_sequence
	var serialized_templates: Array[Dictionary] = []
	for loadout_template: LoadoutTemplateState in get_loadout_templates():
		serialized_templates.append(loadout_template.to_dictionary())
	base["loadout_templates"] = serialized_templates
	base["default_loadout_template_by_troop_type"] = default_loadout_template_by_troop_type.duplicate(true)
	base["next_loadout_template_sequence"] = next_loadout_template_sequence
	var serialized_transports: Array[Dictionary] = []
	for transport: TransportState in get_transports():
		serialized_transports.append(transport.to_dictionary())
	base["transports"] = serialized_transports
	var serialized_squads: Array[Dictionary] = []
	for squad: CampaignSquadState in get_squads():
		serialized_squads.append(squad.to_dictionary())
	base["squads"] = serialized_squads
	var serialized_bays: Array[Dictionary] = []
	for bay: StableBayState in get_stable_bays():
		serialized_bays.append(bay.to_dictionary())
	base["stable_bays"] = serialized_bays
	base["next_squad_sequence"] = next_squad_sequence
	var serialized_research: Array[String] = []
	for raw_research_id: Variant in completed_research_ids.keys():
		serialized_research.append(String(raw_research_id))
	serialized_research.sort()
	base["completed_research_ids"] = serialized_research
	base["next_transport_sequence"] = next_transport_sequence
	var serialized_reservations: Array[Dictionary] = []
	for reservation: StrategicReservationStateScript in get_strategic_reservations():
		serialized_reservations.append(reservation.to_dictionary())
	base["strategic_reservations"] = serialized_reservations
	base["roster_capacity"] = roster_capacity
	base["recruitment_market_revision"] = recruitment_market_revision
	base["recruitment_market_month_index"] = recruitment_market_month_index
	var serialized_offers: Array[Dictionary] = []
	for offer: HenchmanRecruitmentOfferState in get_recruitment_offers():
		serialized_offers.append(offer.to_dictionary())
	base["recruitment_offers"] = serialized_offers
	var serialized_recruitment_projects: Array[Dictionary] = []
	for project: HenchmanRecruitmentProjectState in get_recruitment_projects():
		serialized_recruitment_projects.append(project.to_dictionary())
	base["recruitment_projects"] = serialized_recruitment_projects
	var serialized_prestige_projects: Array[Dictionary] = []
	for project: TroopPrestigeProjectState in get_prestige_projects():
		serialized_prestige_projects.append(project.to_dictionary())
	base["prestige_projects"] = serialized_prestige_projects
	base["next_recruitment_project_sequence"] = next_recruitment_project_sequence
	base["next_recruit_character_sequence"] = next_recruit_character_sequence
	base["next_prestige_project_sequence"] = next_prestige_project_sequence
	base["mission_history"] = mission_history_by_id.duplicate(true)
	var provenance_ids: Array[String] = []
	for raw_id: Variant in applied_generated_item_provenance_ids.keys():
		provenance_ids.append(String(raw_id))
	provenance_ids.sort()
	base["applied_generated_item_provenance_ids"] = provenance_ids
	base["campaign_id"] = String(campaign_id)
	base["campaign_seed"] = campaign_seed
	base["campaign_status"] = String(campaign_status)
	base["campaign_tick"] = campaign_tick
	base["protagonist_character_id"] = String(protagonist_character_id)
	base["current_region_id"] = String(current_region_id)
	base["resources"] = (
		resources.to_dictionary() if resources != null else {}
	)
	var serialized_shop_transactions: Array[Dictionary] = []
	for shop_transaction in get_shop_transactions():
		serialized_shop_transactions.append(shop_transaction.to_dictionary())
	base["shop_transactions"] = serialized_shop_transactions
	base["next_shop_transaction_sequence"] = next_shop_transaction_sequence
	base["next_shop_item_sequence"] = next_shop_item_sequence
	base["workforce_counts"] = workforce_counts_by_definition_id.duplicate(true)
	base["workforce_market_revision"] = workforce_market_revision
	base["workforce_market_month_index"] = workforce_market_month_index
	var serialized_workforce_offers: Array[Dictionary] = []
	for offer: WorkforceOfferState in get_workforce_offers():
		serialized_workforce_offers.append(offer.to_dictionary())
	base["workforce_offers"] = serialized_workforce_offers
	var serialized_production_projects: Array[Dictionary] = []
	for project: ProductionProjectState in get_production_projects():
		serialized_production_projects.append(project.to_dictionary())
	base["production_projects"] = serialized_production_projects
	base["next_production_project_sequence"] = next_production_project_sequence
	base["next_production_item_sequence"] = next_production_item_sequence
	var serialized_research_projects: Array[Dictionary] = []
	for project: ResearchProjectState in get_research_projects():
		serialized_research_projects.append(project.to_dictionary())
	base["research_projects"] = serialized_research_projects
	base["research_reservation_ids_by_project_id"] = research_reservation_ids_by_project_id.duplicate(true)
	base["research_source_ids"] = _sorted_flag_ids(research_source_ids)
	base["unlocked_shop_contact_ids"] = _sorted_flag_ids(unlocked_shop_contact_ids)
	base["unlocked_capability_ids"] = _sorted_flag_ids(unlocked_capability_ids)
	base["next_research_project_sequence"] = next_research_project_sequence
	var serialized_missions: Array[Dictionary] = []
	for mission: ActiveMissionState in get_active_missions():
		serialized_missions.append(mission.to_dictionary())
	base["active_missions"] = serialized_missions
	base["next_mission_sequence"] = next_mission_sequence
	base["latest_committed_result_id"] = String(latest_committed_result_id)
	var serialized_agents: Array[Dictionary] = []
	for agent: AgentState in get_agents():
		serialized_agents.append(agent.to_dictionary())
	base["agents"] = serialized_agents
	base["stronghold"] = stronghold.to_dictionary() if stronghold != null else {}
	var serialized_operations: Array[Dictionary] = []
	for operation: SquadTravelOperationState in get_squad_travel_operations():
		serialized_operations.append(operation.to_dictionary())
	base["squad_travel_operations"] = serialized_operations
	var serialized_notoriety: Dictionary = {}
	var notoriety_region_ids: Array = subregion_notoriety_by_region.keys()
	notoriety_region_ids.sort()
	for raw_region_id: Variant in notoriety_region_ids:
		var region_id := StringName(raw_region_id)
		var region_states: Dictionary = subregion_notoriety_by_region.get(region_id, {}) as Dictionary
		var entries: Array[Dictionary] = []
		var subregion_ids: Array = region_states.keys()
		subregion_ids.sort()
		for raw_subregion_id: Variant in subregion_ids:
			var local: SubregionNotorietyState = region_states.get(raw_subregion_id) as SubregionNotorietyState
			if local != null:
				entries.append(local.to_dictionary())
		serialized_notoriety[String(region_id)] = entries
	base["subregion_notoriety"] = serialized_notoriety
	var serialized_reports: Array[Dictionary] = []
	for raw_report: Variant in travel_notoriety_reports_by_id.values():
		var report: TravelNotorietyReport = raw_report as TravelNotorietyReport
		if report != null:
			serialized_reports.append(report.to_dictionary())
	serialized_reports.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("report_id", "")) < String(b.get("report_id", ""))
	)
	base["travel_notoriety_reports"] = serialized_reports
	var serialized_raids: Array[Dictionary] = []
	for raw_raid: Variant in raid_operations_by_id.values():
		var raid: RaidOperationState = raw_raid as RaidOperationState
		if raid != null:
			serialized_raids.append(raid.to_dictionary())
	serialized_raids.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("operation_id", "")) < String(b.get("operation_id", ""))
	)
	base["raid_operations"] = serialized_raids
	var resolved_events: Array[String] = []
	for raw_event_id: Variant in resolved_strategic_event_ids.keys():
		resolved_events.append(String(raw_event_id))
	resolved_events.sort()
	base["resolved_strategic_event_ids"] = resolved_events
	base["next_squad_operation_sequence"] = next_squad_operation_sequence
	base["next_notoriety_report_sequence"] = next_notoriety_report_sequence
	base["next_raid_sequence"] = next_raid_sequence
	return base


static func from_dictionary(data: Dictionary) -> CampaignState:
	var campaign: CampaignState = CampaignState.new()
	campaign.revision = maxi(0, int(data.get("revision", 0)))
	campaign.campaign_id = StringName(data.get("campaign_id", ""))
	campaign.campaign_seed = maxi(0, int(data.get("campaign_seed", 0)))
	campaign.campaign_status = StringName(
		data.get("campaign_status", CampaignStatus.UNINITIALIZED)
	)
	campaign.campaign_tick = maxi(0, int(data.get("campaign_tick", 0)))
	campaign.protagonist_character_id = StringName(
		data.get("protagonist_character_id", "")
	)
	campaign.current_region_id = StringName(data.get("current_region_id", ""))
	var raw_resources: Variant = data.get("resources", {})
	var resource_data: Dictionary = {}
	if raw_resources is Dictionary:
		resource_data = raw_resources as Dictionary
	campaign.resources = CampaignResourceBalances.from_dictionary(resource_data)
	for raw_transaction: Variant in data.get("shop_transactions", []):
		if raw_transaction is Dictionary:
			var shop_transaction = SHOP_TRANSACTION_STATE_SCRIPT.from_dictionary(
				raw_transaction as Dictionary
			)
			if not shop_transaction.transaction_id.is_empty():
				campaign.shop_transactions_by_id[shop_transaction.transaction_id] = shop_transaction
	campaign.next_shop_transaction_sequence = maxi(
		1, int(data.get("next_shop_transaction_sequence", 1))
	)
	campaign.next_shop_item_sequence = maxi(1, int(data.get("next_shop_item_sequence", 1)))
	var raw_workforce_counts: Variant = data.get("workforce_counts", {})
	if raw_workforce_counts is Dictionary:
		for raw_id: Variant in (raw_workforce_counts as Dictionary).keys():
			var count: int = maxi(0, int((raw_workforce_counts as Dictionary)[raw_id]))
			if count > 0:
				campaign.workforce_counts_by_definition_id[StringName(raw_id)] = count
	campaign.workforce_market_revision = maxi(0, int(data.get("workforce_market_revision", 0)))
	campaign.workforce_market_month_index = int(data.get("workforce_market_month_index", -1))
	if int(data.get("save_version", 0)) < 23:
		# Refresh the existing monthly pool once so newly activated Research-worker
		# offers can appear without changing the normal monthly replacement rule.
		campaign.workforce_market_month_index = -1
	for raw_offer: Variant in data.get("workforce_offers", []):
		if raw_offer is Dictionary:
			var workforce_offer = WORKFORCE_OFFER_STATE_SCRIPT.from_dictionary(raw_offer as Dictionary)
			if not workforce_offer.offer_id.is_empty():
				campaign.workforce_offers_by_id[workforce_offer.offer_id] = workforce_offer
	for raw_project: Variant in data.get("production_projects", []):
		if raw_project is Dictionary:
			var production_project = PRODUCTION_PROJECT_STATE_SCRIPT.from_dictionary(raw_project as Dictionary)
			if not production_project.project_id.is_empty():
				campaign.production_projects_by_id[production_project.project_id] = production_project
	campaign.next_production_project_sequence = maxi(1, int(data.get("next_production_project_sequence", 1)))
	campaign.next_production_item_sequence = maxi(1, int(data.get("next_production_item_sequence", 1)))
	for raw_project: Variant in data.get("research_projects", []):
		if raw_project is Dictionary:
			var research_project = RESEARCH_PROJECT_STATE_SCRIPT.from_dictionary(raw_project as Dictionary)
			if not research_project.project_id.is_empty():
				campaign.research_projects_by_id[research_project.project_id] = research_project
	var raw_research_reservations: Variant = data.get("research_reservation_ids_by_project_id", {})
	if raw_research_reservations is Dictionary:
		for raw_project_id: Variant in (raw_research_reservations as Dictionary).keys():
			var project_id := StringName(raw_project_id)
			var reservation_id := StringName((raw_research_reservations as Dictionary)[raw_project_id])
			if not project_id.is_empty() and not reservation_id.is_empty():
				campaign.research_reservation_ids_by_project_id[project_id] = reservation_id
	campaign.research_source_ids = _flag_dictionary(data.get("research_source_ids", []))
	campaign.unlocked_shop_contact_ids = _flag_dictionary(data.get("unlocked_shop_contact_ids", []))
	campaign.unlocked_capability_ids = _flag_dictionary(data.get("unlocked_capability_ids", []))
	campaign.next_research_project_sequence = maxi(1, int(data.get("next_research_project_sequence", 1)))
	campaign.roster_capacity = maxi(1, int(data.get("roster_capacity", 12)))
	campaign.recruitment_market_revision = maxi(0, int(data.get("recruitment_market_revision", 0)))
	campaign.recruitment_market_month_index = int(data.get("recruitment_market_month_index", -1))
	for raw_offer: Variant in data.get("recruitment_offers", []):
		if raw_offer is Dictionary:
			var offer := HenchmanRecruitmentOfferState.from_dictionary(raw_offer as Dictionary)
			if not offer.offer_id.is_empty():
				campaign.recruitment_offers_by_id[offer.offer_id] = offer
	for raw_project: Variant in data.get("recruitment_projects", []):
		if raw_project is Dictionary:
			var recruitment_project := HenchmanRecruitmentProjectState.from_dictionary(raw_project as Dictionary)
			if not recruitment_project.project_id.is_empty():
				campaign.recruitment_projects_by_id[recruitment_project.project_id] = recruitment_project
	for raw_project: Variant in data.get("prestige_projects", []):
		if raw_project is Dictionary:
			var prestige_project := TroopPrestigeProjectState.from_dictionary(raw_project as Dictionary)
			if not prestige_project.project_id.is_empty():
				campaign.prestige_projects_by_id[prestige_project.project_id] = prestige_project
	campaign.next_recruitment_project_sequence = maxi(1, int(data.get("next_recruitment_project_sequence", 1)))
	campaign.next_recruit_character_sequence = maxi(1, int(data.get("next_recruit_character_sequence", 1)))
	campaign.next_prestige_project_sequence = maxi(1, int(data.get("next_prestige_project_sequence", 1)))
	campaign.next_mission_sequence = maxi(1, int(data.get("next_mission_sequence", 1)))
	campaign.latest_committed_result_id = StringName(
		data.get("latest_committed_result_id", "")
	)
	var raw_active_missions: Variant = data.get("active_missions", [])
	if raw_active_missions is Array:
		for raw_mission: Variant in raw_active_missions as Array:
			if not raw_mission is Dictionary:
				continue
			var active_mission := ActiveMissionState.from_dictionary(
				raw_mission as Dictionary
			)
			if not active_mission.mission_instance_id.is_empty():
				campaign.active_missions_by_id[active_mission.mission_instance_id] = active_mission

	var raw_agents: Variant = data.get("agents", [])
	if raw_agents is Array:
		for raw_agent: Variant in raw_agents as Array:
			if not raw_agent is Dictionary:
				continue
			var agent := AgentState.from_dictionary(raw_agent as Dictionary)
			if not agent.agent_id.is_empty():
				campaign.agents_by_id[agent.agent_id] = agent

	var raw_stronghold: Variant = data.get("stronghold", {})
	if raw_stronghold is Dictionary and not (raw_stronghold as Dictionary).is_empty():
		campaign.stronghold = StrongholdStateScript.from_dictionary(raw_stronghold as Dictionary)

	var raw_operations: Variant = data.get("squad_travel_operations", [])
	if raw_operations is Array:
		for raw_operation: Variant in raw_operations as Array:
			if raw_operation is Dictionary:
				var operation := SquadTravelOperationState.from_dictionary(raw_operation as Dictionary)
				if operation.transport_id in [
					&"transport.foot_column",
					&"transport.pack_train",
					&"transport.wagon_train",
					&"transport.mounted_column",
				]:
					operation.transport_id = &"transport.walking"
					operation.transport_display_name = "Walking"
					operation.transport_instance_ids.clear()
					operation.transport_assigned_count = 0
					operation.transport_passenger_capacity = 0
					operation.transport_cargo_capacity_lb = 0.0
					operation.transport_notoriety_modifier_percent = 0
					operation.transport_stable_space = 0
					operation.transport_is_walking = true
				if not operation.operation_id.is_empty():
					campaign.squad_travel_operations_by_id[operation.operation_id] = operation
	var raw_reservations: Variant = data.get("strategic_reservations", [])
	if raw_reservations is Array:
		for raw_reservation: Variant in raw_reservations as Array:
			if raw_reservation is Dictionary:
				var reservation := StrategicReservationStateScript.from_dictionary(
					raw_reservation as Dictionary
				)
				if not reservation.reservation_id.is_empty():
					campaign.strategic_reservations_by_id[reservation.reservation_id] = reservation
	var raw_notoriety: Variant = data.get("subregion_notoriety", {})
	if raw_notoriety is Dictionary:
		for raw_region_id: Variant in (raw_notoriety as Dictionary).keys():
			var region_id := StringName(raw_region_id)
			var region_states: Dictionary = {}
			var raw_states: Variant = (raw_notoriety as Dictionary).get(raw_region_id, [])
			if raw_states is Array:
				for raw_state: Variant in raw_states as Array:
					if raw_state is Dictionary:
						var local := SubregionNotorietyState.from_dictionary(raw_state as Dictionary)
						if not local.subregion_id.is_empty():
							region_states[local.subregion_id] = local
			campaign.subregion_notoriety_by_region[region_id] = region_states
	var raw_reports: Variant = data.get("travel_notoriety_reports", [])
	if raw_reports is Array:
		for raw_report: Variant in raw_reports as Array:
			if raw_report is Dictionary:
				var report := TravelNotorietyReport.from_dictionary(raw_report as Dictionary)
				if not report.report_id.is_empty():
					campaign.travel_notoriety_reports_by_id[report.report_id] = report
	var raw_raids: Variant = data.get("raid_operations", [])
	if raw_raids is Array:
		for raw_raid: Variant in raw_raids as Array:
			if raw_raid is Dictionary:
				var raid := RaidOperationState.from_dictionary(raw_raid as Dictionary)
				if not raid.operation_id.is_empty():
					campaign.raid_operations_by_id[raid.operation_id] = raid
	var raw_resolved_events: Variant = data.get("resolved_strategic_event_ids", [])
	if raw_resolved_events is Array:
		for raw_event_id: Variant in raw_resolved_events as Array:
			var event_id := StringName(raw_event_id)
			if not event_id.is_empty():
				campaign.resolved_strategic_event_ids[event_id] = true
	campaign.next_squad_operation_sequence = maxi(1, int(data.get("next_squad_operation_sequence", 1)))
	campaign.next_notoriety_report_sequence = maxi(1, int(data.get("next_notoriety_report_sequence", 1)))
	campaign.next_raid_sequence = maxi(1, int(data.get("next_raid_sequence", 1)))

	var raw_result_ids: Array = data.get("applied_result_ids", [])
	for raw_result_id: Variant in raw_result_ids:
		var result_id: StringName = StringName(raw_result_id)
		if not result_id.is_empty():
			campaign.applied_result_ids[result_id] = true

	var raw_provenance_ids: Variant = data.get(
		"applied_generated_item_provenance_ids", []
	)
	if raw_provenance_ids is Array:
		for raw_provenance_id: Variant in raw_provenance_ids as Array:
			var provenance_id := StringName(raw_provenance_id)
			if not provenance_id.is_empty():
				campaign.applied_generated_item_provenance_ids[provenance_id] = true

	var raw_characters: Array = data.get("characters", [])
	for raw_character: Variant in raw_characters:
		if not raw_character is Dictionary:
			continue
		var character_data: Dictionary = raw_character as Dictionary
		var character: PersistentCharacterState = (
			PersistentCharacterState.from_dictionary(character_data)
		)
		if character.character_id.is_empty():
			continue
		campaign.characters_by_id[character.character_id] = character
		_migrate_legacy_loadouts(campaign, character_data, character.character_id)

	var raw_items: Array = data.get("items", [])
	for raw_item: Variant in raw_items:
		if not raw_item is Dictionary:
			continue
		var item = CAMPAIGN_ITEM_STATE_SCRIPT.from_dictionary(
			raw_item as Dictionary
		)
		if item.item_id.is_empty():
			continue
		item.item_id = campaign.unique_item_id(item.item_id)
		campaign.items_by_id[item.item_id] = item

	_migrate_legacy_campaign_loot(
		campaign,
		data.get("campaign_loot_entries", [])
	)

	var raw_loadout_templates: Variant = data.get("loadout_templates", [])
	if raw_loadout_templates is Array:
		for raw_template: Variant in raw_loadout_templates as Array:
			if raw_template is Dictionary:
				var loadout_template := LoadoutTemplateState.from_dictionary(raw_template as Dictionary)
				if not loadout_template.template_id.is_empty():
					campaign.loadout_templates_by_id[loadout_template.template_id] = loadout_template
	var raw_default_templates: Variant = data.get("default_loadout_template_by_troop_type", {})
	if raw_default_templates is Dictionary:
		for raw_key: Variant in (raw_default_templates as Dictionary).keys():
			campaign.default_loadout_template_by_troop_type[StringName(raw_key)] = StringName((raw_default_templates as Dictionary).get(raw_key, ""))
	campaign.next_loadout_template_sequence = maxi(1, int(data.get("next_loadout_template_sequence", 1)))
	var raw_transports: Variant = data.get("transports", [])
	if raw_transports is Array:
		for raw_transport: Variant in raw_transports as Array:
			if raw_transport is Dictionary:
				var transport := TransportState.from_dictionary(raw_transport as Dictionary)
				if not transport.transport_id.is_empty():
					campaign.transports_by_id[transport.transport_id] = transport
	var raw_research: Variant = data.get("completed_research_ids", [])
	if raw_research is Array:
		for raw_research_id: Variant in raw_research as Array:
			var research_id := StringName(raw_research_id)
			if not research_id.is_empty():
				campaign.completed_research_ids[research_id] = true
	campaign.next_transport_sequence = maxi(1, int(data.get("next_transport_sequence", 1)))
	var raw_squads: Variant = data.get("squads", [])
	if raw_squads is Array:
		for raw_squad: Variant in raw_squads as Array:
			if raw_squad is Dictionary:
				var squad := CampaignSquadState.from_dictionary(raw_squad as Dictionary)
				if not squad.squad_id.is_empty():
					campaign.squads_by_id[squad.squad_id] = squad
	var raw_bays: Variant = data.get("stable_bays", [])
	if raw_bays is Array:
		for raw_bay: Variant in raw_bays as Array:
			if raw_bay is Dictionary:
				var bay := StableBayState.from_dictionary(raw_bay as Dictionary)
				if not bay.bay_id.is_empty():
					campaign.stable_bays_by_id[bay.bay_id] = bay
	_migrate_physical_stable_housing(campaign)
	campaign.next_squad_sequence = maxi(1, int(data.get("next_squad_sequence", 1)))
	var raw_captives: Variant = data.get("captives", [])
	if raw_captives is Array:
		for raw_captive: Variant in raw_captives as Array:
			if not raw_captive is Dictionary:
				continue
			var captive: CampaignCaptiveState = CampaignCaptiveState.from_dictionary(
				raw_captive as Dictionary
			)
			if not captive.captive_id.is_empty():
				campaign.captives_by_id[captive.captive_id] = captive
	var raw_captive_reports: Variant = data.get("captive_action_reports", {})
	if raw_captive_reports is Dictionary:
		campaign.captive_action_reports_by_id = (raw_captive_reports as Dictionary).duplicate(true)
	campaign.next_captive_action_report_sequence = maxi(
		1, int(data.get("next_captive_action_report_sequence", 1))
	)
	var raw_history: Variant = data.get("mission_history", {})
	if raw_history is Dictionary:
		for raw_mission_id: Variant in (raw_history as Dictionary).keys():
			var mission_id: StringName = StringName(raw_mission_id)
			var raw_entry: Variant = (raw_history as Dictionary).get(
				raw_mission_id, {}
			)
			if not mission_id.is_empty() and raw_entry is Dictionary:
				campaign.mission_history_by_id[mission_id] = (
					(raw_entry as Dictionary).duplicate(true)
				)
	_migrate_legacy_deployment_reservations(campaign)
	campaign.save_version = CURRENT_SAVE_VERSION
	return campaign


static func _migrate_physical_stable_housing(campaign: CampaignState) -> void:
	if campaign == null or campaign.stronghold == null:
		return
	var stable_facility_ids: Array[StringName] = []
	for facility in campaign.stronghold.get_facilities():
		if facility != null and facility.definition_id == &"facility.stables":
			stable_facility_ids.append(facility.instance_id)
	if stable_facility_ids.is_empty():
		return
	var bays: Array[StableBayState] = campaign.get_stable_bays()
	var remove_ids: Array[StringName] = []
	for index: int in range(bays.size()):
		var bay: StableBayState = bays[index]
		if index < stable_facility_ids.size():
			bay.stable_facility_id = stable_facility_ids[index]
			bay.bay_index = index
		elif bay.is_active():
			# Preserve an already-away legacy expedition until it returns. The
			# session removes this temporary duplicate housing record afterwards.
			bay.stable_facility_id = stable_facility_ids[0]
		else:
			var squad: CampaignSquadState = campaign.get_squad(bay.assigned_squad_id)
			if squad != null and squad.assigned_stable_bay_id == bay.bay_id:
				squad.assigned_stable_bay_id = &""
			var orphaned_transport: TransportState = campaign.get_transport(bay.transport_asset_id)
			if orphaned_transport != null and not orphaned_transport.is_reserved():
				orphaned_transport.assigned_bay_id = &""
				orphaned_transport.housed_stable_id = &""
				orphaned_transport.status = TransportState.STATUS_AVAILABLE
			remove_ids.append(bay.bay_id)
			continue
		if not bay.transport_asset_id.is_empty():
			var transport: TransportState = campaign.get_transport(bay.transport_asset_id)
			if transport != null:
				transport.assigned_bay_id = bay.bay_id
				transport.housed_stable_id = bay.stable_facility_id
				if not transport.is_reserved():
					transport.status = TransportState.STATUS_ASSIGNED
	for bay_id: StringName in remove_ids:
		campaign.stable_bays_by_id.erase(bay_id)


static func _migrate_legacy_deployment_reservations(
		campaign: CampaignState
) -> void:
	if campaign == null:
		return
	for operation: SquadTravelOperationState in campaign.get_squad_travel_operations():
		if operation == null or not operation.is_active():
			continue
		var reservation_id: StringName = operation.reservation_id
		if reservation_id.is_empty():
			reservation_id = StringName("reservation.%s" % operation.operation_id)
			operation.reservation_id = reservation_id
		var mission: ActiveMissionState = campaign.get_active_mission(
			operation.mission_instance_id
		)
		if mission != null:
			mission.deployment_reservation_id = reservation_id
		if campaign.get_strategic_reservation(reservation_id) != null:
			continue
		var reservation := StrategicReservationStateScript.new()
		reservation.reservation_id = reservation_id
		reservation.purpose = StrategicReservationStateScript.PURPOSE_DEPLOYMENT
		reservation.owner_id = operation.operation_id
		reservation.mission_instance_id = operation.mission_instance_id
		reservation.display_name = (
			String(mission.mission_definition_id).replace("_", " ").capitalize()
			if mission != null
			else "Registered mission"
		)
		reservation.character_ids = operation.character_ids.duplicate()
		reservation.item_ids = operation.reserved_item_ids.duplicate()
		reservation.created_tick = operation.started_tick
		campaign.strategic_reservations_by_id[reservation_id] = reservation
	for mission: ActiveMissionState in campaign.get_active_missions():
		if mission == null or not mission.is_registered():
			continue
		if not mission.travel_operation_id.is_empty():
			continue
		var mission_reservation_id: StringName = mission.deployment_reservation_id
		if mission_reservation_id.is_empty():
			mission_reservation_id = StringName(
				"reservation.mission.%s" % mission.mission_instance_id
			)
			mission.deployment_reservation_id = mission_reservation_id
		if campaign.get_strategic_reservation(mission_reservation_id) != null:
			continue
		var item_ids: Array[StringName] = []
		for character_id: StringName in mission.selected_character_ids:
			for item_id: StringName in campaign.item_ids_for_character(character_id):
				if not item_ids.has(item_id):
					item_ids.append(item_id)
		var mission_reservation := StrategicReservationStateScript.new()
		mission_reservation.reservation_id = mission_reservation_id
		mission_reservation.purpose = StrategicReservationStateScript.PURPOSE_DEPLOYMENT
		mission_reservation.owner_id = mission.mission_instance_id
		mission_reservation.mission_instance_id = mission.mission_instance_id
		mission_reservation.display_name = String(mission.mission_definition_id).replace(
			"_", " "
		).capitalize()
		mission_reservation.character_ids = mission.selected_character_ids.duplicate()
		mission_reservation.item_ids = item_ids
		mission_reservation.created_tick = campaign.campaign_tick
		campaign.strategic_reservations_by_id[mission_reservation_id] = mission_reservation


static func _sorted_flag_ids(values: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_id: Variant in values.keys():
		if bool(values[raw_id]):
			result.append(String(raw_id))
	result.sort()
	return result


static func _flag_dictionary(raw_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if raw_value is Array:
		for raw_id: Variant in raw_value as Array:
			var id := StringName(raw_id)
			if not id.is_empty():
				result[id] = true
	elif raw_value is Dictionary:
		for raw_id: Variant in (raw_value as Dictionary).keys():
			if bool((raw_value as Dictionary)[raw_id]):
				result[StringName(raw_id)] = true
	return result


static func _migrate_legacy_loadouts(
		campaign: CampaignState,
		character_data: Dictionary,
		character_id: StringName
) -> void:
	var raw_loadout: Variant = character_data.get("loadout_entries", [])
	if not raw_loadout is Array:
		return
	var legacy_entries: Array = raw_loadout as Array
	for raw_entry: Variant in legacy_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var preferred_id: StringName = StringName(entry.get("instance_id", ""))
		var item_id: StringName = campaign.unique_item_id(preferred_id)
		var container_id: StringName = StringName(
			entry.get("container_kind", CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.CONTAINER_BACKPACK)
		)
		var position: Vector2i = CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT._vector_from_value(
			entry.get("grid_position", [0, 0])
		)
		var item = CAMPAIGN_ITEM_STATE_SCRIPT.new(
			item_id,
			StringName(entry.get("definition_id", "")),
			maxi(1, int(entry.get("quantity", 1))),
			clampf(float(entry.get("condition", 1.0)), 0.0, 1.0),
			CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.character_slot(
				character_id,
				container_id,
				position
			)
		)
		campaign.items_by_id[item.item_id] = item


static func _migrate_legacy_campaign_loot(
		campaign: CampaignState,
		raw_entries: Variant
) -> void:
	if not raw_entries is Array:
		return
	var legacy_entries: Array = raw_entries as Array
	for raw_entry: Variant in legacy_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var preferred_id: StringName = StringName(entry.get("instance_id", ""))
		var item_id: StringName = campaign.unique_item_id(preferred_id)
		var position: Vector2i = CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT._vector_from_value(
			entry.get("grid_position", [0, 0])
		)
		var item = CAMPAIGN_ITEM_STATE_SCRIPT.new(
			item_id,
			StringName(entry.get("definition_id", "")),
			maxi(1, int(entry.get("quantity", 1))),
			clampf(float(entry.get("condition", 1.0)), 0.0, 1.0),
			CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.stronghold_storage(
				CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.DEFAULT_STRONGHOLD_STORAGE_ID,
				position
			)
		)
		campaign.items_by_id[item.item_id] = item
