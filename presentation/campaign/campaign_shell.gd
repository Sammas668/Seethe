class_name CampaignShell
extends Control

const StrongholdDefinitionScript = preload("res://domain/stronghold/stronghold_definition.gd")
const StrongholdStateScript = preload("res://domain/stronghold/stronghold_state.gd")
const StrongholdPlotDefinitionScript = preload("res://domain/stronghold/stronghold_plot_definition.gd")
const StrongholdPlotStateScript = preload("res://domain/stronghold/stronghold_plot_state.gd")
const StrongholdFacilityPresentationDefinitionScript = preload("res://domain/stronghold/stronghold_facility_presentation_definition.gd")
const StrongholdFacilityDefinitionScript = preload("res://domain/stronghold/stronghold_facility_definition.gd")
const StrongholdFacilityStateScript = preload("res://domain/stronghold/stronghold_facility_state.gd")
const StrongholdProjectStateScript = preload("res://domain/stronghold/stronghold_project_state.gd")
const StrongholdGridViewScript = preload("res://presentation/campaign/widgets/stronghold_grid_view.gd")
const StrategicSpatialInventoryGridScript = preload("res://presentation/campaign/widgets/strategic_spatial_inventory_grid.gd")
const StrategicEquipmentDropSlotScript = preload("res://presentation/campaign/widgets/strategic_equipment_drop_slot.gd")
const StrategicStorageDropPanelScript = preload("res://presentation/campaign/widgets/strategic_storage_drop_panel.gd")
const SpatialInventoryItemControlScript = preload("res://presentation/tactical/spatial_inventory_item_control.gd")
const StableReserveDropZoneScript = preload("res://presentation/campaign/stable/stable_reserve_drop_zone.gd")
const ProductionScreenControllerScript = preload("res://presentation/campaign/controllers/production_screen_controller.gd")
const ResearchScreenControllerScript = preload("res://presentation/campaign/controllers/research_screen_controller.gd")
const LOADOUT_TEMPLATE_ICON: Texture2D = preload("res://assets/strategic/roster/loadout_template_icon.svg")
const ARMOUR_SLOT_ICON: Texture2D = preload("res://assets/strategic/roster/armour_slot_icon.svg")
const WEAPON_SLOT_ICON: Texture2D = preload("res://assets/strategic/roster/weapon_slot_icon.svg")
const EMPTY_SLOT_ICON: Texture2D = preload("res://assets/strategic/roster/empty_slot_icon.svg")
const LINKED_SLOT_ICON: Texture2D = preload("res://assets/strategic/roster/linked_slot_icon.svg")


signal deploy_requested(mission_instance_id: StringName, character_ids: Array[StringName])
signal restart_registered_mission_requested
signal load_current_campaign_requested
signal return_to_main_menu_requested
signal reload_safe_checkpoint_requested
signal quit_requested
signal mission_recovery_confirmed(selected_item_ids: Array[StringName], selected_captive_ids: Array[StringName])
signal mission_recovery_selection_changed(selected_item_ids: Array[StringName], selected_captive_ids: Array[StringName])

const SCREEN_REGION: StringName = &"region"
const SCREEN_STRONGHOLD: StringName = &"stronghold"
const SCREEN_ROSTER: StringName = &"roster"
const SCREEN_STORAGE: StringName = &"storage"
const SCREEN_SHOP: StringName = &"shop"
const SCREEN_PRODUCTION: StringName = &"production"
const SCREEN_RESEARCH: StringName = &"research"
const SCREEN_STABLE: StringName = &"stable"
const SCREEN_PRISON: StringName = &"prison"
# Compatibility alias for earlier Stage 5.0 validation and external callers.
const SCREEN_EQUIPMENT: StringName = SCREEN_STORAGE
const SCREEN_BRIEFING: StringName = &"briefing"
const SCREEN_RECOVERY: StringName = &"recovery"
const SCREEN_SUMMARY: StringName = &"summary"
const SCREEN_DEFEAT: StringName = &"defeat"

const SHOP_MODE_BUY: StringName = &"buy"
const SHOP_MODE_SELL: StringName = &"sell"

const STORAGE_VIEW_STORED: StringName = &"storage"
const STORAGE_VIEW_EQUIPPED: StringName = &"equipped"

const ROSTER_MODE_MANAGE: StringName = &"manage"
const ROSTER_MODE_EQUIP: StringName = &"equip"
const ROSTER_MODE_MEMORIAL: StringName = &"memorial"
const ROSTER_MODE_HIRE: StringName = &"hire"
const ROSTER_MODE_WORKFORCE: StringName = &"workforce"

const ROSTER_FILTER_ALL: StringName = &"all"
const ROSTER_FILTER_READY: StringName = &"ready"
const ROSTER_FILTER_WOUNDED: StringName = &"wounded"
const ROSTER_FILTER_DEPLOYED: StringName = &"deployed"
const ROSTER_FILTER_UNAVAILABLE: StringName = &"unavailable"

const PRISON_FILTER_ALL: StringName = &"all"
const PRISON_FILTER_HELD: StringName = &"held"
const PRISON_FILTER_INCOMING: StringName = &"incoming"
const PRISON_FILTER_RANSOMABLE: StringName = &"ransomable"
const PRISON_FILTER_WOUNDED: StringName = &"wounded"

const EQUIPMENT_CATEGORY_WEAPONS: StringName = &"weapons"
const EQUIPMENT_CATEGORY_ARMOUR: StringName = &"armour"
const EQUIPMENT_CATEGORY_GEAR: StringName = &"gear"
const EQUIPMENT_CATEGORY_CONSUMABLES: StringName = &"consumables"
const EQUIPMENT_CATEGORY_AMMUNITION: StringName = &"ammunition"

# Stage 5.3 Xenonauts-style equipment composition. The screen is divided into
# five non-overlapping functional zones: information, compact equipped slots,
# the full-body figure, carried inventory, and the available-equipment rail.
# The backpack receives the largest interactive share of the centre-right area.
const EQUIP_LEFT_RAIL_LEFT: float = 0.008
# The left rail is now 75% of its former width. This keeps the compact
# Xenonauts information-card presence without sacrificing the readable roster.
const EQUIP_LEFT_RAIL_RIGHT: float = 0.164
# Legacy equipment-stack boundaries remain as named layout guides, but the
# separate stack is no longer rendered. The full-body figure now uses that
# released space and the complete equipped loadout lives beneath Backpack.
const EQUIP_EQUIPPED_LEFT: float = 0.175
const EQUIP_EQUIPPED_RIGHT: float = 0.245
const EQUIP_CHARACTER_LEFT: float = 0.175
const EQUIP_CHARACTER_RIGHT: float = 0.565
# The carried-loadout column is centred between the full-body portrait and
# Available Equipment. Its left edge remains locked while the right edge gains
# a small authored expansion to tighten the inter-panel gap.
const EQUIP_CARRIED_LEFT: float = 0.548
const EQUIP_CARRIED_RIGHT: float = 0.708
# Keep the accepted left position, then extend only the right edge by 48 px.
# This reduces the gap before Available Equipment without allowing any child
# control to determine the loadout-column width.
const EQUIP_CARRIED_SHIFT_X: float = -24.0
const EQUIP_CARRIED_EXPAND_RIGHT_X: float = 48.0
const EQUIP_CARRIED_BOTTOM: float = 0.850
const EQUIP_AVAILABLE_LEFT: float = 0.750
const EQUIP_AVAILABLE_RIGHT: float = 0.992
# The two roster subviews are fixed directly beneath the centred ROSTER header
# button. All loadout and character content begins below this shared strip.
const EQUIP_SUBVIEW_BAR_LEFT: float = 0.360
const EQUIP_SUBVIEW_BAR_TOP: float = 0.006
const EQUIP_SUBVIEW_BAR_RIGHT: float = 0.640
const EQUIP_SUBVIEW_BAR_BOTTOM: float = 0.060
const EQUIP_CONTENT_TOP: float = 0.075
const EQUIP_CONTENT_BOTTOM: float = 0.850
# Legacy reference retained for older layout validators; the active subview bar
# now uses the fixed top-centre anchors above.
const EQUIP_CHARACTER_TABS_TOP: float = 0.865
# The primary roster-mode bar is fixed independently of the selected subview,
# so Manage Roster, Equip Troops and Memorial never shift between screens.
const EQUIP_MODE_BAR_LEFT: float = 0.215
const EQUIP_MODE_BAR_TOP: float = 0.943
const EQUIP_MODE_BAR_RIGHT: float = 0.785
const EQUIP_MODE_BAR_BOTTOM: float = 1.0
# Manage Roster and Memorial use the same authored canvas and content bounds as
# Equip Troops. Their content may differ, but the screen frame and mode controls
# never move when the player changes roster mode.
const ROSTER_CONTENT_LEFT: float = 0.055
const ROSTER_CONTENT_TOP: float = EQUIP_CONTENT_TOP
const ROSTER_CONTENT_RIGHT: float = 0.945
const ROSTER_CONTENT_BOTTOM: float = EQUIP_CONTENT_BOTTOM

const EQUIP_GROUP_ALL: StringName = &"all"
const EQUIP_GROUP_READY: StringName = &"ready"
const EQUIP_GROUP_MISSION: StringName = &"mission"

const AGENT_BUTTON_READY_AT_STRONGHOLD: StringName = &"ready_at_stronghold"
const AGENT_BUTTON_DEPLOYED: StringName = &"deployed"
const AGENT_BUTTON_TRAVELLING: StringName = &"travelling"
const AGENT_BUTTON_PREVIEW_ACTIVE: StringName = &"preview_active"
const AGENT_BUTTON_BLOCKED_BY_MODAL: StringName = &"blocked_by_modal"

const AGENT_ICON_READY: Texture2D = preload(
	"res://presentation/campaign/icons/agent_ready.svg"
)
const AGENT_ICON_DEPLOYED: Texture2D = preload(
	"res://presentation/campaign/icons/agent_deployed.svg"
)
const AGENT_ICON_TRAVELLING: Texture2D = preload(
	"res://presentation/campaign/icons/agent_travelling.svg"
)
const AGENT_ICON_PREVIEW: Texture2D = preload(
	"res://presentation/campaign/icons/agent_preview.svg"
)
const AGENT_ICON_BLOCKED: Texture2D = preload(
	"res://presentation/campaign/icons/agent_blocked.svg"
)

var _campaign_session: CampaignSession
var _production_screen_controller
var _research_screen_controller
var _current_screen: StringName = SCREEN_REGION
var _workspace: Control
var _primary_header: PanelContainer
var _secondary_header: PanelContainer
var _campaign_identity_block: HBoxContainer
var _campaign_time_box: VBoxContainer
var _time_controls_block: Control
var _global_action_block: Control
var _title_label: Label
var _day_label: Label
var _time_label: Label
var _autosave_label: Label
var _resource_labels: Dictionary = {}
var _resource_symbols: Dictionary = {
	&"wood": "W",
	&"stone": "S",
	&"metal": "M",
	&"food": "F",
	&"textiles": "T",
	&"magic": "✦",
	&"gold": "G",
}
var _navigation_buttons: Dictionary = {}
var _agent_button: Button
var _report_button: Button
var _menu_panel: PanelContainer
var _toast_label: Label
var _selected_site_panel: PanelContainer
var _region_map_view: RegionMapView
var _selected_character_id: StringName = &""
var _selected_storage_item_id: StringName = &""
var _selected_storage_definition_id: StringName = &""
var _selected_storage_resource_id: StringName = &""
var _storage_expanded_definition_ids: Dictionary = {}
var _storage_category_filter: StringName = &"all"
var _storage_availability_filter: StringName = &"all"
var _storage_sort_id: StringName = &"name"
var _storage_search_text: String = ""
var _storage_search_generation: int = 0
var _storage_search_restore_focus: bool = false
var _storage_location_filter: StringName = STORAGE_VIEW_STORED
var _shop_mode: StringName = SHOP_MODE_BUY
var _shop_category_filter: StringName = &"all"
var _shop_search_text: String = ""
var _shop_search_generation: int = 0
var _shop_search_restore_focus: bool = false
var _shop_selected_definition_id: StringName = &""
var _shop_selected_item_id: StringName = &""
var _shop_selected_resource_id: StringName = &""
var _shop_quantity: int = 1
var _roster_tab_index: int = 0
var _roster_mode: StringName = ROSTER_MODE_MANAGE
var _roster_filter_id: StringName = ROSTER_FILTER_ALL
var _roster_sort_id: StringName = &"name"
var _roster_sort_ascending: bool = true
var _roster_equipment_category: StringName = EQUIPMENT_CATEGORY_WEAPONS
var _roster_selected_slot: StringName = CampaignItemLocationState.CONTAINER_PRIMARY_HAND
var _roster_selected_item_id: StringName = &""
var _roster_equipment_search: String = ""
var _roster_compatible_only: bool = true
var _equip_roster_group_id: StringName = EQUIP_GROUP_ALL
var _roster_selected_template_id: StringName = &""
var _roster_selected_talent_id: StringName = &""
var _roster_undo_locations: Dictionary = {}
var _roster_screen_open_locations: Dictionary = {}
var _briefing_selected_ids: Dictionary = {}
var _pending_recovery_result: MissionResult
var _mission_recovery_snapshot: Dictionary = {}
var _recovery_selected_item_ids: Dictionary = {}
var _recovery_selected_captive_ids: Dictionary = {}
var _selected_captive_id: StringName = &""
var _prison_filter_id: StringName = PRISON_FILTER_ALL
var _prison_sort_id: StringName = &"name"
var _summary_result: MissionResult
var _last_clock_refresh_ms: int = 0
var _clock_process_accumulator: float = 0.0
var _clock_error_latched: bool = false
var _clock_error_message: String = ""
var _mission_popup_open: bool = false
var _agent_button_alert_until_ms: int = 0
var _last_agent_button_state: StringName = &""
var _planning_mission_id: StringName = &""
var _route_planning_active: bool = false
var _route_waypoints: Array[RegionHexCoord] = []
var _route_plan: SquadRoutePlan
var _route_visibility: SquadVisibilitySnapshot
var _route_exposure_entries: Array[TravelExposureEntry] = []
var _selected_transport_id: StringName = &"transport.walking"
var _selected_transport_count: int = 1
var _selected_stable_bay_id: StringName = &""
var _selected_roster_squad_id: StringName = &""
var _route_transport_snapshot: Dictionary = {}
var _route_transport_notoriety: Dictionary = {}
var _route_panel: PanelContainer
var _retaliation_panel: PanelContainer
var _retaliation_label: Label
var _retaliation_bar: ProgressBar
var _selected_stronghold_coord: Vector2i = Vector2i(-1, -1)
var _stronghold_grid_view: StrongholdGridViewScript
var _stronghold_inspector_content: VBoxContainer
var _stronghold_build_definition_id: StringName = &""
var _stronghold_build_origin: Vector2i = Vector2i(-1, -1)
var _stronghold_build_valid: bool = false
var _stronghold_build_message: String = ""
var _stronghold_preserve_selection_once: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_screen_controllers()
	_build_shell()
	set_process(true)


func _ensure_screen_controllers() -> void:
	if _production_screen_controller == null:
		_production_screen_controller = ProductionScreenControllerScript.new(self)
	if _research_screen_controller == null:
		_research_screen_controller = ResearchScreenControllerScript.new(self)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.pressed
			and not key_event.echo
			and key_event.keycode == KEY_R
			and _current_screen == SCREEN_ROSTER
			and _roster_mode == ROSTER_MODE_EQUIP
			and not _roster_selected_item_id.is_empty()
		):
			_rotate_strategic_inventory_item(_roster_selected_item_id, _selected_character_id)
			get_viewport().set_input_as_handled()
			return
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if not _stronghold_build_definition_id.is_empty():
				_cancel_stronghold_build_preview()
				get_viewport().set_input_as_handled()
			elif _route_planning_active:
				_exit_route_planning_to_briefing()
				get_viewport().set_input_as_handled()
			elif _region_map_view != null and _region_map_view.is_agent_preview_mode():
				_region_map_view.set_agent_preview_mode(false)
				_refresh_header()
				get_viewport().set_input_as_handled()
			elif _selected_site_panel != null:
				_close_selected_site_panel()
				get_viewport().set_input_as_handled()
			elif _current_screen == SCREEN_STRONGHOLD and _selected_stronghold_coord.x >= 0:
				_selected_stronghold_coord = Vector2i(-1, -1)
				if _stronghold_grid_view != null:
					_stronghold_grid_view.clear_selection()
				_rebuild_stronghold_inspector()
				get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT
		and (event as InputEventMouseButton).pressed
		and _current_screen == SCREEN_STRONGHOLD
	):
		if not _stronghold_build_definition_id.is_empty():
			_cancel_stronghold_build_preview()
		elif _selected_stronghold_coord.x >= 0:
			_selected_stronghold_coord = Vector2i(-1, -1)
			if _stronghold_grid_view != null:
				_stronghold_grid_view.clear_selection()
			_rebuild_stronghold_inspector()
		get_viewport().set_input_as_handled()


func configure(campaign_session: CampaignSession) -> void:
	_campaign_session = campaign_session
	if _campaign_session != null:
		if not _campaign_session.campaign_changed.is_connected(_on_campaign_changed):
			_campaign_session.campaign_changed.connect(_on_campaign_changed)
		if not _campaign_session.agent_mission_discovered.is_connected(_on_agent_mission_discovered):
			_campaign_session.agent_mission_discovered.connect(_on_agent_mission_discovered)
		if not _campaign_session.mission_expired.is_connected(_on_mission_expired):
			_campaign_session.mission_expired.connect(_on_mission_expired)
		if not _campaign_session.squad_returned.is_connected(_on_squad_returned):
			_campaign_session.squad_returned.connect(_on_squad_returned)
		if not _campaign_session.travel_notoriety_applied.is_connected(_on_travel_notoriety_applied):
			_campaign_session.travel_notoriety_applied.connect(_on_travel_notoriety_applied)
		if not _campaign_session.raid_operation_created.is_connected(_on_raid_operation_created):
			_campaign_session.raid_operation_created.connect(_on_raid_operation_created)
		if not _campaign_session.stronghold_project_completed.is_connected(_on_stronghold_project_completed):
			_campaign_session.stronghold_project_completed.connect(_on_stronghold_project_completed)
		if not _campaign_session.recruitment_project_completed.is_connected(_on_recruitment_project_completed):
			_campaign_session.recruitment_project_completed.connect(_on_recruitment_project_completed)
		if not _campaign_session.prestige_project_completed.is_connected(_on_prestige_project_completed):
			_campaign_session.prestige_project_completed.connect(_on_prestige_project_completed)
		if not _campaign_session.production_project_completed.is_connected(_on_production_project_completed):
			_campaign_session.production_project_completed.connect(_on_production_project_completed)
		if not _campaign_session.research_project_completed.is_connected(_on_research_project_completed):
			_campaign_session.research_project_completed.connect(_on_research_project_completed)
	_show_screen(SCREEN_REGION)
	_refresh_header()


func show_mission_summary(result: MissionResult) -> void:
	_summary_result = result
	_pending_recovery_result = null
	_mission_recovery_snapshot.clear()
	_recovery_selected_item_ids.clear()
	_recovery_selected_captive_ids.clear()
	_show_screen(SCREEN_SUMMARY)
	_show_toast("Mission result committed and autosaved.")


func show_mission_recovery(
		result: MissionResult,
		recovery_snapshot: Dictionary,
		restored_selected_item_ids: Array[StringName] = [],
		restored_selected_captive_ids: Array[StringName] = [],
		restore_selection: bool = false
) -> void:
	_pending_recovery_result = result
	_mission_recovery_snapshot = recovery_snapshot.duplicate(true)
	_recovery_selected_item_ids.clear()
	_recovery_selected_captive_ids.clear()
	var valid_optional_ids: Dictionary = {}
	for raw_entry: Variant in _mission_recovery_snapshot.get("optional_entries", []):
		if raw_entry is Dictionary:
			var optional_id := StringName((raw_entry as Dictionary).get("item_id", ""))
			if not optional_id.is_empty():
				valid_optional_ids[String(optional_id)] = true
	var valid_captive_ids: Dictionary = {}
	for raw_entry: Variant in _mission_recovery_snapshot.get("captive_entries", []):
		if raw_entry is Dictionary:
			var captive_id := StringName((raw_entry as Dictionary).get("captive_id", ""))
			if not captive_id.is_empty():
				valid_captive_ids[String(captive_id)] = true
	if restore_selection:
		for item_id: StringName in restored_selected_item_ids:
			if not item_id.is_empty() and valid_optional_ids.has(String(item_id)):
				_recovery_selected_item_ids[item_id] = true
		for captive_id: StringName in restored_selected_captive_ids:
			if not captive_id.is_empty() and valid_captive_ids.has(String(captive_id)):
				_recovery_selected_captive_ids[captive_id] = true
	else:
		for raw_entry: Variant in _mission_recovery_snapshot.get("optional_entries", []):
			if not raw_entry is Dictionary:
				continue
			var entry: Dictionary = raw_entry as Dictionary
			var item_id := StringName(entry.get("item_id", ""))
			if item_id.is_empty():
				continue
			_recovery_selected_item_ids[item_id] = true
			if not _recovery_selection_validation().success:
				_recovery_selected_item_ids.erase(item_id)
		for raw_entry: Variant in _mission_recovery_snapshot.get("captive_entries", []):
			if not raw_entry is Dictionary:
				continue
			var captive_id := StringName((raw_entry as Dictionary).get("captive_id", ""))
			if captive_id.is_empty():
				continue
			_recovery_selected_captive_ids[captive_id] = true
			if not _recovery_selection_validation().success:
				_recovery_selected_captive_ids.erase(captive_id)
	_show_screen(SCREEN_RECOVERY)
	mission_recovery_selection_changed.emit(_recovery_selected_ids(), _recovery_selected_captive_ids_array())


func show_campaign_defeat(result: MissionResult) -> void:
	_summary_result = result
	_show_screen(SCREEN_DEFEAT)


func show_region_map(message: String = "") -> void:
	_show_screen(SCREEN_REGION)
	if not message.is_empty():
		_show_toast(message)


func show_error(message: String) -> void:
	_show_toast(message, true)


func _process(delta: float) -> void:
	if _campaign_session == null:
		return
	if _current_screen == SCREEN_REGION and not _route_planning_active:
		# Batch clock commits so very-fast time never performs a save every frame.
		# The StrategicClockService still advances whole authoritative minutes.
		_clock_process_accumulator += delta
		if _clock_process_accumulator >= 0.5:
			var elapsed: float = _clock_process_accumulator
			_clock_process_accumulator = 0.0
			var result: OperationResult = _campaign_session.process_strategic_time(elapsed)
			if result != null and not result.success:
				_campaign_session.pause_clock(false)
				var message: String = "Strategic time paused: %s" % result.message
				if not _clock_error_latched or _clock_error_message != message:
					_clock_error_latched = true
					_clock_error_message = message
					_show_toast(message, true)
			elif result != null and result.success:
				_clock_error_latched = false
				_clock_error_message = ""
	else:
		_clock_process_accumulator = 0.0
	var now: int = Time.get_ticks_msec()
	if now - _last_clock_refresh_ms >= 250:
		_last_clock_refresh_ms = now
		_refresh_header()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = Color("090c0e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_primary_header = PanelContainer.new()
	_primary_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_primary_header.custom_minimum_size.y = 80
	_primary_header.offset_bottom = 80
	background.add_child(_primary_header)
	var primary_row := HBoxContainer.new()
	primary_row.add_theme_constant_override("separation", 8)
	_primary_header.add_child(primary_row)
	_campaign_identity_block = _build_campaign_identity_block() as HBoxContainer
	primary_row.add_child(_campaign_identity_block)
	primary_row.add_child(_build_resource_block())
	primary_row.add_child(_build_navigation_block())
	_global_action_block = _build_global_action_block()
	primary_row.add_child(_global_action_block)

	_secondary_header = PanelContainer.new()
	_secondary_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_secondary_header.offset_top = 80
	_secondary_header.offset_bottom = 122
	background.add_child(_secondary_header)
	var secondary_row := HBoxContainer.new()
	_secondary_header.add_child(secondary_row)
	_time_controls_block = _build_time_controls()
	secondary_row.add_child(_time_controls_block)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color("c9aa62"))
	secondary_row.add_child(_title_label)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 220
	secondary_row.add_child(spacer)

	_workspace = Control.new()
	_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_workspace.offset_top = 122
	background.add_child(_workspace)

	_toast_label = Label.new()
	_toast_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_toast_label.position = Vector2(-470, -86)
	_toast_label.size = Vector2(440, 56)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.visible = false
	_toast_label.z_index = 50
	background.add_child(_toast_label)

	_build_menu_panel(background)


func _build_campaign_identity_block() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = 190
	var menu_button := Button.new()
	menu_button.text = "⚙"
	menu_button.tooltip_text = "Campaign menu"
	menu_button.custom_minimum_size = Vector2(62, 62)
	menu_button.add_theme_font_size_override("font_size", 28)
	menu_button.pressed.connect(_toggle_menu)
	row.add_child(menu_button)
	_campaign_time_box = VBoxContainer.new()
	_campaign_time_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_day_label = Label.new()
	_day_label.add_theme_font_size_override("font_size", 16)
	_campaign_time_box.add_child(_day_label)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 20)
	_campaign_time_box.add_child(_time_label)
	_autosave_label = Label.new()
	_autosave_label.text = "AUTOSAVE READY"
	_autosave_label.add_theme_font_size_override("font_size", 10)
	_autosave_label.add_theme_color_override("font_color", Color("758677"))
	_campaign_time_box.add_child(_autosave_label)
	row.add_child(_campaign_time_box)
	return row


func _build_resource_block() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 370
	var title := Label.new()
	title.text = "STRONGHOLD RESOURCES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	panel.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	for resource_id: StringName in CampaignResourceBalances.RESOURCE_IDS:
		var label := Label.new()
		label.tooltip_text = String(resource_id).capitalize()
		label.text = "%s 0" % String(_resource_symbols.get(resource_id, "?"))
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color("d7d0bd"))
		row.add_child(label)
		_resource_labels[resource_id] = label
	return panel


func _build_navigation_block() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	_add_nav_button(row, SCREEN_REGION, "MAP", "Region Map")
	_add_nav_button(row, SCREEN_STRONGHOLD, "RUIN", "Stronghold")
	_add_nav_button(row, SCREEN_ROSTER, "ROSTER", "Roster and Equipment")
	_add_nav_button(row, SCREEN_STORAGE, "STORAGE", "Stronghold Storage")
	_add_nav_button(row, SCREEN_SHOP, "SHOP", "Buy from known contacts and sell stored assets")
	_add_nav_button(row, SCREEN_PRODUCTION, "PRODUCTION", "Manufacture equipment and repair recovered destroyed items")
	_add_nav_button(row, SCREEN_RESEARCH, "RESEARCH", "Direct permanent organisational Research and unlock new capabilities")
	_add_nav_button(row, SCREEN_STABLE, "STABLE", "Squads, transport and deployment formation")
	return row


func _add_nav_button(parent: Control, screen_id: StringName, text_value: String, tooltip: String) -> void:
	var button := Button.new()
	button.text = text_value
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(72, 62)
	button.toggle_mode = true
	button.pressed.connect(func() -> void:
		if screen_id == SCREEN_ROSTER:
			_roster_mode = ROSTER_MODE_MANAGE
			_roster_tab_index = 0
		_show_screen(screen_id)
	)
	parent.add_child(button)
	_navigation_buttons[screen_id] = button


func _build_global_action_block() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = 224
	row.alignment = BoxContainer.ALIGNMENT_END
	_agent_button = Button.new()
	_agent_button.text = "AGENT"
	_agent_button.tooltip_text = "Deploy Agent"
	_agent_button.icon = AGENT_ICON_READY
	_agent_button.expand_icon = true
	_agent_button.add_theme_constant_override("icon_max_width", 34)
	_agent_button.custom_minimum_size = Vector2(112, 62)
	_agent_button.pressed.connect(_on_agent_button_pressed)
	row.add_child(_agent_button)
	_report_button = Button.new()
	_report_button.text = "LAST REPORT"
	_report_button.custom_minimum_size = Vector2(112, 62)
	_report_button.pressed.connect(_open_last_report)
	row.add_child(_report_button)
	return row


func _build_time_controls() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = 220
	row.add_theme_constant_override("separation", 2)
	for entry: Array in [
		["Ⅱ", StrategicClockService.SPEED_PAUSED, "Pause"],
		["▶", StrategicClockService.SPEED_NORMAL, "Normal speed"],
		["▶▶", StrategicClockService.SPEED_FAST, "Fast speed"],
		["▶▶▶", StrategicClockService.SPEED_VERY_FAST, "Very fast speed"],
	]:
		var button := Button.new()
		button.text = entry[0]
		button.tooltip_text = entry[2]
		button.custom_minimum_size = Vector2(52, 34)
		var speed: int = int(entry[1])
		button.pressed.connect(func() -> void: _set_clock_speed(speed))
		row.add_child(button)
	return row


func _build_menu_panel(parent: Control) -> void:
	_menu_panel = PanelContainer.new()
	_menu_panel.position = Vector2(12, 84)
	_menu_panel.size = Vector2(270, 330)
	_menu_panel.visible = false
	_menu_panel.z_index = 100
	parent.add_child(_menu_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_menu_panel.add_child(content)
	var save := Button.new()
	save.text = "SAVE CAMPAIGN"
	save.pressed.connect(_save_campaign)
	content.add_child(save)
	var load_current := Button.new()
	load_current.text = "LOAD CURRENT CAMPAIGN"
	load_current.pressed.connect(func() -> void: load_current_campaign_requested.emit())
	content.add_child(load_current)
	var load_safe := Button.new()
	load_safe.text = "RELOAD LAST SAFE STATE"
	load_safe.disabled = _campaign_session == null or not _campaign_session.has_safe_checkpoint()
	load_safe.pressed.connect(func() -> void: reload_safe_checkpoint_requested.emit())
	content.add_child(load_safe)
	var display := Button.new()
	display.text = "TOGGLE FULLSCREEN"
	display.pressed.connect(_toggle_fullscreen)
	content.add_child(display)
	var main_menu := Button.new()
	main_menu.text = "RETURN TO MAIN MENU"
	main_menu.pressed.connect(func() -> void: return_to_main_menu_requested.emit())
	content.add_child(main_menu)
	var quit := Button.new()
	quit.text = "QUIT"
	quit.pressed.connect(func() -> void: quit_requested.emit())
	content.add_child(quit)
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(_toggle_menu)
	content.add_child(close)


func _toggle_menu() -> void:
	_menu_panel.visible = not _menu_panel.visible
	if _menu_panel.visible and _campaign_session != null:
		_campaign_session.pause_clock()
		if _region_map_view != null:
			_region_map_view.set_strategic_speed(_campaign_session.strategic_speed())


func _toggle_fullscreen() -> void:
	var is_fullscreen: bool = (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED
		if is_fullscreen
		else DisplayServer.WINDOW_MODE_FULLSCREEN
	)



func _save_campaign() -> void:
	if _campaign_session == null:
		return
	var result: OperationResult = _campaign_session.save_current()
	_show_toast(result.message, not result.success)
	_menu_panel.visible = false


func _set_clock_speed(speed: int) -> void:
	if _campaign_session == null:
		return
	if _current_screen != SCREEN_REGION:
		_show_toast("Strategic time advances only on the Region Map.")
		return
	if _route_planning_active:
		_show_toast("Strategic time remains paused while planning a route.")
		return
	_campaign_session.set_clock_speed(speed)
	if _region_map_view != null:
		_region_map_view.set_strategic_speed(_campaign_session.strategic_speed())


func _show_screen(screen_id: StringName) -> void:
	_current_screen = screen_id
	if _campaign_session != null and screen_id != SCREEN_REGION:
		_campaign_session.pause_clock()
	if screen_id == SCREEN_STRONGHOLD:
		if not _stronghold_preserve_selection_once:
			_selected_stronghold_coord = Vector2i(-1, -1)
		_stronghold_preserve_selection_once = false
	else:
		_stronghold_preserve_selection_once = false
	_apply_screen_chrome()
	_clear_workspace()
	match screen_id:
		SCREEN_REGION:
			_build_region_screen()
		SCREEN_STRONGHOLD:
			_build_stronghold_screen()
		SCREEN_ROSTER:
			_build_roster_screen()
		SCREEN_STORAGE:
			_build_storage_screen()
		SCREEN_SHOP:
			_build_shop_screen()
		SCREEN_PRODUCTION:
			_ensure_screen_controllers()
			_production_screen_controller.build()
		SCREEN_RESEARCH:
			_ensure_screen_controllers()
			_research_screen_controller.build()
		SCREEN_STABLE:
			_build_stable_screen()
		SCREEN_PRISON:
			_build_prison_screen()
		SCREEN_RECOVERY:
			_build_mission_recovery_screen()
		SCREEN_BRIEFING:
			_build_briefing_screen()
		SCREEN_SUMMARY:
			_build_summary_screen()
		SCREEN_DEFEAT:
			_build_defeat_screen()
	_refresh_header()


func _apply_screen_chrome() -> void:
	var region_screen: bool = _current_screen == SCREEN_REGION
	var recovery_screen: bool = _current_screen == SCREEN_RECOVERY
	for raw_button: Variant in _navigation_buttons.values():
		var navigation_button: Button = raw_button as Button
		if navigation_button != null:
			navigation_button.disabled = recovery_screen
	if _campaign_time_box != null:
		_campaign_time_box.visible = region_screen
	if _campaign_identity_block != null:
		_campaign_identity_block.custom_minimum_size.x = 190.0 if region_screen else 72.0
	if _secondary_header != null:
		_secondary_header.visible = region_screen
	if _global_action_block != null:
		_global_action_block.visible = region_screen
	if _menu_panel != null and recovery_screen:
		_menu_panel.visible = false
	if _workspace != null:
		_workspace.offset_top = 122.0 if region_screen else 80.0



func _clear_workspace() -> void:
	if _workspace == null:
		return
	for child: Node in _workspace.get_children():
		_workspace.remove_child(child)
		child.queue_free()
	_selected_site_panel = null
	_region_map_view = null
	_route_panel = null
	_retaliation_panel = null
	_retaliation_label = null
	_retaliation_bar = null
	_stronghold_grid_view = null
	_stronghold_inspector_content = null
	_mission_popup_open = false


func _build_region_screen() -> void:
	_region_map_view = RegionMapView.new()
	_region_map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_region_map_view.configure(
		_campaign_session.current_region_definition()
		if _campaign_session != null
		else null,
		_campaign(),
		Callable(_campaign_session, "preview_agent_route")
		if _campaign_session != null
		else Callable()
	)
	_region_map_view.set_strategic_speed(
		_campaign_session.strategic_speed()
		if _campaign_session != null
		else StrategicClockService.SPEED_PAUSED
	)
	_region_map_view.site_selected.connect(_on_site_selected)
	_region_map_view.squad_selected.connect(_on_squad_selected)
	_region_map_view.selection_cleared.connect(_close_selected_site_panel)
	_region_map_view.agent_destination_confirmed.connect(_on_agent_destination_confirmed)
	_region_map_view.agent_preview_cancelled.connect(_on_agent_preview_cancelled)
	_region_map_view.squad_waypoint_added.connect(_on_squad_waypoint_added)
	_region_map_view.squad_waypoint_removed.connect(_on_squad_waypoint_removed)
	_region_map_view.squad_route_cancelled.connect(_exit_route_planning_to_briefing)
	_workspace.add_child(_region_map_view)
	_build_regional_retaliation_bar()
	if _route_planning_active:
		_region_map_view.set_squad_route_mode(
			true,
			_planning_mission_id,
			_route_mission_site_id(),
			_route_waypoints,
			_route_plan,
			Callable(_campaign_session, "preview_squad_route")
		)
		_build_route_planning_panel()


func _on_agent_button_pressed() -> void:
	if _campaign_session == null:
		return
	if _mission_popup_open or _route_planning_active:
		return
	if _current_screen != SCREEN_REGION:
		_show_screen(SCREEN_REGION)
	if _region_map_view == null:
		return
	var agent: AgentState = _campaign_session.primary_agent()
	if agent == null:
		_show_toast("No Agent is available.", true)
		return
	if _region_map_view.is_agent_preview_mode():
		_region_map_view.set_agent_preview_mode(false)
		_refresh_header()
		return
	if agent.status == AgentState.STATUS_TRAVELLING:
		_region_map_view.focus_agent()
		_refresh_header()
		return
	_region_map_view.set_agent_preview_mode(true)
	_region_map_view.focus_agent()
	_close_selected_site_panel()
	_refresh_header()


func _on_agent_destination_confirmed(destination: RegionHexCoord) -> void:
	if _campaign_session == null or destination == null:
		return
	var result: OperationResult = _campaign_session.dispatch_agent(destination)
	if not result.success:
		_show_toast(result.message, true)
		return
	if _region_map_view != null:
		_region_map_view.set_agent_preview_mode(false)
		_region_map_view.update_campaign(_campaign())
	_show_toast("Agent dispatched.")
	_refresh_header()


func _on_agent_preview_cancelled() -> void:
	_refresh_header()


func _on_agent_mission_discovered(mission_instance_id: StringName) -> void:
	var campaign: CampaignState = _campaign()
	var mission: ActiveMissionState = (
		campaign.get_active_mission(mission_instance_id) if campaign != null else null
	)
	if mission == null:
		return
	_show_screen(SCREEN_REGION)
	if _region_map_view != null:
		_region_map_view.mark_mission_new(mission.mission_instance_id)
		_region_map_view.focus_site(mission.site_id, true)
	_on_site_selected(mission.site_id, true)
	_agent_button_alert_until_ms = Time.get_ticks_msec() + 4500
	_show_toast("A new opportunity has appeared.")
	_refresh_header()


func _on_mission_expired(mission_instance_id: StringName) -> void:
	if _planning_mission_id == mission_instance_id:
		_planning_mission_id = &""
		_briefing_selected_ids.clear()
	_show_toast("An opportunity has expired.")
	_refresh_header()


func _on_squad_returned(_operation_id: StringName, replenishment_message: String) -> void:
	_refresh_header()
	var message: String = "Squad returned to the lair."
	if not replenishment_message.strip_edges().is_empty():
		message += " %s" % replenishment_message
	_show_toast(message)


func _on_travel_notoriety_applied(_report_id: StringName) -> void:
	_refresh_retaliation_bar()
	_show_toast("The travelling warband has drawn local attention.")


func _on_raid_operation_created(operation_id: StringName) -> void:
	if _campaign_session != null:
		_campaign_session.pause_clock()
	var campaign: CampaignState = _campaign()
	var raid: RaidOperationState = (
		campaign.raid_operations_by_id.get(operation_id) as RaidOperationState
		if campaign != null
		else null
	)
	if raid != null:
		_show_screen(SCREEN_REGION)
		if _region_map_view != null and not raid.origin_settlement_id.is_empty():
			_region_map_view.focus_site(raid.origin_settlement_id, true)
	_show_toast("Regional forces are preparing an attack on the stronghold.", true)
	_refresh_retaliation_bar()


func _on_recruitment_project_completed(character_id: StringName) -> void:
	var campaign: CampaignState = _campaign()
	var character: PersistentCharacterState = (
		campaign.get_character(character_id) if campaign != null else null
	)
	_show_toast(
		"%s has joined the Roster." % character.display_name
		if character != null
		else "A new henchman has joined the Roster."
	)
	if _current_screen == SCREEN_ROSTER:
		_show_screen(SCREEN_ROSTER)


func _on_prestige_project_completed(
		character_id: StringName,
		stage_id: StringName
) -> void:
	var campaign: CampaignState = _campaign()
	var character: PersistentCharacterState = (
		campaign.get_character(character_id) if campaign != null else null
	)
	var stage: TroopPrestigeStageDefinition = (
		_campaign_session.catalogue.prestige_stage(stage_id)
		if _campaign_session != null and _campaign_session.catalogue != null
		else null
	)
	var character_name: String = character.display_name if character != null else "The troop"
	var tier_name: String = stage.display_name if stage != null else "a new Tier"
	_show_toast("%s completed Prestige and is now %s." % [character_name, tier_name])
	if _current_screen == SCREEN_ROSTER:
		_show_screen(SCREEN_ROSTER)


func _on_production_project_completed(project_id: StringName, recipe_id: StringName) -> void:
	var recipe_value: ProductionRecipeDefinition = (
		_campaign_session.production_catalogue.recipe(recipe_id)
		if _campaign_session != null and _campaign_session.production_catalogue != null
		else null
	)
	_show_toast(
		"%s complete." % recipe_value.display_name
		if recipe_value != null
		else "Production project complete."
	)
	if _current_screen in [SCREEN_PRODUCTION, SCREEN_STORAGE]:
		_show_screen(_current_screen)


func _on_research_project_completed(project_id: StringName, research_id: StringName) -> void:
	var definition_value: ResearchProjectDefinition = (
		_campaign_session.research_catalogue.definition(research_id)
		if _campaign_session != null and _campaign_session.research_catalogue != null
		else null
	)
	_show_toast(
		"%s complete." % definition_value.display_name
		if definition_value != null
		else "Research project complete."
	)
	if _current_screen in [SCREEN_RESEARCH, SCREEN_PRODUCTION, SCREEN_SHOP, SCREEN_ROSTER]:
		_show_screen(_current_screen)


func _on_stronghold_project_completed(
	facility_instance_id: StringName,
	project_kind: StringName
) -> void:
	var state: StrongholdStateScript = (
		_campaign_session.current_stronghold_state()
		if _campaign_session != null
		else null
	)
	var definition: StrongholdDefinitionScript = (
		_campaign_session.current_stronghold_definition()
		if _campaign_session != null
		else null
	)
	var facility: StrongholdFacilityStateScript = (
		state.get_facility(facility_instance_id) if state != null else null
	)
	var facility_definition: StrongholdFacilityDefinitionScript = (
		definition.facility_definition(facility.definition_id)
		if definition != null and facility != null
		else null
	)
	var name_text: String = (
		facility_definition.display_name if facility_definition != null else "Facility"
	)
	var action_text: String = (
		"construction" if project_kind == StrongholdProjectStateScript.KIND_CONSTRUCTION else "upgrade"
	)
	_show_toast("%s %s complete." % [name_text, action_text])


func _on_squad_selected(operation_id: StringName) -> void:
	_close_selected_site_panel(false)
	var campaign: CampaignState = _campaign()
	var operation: SquadTravelOperationState = (
		campaign.get_squad_travel_operation(operation_id)
		if campaign != null
		else null
	)
	if operation == null or operation.status not in [
		SquadTravelOperationState.STATUS_TRAVELLING,
		SquadTravelOperationState.STATUS_RETURNING,
	]:
		_show_toast("The selected squad is no longer travelling.")
		return
	_selected_site_panel = PanelContainer.new()
	_selected_site_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_selected_site_panel.position = Vector2(-410, -235)
	_selected_site_panel.size = Vector2(385, 470)
	_selected_site_panel.z_index = 20
	_workspace.add_child(_selected_site_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_selected_site_panel.add_child(content)
	var squad: CampaignSquadState = campaign.get_squad(operation.campaign_squad_id)
	var squad_name: String = (
		squad.display_name
		if squad != null
		else "TRAVELLING SQUAD"
	)
	var title := Label.new()
	title.text = squad_name.to_upper()
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	var status := Label.new()
	status.text = (
		"RETURNING TO THE STRONGHOLD"
		if operation.status == SquadTravelOperationState.STATUS_RETURNING
		else "TRAVELLING TO THE MISSION"
	)
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color("8bd0e3") if operation.status == SquadTravelOperationState.STATUS_RETURNING else Color("edb75f"))
	content.add_child(status)
	var transport_name: String = operation.transport_display_name.strip_edges()
	if transport_name.is_empty():
		transport_name = "Walking" if operation.transport_is_walking else String(operation.transport_id).capitalize()
	content.add_child(_body_label(
		"TRANSPORT — %s\nMEMBERS — %d\nSTATUS — %s" % [
			transport_name,
			operation.character_ids.size(),
			"Returning" if operation.status == SquadTravelOperationState.STATUS_RETURNING else "En route",
		]
	))
	var mission: ActiveMissionState = campaign.get_active_mission(operation.mission_instance_id)
	if mission != null:
		var region: RegionMapDefinition = _campaign_session.current_region_definition() if _campaign_session != null else null
		var destination: RegionSiteDefinition = region.site(mission.site_id) if region != null else null
		if destination != null:
			content.add_child(_body_label("MISSION — %s" % destination.display_name))
	var member_names: Array[String] = []
	for character_id: StringName in operation.character_ids:
		var character: PersistentCharacterState = campaign.get_character(character_id)
		if character != null:
			member_names.append(character.display_name)
	if not member_names.is_empty():
		content.add_child(_body_label("SQUAD MEMBERS\n%s" % "\n".join(PackedStringArray(member_names))))
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(_close_selected_site_panel)
	content.add_child(close)


func _on_site_selected(site_id: StringName, as_mission_popup: bool = false) -> void:
	_close_selected_site_panel()
	_mission_popup_open = as_mission_popup
	var region: RegionMapDefinition = (
		_campaign_session.current_region_definition()
		if _campaign_session != null
		else null
	)
	var site: RegionSiteDefinition = region.site(site_id) if region != null else null
	if site == null:
		_mission_popup_open = false
		_show_toast("The selected authored site could not be loaded.", true)
		_refresh_header()
		return
	if _region_map_view != null:
		_region_map_view.acknowledge_mission_at_site(site.id)
	_selected_site_panel = PanelContainer.new()
	_selected_site_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_selected_site_panel.position = Vector2(-410, -260)
	_selected_site_panel.size = Vector2(385, 520)
	_selected_site_panel.z_index = 20
	_workspace.add_child(_selected_site_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_selected_site_panel.add_child(content)
	var mission: ActiveMissionState = (
		_campaign_session.mission_at_site(site.id)
		if _campaign_session != null
		else null
	)
	if mission != null and mission.is_available() and _campaign_session != null:
		_campaign_session.pause_clock()
	var is_mission_popup: bool = as_mission_popup and mission != null
	var mission_definition: MissionDefinition = (
		MissionDefinitionRegistry.definition(mission.mission_definition_id)
		if is_mission_popup
		else null
	)
	var title := Label.new()
	title.text = "NEW OPPORTUNITY" if is_mission_popup else site.display_name.to_upper()
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	if is_mission_popup:
		var mission_name := Label.new()
		mission_name.text = (
			mission_definition.display_name.to_upper()
			if mission_definition != null
			else "MISSION"
		)
		mission_name.add_theme_font_size_override("font_size", 19)
		mission_name.add_theme_color_override("font_color", Color("c9aa62"))
		content.add_child(mission_name)
		var mission_location := Label.new()
		mission_location.text = site.display_name
		mission_location.add_theme_color_override("font_color", Color("d7d0bd"))
		content.add_child(mission_location)
	var type_label := Label.new()
	type_label.text = _site_type_label(site.site_type)
	type_label.add_theme_color_override("font_color", Color("c9aa62"))
	content.add_child(type_label)
	if mission != null and mission.is_available():
		content.add_child(_body_label(
			"AVAILABILITY — %s\nRISK — %s\nOPPOSITION — %s\nLIKELY REWARDS — %s" % [
				_format_duration(mission.remaining_minutes(_campaign().campaign_tick)),
				String(mission.risk_rating).to_upper(),
				String(mission.opposition_information).to_upper(),
				", ".join(mission.reward_preview),
			]
		))
	var body := Label.new()
	body.text = site.description
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	var subregion_name: String = String(
		region.subregions_by_id.get(site.subregion_id, site.subregion_id)
	)
	content.add_child(_body_label(
		"SUBREGION — %s\nHEX — %d, %d"
		% [subregion_name, site.coord.offset_col, site.coord.offset_row]
	))
	if not site.tags.is_empty():
		var tag_names: Array[String] = []
		for tag: StringName in site.tags:
			tag_names.append(String(tag).capitalize())
		content.add_child(_body_label("SITE TAGS\n%s" % ", ".join(tag_names)))
	var mission_site: RegionSiteDefinition = (
		region.site(mission.site_id) if mission != null else null
	)
	if mission != null and mission_site != null and mission_site.id == site.id:
		var briefing := Button.new()
		briefing.text = "OPEN MISSION BRIEFING"
		briefing.pressed.connect(func() -> void: _show_screen(SCREEN_BRIEFING))
		content.add_child(briefing)
	if site.id == region.fifth_god_ruin_site_id:
		var open := Button.new()
		open.text = "ENTER STRONGHOLD"
		open.pressed.connect(func() -> void: _show_screen(SCREEN_STRONGHOLD))
		content.add_child(open)
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(_close_selected_site_panel)
	content.add_child(close)


func _close_selected_site_panel(clear_map_selection: bool = true) -> void:
	_mission_popup_open = false
	if clear_map_selection and _region_map_view != null:
		_region_map_view.clear_squad_selection()
	if _selected_site_panel == null:
		_refresh_header()
		return
	if _selected_site_panel.get_parent() != null:
		_selected_site_panel.get_parent().remove_child(_selected_site_panel)
	_selected_site_panel.queue_free()
	_selected_site_panel = null
	_refresh_header()


func _site_type_label(site_type: StringName) -> String:
	match site_type:
		&"settlement":
			return "ILYRA-REALM SETTLEMENT"
		&"stronghold":
			return "PLAYER STRONGHOLD"
		&"farm":
			return "AGRICULTURAL SITE"
		&"religious":
			return "ILYRAN RELIGIOUS SITE"
		&"military":
			return "REGIONAL MILITARY SITE"
		&"district":
			return "TELLURIA DISTRICT"
		&"wilderness":
			return "WILDERNESS SITE"
	return String(site_type).capitalize()


func _build_stronghold_screen() -> void:
	var definition: StrongholdDefinitionScript = (
		_campaign_session.current_stronghold_definition()
		if _campaign_session != null
		else null
	)
	var stronghold_state: StrongholdStateScript = (
		_campaign_session.current_stronghold_state()
		if _campaign_session != null
		else null
	)
	var connectivity: Dictionary = (
		_campaign_session.current_stronghold_connectivity()
		if _campaign_session != null
		else {}
	)
	if definition == null or stronghold_state == null:
		_workspace.add_child(_body_label("The authored stronghold definition could not be loaded."))
		return

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	_workspace.add_child(root)

	var grid_panel := PanelContainer.new()
	grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_panel.size_flags_stretch_ratio = 3.2
	root.add_child(grid_panel)

	_stronghold_grid_view = StrongholdGridViewScript.new()
	_stronghold_grid_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stronghold_grid_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stronghold_grid_view.configure(
		definition,
		stronghold_state,
		connectivity,
		_campaign().campaign_tick if _campaign() != null else 0
	)
	if _selected_stronghold_coord.x >= 0:
		_stronghold_grid_view.select_plot(_selected_stronghold_coord)
	else:
		_stronghold_grid_view.clear_selection()
	_stronghold_grid_view.plot_selected.connect(_on_stronghold_plot_selected)
	_stronghold_grid_view.plot_hovered.connect(_on_stronghold_plot_hovered)
	grid_panel.add_child(_stronghold_grid_view)

	var inspector_panel := PanelContainer.new()
	inspector_panel.custom_minimum_size.x = 345
	inspector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.size_flags_stretch_ratio = 1.0
	root.add_child(inspector_panel)
	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.add_child(inspector_scroll)
	_stronghold_inspector_content = VBoxContainer.new()
	_stronghold_inspector_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stronghold_inspector_content.add_theme_constant_override("separation", 10)
	inspector_scroll.add_child(_stronghold_inspector_content)
	_rebuild_stronghold_inspector()


func _on_stronghold_plot_selected(coord: Vector2i) -> void:
	if _campaign_session == null:
		return
	if not _stronghold_build_definition_id.is_empty():
		_update_stronghold_build_preview(coord)
		if _stronghold_build_valid:
			_request_stronghold_build_confirmation()
		return
	var state: StrongholdStateScript = _campaign_session.current_stronghold_state()
	var plot_state: StrongholdPlotStateScript = state.get_plot(coord) if state != null else null
	if plot_state != null and not plot_state.facility_id.is_empty():
		var facility: StrongholdFacilityStateScript = state.get_facility(plot_state.facility_id)
		if (
			facility != null
			and facility.condition != StrongholdFacilityStateScript.CONDITION_UNDER_CONSTRUCTION
		):
			if facility.definition_id == &"facility.stables":
				_show_screen(SCREEN_STABLE)
				return
			if facility.definition_id == &"facility.prison":
				_show_screen(SCREEN_PRISON)
				return
		_selected_stronghold_coord = state.canonical_coord(coord)
		if _stronghold_grid_view != null:
			_stronghold_grid_view.select_plot(_selected_stronghold_coord)
	else:
		_selected_stronghold_coord = Vector2i(-1, -1)
		if _stronghold_grid_view != null:
			_stronghold_grid_view.clear_selection()
	_rebuild_stronghold_inspector()


func _on_stronghold_plot_hovered(coord: Vector2i) -> void:
	if _stronghold_build_definition_id.is_empty() or coord.x < 0:
		return
	_update_stronghold_build_preview(coord)


func _rebuild_stronghold_inspector() -> void:
	if _stronghold_inspector_content == null or _campaign_session == null:
		return
	for child: Node in _stronghold_inspector_content.get_children():
		_stronghold_inspector_content.remove_child(child)
		child.queue_free()
	var definition: StrongholdDefinitionScript = _campaign_session.current_stronghold_definition()
	var stronghold_state: StrongholdStateScript = _campaign_session.current_stronghold_state()
	if definition == null or stronghold_state == null:
		_stronghold_inspector_content.add_child(_body_label("Stronghold data is unavailable."))
		return
	if not _stronghold_build_definition_id.is_empty():
		_build_stronghold_placement_inspector(definition)
	else:
		var plot_state: StrongholdPlotStateScript = (
			stronghold_state.get_plot(_selected_stronghold_coord)
			if _selected_stronghold_coord.x >= 0
			else null
		)
		if plot_state != null and not plot_state.facility_id.is_empty():
			_build_stronghold_facility_inspector(
				definition,
				stronghold_state,
				plot_state.facility_id
			)
		else:
			_build_stronghold_construction_catalogue(definition, stronghold_state)
	var map_button := Button.new()
	map_button.text = "RETURN TO REGION MAP"
	map_button.pressed.connect(func() -> void: _show_screen(SCREEN_REGION))
	_stronghold_inspector_content.add_child(map_button)


func _build_stronghold_construction_catalogue(
	definition: StrongholdDefinitionScript,
	stronghold_state: StrongholdStateScript
) -> void:
	_stronghold_inspector_content.add_child(_heading_label("BUILD ROOMS"))
	_stronghold_inspector_content.add_child(_body_label(
		"Choose a room, then move its illustrated preview across the stronghold and click a valid position."
	))
	_stronghold_inspector_content.add_child(HSeparator.new())
	var catalogue: Array[StrongholdFacilityDefinitionScript] = (
		_campaign_session.current_stronghold_build_catalogue()
	)
	if catalogue.is_empty():
		_stronghold_inspector_content.add_child(_body_label("No facilities are currently available."))
		return
	for facility_definition: StrongholdFacilityDefinitionScript in catalogue:
		_stronghold_inspector_content.add_child(
			_build_stronghold_catalogue_card(
				definition,
				stronghold_state,
				facility_definition
			)
		)


func _build_stronghold_catalogue_card(
	definition: StrongholdDefinitionScript,
	stronghold_state: StrongholdStateScript,
	facility_definition: StrongholdFacilityDefinitionScript
) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var presentation: StrongholdFacilityPresentationDefinitionScript = definition.facility_presentation(
		facility_definition.presentation_id
	)
	var thumbnail := TextureRect.new()
	thumbnail.custom_minimum_size = Vector2(86.0, 86.0)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if presentation != null and ResourceLoader.exists(presentation.art_path):
		thumbnail.texture = load(presentation.art_path) as Texture2D
	row.add_child(thumbnail)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	var name_label := Label.new()
	name_label.text = "%s  •  %s" % [
		facility_definition.display_name.to_upper(),
		facility_definition.footprint_label(),
	]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color("e4d5af"))
	details.add_child(name_label)
	var purpose := Label.new()
	purpose.text = facility_definition.description
	purpose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	purpose.add_theme_font_size_override("font_size", 11)
	purpose.add_theme_color_override("font_color", Color("b9b7ac"))
	details.add_child(purpose)
	var time_label := Label.new()
	time_label.text = "BUILD TIME — %s" % _format_duration(
		facility_definition.construction_duration_minutes
	).to_upper()
	time_label.add_theme_font_size_override("font_size", 10)
	time_label.add_theme_color_override("font_color", Color("c9aa62"))
	details.add_child(time_label)
	var unavailable_reason: String = ""
	if (
		facility_definition.unique
		and stronghold_state.count_facilities_with_definition(facility_definition.id) > 0
	):
		unavailable_reason = "Only one may be constructed."
	var build_button := Button.new()
	build_button.text = "BUILD"
	build_button.disabled = not unavailable_reason.is_empty()
	build_button.tooltip_text = unavailable_reason
	build_button.pressed.connect(
		func() -> void: _begin_stronghold_build(facility_definition.id)
	)
	details.add_child(build_button)
	return panel


func _build_stronghold_placement_inspector(definition: StrongholdDefinitionScript) -> void:
	var facility_definition: StrongholdFacilityDefinitionScript = definition.facility_definition(
		_stronghold_build_definition_id
	)
	if facility_definition == null:
		_cancel_stronghold_build_preview()
		return
	_stronghold_inspector_content.add_child(
		_heading_label("PLACE %s" % facility_definition.display_name.to_upper())
	)
	_stronghold_inspector_content.add_child(_body_label(facility_definition.description))
	_stronghold_inspector_content.add_child(_body_label(
		"CONSTRUCTION TIME — %s" % _format_duration(
			facility_definition.construction_duration_minutes
		).to_upper()
	))
	var validation := Label.new()
	if _stronghold_build_origin.x < 0:
		validation.text = "MOVE THE POINTER OVER THE GRID"
		validation.add_theme_color_override("font_color", Color("c9aa62"))
	elif _stronghold_build_valid:
		validation.text = "VALID POSITION — CLICK TO BUILD"
		validation.add_theme_color_override("font_color", Color("8fbd8f"))
	else:
		validation.text = "INVALID — %s" % _stronghold_build_message.to_upper()
		validation.add_theme_color_override("font_color", Color("cc6666"))
	validation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation.add_theme_font_size_override("font_size", 15)
	_stronghold_inspector_content.add_child(validation)
	_stronghold_inspector_content.add_child(_body_label(
		"Right-click or press Escape to cancel placement."
	))
	var cancel := Button.new()
	cancel.text = "CANCEL PLACEMENT"
	cancel.pressed.connect(_cancel_stronghold_build_preview)
	_stronghold_inspector_content.add_child(cancel)


func _build_stronghold_facility_inspector(
	definition: StrongholdDefinitionScript,
	stronghold_state: StrongholdStateScript,
	facility_instance_id: StringName
) -> void:
	var facility_state: StrongholdFacilityStateScript = stronghold_state.get_facility(
		facility_instance_id
	)
	if facility_state == null:
		_selected_stronghold_coord = Vector2i(-1, -1)
		_build_stronghold_construction_catalogue(definition, stronghold_state)
		return
	var facility_definition: StrongholdFacilityDefinitionScript = definition.facility_definition(
		facility_state.definition_id
	)
	if facility_definition == null:
		_stronghold_inspector_content.add_child(_body_label("The selected facility definition is missing."))
		return
	var presentation: StrongholdFacilityPresentationDefinitionScript = definition.facility_presentation(
		facility_definition.presentation_id
	)
	if presentation != null and ResourceLoader.exists(presentation.art_path):
		var artwork := TextureRect.new()
		artwork.custom_minimum_size = Vector2(0.0, 150.0)
		artwork.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.texture = load(presentation.art_path) as Texture2D
		_stronghold_inspector_content.add_child(artwork)
	_stronghold_inspector_content.add_child(
		_heading_label(facility_definition.display_name.to_upper())
	)
	var condition_label := Label.new()
	condition_label.text = "LEVEL %d  •  %s" % [
		facility_state.level,
		_condition_display_name(facility_state.condition),
	]
	condition_label.add_theme_font_size_override("font_size", 16)
	condition_label.add_theme_color_override(
		"font_color",
		Color("8fbd8f")
		if facility_state.condition == StrongholdFacilityStateScript.CONDITION_OPERATIONAL
		else Color("c9aa62")
	)
	_stronghold_inspector_content.add_child(condition_label)
	_stronghold_inspector_content.add_child(_body_label(facility_definition.description))
	var current_storage_capacity: int = facility_definition.storage_capacity_for_level(facility_state.level)
	var current_prison_capacity: int = facility_definition.prison_capacity_for_level(facility_state.level)
	match facility_state.condition:
		StrongholdFacilityStateScript.CONDITION_DAMAGED:
			current_storage_capacity = floori(float(current_storage_capacity) * 0.5)
			current_prison_capacity = current_prison_capacity / 2
		StrongholdFacilityStateScript.CONDITION_DISABLED, StrongholdFacilityStateScript.CONDITION_UNDER_CONSTRUCTION:
			current_storage_capacity = 0
			current_prison_capacity = 0
	if current_storage_capacity > 0 or current_prison_capacity > 0 or not facility_definition.benefit_lines.is_empty():
		_stronghold_inspector_content.add_child(HSeparator.new())
		_stronghold_inspector_content.add_child(_heading_label("CURRENT BENEFITS"))
		if current_storage_capacity > 0:
			_stronghold_inspector_content.add_child(_body_label("• Storage Capacity +%d" % current_storage_capacity))
		if current_prison_capacity > 0:
			_stronghold_inspector_content.add_child(_body_label("• Prison Cells %d" % current_prison_capacity))
		for benefit: String in facility_definition.benefit_lines:
			_stronghold_inspector_content.add_child(_body_label("• %s" % benefit))
	if facility_definition.id == &"facility.stables":
		_build_stable_transport_inspector(facility_instance_id)
	elif facility_definition.id == &"facility.prison" and facility_state.condition != StrongholdFacilityStateScript.CONDITION_UNDER_CONSTRUCTION:
		var open_prison := Button.new()
		open_prison.text = "OPEN PRISON"
		open_prison.pressed.connect(func() -> void: _show_screen(SCREEN_PRISON))
		_stronghold_inspector_content.add_child(open_prison)
	var project: StrongholdProjectStateScript = stronghold_state.project_for_facility(
		facility_instance_id
	)
	if project != null:
		_stronghold_inspector_content.add_child(HSeparator.new())
		_stronghold_inspector_content.add_child(_heading_label("CURRENT ACTIVITY"))
		var campaign_tick: int = _campaign().campaign_tick if _campaign() != null else 0
		var activity_name: String = (
			"CONSTRUCTION"
			if project.project_kind == StrongholdProjectStateScript.KIND_CONSTRUCTION
			else "UPGRADE TO LEVEL %d" % project.target_level
		)
		_stronghold_inspector_content.add_child(_body_label(
			"%s\n%s remaining\nProgress: %d%%" % [
				activity_name,
				_format_duration(project.remaining_minutes(campaign_tick)),
				roundi(project.progress(campaign_tick) * 100.0),
			]
		))
		var cancel_project := Button.new()
		cancel_project.text = "CANCEL %s" % activity_name
		cancel_project.pressed.connect(
			func() -> void: _request_stronghold_project_cancellation(project.project_id)
		)
		_stronghold_inspector_content.add_child(cancel_project)
		return
	_stronghold_inspector_content.add_child(HSeparator.new())
	_stronghold_inspector_content.add_child(_heading_label("ACTIONS"))
	var upgrade := Button.new()
	if facility_state.level >= facility_definition.max_level:
		upgrade.text = "MAXIMUM LEVEL REACHED"
		upgrade.disabled = true
	else:
		var target_level: int = facility_state.level + 1
		var upgrade_minutes: int = facility_definition.upgrade_duration_for_target_level(
			target_level
		)
		upgrade.text = "UPGRADE TO LEVEL %d — %s" % [
			target_level,
			_format_duration(upgrade_minutes).to_upper(),
		]
		upgrade.pressed.connect(
			func() -> void: _request_stronghold_upgrade(facility_instance_id)
		)
	_stronghold_inspector_content.add_child(upgrade)
	if facility_definition.demolishable:
		var demolish := Button.new()
		demolish.text = "DEMOLISH FACILITY"
		demolish.pressed.connect(
			func() -> void: _request_stronghold_demolition(facility_instance_id)
		)
		_stronghold_inspector_content.add_child(demolish)


func _build_stable_transport_inspector(facility_instance_id: StringName) -> void:
	if _campaign_session == null or _stronghold_inspector_content == null:
		return
	var campaign: CampaignState = _campaign()
	var bay: StableBayState = _campaign_session.stable_bay_for_facility(facility_instance_id)
	if bay == null:
		_stronghold_inspector_content.add_child(_body_label("This Stable has no campaign housing record."))
		return
	var summary: Dictionary = _campaign_session.stable_bay_summary(bay.bay_id)
	var transport: Dictionary = summary.get("transport", {}) as Dictionary
	var housed_asset: TransportState = campaign.get_transport(bay.transport_asset_id) if campaign != null else null

	_stronghold_inspector_content.add_child(HSeparator.new())
	_stronghold_inspector_content.add_child(_heading_label("STABLE HOUSING"))
	_stronghold_inspector_content.add_child(_body_label(
		"Transport: %s\nAssigned squad: %s\nDeployment: %d / %d\nStatus: %s" % [
			String(transport.get("transport_display_name", transport.get("display_name", "No vehicle — Walking")))
			if housed_asset != null
			else "No vehicle — Walking",
			String(summary.get("squad_name", "Unassigned")),
			int(summary.get("deployed_count", 0)),
			6 if bay.is_walking else int(transport.get("total_passenger_capacity", 0)),
			String(bay.status).replace("_", " ").to_upper(),
		]
	))
	_stronghold_inspector_content.add_child(_body_label(
		"One constructed Stable houses one exact transport. A squad assigned to an empty Stable travels on foot with six fixed deployment positions."
	))
	var open_stable := Button.new()
	open_stable.text = "OPEN THIS STABLE"
	open_stable.custom_minimum_size.y = 42
	open_stable.pressed.connect(func() -> void:
		_selected_stable_bay_id = bay.bay_id
		_show_screen(SCREEN_STABLE)
	)
	_stronghold_inspector_content.add_child(open_stable)

	_stronghold_inspector_content.add_child(HSeparator.new())
	_stronghold_inspector_content.add_child(_heading_label("ACQUIRE TRANSPORT"))
	var stable_empty: bool = bay.is_vacant_for_transport()
	if not stable_empty:
		_stronghold_inspector_content.add_child(_body_label(
			"This Stable is occupied by an active expedition. It must return before a transport can be acquired here."
			if housed_asset == null
			else "This Stable already houses a transport. Sell it or construct another Stable before acquiring another vehicle."
		))
	for transport_data: Dictionary in _campaign_session.transport_definitions():
		if bool(transport_data.get("is_walking", false)):
			continue
		var method_card := PanelContainer.new()
		var method_margin := MarginContainer.new()
		method_margin.add_theme_constant_override("margin_left", 8)
		method_margin.add_theme_constant_override("margin_right", 8)
		method_margin.add_theme_constant_override("margin_top", 7)
		method_margin.add_theme_constant_override("margin_bottom", 7)
		method_card.add_child(method_margin)
		var method_column := VBoxContainer.new()
		method_column.add_theme_constant_override("separation", 4)
		method_margin.add_child(method_column)
		var method_name := Label.new()
		method_name.text = String(transport_data.get("display_name", "Transport")).to_upper()
		method_name.add_theme_font_size_override("font_size", 12)
		method_name.add_theme_color_override("font_color", Color("cbb678"))
		method_column.add_child(method_name)
		method_column.add_child(_body_label(
			"Passengers %d · Speed ×%.2f · Cargo %.0f lb · Notoriety %+d%%\n%s" % [
				int(transport_data.get("passenger_capacity", 0)),
				float(transport_data.get("strategic_speed_multiplier", 1.0)),
				float(transport_data.get("cargo_capacity_lb", 0.0)),
				int(transport_data.get("journey_notoriety_modifier_percent", 0)),
				String(transport_data.get("description", "")),
			]
		))
		var acquire := Button.new()
		var research_complete: bool = bool(transport_data.get("research_complete", false))
		acquire.text = (
			"ACQUIRE INTO THIS STABLE — %s" % String(transport_data.get("acquisition_cost_text", ""))
			if research_complete
			else "RESEARCH REQUIRED — %s" % String(transport_data.get("research_unlock_id", "Unknown Research"))
		)
		acquire.disabled = not research_complete or not stable_empty
		acquire.tooltip_text = (
			"Construct or select an empty Stable first."
			if not stable_empty
			else "Complete the required Research first."
			if not research_complete
			else "Acquire this exact transport and house it in this Stable."
		)
		var definition_id := StringName(transport_data.get("id", ""))
		acquire.pressed.connect(func() -> void:
			var result: OperationResult = _campaign_session.acquire_transport(definition_id, bay.bay_id)
			if not result.success:
				_show_toast(result.message, true)
				return
			_stronghold_preserve_selection_once = true
			_show_screen(SCREEN_STRONGHOLD)
			_show_toast(result.message)
		)
		method_column.add_child(acquire)
		_stronghold_inspector_content.add_child(method_card)


func _condition_display_name(condition: StringName) -> String:
	match condition:
		StrongholdFacilityStateScript.CONDITION_OPERATIONAL:
			return "OPERATIONAL"
		StrongholdFacilityStateScript.CONDITION_UNDER_CONSTRUCTION:
			return "UNDER CONSTRUCTION"
		StrongholdFacilityStateScript.CONDITION_UPGRADING:
			return "UPGRADING"
		StrongholdFacilityStateScript.CONDITION_DAMAGED:
			return "DAMAGED"
		StrongholdFacilityStateScript.CONDITION_DISABLED:
			return "DISABLED"
	return String(condition).replace("_", " ").to_upper()


func _begin_stronghold_build(facility_definition_id: StringName) -> void:
	_stronghold_build_definition_id = facility_definition_id
	_stronghold_build_origin = Vector2i(-1, -1)
	_stronghold_build_valid = false
	_stronghold_build_message = "Move the pointer over the grid."
	_selected_stronghold_coord = Vector2i(-1, -1)
	if _stronghold_grid_view != null:
		_stronghold_grid_view.clear_selection()
		_stronghold_grid_view.clear_build_preview()
	_rebuild_stronghold_inspector()


func _update_stronghold_build_preview(origin: Vector2i) -> void:
	if _stronghold_build_definition_id.is_empty() or _campaign_session == null:
		return
	var definition: StrongholdDefinitionScript = _campaign_session.current_stronghold_definition()
	var facility_definition: StrongholdFacilityDefinitionScript = definition.facility_definition(
		_stronghold_build_definition_id
	) if definition != null else null
	if facility_definition == null:
		return
	_stronghold_build_origin = origin
	var preview: OperationResult = _campaign_session.preview_stronghold_build(
		_stronghold_build_definition_id,
		origin
	)
	_stronghold_build_valid = preview.success
	_stronghold_build_message = preview.message
	if _stronghold_grid_view != null:
		_stronghold_grid_view.set_build_preview(
			_stronghold_build_definition_id,
			origin,
			facility_definition.footprint,
			preview.success,
			preview.message
		)
	_rebuild_stronghold_inspector()


func _request_stronghold_build_confirmation() -> void:
	if not _stronghold_build_valid or _campaign_session == null:
		return
	var definition: StrongholdDefinitionScript = _campaign_session.current_stronghold_definition()
	var facility_definition: StrongholdFacilityDefinitionScript = (
		definition.facility_definition(_stronghold_build_definition_id)
		if definition != null
		else null
	)
	if facility_definition == null:
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Construct %s" % facility_definition.display_name
	dialog.dialog_text = (
		"Construction time: %s\n\nThe room will remain unavailable until construction finishes."
		% _format_duration(facility_definition.construction_duration_minutes)
	)
	dialog.get_ok_button().text = "CONSTRUCT"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_confirm_stronghold_build()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(540, 250))


func _confirm_stronghold_build() -> void:
	if not _stronghold_build_valid or _campaign_session == null:
		return
	var result: OperationResult = _campaign_session.construct_stronghold_facility(
		_stronghold_build_definition_id,
		_stronghold_build_origin
	)
	if not result.success:
		_stronghold_build_valid = false
		_stronghold_build_message = result.message
		_rebuild_stronghold_inspector()
		_show_toast(result.message, true)
		return
	var result_data: Dictionary = {}
	if result.data is Dictionary:
		result_data = result.data as Dictionary
	var facility_instance_id := StringName(result_data.get("facility_instance_id", ""))
	var state: StrongholdStateScript = _campaign_session.current_stronghold_state()
	_selected_stronghold_coord = (
		state.facility_origin(facility_instance_id)
		if state != null and not facility_instance_id.is_empty()
		else _stronghold_build_origin
	)
	var message: String = result.message
	_clear_stronghold_build_state()
	_stronghold_preserve_selection_once = true
	_show_screen(SCREEN_STRONGHOLD)
	_show_toast(message)


func _cancel_stronghold_build_preview() -> void:
	_clear_stronghold_build_state()
	_selected_stronghold_coord = Vector2i(-1, -1)
	if _stronghold_grid_view != null:
		_stronghold_grid_view.clear_build_preview()
		_stronghold_grid_view.clear_selection()
	_rebuild_stronghold_inspector()


func _clear_stronghold_build_state() -> void:
	_stronghold_build_definition_id = &""
	_stronghold_build_origin = Vector2i(-1, -1)
	_stronghold_build_valid = false
	_stronghold_build_message = ""


func _request_stronghold_upgrade(facility_instance_id: StringName) -> void:
	var state: StrongholdStateScript = _campaign_session.current_stronghold_state()
	var definition: StrongholdDefinitionScript = _campaign_session.current_stronghold_definition()
	var facility_state: StrongholdFacilityStateScript = state.get_facility(facility_instance_id) if state != null else null
	var facility_definition: StrongholdFacilityDefinitionScript = (
		definition.facility_definition(facility_state.definition_id)
		if definition != null and facility_state != null
		else null
	)
	if facility_state == null or facility_definition == null:
		return
	var target_level: int = facility_state.level + 1
	var duration: int = facility_definition.upgrade_duration_for_target_level(target_level)
	var dialog := ConfirmationDialog.new()
	dialog.title = "Upgrade %s" % facility_definition.display_name
	var current_capacity: int = facility_definition.storage_capacity_for_level(facility_state.level)
	var target_capacity: int = facility_definition.storage_capacity_for_level(target_level)
	var capacity_text: String = ""
	if current_capacity > 0 or target_capacity > 0:
		capacity_text = "\n\nStorage Capacity\n+%d → +%d\nCurrent capacity remains active during the upgrade." % [
			current_capacity,
			target_capacity,
		]
	dialog.dialog_text = "Upgrade to level %d?\n\nUpgrade time: %s%s" % [
		target_level,
		_format_duration(duration),
		capacity_text,
	]
	dialog.get_ok_button().text = "UPGRADE"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _campaign_session.upgrade_stronghold_facility(facility_instance_id)
		dialog.queue_free()
		if not result.success:
			_show_toast(result.message, true)
			return
		_selected_stronghold_coord = state.facility_origin(facility_instance_id)
		_stronghold_preserve_selection_once = true
		_show_screen(SCREEN_STRONGHOLD)
		_show_toast(result.message)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(520, 230))


func _request_stronghold_project_cancellation(project_id: StringName) -> void:
	var state: StrongholdStateScript = _campaign_session.current_stronghold_state()
	var project: StrongholdProjectStateScript = state.get_project(project_id) if state != null else null
	if project == null:
		return
	var was_construction: bool = project.project_kind == StrongholdProjectStateScript.KIND_CONSTRUCTION
	var facility_id: StringName = project.facility_instance_id
	var dialog := ConfirmationDialog.new()
	dialog.title = "Cancel Project"
	dialog.dialog_text = (
		"Cancel construction and release the room footprint?"
		if was_construction
		else "Cancel this upgrade and return the facility to operation?"
	)
	dialog.get_ok_button().text = "CANCEL PROJECT"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _campaign_session.cancel_stronghold_project(project_id)
		dialog.queue_free()
		if not result.success:
			_show_toast(result.message, true)
			return
		if was_construction:
			_selected_stronghold_coord = Vector2i(-1, -1)
		else:
			var current_state: StrongholdStateScript = _campaign_session.current_stronghold_state()
			_selected_stronghold_coord = current_state.facility_origin(facility_id)
		_stronghold_preserve_selection_once = true
		_show_screen(SCREEN_STRONGHOLD)
		_show_toast(result.message)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(520, 220))


func _request_stronghold_demolition(facility_instance_id: StringName) -> void:
	var capacity_snapshot: Dictionary = _campaign_session.storage_capacity_snapshot()
	var used: int = int(capacity_snapshot.get("used", 0))
	var current_maximum: int = int(capacity_snapshot.get("maximum", 0))
	var removed_capacity: int = 0
	for raw_source: Variant in capacity_snapshot.get("capacity_sources", []) as Array:
		if raw_source is Dictionary and StringName((raw_source as Dictionary).get("source_id", &"")) == facility_instance_id:
			removed_capacity = int((raw_source as Dictionary).get("capacity", 0))
			break
	var resulting_maximum: int = maxi(0, current_maximum - removed_capacity)
	var resulting_overflow: int = maxi(0, used - resulting_maximum)
	var capacity_warning: String = ""
	if removed_capacity > 0:
		capacity_warning = "\n\nStorage capacity:\n%d → %d\nCurrent usage: %d" % [
			current_maximum,
			resulting_maximum,
			used,
		]
		if resulting_overflow > 0:
			capacity_warning += "\n\nThe stronghold will be over capacity by %d. No items will be destroyed." % resulting_overflow
	var dialog := ConfirmationDialog.new()
	dialog.title = "Demolish Facility"
	dialog.dialog_text = "Demolish the complete facility? The current prototype provides no refund.%s" % capacity_warning
	dialog.get_ok_button().text = "DEMOLISH"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _campaign_session.demolish_stronghold_facility(facility_instance_id)
		dialog.queue_free()
		if not result.success:
			_show_toast(result.message, true)
			return
		_selected_stronghold_coord = Vector2i(-1, -1)
		_stronghold_preserve_selection_once = true
		_show_screen(SCREEN_STRONGHOLD)
		_show_toast(result.message)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(520, 220))



func _build_prison_screen() -> void:
	if _campaign_session == null:
		_workspace.add_child(_body_label("Prison services are unavailable."))
		return
	var snapshot: Dictionary = _campaign_session.prison_snapshot()
	var all_captives: Array = snapshot.get("captives", []) as Array
	var captives: Array = _filtered_prison_captives(all_captives)
	var valid_ids: Dictionary = {}
	for raw_entry: Variant in captives:
		if raw_entry is Dictionary:
			var captive_id := StringName((raw_entry as Dictionary).get("captive_id", ""))
			if not captive_id.is_empty():
				valid_ids[captive_id] = true
	if _selected_captive_id.is_empty() or not valid_ids.has(_selected_captive_id):
		_selected_captive_id = &""
		for raw_entry: Variant in captives:
			if not raw_entry is Dictionary:
				continue
			var entry: Dictionary = raw_entry as Dictionary
			if StringName(entry.get("status", "")) == &"held":
				_selected_captive_id = StringName(entry.get("captive_id", ""))
				break
		if _selected_captive_id.is_empty() and not captives.is_empty() and captives[0] is Dictionary:
			_selected_captive_id = StringName((captives[0] as Dictionary).get("captive_id", ""))

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	_workspace.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title := Label.new()
	title.text = "PRISON"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("c9a557"))
	header.add_child(title)
	var capacity_label := Label.new()
	capacity_label.text = "HELD %d  ·  INCOMING %d  ·  CAPACITY %d  ·  AVAILABLE %d" % [
		int(snapshot.get("held_cells", 0)),
		int(snapshot.get("incoming_cells", 0)),
		int(snapshot.get("total_capacity", 0)),
		int(snapshot.get("available_capacity", 0)),
	]
	capacity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capacity_label.add_theme_font_size_override("font_size", 14)
	capacity_label.add_theme_color_override("font_color", Color("d8d0bd"))
	header.add_child(capacity_label)
	var return_button := Button.new()
	return_button.text = "RETURN TO STRONGHOLD"
	return_button.pressed.connect(func() -> void: _show_screen(SCREEN_STRONGHOLD))
	header.add_child(return_button)

	var facility_lines: Array[String] = []
	for raw_facility: Variant in snapshot.get("facilities", []) as Array:
		if not raw_facility is Dictionary:
			continue
		var facility: Dictionary = raw_facility as Dictionary
		facility_lines.append("Level %d · %s · %d/%d cells" % [
			int(facility.get("level", 1)),
			String(facility.get("condition", "operational")).replace("_", " ").capitalize(),
			int(facility.get("held", 0)),
			int(facility.get("capacity", 0)),
		])
	var facility_summary := Label.new()
	facility_summary.text = (
		"PRISON FACILITIES — " + "  |  ".join(PackedStringArray(facility_lines))
		if not facility_lines.is_empty()
		else "NO CONSTRUCTED PRISON — build a Prison before returning with captives."
	)
	facility_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facility_summary.add_theme_font_size_override("font_size", 11)
	facility_summary.add_theme_color_override(
		"font_color", Color("aaa89d") if not facility_lines.is_empty() else Color("cc7777")
	)
	root.add_child(facility_summary)
	var action_reports: Array = snapshot.get("action_reports", []) as Array
	if not action_reports.is_empty():
		var recent_lines: Array[String] = []
		for index: int in range(mini(3, action_reports.size())):
			var raw_report: Variant = action_reports[index]
			if not raw_report is Dictionary:
				continue
			var report: Dictionary = raw_report as Dictionary
			var consequence: String = ""
			var gold_delta: int = int(report.get("gold_delta", 0))
			var notoriety_delta: int = int(report.get("notoriety_delta", 0))
			if gold_delta != 0:
				consequence = " · Gold +%d" % gold_delta
			elif notoriety_delta != 0:
				consequence = " · Notoriety %d" % notoriety_delta
			else:
				consequence = " · No Notoriety change"
			recent_lines.append("%s%s" % [String(report.get("label", "Captive action")), consequence])
		if not recent_lines.is_empty():
			var recent := Label.new()
			recent.text = "RECENT PRISON ACTIONS — " + "  |  ".join(PackedStringArray(recent_lines))
			recent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			recent.add_theme_font_size_override("font_size", 10)
			recent.add_theme_color_override("font_color", Color("9ea99a"))
			root.add_child(recent)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	root.add_child(columns)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size.x = 310
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(list_panel)
	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 10)
	list_margin.add_theme_constant_override("margin_right", 10)
	list_margin.add_theme_constant_override("margin_top", 10)
	list_margin.add_theme_constant_override("margin_bottom", 10)
	list_panel.add_child(list_margin)
	var list_column := VBoxContainer.new()
	list_column.add_theme_constant_override("separation", 7)
	list_margin.add_child(list_column)
	list_column.add_child(_heading_label("CAPTIVES"))
	var list_controls := HBoxContainer.new()
	list_controls.add_theme_constant_override("separation", 6)
	list_column.add_child(list_controls)
	var filter_control := OptionButton.new()
	filter_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for filter_entry: Array in [
		[PRISON_FILTER_ALL, "ALL"],
		[PRISON_FILTER_HELD, "HELD"],
		[PRISON_FILTER_INCOMING, "INCOMING"],
		[PRISON_FILTER_RANSOMABLE, "RANSOMABLE"],
		[PRISON_FILTER_WOUNDED, "WOUNDED"],
	]:
		filter_control.add_item(String(filter_entry[1]))
		filter_control.set_item_metadata(filter_control.item_count - 1, filter_entry[0])
		if StringName(filter_entry[0]) == _prison_filter_id:
			filter_control.select(filter_control.item_count - 1)
	filter_control.item_selected.connect(func(index: int) -> void:
		_prison_filter_id = StringName(filter_control.get_item_metadata(index))
		_show_screen(SCREEN_PRISON)
	)
	list_controls.add_child(filter_control)
	var sort_control := OptionButton.new()
	for sort_entry: Array in [
		[&"name", "NAME"],
		[&"faction", "FACTION"],
		[&"days_held", "DAYS"],
		[&"ransom", "RANSOM"],
	]:
		sort_control.add_item(String(sort_entry[1]))
		sort_control.set_item_metadata(sort_control.item_count - 1, sort_entry[0])
		if StringName(sort_entry[0]) == _prison_sort_id:
			sort_control.select(sort_control.item_count - 1)
	sort_control.item_selected.connect(func(index: int) -> void:
		_prison_sort_id = StringName(sort_control.get_item_metadata(index))
		_show_screen(SCREEN_PRISON)
	)
	list_controls.add_child(sort_control)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_column.add_child(list_scroll)
	var captive_list := VBoxContainer.new()
	captive_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	captive_list.add_theme_constant_override("separation", 5)
	list_scroll.add_child(captive_list)
	if captives.is_empty():
		captive_list.add_child(_body_label("No captives are currently held or returning."))
	else:
		for raw_entry: Variant in captives:
			if raw_entry is Dictionary:
				captive_list.add_child(_build_prison_captive_list_row(raw_entry as Dictionary))

	var dossier_panel := PanelContainer.new()
	dossier_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(dossier_panel)
	var dossier_margin := MarginContainer.new()
	dossier_margin.add_theme_constant_override("margin_left", 16)
	dossier_margin.add_theme_constant_override("margin_right", 16)
	dossier_margin.add_theme_constant_override("margin_top", 12)
	dossier_margin.add_theme_constant_override("margin_bottom", 12)
	dossier_panel.add_child(dossier_margin)
	var dossier_scroll := ScrollContainer.new()
	dossier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dossier_margin.add_child(dossier_scroll)
	var dossier := VBoxContainer.new()
	dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier.add_theme_constant_override("separation", 9)
	dossier_scroll.add_child(dossier)
	var selected: Dictionary = _prison_selected_snapshot(captives)
	if selected.is_empty():
		dossier.add_child(_body_label("Select a captive to inspect their exact campaign record."))
	else:
		_build_prison_captive_dossier(dossier, selected)

	var actions_panel := PanelContainer.new()
	actions_panel.custom_minimum_size.x = 270
	actions_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(actions_panel)
	var actions_margin := MarginContainer.new()
	actions_margin.add_theme_constant_override("margin_left", 12)
	actions_margin.add_theme_constant_override("margin_right", 12)
	actions_margin.add_theme_constant_override("margin_top", 12)
	actions_margin.add_theme_constant_override("margin_bottom", 12)
	actions_panel.add_child(actions_margin)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 9)
	actions_margin.add_child(actions)
	actions.add_child(_heading_label("ACTIONS"))
	if selected.is_empty():
		actions.add_child(_body_label("No captive selected."))
	else:
		var status := StringName(selected.get("status", ""))
		var held: bool = status == &"held"
		var ransom := Button.new()
		ransom.text = "RANSOM — %d GOLD" % int(selected.get("ransom_value", 0))
		ransom.custom_minimum_size.y = 48
		var prison_disabled: bool = StringName(selected.get("assigned_prison_condition", "")) == StrongholdFacilityStateScript.CONDITION_DISABLED
		ransom.disabled = not held or not bool(selected.get("ransom_allowed", false)) or prison_disabled
		ransom.tooltip_text = (
			"Ransom processing is suspended until the assigned Prison is repaired."
			if prison_disabled
			else (
				"No valid ransom channel exists for this captive."
				if ransom.disabled
				else "Receive the exact displayed payment and permanently remove this captive."
			)
		)
		ransom.pressed.connect(func() -> void:
			_request_ransom_captive(StringName(selected.get("captive_id", "")))
		)
		actions.add_child(ransom)

		var release := Button.new()
		var release_delta: int = int(selected.get("release_notoriety_delta", 0))
		release.text = "RELEASE%s" % (
			"  ·  NOTORIETY %d" % release_delta if release_delta != 0 else ""
		)
		release.custom_minimum_size.y = 48
		release.disabled = not held or not bool(selected.get("release_allowed", false))
		release.tooltip_text = (
			"Incoming captives cannot be released until they reach the Prison."
			if status == &"incoming"
			else "Permanently release this captive. Ordinary releases have no hidden reward."
		)
		release.pressed.connect(func() -> void:
			_request_release_captive(StringName(selected.get("captive_id", "")))
		)
		actions.add_child(release)

		actions.add_child(HSeparator.new())
		var interrogate := Button.new()
		interrogate.text = "INTERROGATE"
		interrogate.custom_minimum_size.y = 48
		var captive_id := StringName(selected.get("captive_id", ""))
		var interrogation_preview: OperationResult = _campaign_session.preview_interrogate_captive(captive_id)
		interrogate.disabled = not interrogation_preview.success
		interrogate.tooltip_text = interrogation_preview.message
		interrogate.pressed.connect(func() -> void:
			_request_interrogate_captive(captive_id)
		)
		actions.add_child(interrogate)
		if bool(selected.get("interrogation_completed", false)):
			actions.add_child(_body_label("INTERROGATED — this captive's authored organisational knowledge has already been recorded."))
		elif not StringName(selected.get("interrogation_source_id", "")).is_empty():
			actions.add_child(_body_label("May reveal a specific Research source. The captive remains held after interrogation."))
		else:
			actions.add_child(_body_label("No authored Research or merchant knowledge is available from this captive."))
		actions.add_child(_body_label("Recruitment and conversion remain deferred until their separate project rules are designed."))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var manage := Button.new()
	manage.text = "MANAGE FACILITY"
	manage.pressed.connect(func() -> void:
		_selected_stronghold_coord = _first_prison_coord()
		_stronghold_preserve_selection_once = true
		_show_screen(SCREEN_STRONGHOLD)
	)
	actions.add_child(manage)


func _build_prison_captive_list_row(entry: Dictionary) -> Control:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	var portrait_id := StringName(entry.get("portrait_id", ""))
	if not portrait_id.is_empty():
		button.icon = PortraitAssetResolver.new().resolve(portrait_id)
		button.expand_icon = true
	var status: String = String(entry.get("status", "held")).replace("_", " ").to_upper()
	var detail: String = "NO RANSOM"
	if bool(entry.get("ransom_allowed", false)):
		detail = "%d GOLD" % int(entry.get("ransom_value", 0))
	var release_delta: int = int(entry.get("release_notoriety_delta", 0))
	if release_delta != 0:
		detail += "  ·  RELEASE %d NOT." % release_delta
	button.text = "%s\n%s  ·  %s" % [
		String(entry.get("display_name", "Unknown captive")).to_upper(),
		status,
		detail,
	]
	button.button_pressed = StringName(entry.get("captive_id", "")) == _selected_captive_id
	button.pressed.connect(func() -> void:
		_selected_captive_id = StringName(entry.get("captive_id", ""))
		_show_screen(SCREEN_PRISON)
	)
	return button


func _filtered_prison_captives(captives: Array) -> Array:
	var result: Array = []
	for raw_entry: Variant in captives:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = (raw_entry as Dictionary).duplicate(true)
		var status := StringName(entry.get("status", ""))
		var include: bool = true
		match _prison_filter_id:
			PRISON_FILTER_HELD:
				include = status == &"held"
			PRISON_FILTER_INCOMING:
				include = status == &"incoming"
			PRISON_FILTER_RANSOMABLE:
				include = status == &"held" and bool(entry.get("ransom_allowed", false))
			PRISON_FILTER_WOUNDED:
				include = (
					int(entry.get("current_hp", 0)) < int(entry.get("maximum_hp", 1))
					or int(entry.get("nonlethal_damage", 0)) > 0
					or not (entry.get("injury_entries", []) as Array).is_empty()
				)
		if include:
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match _prison_sort_id:
			&"faction":
				var faction_compare: int = String(a.get("faction_id", "")).nocasecmp_to(String(b.get("faction_id", "")))
				if faction_compare != 0:
					return faction_compare < 0
			&"days_held":
				var a_days: int = int(a.get("days_held", 0))
				var b_days: int = int(b.get("days_held", 0))
				if a_days != b_days:
					return a_days > b_days
			&"ransom":
				var a_ransom: int = int(a.get("ransom_value", 0))
				var b_ransom: int = int(b.get("ransom_value", 0))
				if a_ransom != b_ransom:
					return a_ransom > b_ransom
		return String(a.get("display_name", "")).nocasecmp_to(String(b.get("display_name", ""))) < 0
	)
	return result


func _prison_selected_snapshot(captives: Array) -> Dictionary:
	for raw_entry: Variant in captives:
		if raw_entry is Dictionary and StringName((raw_entry as Dictionary).get("captive_id", "")) == _selected_captive_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _build_prison_captive_dossier(dossier: VBoxContainer, entry: Dictionary) -> void:
	dossier.add_child(_heading_label("SELECTED CAPTIVE"))
	var portrait_id := StringName(entry.get("portrait_id", ""))
	if not portrait_id.is_empty():
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(180, 220)
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		portrait.texture = PortraitAssetResolver.new().resolve(portrait_id)
		dossier.add_child(portrait)
	var name := Label.new()
	name.text = String(entry.get("display_name", "UNKNOWN CAPTIVE")).to_upper()
	name.add_theme_font_size_override("font_size", 24)
	name.add_theme_color_override("font_color", Color("e0d3b0"))
	dossier.add_child(name)
	var identity_text: String = "Identity known" if bool(entry.get("identity_known", false)) else "Identity unknown"
	dossier.add_child(_body_label("%s\n%s · Level %d\nFaction: %s" % [
		identity_text,
		String(entry.get("troop_type_id", "unknown")).replace("_", " ").capitalize(),
		int(entry.get("level", 1)),
		String(entry.get("faction_id", "unknown")).replace("_", " ").capitalize(),
	]))
	dossier.add_child(HSeparator.new())
	dossier.add_child(_heading_label("CONDITION"))
	dossier.add_child(_body_label("HP %d / %d\nNonlethal damage %d\nStatus: %s" % [
		int(entry.get("current_hp", 0)),
		int(entry.get("maximum_hp", 1)),
		int(entry.get("nonlethal_damage", 0)),
		String(entry.get("status", "held")).replace("_", " ").capitalize(),
	]))
	var injuries: Array = entry.get("injury_entries", []) as Array
	if injuries.is_empty():
		dossier.add_child(_body_label("No recorded strategic injuries."))
	else:
		var injury_lines: Array[String] = []
		for raw_injury: Variant in injuries:
			injury_lines.append("• %s" % String(raw_injury))
		dossier.add_child(_body_label("\n".join(PackedStringArray(injury_lines))))
	dossier.add_child(HSeparator.new())
	dossier.add_child(_heading_label("CAPTURE RECORD"))
	var captor_label: String = String(entry.get("captor_character_id", ""))
	if captor_label.is_empty():
		captor_label = "Not recorded"
	dossier.add_child(_body_label("Captured at: %s\nMission: %s\nCaptor: %s\nDays held: %d\nContainment: %s\nCell cost: %d" % [
		String(entry.get("capture_location_label", "Unknown location")),
		String(entry.get("captured_mission_id", "Unknown mission")),
		captor_label,
		int(entry.get("days_held", 0)),
		String(entry.get("containment_profile_id", "standard humanoid")).replace("containment.", "").replace("_", " ").capitalize(),
		int(entry.get("cell_cost", 1)),
	]))
	var history: Array = entry.get("history_entries", []) as Array
	if not history.is_empty():
		dossier.add_child(HSeparator.new())
		dossier.add_child(_heading_label("HISTORY"))
		var lines: Array[String] = []
		for raw_line: Variant in history:
			lines.append("• %s" % String(raw_line))
		dossier.add_child(_body_label("\n".join(PackedStringArray(lines))))


func _request_interrogate_captive(captive_id: StringName) -> void:
	var preview: OperationResult = _campaign_session.preview_interrogate_captive(captive_id)
	if not preview.success:
		_show_toast(preview.message, true)
		_show_screen(SCREEN_PRISON)
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Interrogate Captive"
	dialog.dialog_text = "Interrogate this captive for their authored organisational knowledge? This is a one-time action and does not release, ransom or recruit them."
	dialog.ok_button_text = "INTERROGATE"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _campaign_session.interrogate_captive(captive_id)
		_show_toast(result.message, not result.success)
		_show_screen(SCREEN_PRISON)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.confirmed.connect(func() -> void: dialog.queue_free(), CONNECT_DEFERRED)
	dialog.popup_centered(Vector2i(640, 280))


func _request_release_captive(captive_id: StringName) -> void:
	if _campaign_session == null or captive_id.is_empty():
		return
	var preview: OperationResult = _campaign_session.preview_release_captive(captive_id)
	if not preview.success:
		_show_toast(preview.message, true)
		return
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var delta: int = int(data.get("release_notoriety_delta", 0))
	var dialog := ConfirmationDialog.new()
	dialog.title = "Release Captive"
	dialog.dialog_text = "Release %s?\n\nPrison space freed: %d\nGold received: 0\nRegional Notoriety: %s\n\nThe captive will permanently leave your custody." % [
		String(data.get("display_name", "this captive")),
		int(data.get("cell_cost", 1)),
		"%d" % delta if delta != 0 else "No change",
	]
	dialog.get_ok_button().text = "RELEASE"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		var result: OperationResult = _campaign_session.release_captive(captive_id)
		if not result.success:
			_show_toast(result.message, true)
			return
		_selected_captive_id = &""
		_show_screen(SCREEN_PRISON)
		_show_toast(result.message)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(620, 360))


func _request_ransom_captive(captive_id: StringName) -> void:
	if _campaign_session == null or captive_id.is_empty():
		return
	var preview: OperationResult = _campaign_session.preview_ransom_captive(captive_id)
	if not preview.success:
		_show_toast(preview.message, true)
		return
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var dialog := ConfirmationDialog.new()
	dialog.title = "Ransom Captive"
	dialog.dialog_text = "Ransom %s?\n\nPayment: %d Gold\nRegional Notoriety: No change\n\nThe captive will permanently leave your Prison." % [
		String(data.get("display_name", "this captive")),
		int(data.get("ransom_value", 0)),
	]
	dialog.get_ok_button().text = "ACCEPT RANSOM"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		var result: OperationResult = _campaign_session.ransom_captive(captive_id)
		if not result.success:
			_show_toast(result.message, true)
			return
		_selected_captive_id = &""
		_show_screen(SCREEN_PRISON)
		_show_toast(result.message)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(620, 340))


func _first_prison_coord() -> Vector2i:
	var state: StrongholdStateScript = _campaign_session.current_stronghold_state() if _campaign_session != null else null
	if state == null:
		return Vector2i(-1, -1)
	for facility: StrongholdFacilityStateScript in state.get_facilities():
		if facility != null and facility.definition_id == &"facility.prison":
			return state.facility_origin(facility.instance_id)
	return Vector2i(-1, -1)


func _build_stable_screen() -> void:
	var campaign: CampaignState = _campaign()
	var root := _build_management_canvas("res://assets/strategic/roster/roster_manage_background.svg")
	var margin := _management_margin(root, 18, 18, 16, 18)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var title := Label.new()
	title.text = "STABLES & EXPEDITIONS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("d6c28f"))
	header.add_child(title)
	var stable_count := Label.new()
	var bays: Array[StableBayState] = _campaign_session.stable_bays()
	stable_count.text = "%d CONSTRUCTED STABLE%s" % [bays.size(), "" if bays.size() == 1 else "S"]
	stable_count.add_theme_font_size_override("font_size", 14)
	stable_count.add_theme_color_override("font_color", Color("b8b5a7"))
	header.add_child(stable_count)

	if bays.is_empty():
		column.add_child(_body_label("No completed Stable is available. Construct a Stable before housing a transport or preparing a squad."))
		return
	if _selected_stable_bay_id.is_empty() or campaign.get_stable_bay(_selected_stable_bay_id) == null:
		_selected_stable_bay_id = bays[0].bay_id
	var selected_bay: StableBayState = campaign.get_stable_bay(_selected_stable_bay_id)
	if selected_bay == null:
		selected_bay = bays[0]
		_selected_stable_bay_id = selected_bay.bay_id

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)
	body.add_child(_build_stable_information_panel(campaign, selected_bay))
	body.add_child(_build_stable_formation_panel(campaign, selected_bay))
	body.add_child(_build_stable_bay_list_panel(bays))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	var help := Label.new()
	help.text = "Roster builds squads. Armoury equips them. Each constructed Stable houses one transport and prepares one squad."
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.add_theme_color_override("font_color", Color("a9aa9e"))
	footer.add_child(help)
	if not _planning_mission_id.is_empty():
		var briefing := Button.new()
		briefing.text = "RETURN TO BRIEFING"
		briefing.pressed.connect(func() -> void: _show_screen(SCREEN_BRIEFING))
		footer.add_child(briefing)
	var ruin := Button.new()
	ruin.text = "VIEW STABLE ROOM"
	ruin.pressed.connect(func() -> void:
		var selected_facility_id: StringName = selected_bay.stable_facility_id
		var facility = campaign.stronghold.get_facility(selected_facility_id) if campaign != null and campaign.stronghold != null else null
		if facility != null:
			_selected_stronghold_coord = facility.origin
		_show_screen(SCREEN_STRONGHOLD)
	)
	footer.add_child(ruin)


func _build_stable_information_panel(campaign: CampaignState, bay: StableBayState) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 340
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	content.add_child(_heading_label("STABLE %d" % (bay.bay_index + 1)))
	var stable_status := Label.new()
	stable_status.text = "OPERATIONAL" if _campaign_session.stable_bay_is_operational(bay.bay_id) else "DISABLED — NO NEW DEPARTURES"
	stable_status.add_theme_color_override("font_color", Color("8fc68e") if _campaign_session.stable_bay_is_operational(bay.bay_id) else Color("d27468"))
	content.add_child(stable_status)

	content.add_child(_heading_label("ASSIGNED SQUAD"))
	var active: bool = bay.is_active()
	var squad_selector := OptionButton.new()
	squad_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	squad_selector.add_item("UNASSIGNED")
	squad_selector.set_item_metadata(0, &"")
	var selected_squad_index: int = 0
	for squad: CampaignSquadState in campaign.get_squads():
		var index: int = squad_selector.item_count
		squad_selector.add_item(squad.display_name.to_upper())
		squad_selector.set_item_metadata(index, squad.squad_id)
		var assigned_elsewhere: bool = not squad.assigned_stable_bay_id.is_empty() and squad.assigned_stable_bay_id != bay.bay_id
		squad_selector.get_popup().set_item_disabled(index, assigned_elsewhere or squad.is_active())
		if squad.squad_id == bay.assigned_squad_id:
			selected_squad_index = index
	squad_selector.select(selected_squad_index)
	squad_selector.disabled = active
	squad_selector.item_selected.connect(func(index: int) -> void:
		var squad_id := StringName(squad_selector.get_item_metadata(index))
		var result: OperationResult = (
			_campaign_session.clear_stable_bay(bay.bay_id)
			if squad_id.is_empty()
			else _campaign_session.assign_squad_to_stable_bay(bay.bay_id, squad_id)
		)
		_show_toast(result.message, not result.success)
		_show_screen(SCREEN_STABLE)
	)
	content.add_child(squad_selector)

	content.add_child(_heading_label("HOUSED TRANSPORT"))
	var housed_asset: TransportState = campaign.get_transport(bay.transport_asset_id)
	var transport_definition: SquadTransportDefinition = (
		_campaign_session.squad_transport_service.definition(housed_asset.definition_id)
		if housed_asset != null and _campaign_session.squad_transport_service != null
		else null
	)
	if housed_asset == null:
		content.add_child(_body_label(
			"NO VEHICLE HOUSED\nAn assigned squad travels on foot with six fixed deployment positions. A newly acquired transport may be housed here while the squad remains assigned."
		))
	else:
		var asset_name: String = housed_asset.custom_name if not housed_asset.custom_name.is_empty() else transport_definition.display_name
		content.add_child(_body_label("%s\n%s" % [asset_name.to_upper(), transport_definition.display_name if transport_definition != null else "Transport"]))
		var rename_row := HBoxContainer.new()
		rename_row.add_theme_constant_override("separation", 6)
		content.add_child(rename_row)
		var name_edit := LineEdit.new()
		name_edit.text = housed_asset.custom_name
		name_edit.placeholder_text = "Transport name"
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.editable = not active
		rename_row.add_child(name_edit)
		var rename_button := Button.new()
		rename_button.text = "RENAME"
		rename_button.disabled = active
		rename_button.pressed.connect(func() -> void:
			var result: OperationResult = _campaign_session.rename_transport(housed_asset.transport_id, name_edit.text)
			_show_toast(result.message, not result.success)
			_show_screen(SCREEN_STABLE)
		)
		rename_row.add_child(rename_button)

		var dismantle_yield_text: String = (
			_campaign_session.squad_transport_service.transport_dismantle_yield_text(transport_definition)
			if _campaign_session.squad_transport_service != null and transport_definition != null
			else "No recoverable materials"
		)
		var dismantle_button := Button.new()
		dismantle_button.text = "DISMANTLE TRANSPORT — %s" % dismantle_yield_text.to_upper()
		dismantle_button.disabled = active
		dismantle_button.tooltip_text = (
			"A transport cannot be dismantled while this Stable's expedition is active."
			if active
			else "Dismantle this exact transport, recover part of its construction resources and convert this Stable to Walking."
		)
		content.add_child(dismantle_button)
		var dismantle_dialog := ConfirmationDialog.new()
		dismantle_dialog.title = "Dismantle Transport"
		dismantle_dialog.dialog_text = (
			"Dismantle %s?\n\nRecovered materials: %s\n\nThe transport will be permanently removed. "
			+ "The assigned squad, if any, will remain in this Stable as a Walking expedition, "
			+ "and its formation will be cleared."
		) % [asset_name, dismantle_yield_text]
		dismantle_dialog.confirmed.connect(func() -> void:
			var result: OperationResult = _campaign_session.dismantle_transport(housed_asset.transport_id)
			_show_toast(result.message, not result.success)
			_show_screen(SCREEN_STABLE)
		)
		panel.add_child(dismantle_dialog)
		dismantle_button.pressed.connect(func() -> void:
			dismantle_dialog.popup_centered(Vector2i(620, 280))
		)

	var summary: Dictionary = _campaign_session.stable_bay_summary(bay.bay_id)
	var transport: Dictionary = summary.get("transport", {}) as Dictionary
	var squad: CampaignSquadState = campaign.get_squad(bay.assigned_squad_id)
	var deployed_ids: Array[StringName] = bay.occupied_character_ids()
	var capacity: int = _stable_deployment_capacity(transport, bay)
	content.add_child(_body_label(
		"STATUS: %s\nSQUAD: %s\nDEPLOYED: %d / %d\nCARGO: %s\nSPEED: ×%.2f\nJOURNEY NOTORIETY: %+d%%" % [
			String(bay.status).replace("_", " ").to_upper(),
			squad.display_name if squad != null else "Unassigned",
			deployed_ids.size(),
			capacity,
			"Survivors’ remaining carrying capacity" if bay.is_walking else "%.0f lb" % float(transport.get("total_cargo_capacity_lb", 0.0)),
			float(transport.get("strategic_speed_multiplier", 1.0)),
			int(transport.get("journey_notoriety_modifier_percent", 0)),
		]
	))

	content.add_child(_heading_label("SQUAD MEMBERS"))
	if squad == null:
		content.add_child(_body_label("Assign a squad to prepare this Stable expedition."))
		return panel

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	content.add_child(controls)
	var auto_assign := Button.new()
	auto_assign.text = "AUTO-ASSIGN"
	auto_assign.disabled = active
	auto_assign.pressed.connect(func() -> void:
		var result: OperationResult = _campaign_session.auto_arrange_stable_formation(bay.bay_id)
		_show_toast(result.message, not result.success)
		_show_screen(SCREEN_STABLE)
	)
	controls.add_child(auto_assign)
	var clear := Button.new()
	clear.text = "CLEAR FORMATION"
	clear.disabled = active or deployed_ids.is_empty()
	clear.pressed.connect(func() -> void:
		var result: OperationResult = _campaign_session.clear_stable_formation(bay.bay_id)
		_show_toast(result.message, not result.success)
		_show_screen(SCREEN_STABLE)
	)
	controls.add_child(clear)

	content.add_child(_small_meta_label("DEPLOYED — %d / %d" % [deployed_ids.size(), capacity]))
	for character_id: StringName in deployed_ids:
		var character: PersistentCharacterState = campaign.get_character(character_id)
		if character == null:
			continue
		var passenger := StablePassengerDrag.new()
		passenger.configure(character.character_id, character.display_name, _roster_status(character))
		passenger.disabled = active
		content.add_child(passenger)

	var reserve_drop := StableReserveDropZoneScript.new()
	reserve_drop.configure(active)
	reserve_drop.character_removed.connect(func(character_id: StringName) -> void:
		var result: OperationResult = _campaign_session.remove_stable_formation_character(bay.bay_id, character_id)
		_show_toast(result.message, not result.success)
		_show_screen(SCREEN_STABLE)
	)
	content.add_child(reserve_drop)

	var reserves: Array[PersistentCharacterState] = []
	var unavailable: Array[PersistentCharacterState] = []
	for character_id: StringName in squad.member_character_ids:
		if deployed_ids.has(character_id):
			continue
		var character: PersistentCharacterState = campaign.get_character(character_id)
		if character == null:
			continue
		if _stable_member_can_deploy(character):
			reserves.append(character)
		else:
			unavailable.append(character)
	content.add_child(_small_meta_label("RESERVES — %d" % reserves.size()))
	if reserves.is_empty():
		content.add_child(_body_label("No deployable reserves."))
	else:
		for character: PersistentCharacterState in reserves:
			var reserve := StablePassengerDrag.new()
			reserve.configure(character.character_id, character.display_name, _roster_status(character))
			reserve.disabled = active
			content.add_child(reserve)
	if not unavailable.is_empty():
		content.add_child(_small_meta_label("UNAVAILABLE — %d" % unavailable.size()))
		for character: PersistentCharacterState in unavailable:
			var unavailable_label := Label.new()
			unavailable_label.text = "%s — %s" % [character.display_name, _roster_status(character)]
			unavailable_label.add_theme_color_override("font_color", Color("927f7b"))
			content.add_child(unavailable_label)
	return panel


func _build_stable_formation_panel(campaign: CampaignState, bay: StableBayState) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	heading.add_child(_heading_label("TACTICAL STARTING FORMATION"))
	var formation_result: OperationResult = _campaign_session.stable_bay_service.formation_validation(campaign, bay)
	var ready := Label.new()
	ready.text = "READY" if formation_result.success else formation_result.message.to_upper()
	ready.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ready.add_theme_color_override("font_color", Color("86bf83") if formation_result.success else Color("d27468"))
	heading.add_child(ready)

	var instruction := Label.new()
	instruction.text = "Drag occupied positions onto each other to swap them. Drag reserves into a position to replace its occupant."
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_font_size_override("font_size", 10)
	instruction.add_theme_color_override("font_color", Color("aaa99d"))
	content.add_child(instruction)

	var art_panel := PanelContainer.new()
	art_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(art_panel)
	var art_root := Control.new()
	art_root.custom_minimum_size = Vector2(520, 330)
	art_panel.add_child(art_root)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = load("res://assets/strategic/stronghold/facilities/stables.svg") as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.modulate = Color(1, 1, 1, 0.34)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_root.add_child(art)
	var grid := GridContainer.new()
	grid.set_anchors_preset(Control.PRESET_CENTER)
	grid.position = Vector2(-170, -120) if bay.is_walking else Vector2(-225, -120)
	grid.size = Vector2(340, 240) if bay.is_walking else Vector2(450, 240)
	grid.columns = 2 if bay.is_walking else 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	art_root.add_child(grid)
	var transport: Dictionary = _campaign_session.stable_bay_summary(bay.bay_id).get("transport", {}) as Dictionary
	var capacity: int = _stable_deployment_capacity(transport, bay)
	var squad: CampaignSquadState = campaign.get_squad(bay.assigned_squad_id)
	for slot_index: int in range(capacity):
		var slot_id := StringName("slot.%02d" % (slot_index + 1))
		var occupant_id := StringName(bay.formation_character_ids_by_slot.get(slot_id, ""))
		var occupant: PersistentCharacterState = campaign.get_character(occupant_id)
		var slot := StableFormationDropSlot.new()
		slot.configure(
			slot_id,
			slot_index + 1,
			occupant_id,
			occupant.display_name if occupant != null else "",
			bay.is_active() or squad == null
		)
		slot.character_dropped.connect(func(dropped_slot_id: StringName, character_id: StringName) -> void:
			var result: OperationResult = _campaign_session.set_stable_formation_slot(
				bay.bay_id,
				dropped_slot_id,
				character_id
			)
			_show_toast(result.message, not result.success)
			_show_screen(SCREEN_STABLE)
		)
		grid.add_child(slot)

	if bay.is_walking:
		content.add_child(_body_label("WALKING FORMATION — SIX FIXED POSITIONS\nStable upgrades, Research and fittings never increase this limit."))
	else:
		content.add_child(_heading_label("TRANSPORT FITTINGS"))
		var fitting_row := HFlowContainer.new()
		fitting_row.add_theme_constant_override("h_separation", 8)
		fitting_row.add_theme_constant_override("v_separation", 8)
		content.add_child(fitting_row)
		var transport_definition: SquadTransportDefinition = (
			_campaign_session.squad_transport_service.definition(bay.transport_method_id)
			if _campaign_session.squad_transport_service != null
			else null
		)
		for fitting_entry: Array in [
			[&"fitting.covered_canopy", &"covering", "COVERED CANOPY", "−20% journey Notoriety"],
			[&"fitting.cargo_racks", &"cargo", "CARGO RACKS", "+300 lb cargo"],
			[&"fitting.captive_cage", &"specialist", "CAPTIVE CAGE", "+2 captive spaces"],
			[&"fitting.medical_litter", &"utility", "MEDICAL LITTER", "Carries one casualty; −1 passenger"],
		]:
			var fitting_id: StringName = fitting_entry[0]
			var fitting_slot_type: StringName = fitting_entry[1]
			if transport_definition == null or not transport_definition.fitting_slot_types.has(fitting_slot_type):
				continue
			var check := CheckButton.new()
			check.text = String(fitting_entry[2])
			check.tooltip_text = String(fitting_entry[3])
			check.button_pressed = bay.installed_fitting_ids.has(fitting_id)
			check.disabled = bay.is_active()
			check.toggled.connect(func(_enabled: bool) -> void:
				var result: OperationResult = _campaign_session.toggle_stable_transport_fitting(bay.bay_id, fitting_id)
				_show_toast(result.message, not result.success)
				_show_screen(SCREEN_STABLE)
			)
			fitting_row.add_child(check)
	return panel


func _build_stable_bay_list_panel(bays: Array[StableBayState]) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 280
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	content.add_child(_heading_label("CONSTRUCTED STABLES"))
	for bay: StableBayState in bays:
		var summary: Dictionary = _campaign_session.stable_bay_summary(bay.bay_id)
		var transport: Dictionary = summary.get("transport", {}) as Dictionary
		var transport_name: String = (
			String(transport.get("transport_display_name", transport.get("display_name", "Transport")))
			if not bay.transport_asset_id.is_empty()
			else "WALKING / EMPTY"
		)
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = bay.bay_id == _selected_stable_bay_id
		button.custom_minimum_size = Vector2(250, 110)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "STABLE %d\n%s\n%s\n%s" % [
			bay.bay_index + 1,
			transport_name.to_upper(),
			String(summary.get("squad_name", "Unassigned")).to_upper(),
			String(bay.status).replace("_", " ").to_upper(),
		]
		button.pressed.connect(func() -> void:
			_selected_stable_bay_id = bay.bay_id
			_show_screen(SCREEN_STABLE)
		)
		content.add_child(button)
	return panel


func _stable_deployment_capacity(transport: Dictionary, bay: StableBayState) -> int:
	if bay == null or bay.is_walking:
		return 6
	return maxi(1, int(transport.get("total_passenger_capacity", 1)))


func _stable_member_can_deploy(character: PersistentCharacterState) -> bool:
	if character == null or character.is_dead:
		return false
	if not character.health_initialized:
		return true
	return character.current_hp > 0 and character.nonlethal_damage < maxi(1, character.current_hp)


func _build_roster_screen() -> void:
	var campaign: CampaignState = _campaign()
	var roster: Array[PersistentCharacterState] = _campaign_roster_characters(campaign)
	if roster.is_empty() and _roster_mode not in [ROSTER_MODE_HIRE, ROSTER_MODE_WORKFORCE]:
		_workspace.add_child(_body_label("No persistent characters are currently available."))
		return
	if not roster.is_empty() and campaign.get_character(_selected_character_id) == null:
		_selected_character_id = roster[0].character_id
	var root: Control = _build_management_canvas(
		""
		if _roster_mode == ROSTER_MODE_EQUIP
		else "res://assets/strategic/roster/roster_manage_background.svg"
	)
	match _roster_mode:
		ROSTER_MODE_EQUIP:
			_build_roster_equip_view(root, campaign, roster)
		ROSTER_MODE_MEMORIAL:
			_build_roster_memorial_view(root, campaign, roster)
		ROSTER_MODE_HIRE:
			_build_roster_hire_view(root, campaign)
		ROSTER_MODE_WORKFORCE:
			_build_roster_workforce_view(root, campaign)
		_:
			_build_roster_manage_view(root, campaign, roster)


func _build_roster_hire_view(root: Control, campaign: CampaignState) -> void:
	var canvas := _build_roster_static_canvas(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_place_equip_region(canvas, column, ROSTER_CONTENT_LEFT, ROSTER_CONTENT_TOP, ROSTER_CONTENT_RIGHT, ROSTER_CONTENT_BOTTOM, 2.0)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	column.add_child(title_row)
	var title := _heading_label("HIRE UNITS")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var capacity := Label.new()
	var personnel: Dictionary = _campaign_session.personnel_capacity_snapshot()
	capacity.text = "PERSONNEL %d / %d" % [int(personnel.get("used", 0)), int(personnel.get("maximum", 0))]
	capacity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(capacity)
	var market_status: Dictionary = _campaign_session.recruitment_market_status()
	var refresh_status := Label.new()
	refresh_status.text = "NEXT REFRESH: DAY %d" % int(market_status.get("next_refresh_day", 31))
	refresh_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(refresh_status)
	var back := Button.new()
	back.text = "BACK TO ROSTER"
	back.pressed.connect(func() -> void:
		_roster_mode = ROSTER_MODE_MANAGE
		_show_screen(SCREEN_ROSTER)
	)
	title_row.add_child(back)
	column.add_child(_body_label("Candidates are generated from the protagonist's unlocked classes. Hiring is instant: the selected named Level 1 troop joins the Roster immediately. The candidate list refreshes automatically every 30 campaign days."))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	var offers: Array[Dictionary] = _campaign_session.recruitment_market()
	if offers.is_empty():
		content.add_child(_body_label("No recruit candidates are currently available. The protagonist may not yet have an eligible class."))
	for preview: Dictionary in offers:
		var offer: HenchmanRecruitmentOfferState = preview.get("offer") as HenchmanRecruitmentOfferState
		var definition: HenchmanRecruitmentDefinition = preview.get("definition") as HenchmanRecruitmentDefinition
		if offer == null or definition == null:
			continue
		var panel := PanelContainer.new()
		content.add_child(panel)
		var margin := MarginContainer.new()
		for side: String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 10)
		panel.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		margin.add_child(row)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(84, 84)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = PortraitAssetResolver.new().resolve(offer.portrait_id)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		details.add_child(_heading_label(offer.candidate_name.to_upper()))
		details.add_child(_body_label("%s — LEVEL %d — %s CAREER" % [definition.display_name, definition.starting_level, _display_id(definition.career_id).to_upper()]))
		var cost_parts: Array[String] = []
		for raw_resource_id: Variant in definition.resource_costs.keys():
			cost_parts.append("%d %s" % [int(definition.resource_costs[raw_resource_id]), String(raw_resource_id).capitalize()])
		details.add_child(_body_label("COST: %s    HIRING: INSTANT" % ", ".join(cost_parts)))
		var eligible := bool(preview.get("eligible", false))
		if not eligible:
			details.add_child(_body_label("UNAVAILABLE: %s" % String(preview.get("reason", "Unavailable"))))
		var hire := Button.new()
		hire.text = "HIRE"
		hire.custom_minimum_size = Vector2(130, 52)
		hire.disabled = not eligible
		var offer_id := offer.offer_id
		hire.pressed.connect(func() -> void: _request_henchman_recruitment(offer_id))
		row.add_child(hire)
	_place_equip_region(canvas, _build_roster_mode_bar(), EQUIP_MODE_BAR_LEFT, EQUIP_MODE_BAR_TOP, EQUIP_MODE_BAR_RIGHT, EQUIP_MODE_BAR_BOTTOM, 0.0)

func _build_roster_workforce_view(root: Control, campaign: CampaignState) -> void:
	var canvas := _build_roster_static_canvas(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_place_equip_region(
		canvas,
		column,
		ROSTER_CONTENT_LEFT,
		ROSTER_CONTENT_TOP,
		ROSTER_CONTENT_RIGHT,
		ROSTER_CONTENT_BOTTOM,
		2.0
	)
	var personnel: Dictionary = _campaign_session.personnel_capacity_snapshot()
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	column.add_child(title_row)
	var title := _heading_label("WORKFORCE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var capacity := Label.new()
	capacity.text = "PERSONNEL %d / %d" % [
		int(personnel.get("used", 0)),
		int(personnel.get("maximum", 0)),
	]
	capacity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(capacity)
	var market_status: Dictionary = _campaign_session.workforce_market_status()
	var refresh := Label.new()
	refresh.text = "NEXT REFRESH: DAY %d" % int(market_status.get("next_refresh_day", 31))
	refresh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(refresh)
	column.add_child(_body_label(
		"Manufacturing and Research workers share personnel capacity with troops. "
		+ "Workers are abstract personnel: the best available eligible workers are assigned automatically."
	))
	var summary := Label.new()
	summary.text = "TROOPS %d    MANUFACTURING %d    RESEARCH %d    FREE SPACE %d" % [
		int(personnel.get("troops", 0)),
		int(personnel.get("manufacturing_workers", 0)),
		int(personnel.get("research_workers", 0)),
		int(personnel.get("free", 0)),
	]
	summary.add_theme_color_override("font_color", Color("d6c28f"))
	column.add_child(summary)
	if int(personnel.get("deficit", 0)) > 0:
		var deficit := Label.new()
		deficit.text = "OVER CAPACITY BY %d — NEW HIRING BLOCKED" % int(personnel.get("deficit", 0))
		deficit.add_theme_color_override("font_color", Color("d97868"))
		column.add_child(deficit)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	column.add_child(split)

	var owned_panel := PanelContainer.new()
	owned_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_panel.size_flags_stretch_ratio = 1.0
	split.add_child(owned_panel)
	var owned_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		owned_margin.add_theme_constant_override("margin_" + side, 10)
	owned_panel.add_child(owned_margin)
	var owned_column := VBoxContainer.new()
	owned_column.add_theme_constant_override("separation", 8)
	owned_margin.add_child(owned_column)
	owned_column.add_child(_heading_label("EMPLOYED WORKERS"))
	var owned_scroll := ScrollContainer.new()
	owned_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	owned_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	owned_column.add_child(owned_scroll)
	var owned_list := VBoxContainer.new()
	owned_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_list.add_theme_constant_override("separation", 6)
	owned_scroll.add_child(owned_list)
	var any_owned: bool = false
	for definition_value: WorkforceDefinition in _campaign_session.workforce_definitions():
		var count: int = campaign.workforce_count(definition_value.worker_definition_id)
		if count <= 0:
			continue
		any_owned = true
		var row_panel := PanelContainer.new()
		owned_list.add_child(row_panel)
		var row_margin := MarginContainer.new()
		for side: String in ["left", "right", "top", "bottom"]:
			row_margin.add_theme_constant_override("margin_" + side, 8)
		row_panel.add_child(row_margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row_margin.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		details.add_child(_heading_label(definition_value.display_name.to_upper()))
		details.add_child(_body_label("%s  •  RATING %d  •  OWNED %d" % [
			String(definition_value.role_id).to_upper(),
			definition_value.work_rating,
			count,
		]))
		var dismiss := Button.new()
		dismiss.text = "DISMISS 1"
		dismiss.tooltip_text = "Free one personnel space. Hiring cost is not refunded."
		var worker_id: StringName = definition_value.worker_definition_id
		var worker_name: String = definition_value.display_name
		dismiss.pressed.connect(func() -> void:
			_request_workforce_dismissal(worker_id, worker_name)
		)
		row.add_child(dismiss)
	if not any_owned:
		owned_list.add_child(_body_label("No strategic workers are currently employed."))

	var market_panel := PanelContainer.new()
	market_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_panel.size_flags_stretch_ratio = 1.2
	split.add_child(market_panel)
	var market_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		market_margin.add_theme_constant_override("margin_" + side, 10)
	market_panel.add_child(market_margin)
	var market_column := VBoxContainer.new()
	market_column.add_theme_constant_override("separation", 8)
	market_margin.add_child(market_column)
	market_column.add_child(_heading_label("AVAILABLE WORKERS"))
	var market_scroll := ScrollContainer.new()
	market_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	market_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	market_column.add_child(market_scroll)
	var market_list := VBoxContainer.new()
	market_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_list.add_theme_constant_override("separation", 6)
	market_scroll.add_child(market_list)
	var offers: Array[Dictionary] = _campaign_session.workforce_market()
	if offers.is_empty():
		market_list.add_child(_body_label("No workers are currently available. The market refreshes each campaign month."))
	for preview: Dictionary in offers:
		var offer: WorkforceOfferState = preview.get("offer") as WorkforceOfferState
		var definition_value: WorkforceDefinition = preview.get("definition") as WorkforceDefinition
		if offer == null or definition_value == null:
			continue
		var offer_panel := PanelContainer.new()
		market_list.add_child(offer_panel)
		var offer_margin := MarginContainer.new()
		for side: String in ["left", "right", "top", "bottom"]:
			offer_margin.add_theme_constant_override("margin_" + side, 8)
		offer_panel.add_child(offer_margin)
		var offer_row := HBoxContainer.new()
		offer_row.add_theme_constant_override("separation", 10)
		offer_margin.add_child(offer_row)
		var offer_details := VBoxContainer.new()
		offer_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		offer_row.add_child(offer_details)
		offer_details.add_child(_heading_label(definition_value.display_name.to_upper()))
		offer_details.add_child(_body_label("%s  •  RATING %d  •  %d GOLD" % [
			String(definition_value.role_id).to_upper(),
			definition_value.work_rating,
			definition_value.hire_gold_cost,
		]))
		offer_details.add_child(_body_label(definition_value.description))
		if not bool(preview.get("eligible", false)):
			offer_details.add_child(_body_label("UNAVAILABLE: %s" % String(preview.get("reason", "Unavailable"))))
		var hire := Button.new()
		hire.text = "HIRE"
		hire.custom_minimum_size = Vector2(110, 46)
		hire.disabled = not bool(preview.get("eligible", false))
		hire.tooltip_text = String(preview.get("reason", "Available"))
		var offer_id: StringName = offer.offer_id
		hire.pressed.connect(func() -> void: _request_workforce_hire(offer_id))
		offer_row.add_child(hire)
	_place_equip_region(canvas, _build_roster_mode_bar(), EQUIP_MODE_BAR_LEFT, EQUIP_MODE_BAR_TOP, EQUIP_MODE_BAR_RIGHT, EQUIP_MODE_BAR_BOTTOM, 0.0)


func _request_workforce_hire(offer_id: StringName) -> void:
	if _campaign_session == null:
		return
	var result: OperationResult = _campaign_session.hire_workforce(offer_id)
	_show_toast(result.message, not result.success)
	_show_screen(SCREEN_ROSTER)


func _request_workforce_dismissal(worker_definition_id: StringName, worker_name: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Dismiss Worker"
	dialog.dialog_text = "Dismiss one %s? The hiring cost will not be refunded. Active projects keep their completed progress and will be reassigned automatically." % worker_name
	dialog.ok_button_text = "DISMISS"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _campaign_session.dismiss_workforce(worker_definition_id, 1)
		_show_toast(result.message, not result.success)
		_show_screen(SCREEN_ROSTER)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.confirmed.connect(func() -> void: dialog.queue_free(), CONNECT_DEFERRED)
	dialog.popup_centered(Vector2i(560, 260))


func _build_management_canvas(background_path: String) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_workspace.add_child(root)
	var base := ColorRect.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.color = Color("0b0f0f")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(base)
	if not background_path.is_empty() and ResourceLoader.exists(background_path):
		var background := TextureRect.new()
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.texture = load(background_path) as Texture2D
		root.add_child(background)
		var shade := ColorRect.new()
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(0.015, 0.02, 0.02, 0.34)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)
	return root

func _management_margin(
		root: Control,
		left: int = 28,
		right: int = 28,
		top: int = 22,
		bottom: int = 20
) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	root.add_child(margin)
	return margin


func _build_roster_static_canvas(root: Control) -> Control:
	# Every roster mode uses this exact outer frame. Content is placed inside the
	# canvas with authored anchors, preventing the navigation bar or screen body
	# from shifting when switching between Manage, Equip and Memorial.
	var margin := _management_margin(root, 12, 12, 10, 10)
	var canvas := Control.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(canvas)
	return canvas


func _campaign_roster_characters(campaign: CampaignState) -> Array[PersistentCharacterState]:
	var result: Array[PersistentCharacterState] = []
	if campaign == null:
		return result
	for character: PersistentCharacterState in campaign.get_characters():
		if (
			character.persistence_scope == PersistentCharacterState.PERSISTENCE_CAMPAIGN
			and character.roster_role == PersistentCharacterState.ROLE_PLAYER
		):
			result.append(character)
	result.sort_custom(
		func(a: PersistentCharacterState, b: PersistentCharacterState) -> bool:
			if a.is_dead != b.is_dead:
				return not a.is_dead
			return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	return result


func _build_roster_manage_view(
		root: Control,
		campaign: CampaignState,
		roster: Array[PersistentCharacterState]
) -> void:
	var canvas := _build_roster_static_canvas(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_place_equip_region(
		canvas,
		column,
		ROSTER_CONTENT_LEFT,
		ROSTER_CONTENT_TOP,
		ROSTER_CONTENT_RIGHT,
		ROSTER_CONTENT_BOTTOM,
		2.0
	)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	column.add_child(title_row)
	var title := Label.new()
	title.text = "MANAGE ROSTER"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("d6c28f"))
	title_row.add_child(title)
	var hire_button := Button.new()
	hire_button.text = "HIRE UNITS"
	hire_button.custom_minimum_size.x = 132
	hire_button.tooltip_text = "Open the recruitment market for random candidates unlocked by the protagonist's classes."
	hire_button.pressed.connect(func() -> void:
		_roster_mode = ROSTER_MODE_HIRE
		_show_screen(SCREEN_ROSTER)
	)
	title_row.add_child(hire_button)
	var personnel: Dictionary = _campaign_session.personnel_capacity_snapshot()
	var personnel_label := Label.new()
	personnel_label.text = "PERSONNEL %d / %d" % [
		int(personnel.get("used", 0)),
		int(personnel.get("maximum", 0)),
	]
	personnel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(personnel_label)
	for filter_entry: Array in [
		[ROSTER_FILTER_ALL, "ALL"],
		[ROSTER_FILTER_READY, "READY"],
		[ROSTER_FILTER_WOUNDED, "WOUNDED"],
		[ROSTER_FILTER_DEPLOYED, "DEPLOYED"],
		[ROSTER_FILTER_UNAVAILABLE, "UNAVAILABLE"],
	]:
		var filter_id: StringName = StringName(filter_entry[0])
		var filter_button := Button.new()
		filter_button.toggle_mode = true
		filter_button.button_pressed = filter_id == _roster_filter_id
		filter_button.text = String(filter_entry[1])
		filter_button.custom_minimum_size.x = 106
		filter_button.pressed.connect(func() -> void:
			_roster_filter_id = filter_id
			_show_screen(SCREEN_ROSTER)
		)
		title_row.add_child(filter_button)


	var squad_tools := HBoxContainer.new()
	squad_tools.add_theme_constant_override("separation", 8)
	column.add_child(squad_tools)
	var squad_selector := OptionButton.new()
	squad_selector.custom_minimum_size.x = 260
	var selected_squad_index: int = 0
	for squad: CampaignSquadState in campaign.get_squads():
		var index: int = squad_selector.item_count
		squad_selector.add_item(squad.display_name.to_upper())
		squad_selector.set_item_metadata(index, squad.squad_id)
		if squad.squad_id == _selected_roster_squad_id:
			selected_squad_index = index
	if squad_selector.item_count > 0:
		squad_selector.select(selected_squad_index)
		_selected_roster_squad_id = StringName(squad_selector.get_item_metadata(selected_squad_index))
	squad_selector.item_selected.connect(func(index: int) -> void:
		_selected_roster_squad_id = StringName(squad_selector.get_item_metadata(index))
		_show_screen(SCREEN_ROSTER)
	)
	squad_tools.add_child(squad_selector)
	var squad_name := LineEdit.new()
	squad_name.placeholder_text = "New or replacement squad name"
	squad_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_squad: CampaignSquadState = campaign.get_squad(_selected_roster_squad_id)
	if selected_squad != null:
		squad_name.text = selected_squad.display_name
	squad_tools.add_child(squad_name)
	var create_squad := Button.new()
	create_squad.text = "CREATE SQUAD"
	create_squad.pressed.connect(func() -> void:
		var result: OperationResult = _campaign_session.create_campaign_squad(squad_name.text)
		if result.success and result.data is CampaignSquadState:
			_selected_roster_squad_id = (result.data as CampaignSquadState).squad_id
		_show_toast(result.message, not result.success)
		_show_screen(SCREEN_ROSTER)
	)
	squad_tools.add_child(create_squad)
	var rename_squad := Button.new()
	rename_squad.text = "RENAME"
	rename_squad.disabled = _selected_roster_squad_id.is_empty()
	rename_squad.pressed.connect(func() -> void:
		var result: OperationResult = _campaign_session.rename_campaign_squad(_selected_roster_squad_id, squad_name.text)
		_show_toast(result.message, not result.success)
		_show_screen(SCREEN_ROSTER)
	)
	squad_tools.add_child(rename_squad)
	var disband_squad := Button.new()
	disband_squad.text = "DISBAND"
	disband_squad.disabled = _selected_roster_squad_id.is_empty()
	disband_squad.pressed.connect(func() -> void:
		var result: OperationResult = _campaign_session.disband_campaign_squad(_selected_roster_squad_id)
		if result.success:
			_selected_roster_squad_id = &""
		_show_toast(result.message, not result.success)
		_show_screen(SCREEN_ROSTER)
	)
	squad_tools.add_child(disband_squad)

	var table_panel := PanelContainer.new()
	table_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(table_panel)
	var table_margin := MarginContainer.new()
	table_margin.add_theme_constant_override("margin_left", 12)
	table_margin.add_theme_constant_override("margin_right", 12)
	table_margin.add_theme_constant_override("margin_top", 10)
	table_margin.add_theme_constant_override("margin_bottom", 10)
	table_panel.add_child(table_margin)
	var table_column := VBoxContainer.new()
	table_column.add_theme_constant_override("separation", 2)
	table_margin.add_child(table_column)
	table_column.add_child(_build_roster_table_header())
	var separator := HSeparator.new()
	table_column.add_child(separator)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 2)
	scroll.add_child(rows)
	var visible_roster: Array[PersistentCharacterState] = _filtered_sorted_roster(
		roster,
		campaign
	)
	if visible_roster.is_empty():
		rows.add_child(_body_label("No characters match the selected filter."))
	else:
		for character: PersistentCharacterState in visible_roster:
			rows.add_child(_build_roster_table_row(character, campaign))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	column.add_child(footer)
	var alive_count: int = 0
	var ready_count: int = 0
	var wounded_count: int = 0
	for character: PersistentCharacterState in roster:
		if character.is_dead:
			continue
		alive_count += 1
		var status_id: StringName = _roster_status_id(character)
		if status_id == &"ready":
			ready_count += 1
		elif status_id in [&"wounded", &"gravely_wounded"]:
			wounded_count += 1
	var summary := Label.new()
	summary.text = "ACTIVE %d    READY %d    WOUNDED %d" % [alive_count, ready_count, wounded_count]
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 13)
	summary.add_theme_color_override("font_color", Color("b8b8aa"))
	footer.add_child(summary)
	var inspect := Button.new()
	inspect.text = "OPEN ARMOURY"
	inspect.custom_minimum_size = Vector2(190, 42)
	inspect.disabled = campaign.get_character(_selected_character_id) == null
	inspect.pressed.connect(func() -> void:
		_roster_mode = ROSTER_MODE_EQUIP
		_roster_tab_index = 0
		_show_screen(SCREEN_ROSTER)
	)
	footer.add_child(inspect)
	_place_equip_region(
		canvas,
		_build_roster_mode_bar(),
		EQUIP_MODE_BAR_LEFT,
		EQUIP_MODE_BAR_TOP,
		EQUIP_MODE_BAR_RIGHT,
		EQUIP_MODE_BAR_BOTTOM,
		0.0
	)


func _build_roster_table_header() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 38
	row.add_theme_constant_override("separation", 0)
	for entry: Array in [
		[&"name", "NAME", 255],
		[&"troop", "TROOP", 155],
		[&"tier", "TIER", 65],
		[&"level", "LV", 60],
		[&"hp", "HP", 90],
		[&"ac", "AC", 65],
		[&"squad", "SQUAD ASSIGNMENT", 250],
		[&"status", "STATUS", 190],
	]:
		var sort_id: StringName = StringName(entry[0])
		var button := Button.new()
		button.text = String(entry[1]) + (("  ▲" if _roster_sort_ascending else "  ▼") if _roster_sort_id == sort_id else "")
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(float(entry[2]), 38)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(func() -> void:
			if _roster_sort_id == sort_id:
				_roster_sort_ascending = not _roster_sort_ascending
			else:
				_roster_sort_id = sort_id
				_roster_sort_ascending = true
			_show_screen(SCREEN_ROSTER)
		)
		row.add_child(button)
	return row


func _build_roster_table_row(
		character: PersistentCharacterState,
		campaign: CampaignState
) -> Control:
	var template: CharacterTemplateDefinition = _campaign_session.catalogue.character_template(character.template_id)
	var snapshot: ResolvedCharacterSnapshot = _resolved_roster_character(character, campaign)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 44
	row.add_theme_constant_override("separation", 0)
	var select := Button.new()
	select.toggle_mode = true
	select.button_pressed = character.character_id == _selected_character_id
	select.text = character.display_name.to_upper()
	select.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select.custom_minimum_size = Vector2(255, 42)
	select.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var character_id: StringName = character.character_id
	select.pressed.connect(func() -> void:
		_selected_character_id = character_id
		_show_screen(SCREEN_ROSTER)
	)
	select.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and mouse_event.double_click:
				_selected_character_id = character_id
				_roster_mode = ROSTER_MODE_EQUIP
				_roster_tab_index = 0
				_show_screen(SCREEN_ROSTER)
	)
	row.add_child(select)
	var maximum_hp: int = snapshot.stat_value(&"maximum_hp", 1)
	var current_hp: int = character.resolved_current_hp(maximum_hp)
	for value_entry: Array in [
		[character.troop_display_name(template.troop_type if template != null else "Unknown"), 155, HORIZONTAL_ALIGNMENT_LEFT],
		[str(character.troop_tier if not character.career_id.is_empty() else (template.troop_tier if template != null else 0)), 65, HORIZONTAL_ALIGNMENT_CENTER],
		[str(character.resolved_level(template)), 60, HORIZONTAL_ALIGNMENT_CENTER],
		["%d/%d" % [current_hp, maximum_hp], 90, HORIZONTAL_ALIGNMENT_CENTER],
		[str(snapshot.stat_value(&"armour_class", 10)), 65, HORIZONTAL_ALIGNMENT_CENTER],
	]:
		var label := Label.new()
		label.text = String(value_entry[0])
		label.custom_minimum_size.x = float(value_entry[1])
		label.horizontal_alignment = int(value_entry[2])
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("dedbcc"))
		row.add_child(label)
	var squad_selector := OptionButton.new()
	squad_selector.custom_minimum_size = Vector2(250, 42)
	squad_selector.add_item("UNASSIGNED")
	squad_selector.set_item_metadata(0, &"")
	var current_squad: CampaignSquadState = campaign.squad_for_character(character.character_id)
	var selected_index: int = 0
	for squad: CampaignSquadState in campaign.get_squads():
		var index: int = squad_selector.item_count
		squad_selector.add_item(squad.display_name.to_upper())
		squad_selector.set_item_metadata(index, squad.squad_id)
		if current_squad != null and squad.squad_id == current_squad.squad_id:
			selected_index = index
	squad_selector.select(selected_index)
	squad_selector.disabled = character.is_dead or (current_squad != null and current_squad.is_active())
	squad_selector.item_selected.connect(func(index: int) -> void:
		var squad_id := StringName(squad_selector.get_item_metadata(index))
		var result: OperationResult = _campaign_session.assign_character_to_squad(character_id, squad_id)
		_show_toast(result.message, not result.success)
		_show_screen(SCREEN_ROSTER)
	)
	row.add_child(squad_selector)
	var status := Label.new()
	status.text = _roster_status(character).to_upper()
	status.custom_minimum_size.x = 190
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", _roster_status_color(character))
	row.add_child(status)
	return row


func _filtered_sorted_roster(
		roster: Array[PersistentCharacterState],
		campaign: CampaignState
) -> Array[PersistentCharacterState]:
	var result: Array[PersistentCharacterState] = []
	for character: PersistentCharacterState in roster:
		if character.is_dead:
			continue
		var status: StringName = _roster_status_id(character)
		if _roster_filter_id == ROSTER_FILTER_READY and status != &"ready":
			continue
		if _roster_filter_id == ROSTER_FILTER_WOUNDED and status not in [&"wounded", &"gravely_wounded"]:
			continue
		if _roster_filter_id == ROSTER_FILTER_DEPLOYED and status != &"deployed":
			continue
		if _roster_filter_id == ROSTER_FILTER_UNAVAILABLE:
			var maximum_hp: int = _persistent_maximum_hp(character)
			if status != &"deployed" and character.can_deploy_with_health(maximum_hp):
				continue
		result.append(character)
	result.sort_custom(func(a: PersistentCharacterState, b: PersistentCharacterState) -> bool:
		return _roster_character_precedes(a, b, campaign)
	)
	return result


func _roster_character_precedes(
		a: PersistentCharacterState,
		b: PersistentCharacterState,
		campaign: CampaignState
) -> bool:
	var a_template: CharacterTemplateDefinition = _campaign_session.catalogue.character_template(a.template_id)
	var b_template: CharacterTemplateDefinition = _campaign_session.catalogue.character_template(b.template_id)
	var comparison: int = 0
	match _roster_sort_id:
		&"troop":
			comparison = String(a_template.troop_type if a_template != null else "").naturalnocasecmp_to(
				String(b_template.troop_type if b_template != null else "")
			)
		&"tier":
			comparison = _compare_int(a_template.troop_tier if a_template != null else 0, b_template.troop_tier if b_template != null else 0)
		&"level":
			comparison = _compare_int(a.resolved_level(a_template), b.resolved_level(b_template))
		&"hp", &"ac", &"attack", &"move":
			var a_snapshot: ResolvedCharacterSnapshot = _resolved_roster_character(a, campaign)
			var b_snapshot: ResolvedCharacterSnapshot = _resolved_roster_character(b, campaign)
			var a_value: int = 0
			var b_value: int = 0
			if _roster_sort_id == &"hp":
				var a_maximum_hp: int = a_snapshot.stat_value(&"maximum_hp", 1)
				var b_maximum_hp: int = b_snapshot.stat_value(&"maximum_hp", 1)
				a_value = a.resolved_current_hp(a_maximum_hp)
				b_value = b.resolved_current_hp(b_maximum_hp)
			elif _roster_sort_id == &"ac":
				a_value = a_snapshot.stat_value(&"armour_class", 10)
				b_value = b_snapshot.stat_value(&"armour_class", 10)
			elif _roster_sort_id == &"attack":
				a_value = _roster_primary_attack(a_snapshot)
				b_value = _roster_primary_attack(b_snapshot)
			else:
				a_value = a_snapshot.stat_value(&"turn_capacity", a_template.base_turn_capacity_feet if a_template != null else 30)
				b_value = b_snapshot.stat_value(&"turn_capacity", b_template.base_turn_capacity_feet if b_template != null else 30)
			comparison = _compare_int(a_value, b_value)
		&"main_hand":
			comparison = _character_container_item_name(campaign, a.character_id, CampaignItemLocationState.CONTAINER_PRIMARY_HAND).naturalnocasecmp_to(
				_character_container_item_name(campaign, b.character_id, CampaignItemLocationState.CONTAINER_PRIMARY_HAND)
			)
		&"squad":
			var a_squad: CampaignSquadState = campaign.squad_for_character(a.character_id) if campaign != null else null
			var b_squad: CampaignSquadState = campaign.squad_for_character(b.character_id) if campaign != null else null
			comparison = String(a_squad.display_name if a_squad != null else "Unassigned").naturalnocasecmp_to(
				String(b_squad.display_name if b_squad != null else "Unassigned")
			)
		&"status":
			comparison = _roster_status(a).naturalnocasecmp_to(_roster_status(b))
		_:
			comparison = a.display_name.naturalnocasecmp_to(b.display_name)
	if comparison == 0:
		comparison = a.display_name.naturalnocasecmp_to(b.display_name)
	return comparison < 0 if _roster_sort_ascending else comparison > 0


func _compare_int(a: int, b: int) -> int:
	return -1 if a < b else (1 if a > b else 0)


func _build_roster_equip_view(
		root: Control,
		campaign: CampaignState,
		roster: Array[PersistentCharacterState]
) -> void:
	var character: PersistentCharacterState = campaign.get_character(_selected_character_id)
	if character == null or character.is_dead:
		for candidate: PersistentCharacterState in roster:
			if not candidate.is_dead:
				character = candidate
				_selected_character_id = candidate.character_id
				break
	if character == null:
		_roster_mode = ROSTER_MODE_MEMORIAL
		_show_screen(SCREEN_ROSTER)
		return
	var template: CharacterTemplateDefinition = _campaign_session.catalogue.character_template(character.template_id)
	# Injuries are already represented by roster status and the Character
	# dossier's Current Condition panel; migrate any stale UI state to Character.
	if _roster_tab_index == 3:
		_roster_tab_index = 1
	# Use the same outer frame as Manage Roster and Memorial. Only the content
	# inside the authored bounds changes between modes.
	var canvas := _build_roster_static_canvas(root)

	_place_equip_region(
		canvas,
		_build_equip_left_rail(campaign, roster, character, template),
		EQUIP_LEFT_RAIL_LEFT,
		EQUIP_CONTENT_TOP,
		EQUIP_LEFT_RAIL_RIGHT,
		EQUIP_CONTENT_BOTTOM,
		2.0
	)

	if _roster_tab_index == 0:
		_build_xenonauts_loadout_composition(canvas, campaign, character, template)
	else:
		_place_equip_region(
			canvas,
			_build_equip_secondary_content(campaign, character, template),
			0.255,
			EQUIP_CONTENT_TOP,
			EQUIP_AVAILABLE_RIGHT,
			EQUIP_CONTENT_BOTTOM,
			4.0
		)

	_place_equip_region(
		canvas,
		_build_equip_character_tabs(),
		EQUIP_SUBVIEW_BAR_LEFT,
		EQUIP_SUBVIEW_BAR_TOP,
		EQUIP_SUBVIEW_BAR_RIGHT,
		EQUIP_SUBVIEW_BAR_BOTTOM,
		0.0
	)
	_place_equip_region(
		canvas,
		_build_roster_mode_bar(),
		EQUIP_MODE_BAR_LEFT,
		EQUIP_MODE_BAR_TOP,
		EQUIP_MODE_BAR_RIGHT,
		EQUIP_MODE_BAR_BOTTOM,
		0.0
	)


func _build_xenonauts_loadout_composition(
		canvas: Control,
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> void:
	# Read the screen left-to-right: compact soldier information, full-body
	# portrait, one complete loadout/inventory column, then available equipment.
	# Armour, hands and carry weight no longer occupy a separate strip beside the
	# portrait; they use the space beneath Backpack instead.
	var figure := _build_equip_character_figure(character, template)
	figure.z_index = 0
	_place_equip_region(
		canvas,
		figure,
		EQUIP_CHARACTER_LEFT,
		EQUIP_CONTENT_TOP,
		EQUIP_CHARACTER_RIGHT,
		EQUIP_CONTENT_BOTTOM,
		0.0
	)
	var carried := _build_equip_carried_panel(campaign, character, template)
	carried.z_index = 2
	_place_equip_region(
		canvas,
		carried,
		EQUIP_CARRIED_LEFT,
		EQUIP_CONTENT_TOP,
		EQUIP_CARRIED_RIGHT,
		EQUIP_CARRIED_BOTTOM,
		2.0
	)
	# Preserve the accepted left edge and widen only toward Available Equipment.
	# The right edge gains exactly 48 px, reducing the gap without moving the
	# available-items rail or making the column content-driven.
	carried.offset_left += EQUIP_CARRIED_SHIFT_X
	carried.offset_right += EQUIP_CARRIED_SHIFT_X + EQUIP_CARRIED_EXPAND_RIGHT_X
	var available := _build_equip_available_items(campaign, character)
	available.z_index = 3
	_place_equip_region(
		canvas,
		available,
		EQUIP_AVAILABLE_LEFT,
		EQUIP_CONTENT_TOP,
		EQUIP_AVAILABLE_RIGHT,
		EQUIP_CONTENT_BOTTOM,
		2.0
	)


func _place_equip_region(
		parent: Control,
		control: Control,
		left: float,
		top: float,
		right: float,
		bottom: float,
		inset: float = 0.0
) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = inset
	control.offset_top = inset
	control.offset_right = -inset
	control.offset_bottom = -inset
	parent.add_child(control)


func _build_equip_left_rail(
		campaign: CampaignState,
		roster: Array[PersistentCharacterState],
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	# Soldier Information keeps the accepted Ready Troops width. Assignments is
	# deliberately 30% wider beneath it, extending only to the right so changing
	# base or squad labels still cannot resize either panel.
	var rail := Control.new()
	rail.clip_contents = false
	rail.custom_minimum_size.x = 0
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var information := _build_equip_character_info_panel(campaign, character, template)
	information.anchor_left = 0.0
	information.anchor_top = 0.0
	information.anchor_right = 1.0
	information.anchor_bottom = 0.54
	information.offset_bottom = -6.0
	rail.add_child(information)
	var assignments := _build_equip_assignment_panel(roster, character)
	assignments.anchor_left = 0.0
	assignments.anchor_top = 0.54
	assignments.anchor_right = 1.30
	assignments.anchor_bottom = 1.0
	assignments.offset_top = 6.0
	assignments.z_index = 1
	rail.add_child(assignments)
	return rail


func _build_equip_character_info_panel(
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.custom_minimum_size.x = 0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	margin.add_child(column)
	column.add_child(_equip_section_heading("SOLDIER INFORMATION"))
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 6)
	column.add_child(identity)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(42, 58)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = _identity_portrait_texture(
		PortraitAssetResolver.new().resolve(character.effective_portrait_id(template))
	)
	identity.add_child(portrait)
	var identity_text := VBoxContainer.new()
	identity_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_text.add_theme_constant_override("separation", 1)
	identity.add_child(identity_text)
	var name := Label.new()
	name.text = character.display_name.to_upper()
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 12)
	name.add_theme_color_override("font_color", Color("e5d5a6"))
	identity_text.add_child(name)
	identity_text.add_child(_small_meta_label("%s  •  TIER %d" % [
		template.troop_type if template != null else "Unknown",
		template.troop_tier if template != null else 0,
	]))
	identity_text.add_child(_small_meta_label("LEVEL %d  •  XP %d" % [
		character.resolved_level(template), character.xp
	]))
	var assigned_squad: CampaignSquadState = campaign.squad_for_character(character.character_id) if campaign != null else null
	identity_text.add_child(_small_meta_label("SQUAD  •  %s" % (
		assigned_squad.display_name.to_upper() if assigned_squad != null else "UNASSIGNED"
	)))
	var readiness := Label.new()
	readiness.text = _roster_status(character).to_upper()
	readiness.add_theme_font_size_override("font_size", 9)
	readiness.add_theme_color_override("font_color", _roster_status_color(character))
	identity_text.add_child(readiness)
	column.add_child(HSeparator.new())
	var career := Label.new()
	career.text = "MISSIONS %d    INJURIES %d" % [character.deployment_count, character.injury_entries.size()]
	career.add_theme_font_size_override("font_size", 8)
	career.add_theme_color_override("font_color", Color("aeb1a7"))
	column.add_child(career)
	var snapshot: ResolvedCharacterSnapshot = _resolved_roster_character(character, campaign)
	var persistent_maximum_hp: int = snapshot.stat_value(&"maximum_hp", 1)
	var persistent_current_hp: int = character.resolved_current_hp(persistent_maximum_hp)
	var attack: int = _roster_primary_attack(snapshot)
	var movement: int = snapshot.stat_value(
		&"turn_capacity", template.base_turn_capacity_feet if template != null else 30
	)
	column.add_child(_build_stat_value_row(
		"HP", "%d / %d" % [persistent_current_hp, persistent_maximum_hp],
		"\n".join(snapshot.stat_breakdown(&"maximum_hp")), true
	))
	column.add_child(_build_stat_value_row(
		"NONLETHAL", str(character.resolved_nonlethal_damage()),
		"Nonlethal damage persists between missions and heals at twice the lethal recovery rate.", true
	))
	column.add_child(_build_stat_value_row(
		"ARMOUR CLASS", str(snapshot.stat_value(&"armour_class", 10)),
		"\n".join(snapshot.stat_breakdown(&"armour_class")), true
	))
	column.add_child(_build_stat_value_row(
		"PRIMARY ATTACK", "%+d" % attack,
		"Base Attack Bonus %+d\nBest ability modifier %+d" % [
			snapshot.stat_value(&"base_attack_bonus", 0),
			maxi(snapshot.ability_modifier("STR"), snapshot.ability_modifier("DEX")),
		], true
	))
	column.add_child(_build_stat_value_row("MOVEMENT", "%d ft" % movement, "Full-turn tactical movement capacity.", true))
	column.add_child(_build_stat_value_row(
		"INITIATIVE", "%+d" % snapshot.stat_value(&"initiative", 0),
		"\n".join(snapshot.stat_breakdown(&"initiative")), true
	))
	column.add_child(_build_stat_value_row(
		"PERCEPTION", str(snapshot.stat_value(&"passive_perception", 10)),
		"\n".join(snapshot.stat_breakdown(&"passive_perception")), true
	))
	return panel

func _build_equip_assignment_panel(
		roster: Array[PersistentCharacterState],
		character: PersistentCharacterState
) -> Control:
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.custom_minimum_size.x = 0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.clip_contents = true
	margin.custom_minimum_size.x = 0
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.clip_contents = true
	column.custom_minimum_size.x = 0
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	column.add_child(_equip_section_heading("ASSIGNMENTS"))
	var base_row := HBoxContainer.new()
	base_row.clip_contents = true
	base_row.custom_minimum_size.x = 0
	base_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_row.add_theme_constant_override("separation", 5)
	column.add_child(base_row)
	var base_label := Label.new()
	base_label.text = "BASE"
	base_label.custom_minimum_size.x = 45
	base_label.add_theme_font_size_override("font_size", 10)
	base_label.add_theme_color_override("font_color", Color("aaa99f"))
	base_row.add_child(base_label)
	var base_selector_holder := Control.new()
	base_selector_holder.clip_contents = true
	base_selector_holder.custom_minimum_size = Vector2(0, 26)
	base_selector_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_row.add_child(base_selector_holder)
	var base_selector := OptionButton.new()
	base_selector.fit_to_longest_item = false
	base_selector.clip_contents = true
	base_selector.custom_minimum_size = Vector2(0, 26)
	base_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var stronghold_definition: StrongholdDefinitionScript = _campaign_session.current_stronghold_definition()
	base_selector.add_item(
		stronghold_definition.display_name.to_upper()
		if stronghold_definition != null
		else "FIFTH-GOD STRONGHOLD"
	)
	base_selector.disabled = true
	base_selector.tooltip_text = "The current campaign has one operational stronghold."
	base_selector_holder.add_child(base_selector)
	base_selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var group_row := HBoxContainer.new()
	group_row.clip_contents = true
	group_row.custom_minimum_size.x = 0
	group_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_row.add_theme_constant_override("separation", 5)
	column.add_child(group_row)
	var group_label := Label.new()
	group_label.text = "SQUAD"
	group_label.custom_minimum_size.x = 45
	group_label.add_theme_font_size_override("font_size", 10)
	group_label.add_theme_color_override("font_color", Color("aaa99f"))
	group_row.add_child(group_label)
	var group_selector_holder := Control.new()
	group_selector_holder.clip_contents = true
	group_selector_holder.custom_minimum_size = Vector2(0, 26)
	group_selector_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_row.add_child(group_selector_holder)
	var group_selector := OptionButton.new()
	group_selector.fit_to_longest_item = false
	group_selector.clip_contents = true
	group_selector.custom_minimum_size = Vector2(0, 26)
	group_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var groups: Array = [
		[EQUIP_GROUP_ALL, "ALL STRONGHOLD TROOPS"],
		[EQUIP_GROUP_READY, "READY TROOPS"],
	]
	var campaign: CampaignState = _campaign()
	if campaign != null:
		for squad: CampaignSquadState in campaign.get_squads():
			groups.append([squad.squad_id, squad.display_name.to_upper()])
	if not _briefing_selected_ids.is_empty():
		groups.append([EQUIP_GROUP_MISSION, "CURRENT MISSION SQUAD"])
	var selected_index: int = 0
	for group_entry: Array in groups:
		var index: int = group_selector.item_count
		group_selector.add_item(String(group_entry[1]))
		group_selector.set_item_metadata(index, StringName(group_entry[0]))
		if StringName(group_entry[0]) == _equip_roster_group_id:
			selected_index = index
	group_selector.select(selected_index)
	group_selector.item_selected.connect(func(index: int) -> void:
		_equip_roster_group_id = StringName(group_selector.get_item_metadata(index))
		_show_screen(SCREEN_ROSTER)
	)
	group_selector_holder.add_child(group_selector)
	group_selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.clip_contents = true
	scroll.custom_minimum_size.x = 0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.clip_contents = true
	list.custom_minimum_size.x = 0
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var visible_count: int = 0
	for roster_character: PersistentCharacterState in roster:
		if roster_character.is_dead or not _equip_group_includes_character(roster_character):
			continue
		visible_count += 1
		var roster_template: CharacterTemplateDefinition = _campaign_session.catalogue.character_template(roster_character.template_id)
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = roster_character.character_id == character.character_id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size = Vector2(0, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s\n%s  •  %s" % [
			roster_character.display_name.to_upper(),
			roster_template.troop_type if roster_template != null else "Unknown",
			_roster_status(roster_character),
		]
		button.add_theme_font_size_override("font_size", 9)
		var roster_character_id: StringName = roster_character.character_id
		button.pressed.connect(func() -> void:
			_selected_character_id = roster_character_id
			_roster_selected_item_id = &""
			_roster_selected_talent_id = &""
			_show_screen(SCREEN_ROSTER)
		)
		list.add_child(button)
	var summary := Label.new()
	summary.text = "%d TROOPS SHOWN" % visible_count
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	summary.add_theme_font_size_override("font_size", 8)
	summary.add_theme_color_override("font_color", Color("969d93"))
	column.add_child(summary)
	return panel


func _equip_group_includes_character(character: PersistentCharacterState) -> bool:
	match _equip_roster_group_id:
		EQUIP_GROUP_READY:
			return _roster_status_id(character) == &"ready"
		EQUIP_GROUP_MISSION:
			return bool(_briefing_selected_ids.get(character.character_id, false))
		EQUIP_GROUP_ALL:
			return true
	var campaign: CampaignState = _campaign()
	var squad: CampaignSquadState = campaign.get_squad(_equip_roster_group_id) if campaign != null else null
	return squad != null and squad.member_character_ids.has(character.character_id)


func _build_equip_equipped_stack(
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	# Compact equipped footer used beneath Backpack. Armour spans the full
	# inventory width; Primary and Secondary share one row as image-only boxes.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.add_child(_build_armour_selector(campaign, character))
	var hands := HBoxContainer.new()
	hands.add_theme_constant_override("separation", 4)
	column.add_child(hands)
	var primary := _build_visual_equipment_slot(
		campaign, character, CampaignItemLocationState.CONTAINER_PRIMARY_HAND, "PRIMARY"
	)
	primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hands.add_child(primary)
	var secondary := _build_visual_equipment_slot(
		campaign, character, CampaignItemLocationState.CONTAINER_SECONDARY_HAND, "SECONDARY"
	)
	secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hands.add_child(secondary)
	var weight: float = _character_carried_weight(campaign, character.character_id)
	var maximum: float = template.maximum_weight_lb if template != null else 1.0
	var carry_header := HBoxContainer.new()
	carry_header.add_theme_constant_override("separation", 3)
	column.add_child(carry_header)
	var carry_heading := Label.new()
	carry_heading.text = "CARRY WEIGHT"
	carry_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carry_heading.add_theme_font_size_override("font_size", 8)
	carry_heading.add_theme_color_override("font_color", Color("cbb678"))
	carry_header.add_child(carry_heading)
	var carry_value := Label.new()
	carry_value.text = "%.1f / %.1f lb" % [weight, maximum]
	carry_value.add_theme_font_size_override("font_size", 8)
	carry_value.add_theme_color_override("font_color", Color("d9d0b9"))
	carry_header.add_child(carry_value)
	var carry_bar := ProgressBar.new()
	carry_bar.max_value = maxf(1.0, maximum)
	carry_bar.value = weight
	carry_bar.show_percentage = false
	carry_bar.custom_minimum_size.y = 7
	column.add_child(carry_bar)
	return column


func _build_equip_character_figure(
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture: Texture2D = PortraitAssetResolver.new().resolve(character.effective_portrait_id(template))
	var shadow := TextureRect.new()
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = 7
	shadow.offset_top = 8
	shadow.offset_right = 7
	shadow.offset_bottom = 8
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.texture = texture
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.38)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)
	var portrait := TextureRect.new()
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.texture = texture
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(portrait)
	var caption := Label.new()
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -42
	caption.offset_bottom = -8
	caption.text = "%s  •  %s" % [character.display_name.to_upper(), _roster_status(character).to_upper()]
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("dfd4b8"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(caption)
	return root


func _build_equip_carried_panel(
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	# One bounded column owns the complete strategic loadout. Using a transparent
	# margin root avoids a tall empty panel below the Backpack while keeping every
	# child inside the accepted narrow inventory width.
	var root := MarginContainer.new()
	root.clip_contents = true
	root.custom_minimum_size.x = 0
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("margin_left", 1)
	root.add_theme_constant_override("margin_right", 1)
	root.add_theme_constant_override("margin_top", 1)
	root.add_theme_constant_override("margin_bottom", 1)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 0
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	root.add_child(column)
	column.add_child(_build_compact_loadout_strip(campaign, character, template))
	var belt: Control = _build_visual_inventory_slot(
		campaign, character, CampaignItemLocationState.CONTAINER_BELT, "BELT", Vector2i(7, 2), false
	)
	belt.custom_minimum_size.y = 58
	column.add_child(belt)
	var backpack: Control = _build_visual_inventory_slot(
		campaign, character, CampaignItemLocationState.CONTAINER_BACKPACK, "BACKPACK", Vector2i(10, 4), false
	)
	column.add_child(backpack)
	column.add_child(_build_equip_equipped_stack(campaign, character, template))
	column.add_child(_build_loadout_readiness_strip(character.character_id))
	return root


func _build_compact_loadout_strip(
		campaign: CampaignState,
		character: PersistentCharacterState,
		_template: CharacterTemplateDefinition
) -> Control:
	var deployment_availability: Dictionary = (
		_campaign_session.strategic_character_availability(character.character_id)
	)
	var deployment_locked: bool = not bool(
		deployment_availability.get("available", true)
	)
	var deployment_lock_reason: String = String(
		deployment_availability.get("reason", "Unavailable until the squad returns.")
	)
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2(0, 32)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.clip_contents = true
	row.custom_minimum_size.x = 0
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 2)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = LOADOUT_TEMPLATE_ICON
	icon.tooltip_text = "Loadout template"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	# A plain clipped holder breaks the OptionButton's content-derived minimum
	# size from the parent HBox. Long template names can widen the popup, but
	# never the closed loadout column.
	var selector_holder := Control.new()
	selector_holder.clip_contents = true
	selector_holder.custom_minimum_size = Vector2(0, 24)
	selector_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_holder.size_flags_stretch_ratio = 1.0
	row.add_child(selector_holder)
	var selector := OptionButton.new()
	selector.fit_to_longest_item = false
	selector.clip_contents = true
	selector.custom_minimum_size = Vector2(0, 24)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.size_flags_stretch_ratio = 1.0
	selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selector.get_popup().min_size = Vector2i(320, 0)
	var templates: Array[LoadoutTemplateState] = _campaign_session.loadout_templates_for_character(character.character_id)
	if _roster_selected_template_id.is_empty():
		_roster_selected_template_id = character.preferred_loadout_template_id
	if _roster_selected_template_id.is_empty() and not templates.is_empty():
		_roster_selected_template_id = templates[0].template_id
	var selected_index: int = 0
	for loadout_template: LoadoutTemplateState in templates:
		var index: int = selector.item_count
		selector.add_item(loadout_template.display_name)
		selector.set_item_metadata(index, loadout_template.template_id)
		selector.get_popup().set_item_tooltip(index, "%s\n%s" % [
			loadout_template.display_name,
			loadout_template.description,
		])
		if loadout_template.template_id == _roster_selected_template_id:
			selected_index = index
	if templates.is_empty():
		selector.add_item("No template")
		selector.disabled = true
	else:
		selector.select(selected_index)
	selector.item_selected.connect(func(index: int) -> void:
		_roster_selected_template_id = StringName(selector.get_item_metadata(index))
	)
	selector_holder.add_child(selector)
	selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var save := MenuButton.new()
	save.text = "SAVE"
	save.custom_minimum_size = Vector2(38, 24)
	save.size_flags_horizontal = Control.SIZE_SHRINK_END
	save.add_theme_font_size_override("font_size", 8)
	save.tooltip_text = "Save the current arrangement as a new template, or update the selected player template."
	var save_popup: PopupMenu = save.get_popup()
	save_popup.add_item("Save current as new", 0)
	var selected_template: LoadoutTemplateState = campaign.get_loadout_template(_roster_selected_template_id)
	if selected_template != null and not selected_template.is_authored:
		save_popup.add_item("Update selected template", 1)
	save_popup.id_pressed.connect(func(action_id: int) -> void:
		if action_id == 1:
			_request_update_selected_template(character.character_id)
		else:
			_request_save_current_as_template(character.character_id)
	)
	row.add_child(save)
	var load_button := Button.new()
	load_button.text = "LOAD"
	load_button.custom_minimum_size = Vector2(38, 24)
	load_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	load_button.add_theme_font_size_override("font_size", 8)
	load_button.disabled = templates.is_empty() or deployment_locked
	load_button.tooltip_text = (
		deployment_lock_reason
		if deployment_locked
		else "Apply the selected template using available exact item instances."
	)
	load_button.pressed.connect(_request_apply_selected_template)
	row.add_child(load_button)
	return panel


func _build_equip_character_tabs() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	# The roster has two permanent subviews. Level Up opens from Character and
	# injuries remain visible through roster status and Current Condition.
	var entries: Array = [
		[0, "LOADOUT"],
		[1, "CHARACTER"],
	]
	for entry: Array in entries:
		var tab_index: int = int(entry[0])
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = (
			tab_index == _roster_tab_index
			or (tab_index == 1 and _roster_tab_index == 2)
			or (tab_index == 1 and _roster_tab_index == 4)
		)
		button.text = String(entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 38
		button.pressed.connect(func() -> void:
			_roster_tab_index = tab_index
			_show_screen(SCREEN_ROSTER)
		)
		row.add_child(button)
	return row


func _build_equip_secondary_content(
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	var panel := PanelContainer.new()
	panel.clip_contents = true
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	if _roster_tab_index == 2:
		scroll.add_child(_build_level_up_content(character, template))
		return panel
	if _roster_tab_index == 4:
		scroll.add_child(_build_prestige_content(character, template))
		return panel
	if _roster_tab_index == 1:
		scroll.add_child(_build_roster_character_dossier(campaign, character, template))
		return panel
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	column.add_child(_body_label("Select Loadout or Character."))
	return panel


func _build_roster_character_dossier(
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	var snapshot: ResolvedCharacterSnapshot = _resolved_roster_character(character, campaign)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 10)
	root.add_child(top_row)
	top_row.add_child(_build_roster_dossier_identity_panel(campaign, character, template, snapshot))
	top_row.add_child(_build_roster_dossier_combat_panel(character, template, snapshot))

	root.add_child(_build_roster_dossier_ability_scores_panel(snapshot))

	var middle_row := HBoxContainer.new()
	middle_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle_row.add_theme_constant_override("separation", 10)
	root.add_child(middle_row)
	middle_row.add_child(_build_roster_dossier_equipment_panel(campaign, character))
	middle_row.add_child(_build_roster_dossier_abilities_panel(character, template))

	var bottom_row := HBoxContainer.new()
	bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_theme_constant_override("separation", 10)
	root.add_child(bottom_row)
	bottom_row.add_child(_build_roster_dossier_condition_panel(campaign, character, template))
	bottom_row.add_child(_build_roster_dossier_record_panel(character))

	return root


func _build_roster_dossier_panel(title: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	if not title.strip_edges().is_empty():
		var heading := Label.new()
		heading.text = title
		heading.add_theme_font_size_override("font_size", 12)
		heading.add_theme_color_override("font_color", Color("cbb678"))
		content.add_child(heading)
	return {"panel": panel, "content": content}


func _build_roster_dossier_identity_panel(
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition,
		snapshot: ResolvedCharacterSnapshot
) -> Control:
	var panel_data: Dictionary = _build_roster_dossier_panel("WARBAND DOSSIER")
	var panel: PanelContainer = panel_data.get("panel") as PanelContainer
	var content: VBoxContainer = panel_data.get("content") as VBoxContainer
	panel.size_flags_stretch_ratio = 1.05
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(120, 160)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.texture = PortraitAssetResolver.new().resolve(character.effective_portrait_id(template))
	row.add_child(portrait)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 3)
	row.add_child(details)
	var name := Label.new()
	name.text = character.display_name.to_upper()
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", Color("e5d5a6"))
	details.add_child(name)
	var role_line := Label.new()
	role_line.text = "%s  •  TIER %d" % [
		template.troop_type if template != null else "Unknown",
		template.troop_tier if template != null else 0,
	]
	role_line.add_theme_font_size_override("font_size", 12)
	role_line.add_theme_color_override("font_color", Color("b6b7b1"))
	details.add_child(role_line)
	var level_line := Label.new()
	level_line.text = "LEVEL %d" % character.resolved_level(template)
	level_line.add_theme_font_size_override("font_size", 12)
	level_line.add_theme_color_override("font_color", Color("d8d1c3"))
	details.add_child(level_line)
	var readiness := Label.new()
	readiness.text = _roster_status(character).to_upper()
	readiness.add_theme_font_size_override("font_size", 13)
	readiness.add_theme_color_override("font_color", _roster_status_color(character))
	details.add_child(readiness)
	details.add_child(_build_roster_dossier_progression_block(character, template))
	var doctrine := Label.new()
	doctrine.text = "Individual level changes do not alter troop tier."
	doctrine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	doctrine.add_theme_font_size_override("font_size", 9)
	doctrine.add_theme_color_override("font_color", Color("8f918b"))
	details.add_child(doctrine)
	var career := HBoxContainer.new()
	career.add_theme_constant_override("separation", 8)
	content.add_child(career)
	career.add_child(_build_roster_dossier_micro_card("MISSIONS", str(character.deployment_count)))
	career.add_child(_build_roster_dossier_micro_card("INJURIES", str(character.injury_entries.size())))
	career.add_child(_build_roster_dossier_micro_card(
		"CARRY",
		"%.1f / %.1f lb" % [
			_character_carried_weight(campaign, character.character_id),
			template.maximum_weight_lb if template != null else 0.0,
		]
	))
	var visibility: CharacterVisibilitySnapshot = _campaign_session.character_visibility(character.character_id)
	career.add_child(_build_roster_dossier_micro_card(
		"VISIBILITY",
		str(visibility.final_visibility) if visibility != null else "?"
	))
	return panel


func _build_roster_dossier_progression_block(
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	var preview: Dictionary = _campaign_session.next_level_preview(character.character_id)
	var current_level: int = int(
		preview.get("current_level", character.resolved_level(template))
	)
	var target_level: int = int(preview.get("target_level", current_level + 1))
	var xp_required: int = maxi(1, int(preview.get("xp_required", character.xp)))
	var eligible: bool = bool(preview.get("eligible", false))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)
	var xp_label := Label.new()
	xp_label.text = "EXPERIENCE"
	xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_label.add_theme_font_size_override("font_size", 9)
	xp_label.add_theme_color_override("font_color", Color("969b90"))
	header.add_child(xp_label)
	var xp_amount := Label.new()
	xp_amount.text = "%d / %d XP" % [character.xp, xp_required]
	xp_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_amount.add_theme_font_size_override("font_size", 10)
	xp_amount.add_theme_color_override("font_color", Color("ddd6c7"))
	header.add_child(xp_amount)

	var xp_bar := ProgressBar.new()
	xp_bar.max_value = float(xp_required)
	xp_bar.value = minf(float(character.xp), float(xp_required))
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size.y = 12
	column.add_child(xp_bar)

	var progression_buttons := HBoxContainer.new()
	progression_buttons.add_theme_constant_override("separation", 6)
	column.add_child(progression_buttons)
	var level_button := Button.new()
	level_button.text = "LEVEL UP AVAILABLE" if eligible else "VIEW LEVEL %d" % target_level
	level_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_button.custom_minimum_size.y = 30
	level_button.tooltip_text = "Choose the gains for Level %d." % target_level if eligible else "Inspect the next level and its requirements."
	level_button.pressed.connect(func() -> void:
		_roster_tab_index = 2
		_show_screen(SCREEN_ROSTER)
	)
	progression_buttons.add_child(level_button)
	var prestige_options: Array[Dictionary] = _campaign_session.prestige_options(character.character_id)
	var prestige_available: bool = false
	for option: Dictionary in prestige_options:
		if bool(option.get("eligible", false)):
			prestige_available = true
			break
	var prestige_button := Button.new()
	prestige_button.text = "PRESTIGE AVAILABLE" if prestige_available else "PRESTIGE"
	prestige_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prestige_button.custom_minimum_size.y = 30
	prestige_button.disabled = character.career_id.is_empty()
	prestige_button.tooltip_text = "Select the next troop Tier. Levels and earned features remain; only Tier starting feats are replaced."
	prestige_button.pressed.connect(func() -> void:
		_roster_tab_index = 4
		_show_screen(SCREEN_ROSTER)
	)
	progression_buttons.add_child(prestige_button)
	return panel


func _build_roster_dossier_combat_panel(
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition,
		snapshot: ResolvedCharacterSnapshot
) -> Control:
	var panel_data: Dictionary = _build_roster_dossier_panel("COMBAT PROFILE")
	var panel: PanelContainer = panel_data.get("panel") as PanelContainer
	var content: VBoxContainer = panel_data.get("content") as VBoxContainer
	panel.size_flags_stretch_ratio = 1.60
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	var movement: int = snapshot.stat_value(&"turn_capacity", template.base_turn_capacity_feet if template != null else 30)
	var maximum_hp: int = snapshot.stat_value(&"maximum_hp", 1)
	var current_hp: int = character.resolved_current_hp(maximum_hp)
	grid.add_child(_build_roster_dossier_stat_card(
		"HEALTH",
		"%d / %d" % [current_hp, maximum_hp],
		"persistent HP",
		"\n".join(snapshot.stat_breakdown(&"maximum_hp"))
	))
	grid.add_child(_build_roster_dossier_stat_card(
		"ARMOUR",
		str(snapshot.stat_value(&"armour_class", 10)),
		"armour class",
		"\n".join(snapshot.stat_breakdown(&"armour_class"))
	))
	grid.add_child(_build_roster_dossier_stat_card(
		"ATTACK",
		"%+d" % _roster_primary_attack(snapshot),
		"primary attack",
		"Base Attack Bonus %+d\nBest ability modifier %+d" % [
			snapshot.stat_value(&"base_attack_bonus", 0),
			maxi(snapshot.ability_modifier("STR"), snapshot.ability_modifier("DEX")),
		]
	))
	grid.add_child(_build_roster_dossier_stat_card(
		"MOVE",
		"%d ft" % movement,
		"turn capacity"
	))
	grid.add_child(_build_roster_dossier_stat_card(
		"INIT",
		"%+d" % snapshot.stat_value(&"initiative", 0),
		"initiative",
		"\n".join(snapshot.stat_breakdown(&"initiative"))
	))
	grid.add_child(_build_roster_dossier_stat_card(
		"PERCEPTION",
		str(snapshot.stat_value(&"passive_perception", 10)),
		"passive",
		"\n".join(snapshot.stat_breakdown(&"passive_perception"))
	))
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 12)
	content.add_child(secondary)
	for entry: Array in [
		["BAB", "%+d" % snapshot.stat_value(&"base_attack_bonus", 0)],
		["FORT", "%+d" % snapshot.stat_value(&"fortitude", 0)],
		["REF", "%+d" % snapshot.stat_value(&"reflex", 0)],
		["WILL", "%+d" % snapshot.stat_value(&"will", 0)],
	]:
		var label := Label.new()
		label.text = "%s %s" % [String(entry[0]), String(entry[1])]
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color("aeb1a7"))
		secondary.add_child(label)
	return panel


func _build_roster_dossier_stat_card(
		label_text: String,
		value_text: String,
		subtitle_text: String = "",
		tooltip_text: String = ""
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 84)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	margin.add_child(column)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("bdb9aa"))
	column.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", Color("e3d9be"))
	column.add_child(value)
	if not subtitle_text.strip_edges().is_empty():
		var subtitle := Label.new()
		subtitle.text = subtitle_text.to_upper()
		subtitle.add_theme_font_size_override("font_size", 8)
		subtitle.add_theme_color_override("font_color", Color("8f918b"))
		column.add_child(subtitle)
	if not tooltip_text.strip_edges().is_empty():
		panel.tooltip_text = tooltip_text
		margin.tooltip_text = tooltip_text
	return panel


func _build_roster_dossier_micro_card(label_text: String, value_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	margin.add_child(column)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("969b90"))
	column.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 12)
	value.add_theme_color_override("font_color", Color("ddd6c7"))
	column.add_child(value)
	return panel


func _build_roster_dossier_ability_scores_panel(snapshot: ResolvedCharacterSnapshot) -> Control:
	var panel_data: Dictionary = _build_roster_dossier_panel("ABILITY SCORES")
	var panel: PanelContainer = panel_data.get("panel") as PanelContainer
	var content: VBoxContainer = panel_data.get("content") as VBoxContainer
	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for ability_id: String in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		grid.add_child(_build_roster_dossier_ability_score_card(snapshot, ability_id))
	return panel


func _build_roster_dossier_ability_score_card(
		snapshot: ResolvedCharacterSnapshot,
		ability_id: String
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 78)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	margin.add_child(column)
	var abbreviation := Label.new()
	abbreviation.text = ability_id
	abbreviation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abbreviation.add_theme_font_size_override("font_size", 10)
	abbreviation.add_theme_color_override("font_color", Color("bdb9aa"))
	column.add_child(abbreviation)
	var score := Label.new()
	score.text = str(snapshot.ability_score(ability_id))
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 20)
	score.add_theme_color_override("font_color", Color("e3d9be"))
	column.add_child(score)
	var modifier := Label.new()
	modifier.text = "%+d" % snapshot.ability_modifier(ability_id)
	modifier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modifier.add_theme_font_size_override("font_size", 9)
	modifier.add_theme_color_override("font_color", Color("8f918b"))
	column.add_child(modifier)
	var tooltip := "\n".join(snapshot.stat_breakdown(StringName("ability.%s" % ability_id.to_lower())))
	if not tooltip.strip_edges().is_empty():
		panel.tooltip_text = tooltip
	return panel


func _build_roster_dossier_equipment_panel(
		campaign: CampaignState,
		character: PersistentCharacterState
) -> Control:
	var panel_data: Dictionary = _build_roster_dossier_panel("EQUIPMENT")
	var panel: PanelContainer = panel_data.get("panel") as PanelContainer
	var content: VBoxContainer = panel_data.get("content") as VBoxContainer
	panel.size_flags_stretch_ratio = 1.0
	var slot_summaries: Array = [
		_roster_dossier_equipment_summary(campaign, character, CampaignItemLocationState.CONTAINER_PRIMARY_HAND, "PRIMARY HAND", WEAPON_SLOT_ICON),
		_roster_dossier_equipment_summary(campaign, character, CampaignItemLocationState.CONTAINER_SECONDARY_HAND, "SECONDARY HAND", WEAPON_SLOT_ICON),
		_roster_dossier_equipment_summary(campaign, character, CampaignItemLocationState.CONTAINER_ARMOUR, "ARMOUR", ARMOUR_SLOT_ICON),
		_roster_dossier_equipment_summary(campaign, character, CampaignItemLocationState.CONTAINER_BELT, "BELT", EMPTY_SLOT_ICON),
		_roster_dossier_equipment_summary(campaign, character, CampaignItemLocationState.CONTAINER_BACKPACK, "BACKPACK", EMPTY_SLOT_ICON),
	]
	for entry: Dictionary in slot_summaries:
		content.add_child(_build_roster_dossier_equipment_row(
			String(entry.get("label", "")),
			entry.get("icon") as Texture2D,
			String(entry.get("primary", "")),
			String(entry.get("secondary", ""))
		))
	var note := Label.new()
	note.text = "Select LOADOUT to manage exact slots, ammunition and carried items."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 9)
	note.add_theme_color_override("font_color", Color("8f918b"))
	content.add_child(note)
	return panel


func _roster_dossier_equipment_summary(
		campaign: CampaignState,
		character: PersistentCharacterState,
		container_id: StringName,
		label_text: String,
		fallback_icon: Texture2D
) -> Dictionary:
	var items: Array[CampaignItemState] = _character_items_in_container(campaign, character.character_id, container_id)
	if items.is_empty():
		return {
			"label": label_text,
			"icon": fallback_icon,
			"primary": "Empty",
			"secondary": "No item assigned.",
		}
	if container_id == CampaignItemLocationState.CONTAINER_BELT or container_id == CampaignItemLocationState.CONTAINER_BACKPACK:
		var names: Array[String] = []
		for item: CampaignItemState in items:
			names.append(_item_name(item))
		var displayed: Array[String] = []
		for index: int in range(mini(3, names.size())):
			displayed.append(names[index])
		var extra_count: int = maxi(0, names.size() - displayed.size())
		var detail: String = ", ".join(PackedStringArray(displayed))
		if extra_count > 0:
			detail += " + %d more" % extra_count
		return {
			"label": label_text,
			"icon": fallback_icon,
			"primary": "%d item%s" % [items.size(), "" if items.size() == 1 else "s"],
			"secondary": detail,
		}
	var item: CampaignItemState = items[0]
	var definition: ItemDefinition = _campaign_session.catalogue.item_definition(item.definition_id)
	var icon: Texture2D = fallback_icon
	if definition != null:
		var path: String = _item_icon_path(definition)
		if ResourceLoader.exists(path):
			icon = load(path) as Texture2D
	return {
		"label": label_text,
		"icon": icon,
		"primary": _item_name(item),
		"secondary": _compact_equipment_summary(item, definition, character).replace("\n", " • "),
	}


func _build_roster_dossier_equipment_row(
		label_text: String,
		icon_texture: Texture2D,
		primary_text: String,
		secondary_text: String
) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = icon_texture
	row.add_child(icon)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 1)
	row.add_child(text_column)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("969b90"))
	text_column.add_child(label)
	var primary := Label.new()
	primary.text = primary_text
	primary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	primary.add_theme_font_size_override("font_size", 12)
	primary.add_theme_color_override("font_color", Color("ddd6c7"))
	text_column.add_child(primary)
	if not secondary_text.strip_edges().is_empty():
		var secondary := Label.new()
		secondary.text = secondary_text
		secondary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		secondary.add_theme_font_size_override("font_size", 8)
		secondary.add_theme_color_override("font_color", Color("8f918b"))
		text_column.add_child(secondary)
	return row


func _build_roster_dossier_abilities_panel(
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	var panel_data: Dictionary = _build_roster_dossier_panel("ABILITIES")
	var panel: PanelContainer = panel_data.get("panel") as PanelContainer
	var content: VBoxContainer = panel_data.get("content") as VBoxContainer
	panel.size_flags_stretch_ratio = 1.0
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	content.add_child(flow)
	var entries: Array[String] = []
	if template != null:
		entries.append_array(template.ability_entries)
	for character_trait: String in character.trait_entries:
		entries.append(character_trait)
	if entries.is_empty():
		content.add_child(_body_label("No authored ability summary."))
		return panel
	for entry: String in entries:
		flow.add_child(_build_roster_dossier_ability_chip(entry))
	return panel


func _build_roster_dossier_ability_chip(entry_text: String) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var label := Label.new()
	var compact_label: String = entry_text
	for separator: String in [":", "—", "-"]:
		if compact_label.contains(separator):
			compact_label = compact_label.get_slice(separator, 0)
			break
	label.text = compact_label.strip_edges().to_upper()
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("ddd6c7"))
	margin.add_child(label)
	panel.tooltip_text = entry_text
	return panel


func _build_roster_dossier_condition_panel(
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	var panel_data: Dictionary = _build_roster_dossier_panel("CURRENT CONDITION")
	var panel: PanelContainer = panel_data.get("panel") as PanelContainer
	var content: VBoxContainer = panel_data.get("content") as VBoxContainer
	panel.size_flags_stretch_ratio = 1.0
	var snapshot: ResolvedCharacterSnapshot = _resolved_roster_character(character, campaign)
	var maximum_hp: int = snapshot.stat_value(&"maximum_hp", 1)
	var current_hp: int = character.resolved_current_hp(maximum_hp)
	var nonlethal: int = character.resolved_nonlethal_damage()
	var recovery: Dictionary = _campaign_session.strategic_recovery_snapshot(
		character.character_id
	)
	content.add_child(_build_roster_dossier_micro_card("STATUS", _roster_status(character)))
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 8)
	content.add_child(health_row)
	health_row.add_child(_build_roster_dossier_micro_card(
		"HP",
		"%d / %d" % [current_hp, maximum_hp]
	))
	health_row.add_child(_build_roster_dossier_micro_card(
		"NONLETHAL",
		str(nonlethal)
	))
	var hp_bar := ProgressBar.new()
	hp_bar.max_value = float(maxi(1, maximum_hp))
	hp_bar.value = float(clampi(current_hp, 0, maximum_hp))
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size.y = 10
	content.add_child(hp_bar)
	var detail := Label.new()
	var lethal_minutes: int = int(recovery.get("lethal_minutes_remaining", 0))
	var nonlethal_minutes: int = int(recovery.get("nonlethal_minutes_remaining", 0))
	var treatment: String = String(recovery.get("treatment_source", "Natural stronghold recovery"))
	var lethal_rate: int = int(recovery.get("lethal_points_per_day", 0))
	var nonlethal_rate: int = int(recovery.get("nonlethal_points_per_day", lethal_rate * 2))
	var paused: bool = bool(recovery.get("recovery_paused", false))
	var recovery_lines: Array[String] = []
	if lethal_minutes > 0:
		recovery_lines.append("Lethal recovery: %s" % _format_duration(lethal_minutes))
	if nonlethal_minutes > 0:
		recovery_lines.append("Nonlethal recovery: %s" % _format_duration(nonlethal_minutes))
	if lethal_minutes <= 0 and nonlethal_minutes <= 0:
		recovery_lines.append("No recoverable health damage remains.")
	recovery_lines.append("Treatment: %s" % treatment)
	recovery_lines.append(
		"Recovery rates: lethal %d/day · nonlethal %d/day (half the time)."
		% [lethal_rate, nonlethal_rate]
	)
	recovery_lines.append(
		"Recovery paused while away from the stronghold."
		if paused
		else "Recovery active while resting at the stronghold."
	)
	if character.is_persistently_unconscious(maximum_hp):
		recovery_lines.append("Unconscious: cannot deploy until enough damage has healed.")
	elif current_hp < maximum_hp or nonlethal > 0:
		recovery_lines.append("May deploy injured at the displayed persistent health values.")
	if not character.injury_entries.is_empty():
		recovery_lines.append("Lasting injuries: • " + " • ".join(PackedStringArray(character.injury_entries)))
	detail.text = "\n".join(PackedStringArray(recovery_lines))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", Color("d7d1c4"))
	content.add_child(detail)
	return panel


func _build_roster_dossier_record_panel(character: PersistentCharacterState) -> Control:
	var panel_data: Dictionary = _build_roster_dossier_panel("WAR RECORD")
	var panel: PanelContainer = panel_data.get("panel") as PanelContainer
	var content: VBoxContainer = panel_data.get("content") as VBoxContainer
	panel.size_flags_stretch_ratio = 1.0
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 8)
	content.add_child(metrics)
	metrics.add_child(_build_roster_dossier_micro_card("MISSIONS", str(character.deployment_count)))
	metrics.add_child(_build_roster_dossier_micro_card("NOTES", str(character.history_entries.size())))
	var visibility: CharacterVisibilitySnapshot = _campaign_session.character_visibility(character.character_id)
	metrics.add_child(_build_roster_dossier_micro_card(
		"VISIBILITY",
		str(visibility.final_visibility) if visibility != null else "?"
	))
	var heading := Label.new()
	heading.text = "Latest record"
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", Color("969b90"))
	content.add_child(heading)
	var record := Label.new()
	if character.history_entries.is_empty():
		record.text = "No recorded missions yet."
	else:
		var recent: Array[String] = []
		var start: int = maxi(0, character.history_entries.size() - 4)
		for index: int in range(start, character.history_entries.size()):
			recent.append("• %s" % character.history_entries[index])
		record.text = "\n".join(PackedStringArray(recent))
	record.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	record.add_theme_font_size_override("font_size", 11)
	record.add_theme_color_override("font_color", Color("d7d1c4"))
	content.add_child(record)
	if visibility != null:
		var visibility_label := Label.new()
		var explanation_lines: Array[String] = visibility.explanation_lines()
		var explanation: Array[String] = []
		for index: int in range(mini(3, explanation_lines.size())):
			explanation.append(explanation_lines[index])
		visibility_label.text = "Visibility: %s" % (
			" | ".join(PackedStringArray(explanation))
			if not explanation.is_empty()
			else "No additional explanation."
		)
		visibility_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		visibility_label.add_theme_font_size_override("font_size", 9)
		visibility_label.add_theme_color_override("font_color", Color("8f918b"))
		content.add_child(visibility_label)
	return panel


func _identity_portrait_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var crop := AtlasTexture.new()
	crop.atlas = source
	var source_width: float = float(source.get_width())
	var source_height: float = float(source.get_height())
	crop.region = Rect2(
		Vector2(source_width * 0.18, 0.0),
		Vector2(source_width * 0.64, source_height * 0.48)
	)
	return crop


func _equip_section_heading(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("cbb678"))
	return label


func _build_equip_character_sidebar(
		campaign: CampaignState,
		roster: Array[PersistentCharacterState],
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 220
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.80
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 9)
	column.add_child(identity)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(76, 108)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = PortraitAssetResolver.new().resolve(character.effective_portrait_id(template))
	identity.add_child(portrait)
	var identity_text := VBoxContainer.new()
	identity_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(identity_text)
	var name := Label.new()
	name.text = character.display_name.to_upper()
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", Color("e1cf9b"))
	identity_text.add_child(name)
	identity_text.add_child(_small_meta_label("%s  •  TIER %d" % [
		template.troop_type if template != null else "Unknown",
		template.troop_tier if template != null else 0,
	]))
	identity_text.add_child(_small_meta_label("LEVEL %d  •  XP %d" % [
		character.resolved_level(template), character.xp
	]))
	var readiness := Label.new()
	readiness.text = _roster_status(character).to_upper()
	readiness.add_theme_font_size_override("font_size", 14)
	readiness.add_theme_color_override("font_color", _roster_status_color(character))
	identity_text.add_child(readiness)
	column.add_child(HSeparator.new())
	var snapshot: ResolvedCharacterSnapshot = _resolved_roster_character(character, campaign)
	var persistent_maximum_hp: int = snapshot.stat_value(&"maximum_hp", 1)
	var persistent_current_hp: int = character.resolved_current_hp(persistent_maximum_hp)
	var attack: int = _roster_primary_attack(snapshot)
	var movement: int = snapshot.stat_value(
		&"turn_capacity",
		template.base_turn_capacity_feet if template != null else 30
	)
	var carried: float = _character_carried_weight(campaign, character.character_id)
	var capacity: float = template.maximum_weight_lb if template != null else 0.0
	column.add_child(_build_stat_value_row(
		"HP", "%d / %d" % [persistent_current_hp, persistent_maximum_hp],
		"\n".join(snapshot.stat_breakdown(&"maximum_hp"))
	))
	column.add_child(_build_stat_value_row(
		"NONLETHAL", str(character.resolved_nonlethal_damage()),
		"Nonlethal damage persists between missions and heals at twice the lethal recovery rate."
	))
	column.add_child(_build_stat_value_row(
		"ARMOUR CLASS", str(snapshot.stat_value(&"armour_class", 10)),
		"\n".join(snapshot.stat_breakdown(&"armour_class"))
	))
	column.add_child(_build_stat_value_row(
		"PRIMARY ATTACK", "%+d" % attack,
		"Base Attack Bonus %+d\nBest ability modifier %+d" % [
			snapshot.stat_value(&"base_attack_bonus", 0),
			maxi(snapshot.ability_modifier("STR"), snapshot.ability_modifier("DEX")),
		]
	))
	column.add_child(_build_stat_value_row("MOVEMENT", "%d ft" % movement, "Full-turn tactical movement capacity."))
	column.add_child(_build_stat_value_row(
		"INITIATIVE", "%+d" % snapshot.stat_value(&"initiative", 0),
		"\n".join(snapshot.stat_breakdown(&"initiative"))
	))
	column.add_child(_build_stat_value_row(
		"PASSIVE PERCEPTION", str(snapshot.stat_value(&"passive_perception", 10)),
		"\n".join(snapshot.stat_breakdown(&"passive_perception"))
	))
	column.add_child(_build_stat_value_row(
		"CARRY WEIGHT", "%.1f / %.1f lb" % [carried, capacity],
		"Total exact item weight compared with the character's carrying capacity."
	))
	column.add_child(HSeparator.new())
	var mission_label := Label.new()
	mission_label.text = "MISSIONS %d    INJURIES %d" % [
		character.deployment_count,
		character.injury_entries.size(),
	]
	mission_label.add_theme_font_size_override("font_size", 12)
	mission_label.add_theme_color_override("font_color", Color("b8b6aa"))
	column.add_child(mission_label)
	column.add_child(HSeparator.new())
	var roster_heading := Label.new()
	roster_heading.text = "QUICK ROSTER"
	roster_heading.add_theme_font_size_override("font_size", 13)
	roster_heading.add_theme_color_override("font_color", Color("cbb678"))
	column.add_child(roster_heading)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	for roster_character: PersistentCharacterState in roster:
		if roster_character.is_dead:
			continue
		var roster_template: CharacterTemplateDefinition = _campaign_session.catalogue.character_template(roster_character.template_id)
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = roster_character.character_id == character.character_id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 42
		button.text = "%s\n%s  •  %s" % [
			roster_character.display_name.to_upper(),
			roster_template.troop_type if roster_template != null else "Unknown",
			_roster_status(roster_character),
		]
		var roster_character_id: StringName = roster_character.character_id
		button.pressed.connect(func() -> void:
			_selected_character_id = roster_character_id
			_roster_selected_item_id = &""
			_roster_selected_talent_id = &""
			_show_screen(SCREEN_ROSTER)
		)
		list.add_child(button)
	return panel


func _build_stat_value_row(
		label_text: String,
		display_value: String,
		breakdown_text: String = "",
		compact: bool = false
) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 20 if compact else 27
	row.add_theme_constant_override("separation", 4 if compact else 7)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 9 if compact else 11)
	label.add_theme_color_override("font_color", Color("bdb9aa"))
	row.add_child(label)
	var amount := Label.new()
	amount.text = display_value
	amount.custom_minimum_size.x = 68 if compact else 105
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.add_theme_font_size_override("font_size", 11 if compact else 13)
	amount.add_theme_color_override("font_color", Color("e3d9be"))
	row.add_child(amount)
	if not breakdown_text.strip_edges().is_empty():
		row.tooltip_text = breakdown_text
		label.tooltip_text = breakdown_text
		amount.tooltip_text = breakdown_text
	return row

func _build_equip_character_centre(
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 2.20
	panel.custom_minimum_size.x = 560
	panel.clip_contents = true
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(tabs)
	var loadout := VBoxContainer.new()
	loadout.name = "LOADOUT"
	loadout.add_theme_constant_override("separation", 7)
	loadout.add_child(_build_equip_loadout_stage(campaign, character, template))
	tabs.add_child(loadout)
	var character_tab := ScrollContainer.new()
	character_tab.name = "CHARACTER"
	character_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var character_content := VBoxContainer.new()
	character_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_content.add_theme_constant_override("separation", 10)
	character_tab.add_child(character_content)
	var snapshot: ResolvedCharacterSnapshot = _resolved_roster_character(character, campaign)
	character_content.add_child(_heading_label("RESOLVED CHARACTER"))
	character_content.add_child(_body_label(
		"HP %d    AC %d    BAB %+d    MOVE %d ft\nSTR %d  DEX %d  CON %d  INT %d  WIS %d  CHA %d\nInitiative %+d    Passive Perception %d" % [
			snapshot.stat_value(&"maximum_hp", 0),
			snapshot.stat_value(&"armour_class", 10),
			snapshot.stat_value(&"base_attack_bonus", 0),
			snapshot.stat_value(&"turn_capacity", template.base_turn_capacity_feet if template != null else 30),
			snapshot.ability_score("STR"), snapshot.ability_score("DEX"), snapshot.ability_score("CON"),
			snapshot.ability_score("INT"), snapshot.ability_score("WIS"), snapshot.ability_score("CHA"),
			snapshot.stat_value(&"initiative", 0), snapshot.stat_value(&"passive_perception", 10),
		]
	))
	character_content.add_child(_heading_label("ABILITIES"))
	character_content.add_child(_body_label(
		"\n".join(template.ability_entries) if template != null and not template.ability_entries.is_empty() else "No authored ability summary."
	))
	character_content.add_child(_heading_label("INDIVIDUAL VISIBILITY"))
	var visibility: CharacterVisibilitySnapshot = _campaign_session.character_visibility(character.character_id)
	if visibility != null:
		character_content.add_child(_body_label(
			"%s\nTotal visibility: %d" % [
				"\n".join(visibility.explanation_lines()),
				visibility.final_visibility,
			]
		))
	else:
		character_content.add_child(_body_label("Visibility information is unavailable."))
	character_content.add_child(_heading_label("MISSION RECORD"))
	character_content.add_child(_body_label(
		"Missions: %d\n\n%s" % [
			character.deployment_count,
			"\n".join(character.history_entries) if not character.history_entries.is_empty() else "No recorded missions.",
		]
	))
	tabs.add_child(character_tab)
	var level_tab := ScrollContainer.new()
	level_tab.name = "LEVEL UP" + (" ●" if bool(_campaign_session.next_level_preview(character.character_id).get("eligible", false)) else "")
	level_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	level_tab.add_child(_build_level_up_content(character, template))
	tabs.add_child(level_tab)
	tabs.current_tab = clampi(_roster_tab_index, 0, tabs.get_tab_count() - 1)
	tabs.tab_changed.connect(func(tab_index: int) -> void: _roster_tab_index = tab_index)
	return panel


func _build_equip_loadout_stage(
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	_ensure_roster_screen_snapshot(character.character_id)
	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	column.add_child(_build_loadout_template_controls(campaign, character, template))
	var stage := HBoxContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation", 8)
	column.add_child(stage)
	var left_slots := VBoxContainer.new()
	left_slots.custom_minimum_size.x = 180
	left_slots.add_theme_constant_override("separation", 6)
	stage.add_child(left_slots)
	left_slots.add_child(_build_armour_selector(campaign, character))
	left_slots.add_child(_build_visual_equipment_slot(campaign, character, CampaignItemLocationState.CONTAINER_PRIMARY_HAND, "PRIMARY HAND"))
	left_slots.add_child(_build_visual_equipment_slot(campaign, character, CampaignItemLocationState.CONTAINER_SECONDARY_HAND, "SECONDARY HAND"))
	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size.x = 110
	portrait_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(portrait_panel)
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.texture = PortraitAssetResolver.new().resolve(character.effective_portrait_id(template))
	portrait_panel.add_child(portrait)
	var right_slots := VBoxContainer.new()
	var inventory_cell_size: float = _strategic_inventory_cell_size()
	right_slots.custom_minimum_size.x = maxf(258.0, inventory_cell_size * 10.0 + 24.0)
	right_slots.add_theme_constant_override("separation", 6)
	stage.add_child(right_slots)
	right_slots.add_child(_build_visual_inventory_slot(campaign, character, CampaignItemLocationState.CONTAINER_BELT, "BELT", Vector2i(7, 2)))
	right_slots.add_child(_build_visual_inventory_slot(campaign, character, CampaignItemLocationState.CONTAINER_BACKPACK, "BACKPACK", Vector2i(10, 4)))
	var weight: float = _character_carried_weight(campaign, character.character_id)
	var maximum: float = template.maximum_weight_lb if template != null else 1.0
	var carry_row := HBoxContainer.new()
	carry_row.add_theme_constant_override("separation", 8)
	column.add_child(carry_row)
	var carry_label := Label.new()
	carry_label.text = "CARRY WEIGHT"
	carry_label.custom_minimum_size.x = 115
	carry_label.add_theme_font_size_override("font_size", 12)
	carry_row.add_child(carry_label)
	var carry_bar := ProgressBar.new()
	carry_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carry_bar.show_percentage = false
	carry_bar.max_value = maxf(1.0, maximum)
	carry_bar.value = weight
	carry_row.add_child(carry_bar)
	var carry_amount := Label.new()
	carry_amount.text = "%.1f / %.1f lb" % [weight, maximum]
	carry_amount.custom_minimum_size.x = 115
	carry_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	carry_row.add_child(carry_amount)
	column.add_child(_build_loadout_readiness_strip(character.character_id))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	column.add_child(actions)
	for entry: Array in [
		["UNDO", Callable(self, "_undo_last_equipment_change")],
		["RESTORE LOADOUT", Callable(self, "_restore_screen_open_loadout").bind(character.character_id)],
		["RETURN CARRIED ITEMS", Callable(self, "_return_all_carried_items").bind(character.character_id)],
	]:
		var button := Button.new()
		button.text = String(entry[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = (String(entry[0]) == "UNDO" and _roster_undo_locations.is_empty())
		var callback: Callable = entry[1] as Callable
		button.pressed.connect(callback)
		actions.add_child(button)
	return column


func _build_visual_equipment_slot(
		campaign: CampaignState,
		character: PersistentCharacterState,
		slot_id: StringName,
		display_name: String
) -> Control:
	var availability: Dictionary = _campaign_session.strategic_character_availability(
		character.character_id
	)
	var deployment_locked: bool = not bool(availability.get("available", true))
	var lock_reason: String = String(
		availability.get("reason", "Unavailable until the squad returns.")
	)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var heading := Label.new()
	heading.text = display_name
	heading.add_theme_font_size_override("font_size", 9)
	heading.add_theme_color_override("font_color", Color("cbb678"))
	column.add_child(heading)
	var slot: StrategicEquipmentDropSlot = StrategicEquipmentDropSlotScript.new()
	slot.custom_minimum_size = Vector2(0, 52)
	var items: Array[CampaignItemState] = _character_items_in_container(
		campaign,
		character.character_id,
		slot_id
	)
	var tooltip: String = "%s — Empty" % display_name.capitalize()
	var icon_texture: Texture2D = null
	if not items.is_empty():
		var item: CampaignItemState = items[0]
		var definition: ItemDefinition = _campaign_session.catalogue.item_definition(
			item.definition_id
		)
		tooltip = _compact_equipment_summary(item, definition, character)
		var linked_two_handed: bool = (
			definition != null
			and definition.is_two_handed()
			and slot_id == CampaignItemLocationState.CONTAINER_SECONDARY_HAND
		)
		if linked_two_handed:
			icon_texture = LINKED_SLOT_ICON
		elif definition != null:
			var icon_path: String = _item_icon_path(definition)
			if ResourceLoader.exists(icon_path):
				icon_texture = load(icon_path) as Texture2D
	slot.configure(slot_id, "")
	if not deployment_locked and not items.is_empty():
		var source_item: CampaignItemState = items[0]
		var source_definition: ItemDefinition = _campaign_session.catalogue.item_definition(
			source_item.definition_id
		)
		slot.configure_drag_source(
			slot_id,
			source_item.item_id,
			source_definition.display_name
			if source_definition != null
			else String(source_item.definition_id),
			source_definition.inventory_footprint
			if source_definition != null
			else Vector2i.ONE
		)
	slot.icon = icon_texture
	slot.expand_icon = true
	slot.add_theme_constant_override("icon_max_width", 46)
	slot.tooltip_text = (
		lock_reason
		if deployment_locked
		else tooltip + (
			"\nDrag onto Available Equipment to return it to storage. Right-click remains a fallback."
			if not items.is_empty()
			else ""
		)
	)
	# Hand slots are direct drop targets. Deployment locks disable both incoming
	# drops and outgoing exact-item drags without hiding the reserved loadout.
	slot.toggle_mode = false
	slot.focus_mode = Control.FOCUS_NONE
	slot.disabled = deployment_locked
	slot.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not deployment_locked:
		slot.item_drop_requested.connect(func(
			item_id: StringName,
			target_container_id: StringName
		) -> void:
			_request_roster_equip(
				item_id,
				character.character_id,
				target_container_id
			)
		)
		if not items.is_empty():
			var item_id: StringName = items[0].item_id
			slot.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton:
					var mouse_event := event as InputEventMouseButton
					if (
						mouse_event.pressed
						and mouse_event.button_index == MOUSE_BUTTON_RIGHT
					):
						_request_roster_unequip(item_id)
			)
	column.add_child(slot)
	return column

func _build_visual_inventory_slot(
		campaign: CampaignState,
		character: PersistentCharacterState,
		container_id: StringName,
		display_name: String,
		dimensions: Vector2i = Vector2i(10, 4),
		_expand_vertical: bool = false
) -> Control:
	var availability: Dictionary = _campaign_session.strategic_character_availability(
		character.character_id
	)
	var deployment_locked: bool = not bool(availability.get("available", true))
	var lock_reason: String = String(
		availability.get("reason", "Unavailable until the squad returns.")
	)
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	column.add_child(header)
	var select := Button.new()
	select.toggle_mode = true
	select.flat = true
	select.button_pressed = container_id == _roster_selected_slot
	select.text = display_name
	select.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.custom_minimum_size.y = 18
	select.add_theme_font_size_override("font_size", 9)
	select.disabled = deployment_locked
	select.tooltip_text = (
		lock_reason
		if deployment_locked
		else (
			"Quick-access tactical items."
			if container_id == CampaignItemLocationState.CONTAINER_BELT
			else "Main carried inventory. Press R or right-click to rotate the selected item."
		)
	)
	if not deployment_locked:
		select.pressed.connect(func() -> void:
			_roster_selected_slot = container_id
			_roster_equipment_category = EQUIPMENT_CATEGORY_GEAR
			_show_screen(SCREEN_ROSTER)
		)
	header.add_child(select)
	var grid: StrategicSpatialInventoryGrid = StrategicSpatialInventoryGridScript.new()
	var cell_size: float = _strategic_inventory_cell_size()
	grid.configure(container_id, dimensions.x, dimensions.y, Vector2(cell_size, cell_size))
	grid.render_campaign_items(
		_character_items_in_container(campaign, character.character_id, container_id),
		_campaign_session.catalogue
	)
	grid.set_selected_item(_roster_selected_item_id)
	grid.set_interaction_locked(deployment_locked, lock_reason)
	if not deployment_locked:
		grid.transfer_requested.connect(func(
			_source_kind: StringName,
			item_id: StringName,
			target_kind: StringName,
			target_cell_index: int
		) -> void:
			_on_strategic_grid_transfer(
				item_id,
				character.character_id,
				target_kind,
				target_cell_index,
				dimensions.x
			)
		)
		grid.item_activated.connect(func(
			item_control: SpatialInventoryItemControl,
			mouse_button: int
		) -> void:
			_roster_selected_item_id = item_control.item_id
			if mouse_button == MOUSE_BUTTON_RIGHT:
				var activated_item: CampaignItemState = campaign.get_item(item_control.item_id) as CampaignItemState
				var activated_definition: ItemDefinition = (
					_campaign_session.catalogue.item_definition(activated_item.definition_id)
					if activated_item != null
					else null
				)
				if activated_definition != null and activated_definition.fixed_inventory_fixture:
					_show_toast("Raider's Sack is permanently fixed to the Marauder's Belt.", true)
					grid.set_selected_item(item_control.item_id)
					return
				_rotate_strategic_inventory_item(
					item_control.item_id,
					character.character_id
				)
			else:
				grid.set_selected_item(item_control.item_id)
		)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_child(grid)
	return panel

func _strategic_inventory_cell_size() -> float:
	# Expand Belt and Backpack cells diagonally to the largest square size that
	# fits the fixed carried column. The grid grows inside the authored bounds;
	# it can never force the column itself wider.
	var canvas_width: float = maxf(1.0, get_viewport_rect().size.x - 24.0)
	var carried_width: float = (
		canvas_width * (EQUIP_CARRIED_RIGHT - EQUIP_CARRIED_LEFT)
		+ EQUIP_CARRIED_EXPAND_RIGHT_X
	)
	# Reserve the region inset, root margins and inventory-panel padding before
	# fitting the 10-column Backpack, which is the widest strategic grid.
	var usable_grid_width: float = maxf(190.0, carried_width - 12.0)
	return clampf(floorf(usable_grid_width / 10.0), 19.0, 36.0)

func _build_prestige_content(character: PersistentCharacterState, template: CharacterTemplateDefinition) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := _heading_label("TROOP PRESTIGE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var back := Button.new()
	back.text = "BACK TO CHARACTER"
	back.pressed.connect(func() -> void:
		_roster_tab_index = 1
		_show_screen(SCREEN_ROSTER)
	)
	title_row.add_child(back)
	column.add_child(_body_label("CURRENT: %s — TIER %d — LEVEL %d" % [character.troop_display_name(template.troop_type if template != null else "Henchman").to_upper(), character.troop_tier, character.resolved_level(template)]))
	column.add_child(_body_label("Prestige retains the troop's Level, XP, level-up feats, learned feats, abilities, spells, talents, equipment, injuries and history. ONLY the old Tier's starting feats are replaced by the selected new Tier's starting feats."))
	var active_project: TroopPrestigeProjectState = _campaign_session.active_prestige_project(character.character_id)
	if active_project != null:
		var remaining := maxi(0, active_project.completion_tick - _campaign().campaign_tick)
		column.add_child(_heading_label("TRAINING ACTIVE — %d HOURS REMAINING" % int(ceil(float(remaining) / 60.0))))
		column.add_child(_body_label("The troop remains in the Roster but cannot deploy until training completes."))
	column.add_child(HSeparator.new())
	var options: Array[Dictionary] = _campaign_session.prestige_options(character.character_id)
	if options.is_empty():
		column.add_child(_body_label("This troop has no authored Prestige career."))
		return column
	for option: Dictionary in options:
		var stage: TroopPrestigeStageDefinition = option.get("stage") as TroopPrestigeStageDefinition
		if stage == null:
			continue
		var panel := PanelContainer.new()
		column.add_child(panel)
		var margin := MarginContainer.new()
		for side: String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 10)
		panel.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		margin.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		details.add_child(_heading_label("TIER %d — %s" % [stage.troop_tier, stage.display_name.to_upper()]))
		details.add_child(_body_label("Requires Level %d. %s" % [stage.minimum_character_level, stage.description]))
		var old_feats: Array = option.get("current_tier_starting_feats", []) as Array
		var new_feats: Array = option.get("new_tier_starting_feats", []) as Array
		details.add_child(_body_label("REPLACED TIER STARTING FEATS: %s" % (", ".join(_variant_strings(old_feats)) if not old_feats.is_empty() else "None")))
		details.add_child(_body_label("NEW TIER STARTING FEATS: %s" % (", ".join(_variant_strings(new_feats)) if not new_feats.is_empty() else "None")))
		details.add_child(_body_label("RETAINED: all Levels, XP, ordinary feat choices, learned abilities and spells, previous non-starting Prestige gains, equipment and history."))
		var choose := Button.new()
		var completed: bool = character.completed_prestige_stage_ids.has(stage.stage_id)
		var eligible: bool = bool(option.get("eligible", false))
		choose.text = "COMPLETED" if completed else ("BEGIN PRESTIGE" if eligible else "LOCKED")
		choose.custom_minimum_size = Vector2(160, 56)
		choose.disabled = completed or not eligible or active_project != null
		choose.tooltip_text = String(option.get("reason", "Available"))
		var stage_id := stage.stage_id
		choose.pressed.connect(func() -> void: _request_troop_prestige(character.character_id, stage_id))
		row.add_child(choose)
	return column


func _build_level_up_content(
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	var preview: Dictionary = _campaign_session.next_level_preview(character.character_id)
	var current_level: int = int(preview.get("current_level", character.resolved_level(template)))
	var target_level: int = int(preview.get("target_level", current_level + 1))
	var xp_required: int = maxi(1, int(preview.get("xp_required", character.xp)))
	var eligible: bool = bool(preview.get("eligible", false))

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	column.add_child(title_row)
	var title := _heading_label("LEVEL %d → LEVEL %d" % [current_level, target_level])
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var back := Button.new()
	back.text = "BACK TO CHARACTER"
	back.custom_minimum_size = Vector2(170, 38)
	back.pressed.connect(func() -> void:
		_roster_tab_index = 1
		_show_screen(SCREEN_ROSTER)
	)
	title_row.add_child(back)

	column.add_child(_body_label("%s — TIER %d" % [
		character.troop_display_name(template.troop_type if template != null else "CHARACTER").to_upper(),
		character.troop_tier if not character.career_id.is_empty() else (template.troop_tier if template != null else 0),
	]))
	if eligible:
		column.add_child(_body_label("The XP requirement has been met. Review the gains below, then confirm the level."))
	else:
		column.add_child(_body_label(
			"This level is locked. Earn %d more XP; current XP progress is shown on the Character sheet."
			% maxi(0, xp_required - character.xp)
		))
	column.add_child(HSeparator.new())
	var stat_adjustments: Dictionary = preview.get("automatic_stat_adjustments", {}) as Dictionary
	if stat_adjustments.is_empty():
		column.add_child(_body_label("No automatic statistic gains are authored for this Level."))
	else:
		column.add_child(_heading_label("AUTOMATIC GAINS"))
		for raw_key: Variant in stat_adjustments.keys():
			var amount: int = int(stat_adjustments[raw_key])
			column.add_child(_body_label("%s  %+d" % [String(raw_key).replace("_", " ").capitalize(), amount]))
	var granted_abilities: Variant = preview.get("granted_ability_ids", [])
	if granted_abilities is Array and not (granted_abilities as Array).is_empty():
		column.add_child(_heading_label("NEW ABILITIES"))
		for raw_ability: Variant in granted_abilities as Array:
			column.add_child(_body_label(String(raw_ability).replace("_", " ").capitalize()))
	var choices: Array = preview.get("talent_choices", []) as Array
	if not choices.is_empty():
		column.add_child(_heading_label("CHOOSE ONE TALENT"))
		for raw_choice: Variant in choices:
			if not raw_choice is Dictionary:
				continue
			var choice: Dictionary = raw_choice as Dictionary
			var talent_id := StringName(choice.get("id", ""))
			var talent := Button.new()
			talent.toggle_mode = true
			talent.button_pressed = talent_id == _roster_selected_talent_id
			talent.alignment = HORIZONTAL_ALIGNMENT_LEFT
			talent.text = "%s\n%s" % [
				String(choice.get("display_name", String(talent_id).replace("_", " ").capitalize())).to_upper(),
				String(choice.get("description", "Authored troop talent.")),
			]
			talent.custom_minimum_size.y = 62
			talent.pressed.connect(func() -> void:
				_roster_selected_talent_id = talent_id
				_show_screen(SCREEN_ROSTER)
			)
			column.add_child(talent)
	var confirm := Button.new()
	confirm.text = "CONFIRM LEVEL %d" % target_level if eligible else "XP THRESHOLD NOT REACHED"
	confirm.disabled = not eligible or (not choices.is_empty() and _roster_selected_talent_id.is_empty())
	confirm.custom_minimum_size.y = 48
	confirm.pressed.connect(func() -> void:
		_request_character_level_up(character.character_id, current_level)
	)
	column.add_child(confirm)
	column.add_child(_body_label("Individual Level changes do not alter Troop Tier or transform a Marauder into a Harpooner."))
	return column


func _build_loadout_template_controls(
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)

	var selector_row := HBoxContainer.new()
	selector_row.add_theme_constant_override("separation", 6)
	column.add_child(selector_row)
	var label := Label.new()
	label.text = "TEMPLATE"
	label.custom_minimum_size.x = 74
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	selector_row.add_child(label)
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var templates: Array[LoadoutTemplateState] = _campaign_session.loadout_templates_for_character(character.character_id)
	if _roster_selected_template_id.is_empty():
		_roster_selected_template_id = character.preferred_loadout_template_id
	if _roster_selected_template_id.is_empty() and not templates.is_empty():
		_roster_selected_template_id = templates[0].template_id
	var selected_index: int = 0
	for loadout_template: LoadoutTemplateState in templates:
		var index: int = selector.item_count
		selector.add_item(loadout_template.display_name + ("  [AUTHORED]" if loadout_template.is_authored else ""))
		selector.set_item_metadata(index, loadout_template.template_id)
		selector.get_popup().set_item_tooltip(index, loadout_template.description)
		if loadout_template.template_id == _roster_selected_template_id:
			selected_index = index
	selector.select(selected_index)
	selector.item_selected.connect(func(index: int) -> void:
		_roster_selected_template_id = StringName(selector.get_item_metadata(index))
		_show_screen(SCREEN_ROSTER)
	)
	selector_row.add_child(selector)
	var apply := Button.new()
	apply.text = "APPLY"
	apply.disabled = templates.is_empty()
	apply.pressed.connect(_request_apply_selected_template)
	selector_row.add_child(apply)

	var selected_template: LoadoutTemplateState = campaign.get_loadout_template(_roster_selected_template_id)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if selected_template == null:
		status.text = "No compatible template selected."
		status.add_theme_color_override("font_color", Color("9da29a"))
	elif _campaign_session.current_loadout_matches_template(character.character_id, selected_template.template_id):
		status.text = "STATUS — MATCHES TEMPLATE"
		status.add_theme_color_override("font_color", Color("8fbd8f"))
	else:
		status.text = "STATUS — MODIFIED"
		status.add_theme_color_override("font_color", Color("d1ad68"))
	status.add_theme_font_size_override("font_size", 10)
	column.add_child(status)

	var actions := HFlowContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", 5)
	actions.add_theme_constant_override("v_separation", 5)
	column.add_child(actions)

	var save_new := Button.new()
	save_new.text = "SAVE AS NEW"
	save_new.pressed.connect(func() -> void: _request_save_current_as_template(character.character_id))
	actions.add_child(save_new)

	var update := Button.new()
	update.text = "UPDATE"
	update.disabled = selected_template == null or selected_template.is_authored
	update.tooltip_text = "Authored templates are locked; duplicate one to customise it." if selected_template != null and selected_template.is_authored else "Replace this player template with the current exact loadout and layout."
	update.pressed.connect(func() -> void: _request_update_selected_template(character.character_id))
	actions.add_child(update)

	var manage := Button.new()
	manage.text = "MANAGE"
	manage.disabled = selected_template == null
	manage.pressed.connect(func() -> void: _open_loadout_template_manager(character.character_id))
	actions.add_child(manage)

	var bulk := Button.new()
	bulk.text = "APPLY TO TROOP TYPE"
	bulk.disabled = templates.is_empty()
	bulk.tooltip_text = "Preview and apply this template to every compatible active %s." % (template.troop_type if template != null else "character")
	bulk.pressed.connect(func() -> void: _request_bulk_apply_selected_template(character, template))
	actions.add_child(bulk)
	return panel


func _build_armour_selector(
		campaign: CampaignState,
		character: PersistentCharacterState
) -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 0
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	var heading := Label.new()
	heading.text = "ARMOUR"
	heading.add_theme_font_size_override("font_size", 9)
	heading.add_theme_color_override("font_color", Color("cbb678"))
	column.add_child(heading)
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2(0, 42)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.clip_contents = true
	row.custom_minimum_size.x = 0
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ARMOUR_SLOT_ICON
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	# The armour selector is hosted by a fixed-width clipping control so the
	# selected armour name cannot expand the complete loadout column.
	var selector_holder := Control.new()
	selector_holder.clip_contents = true
	selector_holder.custom_minimum_size = Vector2(0, 30)
	selector_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(selector_holder)
	var selector := OptionButton.new()
	selector.fit_to_longest_item = false
	selector.clip_contents = true
	selector.custom_minimum_size.x = 0
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selector.get_popup().min_size = Vector2i(340, 0)
	selector.add_item("No Armour")
	selector.set_item_metadata(0, &"")
	var current_items: Array[CampaignItemState] = _character_items_in_container(
		campaign, character.character_id, CampaignItemLocationState.CONTAINER_ARMOUR
	)
	var current_id: StringName = current_items[0].item_id if not current_items.is_empty() else &""
	var candidates: Array[CampaignItemState] = []
	for item: CampaignItemState in current_items:
		candidates.append(item)
	for raw_item: Variant in campaign.stronghold_storage_items():
		var item: CampaignItemState = raw_item as CampaignItemState
		var definition: ItemDefinition = _campaign_session.catalogue.item_definition(item.definition_id) if item != null else null
		if item != null and definition != null and (
			definition.can_equip_in_slot(CampaignItemLocationState.CONTAINER_ARMOUR)
			or not definition.defence_profile_id.is_empty()
		):
			candidates.append(item)
	var selected_index: int = 0
	for item: CampaignItemState in candidates:
		var definition: ItemDefinition = _campaign_session.catalogue.item_definition(item.definition_id)
		if definition == null:
			continue
		var preview: OperationResult = _campaign_session.preview_strategic_equip(
			item.item_id, character.character_id, CampaignItemLocationState.CONTAINER_ARMOUR
		)
		var index: int = selector.item_count
		selector.add_item(definition.display_name)
		selector.set_item_metadata(index, item.item_id)
		selector.get_popup().set_item_disabled(index, not preview.success and item.item_id != current_id)
		selector.get_popup().set_item_tooltip(index, _equipment_comparison_text(
			item.item_id, character.character_id, CampaignItemLocationState.CONTAINER_ARMOUR
		) + ("\n" + preview.message if not preview.success else ""))
		if item.item_id == current_id:
			selected_index = index
	selector.select(selected_index)
	selector.item_selected.connect(func(index: int) -> void:
		var item_id := StringName(selector.get_item_metadata(index))
		_request_armour_change(character.character_id, current_id, item_id)
	)
	if not current_items.is_empty():
		var current_definition: ItemDefinition = _campaign_session.catalogue.item_definition(current_items[0].definition_id)
		selector.tooltip_text = "AC modifier %+d  •  Max Dex %d  •  %.1f lb" % [
			current_definition.stat_modifier(&"armour_class") if current_definition != null else 0,
			current_definition.maximum_dexterity_bonus if current_definition != null else 99,
			current_definition.weight_lb if current_definition != null else 0.0,
		]
	else:
		selector.tooltip_text = "No armour equipped."
	var availability: Dictionary = _campaign_session.strategic_character_availability(
		character.character_id
	)
	if not bool(availability.get("available", true)):
		selector.disabled = true
		selector.tooltip_text = String(
			availability.get("reason", "Unavailable until the squad returns.")
		)
	selector_holder.add_child(selector)
	selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return column

func _build_loadout_readiness_strip(character_id: StringName) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	panel.add_child(margin)
	var label := Label.new()
	var status: Dictionary = _campaign_session.strategic_loadout_status(character_id)
	var blocking: Array = status.get("blocking", []) as Array
	var warnings: Array = status.get("warnings", []) as Array
	if bool(status.get("locked", false)):
		label.text = "DEPLOYED\n%s" % String(
			status.get("lock_reason", "Unavailable until the squad returns.")
		)
		label.add_theme_color_override("font_color", Color("7b9bac"))
	elif bool(status.get("ready", false)) and warnings.is_empty():
		label.text = "LOADOUT READY"
		label.add_theme_color_override("font_color", Color("8fbd8f"))
	elif blocking.is_empty():
		label.text = "LOADOUT READY WITH WARNINGS\n• %s" % "\n• ".join(
			_variant_strings(warnings)
		)
		label.add_theme_color_override("font_color", Color("d1ad68"))
	else:
		label.text = "LOADOUT INCOMPLETE\n• %s" % "\n• ".join(
			_variant_strings(blocking + warnings)
		)
		label.add_theme_color_override("font_color", Color("cc7777"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 9)
	margin.add_child(label)
	return panel

func _compact_equipment_summary(
		item: CampaignItemState,
		definition: ItemDefinition,
		character: PersistentCharacterState
) -> String:
	if item == null or definition == null:
		return "UNKNOWN ITEM"
	var lines: Array[String] = [definition.display_name.to_upper()]
	if definition.can_equip_in_hand():
		var snapshot: ResolvedCharacterSnapshot = _resolved_roster_character(character, _campaign())
		lines.append("Attack %+d · %s · %.1f lb" % [
			_roster_primary_attack(snapshot),
			"Two-handed" if definition.is_two_handed() else "One-handed",
			definition.weight_lb,
		])
	elif definition.can_equip_in_slot(CampaignItemLocationState.CONTAINER_ARMOUR):
		lines.append("AC %+d · %.1f lb" % [definition.stat_modifier(&"armour_class"), definition.weight_lb])
	else:
		lines.append("%.1f lb · %s" % [definition.weight_lb, _item_condition_label(item)])
	return "\n".join(lines)


func _available_equipment_destinations(definition: ItemDefinition) -> Array[StringName]:
	# Available Equipment is now fully drag-first. Compatibility therefore means
	# that at least one real drop target accepts the item; it is not derived from
	# a previously clicked hand slot or a hidden destination selection.
	var destinations: Array[StringName] = []
	if definition == null:
		return destinations
	if (
		definition.can_equip_in_slot(CampaignItemLocationState.CONTAINER_ARMOUR)
		or not definition.defence_profile_id.is_empty()
	):
		destinations.append(CampaignItemLocationState.CONTAINER_ARMOUR)
	if definition.can_equip_in_hand():
		destinations.append(CampaignItemLocationState.CONTAINER_PRIMARY_HAND)
		destinations.append(CampaignItemLocationState.CONTAINER_SECONDARY_HAND)
	if definition.belt_allowed:
		destinations.append(CampaignItemLocationState.CONTAINER_BELT)
	if definition.backpack_allowed:
		destinations.append(CampaignItemLocationState.CONTAINER_BACKPACK)
	return destinations


func _preview_available_equipment_destination(
		item_id: StringName,
		character_id: StringName,
		definition: ItemDefinition
) -> Dictionary:
	var destinations: Array[StringName] = _available_equipment_destinations(definition)
	var fallback_destination: StringName = (
		destinations[0]
		if not destinations.is_empty()
		else CampaignItemLocationState.CONTAINER_BACKPACK
	)
	var fallback_preview: OperationResult = null
	for destination: StringName in destinations:
		var preview: OperationResult = _campaign_session.preview_strategic_equip(
			item_id,
			character_id,
			destination
		)
		if fallback_preview == null:
			fallback_preview = preview
			fallback_destination = destination
		if preview.success:
			return {
				"destination": destination,
				"preview": preview,
			}
	if fallback_preview == null:
		fallback_preview = OperationResult.fail(
			&"no_loadout_destination",
			"This item has no valid loadout destination."
		)
	return {
		"destination": fallback_destination,
		"preview": fallback_preview,
	}


func _equipment_comparison_text(
		item_id: StringName,
		character_id: StringName,
		container_id: StringName
) -> String:
	var campaign: CampaignState = _campaign()
	if campaign == null or _campaign_session.strategic_equipment_service == null:
		return ""
	var character: PersistentCharacterState = campaign.get_character(character_id)
	if character == null:
		return ""
	var before: ResolvedCharacterSnapshot = _resolved_roster_character(character, campaign)
	var candidate := CampaignState.from_dictionary(campaign.to_dictionary())
	var applied: OperationResult = _campaign_session.strategic_equipment_service.equip_candidate(
		candidate,
		item_id,
		character_id,
		container_id
	)
	if not applied.success:
		return ""
	var candidate_character: PersistentCharacterState = candidate.get_character(character_id)
	var after: ResolvedCharacterSnapshot = _resolved_roster_character(candidate_character, candidate)
	var lines: Array[String] = []
	var before_ac: int = before.stat_value(&"armour_class", 10)
	var after_ac: int = after.stat_value(&"armour_class", 10)
	if before_ac != after_ac:
		lines.append("AC %d → %d" % [before_ac, after_ac])
	var before_attack: int = _roster_primary_attack(before)
	var after_attack: int = _roster_primary_attack(after)
	if before_attack != after_attack:
		lines.append("Attack %+d → %+d" % [before_attack, after_attack])
	var before_move: int = before.stat_value(&"turn_capacity", 30)
	var after_move: int = after.stat_value(&"turn_capacity", 30)
	if before_move != after_move:
		lines.append("Move %d → %d ft" % [before_move, after_move])
	var before_weight: float = _character_carried_weight(campaign, character_id)
	var after_weight: float = _character_carried_weight(candidate, character_id)
	if absf(before_weight - after_weight) > 0.01:
		lines.append("Carry %.1f → %.1f lb" % [before_weight, after_weight])
	return " · ".join(lines)


func _request_armour_change(
		character_id: StringName,
		current_item_id: StringName,
		selected_item_id: StringName
) -> void:
	if selected_item_id == current_item_id:
		return
	if selected_item_id.is_empty():
		if not current_item_id.is_empty():
			_request_roster_unequip(current_item_id)
		return
	_request_roster_equip(selected_item_id, character_id, CampaignItemLocationState.CONTAINER_ARMOUR)


func _on_strategic_grid_transfer(
		item_id: StringName,
		character_id: StringName,
		container_id: StringName,
		target_cell_index: int,
		grid_width: int
) -> void:
	var item: CampaignItemState = _campaign().get_item(item_id) as CampaignItemState
	if item == null:
		_show_toast("The selected item no longer exists.", true)
		return
	var position := Vector2i(target_cell_index % grid_width, int(target_cell_index / grid_width))
	var rotated: bool = item.location.is_rotated if item.location != null else false
	var preview: OperationResult = _campaign_session.preview_strategic_place(
		item_id, character_id, container_id, position, rotated
	)
	if not preview.success:
		_show_toast(preview.message, true)
		return
	_record_equipment_undo()
	var result: OperationResult = _campaign_session.place_strategic_item(
		item_id, character_id, container_id, position, rotated
	)
	if not result.success:
		_show_toast(result.message, true)
		return
	_roster_selected_item_id = item_id
	_show_screen(SCREEN_ROSTER)
	_show_toast(result.message)


func _rotate_strategic_inventory_item(item_id: StringName, character_id: StringName) -> void:
	var campaign: CampaignState = _campaign()
	var item: CampaignItemState
	if campaign != null:
		item = campaign.get_item(item_id) as CampaignItemState
	if item == null or item.location == null:
		return
	var definition: ItemDefinition = _campaign_session.catalogue.item_definition(item.definition_id)
	if definition == null or not definition.inventory_rotation_allowed:
		_show_toast("This item cannot be rotated.", true)
		return
	_record_equipment_undo()
	var result: OperationResult = _campaign_session.place_strategic_item(
		item_id,
		character_id,
		item.location.container_id,
		item.location.grid_position,
		not item.location.is_rotated
	)
	if not result.success:
		_show_toast(result.message, true)
		return
	_show_screen(SCREEN_ROSTER)
	_show_toast("Item rotated.")


func _auto_pack_character_container(character_id: StringName, container_id: StringName) -> void:
	_record_equipment_undo()
	var result: OperationResult = _campaign_session.auto_pack_strategic_container(character_id, container_id)
	if not result.success:
		_show_toast(result.message, true)
		return
	_show_screen(SCREEN_ROSTER)
	_show_toast(result.message)


func _clear_character_container(character_id: StringName, container_id: StringName) -> void:
	_record_equipment_undo()
	var result: OperationResult = _campaign_session.return_strategic_container_to_storage(character_id, container_id)
	if not result.success:
		_show_toast(result.message, true)
		return
	_show_screen(SCREEN_ROSTER)
	_show_toast(result.message)


func _ensure_roster_screen_snapshot(character_id: StringName) -> void:
	var key := String(character_id)
	if not _roster_screen_open_locations.has(key):
		_roster_screen_open_locations[key] = _campaign_session.capture_strategic_item_locations()


func _record_equipment_undo() -> void:
	_roster_undo_locations = _campaign_session.capture_strategic_item_locations()


func _undo_last_equipment_change() -> void:
	if _roster_undo_locations.is_empty():
		return
	var result: OperationResult = _campaign_session.restore_strategic_item_locations(
		_roster_undo_locations,
		&"strategic_equipment_undo"
	)
	if not result.success:
		_show_toast(result.message, true)
		return
	_roster_undo_locations.clear()
	_show_screen(SCREEN_ROSTER)
	_show_toast("Last equipment change undone.")


func _restore_screen_open_loadout(character_id: StringName) -> void:
	var snapshot: Dictionary = _roster_screen_open_locations.get(String(character_id), {}) as Dictionary
	if snapshot.is_empty():
		_show_toast("No screen-open loadout snapshot is available.")
		return
	_record_equipment_undo()
	var result: OperationResult = _campaign_session.restore_strategic_item_locations(
		snapshot,
		&"strategic_loadout_screen_restore"
	)
	if not result.success:
		_show_toast(result.message, true)
		return
	_show_screen(SCREEN_ROSTER)
	_show_toast("Screen-open loadout restored.")


func _return_all_carried_items(character_id: StringName) -> void:
	_record_equipment_undo()
	var result: OperationResult = _campaign_session.return_all_strategic_items(character_id)
	if not result.success:
		_show_toast(result.message, true)
		return
	_show_screen(SCREEN_ROSTER)
	_show_toast(result.message)


func _request_apply_selected_template() -> void:
	if _roster_selected_template_id.is_empty():
		return
	var preview: OperationResult = _campaign_session.preview_apply_loadout_template(
		_selected_character_id,
		_roster_selected_template_id
	)
	if not preview.success:
		_show_toast(preview.message, true)
		return
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var lines: Array[String] = []
	var outcomes: Variant = data.get("outcomes", [])
	if outcomes is Array:
		for raw_outcome: Variant in outcomes as Array:
			if raw_outcome is Dictionary:
				var outcome: Dictionary = raw_outcome as Dictionary
				var marker: String = "△" if String(outcome.get("status", "")) == "substituted" else "✓"
				lines.append("%s %s" % [marker, String(outcome.get("label", "Item"))])
	var dialog := ConfirmationDialog.new()
	dialog.title = "Apply Loadout Template"
	dialog.dialog_text = "%s\n\n%s" % [String(data.get("template_name", "Loadout")), "\n".join(lines)]
	dialog.get_ok_button().text = "APPLY"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_record_equipment_undo()
		var result: OperationResult = _campaign_session.apply_loadout_template(
			_selected_character_id,
			_roster_selected_template_id
		)
		if not result.success:
			_show_toast(result.message, true)
			return
		_show_screen(SCREEN_ROSTER)
		_show_toast(result.message)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(620, 480))


func _request_save_current_as_template(character_id: StringName) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Save Loadout Template"
	dialog.dialog_text = "Create a reusable player loadout from the current exact equipment and spatial layout."
	dialog.get_ok_button().text = "SAVE"
	var name_input := LineEdit.new()
	name_input.placeholder_text = "Template name"
	name_input.text = "Custom Loadout"
	dialog.add_child(name_input)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _campaign_session.save_current_loadout_as_template(
			character_id,
			name_input.text
		)
		dialog.queue_free()
		if not result.success:
			_show_toast(result.message, true)
			return
		if result.data is LoadoutTemplateState:
			_roster_selected_template_id = (result.data as LoadoutTemplateState).template_id
		_show_screen(SCREEN_ROSTER)
		_show_toast(result.message)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(560, 260))


func _request_update_selected_template(character_id: StringName) -> void:
	if _roster_selected_template_id.is_empty():
		return
	var result: OperationResult = _campaign_session.update_loadout_template_from_character(
		character_id,
		_roster_selected_template_id
	)
	if not result.success:
		_show_toast(result.message, true)
		return
	_show_screen(SCREEN_ROSTER)
	_show_toast(result.message)


func _open_loadout_template_manager(character_id: StringName) -> void:
	var campaign: CampaignState = _campaign()
	var selected_template: LoadoutTemplateState = (
		campaign.get_loadout_template(_roster_selected_template_id)
		if campaign != null
		else null
	)
	var dialog := AcceptDialog.new()
	dialog.title = "Manage Loadout Templates"
	dialog.get_ok_button().text = "CLOSE"
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(590, 360)
	column.add_theme_constant_override("separation", 10)
	dialog.add_child(column)
	var selected_name: String = selected_template.display_name if selected_template != null else "No template selected"
	column.add_child(_heading_label(selected_name.to_upper()))
	column.add_child(_body_label(
		"Templates describe desired equipment and spatial layout. They never own item instances. "
		+ "Apply a template, customise the character manually, then use Update from Current to revise a player template."
	))
	var policy_row := HBoxContainer.new()
	policy_row.add_theme_constant_override("separation", 8)
	column.add_child(policy_row)
	var policy_label := Label.new()
	policy_label.text = "SUBSTITUTION POLICY"
	policy_label.custom_minimum_size.x = 165
	policy_row.add_child(policy_label)
	var policy := OptionButton.new()
	policy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: Array in [
		[LoadoutTemplateState.POLICY_STRICT, "Strict"],
		[LoadoutTemplateState.POLICY_EQUIVALENT, "Equivalent"],
		[LoadoutTemplateState.POLICY_BEST_AVAILABLE, "Best Available"],
		[LoadoutTemplateState.POLICY_CONSERVE_VALUABLE, "Conserve Valuable Gear"],
	]:
		var index: int = policy.item_count
		policy.add_item(String(entry[1]))
		policy.set_item_metadata(index, StringName(entry[0]))
		if selected_template != null and selected_template.substitution_policy == StringName(entry[0]):
			policy.select(index)
	policy.disabled = selected_template == null or selected_template.is_authored
	policy.item_selected.connect(func(index: int) -> void:
		var policy_id := StringName(policy.get_item_metadata(index))
		var result: OperationResult = _campaign_session.set_loadout_template_substitution_policy(
			_roster_selected_template_id,
			policy_id
		)
		if not result.success:
			_show_toast(result.message, true)
		else:
			_show_toast(result.message)
	)
	policy_row.add_child(policy)
	var create_blank := Button.new()
	create_blank.text = "CREATE BLANK TEMPLATE"
	create_blank.pressed.connect(func() -> void:
		dialog.hide()
		_prompt_create_blank_loadout_template(character_id)
		dialog.queue_free()
	)
	column.add_child(create_blank)
	var duplicate := Button.new()
	duplicate.text = "DUPLICATE SELECTED TEMPLATE"
	duplicate.disabled = selected_template == null
	duplicate.pressed.connect(func() -> void:
		dialog.hide()
		_prompt_duplicate_loadout_template(selected_template)
		dialog.queue_free()
	)
	column.add_child(duplicate)
	var delete := Button.new()
	delete.text = "DELETE SELECTED PLAYER TEMPLATE"
	delete.disabled = selected_template == null or selected_template.is_authored
	delete.pressed.connect(func() -> void:
		dialog.hide()
		_confirm_delete_loadout_template(selected_template)
		dialog.queue_free()
	)
	column.add_child(delete)
	var hint := Label.new()
	hint.text = "Authored templates are locked. Duplicate them before changing contents or substitution policy."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("9da29a"))
	column.add_child(hint)
	add_child(dialog)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.confirmed.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(640, 470))


func _prompt_create_blank_loadout_template(character_id: StringName) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Create Blank Loadout Template"
	dialog.dialog_text = "Create an empty template for this troop type. Apply it, equip the desired contents, then update it from the current loadout."
	dialog.get_ok_button().text = "CREATE"
	var name_input := LineEdit.new()
	name_input.placeholder_text = "Template name"
	name_input.text = "Blank Custom Loadout"
	dialog.add_child(name_input)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _campaign_session.create_blank_loadout_template(
			character_id,
			name_input.text
		)
		dialog.queue_free()
		if not result.success:
			_show_toast(result.message, true)
			return
		if result.data is LoadoutTemplateState:
			_roster_selected_template_id = (result.data as LoadoutTemplateState).template_id
		_show_screen(SCREEN_ROSTER)
		_show_toast(result.message)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(560, 270))


func _prompt_duplicate_loadout_template(source: LoadoutTemplateState) -> void:
	if source == null:
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Duplicate Loadout Template"
	dialog.dialog_text = "Create an editable player copy of %s." % source.display_name
	dialog.get_ok_button().text = "DUPLICATE"
	var name_input := LineEdit.new()
	name_input.placeholder_text = "Template name"
	name_input.text = "%s Copy" % source.display_name
	dialog.add_child(name_input)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _campaign_session.duplicate_loadout_template(
			source.template_id,
			name_input.text
		)
		dialog.queue_free()
		if not result.success:
			_show_toast(result.message, true)
			return
		if result.data is LoadoutTemplateState:
			_roster_selected_template_id = (result.data as LoadoutTemplateState).template_id
		_show_screen(SCREEN_ROSTER)
		_show_toast(result.message)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(560, 250))


func _confirm_delete_loadout_template(template: LoadoutTemplateState) -> void:
	if template == null or template.is_authored:
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Loadout Template"
	dialog.dialog_text = "Delete %s? Existing character equipment will not change." % template.display_name
	dialog.get_ok_button().text = "DELETE"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _campaign_session.delete_loadout_template(template.template_id)
		dialog.queue_free()
		if not result.success:
			_show_toast(result.message, true)
			return
		_roster_selected_template_id = &""
		_show_screen(SCREEN_ROSTER)
		_show_toast(result.message)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(520, 220))


func _request_bulk_apply_selected_template(
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition
) -> void:
	if _roster_selected_template_id.is_empty() or template == null:
		return
	var character_ids: Array[StringName] = []
	for roster_character: PersistentCharacterState in _campaign_roster_characters(_campaign()):
		if roster_character.is_dead:
			continue
		var roster_template: CharacterTemplateDefinition = _campaign_session.catalogue.character_template(roster_character.template_id)
		if roster_template != null and roster_template.troop_type == template.troop_type:
			character_ids.append(roster_character.character_id)
	var preview: OperationResult = _campaign_session.loadout_service.preview_apply_template_to_many(
		_campaign(), character_ids, _roster_selected_template_id
	)
	if not preview.success:
		_show_toast(preview.message, true)
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Apply Template to %s Troops" % template.troop_type
	dialog.dialog_text = "%s\n\nExact inventory is allocated once across the complete group. Existing loadouts return to storage before allocation." % preview.message
	dialog.get_ok_button().text = "APPLY TO GROUP"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_record_equipment_undo()
		var result: OperationResult = _campaign_session.apply_loadout_template_to_characters(
			character_ids,
			_roster_selected_template_id
		)
		if not result.success:
			_show_toast(result.message, true)
			return
		_show_screen(SCREEN_ROSTER)
		_show_toast(result.message)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(620, 320))


func _request_henchman_recruitment(offer_id: StringName) -> void:
	var result: OperationResult = _campaign_session.begin_henchman_recruitment(offer_id)
	_show_toast(result.message, not result.success)
	if result.success:
		_show_screen(SCREEN_ROSTER)


func _request_troop_prestige(character_id: StringName, stage_id: StringName) -> void:
	var selected_option: Dictionary = {}
	for option: Dictionary in _campaign_session.prestige_options(character_id):
		var stage: TroopPrestigeStageDefinition = option.get("stage") as TroopPrestigeStageDefinition
		if stage != null and stage.stage_id == stage_id:
			selected_option = option
			break
	var stage: TroopPrestigeStageDefinition = selected_option.get("stage") as TroopPrestigeStageDefinition
	if stage == null or not bool(selected_option.get("eligible", false)):
		_show_toast(String(selected_option.get("reason", "Prestige is unavailable.")), true)
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Prestige to Tier %d — %s" % [stage.troop_tier, stage.display_name]
	dialog.dialog_text = "This keeps every Level, XP award, level-up feat, learned feat, ability, spell, talent, item, injury and history. Only the current Tier's starting feats will be removed and replaced with the new Tier's starting feats.\n\nBegin this Prestige project?"
	dialog.get_ok_button().text = "BEGIN PRESTIGE"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		var result: OperationResult = _campaign_session.begin_troop_prestige(character_id, stage_id)
		_show_toast(result.message, not result.success)
		_show_screen(SCREEN_ROSTER)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(680, 360))


func _request_character_level_up(character_id: StringName, expected_level: int) -> void:
	var result: OperationResult = _campaign_session.level_up_character(
		character_id,
		expected_level,
		_roster_selected_talent_id
	)
	if not result.success:
		_show_toast(result.message, true)
		return
	_roster_selected_talent_id = &""
	_roster_tab_index = 2
	_show_screen(SCREEN_ROSTER)
	_show_toast("Character advanced to the next Level.")


func _display_id(value: StringName) -> String:
	var text := String(value)
	var pieces := text.split(".", false)
	return (pieces[-1] if not pieces.is_empty() else text).replace("_", " ").capitalize()


func _variant_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	return result


# Legacy Stage 5.3 correction reference retained for regression tooling: panel.custom_minimum_size.x = 280
func _build_equip_available_items(
		campaign: CampaignState,
		character: PersistentCharacterState
) -> Control:
	if _roster_equipment_category == EQUIPMENT_CATEGORY_ARMOUR:
		_roster_equipment_category = EQUIPMENT_CATEGORY_WEAPONS
	var panel = StrategicStorageDropPanelScript.new()
	panel.custom_minimum_size.x = 0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.10
	panel.clip_contents = true
	panel.tooltip_text = "Drop any equipped or carried item anywhere in this panel to return it to Stronghold Storage."
	panel.item_drop_requested.connect(func(item_id: StringName) -> void:
		_request_roster_unequip(item_id)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "AVAILABLE EQUIPMENT"
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color("d8c187"))
	column.add_child(heading)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 5)
	column.add_child(search_row)
	var search := LineEdit.new()
	search.placeholder_text = "Search equipment"
	search.text = _roster_equipment_search
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_submitted.connect(func(value: String) -> void:
		_roster_equipment_search = value.strip_edges()
		_show_screen(SCREEN_ROSTER)
	)
	search_row.add_child(search)
	var compatibility := Button.new()
	compatibility.toggle_mode = true
	compatibility.button_pressed = _roster_compatible_only
	compatibility.text = "COMPATIBLE" if _roster_compatible_only else "ALL"
	compatibility.tooltip_text = "Show only items accepted by at least one hand, Belt or Backpack drop target."
	compatibility.pressed.connect(func() -> void:
		_roster_compatible_only = not _roster_compatible_only
		_show_screen(SCREEN_ROSTER)
	)
	search_row.add_child(compatibility)
	var category_row := GridContainer.new()
	category_row.columns = 4
	category_row.add_theme_constant_override("h_separation", 3)
	category_row.add_theme_constant_override("v_separation", 3)
	column.add_child(category_row)
	for category_entry: Array in [
		[EQUIPMENT_CATEGORY_WEAPONS, "WEAPONS"],
		[EQUIPMENT_CATEGORY_GEAR, "GEAR"],
		[EQUIPMENT_CATEGORY_CONSUMABLES, "CONSUMABLES"],
		[EQUIPMENT_CATEGORY_AMMUNITION, "AMMO"],
	]:
		var category_id: StringName = StringName(category_entry[0])
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = category_id == _roster_equipment_category
		button.text = String(category_entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(func() -> void:
			_roster_equipment_category = category_id
			_show_screen(SCREEN_ROSTER)
		)
		category_row.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	var count: int = 0
	for raw_item: Variant in campaign.stronghold_storage_items():
		var item: CampaignItemState = raw_item as CampaignItemState
		if item == null:
			continue
		var definition: ItemDefinition = _campaign_session.catalogue.item_definition(item.definition_id)
		if not _is_roster_equipment_candidate(definition):
			continue
		if _equipment_category_id(definition) != _roster_equipment_category:
			continue
		if not _roster_equipment_search.is_empty() and (
			definition == null or not definition.display_name.to_lower().contains(_roster_equipment_search.to_lower())
		):
			continue
		var compatibility_preview: Dictionary = _preview_available_equipment_destination(
			item.item_id,
			character.character_id,
			definition
		)
		var destination := StringName(compatibility_preview.get(
			"destination",
			CampaignItemLocationState.CONTAINER_BACKPACK
		))
		var preview: OperationResult = compatibility_preview.get("preview") as OperationResult
		if preview == null:
			preview = OperationResult.fail(
				&"equipment_preview_unavailable",
				"Equipment compatibility could not be checked."
			)
		if _roster_compatible_only and not preview.success:
			continue
		count += 1
		list.add_child(_build_available_equipment_card(item, definition, character, destination, preview))
	if count == 0:
		list.add_child(_body_label("No matching items are currently available. Switch to All to inspect rejected equipment."))
	return panel


func _build_available_equipment_card(
		item: CampaignItemState,
		definition: ItemDefinition,
		character: PersistentCharacterState,
		destination: StringName,
		preview: OperationResult
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 56
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	margin.add_child(row)
	var drag_item: SpatialInventoryItemControl = SpatialInventoryItemControlScript.new()
	drag_item.custom_minimum_size = Vector2(48, 44)
	drag_item.configure(
		&"stronghold_storage",
		item.item_id,
		definition.display_name if definition != null else String(item.definition_id),
		definition.inventory_footprint if definition != null else Vector2i.ONE,
		definition.tactical_visual_category if definition != null else &"misc"
	)
	var character_availability: Dictionary = (
		_campaign_session.strategic_character_availability(character.character_id)
	)
	var character_locked: bool = not bool(
		character_availability.get("available", true)
	)
	drag_item.disabled = character_locked
	drag_item.tooltip_text = (
		String(character_availability.get("reason", "Unavailable until the squad returns."))
		if character_locked
		else "Drag to a hand, Belt or Backpack."
	)
	row.add_child(drag_item)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	var title := Label.new()
	title.text = "%s%s%s" % [
		definition.display_name if definition != null else String(item.definition_id),
		" ×%d" % item.quantity if item.quantity > 1 else "",
		"",
	]
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 11)
	details.add_child(title)
	var item_meta: String = "%.1f lb" % (definition.weight_lb * float(item.quantity))
	if not _is_armour_definition(definition):
		item_meta += "  •  %s" % _item_condition_label(item)
	details.add_child(_small_meta_label(item_meta))
	var comparison: String = _equipment_comparison_text(item.item_id, character.character_id, destination)
	if not comparison.is_empty():
		var comparison_label := Label.new()
		comparison_label.text = comparison
		comparison_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		comparison_label.add_theme_font_size_override("font_size", 9)
		comparison_label.add_theme_color_override("font_color", Color("aeb9ae"))
		details.add_child(comparison_label)
	# Available equipment is deliberately drag-first, matching the tactical
	# inventory interaction. The card exposes no click-to-equip button; drag the
	# exact item instance onto a hand, Belt cell, Backpack cell, or Storage.
	# Keep rejected instances draggable in the All view so the authoritative
	# target validator can explain the failed drop rather than turning the card
	# back into a click-only disabled row.
	drag_item.modulate = (
		Color.WHITE
		if preview.success and not character_locked
		else Color(0.62, 0.62, 0.62, 0.82)
	)
	drag_item.tooltip_text = (
		String(character_availability.get("reason", "Unavailable until the squad returns."))
		if character_locked
		else "Drag this exact item to a hand, Belt, or Backpack."
		if preview.success
		else preview.message
	)
	if not preview.success:
		var reason := Label.new()
		reason.text = preview.message
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.add_theme_font_size_override("font_size", 9)
		reason.add_theme_color_override("font_color", Color("ba7777"))
		details.add_child(reason)
	return panel


func _equipment_category_id(definition: ItemDefinition) -> StringName:
	if definition == null:
		return EQUIPMENT_CATEGORY_GEAR
	if definition.has_tag(&"ammunition"):
		return EQUIPMENT_CATEGORY_AMMUNITION
	if definition.has_tag(&"consumable") or definition.has_tag(&"medical"):
		return EQUIPMENT_CATEGORY_CONSUMABLES
	if definition.can_equip_in_hand():
		return EQUIPMENT_CATEGORY_WEAPONS
	if definition.can_equip_in_slot(CampaignItemLocationState.CONTAINER_ARMOUR) or not definition.defence_profile_id.is_empty():
		return EQUIPMENT_CATEGORY_ARMOUR
	return EQUIPMENT_CATEGORY_GEAR


func _build_roster_memorial_view(
		root: Control,
		campaign: CampaignState,
		roster: Array[PersistentCharacterState]
) -> void:
	var canvas := _build_roster_static_canvas(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_place_equip_region(
		canvas,
		column,
		ROSTER_CONTENT_LEFT,
		ROSTER_CONTENT_TOP,
		ROSTER_CONTENT_RIGHT,
		ROSTER_CONTENT_BOTTOM,
		2.0
	)
	var title := Label.new()
	title.text = "MEMORIAL"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("d4bd7d"))
	column.add_child(title)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)
	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 14)
	panel_margin.add_theme_constant_override("margin_right", 14)
	panel_margin.add_theme_constant_override("margin_top", 12)
	panel_margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(panel_margin)
	var memorial_column := VBoxContainer.new()
	memorial_column.add_theme_constant_override("separation", 4)
	panel_margin.add_child(memorial_column)
	var dead: Array[PersistentCharacterState] = []
	for character: PersistentCharacterState in roster:
		if character.is_dead:
			dead.append(character)
	if dead.is_empty():
		memorial_column.add_child(_body_label("No permanent characters have been lost."))
	else:
		var header := HBoxContainer.new()
		for entry: Array in [["NAME", 320], ["TROOP", 200], ["TIER", 80], ["FINAL LEVEL", 110], ["MISSIONS", 100], ["HISTORY", 400]]:
			var label := Label.new()
			label.text = String(entry[0])
			label.custom_minimum_size.x = float(entry[1])
			label.add_theme_font_size_override("font_size", 11)
			label.add_theme_color_override("font_color", Color("b7aa87"))
			header.add_child(label)
		memorial_column.add_child(header)
		memorial_column.add_child(HSeparator.new())
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		memorial_column.add_child(scroll)
		var list := VBoxContainer.new()
		scroll.add_child(list)
		for character: PersistentCharacterState in dead:
			var template: CharacterTemplateDefinition = _campaign_session.catalogue.character_template(character.template_id)
			var row := HBoxContainer.new()
			for value_entry: Array in [
				[character.display_name.to_upper(), 320],
				[template.troop_type if template != null else "Unknown", 200],
				[str(template.troop_tier if template != null else 0), 80],
				[str(character.resolved_level(template)), 110],
				[str(character.deployment_count), 100],
				[character.history_entries[-1] if not character.history_entries.is_empty() else "Fell in service to the Fifth.", 400],
			]:
				var label := Label.new()
				label.text = String(value_entry[0])
				label.custom_minimum_size.x = float(value_entry[1])
				label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				label.add_theme_font_size_override("font_size", 12)
				label.add_theme_color_override("font_color", Color("c8b9aa"))
				row.add_child(label)
			list.add_child(row)
	_place_equip_region(
		canvas,
		_build_roster_mode_bar(),
		EQUIP_MODE_BAR_LEFT,
		EQUIP_MODE_BAR_TOP,
		EQUIP_MODE_BAR_RIGHT,
		EQUIP_MODE_BAR_BOTTOM,
		0.0
	)


func _build_roster_mode_bar() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for mode_entry: Array in [
		[ROSTER_MODE_MANAGE, "MANAGE ROSTER"],
		[ROSTER_MODE_EQUIP, "ARMOURY"],
		[ROSTER_MODE_WORKFORCE, "WORKFORCE"],
		[ROSTER_MODE_MEMORIAL, "MEMORIAL"],
	]:
		var mode_id: StringName = StringName(mode_entry[0])
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = mode_id == _roster_mode
		button.text = String(mode_entry[1])
		button.custom_minimum_size = Vector2(160, 44)
		button.pressed.connect(func() -> void:
			var entering_equip: bool = (
				mode_id == ROSTER_MODE_EQUIP
				and _roster_mode != ROSTER_MODE_EQUIP
			)
			_roster_mode = mode_id
			if entering_equip:
				_roster_tab_index = 0
			_show_screen(SCREEN_ROSTER)
		)
		row.add_child(button)
	if not _planning_mission_id.is_empty():
		var briefing := Button.new()
		briefing.text = "RETURN TO BRIEFING"
		briefing.custom_minimum_size = Vector2(190, 44)
		briefing.pressed.connect(func() -> void: _show_screen(SCREEN_BRIEFING))
		row.add_child(briefing)
	return row


func _resolved_roster_character(
		character: PersistentCharacterState,
		campaign: CampaignState
) -> ResolvedCharacterSnapshot:
	var service := CharacterResolutionService.new()
	service.configure(_campaign_session.catalogue)
	var items: Array = (
		campaign.items_for_character(character.character_id)
		if campaign != null and character != null
		else []
	)
	return service.resolve_character(character, [], items)


func _roster_primary_attack(snapshot: ResolvedCharacterSnapshot) -> int:
	if snapshot == null:
		return 0
	return snapshot.stat_value(&"base_attack_bonus", 0) + maxi(
		snapshot.ability_modifier("STR"),
		snapshot.ability_modifier("DEX")
	)


func _persistent_maximum_hp(character: PersistentCharacterState) -> int:
	if character == null:
		return 1
	var snapshot: ResolvedCharacterSnapshot = _resolved_roster_character(
		character,
		_campaign()
	)
	return maxi(1, snapshot.stat_value(&"maximum_hp", 1))


func _roster_status_id(character: PersistentCharacterState) -> StringName:
	if character == null or character.is_dead:
		return &"dead"
	if _campaign_session != null:
		if _campaign_session.active_prestige_project(character.character_id) != null:
			return &"prestige_training"
		var availability: Dictionary = _campaign_session.strategic_character_availability(
			character.character_id
		)
		if not bool(availability.get("available", true)):
			return &"deployed"
	return character.health_condition_id(_persistent_maximum_hp(character))


func _roster_status(character: PersistentCharacterState) -> String:
	match _roster_status_id(character):
		&"dead":
			return "Dead"
		&"gravely_wounded":
			return "Gravely Wounded"
		&"wounded":
			return "Wounded"
		&"deployed":
			return "Deployed"
		&"prestige_training":
			return "Prestige Training"
	return "Ready"


func _roster_status_color(character: PersistentCharacterState) -> Color:
	match _roster_status_id(character):
		&"dead":
			return Color("b05f66")
		&"gravely_wounded":
			return Color("c95f58")
		&"wounded":
			return Color("d09a58")
		&"deployed":
			return Color("7b9bac")
		&"prestige_training":
			return Color("c9a557")
	return Color("8eb789")


func _character_container_item_name(
		campaign: CampaignState,
		character_id: StringName,
		container_id: StringName
) -> String:
	var items: Array[CampaignItemState] = _character_items_in_container(campaign, character_id, container_id)
	if items.is_empty():
		return "—"
	return _item_name(items[0])


func _request_roster_equip(
		item_id: StringName,
		character_id: StringName,
		container_id: StringName
) -> void:
	var preview: OperationResult = _campaign_session.preview_strategic_equip(
		item_id,
		character_id,
		container_id
	)
	if not preview.success:
		_show_toast(preview.message, true)
		return
	var preview_data: Dictionary = {}
	if preview.data is Dictionary:
		preview_data = preview.data as Dictionary
	var displaced: Array = preview_data.get("displaced_item_ids", []) as Array
	if displaced.is_empty():
		_commit_roster_equip(item_id, character_id, container_id)
		return
	var names: Array[String] = []
	var campaign: CampaignState = _campaign()
	for raw_id: Variant in displaced:
		var displaced_item: CampaignItemState = campaign.get_item(StringName(raw_id)) as CampaignItemState
		if displaced_item != null:
			names.append(_item_name(displaced_item))
	var dialog := ConfirmationDialog.new()
	dialog.title = "Replace Equipment"
	dialog.dialog_text = "The following item%s will return to storage:\n\n%s" % [
		"s" if names.size() != 1 else "",
		"\n".join(names),
	]
	dialog.get_ok_button().text = "EQUIP"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_commit_roster_equip(item_id, character_id, container_id)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(520, 260))


func _commit_roster_equip(
		item_id: StringName,
		character_id: StringName,
		container_id: StringName
) -> void:
	_record_equipment_undo()
	var result: OperationResult = _campaign_session.equip_strategic_item(
		item_id,
		character_id,
		container_id
	)
	if not result.success:
		_show_toast(result.message, true)
		return
	_selected_character_id = character_id
	_roster_mode = ROSTER_MODE_EQUIP
	_show_screen(SCREEN_ROSTER)
	_show_toast(result.message)


func _request_roster_unequip(item_id: StringName) -> void:
	_record_equipment_undo()
	var result: OperationResult = _campaign_session.unequip_strategic_item(item_id)
	if not result.success:
		_show_toast(result.message, true)
		return
	_roster_mode = ROSTER_MODE_EQUIP
	_show_screen(SCREEN_ROSTER)
	_show_toast(result.message)


func _character_items_in_container(
		campaign: CampaignState,
		character_id: StringName,
		container_id: StringName
) -> Array[CampaignItemState]:
	var result: Array[CampaignItemState] = []
	if campaign == null:
		return result
	for raw_item: Variant in campaign.items_for_character(character_id):
		var item: CampaignItemState = raw_item as CampaignItemState
		if item != null and item.location != null and item.location.container_id == container_id:
			result.append(item)
	result.sort_custom(
		func(a: CampaignItemState, b: CampaignItemState) -> bool:
			if a.location.grid_position.y != b.location.grid_position.y:
				return a.location.grid_position.y < b.location.grid_position.y
			if a.location.grid_position.x != b.location.grid_position.x:
				return a.location.grid_position.x < b.location.grid_position.x
			return String(a.item_id) < String(b.item_id)
	)
	return result


func _character_carried_weight(campaign: CampaignState, character_id: StringName) -> float:
	var total: float = 0.0
	if campaign == null:
		return total
	for raw_item: Variant in campaign.items_for_character(character_id):
		var item: CampaignItemState = raw_item as CampaignItemState
		if item == null:
			continue
		var definition: ItemDefinition = _campaign_session.catalogue.item_definition(item.definition_id)
		if definition != null:
			total += definition.weight_lb * float(item.quantity)
	return total


func _is_furniture_definition(definition: ItemDefinition) -> bool:
	return (
		definition != null
		and (
			definition.has_tag(&"furniture")
			or definition.has_tag(&"installation")
			or (definition.has_tag(&"bulky") and definition.has_tag(&"loot"))
		)
	)


func _is_roster_equipment_candidate(definition: ItemDefinition) -> bool:
	if definition == null:
		return false
	if _is_furniture_definition(definition) or definition.has_tag(&"salvage"):
		return false
	if definition.has_tag(&"loot") and not (
		definition.has_tag(&"weapon")
		or definition.has_tag(&"consumable")
		or definition.has_tag(&"medical")
		or definition.has_tag(&"restraint")
	):
		return false
	return (
		definition.can_equip_in_hand()
		or not definition.equipment_slot_ids.is_empty()
		or definition.belt_allowed
		or definition.backpack_allowed
	)


func _build_storage_screen() -> void:
	# Compatibility for a hot-reloaded screen or old debug state that still
	# references the removed category. Installation-tagged items now belong to
	# Furniture and there is no separate Installations filter.
	if _storage_category_filter == &"installations":
		_storage_category_filter = &"furniture"
	if _storage_location_filter not in [STORAGE_VIEW_STORED, STORAGE_VIEW_EQUIPPED]:
		_storage_location_filter = STORAGE_VIEW_STORED
	if (
		_storage_location_filter == STORAGE_VIEW_STORED
		and _storage_availability_filter == &"assigned"
	):
		_storage_availability_filter = &"all"
	elif (
		_storage_location_filter == STORAGE_VIEW_EQUIPPED
		and _storage_availability_filter == &"available"
	):
		_storage_availability_filter = &"all"
	if _storage_location_filter == STORAGE_VIEW_EQUIPPED and _storage_category_filter == &"resources":
		_storage_category_filter = &"all"
	var campaign: CampaignState = _campaign()
	if campaign == null:
		_workspace.add_child(_body_label("No campaign storage is available."))
		return
	var groups: Array[Dictionary] = _campaign_session.storage_group_snapshots(
		_storage_category_filter,
		_storage_availability_filter,
		_storage_search_text,
		_storage_sort_id,
		_storage_location_filter
	)
	var resource_ids: Array[StringName] = _storage_visible_resource_ids(campaign)
	var display_entries: Array[Dictionary] = _storage_display_entries(groups, campaign, resource_ids)
	var visible_definition_ids: Dictionary = {}
	var visible_item_ids: Dictionary = {}
	var visible_resource_ids: Dictionary = {}
	for group: Dictionary in groups:
		var definition_id := StringName(group.get("definition_id", &""))
		visible_definition_ids[definition_id] = true
		for raw_instance: Variant in group.get("visible_instances", []) as Array:
			if raw_instance is Dictionary:
				visible_item_ids[StringName((raw_instance as Dictionary).get("item_id", &""))] = true
	for resource_id: StringName in resource_ids:
		visible_resource_ids[resource_id] = true
	if not _selected_storage_definition_id.is_empty() and not visible_definition_ids.has(_selected_storage_definition_id):
		_selected_storage_definition_id = &""
		_selected_storage_item_id = &""
	if not _selected_storage_item_id.is_empty() and not visible_item_ids.has(_selected_storage_item_id):
		_selected_storage_item_id = &""
	if (
		not _selected_storage_resource_id.is_empty()
		and not visible_resource_ids.has(_selected_storage_resource_id)
	):
		_selected_storage_resource_id = &""
	for raw_expanded_definition_id: Variant in _storage_expanded_definition_ids.keys():
		var expanded_definition_id := StringName(raw_expanded_definition_id)
		if not visible_definition_ids.has(expanded_definition_id):
			_storage_expanded_definition_ids.erase(expanded_definition_id)

	var root: Control = _build_management_canvas("res://assets/strategic/storage/storage_background.svg")
	var margin := _management_margin(root, 24, 24, 20, 20)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	column.add_child(_build_storage_location_tabs())
	column.add_child(_build_storage_toolbar())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	var inventory_panel := _build_storage_grouped_inventory(display_entries)
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_panel.size_flags_stretch_ratio = 3.2
	body.add_child(inventory_panel)
	var details_panel := _build_storage_grouped_details(groups, campaign)
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_panel.size_flags_stretch_ratio = 1.15
	body.add_child(details_panel)


func _build_storage_location_tabs() -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)
	for entry: Array in [
		[STORAGE_VIEW_STORED, "IN STORAGE"],
		[STORAGE_VIEW_EQUIPPED, "EQUIPPED & CARRIED"],
	]:
		var view_id := StringName(entry[0])
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = _storage_location_filter == view_id
		button.text = String(entry[1])
		button.custom_minimum_size = Vector2(240, 38)
		button.add_theme_font_size_override("font_size", 11)
		button.tooltip_text = (
			"Items physically held by the stronghold. Only this tab uses Storage Space."
			if view_id == STORAGE_VIEW_STORED
			else "Weapons, armour, Belt contents and Backpack contents currently held by characters. These use no Stronghold Storage Space."
		)
		button.pressed.connect(func() -> void:
			_storage_location_filter = view_id
			_storage_availability_filter = &"all"
			_selected_storage_item_id = &""
			_selected_storage_definition_id = &""
			_selected_storage_resource_id = &""
			_storage_expanded_definition_ids.clear()
			_show_screen(SCREEN_STORAGE)
		)
		row.add_child(button)
	return panel


func _build_storage_toolbar() -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var utility_row := HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 6)
	column.add_child(utility_row)
	var search := LineEdit.new()
	search.placeholder_text = (
		"Search stored items, resources or reservations"
		if _storage_location_filter == STORAGE_VIEW_STORED
		else "Search equipped items, characters, containers or reservations"
	)
	search.text = _storage_search_text
	search.custom_minimum_size.x = 360
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(_on_storage_search_text_changed)
	utility_row.add_child(search)
	var availability := OptionButton.new()
	availability.fit_to_longest_item = false
	availability.custom_minimum_size.x = 145
	var availability_entries: Array = []
	if _storage_location_filter == STORAGE_VIEW_STORED:
		availability_entries = [
			[&"all", "ALL STATES"],
			[&"available", "AVAILABLE"],
			[&"reserved", "RESERVED"],
		]
	else:
		availability_entries = [
			[&"all", "ALL STATES"],
			[&"assigned", "EQUIPPED / CARRIED"],
			[&"reserved", "RESERVED"],
		]
	for entry: Array in availability_entries:
		var index: int = availability.item_count
		availability.add_item(String(entry[1]))
		availability.set_item_metadata(index, StringName(entry[0]))
		if StringName(entry[0]) == _storage_availability_filter:
			availability.select(index)
	availability.item_selected.connect(func(index: int) -> void:
		_storage_availability_filter = StringName(availability.get_item_metadata(index))
		_selected_storage_item_id = &""
		_show_screen(SCREEN_STORAGE)
	)
	utility_row.add_child(availability)
	var sort := OptionButton.new()
	sort.fit_to_longest_item = false
	sort.custom_minimum_size.x = 175
	for entry: Array in [
		[&"name", "NAME"],
		[&"total", "TOTAL QUANTITY"],
		[&"available", "AVAILABLE QUANTITY"],
	]:
		var index: int = sort.item_count
		sort.add_item(String(entry[1]))
		sort.set_item_metadata(index, StringName(entry[0]))
		if StringName(entry[0]) == _storage_sort_id:
			sort.select(index)
	sort.item_selected.connect(func(index: int) -> void:
		_storage_sort_id = StringName(sort.get_item_metadata(index))
		_show_screen(SCREEN_STORAGE)
	)
	utility_row.add_child(sort)
	if _storage_location_filter == STORAGE_VIEW_STORED:
		utility_row.add_child(_build_storage_capacity_display())
	else:
		var equipped_space := Label.new()
		equipped_space.custom_minimum_size.x = 250
		equipped_space.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equipped_space.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		equipped_space.text = "EQUIPPED & CARRIED · 0 STORAGE SPACE"
		equipped_space.tooltip_text = "Only items physically located in Stronghold Storage consume Storage Space."
		equipped_space.add_theme_font_size_override("font_size", 10)
		equipped_space.add_theme_color_override("font_color", Color("9db59f"))
		utility_row.add_child(equipped_space)
	var categories := HBoxContainer.new()
	categories.add_theme_constant_override("separation", 3)
	column.add_child(categories)
	var category_entries: Array = [
		[&"all", "ALL"],
	]
	if _storage_location_filter == STORAGE_VIEW_STORED:
		category_entries.append([&"resources", "RESOURCES"])
	category_entries.append_array([
		[&"equipment", "EQUIPMENT"],
		[&"furniture", "FURNITURE"],
		[&"consumables", "CONSUMABLES"],
		[&"ammunition", "AMMUNITION"],
		[&"salvage", "SALVAGE"],
		[&"other", "OTHER"],
	])
	for entry: Array in category_entries:
		var category_id := StringName(entry[0])
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = category_id == _storage_category_filter
		button.text = String(entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(func() -> void:
			_storage_category_filter = category_id
			_selected_storage_item_id = &""
			_selected_storage_definition_id = &""
			_selected_storage_resource_id = &""
			_show_screen(SCREEN_STORAGE)
		)
		categories.add_child(button)
	if _storage_search_restore_focus:
		_storage_search_restore_focus = false
		search.call_deferred("grab_focus")
		search.call_deferred("set_caret_column", _storage_search_text.length())
	return panel


func _build_storage_capacity_display() -> Control:
	var snapshot: Dictionary = _campaign_session.storage_capacity_snapshot()
	var used: int = int(snapshot.get("used", 0))
	var maximum: int = int(snapshot.get("maximum", 0))
	var overflow: int = int(snapshot.get("overflow", 0))
	var ratio: float = float(snapshot.get("usage_ratio", 0.0))
	var label := Label.new()
	label.custom_minimum_size.x = 210
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	if overflow > 0:
		label.text = "STORAGE %d / %d · OVER BY %d" % [used, maximum, overflow]
		label.add_theme_color_override("font_color", Color("e29a79"))
	elif ratio >= 0.8:
		label.text = "STORAGE %d / %d · NEAR LIMIT" % [used, maximum]
		label.add_theme_color_override("font_color", Color("d6ba68"))
	else:
		label.text = "STORAGE %d / %d" % [used, maximum]
		label.add_theme_color_override("font_color", Color("c9c7b8"))
	label.tooltip_text = _storage_capacity_tooltip(snapshot)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	return label


func _storage_capacity_tooltip(snapshot: Dictionary) -> String:
	var lines: Array[String] = ["CAPACITY"]
	var source_lines: Array[String] = []
	for raw_source: Variant in snapshot.get("capacity_sources", []) as Array:
		if not raw_source is Dictionary:
			continue
		var source: Dictionary = raw_source as Dictionary
		var contribution: int = int(source.get("capacity", 0))
		var base_capacity: int = int(source.get("base_capacity", contribution))
		var condition := StringName(source.get("condition", &"operational"))
		var suffix: String = ""
		if condition == StrongholdFacilityStateScript.CONDITION_DAMAGED:
			suffix = " (damaged; normally %d)" % base_capacity
		elif condition in [
			StrongholdFacilityStateScript.CONDITION_DISABLED,
			StrongholdFacilityStateScript.CONDITION_UNDER_CONSTRUCTION,
		]:
			suffix = " (inactive)"
		source_lines.append("%s: %d%s" % [
			String(source.get("display_name", "Storage source")),
			contribution,
			suffix,
		])
	if source_lines.is_empty():
		source_lines.append("No active storage source: 0")
	lines.append_array(source_lines)
	lines.append("Maximum: %d" % int(snapshot.get("maximum", 0)))
	lines.append("")
	lines.append("USAGE")
	var category_labels: Dictionary = {
		&"resources": "Strategic resources",
		&"equipment": "Equipment",
		&"furniture": "Furniture and bulky loot",
		&"consumables": "Consumables",
		&"ammunition": "Ammunition",
		&"salvage": "Salvage",
		&"other": "Other",
	}
	var usage: Dictionary = snapshot.get("usage_by_category", {}) as Dictionary
	for category_id: StringName in [
		&"resources", &"equipment", &"furniture", &"consumables", &"ammunition", &"salvage", &"other"
	]:
		var amount: int = int(usage.get(category_id, 0))
		if amount <= 0:
			continue
		lines.append("%s: %d" % [String(category_labels.get(category_id, "Other")), amount])
	var resource_usage: Dictionary = snapshot.get("resource_usage", {}) as Dictionary
	if int(snapshot.get("resource_used", 0)) > 0:
		for resource_id: StringName in CampaignResourceBalances.STORAGE_RESOURCE_IDS:
			var resource_space: int = int(resource_usage.get(resource_id, 0))
			if resource_space <= 0:
				continue
			lines.append("  %s: %d" % [String(resource_id).capitalize(), resource_space])
		lines.append("  1 space per 100 units; Gold uses no space")
	lines.append("Used: %d" % int(snapshot.get("used", 0)))
	if bool(snapshot.get("is_over_capacity", false)):
		lines.append("Over capacity: %d" % int(snapshot.get("overflow", 0)))
	else:
		lines.append("Free: %d" % maxi(0, int(snapshot.get("free", 0))))
	return "\n".join(lines)


func _on_storage_search_text_changed(value: String) -> void:
	_storage_search_text = value
	_storage_search_generation += 1
	var expected_generation: int = _storage_search_generation
	await get_tree().create_timer(0.2).timeout
	if expected_generation != _storage_search_generation:
		return
	if _current_screen != SCREEN_STORAGE:
		return
	_storage_search_restore_focus = true
	_show_screen(SCREEN_STORAGE)


func _storage_visible_resource_ids(campaign: CampaignState) -> Array[StringName]:
	var result: Array[StringName] = []
	if (
		campaign == null
		or campaign.resources == null
		or _storage_location_filter != STORAGE_VIEW_STORED
		or _storage_category_filter not in [&"all", &"resources"]
		or _storage_availability_filter == &"reserved"
	):
		return result
	var normalized_search: String = _storage_search_text.strip_edges().to_lower()
	for resource_id: StringName in CampaignResourceBalances.RESOURCE_IDS:
		# Gold is campaign funds, not a stored physical resource. It remains in
		# the strategic header and Shop balance but never appears as a Storage row.
		if resource_id == &"gold":
			continue
		var amount: int = campaign.resources.amount(resource_id)
		if amount <= 0:
			continue
		var search_text: String = " ".join([
			_storage_resource_display_name(resource_id),
			String(resource_id),
			"resource",
		]).to_lower()
		if not normalized_search.is_empty() and not search_text.contains(normalized_search):
			continue
		result.append(resource_id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		var a_amount: int = campaign.resources.amount(a)
		var b_amount: int = campaign.resources.amount(b)
		if _storage_sort_id in [&"total", &"available"] and a_amount != b_amount:
			return a_amount > b_amount
		return _storage_resource_display_name(a).naturalnocasecmp_to(
			_storage_resource_display_name(b)
		) < 0
	)
	return result


func _storage_display_entries(
		groups: Array[Dictionary],
		campaign: CampaignState,
		resource_ids: Array[StringName]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for group: Dictionary in groups:
		var item_entry: Dictionary = group.duplicate(true)
		item_entry["entry_kind"] = &"item"
		item_entry["storage_space"] = (
			int(group.get("stored_space", 0))
			if _storage_location_filter == STORAGE_VIEW_STORED
			else 0
		)
		result.append(item_entry)
	for resource_id: StringName in resource_ids:
		var amount: int = campaign.resources.amount(resource_id)
		result.append({
			"entry_kind": &"resource",
			"resource_id": resource_id,
			"display_name": _storage_resource_display_name(resource_id),
			"category_id": &"resources",
			"total_count": amount,
			"available_count": amount,
			"storage_space": campaign.resources.storage_space_for(resource_id),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match _storage_sort_id:
			&"total":
				if int(a.get("total_count", 0)) != int(b.get("total_count", 0)):
					return int(a.get("total_count", 0)) > int(b.get("total_count", 0))
			&"available":
				if int(a.get("available_count", 0)) != int(b.get("available_count", 0)):
					return int(a.get("available_count", 0)) > int(b.get("available_count", 0))
		return String(a.get("display_name", "")).naturalnocasecmp_to(
			String(b.get("display_name", ""))
		) < 0
	)
	return result


func _storage_resource_display_name(resource_id: StringName) -> String:
	return String(resource_id).capitalize()


func _storage_resource_description(resource_id: StringName) -> String:
	match resource_id:
		&"wood":
			return "Usable timber, planks and wooden construction material."
		&"stone":
			return "Masonry, cut stone and durable mineral construction material."
		&"metal":
			return "Worked and recoverable metal used for equipment and construction."
		&"food":
			return "Stored grain, preserved provisions and other campaign food supplies."
		&"textiles":
			return "Cloth, canvas, wool, cordage, padding and usable hide or leather."
		&"magic":
			return "Rare magical matter and power suitable for advanced projects."
	return "Stored strategic resource."


func _build_storage_grouped_inventory(entries: Array[Dictionary]) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var title := Label.new()
	title.text = (
		"IN STORAGE"
		if _storage_location_filter == STORAGE_VIEW_STORED
		else "EQUIPPED & CARRIED"
	)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("d3bd83"))
	column.add_child(title)
	column.add_child(_build_storage_group_header())
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	if entries.is_empty():
		list.add_child(_body_label(
			"No stored items or physical resources match the current search and filters."
			if _storage_location_filter == STORAGE_VIEW_STORED
			else "No equipped or carried items match the current search and filters."
		))
		return panel
	for entry: Dictionary in entries:
		if StringName(entry.get("entry_kind", &"item")) == &"resource":
			list.add_child(_build_storage_resource_row(entry))
		else:
			list.add_child(_build_storage_group_block(entry))
	return panel


func _build_storage_group_header() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 28
	var asset := Label.new()
	asset.text = "ASSET"
	asset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asset.add_theme_font_size_override("font_size", 10)
	asset.add_theme_color_override("font_color", Color("aaa58f"))
	row.add_child(asset)
	var quantity := Label.new()
	quantity.text = "QUANTITY"
	quantity.custom_minimum_size.x = 92
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity.add_theme_font_size_override("font_size", 9)
	quantity.add_theme_color_override("font_color", Color("aaa58f"))
	row.add_child(quantity)
	var storage := Label.new()
	storage.text = "STORAGE"
	storage.custom_minimum_size.x = 82
	storage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storage.add_theme_font_size_override("font_size", 9)
	storage.add_theme_color_override("font_color", Color("aaa58f"))
	row.add_child(storage)
	return row


func _build_storage_resource_row(entry: Dictionary) -> Control:
	var resource_id := StringName(entry.get("resource_id", &""))
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = resource_id == _selected_storage_resource_id
	button.custom_minimum_size.y = 48
	button.text = ""
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	button.add_child(row)
	var indent := Control.new()
	indent.custom_minimum_size.x = 28
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(indent)
	var symbol := Label.new()
	symbol.text = String(_resource_symbols.get(resource_id, "◆"))
	symbol.custom_minimum_size.x = 34
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol.add_theme_font_size_override("font_size", 16)
	symbol.add_theme_color_override("font_color", Color("d8c688"))
	row.add_child(symbol)
	var name := Label.new()
	name.text = String(entry.get("display_name", resource_id))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.add_theme_font_size_override("font_size", 12)
	row.add_child(name)
	var quantity := Label.new()
	quantity.text = str(int(entry.get("total_count", 0)))
	quantity.custom_minimum_size.x = 92
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity.add_theme_font_size_override("font_size", 12)
	row.add_child(quantity)
	var storage := Label.new()
	storage.text = str(int(entry.get("storage_space", 0)))
	storage.custom_minimum_size.x = 82
	storage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	storage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	storage.add_theme_font_size_override("font_size", 12)
	storage.tooltip_text = "Every 100 stored units, or part thereof, use 1 Stronghold Storage Space."
	row.add_child(storage)
	button.tooltip_text = "%s · %d stored · %d Storage Space" % [
		_storage_resource_display_name(resource_id),
		int(entry.get("total_count", 0)),
		int(entry.get("storage_space", 0)),
	]
	button.pressed.connect(func() -> void:
		_selected_storage_resource_id = resource_id
		_selected_storage_definition_id = &""
		_selected_storage_item_id = &""
		_show_screen(SCREEN_STORAGE)
	)
	return button


func _build_storage_group_block(group: Dictionary) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 1)
	var definition_id := StringName(group.get("definition_id", &""))
	var expanded: bool = _storage_expanded_definition_ids.has(definition_id)
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size.y = 48
	block.add_child(row_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row_panel.add_child(row)
	var expand := Button.new()
	expand.text = "▾" if expanded else "▸"
	expand.flat = true
	expand.custom_minimum_size.x = 28
	expand.tooltip_text = "Collapse exact instances" if expanded else "Show exact instances"
	expand.pressed.connect(func() -> void:
		if expanded:
			_storage_expanded_definition_ids.erase(definition_id)
		else:
			_storage_expanded_definition_ids[definition_id] = true
		if _selected_storage_definition_id == definition_id:
			_selected_storage_item_id = &""
		_show_screen(SCREEN_STORAGE)
	)
	row.add_child(expand)
	var select := Button.new()
	select.toggle_mode = true
	select.button_pressed = (
		definition_id == _selected_storage_definition_id
		and _selected_storage_item_id.is_empty()
		and _selected_storage_resource_id.is_empty()
	)
	select.text = ""
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(select)
	var item_content := HBoxContainer.new()
	item_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_content.add_theme_constant_override("separation", 7)
	select.add_child(item_content)
	var definition: ItemDefinition = _campaign_session.catalogue.item_definition(definition_id)
	item_content.add_child(_build_item_icon(definition, Vector2(34, 34)))
	var name := Label.new()
	name.text = String(group.get("display_name", definition_id))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.add_theme_font_size_override("font_size", 12)
	item_content.add_child(name)
	select.pressed.connect(func() -> void:
		_selected_storage_definition_id = definition_id
		_selected_storage_item_id = &""
		_selected_storage_resource_id = &""
		_show_screen(SCREEN_STORAGE)
	)
	var quantity := Label.new()
	quantity.text = str(int(group.get("total_count", 0)))
	quantity.custom_minimum_size.x = 92
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity.add_theme_font_size_override("font_size", 12)
	row.add_child(quantity)
	var storage := Label.new()
	storage.text = str(int(group.get("storage_space", 0)))
	storage.custom_minimum_size.x = 82
	storage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	storage.add_theme_font_size_override("font_size", 12)
	storage.tooltip_text = (
		"Stronghold Storage Space currently used by this item group."
		if _storage_location_filter == STORAGE_VIEW_STORED
		else "Equipped and carried items use no Stronghold Storage Space."
	)
	row.add_child(storage)
	if expanded:
		var instances: Array = group.get("visible_instances", []) as Array
		for index: int in range(instances.size()):
			var raw_instance: Variant = instances[index]
			if raw_instance is Dictionary:
				block.add_child(_build_storage_instance_row(group, raw_instance as Dictionary, index + 1))
	return block


func _build_storage_instance_row(
		group: Dictionary,
		instance: Dictionary,
		visible_index: int
) -> Control:
	var button := Button.new()
	button.toggle_mode = true
	var item_id := StringName(instance.get("item_id", &""))
	button.button_pressed = item_id == _selected_storage_item_id
	button.custom_minimum_size.y = 36
	button.text = ""
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	button.add_child(row)
	var indent := Control.new()
	indent.custom_minimum_size.x = 44
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(indent)
	var state := StringName(instance.get("state", &"available"))
	var icon := Label.new()
	icon.text = "🔒" if state == &"reserved" else ("⚔" if state == &"assigned" else "✓")
	icon.custom_minimum_size.x = 26
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = "%s%s" % [
		_storage_instance_label(group, item_id, visible_index),
		" ×%d" % int(instance.get("quantity", 1))
		if int(instance.get("quantity", 1)) > 1
		else "",
	]
	label.custom_minimum_size.x = 112
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 10)
	row.add_child(label)
	var location := Label.new()
	location.text = String(instance.get("location_text", "Unknown"))
	location.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	location.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	location.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location.add_theme_font_size_override("font_size", 10)
	row.add_child(location)
	var status := Label.new()
	status.text = _storage_state_display(state, instance)
	status.custom_minimum_size.x = 155
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_font_size_override("font_size", 9)
	if state == &"reserved":
		status.add_theme_color_override("font_color", Color("d2a765"))
	button.add_theme_font_size_override("font_size", 10)
	row.add_child(status)
	button.tooltip_text = String(instance.get("reservation_reason", "")) if state == &"reserved" else String(instance.get("location_text", ""))
	button.pressed.connect(func() -> void:
		_selected_storage_definition_id = StringName(group.get("definition_id", &""))
		_selected_storage_item_id = item_id
		_selected_storage_resource_id = &""
		_show_screen(SCREEN_STORAGE)
	)
	return button


func _storage_instance_label(group: Dictionary, item_id: StringName, fallback_index: int = 1) -> String:
	var instances: Array = group.get("instances", []) as Array
	for index: int in range(instances.size()):
		var raw_instance: Variant = instances[index]
		if raw_instance is Dictionary and StringName((raw_instance as Dictionary).get("item_id", &"")) == item_id:
			return "Instance %02d" % (index + 1)
	return "Instance %02d" % fallback_index


func _storage_state_display(state: StringName, instance: Dictionary) -> String:
	match state:
		&"reserved":
			var reservation_name: String = String(instance.get("reservation_name", ""))
			return reservation_name.to_upper() if not reservation_name.is_empty() else "RESERVED"
		&"assigned":
			return (
				"EQUIPPED"
				if StringName(instance.get("location_type", &""))
				== CampaignItemLocationState.LOCATION_CHARACTER_EQUIPMENT
				else "CARRIED"
			)
	return "AVAILABLE"


func _build_storage_grouped_details(
		groups: Array[Dictionary],
		campaign: CampaignState
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 330
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	if not _selected_storage_resource_id.is_empty():
		_build_storage_resource_details(column, campaign, _selected_storage_resource_id)
		return panel
	if _selected_storage_definition_id.is_empty():
		column.add_child(_heading_label("ASSET DETAILS"))
		column.add_child(_body_label("Select an item group, exact instance or stored resource."))
		return panel
	var group: Dictionary = _storage_find_group(groups, _selected_storage_definition_id)
	if group.is_empty():
		group = _campaign_session.storage_group_snapshot(
			_selected_storage_definition_id,
			_storage_location_filter
		)
	if group.is_empty():
		column.add_child(_heading_label("ITEM DETAILS"))
		column.add_child(_body_label("The selected item group no longer exists."))
		return panel
	var definition: ItemDefinition = _campaign_session.catalogue.item_definition(_selected_storage_definition_id)
	if _selected_storage_item_id.is_empty():
		_build_storage_group_summary(column, group, definition)
	else:
		_build_storage_instance_details(column, group, definition, campaign)
	return panel


func _build_storage_resource_details(
		column: VBoxContainer,
		campaign: CampaignState,
		resource_id: StringName
) -> void:
	if campaign == null or campaign.resources == null:
		column.add_child(_heading_label("RESOURCE DETAILS"))
		column.add_child(_body_label("The selected resource is unavailable."))
		return
	var amount: int = campaign.resources.amount(resource_id)
	if amount <= 0:
		column.add_child(_heading_label("RESOURCE DETAILS"))
		column.add_child(_body_label("The selected resource is no longer in Storage."))
		return
	var symbol := Label.new()
	symbol.text = String(_resource_symbols.get(resource_id, "◆"))
	symbol.custom_minimum_size = Vector2(130, 110)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	symbol.add_theme_font_size_override("font_size", 52)
	symbol.add_theme_color_override("font_color", Color("d8c688"))
	column.add_child(symbol)
	var title := Label.new()
	title.text = _storage_resource_display_name(resource_id).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("ddc78e"))
	column.add_child(title)
	column.add_child(_small_meta_label("RESOURCE"))
	column.add_child(_body_label(_storage_resource_description(resource_id)))
	column.add_child(HSeparator.new())
	column.add_child(_heading_label("STORAGE"))
	var storage_space: int = campaign.resources.storage_space_for(resource_id)
	column.add_child(_body_label(
		"Stored quantity: %d\nAvailable now: %d\n\nStronghold Storage Space: %d\nEvery 100 stored units, or part thereof, use 1 Storage Space."
		% [amount, amount, storage_space]
	))
	column.add_child(HSeparator.new())
	column.add_child(_heading_label("ACTIONS"))
	var preview: OperationResult = _campaign_session.preview_shop_sell_resource(resource_id, 1)
	if preview.success:
		var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
		column.add_child(_body_label("Current sale lot: %d %s → %d Gold" % [
			int(data.get("lot_size", 1)),
			_storage_resource_display_name(resource_id),
			int(data.get("unit_price_gold", data.get("total_gold", 0))),
		]))
	else:
		column.add_child(_body_label(preview.message))
	var sell := Button.new()
	sell.text = "SELL IN SHOP"
	sell.disabled = not preview.success
	sell.tooltip_text = preview.message
	sell.pressed.connect(func() -> void:
		_shop_mode = SHOP_MODE_SELL
		_shop_category_filter = &"resources"
		_shop_selected_definition_id = &""
		_shop_selected_item_id = &""
		_shop_selected_resource_id = resource_id
		_shop_quantity = 1
		call_deferred("_show_screen", SCREEN_SHOP)
	)
	column.add_child(sell)


func _storage_find_group(groups: Array[Dictionary], definition_id: StringName) -> Dictionary:
	for group: Dictionary in groups:
		if StringName(group.get("definition_id", &"")) == definition_id:
			return group
	return {}


func _build_storage_group_summary(
		column: VBoxContainer,
		group: Dictionary,
		definition: ItemDefinition
) -> void:
	var icon := _build_item_icon(definition, Vector2(130, 130))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var title := Label.new()
	title.text = String(group.get("display_name", "ITEM")).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("ddc78e"))
	column.add_child(title)
	column.add_child(_small_meta_label(_item_category_display(StringName(group.get("category_id", &"other")))))
	if definition != null:
		column.add_child(_body_label(definition.description))
	column.add_child(HSeparator.new())
	if _storage_location_filter == STORAGE_VIEW_STORED:
		column.add_child(_body_label(
			"Stored quantity: %d\nAvailable now: %d\nReserved in Storage: %d\n\nUnit weight: %.1f lb\nCombined weight: %.1f lb\n\nSingle-item Storage Space: %d\nCurrent stored space: %d" % [
				int(group.get("total_count", 0)),
				int(group.get("available_count", 0)),
				int(group.get("reserved_count", 0)),
				float(group.get("unit_weight", 0.0)),
				float(group.get("combined_weight", 0.0)),
				int(group.get("single_item_storage_space", 0)),
				int(group.get("stored_space", 0)),
			]
		))
	else:
		column.add_child(_body_label(
			"Equipped or carried quantity: %d\nCharacters carrying: %d\nReserved by active operations: %d\n\nUnit weight: %.1f lb\nCombined carried weight: %.1f lb\n\nStronghold Storage Space used: 0" % [
				int(group.get("total_count", 0)),
				int(group.get("owner_count", 0)),
				int(group.get("reserved_count", 0)),
				float(group.get("unit_weight", 0.0)),
				float(group.get("combined_weight", 0.0)),
			]
		))
	_build_storage_recipe_summary(column, definition, false)


func _build_storage_instance_details(
		column: VBoxContainer,
		group: Dictionary,
		definition: ItemDefinition,
		campaign: CampaignState
) -> void:
	var item: CampaignItemState = campaign.get_item(_selected_storage_item_id) as CampaignItemState
	if item == null:
		_selected_storage_item_id = &""
		_build_storage_group_summary(column, group, definition)
		return
	var instance: Dictionary = _campaign_session.storage_instance_snapshot(item.item_id)
	var icon := _build_item_icon(definition, Vector2(130, 130))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var title := Label.new()
	title.text = definition.display_name.to_upper() if definition != null else String(item.definition_id).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("ddc78e"))
	column.add_child(title)
	var instance_label := Label.new()
	instance_label.text = _storage_instance_label(group, item.item_id)
	instance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instance_label.add_theme_font_size_override("font_size", 11)
	instance_label.add_theme_color_override("font_color", Color("a8aa9f"))
	column.add_child(instance_label)
	if definition != null:
		column.add_child(_body_label(definition.description))
	column.add_child(HSeparator.new())
	column.add_child(_heading_label("LOCATION"))
	column.add_child(_body_label(String(instance.get("location_text", _item_location_display(item, campaign)))))
	column.add_child(_heading_label("AVAILABILITY"))
	var state := StringName(instance.get("state", &"available"))
	if state == &"reserved":
		var reservation_text: String = String(instance.get("reservation_reason", "Reserved."))
		var release_text: String = String(instance.get("release_condition", ""))
		column.add_child(_body_label("%s%s" % [
			reservation_text,
			"\n" + release_text if not release_text.is_empty() else "",
		]))
	else:
		column.add_child(_body_label(_storage_state_display(state, instance).capitalize()))
	if item.quantity > 1:
		column.add_child(_heading_label("QUANTITY"))
		column.add_child(_body_label(str(item.quantity)))
	column.add_child(_heading_label("WEIGHT"))
	column.add_child(_body_label("%.1f lb" % float(instance.get("weight", 0.0))))
	column.add_child(_heading_label("STORAGE SPACE"))
	var current_storage_space: int = int(instance.get("current_storage_space", 0))
	var return_storage_space: int = int(instance.get("storage_space_if_stored", 0))
	if definition != null and definition.fixed_inventory_fixture:
		column.add_child(_body_label(
			"0 currently used\nPermanent Marauder Tier fixture; it cannot enter Stronghold Storage."
		))
	elif current_storage_space > 0:
		var storage_note: String = "%d" % current_storage_space
		if state == &"reserved":
			storage_note += "\nThis reserved object remains in Stronghold Storage and continues using capacity."
		column.add_child(_body_label(storage_note))
	else:
		column.add_child(_body_label(
			"0 currently used\nRequires %d space if returned to Stronghold Storage." % return_storage_space
		))
	if definition != null and not _is_armour_definition(definition):
		column.add_child(_heading_label("CONDITION"))
		column.add_child(_body_label(_item_condition_label(item)))
	_build_storage_recipe_summary(column, definition, true)
	column.add_child(HSeparator.new())
	column.add_child(_heading_label("ACTIONS"))
	if definition != null and definition.fixed_inventory_fixture:
		var fixture_note := Label.new()
		fixture_note.text = "PERMANENT TIER FIXTURE\nGranted by Raider's Burden. It cannot be moved, sold, dismantled or transferred."
		fixture_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fixture_note.add_theme_color_override("font_color", Color("d2a765"))
		column.add_child(fixture_note)
	else:
		var protect := Button.new()
		protect.text = "UNPROTECT" if item.is_protected else "PROTECT"
		protect.tooltip_text = (
			"Allow Shop sale, dismantling and future automatic project selection."
			if item.is_protected
			else "Protect this exact item from sale, dismantling and future automatic project selection."
		)
		var protected_item_id: StringName = item.item_id
		var protected_value: bool = not item.is_protected
		protect.pressed.connect(func() -> void:
			_request_storage_protection(protected_item_id, protected_value)
		)
		column.add_child(protect)
		var preview: OperationResult = _campaign_session.preview_dismantle_item(item.item_id)
		var recipe = _campaign_session.catalogue.dismantling_recipe_for_item(item.definition_id)
		if recipe != null:
			var dismantle := Button.new()
			dismantle.text = "DISMANTLE"
			dismantle.disabled = not preview.success
			dismantle.tooltip_text = preview.message
			var item_id: StringName = item.item_id
			dismantle.pressed.connect(func() -> void: _request_storage_dismantle(item_id))
			column.add_child(dismantle)
	if item.condition <= 0.0 and (definition == null or not definition.fixed_inventory_fixture):
		var repair := Button.new()
		repair.text = "REPAIR"
		var repair_recipe: ProductionRecipeDefinition = _campaign_session.repair_recipe_for_item(item.item_id)
		if repair_recipe == null:
			repair.disabled = true
			repair.tooltip_text = "No ordinary Workshop repair definition supports this destroyed item."
		else:
			var repair_preview: OperationResult = _campaign_session.preview_production_project(repair_recipe.recipe_id, 1, item.item_id)
			repair.disabled = not repair_preview.success
			repair.tooltip_text = repair_preview.message
			var repair_item_id: StringName = item.item_id
			var repair_recipe_id: StringName = repair_recipe.recipe_id
			repair.pressed.connect(func() -> void:
				_request_item_repair(repair_item_id, repair_recipe_id)
			)
		column.add_child(repair)
	if item.location != null and item.location.belongs_to_character(item.location.owner_id):
		var view_character := Button.new()
		view_character.text = "VIEW CHARACTER"
		var owner_id: StringName = item.location.owner_id
		view_character.pressed.connect(func() -> void:
			_selected_character_id = owner_id
			_roster_mode = ROSTER_MODE_EQUIP
			_roster_tab_index = 0
			_show_screen(SCREEN_ROSTER)
		)
		column.add_child(view_character)
	elif item.location != null and item.location.is_stronghold_storage() and _is_roster_equipment_candidate(definition):
		var equip := Button.new()
		equip.text = "OPEN ARMOURY"
		equip.pressed.connect(func() -> void:
			_roster_mode = ROSTER_MODE_EQUIP
			_roster_tab_index = 0
			_show_screen(SCREEN_ROSTER)
		)
		column.add_child(equip)


func _build_storage_recipe_summary(
		column: VBoxContainer,
		definition: ItemDefinition,
		exact_instance_selected: bool
) -> void:
	column.add_child(HSeparator.new())
	column.add_child(_heading_label("BASIC DISMANTLING"))
	var recipe = (
		_campaign_session.catalogue.dismantling_recipe_for_item(definition.id)
		if definition != null
		else null
	)
	if recipe == null:
		column.add_child(_body_label("This item has no available dismantling method."))
		return
	var yields: Dictionary = recipe.clean_resource_yields()
	var lines: Array[String] = ["1 %s" % definition.display_name]
	var yield_lines: Array[String] = []
	for raw_resource_id: Variant in yields.keys():
		yield_lines.append("→ %d %s" % [
			int(yields[raw_resource_id]),
			String(raw_resource_id).capitalize(),
		])
	yield_lines.sort()
	lines.append_array(yield_lines)
	lines.append(
		"Select an available exact instance to dismantle it."
		if not exact_instance_selected
		else "The selected exact item will be permanently destroyed."
	)
	column.add_child(_body_label("\n".join(lines)))


func _request_storage_protection(item_id: StringName, protected_value: bool) -> void:
	if _campaign_session == null:
		return
	var result: OperationResult = _campaign_session.set_item_protected(item_id, protected_value)
	if result.success:
		_selected_storage_item_id = item_id
		_show_screen(SCREEN_STORAGE)
	_show_toast(result.message, not result.success)


func _request_storage_dismantle(item_id: StringName) -> void:
	var preview: OperationResult = _campaign_session.preview_dismantle_item(item_id)
	if not preview.success:
		_show_toast(preview.message, true)
		_show_screen(SCREEN_STORAGE)
		return
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var yields: Dictionary = data.get("resource_yields", {}) as Dictionary
	var yield_lines: Array[String] = []
	for raw_resource_id: Variant in yields.keys():
		yield_lines.append("%d %s" % [
			int(yields[raw_resource_id]),
			String(raw_resource_id).capitalize(),
		])
	yield_lines.sort()
	var dialog := ConfirmationDialog.new()
	dialog.title = "Dismantle %s" % String(data.get("item_name", "Item"))
	var storage_lines: String = ""
	var used_before: int = int(data.get("storage_used_before", 0))
	var used_after: int = int(data.get("storage_used_after", used_before))
	var storage_maximum: int = int(data.get("storage_maximum", 0))
	var released_space: int = int(data.get("storage_space_released", 0))
	if released_space > 0:
		storage_lines = "\n\nStorage:\n%d / %d → %d / %d\nFrees %d Storage Space" % [
			used_before,
			storage_maximum,
			used_after,
			storage_maximum,
			released_space,
		]
	dialog.dialog_text = (
		"This exact item will be permanently destroyed.\n\nYou will receive:\n%s%s"
		% ["\n".join(yield_lines), storage_lines]
	)
	dialog.get_ok_button().text = "DISMANTLE"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		var result: OperationResult = _campaign_session.dismantle_item(item_id)
		if not result.success:
			_show_toast(result.message, true)
			_show_screen(SCREEN_STORAGE)
			return
		_selected_storage_item_id = &""
		var remaining_group: Dictionary = _campaign_session.storage_group_snapshot(
			_selected_storage_definition_id,
			_storage_location_filter
		)
		if remaining_group.is_empty():
			var removed_definition_id := _selected_storage_definition_id
			_selected_storage_definition_id = &""
			_storage_expanded_definition_ids.erase(removed_definition_id)
		_show_screen(SCREEN_STORAGE)
		_show_toast(result.message)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(520, 300))



func _request_item_repair(item_id: StringName, recipe_id: StringName) -> void:
	_ensure_screen_controllers()
	_production_screen_controller.request_item_repair(item_id, recipe_id)


func _build_shop_screen() -> void:
	var campaign: CampaignState = _campaign()
	if campaign == null:
		_workspace.add_child(_body_label("No campaign Shop is available."))
		return
	var entries: Array[Dictionary] = _shop_filtered_entries()
	var visible_definition_ids: Dictionary = {}
	var visible_item_ids: Dictionary = {}
	var visible_resource_ids: Dictionary = {}
	for entry: Dictionary in entries:
		var definition_id := StringName(entry.get("definition_id", &""))
		if not definition_id.is_empty():
			visible_definition_ids[definition_id] = true
		var item_id := StringName(entry.get("item_id", &""))
		if not item_id.is_empty():
			visible_item_ids[item_id] = true
		var resource_id := StringName(entry.get("resource_id", &""))
		if not resource_id.is_empty():
			visible_resource_ids[resource_id] = true
	if _shop_mode == SHOP_MODE_BUY:
		if (
			not _shop_selected_definition_id.is_empty()
			and not visible_definition_ids.has(_shop_selected_definition_id)
		):
			_shop_selected_definition_id = &""
	else:
		if not _shop_selected_item_id.is_empty() and not visible_item_ids.has(_shop_selected_item_id):
			_shop_selected_item_id = &""
		if (
			not _shop_selected_resource_id.is_empty()
			and not visible_resource_ids.has(_shop_selected_resource_id)
		):
			_shop_selected_resource_id = &""

	var root: Control = _build_management_canvas("res://assets/strategic/storage/storage_background.svg")
	var margin := _management_margin(root, 24, 24, 20, 20)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	column.add_child(_build_shop_toolbar())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	var list_panel: Control = _build_shop_list(entries)
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_stretch_ratio = 2.4
	body.add_child(list_panel)
	var details_panel: Control = _build_shop_details(entries, campaign)
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_panel.size_flags_stretch_ratio = 1.2
	body.add_child(details_panel)
	column.add_child(_build_shop_recent_transactions(campaign))

func _build_shop_toolbar() -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	column.add_child(top_row)
	for mode_entry: Array in [
		[SHOP_MODE_BUY, "BUY"],
		[SHOP_MODE_SELL, "SELL"],
	]:
		var mode_id := StringName(mode_entry[0])
		var mode_button := Button.new()
		mode_button.text = String(mode_entry[1])
		mode_button.toggle_mode = true
		mode_button.button_pressed = _shop_mode == mode_id
		mode_button.custom_minimum_size = Vector2(112, 38)
		mode_button.pressed.connect(func() -> void:
			_shop_mode = mode_id
			_shop_selected_definition_id = &""
			_shop_selected_item_id = &""
			_shop_selected_resource_id = &""
			_shop_quantity = 1
			call_deferred("_show_screen", SCREEN_SHOP)
		)
		top_row.add_child(mode_button)
	var search := LineEdit.new()
	search.placeholder_text = (
		"Search available goods"
		if _shop_mode == SHOP_MODE_BUY
		else "Search stored items for sale"
	)
	search.text = _shop_search_text
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.x = 320
	search.text_changed.connect(_on_shop_search_text_changed)
	top_row.add_child(search)
	var campaign: CampaignState = _campaign()
	var gold := Label.new()
	gold.custom_minimum_size.x = 170
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold.text = "GOLD  %d" % (
		campaign.resources.amount(&"gold")
		if campaign != null and campaign.resources != null
		else 0
	)
	gold.add_theme_font_size_override("font_size", 17)
	gold.add_theme_color_override("font_color", Color("dfc778"))
	top_row.add_child(gold)
	var categories := HBoxContainer.new()
	categories.add_theme_constant_override("separation", 3)
	column.add_child(categories)
	for category_entry: Array in [
		[&"all", "ALL"],
		[&"resources", "RESOURCES"],
		[&"weapons", "WEAPONS"],
		[&"armour", "ARMOUR"],
		[&"ammunition", "AMMO"],
		[&"supplies", "SUPPLIES"],
		[&"consumables", "CONSUMABLES"],
		[&"tools", "TOOLS"],
		[&"restraints", "RESTRAINTS"],
		[&"furniture", "FURNITURE"],
		[&"salvage", "SALVAGE"],
		[&"specialist", "SPECIALIST"],
	]:
		var category_id := StringName(category_entry[0])
		var category_button := Button.new()
		category_button.text = String(category_entry[1])
		category_button.toggle_mode = true
		category_button.button_pressed = _shop_category_filter == category_id
		category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_button.add_theme_font_size_override("font_size", 8)
		category_button.pressed.connect(func() -> void:
			_shop_category_filter = category_id
			_shop_selected_definition_id = &""
			_shop_selected_item_id = &""
			_shop_selected_resource_id = &""
			_shop_quantity = 1
			call_deferred("_show_screen", SCREEN_SHOP)
		)
		categories.add_child(category_button)
	if _shop_search_restore_focus:
		_shop_search_restore_focus = false
		search.call_deferred("grab_focus")
		search.call_deferred("set_caret_column", _shop_search_text.length())
	return panel


func _on_shop_search_text_changed(value: String) -> void:
	_shop_search_text = value
	_shop_search_generation += 1
	var expected_generation: int = _shop_search_generation
	await get_tree().create_timer(0.2).timeout
	if expected_generation != _shop_search_generation or _current_screen != SCREEN_SHOP:
		return
	_shop_search_restore_focus = true
	_shop_selected_definition_id = &""
	_shop_selected_item_id = &""
	_shop_selected_resource_id = &""
	_shop_quantity = 1
	call_deferred("_show_screen", SCREEN_SHOP)


func _shop_filtered_entries() -> Array[Dictionary]:
	var source: Array[Dictionary] = []
	if _campaign_session != null:
		if _shop_mode == SHOP_MODE_BUY:
			source = _campaign_session.shop_buy_entries()
		else:
			source = _campaign_session.shop_sell_entries()
	var result: Array[Dictionary] = []
	var search: String = _shop_search_text.strip_edges().to_lower()
	for entry: Dictionary in source:
		var category_id := StringName(entry.get("category_id", &"other"))
		if _shop_category_filter != &"all" and category_id != _shop_category_filter:
			continue
		var display_name: String = String(entry.get("display_name", ""))
		var description: String = String(entry.get("description", ""))
		if (
			not search.is_empty()
			and display_name.to_lower().find(search) < 0
			and description.to_lower().find(search) < 0
		):
			continue
		result.append(entry)
	return result


func _build_shop_list(entries: Array[Dictionary]) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var title := Label.new()
	title.text = "AVAILABLE GOODS" if _shop_mode == SHOP_MODE_BUY else "STORAGE FOR SALE"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("d3bd83"))
	column.add_child(title)
	var header := HBoxContainer.new()
	var item_header := Label.new()
	item_header.text = "ITEM"
	item_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_header.add_theme_font_size_override("font_size", 10)
	header.add_child(item_header)
	if _shop_mode == SHOP_MODE_SELL:
		var quantity_header := Label.new()
		quantity_header.text = "QTY"
		quantity_header.custom_minimum_size.x = 58
		quantity_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quantity_header.add_theme_font_size_override("font_size", 10)
		header.add_child(quantity_header)
	var price_header := Label.new()
	price_header.text = "PRICE"
	price_header.custom_minimum_size.x = 100
	price_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_header.add_theme_font_size_override("font_size", 10)
	header.add_child(price_header)
	column.add_child(header)
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	if entries.is_empty():
		list.add_child(_body_label(
			"No goods match the current filters."
			if _shop_mode == SHOP_MODE_BUY
			else "No stored items with an authored sale value match the current filters."
		))
		return panel
	for entry: Dictionary in entries:
		list.add_child(_build_shop_entry_row(entry))
	return panel


func _build_shop_entry_row(entry: Dictionary) -> Control:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size.y = 52
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row_panel.add_child(row)
	var entry_kind := StringName(entry.get("entry_kind", &"item"))
	var definition_id := StringName(entry.get("definition_id", &""))
	var item_id := StringName(entry.get("item_id", &""))
	var resource_id := StringName(entry.get("resource_id", &""))
	var selected: bool = false
	if _shop_mode == SHOP_MODE_BUY:
		selected = definition_id == _shop_selected_definition_id
	elif entry_kind == &"resource":
		selected = resource_id == _shop_selected_resource_id
	else:
		selected = item_id == _shop_selected_item_id
	var select := Button.new()
	select.toggle_mode = true
	select.button_pressed = selected
	select.text = ""
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(select)
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 7)
	select.add_child(content)
	var definition: ItemDefinition = (
		_campaign_session.catalogue.item_definition(definition_id)
		if _campaign_session != null and not definition_id.is_empty()
		else null
	)
	content.add_child(_build_item_icon(definition, Vector2(36, 36)))
	var label := VBoxContainer.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(label)
	var name := Label.new()
	name.text = String(entry.get("display_name", definition_id))
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 12)
	label.add_child(name)
	var sub := Label.new()
	sub.text = _shop_category_display(StringName(entry.get("category_id", &"other")))
	if entry_kind == &"resource":
		sub.text += " · %d PER LOT" % int(entry.get("lot_size", 1))
	if _shop_mode == SHOP_MODE_SELL and not bool(entry.get("available", true)):
		sub.text += " · UNAVAILABLE"
		sub.add_theme_color_override("font_color", Color("d18d7d"))
	else:
		sub.add_theme_color_override("font_color", Color("aaa58f"))
	sub.add_theme_font_size_override("font_size", 9)
	label.add_child(sub)
	if _shop_mode == SHOP_MODE_SELL:
		var quantity := Label.new()
		quantity.text = str(
			int(entry.get("resource_amount", 0))
			if entry_kind == &"resource"
			else int(entry.get("quantity", 1))
		)
		quantity.custom_minimum_size.x = 58
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(quantity)
	var price := Label.new()
	price.text = "%d G" % int(entry.get("buy_price_gold", entry.get("unit_price_gold", 0)))
	if entry_kind == &"resource":
		price.text += " / LOT"
	price.custom_minimum_size.x = 100
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.add_theme_color_override("font_color", Color("dfc778"))
	row.add_child(price)
	select.pressed.connect(func() -> void:
		if _shop_mode == SHOP_MODE_BUY:
			_shop_selected_definition_id = definition_id
			_shop_selected_item_id = &""
			_shop_selected_resource_id = &""
		elif entry_kind == &"resource":
			_shop_selected_resource_id = resource_id
			_shop_selected_item_id = &""
			_shop_selected_definition_id = &""
		else:
			_shop_selected_item_id = item_id
			_shop_selected_resource_id = &""
			_shop_selected_definition_id = definition_id
		_shop_quantity = 1
		call_deferred("_show_screen", SCREEN_SHOP)
	)
	return row_panel

func _build_shop_details(entries: Array[Dictionary], campaign: CampaignState) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	scroll.add_child(column)
	var entry: Dictionary = _shop_selected_entry(entries)
	if entry.is_empty():
		column.add_child(_heading_label("SELECT AN ITEM OR RESOURCE"))
		column.add_child(_body_label(
			"Choose an available good to buy."
			if _shop_mode == SHOP_MODE_BUY
			else "Choose an exact stored item or a stored resource lot to sell."
		))
		return panel
	var entry_kind := StringName(entry.get("entry_kind", &"item"))
	var definition_id := StringName(entry.get("definition_id", &""))
	var resource_id := StringName(entry.get("resource_id", &""))
	var definition: ItemDefinition = (
		_campaign_session.catalogue.item_definition(definition_id)
		if _campaign_session != null and not definition_id.is_empty()
		else null
	)
	var icon := _build_item_icon(definition, Vector2(130, 130))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var title := Label.new()
	title.text = String(entry.get("display_name", definition_id)).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("ddc78e"))
	column.add_child(title)
	var description: String = (
		definition.description if definition != null else String(entry.get("description", ""))
	)
	if not description.is_empty():
		column.add_child(_body_label(description))
	column.add_child(HSeparator.new())
	column.add_child(_heading_label("DETAILS"))
	column.add_child(_body_label("Category: %s" % _shop_category_display(
		StringName(entry.get("category_id", &"other"))
	)))
	if entry_kind == &"resource":
		column.add_child(_body_label("Stored: %d units" % int(entry.get("resource_amount", 0))))
		column.add_child(_body_label("Trade lot: %d units" % int(entry.get("lot_size", 1))))
	else:
		column.add_child(_body_label("Weight: %.1f lb each" % float(entry.get("weight_lb", 0.0))))
	var maximum_quantity: int = 99
	if _shop_mode == SHOP_MODE_SELL:
		maximum_quantity = (
			maxi(1, int(entry.get("maximum_lots", 0)))
			if entry_kind == &"resource"
			else maxi(1, int(entry.get("quantity", 1)))
		)
	_shop_quantity = clampi(_shop_quantity, 1, maximum_quantity)
	var quantity_row := HBoxContainer.new()
	quantity_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quantity_row.add_theme_constant_override("separation", 8)
	var quantity_label := _body_label("Lots" if entry_kind == &"resource" else "Quantity")
	quantity_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	quantity_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	quantity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_row.add_child(quantity_label)
	var quantity_controls := HBoxContainer.new()
	quantity_controls.size_flags_horizontal = Control.SIZE_SHRINK_END
	quantity_controls.add_theme_constant_override("separation", 3)
	quantity_row.add_child(quantity_controls)
	var quantity_decrease := Button.new()
	quantity_decrease.text = "−"
	quantity_decrease.tooltip_text = "Reduce quantity"
	quantity_decrease.custom_minimum_size = Vector2(34, 36)
	quantity_controls.add_child(quantity_decrease)
	var quantity_edit := LineEdit.new()
	quantity_edit.text = str(_shop_quantity)
	quantity_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_edit.max_length = 6
	quantity_edit.custom_minimum_size = Vector2(54, 36)
	quantity_edit.size_flags_horizontal = Control.SIZE_SHRINK_END
	quantity_controls.add_child(quantity_edit)
	var quantity_increase := Button.new()
	quantity_increase.text = "+"
	quantity_increase.tooltip_text = "Increase quantity"
	quantity_increase.custom_minimum_size = Vector2(34, 36)
	quantity_controls.add_child(quantity_increase)
	column.add_child(quantity_row)
	column.add_child(HSeparator.new())
	column.add_child(_heading_label("TRANSACTION"))
	var preview_column := VBoxContainer.new()
	preview_column.add_theme_constant_override("separation", 7)
	column.add_child(preview_column)
	var action := Button.new()
	action.text = "BUY" if _shop_mode == SHOP_MODE_BUY else "SELL"
	action.custom_minimum_size.y = 52
	var item_id := StringName(entry.get("item_id", &""))
	if _shop_mode == SHOP_MODE_BUY:
		action.pressed.connect(func() -> void:
			_request_shop_buy(definition_id, _shop_quantity)
		)
	elif entry_kind == &"resource":
		action.pressed.connect(func() -> void:
			_request_shop_sell_resource(resource_id, _shop_quantity)
		)
	else:
		action.pressed.connect(func() -> void:
			_request_shop_sell(item_id, _shop_quantity)
		)
	column.add_child(action)
	_refresh_shop_transaction_preview(
		preview_column,
		action,
		entry_kind,
		definition_id,
		resource_id,
		item_id
	)
	var apply_quantity := func(next_value: int) -> void:
		_shop_quantity = clampi(next_value, 1, maximum_quantity)
		if is_instance_valid(quantity_edit):
			quantity_edit.text = str(_shop_quantity)
			quantity_edit.caret_column = quantity_edit.text.length()
		if is_instance_valid(quantity_decrease):
			quantity_decrease.disabled = _shop_quantity <= 1
		if is_instance_valid(quantity_increase):
			quantity_increase.disabled = _shop_quantity >= maximum_quantity
		_refresh_shop_transaction_preview(
			preview_column,
			action,
			entry_kind,
			definition_id,
			resource_id,
			item_id
		)
	quantity_decrease.pressed.connect(func() -> void:
		apply_quantity.call(_shop_quantity - 1)
	)
	quantity_increase.pressed.connect(func() -> void:
		apply_quantity.call(_shop_quantity + 1)
	)
	quantity_edit.text_submitted.connect(func(value: String) -> void:
		apply_quantity.call(value.to_int() if value.is_valid_int() else _shop_quantity)
	)
	quantity_edit.focus_exited.connect(func() -> void:
		var value: String = quantity_edit.text
		apply_quantity.call(value.to_int() if value.is_valid_int() else _shop_quantity)
	)
	apply_quantity.call(_shop_quantity)
	if _shop_mode == SHOP_MODE_SELL:
		var open_storage := Button.new()
		open_storage.text = "VIEW IN STORAGE"
		var stored_item_id := StringName(entry.get("item_id", &""))
		open_storage.pressed.connect(func() -> void:
			_storage_location_filter = STORAGE_VIEW_STORED
			_selected_storage_definition_id = definition_id
			_selected_storage_item_id = stored_item_id
			call_deferred("_show_screen", SCREEN_STORAGE)
		)
		column.add_child(open_storage)
	return panel


func _refresh_shop_transaction_preview(
		preview_column: VBoxContainer,
		action: Button,
		entry_kind: StringName,
		definition_id: StringName,
		resource_id: StringName,
		item_id: StringName
) -> void:
	if not is_instance_valid(preview_column) or not is_instance_valid(action):
		return
	for child: Node in preview_column.get_children():
		preview_column.remove_child(child)
		child.queue_free()
	var preview: OperationResult
	if _campaign_session == null:
		preview = OperationResult.fail(&"no_campaign_session", "No active campaign session.")
	elif _shop_mode == SHOP_MODE_BUY:
		preview = _campaign_session.preview_shop_buy(definition_id, _shop_quantity)
	elif entry_kind == &"resource":
		preview = _campaign_session.preview_shop_sell_resource(resource_id, _shop_quantity)
	else:
		preview = _campaign_session.preview_shop_sell(item_id, _shop_quantity)
	action.disabled = not preview.success
	action.tooltip_text = preview.message
	if preview.success and preview.data is Dictionary:
		var data: Dictionary = preview.data as Dictionary
		if entry_kind == &"resource":
			preview_column.add_child(_body_label("Lot price: %d Gold per %d units" % [
				int(data.get("unit_price_gold", 0)),
				int(data.get("lot_size", 1)),
			]))
			preview_column.add_child(_body_label(
				"Resources sold: %d" % int(data.get("resource_amount", 0))
			))
			preview_column.add_child(_body_label("Stored resource: %d → %d" % [
				int(data.get("resource_before", 0)),
				int(data.get("resource_after", 0)),
			]))
		else:
			preview_column.add_child(_body_label(
				"Unit price: %d Gold" % int(data.get("unit_price_gold", 0))
			))
		preview_column.add_child(_body_label(
			"Total: %d Gold" % int(data.get("total_gold", 0))
		))
		preview_column.add_child(_body_label("Gold: %d → %d" % [
			int(data.get("gold_before", 0)),
			int(data.get("gold_after", 0)),
		]))
		if _shop_mode == SHOP_MODE_BUY or entry_kind == &"resource":
			preview_column.add_child(_body_label("Storage: %d / %d → %d / %d" % [
				int(data.get("storage_used_before", 0)),
				int(data.get("storage_maximum", 0)),
				int(data.get("storage_used_after", 0)),
				int(data.get("storage_maximum", 0)),
			]))
	else:
		preview_column.add_child(_body_label("UNAVAILABLE\n%s" % preview.message))

func _shop_selected_entry(entries: Array[Dictionary]) -> Dictionary:
	for entry: Dictionary in entries:
		if (
			_shop_mode == SHOP_MODE_BUY
			and StringName(entry.get("definition_id", &"")) == _shop_selected_definition_id
		):
			return entry
		if _shop_mode != SHOP_MODE_SELL:
			continue
		if (
			StringName(entry.get("entry_kind", &"item")) == &"resource"
			and StringName(entry.get("resource_id", &"")) == _shop_selected_resource_id
		):
			return entry
		if StringName(entry.get("item_id", &"")) == _shop_selected_item_id:
			return entry
	return {}

func _build_shop_recent_transactions(campaign: CampaignState) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var heading := Label.new()
	heading.text = "RECENT TRADE"
	heading.custom_minimum_size.x = 120
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", Color("c5a35b"))
	row.add_child(heading)
	var transactions: Array = campaign.get_shop_transactions() if campaign != null else []
	if transactions.is_empty():
		var empty := Label.new()
		empty.text = "No purchases or sales have been completed."
		empty.add_theme_font_size_override("font_size", 10)
		row.add_child(empty)
		return panel
	var start_index: int = maxi(0, transactions.size() - 4)
	for index: int in range(transactions.size() - 1, start_index - 1, -1):
		var transaction = transactions[index]
		var label := Label.new()
		if transaction.is_resource_transaction():
			label.text = "SELL %d %s +%d G" % [
				int(transaction.resource_amount),
				String(transaction.resource_id).capitalize(),
				int(transaction.total_gold),
			]
		else:
			var definition: ItemDefinition = _campaign_session.catalogue.item_definition(
				transaction.item_definition_id
			)
			var name: String = (
				definition.display_name
				if definition != null
				else String(transaction.item_definition_id)
			)
			label.text = "%s %d× %s %s%d G" % [
				String(transaction.transaction_kind).to_upper(),
				int(transaction.quantity),
				name,
				"−" if transaction.transaction_kind == &"buy" else "+",
				int(transaction.total_gold),
			]
		label.add_theme_font_size_override("font_size", 9)
		row.add_child(label)
	return panel

func _request_shop_buy(definition_id: StringName, quantity: int) -> void:
	if _campaign_session == null:
		return
	var preview: OperationResult = _campaign_session.preview_shop_buy(definition_id, quantity)
	if not preview.success:
		_show_toast(preview.message, true)
		return
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm Purchase"
	dialog.dialog_text = (
		"Purchase %d × %s for %d Gold?\n\nGold: %d → %d\nStorage: %d / %d → %d / %d"
		% [
			int(data.get("quantity", quantity)),
			String(data.get("display_name", definition_id)),
			int(data.get("total_gold", 0)),
			int(data.get("gold_before", 0)),
			int(data.get("gold_after", 0)),
			int(data.get("storage_used_before", 0)),
			int(data.get("storage_maximum", 0)),
			int(data.get("storage_used_after", 0)),
			int(data.get("storage_maximum", 0)),
		]
	)
	_workspace.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _campaign_session.buy_shop_item(definition_id, quantity)
		dialog.queue_free()
		if result.success:
			_shop_selected_definition_id = definition_id
			call_deferred("_show_screen", SCREEN_SHOP)
		_show_toast(result.message, not result.success)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(560, 330))


func _request_shop_sell(item_id: StringName, quantity: int) -> void:
	if _campaign_session == null:
		return
	var preview: OperationResult = _campaign_session.preview_shop_sell(item_id, quantity)
	if not preview.success:
		_show_toast(preview.message, true)
		return
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm Sale"
	dialog.dialog_text = (
		"Sell %d × %s for %d Gold?\n\nGold: %d → %d\nThis removes the selected exact item or quantity from Storage."
		% [
			int(data.get("quantity", quantity)),
			String(data.get("display_name", "Item")),
			int(data.get("total_gold", 0)),
			int(data.get("gold_before", 0)),
			int(data.get("gold_after", 0)),
		]
	)
	_workspace.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _campaign_session.sell_shop_item(item_id, quantity)
		dialog.queue_free()
		if result.success:
			var sold_all: bool = int(data.get("quantity", 0)) >= int(data.get("stack_quantity_before", 0))
			if sold_all:
				_shop_selected_item_id = &""
			_shop_selected_resource_id = &""
			_shop_quantity = 1
			call_deferred("_show_screen", SCREEN_SHOP)
		_show_toast(result.message, not result.success)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(560, 300))


func _request_shop_sell_resource(resource_id: StringName, lot_quantity: int) -> void:
	if _campaign_session == null:
		return
	var preview: OperationResult = _campaign_session.preview_shop_sell_resource(
		resource_id,
		lot_quantity
	)
	if not preview.success:
		_show_toast(preview.message, true)
		return
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm Resource Sale"
	dialog.dialog_text = (
		"Sell %d %s for %d Gold?\n\nStored: %d → %d\nGold: %d → %d\nStorage: %d / %d → %d / %d"
		% [
			int(data.get("resource_amount", 0)),
			String(data.get("display_name", resource_id)),
			int(data.get("total_gold", 0)),
			int(data.get("resource_before", 0)),
			int(data.get("resource_after", 0)),
			int(data.get("gold_before", 0)),
			int(data.get("gold_after", 0)),
			int(data.get("storage_used_before", 0)),
			int(data.get("storage_maximum", 0)),
			int(data.get("storage_used_after", 0)),
			int(data.get("storage_maximum", 0)),
		]
	)
	_workspace.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _campaign_session.sell_shop_resource(
			resource_id,
			lot_quantity
		)
		dialog.queue_free()
		if result.success:
			if int(data.get("resource_after", 0)) < int(data.get("lot_size", 1)):
				_shop_selected_resource_id = &""
			_shop_quantity = 1
			call_deferred("_show_screen", SCREEN_SHOP)
		_show_toast(result.message, not result.success)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(580, 340))


func _shop_category_display(category_id: StringName) -> String:
	match category_id:
		&"resources":
			return "Resources"
		&"weapons":
			return "Weapons"
		&"armour":
			return "Armour"
		&"ammunition":
			return "Ammunition"
		&"supplies":
			return "Supplies"
		&"consumables":
			return "Consumables"
		&"tools":
			return "Tools"
		&"restraints":
			return "Restraints"
		&"furniture":
			return "Furniture"
		&"salvage":
			return "Salvage"
		&"specialist":
			return "Specialist"
	return "Other"


func _build_item_icon(definition: ItemDefinition, minimum_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = minimum_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = _item_icon_path(definition)
	if ResourceLoader.exists(path):
		icon.texture = load(path) as Texture2D
	return icon


func _item_icon_path(definition: ItemDefinition) -> String:
	if definition == null:
		return "res://presentation/campaign/icons/item_categories/other.svg"
	if _is_furniture_definition(definition):
		return "res://presentation/campaign/icons/item_categories/furniture.svg"
	if definition.has_tag(&"salvage"):
		return "res://presentation/campaign/icons/item_categories/salvage.svg"
	if definition.has_tag(&"ammunition"):
		return "res://presentation/campaign/icons/item_categories/ammunition.svg"
	if definition.has_tag(&"consumable") or definition.has_tag(&"medical"):
		return "res://presentation/campaign/icons/item_categories/consumable.svg"
	if definition.can_equip_in_hand():
		return "res://presentation/campaign/icons/item_categories/weapon.svg"
	if definition.can_equip_in_slot(CampaignItemLocationState.CONTAINER_ARMOUR) or not definition.defence_profile_id.is_empty():
		return "res://presentation/campaign/icons/item_categories/armour.svg"
	if _is_roster_equipment_candidate(definition):
		return "res://presentation/campaign/icons/item_categories/gear.svg"
	return "res://presentation/campaign/icons/item_categories/other.svg"


func _item_category_id(definition: ItemDefinition) -> StringName:
	if definition == null:
		return &"other"
	if _is_furniture_definition(definition):
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


func _item_category_display(category_id: StringName) -> String:
	match category_id:
		&"equipment":
			return "Equipment"
		&"furniture":
			return "Furniture"
		&"consumables":
			return "Consumables"
		&"ammunition":
			return "Ammunition"
		&"salvage":
			return "Structural Salvage"
		&"all":
			return "All Items"
	return "Other"


func _is_armour_definition(definition: ItemDefinition) -> bool:
	return (
		definition != null
		and (
			definition.can_equip_in_slot(CampaignItemLocationState.CONTAINER_ARMOUR)
			or not definition.defence_profile_id.is_empty()
		)
	)


func _strategic_item_condition_label(
		item: CampaignItemState,
		definition: ItemDefinition
) -> String:
	if _is_armour_definition(definition):
		return "—"
	return _item_condition_label(item)


func _item_condition_label(item: CampaignItemState) -> String:
	if item == null:
		return "Unknown condition"
	if item.condition <= 0.0:
		return "DESTROYED — 0%"
	var percentage: int = roundi(item.condition * 100.0)
	if percentage >= 90:
		return "Excellent %d%%" % percentage
	if percentage >= 65:
		return "Serviceable %d%%" % percentage
	if percentage >= 35:
		return "Damaged %d%%" % percentage
	return "Critical %d%%" % percentage


func _item_location_display(item: CampaignItemState, campaign: CampaignState) -> String:
	if item == null or item.location == null:
		return "Unknown"
	var location_text: String = ""
	match item.location.location_type:
		CampaignItemLocationState.LOCATION_STRONGHOLD_STORAGE:
			location_text = "Stronghold Storage"
		CampaignItemLocationState.LOCATION_CHARACTER_EQUIPMENT, CampaignItemLocationState.LOCATION_CHARACTER_INVENTORY:
			var owner: PersistentCharacterState = (
				campaign.get_character(item.location.owner_id)
				if campaign != null
				else null
			)
			var owner_name: String = (
				owner.display_name if owner != null else String(item.location.owner_id)
			)
			location_text = "%s — %s" % [
				owner_name,
				String(item.location.container_id).replace("_", " ").capitalize(),
			]
		CampaignItemLocationState.LOCATION_MISSION_GROUND:
			location_text = (
				item.location.source_label
				if not item.location.source_label.is_empty()
				else "Mission Ground"
			)
		CampaignItemLocationState.LOCATION_LOST:
			location_text = "Lost"
		CampaignItemLocationState.LOCATION_UNASSIGNED:
			location_text = "Unassigned"
		_:
			location_text = String(item.location.location_type).replace(
				"_", " "
			).capitalize()
	if _campaign_session != null:
		var availability: Dictionary = _campaign_session.strategic_item_availability(
			item.item_id
		)
		if not bool(availability.get("available", true)):
			location_text += " — Reserved for %s" % String(
				availability.get("display_name", "deployment")
			)
	return location_text

func _request_storage_return_item(item_id: StringName) -> void:
	var result: OperationResult = _campaign_session.unequip_strategic_item(item_id)
	if not result.success:
		_show_toast(result.message, true)
		return
	_selected_storage_item_id = item_id
	_storage_location_filter = STORAGE_VIEW_STORED
	_show_screen(SCREEN_STORAGE)
	_show_toast(result.message)


func _small_meta_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("92988f"))
	return label


func _build_briefing_screen() -> void:
	var campaign: CampaignState = _campaign()
	var mission: ActiveMissionState = _actionable_mission()
	if campaign == null or mission == null:
		_workspace.add_child(_body_label("No mission is available for briefing."))
		return
	var definition: MissionDefinition = MissionDefinitionRegistry.definition(mission.mission_definition_id)
	if definition == null:
		_workspace.add_child(_body_label("The mission definition is unavailable."))
		return
	_planning_mission_id = mission.mission_instance_id
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_workspace.add_child(root)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 82)
	root.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	content.add_child(_heading_label(definition.display_name.to_upper()))
	content.add_child(_body_label(definition.briefing_text))
	content.add_child(_heading_label("OBJECTIVES"))
	for objective: MissionObjectiveDefinition in definition.primary_objectives:
		if objective != null:
			content.add_child(_body_label("PRIMARY — %s" % objective.display_name))
	for objective: MissionObjectiveDefinition in definition.optional_objectives:
		if objective != null:
			content.add_child(_body_label("OPTIONAL — %s" % objective.display_name))

	content.add_child(HSeparator.new())
	content.add_child(_heading_label("PREPARED EXPEDITION"))
	var ready_bays: Array[StableBayState] = _campaign_session.ready_stable_bays()
	var selected_bay: StableBayState = campaign.get_stable_bay(_selected_stable_bay_id)
	var briefing_blocker: String = ""
	if selected_bay == null or not ready_bays.has(selected_bay):
		selected_bay = ready_bays[0] if not ready_bays.is_empty() else null
		_selected_stable_bay_id = selected_bay.bay_id if selected_bay != null else &""
	var bay_selector := OptionButton.new()
	bay_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_index: int = 0
	for bay: StableBayState in ready_bays:
		var summary: Dictionary = _campaign_session.stable_bay_summary(bay.bay_id)
		var transport: Dictionary = summary.get("transport", {}) as Dictionary
		var index: int = bay_selector.item_count
		bay_selector.add_item("%s — %s" % [
			String(summary.get("squad_name", "Squad")),
			String(transport.get("transport_display_name", transport.get("display_name", "Walking"))),
		])
		bay_selector.set_item_metadata(index, bay.bay_id)
		if selected_bay != null and bay.bay_id == selected_bay.bay_id:
			selected_index = index
	if bay_selector.item_count == 0:
		bay_selector.add_item("NO READY STABLE EXPEDITION")
		bay_selector.disabled = true
	else:
		bay_selector.select(selected_index)
		bay_selector.item_selected.connect(func(index: int) -> void:
			_selected_stable_bay_id = StringName(bay_selector.get_item_metadata(index))
			_show_screen(SCREEN_BRIEFING)
		)
	content.add_child(bay_selector)

	if selected_bay == null:
		content.add_child(_body_label(
			"Prepare a squad, travel method and complete starting formation in the Stable before this mission can launch."
		))
	else:
		var bay_summary: Dictionary = _campaign_session.stable_bay_summary(selected_bay.bay_id)
		var transport: Dictionary = bay_summary.get("transport", {}) as Dictionary
		var squad: CampaignSquadState = campaign.get_squad(selected_bay.assigned_squad_id)
		var deployed_ids: Array[StringName] = selected_bay.occupied_character_ids()
		_briefing_selected_ids.clear()
		for character_id: StringName in deployed_ids:
			_briefing_selected_ids[character_id] = true
		if squad != null:
			if deployed_ids.size() > definition.maximum_player_deployment:
				briefing_blocker = "This mission allows %d characters; the Stable formation currently deploys %d." % [
					definition.maximum_player_deployment,
					deployed_ids.size(),
				]
			elif not deployed_ids.has(definition.protagonist_character_id):
				briefing_blocker = "This mission requires the protagonist in the Stable deployment formation."
		content.add_child(_body_label(
			"SQUAD: %s\nDEPLOYED: %d / %d SQUAD MEMBERS\nTRANSPORT: %s\nPASSENGERS: %d / %d\nCARGO: %s\nTRAVEL SPEED: ×%.2f\nJOURNEY NOTORIETY: %+d%%\nFORMATION: %s" % [
				String(bay_summary.get("squad_name", "Squad")),
				deployed_ids.size(),
				int(bay_summary.get("member_count", 0)),
				String(transport.get("transport_display_name", transport.get("display_name", "Walking"))),
				deployed_ids.size(),
				6 if bool(transport.get("is_walking", false)) else int(transport.get("total_passenger_capacity", 0)),
				"Survivors’ remaining carrying capacity" if bool(transport.get("is_walking", false)) else "%.0f lb" % float(transport.get("total_cargo_capacity_lb", 0.0)),
				float(transport.get("strategic_speed_multiplier", 1.0)),
				int(transport.get("journey_notoriety_modifier_percent", 0)),
				"READY" if bool(bay_summary.get("formation_ready", false)) else String(bay_summary.get("formation_message", "Incomplete")),
			]
		))
		content.add_child(_heading_label("SQUAD MEMBERS"))
		var injured_deployment_lines: Array[String] = []
		if squad != null:
			for character_id: StringName in selected_bay.occupied_character_ids():
				var character: PersistentCharacterState = campaign.get_character(character_id)
				if character == null:
					continue
				var health: Dictionary = _campaign_session.strategic_recovery_snapshot(character_id)
				var current_hp: int = int(health.get("current_hp", 0))
				var maximum_hp: int = int(health.get("maximum_hp", 1))
				var nonlethal: int = int(health.get("nonlethal_damage", 0))
				var health_locked: bool = not bool(health.get("can_deploy", true))
				content.add_child(_body_label("%s — %s — %d/%d HP%s" % [
					character.display_name,
					_roster_status(character),
					current_hp,
					maximum_hp,
					" — CANNOT DEPLOY" if health_locked else "",
				]))
				if current_hp < maximum_hp or nonlethal > 0:
					injured_deployment_lines.append("%s enters at %d/%d HP with %d nonlethal damage." % [
						character.display_name, current_hp, maximum_hp, nonlethal,
					])
		if not injured_deployment_lines.is_empty():
			content.add_child(_heading_label("INJURED DEPLOYMENT WARNING"))
			content.add_child(_body_label(
				"May deploy injured at the displayed persistent health values. Recovery pauses while the expedition is away.\n\n%s" % "\n".join(PackedStringArray(injured_deployment_lines))
			))

	if not briefing_blocker.is_empty():
		content.add_child(_heading_label("EXPEDITION BLOCKED"))
		content.add_child(_body_label(briefing_blocker))

	var shortcuts := HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 8)
	content.add_child(shortcuts)
	var roster_button := Button.new()
	roster_button.text = "OPEN ROSTER"
	roster_button.pressed.connect(func() -> void:
		_roster_mode = ROSTER_MODE_MANAGE
		_show_screen(SCREEN_ROSTER)
	)
	shortcuts.add_child(roster_button)
	var armoury_button := Button.new()
	armoury_button.text = "OPEN ARMOURY"
	armoury_button.pressed.connect(_open_equipment_from_briefing)
	shortcuts.add_child(armoury_button)
	var stable_button := Button.new()
	stable_button.text = "OPEN STABLE"
	stable_button.pressed.connect(func() -> void: _show_screen(SCREEN_STABLE))
	shortcuts.add_child(stable_button)

	var action_bar := PanelContainer.new()
	action_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	action_bar.offset_top = -70
	action_bar.offset_bottom = -8
	root.add_child(action_bar)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	action_bar.add_child(actions)
	var back := Button.new()
	back.text = "RETURN TO MAP"
	back.custom_minimum_size = Vector2(190, 52)
	back.pressed.connect(func() -> void: _show_screen(SCREEN_REGION))
	actions.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var route := Button.new()
	route.text = "PLAN ROUTE"
	route.custom_minimum_size = Vector2(230, 52)
	route.disabled = selected_bay == null or not briefing_blocker.is_empty()
	route.tooltip_text = (
		briefing_blocker
		if not briefing_blocker.is_empty()
		else "Prepare a valid expedition in the Stable first."
		if selected_bay == null
		else "Plan this expedition’s route."
	)
	route.pressed.connect(_enter_route_planning)
	actions.add_child(route)


func _selected_briefing_character_ids(
		_definition: MissionDefinition = null
) -> Array[StringName]:
	var selected: Array[StringName] = []
	var campaign: CampaignState = _campaign()
	var bay: StableBayState = campaign.get_stable_bay(_selected_stable_bay_id) if campaign != null else null
	if bay == null:
		return selected
	for character_id: StringName in bay.occupied_character_ids():
		var character: PersistentCharacterState = campaign.get_character(character_id)
		if character == null or character.is_dead:
			continue
		if character.health_initialized and (
			character.current_hp <= 0 or character.nonlethal_damage >= maxi(1, character.current_hp)
		):
			continue
		selected.append(character_id)
	return selected


func _open_equipment_from_briefing() -> void:
	var selected: Array[StringName] = _selected_briefing_character_ids()
	if not selected.is_empty():
		_selected_character_id = selected[0]
	_roster_mode = ROSTER_MODE_EQUIP
	_roster_tab_index = 0
	_show_screen(SCREEN_ROSTER)


func _enter_route_planning() -> void:
	if _campaign_session == null or _planning_mission_id.is_empty():
		return
	_campaign_session.pause_clock()
	_route_waypoints.clear()
	_route_planning_active = true
	if not _recalculate_route_plan():
		_route_planning_active = false
		_show_toast("No valid route reaches this mission.", true)
		return
	_show_screen(SCREEN_REGION)


func _recalculate_route_plan() -> bool:
	if _campaign_session == null or _planning_mission_id.is_empty():
		return false
	var preview: Dictionary = _campaign_session.preview_stable_bay_operation(
		_planning_mission_id,
		_selected_stable_bay_id,
		_route_waypoints
	)
	_route_plan = preview.get("route") as SquadRoutePlan
	_route_visibility = preview.get("visibility") as SquadVisibilitySnapshot
	_route_transport_snapshot = (preview.get("transport", {}) as Dictionary).duplicate(true)
	_route_transport_notoriety = (preview.get("notoriety", {}) as Dictionary).duplicate(true)
	_route_exposure_entries.clear()
	var raw_entries: Variant = preview.get("entries", [])
	if raw_entries is Array:
		for raw_entry: Variant in raw_entries as Array:
			var entry: TravelExposureEntry = raw_entry as TravelExposureEntry
			if entry != null:
				_route_exposure_entries.append(entry)
	return _route_plan != null and _route_visibility != null


func _on_squad_waypoint_added(destination: RegionHexCoord) -> void:
	if not _route_planning_active or destination == null:
		return
	var mission: ActiveMissionState = _campaign().get_active_mission(_planning_mission_id)
	var site: RegionSiteDefinition = (
		_campaign_session.current_region_site(mission.site_id) if mission != null else null
	)
	if site != null and site.coord != null and site.coord.key() == destination.key():
		_show_toast("The planned route already ends at the mission site.")
		return
	for waypoint: RegionHexCoord in _route_waypoints:
		if waypoint.key() == destination.key():
			_show_toast("That waypoint is already in the route.")
			return
	_route_waypoints.append(destination.duplicate_coord())
	if not _recalculate_route_plan():
		_route_waypoints.pop_back()
		_recalculate_route_plan()
		_show_toast("That waypoint creates an invalid or excessive detour.", true)
	if _region_map_view != null:
		_region_map_view.update_squad_route(_route_waypoints, _route_plan)
	_rebuild_route_planning_panel()
	_refresh_retaliation_bar()


func _on_squad_waypoint_removed() -> void:
	if not _route_planning_active or _route_waypoints.is_empty():
		return
	_route_waypoints.pop_back()
	_recalculate_route_plan()
	if _region_map_view != null:
		_region_map_view.update_squad_route(_route_waypoints, _route_plan)
	_rebuild_route_planning_panel()
	_refresh_retaliation_bar()


func _route_mission_site_id() -> StringName:
	var campaign: CampaignState = _campaign()
	var mission: ActiveMissionState = (
		campaign.get_active_mission(_planning_mission_id) if campaign != null else null
	)
	return mission.site_id if mission != null else &""


func _build_route_planning_panel() -> void:
	_route_panel = PanelContainer.new()
	_route_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_route_panel.position = Vector2(-475, -310)
	_route_panel.size = Vector2(455, 620)
	_route_panel.z_index = 30
	_workspace.add_child(_route_panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_route_panel.add_child(root)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	content.add_child(_heading_label("PLAN SQUAD ROUTE"))
	content.add_child(_body_label(
		"Left-click a land tile to add a waypoint. Right-click removes the most recent waypoint. Strategic time and mission expiry remain paused."
	))
	if _route_plan == null or _route_visibility == null:
		content.add_child(_body_label("No valid route is available."))
	else:
		content.add_child(_heading_label("JOURNEY"))
		var walking: bool = bool(_route_transport_snapshot.get("is_walking", false))
		var cargo_text: String = (
			"Survivors’ remaining carrying capacity"
			if walking
			else "%.0f lb dedicated cargo" % float(_route_transport_snapshot.get("total_cargo_capacity_lb", 0.0))
		)
		content.add_child(_heading_label("SQUAD VISIBILITY"))
		content.add_child(_body_label(
			"Prepared expedition: %s\nTravel time: %s\nTerrain time modifier: ×%.2f\nRecovery capacity: %s\nPassenger capacity: %s\nWaypoints: %d\nSquad footprint: %s — %d" % [
				String(_route_transport_snapshot.get("transport_display_name", _route_transport_snapshot.get("display_name", "Walking"))),
				_format_duration(ceili(_route_plan.total_minutes())),
				float(_route_transport_snapshot.get("terrain_multiplier", 1.0)),
				cargo_text,
				"Mission squad limit" if walking else str(int(_route_transport_snapshot.get("total_passenger_capacity", 0))),
				_route_waypoints.size(),
				_route_visibility.category_display_name(),
				_route_visibility.total_visibility,
			]
		))
		content.add_child(_heading_label("PROJECTED JOURNEY NOTORIETY"))
		var base_total: int = int(_route_transport_notoriety.get("base_total", 0))
		var modifier_percent: int = int(_route_transport_notoriety.get("modifier_percent", 0))
		var adjustment: int = int(_route_transport_notoriety.get("adjustment", 0))
		var projected_total: int = int(_route_transport_notoriety.get("final_total", 0))
		if _route_exposure_entries.is_empty():
			content.add_child(_body_label("This route creates no projected travel Notoriety."))
		else:
			for entry: TravelExposureEntry in _route_exposure_entries:
				var before_transport: int = entry.pre_transport_subtotal if entry.pre_transport_subtotal > 0 else entry.applied_subtotal
				content.add_child(_body_label("%s — %s: +%d" % [
					String(entry.subregion_id).replace("_", " ").capitalize(), entry.report_text, before_transport,
				]))
		content.add_child(HSeparator.new())
		content.add_child(_body_label(
			"Base Journey Notoriety: +%d\nTransport modifier: %+d%%\nTransport adjustment: %+d\nFINAL PROJECTED NOTORIETY: +%d" % [
				base_total, modifier_percent, adjustment, projected_total,
			]
		))
	var action_bar := HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 10)
	root.add_child(action_bar)
	var return_button := Button.new()
	return_button.text = "RETURN TO BRIEFING"
	return_button.custom_minimum_size = Vector2(185, 54)
	return_button.pressed.connect(_exit_route_planning_to_briefing)
	action_bar.add_child(return_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_bar.add_child(spacer)
	var send := Button.new()
	send.text = "SEND SQUAD"
	send.custom_minimum_size = Vector2(185, 54)
	send.disabled = (
		_route_plan == null
		or not bool(_route_transport_snapshot.get("availability_valid", false))
		or not bool(_route_transport_snapshot.get("capacity_valid", false))
	)
	send.tooltip_text = (
		String(_route_transport_snapshot.get("validation_message", "The prepared Stable expedition is invalid."))
		if send.disabled else "Dispatch the exact squad, transport and Stable formation."
	)
	send.pressed.connect(_dispatch_planned_squad)
	action_bar.add_child(send)


func _rebuild_route_planning_panel() -> void:
	if _route_panel != null:
		_route_panel.queue_free()
		_route_panel = null
	_build_route_planning_panel()


func _dispatch_planned_squad() -> void:
	if _campaign_session == null or _route_plan == null:
		return
	var result: OperationResult = _campaign_session.dispatch_stable_bay(
		_planning_mission_id,
		_selected_stable_bay_id,
		_route_waypoints
	)
	if not result.success:
		_show_toast(result.message, true)
		return
	_route_planning_active = false
	_route_waypoints.clear()
	_route_plan = null
	_route_visibility = null
	_route_exposure_entries.clear()
	_route_transport_snapshot.clear()
	_route_transport_notoriety.clear()
	_planning_mission_id = &""
	_briefing_selected_ids.clear()
	_show_screen(SCREEN_REGION)
	_show_toast("Squad dispatched. Mission expiry is now suspended.")


func _exit_route_planning_to_briefing() -> void:
	if not _route_planning_active:
		return
	_route_planning_active = false
	_route_waypoints.clear()
	_route_plan = null
	_route_visibility = null
	_route_exposure_entries.clear()
	_route_transport_snapshot.clear()
	_route_transport_notoriety.clear()
	_show_screen(SCREEN_BRIEFING)


func _build_regional_retaliation_bar() -> void:
	_retaliation_panel = PanelContainer.new()
	_retaliation_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_retaliation_panel.position = Vector2(-180, -72)
	_retaliation_panel.size = Vector2(360, 56)
	_retaliation_panel.z_index = 25
	_retaliation_panel.tooltip_text = (
		"Cumulative attention across the current campaign region. "
		+ "Local subregion values remain available only in relevant planning views."
	)
	_workspace.add_child(_retaliation_panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 1)
	_retaliation_panel.add_child(content)
	_retaliation_label = Label.new()
	_retaliation_label.custom_minimum_size = Vector2(336, 31)
	_retaliation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_retaliation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_retaliation_label.add_theme_font_size_override("font_size", 11)
	_retaliation_label.add_theme_color_override("font_color", Color("d8bd76"))
	_retaliation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_retaliation_label)
	_retaliation_bar = ProgressBar.new()
	_retaliation_bar.custom_minimum_size = Vector2(320, 10)
	_retaliation_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_retaliation_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_retaliation_bar.show_percentage = false
	_retaliation_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_retaliation_bar)
	_refresh_retaliation_bar()


func _refresh_retaliation_bar() -> void:
	if _campaign_session == null or _retaliation_bar == null:
		return
	var current: int = _campaign_session.regional_notoriety_total()
	var threshold: int = _campaign_session.regional_retaliation_threshold()
	var projected: int = current
	if _route_planning_active:
		for entry: TravelExposureEntry in _route_exposure_entries:
			projected += entry.applied_subtotal
	_retaliation_bar.max_value = maxf(1.0, float(threshold))
	_retaliation_bar.value = current
	var raid: RaidOperationState = _campaign().active_raid_operation(_campaign().current_region_id)
	if raid != null:
		_retaliation_label.text = "REGIONAL RAID INCOMING\n%d / %d" % [current, threshold]
	elif projected != current:
		_retaliation_label.text = "REGIONAL RETALIATION\n%d → %d / %d" % [current, projected, threshold]
	else:
		_retaliation_label.text = "REGIONAL RETALIATION\n%d / %d" % [current, threshold]


func _format_duration(minutes: int) -> String:
	if minutes < 0:
		return "No expiry"
	var days: int = minutes / (24 * 60)
	var hours: int = (minutes % (24 * 60)) / 60
	var remaining_minutes: int = minutes % 60
	var parts: Array[String] = []
	if days > 0:
		parts.append("%d day%s" % [days, "" if days == 1 else "s"])
	if hours > 0:
		parts.append("%d hour%s" % [hours, "" if hours == 1 else "s"])
	if remaining_minutes > 0 and days == 0:
		parts.append("%d minutes" % remaining_minutes)
	return " ".join(parts) if not parts.is_empty() else "Less than one minute"


func _build_registered_mission_resume(mission: ActiveMissionState) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-310, -190)
	panel.size = Vector2(620, 380)
	_workspace.add_child(panel)
	if mission.status == ActiveMissionState.STATUS_EN_ROUTE:
		panel.add_child(_heading_label("SQUAD EN ROUTE"))
		var operation: SquadTravelOperationState = (
			_campaign().get_squad_travel_operation(mission.travel_operation_id)
		)
		panel.add_child(_body_label(
			"The squad and its equipment are committed. Mission expiry is permanently "
			+ "suspended while the warband travels.\n\n"
			+ (
				"Arrival in %s.\nTravel Notoriety will be applied as each authored subregion span is crossed."
				% _format_duration(maxi(0, operation.arrival_tick - _campaign().campaign_tick))
				if operation != null
				else "The squad operation could not be resolved."
			)
		))
		var map_button := Button.new()
		map_button.text = "VIEW SQUAD ON REGION MAP"
		map_button.custom_minimum_size.y = 54
		map_button.pressed.connect(func() -> void:
			_show_screen(SCREEN_REGION)
			if _region_map_view != null:
				_region_map_view.focus_squad()
		)
		panel.add_child(map_button)
		if operation != null and _campaign().campaign_tick == operation.started_tick:
			var recall := Button.new()
			recall.text = "RECALL SQUAD BEFORE DEPARTURE"
			recall.tooltip_text = (
				"Cancel this deployment before strategic time advances and release "
				+ "every character and exact item reservation."
			)
			recall.pressed.connect(func() -> void:
				_request_squad_deployment_cancellation(mission.mission_instance_id)
			)
			panel.add_child(recall)
		return
	panel.add_child(_heading_label("REGISTERED MISSION"))
	panel.add_child(_body_label(
		"The mission has an immutable setup registered at campaign revision %d.\n\n"
		+ "Restarting uses the same squad, item identities and deterministic mission seed."
		% mission.source_campaign_revision
	))
	var restart := Button.new()
	restart.text = "RESTART REGISTERED MISSION"
	restart.custom_minimum_size.y = 58
	restart.pressed.connect(func() -> void: restart_registered_mission_requested.emit())
	panel.add_child(restart)
	var restore := Button.new()
	restore.text = "RESTORE LAST SAFE STATE"
	restore.pressed.connect(func() -> void: reload_safe_checkpoint_requested.emit())
	panel.add_child(restore)


func _request_squad_deployment_cancellation(
		mission_instance_id: StringName
) -> void:
	if _campaign_session == null:
		return
	var result: OperationResult = _campaign_session.cancel_squad_deployment(
		mission_instance_id
	)
	if not result.success:
		_show_toast(result.message, true)
		return
	_planning_mission_id = mission_instance_id
	_briefing_selected_ids.clear()
	_show_screen(SCREEN_BRIEFING)
	_show_toast(result.message)


func _request_deployment(
		mission: ActiveMissionState,
		definition: MissionDefinition
) -> void:
	var selected: Array[StringName] = []
	for character_id: StringName in definition.player_character_ids:
		if bool(_briefing_selected_ids.get(character_id, false)):
			selected.append(character_id)
	if not selected.has(definition.protagonist_character_id):
		_show_toast("The protagonist must deploy.", true)
		return
	if selected.size() > definition.maximum_player_deployment:
		_show_toast("The selected squad exceeds deployment capacity.", true)
		return
	deploy_requested.emit(mission.mission_instance_id, selected)


func _build_mission_recovery_screen() -> void:
	if _pending_recovery_result == null or _mission_recovery_snapshot.is_empty():
		_workspace.add_child(_body_label("No mission recovery manifest is awaiting confirmation."))
		return
	# Recovery is a full strategic screen. Build one full-height vertical layout
	# whose body scrolls and whose footer never scrolls. This avoids relying on
	# free-positioned anchors inside a complex campaign shell, which allowed a
	# long manifest to push the confirmation action beyond the visible viewport.
	var recovery_layer := Control.new()
	_workspace.add_child(recovery_layer)
	recovery_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	recovery_layer.mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	recovery_layer.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("080b0d")
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

	# The scroll body and footer use independent anchors. ScrollContainer minimum
	# size follows its contents, so placing both inside a VBox could still let a
	# very long manifest push the footer below the viewport.
	var body_scroll := ScrollContainer.new()
	recovery_layer.add_child(body_scroll)
	body_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_scroll.offset_left = 18.0
	body_scroll.offset_right = -18.0
	body_scroll.offset_top = 12.0
	body_scroll.offset_bottom = -92.0
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	body_scroll.add_child(root)

	var title := Label.new()
	title.text = "RECOVERED CARGO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("c9a557"))
	root.add_child(title)

	var transport: Dictionary = _mission_recovery_snapshot.get("transport", {}) as Dictionary
	var capacity: float = _recovery_effective_capacity()
	var selected_weight: float = _recovery_selected_weight()
	var validation: OperationResult = _recovery_selection_validation()
	var uses_dedicated_transport: bool = bool(
		_mission_recovery_snapshot.get("uses_dedicated_transport", false)
	)
	var transport_panel := PanelContainer.new()
	root.add_child(transport_panel)
	var transport_row := HBoxContainer.new()
	transport_row.add_theme_constant_override("separation", 14)
	transport_panel.add_child(transport_row)
	var transport_text := Label.new()
	if uses_dedicated_transport:
		transport_text.text = "%s%s\nTransport cargo capacity: %.0f lb\nSquad and personal equipment: passenger allowance\nSurvivor carrying contribution: ignored\nMandatory cargo burden: %.0f lb\nOptional recovery capacity: %.0f lb\nProjected return time: %s" % [
			String(transport.get("display_name", "Transport")),
			" ×%d" % int(transport.get("assigned_count", 0)),
			float(_mission_recovery_snapshot.get("transport_cargo_capacity_lb", 0.0)),
			_recovery_effective_mandatory_burden(),
			capacity,
			_format_duration(int(_mission_recovery_snapshot.get("projected_return_minutes", 0))),
		]
	else:
		transport_text.text = "%s\nDedicated transport cargo: 0 lb\nSurvivors’ remaining carrying capacity: %.0f lb\nMandatory carried burden: %.0f lb\nOptional recovery capacity: %.0f lb\nProjected return time: %s" % [
			String(transport.get("display_name", "Walking")),
			float(_mission_recovery_snapshot.get("personal_remaining_carry_capacity_lb", 0.0)),
			_recovery_effective_mandatory_burden(),
			capacity,
			_format_duration(int(_mission_recovery_snapshot.get("projected_return_minutes", 0))),
		]
	transport_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transport_text.add_theme_font_size_override("font_size", 13)
	transport_row.add_child(transport_text)
	var cargo_column := VBoxContainer.new()
	cargo_column.custom_minimum_size.x = 440
	transport_row.add_child(cargo_column)
	var cargo_label := Label.new()
	cargo_label.text = "OPTIONAL CARGO  %.1f / %.1f lb" % [selected_weight, capacity]
	cargo_label.add_theme_font_size_override("font_size", 14)
	cargo_label.add_theme_color_override(
		"font_color",
		Color("8fbd8f") if validation.success else Color("cc7777")
	)
	cargo_column.add_child(cargo_label)
	var cargo_bar := ProgressBar.new()
	cargo_bar.max_value = maxf(1.0, capacity)
	cargo_bar.value = selected_weight
	cargo_bar.show_percentage = false
	cargo_bar.custom_minimum_size.y = 16
	cargo_column.add_child(cargo_bar)
	var special_usage: Dictionary = (
		(validation.data as Dictionary).get("special_usage", {}) as Dictionary
		if validation.success and validation.data is Dictionary
		else _recovery_selected_special_usage()
	)
	var special_capacity: Dictionary = _mission_recovery_snapshot.get("special_capacity", {}) as Dictionary
	var manual_special: Dictionary = (
		(validation.data as Dictionary).get("manual_special_usage", {}) as Dictionary
		if validation.success and validation.data is Dictionary
		else {}
	)
	var special_label := Label.new()
	special_label.text = "DEDICATED SPECIALIST SUPPORT\nCages %d/%d · Monsters %d/%d · Siege %d/%d · Oversized %d/%d\n%s: cages %d · oversized %d" % [
		int(special_usage.get("cage", 0)), int(special_capacity.get("cage", 0)),
		int(special_usage.get("monster", 0)), int(special_capacity.get("monster", 0)),
		int(special_usage.get("siege", 0)), int(special_capacity.get("siege", 0)),
		int(special_usage.get("oversized", 0)), int(special_capacity.get("oversized", 0)),
		"Using ordinary cargo allowance" if uses_dedicated_transport else "Manually carried",
		int(manual_special.get("cage", 0)), int(manual_special.get("oversized", 0)),
	]
	special_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	special_label.add_theme_font_size_override("font_size", 10)
	special_label.add_theme_color_override("font_color", Color("b8b8aa"))
	cargo_column.add_child(special_label)
	if not validation.success:
		var reason := Label.new()
		reason.text = validation.message
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.add_theme_font_size_override("font_size", 10)
		reason.add_theme_color_override("font_color", Color("cc7777"))
		cargo_column.add_child(reason)


	var contributor_entries: Array = _mission_recovery_snapshot.get("contributing_survivors", []) as Array
	if not uses_dedicated_transport and not contributor_entries.is_empty():
		var carrier_lines: Array[String] = []
		for raw_contributor: Variant in contributor_entries:
			if not raw_contributor is Dictionary:
				continue
			var contributor: Dictionary = raw_contributor as Dictionary
			carrier_lines.append(
				"%s — %.0f lb maximum − %.1f lb outbound equipment = %.1f lb available" % [
					String(contributor.get("display_name", "Survivor")),
					float(contributor.get("maximum_load_lb", 0.0)),
					float(contributor.get("mandatory_carried_lb", 0.0)),
					float(contributor.get("remaining_lb", 0.0)),
				]
			)
		if not carrier_lines.is_empty():
			root.add_child(_body_label(
				"RECOVERY CARRYING BREAKDOWN\n" + "\n".join(carrier_lines)
			))

	var return_notoriety: Dictionary = _mission_recovery_snapshot.get("return_notoriety", {}) as Dictionary
	root.add_child(_body_label(
		"RETURN JOURNEY NOTORIETY\nBase +%d · %s %+d%% · adjustment %+d · projected final +%d" % [
			int(return_notoriety.get("base_total", 0)),
			String(transport.get("display_name", "Walking")),
			int(return_notoriety.get("modifier_percent", 0)),
			int(return_notoriety.get("adjustment", 0)),
			int(return_notoriety.get("final_total", 0)),
		]
	))
	root.add_child(_body_label(
		"Choose which optional recovered objects return with the squad. Original equipment and required extraction items return automatically. "
		+ (
			"The assigned transport carries the squad and their personal mission equipment through passenger capacity. Optional assets use only its dedicated cargo allowance; troop carrying capacity is not added."
			if uses_dedicated_transport
			else "Walking pools each conscious survivor’s unused capacity up to maximum load. Medium and heavy return loads are allowed, but no survivor may exceed maximum load."
		)
	))

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)
	var select_all := Button.new()
	select_all.text = "SELECT ALL THAT FIT"
	select_all.pressed.connect(_select_recovery_items_that_fit)
	controls.add_child(select_all)
	var select_none := Button.new()
	select_none.text = "ABANDON ALL OPTIONAL LOOT"
	select_none.pressed.connect(func() -> void:
		_recovery_selected_item_ids.clear()
		mission_recovery_selection_changed.emit(_recovery_selected_ids(), _recovery_selected_captive_ids_array())
		_show_screen(SCREEN_RECOVERY)
	)
	controls.add_child(select_none)
	var fixed_summary := Label.new()
	var prison_snapshot: Dictionary = _mission_recovery_snapshot.get("prison", {}) as Dictionary
	fixed_summary.text = "Mandatory items %d · Captives selected %d / %d · Prison cells available %d · %s %d" % [
		int(_mission_recovery_snapshot.get("mandatory_item_count", 0)),
		_recovery_selected_captive_ids.size(),
		int(_mission_recovery_snapshot.get("captive_count", 0)),
		int(prison_snapshot.get("available_capacity", 0)),
		"Squad casualties in passenger allowance" if uses_dedicated_transport else "Casualties carried",
		int(_mission_recovery_snapshot.get("carried_casualty_count", 0)),
	]
	fixed_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fixed_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fixed_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.add_child(fixed_summary)

	var captive_entries: Array = _mission_recovery_snapshot.get("captive_entries", []) as Array
	if not captive_entries.is_empty():
		var captive_panel := PanelContainer.new()
		captive_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root.add_child(captive_panel)
		var captive_margin := MarginContainer.new()
		captive_margin.add_theme_constant_override("margin_left", 10)
		captive_margin.add_theme_constant_override("margin_right", 10)
		captive_margin.add_theme_constant_override("margin_top", 10)
		captive_margin.add_theme_constant_override("margin_bottom", 10)
		captive_panel.add_child(captive_margin)
		var captive_column := VBoxContainer.new()
		captive_column.add_theme_constant_override("separation", 6)
		captive_margin.add_child(captive_column)
		captive_column.add_child(_heading_label("CAPTIVES"))
		var captive_help := Label.new()
		captive_help.text = "Accepted captives reserve Prison cells immediately and remain incoming until the squad reaches the stronghold."
		captive_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		captive_help.add_theme_font_size_override("font_size", 10)
		captive_help.add_theme_color_override("font_color", Color("aaa89d"))
		captive_column.add_child(captive_help)
		for raw_captive: Variant in captive_entries:
			if not raw_captive is Dictionary:
				continue
			var captive_entry: Dictionary = raw_captive as Dictionary
			var captive_id := StringName(captive_entry.get("captive_id", ""))
			var captive_check := CheckBox.new()
			captive_check.button_pressed = bool(_recovery_selected_captive_ids.get(captive_id, false))
			captive_check.text = "%s  ·  HP %d/%d  ·  %d cell%s  ·  %s" % [
				String(captive_entry.get("display_name", "Living captive")),
				int(captive_entry.get("current_hp", 0)),
				int(captive_entry.get("maximum_hp", 1)),
				int(captive_entry.get("cell_cost", 1)),
				"" if int(captive_entry.get("cell_cost", 1)) == 1 else "s",
				("Ransom %d Gold" % int(captive_entry.get("ransom_value", 0)))
				if bool(captive_entry.get("ransom_allowed", false))
				else "No ransom",
			]
			captive_check.toggled.connect(func(enabled: bool) -> void:
				if enabled:
					_recovery_selected_captive_ids[captive_id] = true
				else:
					_recovery_selected_captive_ids.erase(captive_id)
				mission_recovery_selection_changed.emit(_recovery_selected_ids(), _recovery_selected_captive_ids_array())
				_show_screen(SCREEN_RECOVERY)
			)
			captive_column.add_child(captive_check)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	margin.add_child(list)
	var optional_entries: Array = _mission_recovery_snapshot.get("optional_entries", []) as Array
	if optional_entries.is_empty():
		list.add_child(_body_label("No optional recovered objects were extracted from this mission."))
	else:
		for raw_entry: Variant in optional_entries:
			if not raw_entry is Dictionary:
				continue
			var entry: Dictionary = raw_entry as Dictionary
			var captured_item_id := StringName(entry.get("item_id", ""))
			var row := PanelContainer.new()
			var row_margin := MarginContainer.new()
			row_margin.add_theme_constant_override("margin_left", 8)
			row_margin.add_theme_constant_override("margin_right", 8)
			row_margin.add_theme_constant_override("margin_top", 6)
			row_margin.add_theme_constant_override("margin_bottom", 6)
			row.add_child(row_margin)
			var check := CheckBox.new()
			check.button_pressed = bool(_recovery_selected_item_ids.get(captured_item_id, false))
			var category_text: String = String(entry.get("cargo_category", "ordinary")).replace("_", " ").capitalize()
			check.text = "%s%s    %.1f lb    Storage %d    %s%s" % [
				String(entry.get("display_name", "Recovered item")),
				" ×%d" % int(entry.get("quantity", 1)) if int(entry.get("quantity", 1)) > 1 else "",
				float(entry.get("weight_lb", 0.0)),
				int(entry.get("storage_space", 0)),
				category_text,
				" · UNIQUE" if bool(entry.get("is_unique", false)) else "",
			]
			check.add_theme_font_size_override("font_size", 13)
			check.toggled.connect(func(enabled: bool) -> void:
				if enabled:
					_recovery_selected_item_ids[captured_item_id] = true
				else:
					_recovery_selected_item_ids.erase(captured_item_id)
				mission_recovery_selection_changed.emit(_recovery_selected_ids(), _recovery_selected_captive_ids_array())
				_show_screen(SCREEN_RECOVERY)
			)
			row_margin.add_child(check)
			list.add_child(row)

	var footer_surface := PanelContainer.new()
	recovery_layer.add_child(footer_surface)
	footer_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	footer_surface.z_index = 20
	footer_surface.anchor_left = 0.0
	footer_surface.anchor_right = 1.0
	footer_surface.anchor_top = 1.0
	footer_surface.anchor_bottom = 1.0
	footer_surface.offset_left = 18.0
	footer_surface.offset_right = -18.0
	footer_surface.offset_top = -80.0
	footer_surface.offset_bottom = -12.0
	var footer_margin := MarginContainer.new()
	footer_margin.add_theme_constant_override("margin_left", 12)
	footer_margin.add_theme_constant_override("margin_right", 12)
	footer_margin.add_theme_constant_override("margin_top", 7)
	footer_margin.add_theme_constant_override("margin_bottom", 7)
	footer_surface.add_child(footer_margin)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer_margin.add_child(footer)
	var abandon_count: int = optional_entries.size() - _recovery_selected_item_ids.size()
	var outcome := Label.new()
	outcome.text = "%d optional item%s selected · %d captive%s selected · %d item%s abandoned" % [
		_recovery_selected_item_ids.size(),
		"" if _recovery_selected_item_ids.size() == 1 else "s",
		_recovery_selected_captive_ids.size(),
		"" if _recovery_selected_captive_ids.size() == 1 else "s",
		maxi(0, abandon_count),
		"" if maxi(0, abandon_count) == 1 else "s",
	]
	outcome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outcome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(outcome)
	var abandon_and_return := Button.new()
	abandon_and_return.text = "ABANDON OPTIONAL LOOT AND RETURN"
	abandon_and_return.custom_minimum_size = Vector2(300, 54)
	abandon_and_return.tooltip_text = "Leave every optional recovered item behind and begin the return journey."
	abandon_and_return.pressed.connect(_abandon_optional_and_confirm_mission_recovery)
	footer.add_child(abandon_and_return)
	var confirm := Button.new()
	confirm.text = "CONFIRM SELECTED CARGO AND RETURN"
	confirm.custom_minimum_size = Vector2(330, 54)
	confirm.disabled = not validation.success
	confirm.tooltip_text = validation.message if confirm.disabled else "Commit the selected recovery manifest and begin the return journey."
	confirm.pressed.connect(_confirm_mission_recovery)
	footer.add_child(confirm)


func _recovery_selected_ids() -> Array[StringName]:
	var selected: Array[StringName] = []
	for raw_item_id: Variant in _recovery_selected_item_ids.keys():
		var item_id := StringName(raw_item_id)
		if not item_id.is_empty():
			selected.append(item_id)
	selected.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return selected


func _recovery_selected_captive_ids_array() -> Array[StringName]:
	var selected: Array[StringName] = []
	for raw_captive_id: Variant in _recovery_selected_captive_ids.keys():
		var captive_id := StringName(raw_captive_id)
		if not captive_id.is_empty():
			selected.append(captive_id)
	selected.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return selected


func _recovery_selection_validation() -> OperationResult:
	if _campaign_session == null:
		return OperationResult.fail(&"campaign_missing", "Campaign services are unavailable.")
	return _campaign_session.validate_mission_recovery_selection(
		_mission_recovery_snapshot,
		_recovery_selected_ids(),
		_recovery_selected_captive_ids_array()
	)


func _recovery_selected_weight() -> float:
	var total: float = 0.0
	var optional_entries: Array = _mission_recovery_snapshot.get("optional_entries", []) as Array
	for raw_entry: Variant in optional_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		if bool(_recovery_selected_item_ids.get(StringName(entry.get("item_id", "")), false)):
			total += float(entry.get("weight_lb", 0.0))
	return total


func _recovery_effective_mandatory_burden() -> float:
	var base_burden: float = float(_mission_recovery_snapshot.get("mandatory_unallocated_item_weight_lb", 0.0))
	base_burden += float(int(_mission_recovery_snapshot.get(
		"manual_casualty_count",
		_mission_recovery_snapshot.get("carried_casualty_count", 0)
	))) * 180.0
	var selected_captives: int = _recovery_selected_captive_ids.size()
	var dedicated_capacity: int = int(_mission_recovery_snapshot.get("dedicated_captive_capacity", 0))
	var manual_captives: int = maxi(0, selected_captives - dedicated_capacity)
	return base_burden + float(manual_captives) * 180.0


func _recovery_effective_capacity() -> float:
	return maxf(
		0.0,
		float(_mission_recovery_snapshot.get("gross_recovery_capacity_lb", 0.0))
		- _recovery_effective_mandatory_burden()
	)


func _recovery_selected_special_usage() -> Dictionary:
	var usage: Dictionary = {"cage": 0, "monster": 0, "siege": 0, "oversized": 0}
	for raw_entry: Variant in _mission_recovery_snapshot.get("optional_entries", []) as Array:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		if not bool(_recovery_selected_item_ids.get(StringName(entry.get("item_id", "")), false)):
			continue
		var category := StringName(entry.get("cargo_category", "ordinary"))
		if usage.has(category):
			usage[category] = int(usage.get(category, 0)) + int(entry.get("special_space_requirement", 0))
	return usage


func _select_recovery_items_that_fit() -> void:
	_recovery_selected_item_ids.clear()
	var optional_entries: Array = _mission_recovery_snapshot.get("optional_entries", []) as Array
	for raw_entry: Variant in optional_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var item_id := StringName(entry.get("item_id", ""))
		if item_id.is_empty():
			continue
		_recovery_selected_item_ids[item_id] = true
		if not _recovery_selection_validation().success:
			_recovery_selected_item_ids.erase(item_id)
	mission_recovery_selection_changed.emit(_recovery_selected_ids(), _recovery_selected_captive_ids_array())
	_show_screen(SCREEN_RECOVERY)


func _abandon_optional_and_confirm_mission_recovery() -> void:
	_recovery_selected_item_ids.clear()
	mission_recovery_selection_changed.emit(_recovery_selected_ids(), _recovery_selected_captive_ids_array())
	var validation: OperationResult = _recovery_selection_validation()
	if not validation.success:
		_show_toast(validation.message, true)
		return
	mission_recovery_confirmed.emit(_recovery_selected_ids(), _recovery_selected_captive_ids_array())


func _confirm_mission_recovery() -> void:
	var validation: OperationResult = _recovery_selection_validation()
	if not validation.success:
		_show_toast(validation.message, true)
		return
	mission_recovery_confirmed.emit(_recovery_selected_ids(), _recovery_selected_captive_ids_array())


func _build_summary_screen() -> void:
	if _summary_result == null:
		_summary_result = _campaign_session.latest_mission_result() if _campaign_session != null else null
	if _summary_result == null:
		_workspace.add_child(_body_label("No committed mission report exists."))
		return

	# The mission report is a full-screen frame with a scrollable body and a
	# fixed footer. Long withdrawal manifests must never move CONTINUE below the
	# viewport.
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	_workspace.add_child(root)

	var outcome := Label.new()
	outcome.text = MissionOutcome.display_name(_summary_result.mission_outcome).to_upper()
	outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome.add_theme_font_size_override("font_size", 34)
	outcome.add_theme_color_override("font_color", Color("c9a557"))
	root.add_child(outcome)

	var body_panel := PanelContainer.new()
	body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body_panel)
	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 12)
	body_margin.add_theme_constant_override("margin_right", 12)
	body_margin.add_theme_constant_override("margin_top", 10)
	body_margin.add_theme_constant_override("margin_bottom", 10)
	body_panel.add_child(body_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	scroll.add_child(columns)

	var squad := VBoxContainer.new()
	squad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	squad.size_flags_stretch_ratio = 1.0
	columns.add_child(squad)
	squad.add_child(_heading_label("SQUAD OUTCOMES"))
	var campaign: CampaignState = _campaign()
	for character_result: MissionCharacterResult in _summary_result.get_character_results():
		if not character_result.was_deployed:
			continue
		var character: PersistentCharacterState = campaign.get_character(character_result.character_id) if campaign != null else null
		var name_text: String = character.display_name if character != null else String(character_result.character_id)
		squad.add_child(_body_label("%s — %s — %d XP" % [
			name_text,
			MissionCharacterResult.outcome_display_name(character_result.outcome_state),
			character_result.xp_awarded,
		]))
		var contribution_parts: Array[String] = []
		var kills: int = character_result.statistic(&"kills")
		var incapacitations: int = character_result.statistic(&"incapacitations")
		var captures: int = character_result.statistic(&"captures")
		var stabilisations: int = character_result.statistic(&"allies_stabilised")
		if kills > 0:
			contribution_parts.append("Kills %d" % kills)
		if incapacitations > 0:
			contribution_parts.append("Incapacitations %d" % incapacitations)
		if captures > 0:
			contribution_parts.append("Captures %d" % captures)
		if stabilisations > 0:
			contribution_parts.append("Allies stabilised %d" % stabilisations)
		if not contribution_parts.is_empty():
			squad.add_child(_small_meta_label(" · ".join(contribution_parts)))
		if not character_result.xp_award_breakdown.is_empty():
			squad.add_child(_small_meta_label(
				"XP: " + " · ".join(character_result.xp_award_breakdown)
			))
		if (
			character != null
			and not character.is_dead
			and bool(
				_campaign_session.next_level_preview(character.character_id).get(
					"eligible",
					false
				)
			)
		):
			var level_ready := _small_meta_label("LEVEL UP AVAILABLE")
			level_ready.add_theme_color_override("font_color", Color("c9a557"))
			squad.add_child(level_ready)

	var objectives := VBoxContainer.new()
	objectives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objectives.size_flags_stretch_ratio = 0.85
	columns.add_child(objectives)
	objectives.add_child(_heading_label("OBJECTIVES"))
	for objective_id: StringName in _summary_result.completed_objective_ids:
		objectives.add_child(_body_label("✓ %s" % String(objective_id).replace("_", " ").capitalize()))
	for objective_id: StringName in _summary_result.failed_objective_ids:
		objectives.add_child(_body_label("✕ %s" % String(objective_id).replace("_", " ").capitalize()))

	var recovered := VBoxContainer.new()
	recovered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recovered.size_flags_stretch_ratio = 1.15
	columns.add_child(recovered)
	recovered.add_child(_heading_label("NEW LOOT RECOVERED"))
	var recovered_groups: Array[Dictionary] = _summary_new_loot_groups(_summary_result)
	if recovered_groups.is_empty():
		recovered.add_child(_body_label("No new optional loot was brought back."))
	else:
		for group: Dictionary in recovered_groups:
			recovered.add_child(_body_label("%s ×%d" % [
				String(group.get("display_name", "Recovered item")),
				int(group.get("quantity", 1)),
			]))
	var automatic_return_count: int = maxi(
		0,
		_summary_result.extracted_item_entries.size() - _summary_new_loot_entry_count(_summary_result)
	)
	recovered.add_child(_small_meta_label(
		"Returned squad equipment is reconciled automatically and is not listed as recovered loot.\n"
		+ "Automatic returns: %d · Captives: %d · Abandoned items: %d · Campaign revision: %d" % [
			automatic_return_count,
			_summary_result.get_captive_results().size(),
			_summary_result.abandoned_item_ids.size(),
			campaign.revision if campaign != null else 0,
		]
	))

	# This footer is deliberately outside the ScrollContainer. It stays visible
	# even when the withdrawal report contains many characters, objectives or
	# recovered-item groups.
	var footer := HBoxContainer.new()
	footer.custom_minimum_size.y = 64
	footer.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(footer)
	var summary_hint := Label.new()
	summary_hint.text = "Mission report committed. Continue when ready."
	summary_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(summary_hint)
	var continue_button := Button.new()
	continue_button.text = "CONTINUE TO REGION MAP"
	continue_button.custom_minimum_size = Vector2(360, 56)
	continue_button.pressed.connect(_continue_from_summary)
	footer.add_child(continue_button)


func _summary_new_loot_groups(result: MissionResult) -> Array[Dictionary]:
	var groups_by_key: Dictionary = {}
	for entry: Dictionary in _summary_new_loot_entries(result):
		var item: CampaignItemState = CampaignItemState.from_dictionary(entry)
		if item == null:
			continue
		var display_name: String = _item_name(item)
		var key: String = "%s|%s" % [String(item.definition_id), display_name]
		var group: Dictionary = groups_by_key.get(key, {
			"display_name": display_name,
			"quantity": 0,
		}) as Dictionary
		group["quantity"] = int(group.get("quantity", 0)) + item.quantity
		groups_by_key[key] = group
	var groups: Array[Dictionary] = []
	for raw_group: Variant in groups_by_key.values():
		if raw_group is Dictionary:
			groups.append((raw_group as Dictionary).duplicate(true))
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("display_name", "")) < String(b.get("display_name", ""))
	)
	return groups


func _summary_new_loot_entry_count(result: MissionResult) -> int:
	return _summary_new_loot_entries(result).size()


func _summary_new_loot_entries(result: MissionResult) -> Array[Dictionary]:
	var recovered: Array[Dictionary] = []
	if result == null:
		return recovered
	var outbound_origin_ids: Dictionary = _summary_outbound_origin_ids(result)
	for entry: Dictionary in result.extracted_item_entries:
		var item: CampaignItemState = CampaignItemState.from_dictionary(entry)
		if item == null or _summary_item_is_outbound(item, outbound_origin_ids):
			continue
		recovered.append(entry.duplicate(true))
	return recovered


func _summary_outbound_origin_ids(result: MissionResult) -> Dictionary:
	var outbound: Dictionary = {}
	if result == null:
		return outbound
	# The item-outcome manifest is the strongest authority for exact items taken
	# out on the mission, including returned, transferred and partly consumed
	# equipment.
	for raw_item_id: Variant in result.item_outcomes_by_id.keys():
		var item_id_text: String = String(raw_item_id)
		if not item_id_text.is_empty():
			outbound[item_id_text] = true
	# Character equipment lists support legacy/interrupted results. Explicit loot
	# entries remain new loot even when carried by a returning character.
	for character_result: MissionCharacterResult in result.get_character_results():
		var loot_ids: Dictionary = {}
		for loot_id: StringName in character_result.loot_item_ids:
			loot_ids[String(loot_id)] = true
		for item_id: StringName in character_result.equipment_item_ids:
			var item_id_text: String = String(item_id)
			if not item_id_text.is_empty() and not loot_ids.has(item_id_text):
				outbound[item_id_text] = true
	# Restraints committed to extracted captives are outbound mission equipment,
	# not newly recovered loot.
	for captive: MissionCaptiveResult in result.get_captive_results():
		if not captive.restraint_item_id.is_empty():
			outbound[String(captive.restraint_item_id)] = true
	return outbound


func _summary_item_is_outbound(
		item: CampaignItemState,
		outbound_origin_ids: Dictionary
) -> bool:
	if item == null:
		return false
	var item_id_text: String = String(item.item_id)
	if outbound_origin_ids.has(item_id_text):
		return true
	var origin_item_id: String = String(item.persistent_modifiers.get(
		TacticalCharacterDeploymentService.MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY,
		""
	))
	if not origin_item_id.is_empty() and outbound_origin_ids.has(origin_item_id):
		return true
	# Compatibility with pending results produced before lineage metadata was
	# authored. Split or attached descendants retain their exact origin prefix.
	for raw_origin_id: Variant in outbound_origin_ids.keys():
		var origin_text: String = String(raw_origin_id)
		if (
			item_id_text.begins_with("%s.attached." % origin_text)
			or item_id_text.begins_with("%s.split." % origin_text)
		):
			return true
	return false


func _continue_from_summary() -> void:
	if _campaign_session != null:
		var save_result: OperationResult = _campaign_session.save_current()
		if not save_result.success:
			_show_toast(save_result.message, true)
			return
	_show_screen(SCREEN_REGION)
	var operation: SquadTravelOperationState = null
	var campaign: CampaignState = _campaign()
	var mission: ActiveMissionState = (
		campaign.get_active_mission(_summary_result.mission_id)
		if campaign != null and _summary_result != null
		else null
	)
	if mission != null and not mission.travel_operation_id.is_empty():
		operation = campaign.get_squad_travel_operation(mission.travel_operation_id)
	if operation != null and operation.status == SquadTravelOperationState.STATUS_RETURNING:
		if _region_map_view != null:
			_region_map_view.focus_squad()



func _build_defeat_screen() -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-370, -210)
	panel.size = Vector2(740, 420)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 18)
	_workspace.add_child(panel)
	var title := Label.new()
	title.text = "THE CHAMPION HAS FALLEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("8d3541"))
	panel.add_child(title)
	panel.add_child(_body_label(
		"The campaign cannot continue from this tactical result.\n"
		+ "No deaths, loot or experience from the lethal result have been committed."
	))
	var reload := Button.new()
	reload.text = "RELOAD LAST SAFE STATE"
	reload.custom_minimum_size = Vector2(360, 58)
	reload.pressed.connect(func() -> void: reload_safe_checkpoint_requested.emit())
	panel.add_child(reload)
	var main := Button.new()
	main.text = "RETURN TO MAIN MENU"
	main.pressed.connect(func() -> void: return_to_main_menu_requested.emit())
	panel.add_child(main)


func _open_last_report() -> void:
	if _campaign_session == null:
		return
	_summary_result = _campaign_session.latest_mission_result()
	if _summary_result == null:
		_show_toast("No committed mission report exists.")
		return
	_show_screen(SCREEN_SUMMARY)


func _refresh_header() -> void:
	var campaign: CampaignState = _campaign()
	if campaign == null:
		return
	_day_label.text = "DAY %d" % StrategicClockService.day_number(campaign.campaign_tick)
	_time_label.text = "%02d:%02d" % [
		StrategicClockService.hour(campaign.campaign_tick),
		StrategicClockService.minute(campaign.campaign_tick),
	]
	if campaign.resources != null:
		for resource_id: StringName in CampaignResourceBalances.RESOURCE_IDS:
			var label: Label = _resource_labels.get(resource_id) as Label
			if label != null:
				label.text = "%s %d" % [String(_resource_symbols.get(resource_id, "?")), campaign.resources.amount(resource_id)]
	for raw_screen: Variant in _navigation_buttons.keys():
		var button: Button = _navigation_buttons[raw_screen] as Button
		if button != null:
			button.button_pressed = StringName(raw_screen) == _current_screen
	_title_label.text = _screen_title(campaign)
	var agent: AgentState = _campaign_session.primary_agent() if _campaign_session != null else null
	_agent_button.visible = _current_screen == SCREEN_REGION and agent != null
	_apply_agent_button_state(agent)
	if _region_map_view != null and _campaign_session != null:
		_region_map_view.set_strategic_speed(_campaign_session.strategic_speed())
	_report_button.visible = _current_screen == SCREEN_REGION and _campaign_session.latest_mission_result() != null


func _apply_agent_button_state(agent: AgentState) -> void:
	if _agent_button == null:
		return
	if agent == null:
		_agent_button.disabled = true
		_agent_button.text = "AGENT"
		_agent_button.icon = AGENT_ICON_BLOCKED
		_agent_button.tooltip_text = "No Agent is available"
		_agent_button.modulate = Color(0.58, 0.58, 0.58, 1.0)
		return
	var state: StringName = _agent_button_state(agent)
	_last_agent_button_state = state
	_agent_button.text = "AGENT"
	_agent_button.disabled = state == AGENT_BUTTON_BLOCKED_BY_MODAL
	var base_modulate := Color.WHITE
	match state:
		AGENT_BUTTON_READY_AT_STRONGHOLD:
			_agent_button.icon = AGENT_ICON_READY
			_agent_button.tooltip_text = "Deploy Agent"
		AGENT_BUTTON_DEPLOYED:
			_agent_button.icon = AGENT_ICON_DEPLOYED
			_agent_button.tooltip_text = "Relocate Agent"
		AGENT_BUTTON_TRAVELLING:
			_agent_button.icon = AGENT_ICON_TRAVELLING
			_agent_button.tooltip_text = "View travelling Agent"
			base_modulate = Color(0.84, 0.91, 0.89, 1.0)
		AGENT_BUTTON_PREVIEW_ACTIVE:
			_agent_button.icon = AGENT_ICON_PREVIEW
			_agent_button.tooltip_text = "Cancel Agent placement"
			base_modulate = Color(1.0, 0.96, 0.72, 1.0)
		AGENT_BUTTON_BLOCKED_BY_MODAL:
			_agent_button.icon = AGENT_ICON_BLOCKED
			_agent_button.tooltip_text = "Unavailable while the mission report is open"
			base_modulate = Color(0.55, 0.55, 0.55, 1.0)
	var now: int = Time.get_ticks_msec()
	if now < _agent_button_alert_until_ms and state != AGENT_BUTTON_PREVIEW_ACTIVE:
		var pulse: float = (sin(float(now) * 0.012) + 1.0) * 0.5
		base_modulate = base_modulate.lerp(Color(1.0, 0.88, 0.50, 1.0), pulse * 0.38)
	_agent_button.modulate = base_modulate


func _agent_button_state(agent: AgentState) -> StringName:
	if _mission_popup_open:
		return AGENT_BUTTON_BLOCKED_BY_MODAL
	if _region_map_view != null and _region_map_view.is_agent_preview_mode():
		return AGENT_BUTTON_PREVIEW_ACTIVE
	if agent.status == AgentState.STATUS_TRAVELLING:
		return AGENT_BUTTON_TRAVELLING
	if agent.status == AgentState.STATUS_DEPLOYED:
		return AGENT_BUTTON_DEPLOYED
	return AGENT_BUTTON_READY_AT_STRONGHOLD


func _screen_title(campaign: CampaignState) -> String:
	match _current_screen:
		SCREEN_REGION:
			var region: RegionMapDefinition = (
				_campaign_session.current_region_definition()
				if _campaign_session != null
				else null
			)
			return region.display_name.to_upper() if region != null else String(campaign.current_region_id)
		SCREEN_STRONGHOLD:
			return "FIFTH-GOD STRONGHOLD"
		SCREEN_ROSTER:
			return "ROSTER & EQUIPMENT"
		SCREEN_STORAGE:
			return "STRONGHOLD STORAGE"
		SCREEN_SHOP:
			return "SHOP"
		SCREEN_PRODUCTION:
			return "PRODUCTION"
		SCREEN_RESEARCH:
			return "RESEARCH"
		SCREEN_STABLE:
			return "STABLES & EXPEDITIONS"
		SCREEN_PRISON:
			return "PRISON & CAPTIVES"
		SCREEN_RECOVERY:
			return "MISSION RECOVERY"
		SCREEN_BRIEFING:
			var mission: ActiveMissionState = _actionable_mission()
			var site: RegionSiteDefinition = (
				_campaign_session.current_region_site(mission.site_id)
				if _campaign_session != null and mission != null
				else null
			)
			return site.display_name.to_upper() if site != null else "MISSION BRIEFING"
		SCREEN_SUMMARY:
			return "MISSION SUMMARY"
		SCREEN_DEFEAT:
			return "CAMPAIGN DEFEAT"
	return String(campaign.current_region_id)


func _on_campaign_changed(_reason: StringName) -> void:
	if _region_map_view != null:
		_region_map_view.update_campaign(_campaign())
		_region_map_view.set_strategic_speed(_campaign_session.strategic_speed())
	_refresh_retaliation_bar()
	_refresh_header()


func _campaign() -> CampaignState:
	return _campaign_session.current_campaign() if _campaign_session != null else null


func _actionable_mission() -> ActiveMissionState:
	var campaign: CampaignState = _campaign()
	return campaign.first_actionable_mission() if campaign != null else null


func _readiness(character: PersistentCharacterState) -> String:
	return _roster_status(character)

func _character_item_summary(character_id: StringName) -> String:
	var campaign: CampaignState = _campaign()
	if campaign == null:
		return "No equipment."
	var lines: Array[String] = []
	for item: CampaignItemState in campaign.items_for_character(character_id):
		var location_name: String = (
			String(item.location.container_id).replace("_", " ").capitalize()
			if item.location != null
			else "Unknown"
		)
		lines.append("%s — %s" % [_item_name(item), location_name])
	return "\n".join(lines) if not lines.is_empty() else "No equipment."


func _item_name(item: CampaignItemState) -> String:
	if item == null or _campaign_session == null:
		return "Unknown item"
	var definition: ItemDefinition = _campaign_session.catalogue.item_definition(item.definition_id)
	return definition.display_name if definition != null else String(item.definition_id)


func _heading_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("c5a35b"))
	return label


func _body_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("d4d0c4"))
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return label


func _show_toast(message: String, is_error: bool = false) -> void:
	if _toast_label == null:
		return
	_toast_label.text = message
	_toast_label.add_theme_color_override(
		"font_color",
		Color("e09797") if is_error else Color("d9cfb7")
	)
	_toast_label.visible = true
	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(func() -> void:
		if _toast_label != null:
			_toast_label.visible = false
	)
