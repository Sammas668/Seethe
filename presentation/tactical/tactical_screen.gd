extends Node2D

signal movement_presentation_finished
signal mission_finished

const UNIT_VIEW_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_unit_view.tscn"
)
const UNIT_MANAGEMENT_WINDOW_SCENE: PackedScene = preload(
	"res://presentation/tactical/unit_management_window.tscn"
)
const TACTICAL_BOARD_VIEW_SCRIPT: Script = preload(
	"res://presentation/tactical/tactical_board_view.gd"
)
const TACTICAL_COMBAT_LOG_SCENE: PackedScene = preload(
	"res://presentation/tactical/combat_log/tactical_combat_log.tscn"
)
const ROSTER_UNIT_BUTTON_SCRIPT: Script = preload(
	"res://presentation/tactical/widgets/roster_unit_button.gd"
)
const MISSION_RESOLUTION_WINDOW_SCRIPT: Script = preload(
	"res://presentation/tactical/missions/tactical_mission_resolution_window.gd"
)
const REACTION_AOO_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/reaction_aoo_icon.svg"
)
const REACTION_OVERWATCH_BOW_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/reaction_overwatch_bow_icon.svg"
)
const REACTION_BRACE_SPEAR_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/reaction_brace_spear_icon.svg"
)

enum BoardIntentMode {
	NONE,
	MOVE_PREVIEW,
	FACING_PREVIEW,
	OVERWATCH_PREVIEW,
	BRACE_PREVIEW,
}

enum PresentationCadenceEvent {
	NONE,
	ACTIVATION_HANDOFF,
	AI_MOVE_TO_ATTACK,
	PHASE_HANDOFF,
	ENEMY_REVEALED,
	ALERT_TRIGGERED,
	INTERRUPTION,
}

enum TacticalPresentationVisibility {
	UNOBSERVED,
	PARTIALLY_OBSERVED,
	OBSERVED,
}

const INVALID_BOARD_TILE: Vector2i = Vector2i(-1, -1)
const ACTIVATION_HANDOFF_SECONDS: float = 0.0
const AI_MOVE_TO_ATTACK_SECONDS: float = 0.0
const PHASE_HANDOFF_SECONDS: float = 0.0
const AI_VISIBLE_MOVE_SHORT_START_SECONDS: float = 0.06
const AI_VISIBLE_MOVE_SHORT_STEP_SECONDS: float = 0.045
const AI_VISIBLE_MOVE_LONG_STEP_SECONDS: float = 0.015
const AI_VISIBLE_MOVE_ORDINARY_CAP_SECONDS: float = 0.34
const AI_VISIBLE_MOVE_MAX_SECONDS: float = 0.40
const AI_VISIBLE_MOVE_ORDINARY_CAP_STEPS: int = 16
const ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC: int = 8000
const ENEMY_HANDOFF_IDLE_WARMUP_BUDGET_USEC: int = 1500
const ENEMY_CHAIN_WARMUP_BUDGET_USEC: int = 1800
const HIDDEN_AI_VISIBILITY_FAST_BUDGET_USEC: int = 16000
const AI_DESTINATION_VISIBILITY_FINAL_BUDGET_USEC: int = 3000
const REVEAL_ACKNOWLEDGEMENT_SECONDS: float = 0.20
const ALERT_ACKNOWLEDGEMENT_SECONDS: float = 0.25
const ALERT_ACTION_LEAD_SECONDS: float = 0.06
const ALERT_FLASH_SECONDS: float = 0.25
const INTERRUPTION_ACKNOWLEDGEMENT_SECONDS: float = 0.15
const AI_VISIBLE_SHORT_ACTION_HANDOFF_SECONDS: float = 0.07
const AI_VISIBLE_MOVEMENT_SUPPLIES_CADENCE_SECONDS: float = 0.10
const ENEMY_STALL_THRESHOLDS_USEC: Array[int] = [
	250_000,
	500_000,
	1_000_000,
	2_000_000,
	5_000_000,
]
const ENEMY_STALL_HISTORY_LIMIT: int = 20

@onready var _board_view: Variant = $BoardView
@onready var _unit_layer: Node2D = $BoardView/UnitLayer

@onready var _objective_label: Label = $HUD/TopBar/Margin/Row/ObjectiveLabel
@onready var _phase_label: Label = $HUD/TopBar/Margin/Row/PhaseLabel
@onready var _hint_label: Label = $HUD/TopBar/Margin/Row/HintLabel

@onready var _roster_container: VBoxContainer = $HUD/RosterPanel/Margin/VBox

@onready var _short_name_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortNameLabel
@onready var _unit_health_bar: Control = $HUD/BottomDeck/Margin/MainRow/UnitBlock/UnitHealthBar
@onready var _short_hp_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortHPLabel
@onready var _short_capacity_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortCapacityLabel
@onready var _unit_capacity_bar: ProgressBar = $HUD/BottomDeck/Margin/MainRow/UnitBlock/UnitCapacityBarContainer/UnitCapacityBar
@onready var _unit_capacity_value_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/UnitCapacityBarContainer/UnitCapacityValueLabel
@onready var _short_context_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortContextLabel
@onready var _attack_mode_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/AttackOptions/AttackModeButton
@onready var _power_attack_down_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/AttackOptions/PowerAttackDownButton
@onready var _power_attack_value_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/AttackOptions/PowerAttackValueButton
@onready var _power_attack_up_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/AttackOptions/PowerAttackUpButton
@onready var _left_hand_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/HandRow/LeftHandButton
@onready var _right_hand_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/HandRow/RightHandButton
@onready var _attack_cursor_preview: PanelContainer = $HUD/AttackCursorPreview
@onready var _attack_cursor_label: Label = $HUD/AttackCursorPreview/Margin/Label

@onready var _attack_button: Button = $HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/AttackButton
@onready var _abilities_button: Button = $HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/AbilitiesButton
@onready var _tactics_button: Button = $HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/TacticsButton
@onready var _inventory_button: Button = $HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/InventoryButton
@onready var _interact_button: Button = $HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/InteractButton
@onready var _end_unit_button: Button = $HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/EndUnitButton

@onready var _context_tray: PanelContainer = $HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray
@onready var _context_action_buttons: Array[Button] = [
	$HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray/Margin/Actions/Action1,
	$HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray/Margin/Actions/Action2,
	$HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray/Margin/Actions/Action3,
	$HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray/Margin/Actions/Action4,
	$HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray/Margin/Actions/Action5,
	$HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray/Margin/Actions/Action6,
]

@onready var _extract_button: Button = $HUD/BottomDeck/Margin/MainRow/PhaseBlock/ExtractButton
@onready var _end_phase_button: Button = $HUD/BottomDeck/Margin/MainRow/PhaseBlock/EndPhaseButton
@onready var _round_short_label: Label = $HUD/BottomDeck/Margin/MainRow/PhaseBlock/RoundShortLabel

var _facade
var _map_definition: TacticalMapDefinition
var _player_unit_order: Array[StringName] = []
var _portrait_resolver: PortraitAssetResolver

var _unit_views: Dictionary = {}
var _unit_buttons: Dictionary = {}
var _selected_unit_id: StringName = &""
var _hovered_tile: Vector2i = INVALID_BOARD_TILE
var _board_intent_mode: int = BoardIntentMode.NONE
var _planned_destination: Vector2i = INVALID_BOARD_TILE
var _planned_facing: Vector2i = Vector2i.ZERO
var _preview_result: MovementPathResult
var _detection_preview: MovementDetectionPreview
var _reaction_preview: MovementReactionPreview
var _reaction_preview_query_count: int = 0
var _reaction_reservation_preview_tiles: Array[Vector2i] = []
var _reaction_reservation_preview_kind: StringName = &""
var _facing_preview_direction: Vector2i = Vector2i.ZERO
var _cover_preview: TacticalCoverPreview
var _directional_cover_field: TacticalDirectionalCoverField
var _selected_cover_category: StringName = &"neutral"
var _selected_attack_geometry: TacticalCombatGeometryResult
var _destination_preview_cache: Dictionary = {}
var _destination_preview_cache_hits: int = 0
var _destination_preview_cache_misses: int = 0
var _hover_preview_build_count: int = 0
var _movement_detection_preview_query_count: int = 0
var _hover_hud_refresh_count: int = 0
var _hover_board_refresh_count: int = 0
var _world_phase_in_progress: bool = false
var _inventory_open: bool = false
var _active_category: StringName = &""
var _context_action_ids: Array[StringName] = [&"", &"", &"", &"", &"", &""]
var _movement_mode: StringName = &"normal"
var _last_status_message: String = "Ready."
var _active_hand_name: String = ""
var _active_hand_item: String = ""
var _active_hand_item_id: StringName = &""
var _selected_weapon_hand_kind: StringName = &""
var _selected_weapon_item_id: StringName = &""
var _selected_hand_by_unit_id: Dictionary = {}
var _contextual_attack_hover_active: bool = false
var _unit_management_window: UnitManagementWindow
var _combat_log: Variant
var _mission_resolution_window: TacticalMissionResolutionWindow
var _mission_resolution_request_in_progress: bool = false
var _attack_targeting: bool = false
var _first_aid_targeting: bool = false
var _grapple_targeting: bool = false
var _selected_attack_id: StringName = &""
var _selected_attack_target_id: StringName = &""
var _power_attack_value: int = 0
var _selected_damage_channel: StringName = (
	TacticalUnitState.DAMAGE_CHANNEL_LETHAL
)
var _legal_attack_target_ids: Array[StringName] = []
var _attack_preview
var _attack_origin_override: Variant = null

# Stage 4.5e1 enters targeting mode before any legal-target scan. The scan is
# deferred to the next idle step so the cursor, status and board mode can render
# immediately. Exact per-target previews remain hover/click driven.
var _attack_targeting_generation: int = 0
var _attack_selection_started_usec: int = 0
var _attack_selections: int = 0
var _deferred_attack_target_scans: int = 0
var _last_attack_selection_total_usec: int = 0
var _last_attack_target_scan_usec: int = 0
var _targeted_attack_presentation_refreshes: int = 0

# Stage 4.5e2 lets the impact event render before broad attack reconciliation.
# Attack state changes are collapsed into one deferred refresh, while the old
# contextual target under the cursor remains cleared until mouse movement.
var _post_attack_reconciliation_scheduled: bool = false
var _pending_post_attack_reasons: Dictionary = {}
var _pending_post_attack_flags: TacticalInvalidationFlags
var _active_state_change_flags: TacticalInvalidationFlags
var _post_attack_reconciliations: int = 0
var _post_attack_refreshes_avoided: int = 0
var _immediate_combat_impacts_presented: int = 0
var _last_post_attack_reconciliation_usec: int = 0
var _legal_attack_targets_dirty: bool = false

# Stage 4.5e4 acknowledges a valid hostile click without inserting a rendered
# frame before authoritative commitment. The command pulse is fire-and-forget;
# the current click frame proceeds directly into the cached-preview commit path.
var _attack_command_in_progress: bool = false
var _attack_command_acknowledgements: int = 0
var _attack_command_frame_yields: int = 0 # Legacy counter; must remain zero.
var _attack_command_dead_frames_avoided: int = 0
var _attack_click_started_usec: int = 0
var _last_attack_click_to_result_usec: int = 0
var _last_attack_click_to_impact_usec: int = 0
var _attack_clicks_using_primed_preview: int = 0
var _attack_click_preview_fallbacks: int = 0
var _opening_popup: PopupMenu
var _opening_menu_options: Array[Dictionary] = []
var _interact_mode_active: bool = false
var _context_opening_id: StringName = &""
var _context_structure_id: StringName = &""
var _context_corner_tile: Vector2i = Vector2i(-1, -1)
var _initiative_ai_in_progress: bool = false
var _initiative_normalization_pending: bool = false
var _facing_commit_in_progress: bool = false
var _last_tactical_mode: StringName = TacticalPhaseState.MODE_SIDE_BASED
var _known_aware_enemy_squad_ids: Dictionary = {}
var _alert_flash: ColorRect
# Presentation keeps a tiny signature cache so HP-driven body-state emblems are
# reconciled on the very next rendered frame even if a future command path
# forgets to request a full HUD refresh. This is presentation-only state; the
# authoritative life state remains on TacticalUnitState.
var _life_state_visual_signature_by_unit_id: Dictionary = {}

# Stage 4.4e1 separates immediate authoritative movement commits from the
# presentation tween. State-change callbacks are collected while the move is
# committed/animated so they cannot snap tokens or rebuild geometry first.
var _movement_commit_in_progress: bool = false
var _movement_animation_active: bool = false
var _animating_unit_ids: Dictionary = {}
var _movement_presentation_unit_ids: Dictionary = {}
var _movement_force_full_visibility: bool = false
var _movement_presentation_started_usec: int = 0
var _last_movement_handoff_total_usec: int = 0
var _last_post_movement_refresh_usec: int = 0
var _targeted_post_movement_refresh_count: int = 0
var _deferred_state_change_reasons: Dictionary = {}
var _deferred_state_change_flags: Dictionary = {}
var _post_commit_perception_flush_scheduled: bool = false
var _deferred_damage_events: Array[Dictionary] = []
var _pending_ai_movement_events: Array[Dictionary] = []
var _pending_movement_cadence_event: int = PresentationCadenceEvent.NONE
var _movement_control_owner_before_commit: StringName = &""
var _movement_interruption_pending: bool = false
var _visible_enemy_unit_ids_before_movement: Dictionary = {}
var _last_cadence_event: int = PresentationCadenceEvent.NONE
var _last_cadence_seconds: float = 0.0
var _cadence_event_count_by_kind: Dictionary = {}
var _cadence_wait_depth: int = 0
var _queued_state_cadence_event: int = PresentationCadenceEvent.NONE
var _queued_state_cadence_unit_id: StringName = &""
var _state_cadence_runner_scheduled: bool = false
var _contact_presentation_ready_unit_id: StringName = &""
var _contact_ai_warmup_started_usec: int = 0
var _contact_ai_warmup_completed_usec: int = 0
var _contact_ai_warmup_processing_usec: int = 0
var _contact_ai_warmup_frames: int = 0
var _contact_ai_warmup_abandoned: bool = false
var _contact_detected_usec: int = 0
var _contact_ai_pulse_started_usec: int = 0
var _contact_first_movement_tween_started_usec: int = 0
var _duplicate_contact_refreshes_avoided: int = 0
var _last_handoff_pulsed_unit_id: StringName = &""
var _last_ai_resolution_observable: bool = false
var _enemy_phase_had_observable_activity: bool = false
var _unobserved_ai_movement_batches_completed_immediately: int = 0
var _unobserved_ai_movement_events_skipped: int = 0
var _partially_observed_ai_movement_events_presented: int = 0
var _observed_ai_movement_events_presented: int = 0
var _unobserved_ai_activation_handoffs_skipped: int = 0
var _unobserved_enemy_phase_handoffs_skipped: int = 0
var _enemy_phase_frame_yields: int = 0
var _enemy_phase_hidden_activations_batched: int = 0
var _side_based_enemy_activation_pulses: int = 0
var _observable_stationary_activation_frame_yields: int = 0
var _last_ai_activation_presented_movement: bool = false
var _last_ai_visible_movement_duration_seconds: float = 0.0
var _last_ai_activation_simulation_usec: int = 0
var _last_ai_activation_presentation_usec: int = 0
var _last_ai_activation_total_usec: int = 0
var _enemy_planning_slice_count: int = 0
var _enemy_planning_yield_count: int = 0
var _enemy_planning_max_slices_per_frame: int = 0
var _enemy_hidden_planning_frames: int = 0
var _destination_visibility_yield_count: int = 0
var _destination_visibility_same_frame_completions: int = 0
var _destination_visibility_final_budget_overruns: int = 0
var _visible_activation_dead_frames_avoided: int = 0
var _enemy_phase_requested_usec: int = 0
var _end_phase_to_first_enemy_feedback_usec: int = 0
var _end_phase_to_first_visible_action_usec: int = 0
var _first_enemy_feedback_recorded: bool = false
var _first_visible_enemy_action_recorded: bool = false
var _end_phase_to_first_visible_movement_usec: int = 0
var _frames_yielded_before_first_visible_action: int = 0
var _hidden_actors_before_first_visible_action: int = 0
var _enemy_phase_committed_usec: int = 0
var _first_actor_feedback_started_usec: int = 0
var _first_movement_tween_started_usec: int = 0
var _ai_destination_visibility_pump_active: bool = false
var _movement_handoff_finishing: bool = false
# Hotfix 5f5: safe AI planning is moved into player decision time so End Turn
# becomes a handoff rather than the point where enemy thinking begins.
var _player_to_enemy_handoff_in_progress: bool = false
var _handoff_requested_usec: int = 0
var _handoff_feedback_started_usec: int = 0
var _handoff_to_authoritative_commit_usec: int = 0
var _handoff_to_movement_tween_usec: int = 0
var _handoff_idle_warmup_processing_usec: int = 0
var _handoff_idle_warmup_frames: int = 0
var _handoff_warmup_ready_frames: int = 0
var _handoff_full_refreshes_avoided: int = 0
var _handoff_duplicate_ai_schedules_avoided: int = 0
# Hotfix 5f6 pipelines consecutive enemies: the next actor is planned while the
# current actor's cosmetic movement/damage presentation is still playing.
var _prepared_ai_presentation_unit_id: StringName = &""
var _chain_warmup_processing_usec: int = 0
var _chain_warmup_frames: int = 0
var _chain_warmup_ready_frames: int = 0
var _chain_warmup_reused_count: int = 0
var _duplicate_enemy_refreshes_avoided: int = 0
var _hidden_actor_refreshes_avoided: int = 0
var _forced_inter_actor_frames_avoided: int = 0
var _presentation_wall_time_excluded_usec: int = 0
var _last_enemy_to_enemy_handoff_usec: int = 0
var _enemy_handoff_started_usec: int = 0
var _enemy_highlight_started_usec: int = 0
var _last_enemy_highlight_to_action_usec: int = 0
var _pre_activation_handoff_validations: int = 0
# Hotfix 5f8 records the exact live planning stage whenever a highlighted
# enemy has not produced movement or an attack within a latency threshold.
var _enemy_stall_active_unit_id: StringName = &""
var _enemy_stall_thresholds_emitted: Dictionary = {}
var _enemy_stall_history: Array[Dictionary] = []
var _enemy_stall_threshold_event_count: int = 0
# Hotfix 5f9 keeps contact non-blocking and adds only adaptive readability
# spacing after visible actions that supplied no meaningful movement time.
var _blocking_alert_acknowledgement_usec: int = 0
var _adaptive_visible_handoff_usec: int = 0
var _adaptive_visible_handoff_count: int = 0
# Hotfix 5f10 suppresses broad presentation reconciliation for one authoritative
# batch of completely hidden no-action actors, then publishes one final refresh
# when control returns to the player.
var _hidden_auto_pass_refreshes_avoided: int = 0
var _last_empty_enemy_phase_usec: int = 0
var _end_phase_to_player_control_restored_usec: int = 0
var _enemy_phase_input_lock_started_usec: int = 0

# Stage 4.5 player Reaction decision presentation. The application layer owns
# legality and resolution; this panel only returns the selected choice.
var _reaction_prompt: PanelContainer
var _reaction_prompt_icon: TextureRect
var _reaction_prompt_title: Label
var _reaction_prompt_body: RichTextLabel
var _reaction_prompt_primary: Button
var _reaction_prompt_secondary: Button
var _reaction_prompt_request: ReactionDecisionRequest
var _reaction_decision_serial: int = 0
var _reaction_decision_resolved_serial: int = 0


func configure(session: TacticalSession) -> void:
	_facade = session.screen_facade if session != null else null


func _ready() -> void:
	if _facade == null:
		push_error("TacticalScreen requires a configured TacticalScreenFacade.")
		return

	if (
		_board_view == null
		or _board_view.get_script() != TACTICAL_BOARD_VIEW_SCRIPT
		or not _board_view.has_method("configure")
	):
		push_error(
			"TacticalScreen requires BoardView to use "
			+ "tactical_board_view.gd."
		)
		return

	_map_definition = _facade.map_definition()
	_player_unit_order = _facade.player_unit_order()
	_portrait_resolver = PortraitAssetResolver.new()

	_board_view.configure(_map_definition, _facade)
	_board_view.tile_hovered.connect(_on_board_tile_hovered)
	_board_view.tile_left_clicked.connect(_on_board_tile_left_clicked)
	_board_view.interaction_target_clicked.connect(_on_board_interaction_target_clicked)
	_board_view.board_right_clicked.connect(_on_board_right_clicked)
	_opening_popup = PopupMenu.new()
	_opening_popup.name = "OpeningContextMenu"
	$HUD.add_child(_opening_popup)
	_opening_popup.id_pressed.connect(_on_opening_menu_selected)

	_combat_log = TACTICAL_COMBAT_LOG_SCENE.instantiate()
	$HUD.add_child(_combat_log)
	if (
		_combat_log != null
		and _combat_log.has_method("configure")
	):
		_combat_log.call("configure", _facade.event_journal())

	_mission_resolution_window = (
		MISSION_RESOLUTION_WINDOW_SCRIPT.new()
		as TacticalMissionResolutionWindow
	)
	$HUD.add_child(_mission_resolution_window)
	_mission_resolution_window.cancelled.connect(
		_on_mission_resolution_cancelled
	)
	_mission_resolution_window.confirm_requested.connect(
		_on_mission_resolution_confirmed
	)
	_mission_resolution_window.continue_requested.connect(
		_on_mission_summary_continue
	)

	_unit_management_window = (
		UNIT_MANAGEMENT_WINDOW_SCENE.instantiate()
		as UnitManagementWindow
	)
	$HUD.add_child(_unit_management_window)
	var initial_unit_id: StringName = (
		_player_unit_order[0]
		if not _player_unit_order.is_empty()
		else &""
	)
	_unit_management_window.configure(
		_facade,
		_portrait_resolver,
		initial_unit_id,
		_player_unit_order
	)
	_unit_management_window.closed.connect(_on_unit_management_closed)
	_unit_management_window.unit_changed.connect(
		_on_unit_management_unit_changed
	)
	_unit_management_window.message_requested.connect(_set_status)

	_create_roster_buttons()

	_facade.state_changed.connect(_on_state_changed)
	_facade.state_changed_with_flags.connect(_on_state_changed_with_flags)
	_facade.damage_committed.connect(_on_damage_committed)
	_facade.movement_committed.connect(_on_ai_movement_committed)
	_facade.reaction_decision_requested.connect(_on_reaction_decision_requested)
	_facade.reaction_decision_cleared.connect(_on_reaction_decision_cleared)
	_create_reaction_prompt()
	var restored_reaction_request: ReactionDecisionRequest = (
		_facade.pending_reaction_decision()
	)
	if restored_reaction_request != null:
		_on_reaction_decision_requested(restored_reaction_request)


	_abilities_button.pressed.connect(func() -> void: _toggle_action_category(&"abilities"))
	_tactics_button.pressed.connect(func() -> void: _toggle_action_category(&"tactics"))
	_inventory_button.pressed.connect(_toggle_inventory)
	_interact_button.pressed.connect(_toggle_interact_mode)
	_end_unit_button.pressed.connect(_on_end_unit_pressed)
	_extract_button.pressed.connect(_on_extract_pressed)
	_end_phase_button.pressed.connect(_on_end_phase_pressed)

	for index: int in range(_context_action_buttons.size()):
		_context_action_buttons[index].pressed.connect(
			_on_context_action_pressed.bind(index)
		)

	_left_hand_button.pressed.connect(
		_select_weapon_from_hand.bind(TacticalInventoryState.KIND_SECONDARY_HAND)
	)
	_right_hand_button.pressed.connect(
		_select_weapon_from_hand.bind(TacticalInventoryState.KIND_PRIMARY_HAND)
	)
	_attack_mode_button.pressed.connect(_cycle_attack_mode)
	_power_attack_down_button.pressed.connect(_adjust_power_attack.bind(-1))
	_power_attack_value_button.pressed.connect(_cycle_power_attack)
	_power_attack_up_button.pressed.connect(_adjust_power_attack.bind(1))

	_create_alert_flash()
	_last_tactical_mode = _facade.state().phase_state.tactical_mode
	_known_aware_enemy_squad_ids = _aware_enemy_squad_id_set()
	_create_unit_views()
	if not initial_unit_id.is_empty():
		_select_unit(initial_unit_id)
		_center_camera_on_selected_unit()
	_set_status(
		"Stage 4.5 active: shared Reactions, threatened movement, Overwatch and Brace are enabled."
	)
	_refresh_all_presentation()


func _process(_delta: float) -> void:
	# Life-state visuals are event-driven from committed tactical changes. Only
	# the cursor-attached preview needs per-frame positioning.
	if _attack_cursor_preview != null and _attack_cursor_preview.visible:
		_position_attack_cursor_preview()
	_step_idle_enemy_handoff_warmup()


func _step_idle_enemy_handoff_warmup() -> void:
	if (
		_facade == null
		or not is_inside_tree()
		or _facade.mission_resolution_locked()
		or _player_to_enemy_handoff_in_progress
		or _movement_commit_in_progress
		or _reaction_prompt_request != null
		or _inventory_open
		or _mission_resolution_request_in_progress
		or _attack_command_in_progress
		or _facing_commit_in_progress
	):
		return

	# Player-time warmup remains available while the player is deciding. During
	# an Enemy Phase, lookahead is permitted only after the current actor has
	# committed: movement/cadence presentation then supplies safe rendered frames.
	var chain_overlap: bool = (
		(
			_movement_animation_active
			and (_initiative_ai_in_progress or _world_phase_in_progress)
		)
		or (
			_cadence_wait_depth > 0
			and (_initiative_ai_in_progress or _world_phase_in_progress)
		)
	)
	var player_idle: bool = (
		not _initiative_ai_in_progress
		and not _world_phase_in_progress
		and not _movement_animation_active
		and _cadence_wait_depth <= 0
	)
	if not chain_overlap and not player_idle:
		return
	var next_ai_id: StringName = _facade.peek_next_ai_handoff_unit_id()
	if next_ai_id.is_empty():
		return
	var budget_usec: int = (
		ENEMY_CHAIN_WARMUP_BUDGET_USEC
		if chain_overlap
		else ENEMY_HANDOFF_IDLE_WARMUP_BUDGET_USEC
	)
	var started_usec: int = Time.get_ticks_usec()
	var result: OperationResult = _facade.warmup_next_ai_handoff(budget_usec)
	var elapsed_usec: int = maxi(0, Time.get_ticks_usec() - started_usec)
	_handoff_idle_warmup_processing_usec += elapsed_usec
	_handoff_idle_warmup_frames += 1
	if chain_overlap:
		_chain_warmup_processing_usec += elapsed_usec
		_chain_warmup_frames += 1
	if result != null and result.code == &"enemy_handoff_warmup_ready":
		_handoff_warmup_ready_frames += 1
		if chain_overlap:
			_chain_warmup_ready_frames += 1


func _unhandled_input(event: InputEvent) -> void:
	if _reaction_prompt_request != null:
		if event is InputEventMouseButton:
			var reaction_mouse := event as InputEventMouseButton
			if reaction_mouse.pressed and reaction_mouse.button_index == MOUSE_BUTTON_RIGHT:
				_resolve_visible_reaction_prompt(false)
			return
		if event is InputEventKey:
			var reaction_key := event as InputEventKey
			if reaction_key.pressed and not reaction_key.echo:
				if reaction_key.keycode == KEY_ENTER or reaction_key.keycode == KEY_KP_ENTER:
					_resolve_visible_reaction_prompt(true)
				elif reaction_key.keycode == KEY_ESCAPE:
					_resolve_visible_reaction_prompt(false)
			return
		return
	if _mission_resolution_window != null and _mission_resolution_window.is_open():
		if event is InputEventKey:
			var modal_key := event as InputEventKey
			if (
				modal_key.pressed
				and not modal_key.echo
				and modal_key.keycode == KEY_ESCAPE
			):
				_mission_resolution_window.close_confirmation()
		return
	if _facade.mission_resolution_locked():
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return

		if key_event.keycode == KEY_C:
			_center_camera_on_selected_unit()
			return

		if key_event.keycode == KEY_F9:
			_print_tactical_performance_snapshot()
			return

		if key_event.keycode == KEY_L:
			if (
				not _inventory_open
				and _combat_log != null
				and _combat_log.has_method("toggle_expanded")
			):
				_combat_log.call("toggle_expanded")
			return

		if _inventory_open:
			return

		match key_event.keycode:
			KEY_I:
				_toggle_inventory()
			KEY_A:
				_select_weapon_from_hand(TacticalInventoryState.KIND_PRIMARY_HAND)
			KEY_ESCAPE:
				if _grapple_targeting:
					_cancel_grapple_targeting("Grapple targeting cancelled.")
				elif _first_aid_targeting:
					_cancel_first_aid_targeting("First Aid targeting cancelled.")
				elif _attack_targeting:
					_clear_weapon_selection("Weapon targeting cancelled.")
				elif _board_intent_mode == BoardIntentMode.MOVE_PREVIEW:
					_cancel_move_preview("Movement preview cancelled.")
				elif _board_intent_mode == BoardIntentMode.FACING_PREVIEW:
					_cancel_facing_preview("Facing preview cancelled.")
				elif _board_intent_mode in [BoardIntentMode.OVERWATCH_PREVIEW, BoardIntentMode.BRACE_PREVIEW]:
					_cancel_reaction_reservation_preview("Reaction targeting cancelled.")
				elif _movement_mode != &"normal":
					_movement_mode = &"normal"
					_set_status("Special movement mode cancelled.")
					_refresh_all_presentation()
				elif _active_category != &"":
					_hide_context_tray()
				else:
					_clear_board_intent()
					_selected_unit_id = &""
					_selected_cover_category = &"neutral"
					_update_unit_selection_visuals()
					_set_status("Unit deselected.")
					_refresh_all_presentation()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				_select_unit_by_shortcut(int(key_event.keycode - KEY_1))
		return

func _on_board_tile_hovered(tile: Vector2i) -> void:
	if _inventory_open or tile == _hovered_tile:
		return
	_hovered_tile = tile

	if _board_intent_mode in [BoardIntentMode.OVERWATCH_PREVIEW, BoardIntentMode.BRACE_PREVIEW]:
		_update_reaction_reservation_preview(tile)
	else:
		# Empty-tile hover is deliberately presentation-only. Movement pathfinding,
		# destination cover and movement commitment begin only after the first left
		# click. This keeps an existing clicked path locked while the cursor moves.
		var previous_attack_target_id: StringName = _selected_attack_target_id
		var previous_contextual_attack_hover: bool = _contextual_attack_hover_active
		if _first_aid_targeting:
			_refresh_first_aid_hover_preview()
		elif _attack_targeting:
			_refresh_attack_hover_preview()
		else:
			_refresh_contextual_hand_attack_hover_preview()

		# The full HUD changes only when an attack-hover context begins, ends or
		# changes target. Ordinary tile hover needs only the cheap board redraw.
		if (
			previous_attack_target_id != _selected_attack_target_id
			or previous_contextual_attack_hover != _contextual_attack_hover_active
		):
			_hover_hud_refresh_count += 1
			_refresh_hud()
	_hover_board_refresh_count += 1
	_refresh_board_view()


func _on_board_tile_left_clicked(tile: Vector2i) -> void:
	if _inventory_open or _attack_command_in_progress:
		return

	if _board_intent_mode in [BoardIntentMode.OVERWATCH_PREVIEW, BoardIntentMode.BRACE_PREVIEW]:
		_confirm_reaction_reservation_preview(tile)
		return

	if _first_aid_targeting:
		_execute_first_aid_at_tile(tile)
		return

	if _grapple_targeting:
		_execute_grapple_at_tile(tile)
		return

	if _interact_mode_active:
		_handle_interact_click(tile)
		return

	var clicked_unit: TacticalUnitState = _facade.visible_unit_at_tile(
		tile,
		_selected_unit_id
	)
	if (
		clicked_unit != null
		and _selected_unit_is_player_controlled()
		and _facade.are_units_hostile(
			_selected_unit_id,
			clicked_unit.unit_id
		)
	):
		# A hostile click is always interpreted as an attempted strike with the
		# selected hand. It never becomes movement or unit inspection.
		_clear_board_intent(false)
		_execute_direct_attack(clicked_unit)
		return

	if _attack_targeting:
		if clicked_unit != null:
			if not _facade.are_units_hostile(
				_selected_unit_id,
				clicked_unit.unit_id
			):
				# Friendly and neutral units remain selection/inspection targets.
				_select_unit(clicked_unit.unit_id)
				return
			_execute_direct_attack(clicked_unit)
		return
	if _board_intent_mode == BoardIntentMode.FACING_PREVIEW:
		_cancel_facing_preview("Facing preview cancelled.")
		return
	_handle_left_click(tile)


func _on_board_right_clicked(tile: Vector2i) -> void:
	if _inventory_open or _attack_command_in_progress:
		return
	if _interact_mode_active:
		_interact_mode_active = false
		_active_category = &""
		_context_tray.visible = false
	if _grapple_targeting:
		_cancel_grapple_targeting("Grapple targeting cancelled.")
		return
	if _first_aid_targeting:
		_cancel_first_aid_targeting("First Aid targeting cancelled.")
		return
	if _attack_targeting:
		_clear_weapon_selection("Weapon targeting cancelled.")
		return
	if _board_intent_mode == BoardIntentMode.MOVE_PREVIEW:
		_cancel_move_preview("Movement preview cancelled.")
		return
	if _board_intent_mode in [BoardIntentMode.OVERWATCH_PREVIEW, BoardIntentMode.BRACE_PREVIEW]:
		_cancel_reaction_reservation_preview("Reaction targeting cancelled.")
		return
	if _movement_mode != &"normal":
		_movement_mode = &"normal"
		_set_status("Special movement mode cancelled.")
		_clear_board_intent(false)
		_refresh_all_presentation()
		return
	if _selected_unit_id.is_empty():
		_set_status("Select a player character before setting facing.")
		return
	# Right-click is reserved for facing and cancelling. Environmental opening
	# interactions are deliberately routed through the existing Interact button.
	_begin_or_update_facing_preview(tile)


func _show_opening_context_menu(opening: TacticalOpeningDefinition) -> void:
	if _opening_popup == null or opening == null or _selected_unit_id.is_empty():
		return
	_context_opening_id = opening.opening_id
	_context_structure_id = &""
	_context_corner_tile = Vector2i(-1, -1)
	_opening_menu_options = _facade.opening_interaction_options(
		_selected_unit_id, opening.opening_id
	)
	var runtime: TacticalOpeningState = _facade.opening_runtime(opening.opening_id)
	var attack_is_meaningful: bool = (
		opening.opening_kind != TacticalOpeningDefinition.KIND_DOOR
		or runtime == null
		or runtime.locked
		or runtime.barred
		or runtime.jammed
		or runtime.state_id in [
			TacticalOpeningDefinition.STATE_DAMAGED,
			TacticalOpeningDefinition.STATE_BROKEN,
		]
	)
	if not _selected_attack_id.is_empty() and attack_is_meaningful:
		_opening_menu_options.append({
			"action_id": &"attack_opening",
			"display_name": "Attack %s" % opening.display_name,
			"cost_label": "Selected attack",
			"enabled": true,
			"rejection_reason": "",
			"icon_id": &"attack_structure",
		})
	if _opening_menu_options.is_empty():
		_set_status("No valid interaction is available for %s." % opening.display_name)
		return
	if _opening_menu_options.size() == 1 and bool(_opening_menu_options[0].get("enabled", false)):
		_execute_opening_interaction(_opening_menu_options[0])
		return
	_opening_popup.clear()
	for index: int in range(_opening_menu_options.size()):
		var option: Dictionary = _opening_menu_options[index]
		var label: String = String(option.get("display_name", "Interact"))
		var cost_label: String = String(option.get("cost_label", ""))
		if not cost_label.is_empty():
			label += " — " + cost_label
		_opening_popup.add_item(label, index)
		_opening_popup.set_item_disabled(index, not bool(option.get("enabled", false)))
	_opening_popup.position = Vector2i(get_viewport().get_mouse_position())
	_opening_popup.popup()


func _execute_opening_interaction(option: Dictionary) -> void:
	var action_id: StringName = StringName(option.get("action_id", &""))
	var result: OperationResult
	match action_id:
		&"toggle_opening":
			result = _facade.toggle_opening(_selected_unit_id, _context_opening_id)
		&"pick_lock":
			result = _facade.pick_opening_lock(_selected_unit_id, _context_opening_id)
		&"attack_opening":
			result = _facade.attack_environment_source(
				_selected_unit_id, _context_opening_id, _selected_attack_id
			)
		_:
			result = OperationResult.fail(&"interaction_unknown", "That interaction is unavailable.")
	_set_status(result.message)
	_interact_mode_active = false
	_active_category = &""
	_context_tray.visible = false
	_refresh_all_presentation()


func _show_structure_context_menu(structure: TacticalStructureDefinition) -> void:
	if _opening_popup == null or structure == null:
		return
	_context_opening_id = &""
	_context_structure_id = structure.structure_id
	_context_corner_tile = Vector2i(-1, -1)
	_opening_popup.clear()
	if _selected_attack_id.is_empty():
		_opening_popup.add_item("Select a weapon to attack this structure", 5)
		_opening_popup.set_item_disabled(0, true)
	else:
		_opening_popup.add_item("Attack %s" % structure.display_name, 4)
	_opening_popup.position = Vector2i(get_viewport().get_mouse_position())
	_opening_popup.popup()


func _on_opening_menu_selected(menu_id: int) -> void:
	if menu_id < 0 or menu_id >= _opening_menu_options.size():
		return
	_execute_opening_interaction(_opening_menu_options[menu_id])


func _begin_or_update_facing_preview(tile: Vector2i) -> void:
	if not _map_definition.is_inside(tile):
		return
	var direction: Vector2i = _facade.preview_facing_direction(
		_selected_unit_id,
		tile
	)
	if direction == Vector2i.ZERO:
		_set_status("Choose a different tile to set a facing direction.")
		return
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null or not unit.is_player_controlled():
		_set_status("Only an active player character can preview facing.")
		return
	if not _facade.can_unit_act(unit.unit_id):
		_set_status("This unit is not active in the current turn mode.")
		return

	if (
		_board_intent_mode == BoardIntentMode.FACING_PREVIEW
		and direction == _planned_facing
	):
		_confirm_facing_preview(tile)
		return

	if direction == unit.facing_direction:
		if _board_intent_mode == BoardIntentMode.FACING_PREVIEW:
			_cancel_facing_preview("Facing preview returned to the committed direction.")
		else:
			_set_status("This unit is already facing that direction.")
		return

	var reason: String = _facade.facing_unavailable_reason(
		_selected_unit_id,
		tile
	)
	if not reason.is_empty():
		_set_status(reason)
		return

	_clear_move_preview_state()
	_board_intent_mode = BoardIntentMode.FACING_PREVIEW
	_planned_facing = direction
	_facing_preview_direction = direction
	var unit_view := _unit_views.get(_selected_unit_id) as TacticalUnitView
	if unit_view != null:
		unit_view.preview_facing(direction)
	_set_status(
		"Preview Face %s (%d ft). Right-click the same direction to confirm; left-click cancels."
		% [
			_facing_label(direction),
			_facade.face_direction_cost_feet(),
		]
	)
	_refresh_hud()
	_refresh_board_view()


func _confirm_facing_preview(tile: Vector2i) -> void:
	_facing_commit_in_progress = true
	var result: OperationResult = _facade.face_direction(
		_selected_unit_id,
		tile
	)
	_facing_commit_in_progress = false
	if not result.success:
		_cancel_facing_preview(result.message)
		return
	var unit_view := _unit_views.get(_selected_unit_id) as TacticalUnitView
	if unit_view != null:
		unit_view.commit_facing_preview(_planned_facing)
	_clear_facing_preview_state()
	_set_status(result.message)
	_refresh_all_presentation()


func _cancel_facing_preview(message: String = "") -> void:
	if _board_intent_mode == BoardIntentMode.FACING_PREVIEW:
		var unit_view := _unit_views.get(_selected_unit_id) as TacticalUnitView
		if unit_view != null:
			unit_view.cancel_facing_preview()
	_clear_facing_preview_state()
	if not message.is_empty():
		_set_status(message)
	_refresh_hud()
	_refresh_board_view()


func _clear_facing_preview_state() -> void:
	if _board_intent_mode == BoardIntentMode.FACING_PREVIEW:
		_board_intent_mode = BoardIntentMode.NONE
	_planned_facing = Vector2i.ZERO
	_facing_preview_direction = Vector2i.ZERO


func _cancel_move_preview(message: String = "") -> void:
	_clear_move_preview_state()
	if not message.is_empty():
		_set_status(message)
	_refresh_hud()
	_refresh_board_view()


func _clear_move_preview_state() -> void:
	if _board_intent_mode == BoardIntentMode.MOVE_PREVIEW:
		_board_intent_mode = BoardIntentMode.NONE
	_planned_destination = INVALID_BOARD_TILE
	_clear_destination_preview_visuals()


func _clear_destination_preview_visuals() -> void:
	_preview_result = null
	_detection_preview = null
	_reaction_preview = null
	_cover_preview = null
	_directional_cover_field = null


func _clear_board_intent(animate_facing_return: bool = true) -> void:
	if _board_intent_mode == BoardIntentMode.FACING_PREVIEW:
		var unit_view := _unit_views.get(_selected_unit_id) as TacticalUnitView
		if unit_view != null:
			if animate_facing_return:
				unit_view.cancel_facing_preview()
			else:
				unit_view.clear_facing_preview_immediately()
	_board_intent_mode = BoardIntentMode.NONE
	_planned_destination = INVALID_BOARD_TILE
	_planned_facing = Vector2i.ZERO
	_reaction_reservation_preview_tiles.clear()
	_reaction_reservation_preview_kind = &""
	_clear_destination_preview_visuals()
	_facing_preview_direction = Vector2i.ZERO


func _create_roster_buttons() -> void:
	for child: Node in _roster_container.get_children():
		if child.name in [&"MarauderButton", &"ArcherButton", &"ScoutButton"]:
			child.queue_free()
	_unit_buttons.clear()
	for index: int in range(_player_unit_order.size()):
		var unit_id: StringName = _player_unit_order[index]
		var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
		if unit == null:
			continue
		var button: Button = ROSTER_UNIT_BUTTON_SCRIPT.new() as Button
		button.name = "RosterUnit%d" % (index + 1)
		button.pressed.connect(_select_unit.bind(unit_id))
		_roster_container.add_child(button)
		_roster_container.move_child(button, 1 + index)
		button.call(
			"refresh_unit",
			unit,
			index + 1,
			_facade.state().phase_state.is_player_phase(),
			unit_id == _selected_unit_id
		)
		_unit_buttons[unit_id] = button


func _select_unit_by_shortcut(index: int) -> void:
	if index < 0 or index >= _player_unit_order.size():
		return
	_select_unit(_player_unit_order[index])


func _unit_color(unit: TacticalUnitState) -> Color:
	if unit.team_id != &"player":
		return (
			Color(0.78, 0.20, 0.16, 1.0)
			if unit.roster_role == &"enemy"
			else Color(0.78, 0.68, 0.28, 1.0)
		)
	var index: int = _player_unit_order.find(unit.unit_id)
	var palette: Array[Color] = [
		Color(0.14, 0.46, 0.90, 1.0),
		Color(0.14, 0.68, 0.38, 1.0),
		Color(0.64, 0.30, 0.82, 1.0),
		Color(0.80, 0.42, 0.16, 1.0),
		Color(0.16, 0.66, 0.72, 1.0),
	]
	return palette[posmod(index, palette.size())] if index >= 0 else Color.WHITE


func _create_unit_views() -> void:
	for unit: TacticalUnitState in _facade.state().get_units():
		var view := UNIT_VIEW_SCENE.instantiate() as TacticalUnitView
		_unit_layer.add_child(view)
		var display_color: Color = _unit_color(unit)
		view.configure(
			unit,
			_board_view.board_origin(),
			_board_view.tile_size(),
			display_color
		)
		_unit_views[unit.unit_id] = view
		view.movement_animation_finished.connect(
			_on_unit_movement_animation_finished
		)
		view.movement_reaction_presentation.connect(
			_on_movement_reaction_presentation
		)


func _handle_left_click(tile: Vector2i) -> void:
	if not _map_definition.is_inside(tile):
		return
	if not _facade.state().phase_state.is_player_phase():
		_set_status("Wait for the Enemy and World Phases to finish.")
		return

	var clicked_unit: TacticalUnitState = _facade.visible_unit_at_tile(tile)
	if clicked_unit != null:
		_clear_board_intent()
		_select_unit(clicked_unit.unit_id)
		return

	if _selected_unit_id == &"":
		_set_status("Select a friendly unit before choosing a destination.")
		return

	if (
		_board_intent_mode == BoardIntentMode.MOVE_PREVIEW
		and tile == _planned_destination
	):
		_confirm_planned_movement()
		return

	_begin_or_update_move_preview(tile)


func _begin_or_update_move_preview(tile: Vector2i) -> void:
	var selected_unit: TacticalUnitState = _facade.state().get_unit(
		_selected_unit_id
	)
	if selected_unit == null:
		return
	if not selected_unit.is_player_controlled():
		_set_status("This unit is available for inspection only.")
		return
	if selected_unit.is_defeated():
		_set_status("Defeated units cannot move.")
		return
	if not _facade.can_unit_act(selected_unit.unit_id):
		_set_status("This unit is not active in the current turn mode.")
		return

	var hidden_occupant: TacticalUnitState = _facade.state().get_unit_at_tile(
		tile,
		_selected_unit_id
	)
	if (
		hidden_occupant != null
		and not _facade.is_unit_visible_to_player(hidden_occupant.unit_id)
	):
		_set_status("That destination is obscured by fog of war.")
		return

	var occupying_unit: TacticalUnitState = _facade.visible_unit_at_tile(
		tile,
		_selected_unit_id
	)
	if occupying_unit != null:
		_set_status("%s occupies that tile." % occupying_unit.display_name)
		return

	var destination_preview: TacticalDestinationPreview = (
		_destination_preview_for(selected_unit, tile)
	)
	var planned_path: MovementPathResult = (
		destination_preview.path_result
		if destination_preview != null
		else null
	)
	if planned_path == null or not planned_path.success:
		var reason := "That destination cannot be reached."
		if planned_path != null and not planned_path.failure_reason.is_empty():
			reason = planned_path.failure_reason
		_set_status(reason)
		return

	if _board_intent_mode == BoardIntentMode.FACING_PREVIEW:
		_cancel_facing_preview()
	_board_intent_mode = BoardIntentMode.MOVE_PREVIEW
	_planned_destination = tile
	_apply_destination_preview(destination_preview)
	_planned_facing = Vector2i.ZERO
	_facing_preview_direction = Vector2i.ZERO
	_set_status(
		"Movement preview ready. Left-click the destination again to move; right-click cancels."
	)
	_refresh_hud()
	_refresh_board_view()


func _confirm_planned_movement() -> void:
	if (
		_board_intent_mode != BoardIntentMode.MOVE_PREVIEW
		or _planned_destination == INVALID_BOARD_TILE
		or _movement_animation_active
	):
		return
	var destination: Vector2i = _planned_destination
	var moving_unit_id: StringName = _selected_unit_id
	var dragged_body_cells_before: Dictionary = (
		_dragged_body_visual_cells(moving_unit_id)
	)
	var geometry_revision_before: int = _facade.geometry_revision()
	_movement_control_owner_before_commit = moving_unit_id

	# State commits synchronously. Hold state-change presentation until the
	# completed path has started animating so visibility/cover work cannot block
	# the first rendered movement frame or snap the token to the destination.
	_facade.begin_visibility_recalculation_deferral()
	_movement_commit_in_progress = true
	var result: OperationResult = _facade.execute_movement(
		moving_unit_id,
		destination,
		_movement_mode
	)
	_movement_commit_in_progress = false

	if not result.success:
		# Releasing deferred perception may itself commit state changes. Keep the
		# presentation gate raised until those callbacks have been collected.
		_movement_commit_in_progress = true
		_facade.end_visibility_recalculation_deferral()
		_movement_commit_in_progress = false
		_flush_deferred_state_changes_without_animation()
		_set_status(result.message)
		# Keep the route visible so the player can understand a stale-plan
		# rejection and choose another destination or cancel it.
		_begin_or_update_move_preview(destination)
		return

	var completed_path := result.data as MovementPathResult
	var completed_tiles: Array[Vector2i] = []
	if completed_path != null:
		completed_tiles = completed_path.path.duplicate()
	_movement_interruption_pending = (
		not completed_tiles.is_empty()
		and completed_tiles.back() != destination
	)
	_movement_mode = &"normal"
	_clear_move_preview_state()
	_set_status(result.message)
	_begin_movement_presentation(
		moving_unit_id,
		completed_tiles,
		dragged_body_cells_before,
		_facade.geometry_revision() != geometry_revision_before,
		completed_path.reaction_events if completed_path != null else []
	)


func _dragged_body_visual_cells(unit_id: StringName) -> Dictionary:
	var result: Dictionary = {}
	if _facade == null:
		return result
	for hand_kind: StringName in [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
	]:
		var item: TacticalItemInstanceState = _facade.state().get_hand_item(
			unit_id,
			hand_kind
		)
		if (
			item == null
			or not item.is_body()
			or item.location == null
			or item.location.transport_mode != &"dragging"
		):
			continue
		var cell: Vector2i = _facade.state().body_ground_cell(item)
		if cell.x >= 0:
			result[item.linked_unit_id] = cell
	return result


func _animate_dragged_body_paths(
		body_cells_before: Dictionary,
		carrier_path: Array[Vector2i],
		carrier_duration: float = -1.0
) -> Array[StringName]:
	var animated_ids: Array[StringName] = []
	if carrier_path.size() <= 1:
		return animated_ids
	for linked_unit_id_value: Variant in body_cells_before.keys():
		var linked_unit_id := StringName(linked_unit_id_value)
		var view := _unit_views.get(linked_unit_id) as TacticalUnitView
		if view == null:
			continue
		var body_path: Array[Vector2i] = []
		var starting_cell: Vector2i = body_cells_before[linked_unit_id_value]
		if starting_cell.x >= 0:
			body_path.append(starting_cell)
		for index: int in range(0, carrier_path.size() - 1):
			var cell: Vector2i = carrier_path[index]
			if body_path.is_empty() or body_path.back() != cell:
				body_path.append(cell)
		if view.animate_path(body_path, [], carrier_duration):
			animated_ids.append(linked_unit_id)
	return animated_ids


func _begin_movement_presentation(
		moving_unit_id: StringName,
		completed_path: Array[Vector2i],
		dragged_body_cells_before: Dictionary,
		force_full_visibility: bool = false,
		reaction_events: Array[Dictionary] = []
) -> void:
	var event: Dictionary = {
		"unit_id": moving_unit_id,
		"path": completed_path.duplicate(),
		"dragged_body_cells_before": dragged_body_cells_before.duplicate(true),
		"force_full_visibility": force_full_visibility,
		"reaction_events": reaction_events.duplicate(true),
	}
	var events: Array[Dictionary] = []
	events.append(event)
	_begin_movement_presentation_batch(events)


func _begin_movement_presentation_batch(events: Array[Dictionary]) -> void:
	_movement_animation_active = true
	_pending_movement_cadence_event = PresentationCadenceEvent.NONE
	_visible_enemy_unit_ids_before_movement = _visible_enemy_unit_id_set()
	_movement_presentation_started_usec = Time.get_ticks_usec()
	_animating_unit_ids.clear()
	_movement_presentation_unit_ids.clear()
	_movement_force_full_visibility = false
	if _board_view != null:
		_board_view.set_input_enabled(false)

	for event: Dictionary in events:
		var moving_unit_id: StringName = StringName(event.get("unit_id", &""))
		if moving_unit_id.is_empty():
			continue
		_movement_presentation_unit_ids[moving_unit_id] = true
		_movement_force_full_visibility = (
			_movement_force_full_visibility
			or bool(event.get("force_full_visibility", false))
		)
		var completed_path: Array[Vector2i] = _movement_path_from_event(event)
		var presentation_path: Array[Vector2i] = completed_path
		var moving_unit: TacticalUnitState = _facade.state().get_unit(
			moving_unit_id
		)
		if moving_unit != null and moving_unit.is_ai_controlled():
			var visibility_kind: int = _ai_movement_event_visibility(event)
			match visibility_kind:
				TacticalPresentationVisibility.UNOBSERVED:
					presentation_path.clear()
					_unobserved_ai_movement_events_skipped += 1
				TacticalPresentationVisibility.PARTIALLY_OBSERVED:
					presentation_path = _observable_ai_path_segment(completed_path)
					_partially_observed_ai_movement_events_presented += 1
					_last_ai_resolution_observable = true
				TacticalPresentationVisibility.OBSERVED:
					_observed_ai_movement_events_presented += 1
					_last_ai_resolution_observable = true
		var dragged_body_cells_before: Dictionary = {}
		var dragged_value: Variant = event.get("dragged_body_cells_before", {})
		if dragged_value is Dictionary:
			var dragged_dictionary: Dictionary = dragged_value
			dragged_body_cells_before = dragged_dictionary.duplicate(true)

		var reaction_events: Array[Dictionary] = []
		var reaction_value: Variant = event.get("reaction_events", [])
		if reaction_value is Array:
			for reaction_event_value: Variant in reaction_value:
				if reaction_event_value is Dictionary:
					reaction_events.append((reaction_event_value as Dictionary).duplicate(true))
		var moving_view := _unit_views.get(moving_unit_id) as TacticalUnitView
		if moving_view != null and not presentation_path.is_empty():
			moving_view.visible = true
		var movement_duration: float = _movement_animation_duration(
			moving_unit,
			presentation_path
		)
		if (
			moving_unit != null
			and moving_unit.is_ai_controlled()
			and movement_duration > 0.0
		):
			_last_ai_visible_movement_duration_seconds = maxf(
				_last_ai_visible_movement_duration_seconds,
				movement_duration
			)
		if (
			moving_view != null
			and moving_view.animate_path(
				presentation_path,
				reaction_events,
				movement_duration
			)
		):
			_animating_unit_ids[moving_unit_id] = true
		for body_unit_id: StringName in _animate_dragged_body_paths(
			dragged_body_cells_before,
			presentation_path,
			movement_duration
		):
			_animating_unit_ids[body_unit_id] = true

	if (
		_last_ai_resolution_observable
		and _handoff_to_movement_tween_usec == 0
		and _handoff_requested_usec > 0
	):
		_handoff_to_movement_tween_usec = maxi(
			0,
			Time.get_ticks_usec() - _handoff_requested_usec
		)
	if (
		_last_ai_resolution_observable
		and _first_movement_tween_started_usec == 0
		and _enemy_phase_requested_usec > 0
	):
		_first_movement_tween_started_usec = Time.get_ticks_usec()
		_end_phase_to_first_visible_movement_usec = maxi(
			0,
			_first_movement_tween_started_usec - _enemy_phase_requested_usec
		)
	if (
		_contact_detected_usec > 0
		and _contact_first_movement_tween_started_usec <= 0
		and _contact_ai_pulse_started_usec > 0
	):
		_contact_first_movement_tween_started_usec = Time.get_ticks_usec()

	# Player movement still uses its click-preview preparation fallback. Enemy
	# destination FOV is advanced asynchronously while the token tween is visible.
	var player_preparing_unit_ids: Array[StringName] = []
	for unit_id_value: Variant in _movement_presentation_unit_ids.keys():
		var unit_id := StringName(unit_id_value)
		var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
		if unit != null and unit.is_player_controlled():
			player_preparing_unit_ids.append(unit_id)
	if not player_preparing_unit_ids.is_empty():
		_facade.prepare_visibility_for_units(player_preparing_unit_ids)
	if _facade.has_pending_enemy_destination_visibility():
		call_deferred("_pump_ai_destination_visibility_during_movement")

	if _animating_unit_ids.is_empty():
		call_deferred("_finish_movement_presentation")


func _movement_animation_duration(
		unit: TacticalUnitState,
		path: Array[Vector2i]
) -> float:
	if path.size() <= 1:
		return 0.0
	if unit == null or not unit.is_ai_controlled():
		return -1.0
	var steps: int = path.size() - 1
	# Hotfix 5f9 slightly restores visual weight without returning to slow enemy
	# travel. Intermediate tiles remain linear; only the final step settles.
	var short_steps: int = mini(steps, 3)
	var duration: float = (
		AI_VISIBLE_MOVE_SHORT_START_SECONDS
		+ float(maxi(0, short_steps - 1)) * AI_VISIBLE_MOVE_SHORT_STEP_SECONDS
	)
	if steps > 3:
		duration += float(steps - 3) * AI_VISIBLE_MOVE_LONG_STEP_SECONDS
	# Legacy validation reference for the shared cap relationship:
	# minf(AI_VISIBLE_MOVE_ORDINARY_CAP_SECONDS, AI_VISIBLE_MOVE_MAX_SECONDS)
	var cap_seconds: float = (
		AI_VISIBLE_MOVE_ORDINARY_CAP_SECONDS
		if steps <= AI_VISIBLE_MOVE_ORDINARY_CAP_STEPS
		else AI_VISIBLE_MOVE_MAX_SECONDS
	)
	return minf(duration, cap_seconds)


func _movement_path_from_event(event: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var raw_path: Variant = event.get("path", [])
	if not (raw_path is Array):
		return path
	for tile_value: Variant in raw_path:
		if tile_value is Vector2i:
			path.append(tile_value)
	return path


func _ai_movement_event_visibility(event: Dictionary) -> int:
	var path: Array[Vector2i] = _movement_path_from_event(event)
	var visible_tiles: int = 0
	for tile: Vector2i in path:
		if _facade.is_tile_visible_to_player(tile):
			visible_tiles += 1
	var observable_reaction: bool = _movement_event_has_observable_reaction(event)
	var unit_id: StringName = StringName(event.get("unit_id", &""))
	var final_visible: bool = (
		not unit_id.is_empty()
		and _facade.is_unit_visible_to_player(unit_id)
	)
	if visible_tiles <= 0 and not final_visible and not observable_reaction:
		return TacticalPresentationVisibility.UNOBSERVED
	if (
		visible_tiles == path.size()
		and not path.is_empty()
		and not observable_reaction
	):
		return TacticalPresentationVisibility.OBSERVED
	return TacticalPresentationVisibility.PARTIALLY_OBSERVED


func _movement_event_has_observable_reaction(event: Dictionary) -> bool:
	var reaction_value: Variant = event.get("reaction_events", [])
	if not (reaction_value is Array):
		return false
	for reaction_event_value: Variant in reaction_value:
		if not (reaction_event_value is Dictionary):
			continue
		var reaction_event: Dictionary = reaction_event_value
		var source_id: StringName = StringName(
			reaction_event.get("source_unit_id", &"")
		)
		var target_id: StringName = StringName(
			reaction_event.get("target_unit_id", &"")
		)
		var source: TacticalUnitState = _facade.state().get_unit(source_id)
		var target: TacticalUnitState = _facade.state().get_unit(target_id)
		if (
			(source != null and source.is_player_controlled())
			or (target != null and target.is_player_controlled())
			or (not source_id.is_empty() and _facade.is_unit_visible_to_player(source_id))
			or (not target_id.is_empty() and _facade.is_unit_visible_to_player(target_id))
		):
			return true
	return false


func _observable_ai_path_segment(path: Array[Vector2i]) -> Array[Vector2i]:
	var best_segment: Array[Vector2i] = []
	var current_segment: Array[Vector2i] = []
	for tile: Vector2i in path:
		if _facade.is_tile_visible_to_player(tile):
			current_segment.append(tile)
			continue
		if current_segment.size() > best_segment.size():
			best_segment = current_segment.duplicate()
		current_segment.clear()
	if current_segment.size() > best_segment.size():
		best_segment = current_segment.duplicate()
	return best_segment


func _on_movement_reaction_presentation(event: Dictionary) -> void:
	var reactor_id: StringName = StringName(event.get("source_unit_id", &""))
	var target_id: StringName = StringName(event.get("target_unit_id", &""))
	var reactor_view := _unit_views.get(reactor_id) as TacticalUnitView
	if reactor_view != null:
		reactor_view.play_active_handoff_pulse()
	_apply_next_deferred_damage_event_for_target(target_id)
	var kind: String = String(event.get("reaction_kind", &"reaction")).replace("_", " ").capitalize()
	_set_status("%s resolves against %s." % [kind, _unit_display_name(target_id)])
	_refresh_hud()


func _apply_next_deferred_damage_event_for_target(target_id: StringName) -> void:
	if target_id.is_empty():
		return
	for index: int in range(_deferred_damage_events.size()):
		var damage_event: Dictionary = _deferred_damage_events[index]
		if StringName(damage_event.get("target_id", &"")) != target_id:
			continue
		_deferred_damage_events.remove_at(index)
		_apply_damage_committed_presentation(damage_event)
		return


func _unit_display_name(unit_id: StringName) -> String:
	var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
	return unit.display_name if unit != null else String(unit_id)


func _on_unit_movement_animation_finished(unit_id: StringName) -> void:
	_animating_unit_ids.erase(unit_id)
	if _movement_animation_active and _animating_unit_ids.is_empty():
		_finish_movement_presentation()


func _pump_ai_destination_visibility_during_movement() -> void:
	if _ai_destination_visibility_pump_active:
		return
	_ai_destination_visibility_pump_active = true
	while (
		_movement_animation_active
		and not _movement_handoff_finishing
		and _facade.has_pending_enemy_destination_visibility()
	):
		var frame_started_usec: int = Time.get_ticks_usec()
		while (
			_facade.has_pending_enemy_destination_visibility()
			and Time.get_ticks_usec() - frame_started_usec < 3000
		):
			var remaining_usec: int = maxi(
				250,
				3000 - (Time.get_ticks_usec() - frame_started_usec)
			)
			if _facade.step_pending_enemy_destination_visibility(remaining_usec):
				break
		if _facade.has_pending_enemy_destination_visibility():
			await get_tree().process_frame
	_ai_destination_visibility_pump_active = false


func _complete_pending_ai_destination_visibility(
		frame_budget_usec: int = ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC
) -> void:
	var safe_frame_budget_usec: int = maxi(250, frame_budget_usec)
	while _facade.has_pending_enemy_destination_visibility():
		var frame_started_usec: int = Time.get_ticks_usec()
		while (
			_facade.has_pending_enemy_destination_visibility()
			and Time.get_ticks_usec() - frame_started_usec
			< safe_frame_budget_usec
		):
			var remaining_usec: int = maxi(
				250,
				safe_frame_budget_usec
				- (Time.get_ticks_usec() - frame_started_usec)
			)
			if _facade.step_pending_enemy_destination_visibility(remaining_usec):
				break
		if _facade.has_pending_enemy_destination_visibility():
			_destination_visibility_yield_count += 1
			if not _first_visible_enemy_action_recorded:
				_frames_yielded_before_first_visible_action += 1
			await get_tree().process_frame


func _complete_pending_ai_destination_visibility_same_frame(
		final_budget_usec: int = AI_DESTINATION_VISIBILITY_FINAL_BUDGET_USEC
) -> void:
	if not _facade.has_pending_enemy_destination_visibility():
		return
	var started_usec: int = Time.get_ticks_usec()
	var safe_budget_usec: int = maxi(250, final_budget_usec)
	while (
		_facade.has_pending_enemy_destination_visibility()
		and Time.get_ticks_usec() - started_usec < safe_budget_usec
	):
		var remaining_usec: int = maxi(
			250,
			safe_budget_usec - (Time.get_ticks_usec() - started_usec)
		)
		if _facade.step_pending_enemy_destination_visibility(remaining_usec):
			break
	if not _facade.has_pending_enemy_destination_visibility():
		_destination_visibility_same_frame_completions += 1
		return

	# A rare cold field may exceed the final presentation allowance. Finish it in
	# the same handoff rather than inserting one or more empty rendered frames.
	# The earlier movement-time pump normally makes this fallback exceptional.
	_destination_visibility_final_budget_overruns += 1
	_facade.step_pending_enemy_destination_visibility(1_000_000)


func _finish_movement_presentation() -> void:
	if not _movement_animation_active or _movement_handoff_finishing:
		return
	_movement_handoff_finishing = true
	_animating_unit_ids.clear()
	# Most destination FOV work completes during the tween. Any cold-field
	# remainder is finished in this handoff without yielding an empty frame.
	_complete_pending_ai_destination_visibility_same_frame()

	var moved_unit_ids: Array[StringName] = []
	for unit_id_value: Variant in _movement_presentation_unit_ids.keys():
		moved_unit_ids.append(StringName(unit_id_value))
	moved_unit_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)

	# Stage 4.4e3 releases only the moved observers' visibility contributions for
	# ordinary movement. Geometry changes and removals retain the safe full
	# rebuild. Attacks request it only when their precise flags report a genuine
	# sight-field change. Perception remains behind
	# the same presentation boundary, so its internal commits are collected below.
	var force_full_visibility: bool = (
		_movement_force_full_visibility
		or _deferred_visibility_requires_full_rebuild()
	)
	_facade.end_visibility_recalculation_deferral_for_units(
		moved_unit_ids,
		force_full_visibility
	)
	_movement_animation_active = false

	var deferred_reasons: Array[StringName] = []
	for reason_value: Variant in _deferred_state_change_reasons.keys():
		deferred_reasons.append(StringName(reason_value))
	_deferred_state_change_reasons.clear()
	for reason: StringName in deferred_reasons:
		if _board_view != null and _board_view.has_method("notify_state_changed"):
			var deferred_flags: TacticalInvalidationFlags = (
				_deferred_state_change_flags.get(reason)
				as TacticalInvalidationFlags
			)
			if deferred_flags != null:
				_board_view.call("notify_state_changed", reason, deferred_flags)
			else:
				_board_view.call("notify_state_changed", reason)
	_deferred_state_change_flags.clear()

	_process_post_movement_refresh(deferred_reasons)
	_last_movement_handoff_total_usec = (
		Time.get_ticks_usec() - _movement_presentation_started_usec
		if _movement_presentation_started_usec > 0
		else 0
	)
	_movement_presentation_unit_ids.clear()
	_movement_force_full_visibility = false
	_movement_handoff_finishing = false
	_complete_movement_handoff_after_frame()

func _deferred_visibility_requires_full_rebuild() -> bool:
	for flags_value: Variant in _deferred_state_change_flags.values():
		var flags := flags_value as TacticalInvalidationFlags
		if flags != null and flags.visibility_changed:
			return true
	# Compatibility fallback for state changes that do not yet publish flags.
	for reason_value: Variant in _deferred_state_change_reasons.keys():
		var reason := StringName(reason_value)
		if not _deferred_state_change_flags.has(reason) and reason in [
			&"character_resolved",
			&"runtime_spawn",
			&"unit_removed",
			&"vision_blocker_changed",
			&"environment_geometry_changed",
			&"opening_state_changed",
			&"structure_state_changed",
			&"structure_attacked",
		]:
			return true
	return false


func _process_post_movement_refresh(
		deferred_reasons: Array[StringName]
) -> void:
	var started_usec: int = Time.get_ticks_usec()
	_destination_preview_cache.clear()
	_ensure_selected_unit_is_visible()
	_refresh_selected_cover_summary()

	# Detection may have transitioned the battle into initiative while the token
	# was moving. Select exactly one presentation cadence event for the complete
	# event chain so reveal, alert and handoff waits never stack.
	var phase_state: TacticalPhaseState = _facade.state().phase_state
	var aware_enemy_squad_ids: Dictionary = _aware_enemy_squad_id_set()
	var new_enemy_squad_alerted: bool = false
	for squad_value: Variant in aware_enemy_squad_ids.keys():
		if not _known_aware_enemy_squad_ids.has(squad_value):
			new_enemy_squad_alerted = true
			break
	var alert_triggered: bool = (
		_last_tactical_mode == TacticalPhaseState.MODE_SIDE_BASED
		and phase_state.is_initiative_combat()
		and new_enemy_squad_alerted
	)
	if alert_triggered:
		_reset_contact_transition_metrics()
		_play_alert_flash()
		_set_pending_movement_cadence(PresentationCadenceEvent.ALERT_TRIGGERED)
	_known_aware_enemy_squad_ids = aware_enemy_squad_ids
	_last_tactical_mode = phase_state.tactical_mode

	var visible_enemy_ids_after: Dictionary = _visible_enemy_unit_id_set()
	if (
		not alert_triggered
		and _has_new_dictionary_key(
			visible_enemy_ids_after,
			_visible_enemy_unit_ids_before_movement
		)
	):
		_set_pending_movement_cadence(PresentationCadenceEvent.ENEMY_REVEALED)
		_last_ai_resolution_observable = true
	if alert_triggered:
		_last_ai_resolution_observable = true

	if _movement_interruption_pending:
		_set_pending_movement_cadence(PresentationCadenceEvent.INTERRUPTION)

	if phase_state.is_initiative_combat():
		var active: TacticalUnitState = _facade.active_initiative_unit()
		if active != null and _unit_handoff_is_observable(active):
			_selected_unit_id = active.unit_id
			if alert_triggered and active.is_ai_controlled():
				_contact_presentation_ready_unit_id = active.unit_id
				_play_active_unit_handoff_pulse(active.unit_id)
			if (
				not _movement_control_owner_before_commit.is_empty()
				and active.unit_id != _movement_control_owner_before_commit
				and _last_handoff_pulsed_unit_id != active.unit_id
			):
				_set_pending_movement_cadence(
					PresentationCadenceEvent.ACTIVATION_HANDOFF
				)
				_play_active_unit_handoff_pulse(active.unit_id)

	_update_unit_selection_visuals()
	_update_unit_finished_visuals()
	_refresh_hud()
	_refresh_board_view()

	_targeted_post_movement_refresh_count += 1
	_last_post_movement_refresh_usec = Time.get_ticks_usec() - started_usec

	if _protagonist_is_dead():
		call_deferred("_resolve_campaign_defeat_if_needed")
		return
	if not _facade.player_force_can_continue():
		call_deferred("_resolve_tactical_defeat_if_needed")

func _complete_movement_handoff_after_frame() -> void:
	# A committed hit must become visible as soon as the movement presentation
	# reaches its final tile. Release the life-state badge and non-blocking crimson
	# pulse before any readability cadence so the player never sees an impact
	# followed by unexplained dead air. The following rendered frame presents the
	# final position, fog delta and hit confirmation together.
	_apply_deferred_damage_events()

	# Any additional wait now happens only for an authored visible consequence.
	# Move-to-attack no longer owns a separate cadence event. Ordinary movement
	# has no fixed dead-air after its final tile, while meaningful reveal, alert,
	# interruption and activation events retain their authored cadence.
	# their central cadence values.
	var cadence_event: int = _pending_movement_cadence_event
	_pending_movement_cadence_event = PresentationCadenceEvent.NONE
	await _await_presentation_cadence(cadence_event)

	_visible_enemy_unit_ids_before_movement.clear()
	_movement_control_owner_before_commit = &""
	_movement_interruption_pending = false
	if (
		_board_view != null
		and not _inventory_open
		and not _world_phase_in_progress
		and not _initiative_ai_in_progress
		and not _facade.mission_resolution_locked()
	):
		_board_view.set_input_enabled(true)
	movement_presentation_finished.emit()
	if not _initiative_ai_in_progress:
		_schedule_initiative_ai()

func _set_pending_movement_cadence(event_kind: int) -> void:
	if _cadence_priority(event_kind) > _cadence_priority(
		_pending_movement_cadence_event
	):
		_pending_movement_cadence_event = event_kind


func _cadence_priority(event_kind: int) -> int:
	match event_kind:
		PresentationCadenceEvent.ALERT_TRIGGERED:
			return 60
		PresentationCadenceEvent.ENEMY_REVEALED:
			return 50
		PresentationCadenceEvent.INTERRUPTION:
			return 40
		PresentationCadenceEvent.AI_MOVE_TO_ATTACK:
			return 30
		PresentationCadenceEvent.PHASE_HANDOFF:
			return 20
		PresentationCadenceEvent.ACTIVATION_HANDOFF:
			return 10
		_:
			return 0


func _cadence_seconds(event_kind: int) -> float:
	match event_kind:
		PresentationCadenceEvent.ACTIVATION_HANDOFF:
			return ACTIVATION_HANDOFF_SECONDS
		PresentationCadenceEvent.AI_MOVE_TO_ATTACK:
			return AI_MOVE_TO_ATTACK_SECONDS
		PresentationCadenceEvent.PHASE_HANDOFF:
			return PHASE_HANDOFF_SECONDS
		PresentationCadenceEvent.ENEMY_REVEALED:
			return REVEAL_ACKNOWLEDGEMENT_SECONDS
		PresentationCadenceEvent.ALERT_TRIGGERED:
			return ALERT_ACKNOWLEDGEMENT_SECONDS
		PresentationCadenceEvent.INTERRUPTION:
			return INTERRUPTION_ACKNOWLEDGEMENT_SECONDS
		_:
			return 0.0


func _await_presentation_cadence(event_kind: int) -> void:
	var authored_seconds: float = _cadence_seconds(event_kind)
	var blocking_seconds: float = authored_seconds
	if event_kind == PresentationCadenceEvent.ALERT_TRIGGERED:
		# The alert flash remains visible for its authored duration, but only a short
		# readable lead blocks authoritative commitment. Planning continues during it.
		blocking_seconds = minf(authored_seconds, ALERT_ACTION_LEAD_SECONDS)
	_last_cadence_event = event_kind
	_last_cadence_seconds = blocking_seconds
	_cadence_event_count_by_kind[event_kind] = int(
		_cadence_event_count_by_kind.get(event_kind, 0)
	) + 1
	if blocking_seconds <= 0.0:
		return
	if event_kind == PresentationCadenceEvent.ALERT_TRIGGERED:
		var alert_started_usec: int = Time.get_ticks_usec()
		var seconds: float = blocking_seconds
		await _await_alert_cadence_with_contact_warmup(seconds)
		_blocking_alert_acknowledgement_usec += maxi(
			0, Time.get_ticks_usec() - alert_started_usec
		)
		return
	_cadence_wait_depth += 1
	await get_tree().create_timer(blocking_seconds).timeout
	_cadence_wait_depth = maxi(0, _cadence_wait_depth - 1)


func _await_alert_cadence_with_contact_warmup(seconds: float) -> void:
	_cadence_wait_depth += 1
	var timer: SceneTreeTimer = get_tree().create_timer(seconds)
	while timer.time_left > 0.0:
		_step_contact_ai_warmup()
		if timer.time_left <= 0.0:
			break
		await get_tree().process_frame
	_cadence_wait_depth = maxi(0, _cadence_wait_depth - 1)


func _adaptive_visible_handoff_seconds(
		next_unit: TacticalUnitState
) -> float:
	if (
		next_unit == null
		or not next_unit.is_ai_controlled()
		or not _unit_handoff_is_observable(next_unit)
		or not _last_ai_resolution_observable
	):
		return 0.0
	if (
		_last_ai_activation_presented_movement
		and _last_ai_visible_movement_duration_seconds
		>= AI_VISIBLE_MOVEMENT_SUPPLIES_CADENCE_SECONDS
	):
		return 0.0
	return AI_VISIBLE_SHORT_ACTION_HANDOFF_SECONDS


func _await_adaptive_visible_handoff(
		next_unit: TacticalUnitState
) -> void:
	var seconds: float = _adaptive_visible_handoff_seconds(next_unit)
	if seconds <= 0.0:
		return
	var started_usec: int = Time.get_ticks_usec()
	_adaptive_visible_handoff_count += 1
	_cadence_wait_depth += 1
	await get_tree().create_timer(seconds).timeout
	_cadence_wait_depth = maxi(0, _cadence_wait_depth - 1)
	_adaptive_visible_handoff_usec += maxi(
		0, Time.get_ticks_usec() - started_usec
	)


func _step_contact_ai_warmup() -> void:
	if (
		_facade == null
		or not _facade.is_initiative_combat()
		or _facade.mission_resolution_locked()
		or _contact_ai_warmup_abandoned
		or _contact_ai_warmup_completed_usec > 0
	):
		return
	var active: TacticalUnitState = _facade.active_initiative_unit()
	if (
		active == null
		or not active.is_ai_controlled()
		or not active.can_take_actions()
		or active.unit_id != _contact_presentation_ready_unit_id
	):
		_facade.cancel_contact_ai_warmup()
		_contact_ai_warmup_abandoned = true
		return
	if _contact_ai_warmup_started_usec <= 0:
		_contact_ai_warmup_started_usec = Time.get_ticks_usec()
	var started_usec: int = Time.get_ticks_usec()
	var result: OperationResult = _facade.warmup_active_ai_initiative(4000)
	_contact_ai_warmup_processing_usec += maxi(
		0,
		Time.get_ticks_usec() - started_usec
	)
	_contact_ai_warmup_frames += 1
	if result == null or not result.success:
		_facade.cancel_contact_ai_warmup()
		_contact_ai_warmup_abandoned = true
		return
	if result.code == &"enemy_contact_warmup_ready":
		_contact_ai_warmup_completed_usec = Time.get_ticks_usec()
	elif result.code == &"no_change":
		_contact_ai_warmup_abandoned = true


func _queue_state_change_cadence(
		event_kind: int,
		unit_id: StringName = &""
) -> void:
	if _cadence_priority(event_kind) > _cadence_priority(
		_queued_state_cadence_event
	):
		_queued_state_cadence_event = event_kind
		_queued_state_cadence_unit_id = unit_id
	if _state_cadence_runner_scheduled:
		return
	_state_cadence_runner_scheduled = true
	call_deferred("_run_queued_state_change_cadence")


func _run_queued_state_change_cadence() -> void:
	while _queued_state_cadence_event != PresentationCadenceEvent.NONE:
		var event_kind: int = _queued_state_cadence_event
		var unit_id: StringName = _queued_state_cadence_unit_id
		_queued_state_cadence_event = PresentationCadenceEvent.NONE
		_queued_state_cadence_unit_id = &""
		if event_kind == PresentationCadenceEvent.ACTIVATION_HANDOFF:
			var handoff_unit: TacticalUnitState = _facade.state().get_unit(unit_id)
			if handoff_unit != null and not _unit_handoff_is_observable(handoff_unit):
				_unobserved_ai_activation_handoffs_skipped += 1
				continue
		if (
			not unit_id.is_empty()
			and _last_handoff_pulsed_unit_id != unit_id
		):
			_play_active_unit_handoff_pulse(unit_id)
		await _await_presentation_cadence(event_kind)
	_state_cadence_runner_scheduled = false
	_schedule_initiative_ai()


func _play_active_unit_handoff_pulse(unit_id: StringName) -> void:
	var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
	if unit != null and not _unit_handoff_is_observable(unit):
		return
	_last_handoff_pulsed_unit_id = unit_id
	if (
		unit_id == _contact_presentation_ready_unit_id
		and _contact_ai_pulse_started_usec <= 0
	):
		_contact_ai_pulse_started_usec = Time.get_ticks_usec()
	var view := _unit_views.get(unit_id) as TacticalUnitView
	if view != null and view.has_method("play_active_handoff_pulse"):
		view.call("play_active_handoff_pulse")


func _visible_enemy_unit_id_set() -> Dictionary:
	var result: Dictionary = {}
	if _facade == null or _facade.state() == null:
		return result
	for unit: TacticalUnitState in _facade.state().get_enemy_units():
		if _facade.is_unit_visible_to_player(unit.unit_id):
			result[unit.unit_id] = true
	return result


func _unit_handoff_is_observable(unit: TacticalUnitState) -> bool:
	return (
		unit != null
		and (
			unit.is_player_controlled()
			or _facade.is_unit_visible_to_player(unit.unit_id)
		)
	)


func _has_visible_enemy_turn_participant() -> bool:
	if _facade == null or _facade.state() == null:
		return false
	for unit: TacticalUnitState in _facade.state().get_enemy_turn_units():
		if (
			unit != null
			and unit.should_receive_enemy_turn()
			and _facade.is_unit_visible_to_player(unit.unit_id)
		):
			return true
	return false


func _select_unit_for_observable_handoff(unit: TacticalUnitState) -> bool:
	if not _unit_handoff_is_observable(unit):
		return false
	_selected_unit_id = unit.unit_id
	return true


func _has_new_dictionary_key(current: Dictionary, previous: Dictionary) -> bool:
	for key: Variant in current.keys():
		if not previous.has(key):
			return true
	return false


func _flush_deferred_state_changes_without_animation() -> void:
	if _deferred_state_change_reasons.is_empty():
		_apply_deferred_damage_events()
		return
	var reasons: Array[StringName] = []
	for reason_value: Variant in _deferred_state_change_reasons.keys():
		reasons.append(StringName(reason_value))
	_deferred_state_change_reasons.clear()
	for reason: StringName in reasons:
		if _board_view != null and _board_view.has_method("notify_state_changed"):
			var deferred_flags: TacticalInvalidationFlags = (
				_deferred_state_change_flags.get(reason)
				as TacticalInvalidationFlags
			)
			if deferred_flags != null:
				_board_view.call("notify_state_changed", reason, deferred_flags)
			else:
				_board_view.call("notify_state_changed", reason)
	_deferred_state_change_flags.clear()
	_process_state_change_after_commit(reasons.back(), false)
	_apply_deferred_damage_events()


func _apply_deferred_damage_events() -> void:
	var events: Array[Dictionary] = []
	for event: Dictionary in _deferred_damage_events:
		events.append(event.duplicate(true))
	_deferred_damage_events.clear()
	for event: Dictionary in events:
		_apply_damage_committed_presentation(event)


func _on_ai_movement_committed(event: Dictionary) -> void:
	_pending_ai_movement_events.append(event.duplicate(true))


func _select_unit(unit_id: StringName) -> void:
	_interact_mode_active = false
	_grapple_targeting = false
	if _first_aid_targeting:
		_cancel_first_aid_targeting()
	if _attack_targeting:
		_clear_attack_targeting_state()
	_clear_board_intent()
	_clear_contextual_attack_hover_preview()
	if not _facade.state().phase_state.is_player_phase():
		return

	var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
	if unit == null:
		return

	if not unit.is_player_controlled():
		_selected_unit_id = unit_id
		_refresh_selected_cover_summary()
		_selected_weapon_hand_kind = &""
		_selected_weapon_item_id = &""
		_selected_attack_id = &""
		_movement_mode = &"normal"
		_hide_context_tray()
		_update_unit_selection_visuals()
		_refresh_board_view()
		_set_status(
			"%s selected for inspection. This %s is not player-controlled."
			% [unit.display_name, unit.roster_role]
		)
		_refresh_hud()
		return

	if unit.is_defeated():
		_set_status(
			"%s is %s and can only be inspected."
			% [
				unit.display_name,
				String(unit.life_state_id()).replace("_", " ").capitalize(),
			]
		)
	elif unit.action_budget.ended_activation:
		var result: OperationResult = _facade.reactivate_unit(unit_id)
		_set_status(result.message)
	else:
		_set_status("%s selected." % unit.display_name)

	_selected_unit_id = unit_id
	_refresh_selected_cover_summary()
	if (
		_unit_management_window != null
		and _unit_management_window.visible
	):
		_unit_management_window.set_current_unit(unit_id)
	_movement_mode = &"normal"
	_hide_context_tray()
	_select_default_weapon_for_unit()
	_update_unit_selection_visuals()
	_refresh_contextual_hand_attack_hover_preview()
	_refresh_hud()
	_refresh_board_view()


func _execute_budget_action(
		action_name: String,
		action_id: StringName
) -> void:
	if not _selected_unit_is_player_controlled():
		_set_status("Only player-controlled units can use tactical commands.")
		return

	var result: OperationResult = _facade.spend_action(
		_selected_unit_id,
		action_name,
		action_id
	)
	_set_status(result.message)
	_clear_board_intent()
	_refresh_all_presentation()


func _toggle_interact_mode() -> void:
	_grapple_targeting = false
	if _inventory_open:
		_close_inventory()
	if _selected_unit_id.is_empty() or not _selected_unit_is_player_controlled():
		_set_status("Select an active player character before interacting.")
		return
	_interact_mode_active = not _interact_mode_active
	_clear_board_intent(false)
	if _attack_targeting:
		_clear_attack_targeting_state()
	_active_category = &"interact" if _interact_mode_active else &""
	_context_tray.visible = false
	_set_status(
		"Interact: choose a highlighted door, window, or opening."
		if _interact_mode_active
		else "Interaction mode cancelled."
	)
	_refresh_all_presentation()


func _on_board_interaction_target_clicked(
		target_kind: StringName,
		target_id: StringName
) -> void:
	if not _interact_mode_active or target_id.is_empty():
		return
	match target_kind:
		&"opening":
			var opening: TacticalOpeningDefinition = _map_definition.opening_definition(target_id)
			if opening == null:
				_set_status("That opening is no longer available.")
				return
			_show_opening_context_menu(opening)
		&"structure":
			var structure: TacticalStructureDefinition = _map_definition.structure_definition(target_id)
			if structure == null:
				_set_status("That structure is no longer available.")
				return
			_show_structure_context_menu(structure)
		_:
			_set_status("That interaction target is unavailable.")


func _handle_interact_click(tile: Vector2i) -> void:
	var selected: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if selected == null or not TacticalEdgeKey.are_adjacent(selected.grid_position, tile):
		_set_status("Choose a highlighted adjacent opening.")
		return
	var opening: TacticalOpeningDefinition = _facade.opening_between_tiles(
		selected.grid_position, tile
	)
	if opening != null:
		_show_opening_context_menu(opening)
		return
	var structure: TacticalStructureDefinition = _facade.structure_between_tiles(
		selected.grid_position, tile
	)
	if structure != null:
		if _selected_attack_id.is_empty():
			_set_status("Select a weapon before attacking %s." % structure.display_name)
			return
		var result: OperationResult = _facade.attack_environment_source(
			_selected_unit_id, structure.structure_id, _selected_attack_id
		)
		_set_status(result.message)
		_interact_mode_active = false
		_active_category = &""
		_refresh_all_presentation()
		return
	_set_status("There is no interactable opening or structure on that edge.")


func _toggle_action_category(category: StringName) -> void:
	_grapple_targeting = false
	if category != &"interact":
		_interact_mode_active = false
	if _first_aid_targeting:
		_cancel_first_aid_targeting()
	if _attack_targeting:
		_clear_attack_targeting_state()
	_clear_board_intent()
	if _inventory_open:
		_close_inventory()

	if _active_category == category and _context_tray.visible:
		_hide_context_tray()
		return

	_active_category = category
	_context_tray.visible = true

	match category:
		&"abilities":
			_configure_ability_actions()
		&"tactics":
			_configure_context_actions(
				[
					"Enter Stealth [Quick]",
					"Sprint [Full]",
					"Disengage [Half]",
					"Overwatch [Half + Reaction]",
					"Brace [Half + Reaction]",
					"First Aid [Half]",
				],
				[&"enter_stealth", &"sprint", &"disengage", &"overwatch", &"brace", &"first_aid"]
			)
		&"interact":
			_toggle_interact_mode()
			return
		&"hand_inspect":
			_inspect_active_hand_item()
		&"hand_open_inventory":
			_open_inventory()
		_:
			_set_status("That action is displayed for UI planning but is not implemented yet.")

	_set_status("%s options opened." % String(category).capitalize())
	_refresh_context_action_availability()
	_refresh_hud()


func _configure_typed_attack_actions() -> void:
	var labels: Array[String] = []
	var ids: Array[StringName] = []
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)

	if unit != null and _facade != null:
		for action_id: StringName in _facade.granted_action_ids_for_unit(
			unit.unit_id
		):
			if not _facade.is_stage_4_attack(action_id):
				continue
			var attack: AttackDefinition = _facade.attack_definition(action_id)
			if attack == null:
				continue
			labels.append(
				"%s %+d [%s]"
				% [
					attack.display_name,
					unit.resolved_character.attack_bonus_for(attack),
					attack.cost_label(),
				]
			)
			ids.append(action_id)
			if labels.size() >= _context_action_buttons.size():
				break

	if labels.is_empty():
		labels.append("Equip Axe, Mace or Dagger")
		ids.append(&"")

	while labels.size() < _context_action_buttons.size():
		labels.append("")
		ids.append(&"")

	_configure_context_actions(labels, ids)

func _configure_context_actions(
		labels: Array[String],
		ids: Array[StringName]
) -> void:
	for index: int in range(_context_action_buttons.size()):
		var button := _context_action_buttons[index]
		var label := labels[index] if index < labels.size() else ""
		var action_id := ids[index] if index < ids.size() else &""

		button.text = label
		button.visible = not label.is_empty()
		_context_action_ids[index] = action_id


func _refresh_context_action_availability() -> void:
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)

	for index: int in range(_context_action_buttons.size()):
		var button: Button = _context_action_buttons[index]
		var action_id: StringName = _context_action_ids[index]

		button.disabled = false
		button.tooltip_text = ""

		if not button.visible:
			continue

		if unit == null:
			button.disabled = true
			button.tooltip_text = "Select a unit first."
			continue

		if not _facade.can_unit_act(unit.unit_id):
			button.disabled = true
			button.tooltip_text = "This unit is not active in the current turn mode."
			continue

		var typed_action: ActionDefinition = _facade.action_definition(action_id)
		if typed_action != null:
			var typed_reason: String = _facade.action_unavailable_reason(
				unit.unit_id,
				action_id
			)
			if not _facade.is_stage_4_attack(action_id):
				button.disabled = true
				button.tooltip_text = "This attack is reserved for a later combat stage."
			else:
				button.disabled = not typed_reason.is_empty()
				button.tooltip_text = (
					typed_reason
					if not typed_reason.is_empty()
					else "Select this attack, then choose a highlighted target."
				)
			continue

		match action_id:
			&"attack_confirm":
				button.disabled = (
					_attack_preview == null
					or not bool(_attack_preview.get("success"))
					or _selected_attack_target_id.is_empty()
				)
				button.tooltip_text = (
					"Choose a highlighted target first."
					if button.disabled
					else "Commit the previewed attack and roll."
				)
			&"damage_mode_toggle":
				var damage_mode_attack: AttackDefinition = _facade.attack_definition(_selected_attack_id)
				var selectable_mode: bool = (
					damage_mode_attack != null
					and damage_mode_attack.damage_mode_policy == AttackDefinition.DAMAGE_POLICY_SELECTABLE
				)
				button.disabled = not selectable_mode
				button.tooltip_text = (
					"Switch between lethal and nonlethal damage. Nonlethal attacks normally take a −4 attack penalty."
					if selectable_mode
					else "This authored weapon has a fixed damage mode."
				)
			&"power_attack_down":
				var power_down_attack: AttackDefinition = _facade.attack_definition(_selected_attack_id)
				var power_down_eligible: bool = (
					power_down_attack != null
					and power_down_attack.allows_power_attack()
					and unit.resolved_character != null
					and unit.resolved_character.has_trait(&"feat.power_attack")
				)
				button.disabled = not power_down_eligible or _power_attack_value <= 0
				button.tooltip_text = (
					"Reduce Power Attack by 1."
					if power_down_eligible
					else "This character or attack does not possess Power Attack."
				)
			&"power_attack_up":
				var power_up_attack: AttackDefinition = _facade.attack_definition(_selected_attack_id)
				var power_up_eligible: bool = (
					power_up_attack != null
					and power_up_attack.allows_power_attack()
					and unit.resolved_character != null
					and unit.resolved_character.has_trait(&"feat.power_attack")
				)
				button.disabled = not power_up_eligible or _power_attack_value >= _maximum_power_attack_value()
				button.tooltip_text = (
					"Increase Power Attack by 1: −1 attack, +1 damage."
					if power_up_eligible
					else "This character or attack does not possess Power Attack."
				)
			&"attack_cancel":
				button.disabled = false
			&"enter_stealth":
				var stealth_reason: String = _facade.stealth_unavailable_reason(unit.unit_id)
				button.disabled = not stealth_reason.is_empty()
				button.tooltip_text = stealth_reason if not stealth_reason.is_empty() else "Enter Stealth and display the mask icon."
			&"rage_toggle":
				var rage_active: bool = unit.active_character_modifier_ids.has(&"effect.rage")
				button.disabled = not rage_active and not unit.rage_available()
				button.tooltip_text = (
					"End Rage voluntarily and become Fatigued for this encounter."
					if rage_active
					else "Quick Action. One use per mission; lasts seven rounds."
				)
			&"ready_stance", &"sprint":
				var reason: String = _facade.action_unavailable_reason(
					unit.unit_id,
					action_id
				)
				button.disabled = not reason.is_empty()
				button.tooltip_text = reason
			&"disengage":
				var reason: String = _facade.action_unavailable_reason(unit.unit_id, &"disengage")
				button.disabled = not reason.is_empty()
				button.tooltip_text = reason if not reason.is_empty() else "Spend a Half Action to prevent ordinary movement-based Attacks of Opportunity this activation."
			&"overwatch":
				var reason: String = _facade.reaction_unavailable_reason(unit.unit_id, ReactionReservationState.KIND_OVERWATCH)
				button.disabled = not reason.is_empty()
				button.tooltip_text = reason if not reason.is_empty() else "Reserve the Reaction for a directional bow shot."
			&"brace":
				var reason: String = _facade.reaction_unavailable_reason(unit.unit_id, ReactionReservationState.KIND_BRACE)
				button.disabled = not reason.is_empty()
				button.tooltip_text = reason if not reason.is_empty() else "Reserve the Reaction with a spear or Brace-capable weapon."
			&"grapple":
				button.disabled = false
				button.tooltip_text = "Half Action opposed Manoeuvre; choose an adjacent hostile."
			&"first_aid":
				button.disabled = false
				button.tooltip_text = (
					"Choose an adjacent Dying character; Medicine DC 10."
				)
			&"hand_inspect", &"hand_open_inventory":
				button.disabled = false
			&"hand_attack":
				button.disabled = not _active_hand_has_stage_4_attack()
				button.tooltip_text = (
					"Begin targeting with this held weapon."
					if not button.disabled
					else "This held item has no Stage 4.0 melee attack."
				)
			&"hand_full_attack", &"hand_overwatch":
				button.disabled = true
				button.tooltip_text = "Full Attacks and Overwatch are outside Stage 4.0."
			&"hand_drop":
				button.disabled = true
				button.tooltip_text = "Open Inventory to drop this item."
			_:
				button.disabled = true
				button.tooltip_text = "Visible placeholder for a later stage."

func _on_context_action_pressed(index: int) -> void:
	if index < 0 or index >= _context_action_ids.size():
		return

	var action_id: StringName = _context_action_ids[index]
	var typed_action: ActionDefinition = (
		_facade.action_definition(action_id)
		if _facade != null
		else null
	)
	if typed_action is AttackDefinition:
		_begin_attack_targeting(action_id)
		return
	if typed_action != null:
		_set_status("That typed action is reserved for a later stage.")
		return

	match action_id:
		&"attack_confirm":
			_confirm_selected_attack()
		&"damage_mode_toggle":
			_toggle_damage_mode()
		&"power_attack_down":
			_adjust_power_attack(-1)
		&"power_attack_up":
			_adjust_power_attack(1)
		&"attack_cancel":
			_cancel_attack_targeting("Attack targeting cancelled.")
		&"enter_stealth":
			var stealth_result: OperationResult = _facade.enter_stealth(_selected_unit_id)
			_set_status(stealth_result.message)
			_hide_context_tray()
			_clear_board_intent()
			_refresh_all_presentation()
		&"ready_stance":
			_execute_budget_action("Ready Stance", &"ready_stance")
		&"rage_toggle":
			_toggle_rage()
		&"grapple":
			_begin_or_resolve_grapple()
		&"first_aid":
			_begin_first_aid_targeting()
		&"sprint":
			_clear_board_intent()
			_movement_mode = &"sprint"
			_hide_context_tray()
			_set_status(
				"Sprint selected. Left-click a legal destination to preview it, then left-click again to confirm."
			)
			_refresh_all_presentation()
		&"disengage":
			var result: OperationResult = _facade.use_disengage(_selected_unit_id)
			_set_status(result.message)
			_hide_context_tray()
			_clear_board_intent(false)
			_refresh_all_presentation()
		&"overwatch":
			_begin_reaction_reservation_preview(ReactionReservationState.KIND_OVERWATCH)
		&"brace":
			_begin_reaction_reservation_preview(ReactionReservationState.KIND_BRACE)
		&"hand_attack":
			_begin_active_hand_attack()
		&"hand_inspect":
			_inspect_active_hand_item()
		&"hand_open_inventory":
			_open_inventory()
		_:
			_set_status("That action is not implemented in Stage 4.0.")

func _select_default_weapon_for_unit() -> void:
	if not _selected_unit_is_player_controlled():
		_clear_attack_targeting_state()
		_selected_weapon_hand_kind = &""
		_selected_weapon_item_id = &""
		_selected_attack_id = &""
		return

	var chosen: StringName = TacticalInventoryState.KIND_PRIMARY_HAND
	if _selected_hand_by_unit_id.has(_selected_unit_id):
		chosen = _valid_hand_kind_or_primary(
			StringName(_selected_hand_by_unit_id[_selected_unit_id])
		)
	else:
		var primary_item: TacticalItemInstanceState = _facade.state().get_hand_item(
			_selected_unit_id,
			TacticalInventoryState.KIND_PRIMARY_HAND
		)
		var secondary_item: TacticalItemInstanceState = _facade.state().get_hand_item(
			_selected_unit_id,
			TacticalInventoryState.KIND_SECONDARY_HAND
		)
		if primary_item == null and secondary_item != null:
			chosen = TacticalInventoryState.KIND_SECONDARY_HAND
	_apply_hand_selection(chosen, true)


func _select_weapon_from_hand(hand_kind: StringName) -> void:
	if not _selected_unit_is_player_controlled():
		_set_status("Only player-controlled units can select hands.")
		return
	_clear_board_intent(false)
	if _attack_targeting:
		_clear_attack_targeting_state()
	_apply_hand_selection(_valid_hand_kind_or_primary(hand_kind), true)
	var hand_label: String = _selected_hand_label(_selected_weapon_hand_kind)
	var item: TacticalItemInstanceState = _facade.state().get_hand_item(
		_selected_unit_id,
		_selected_weapon_hand_kind
	)
	if item == null:
		_set_status("%s selected: Empty. Contextual attacks are unavailable." % hand_label)
	elif _selected_attack_id.is_empty():
		_set_status(
			"%s selected: %s. This item has no supported basic attack."
			% [hand_label, item.display_name]
		)
	else:
		_set_status(
			"%s selected: %s. Left-click a legal hostile to attack."
			% [hand_label, item.display_name]
		)
	# One hand selection performs at most one contextual preview. A broad
	# presentation refresh used to invoke the same preview a second time.
	_refresh_contextual_hand_attack_hover_preview()
	_refresh_weapon_attack_strip()
	_refresh_hud()
	_refresh_board_view()


func _apply_hand_selection(hand_kind: StringName, remember: bool) -> void:
	_selected_weapon_hand_kind = _valid_hand_kind_or_primary(hand_kind)
	if remember and not _selected_unit_id.is_empty():
		_selected_hand_by_unit_id[_selected_unit_id] = _selected_weapon_hand_kind
	var item: TacticalItemInstanceState = _facade.state().get_hand_item(
		_selected_unit_id,
		_selected_weapon_hand_kind
	)
	_selected_weapon_item_id = item.item_id if item != null else &""
	_selected_attack_id = _stage_4_attack_id_for_item(item)
	_selected_attack_target_id = &""
	_attack_preview = null
	_legal_attack_target_ids.clear()
	_contextual_attack_hover_active = false


func _valid_hand_kind_or_primary(hand_kind: StringName) -> StringName:
	if hand_kind == TacticalInventoryState.KIND_SECONDARY_HAND:
		return TacticalInventoryState.KIND_SECONDARY_HAND
	return TacticalInventoryState.KIND_PRIMARY_HAND


func _selected_hand_label(hand_kind: StringName) -> String:
	return (
		"Secondary Hand"
		if hand_kind == TacticalInventoryState.KIND_SECONDARY_HAND
		else "Primary Hand"
	)


func _stage_4_attack_id_for_item(
	item: TacticalItemInstanceState
) -> StringName:
	if item == null or item.definition == null or _facade == null:
		return &""
	for action_id: StringName in item.definition.granted_action_ids:
		if _facade.is_stage_4_attack(action_id):
			return action_id
	return &""


func _cycle_attack_mode() -> void:
	if _selected_attack_id.is_empty():
		_set_status("The selected hand has no supported attack mode.")
		return
	_toggle_damage_mode()


func _cycle_power_attack() -> void:
	if _selected_attack_id.is_empty():
		return
	_power_attack_value = (_power_attack_value + 1) % (_maximum_power_attack_value() + 1)
	_refresh_attack_configuration()


func _refresh_attack_configuration() -> void:
	if _attack_targeting:
		_refresh_legal_attack_targets()
	if not _selected_attack_target_id.is_empty():
		_attack_preview = _facade.preview_attack(
			_selected_unit_id,
			_selected_attack_target_id,
			_selected_attack_id,
			_power_attack_value,
			_selected_damage_channel,
			_attack_origin_override
		)
	_refresh_weapon_attack_strip()
	_refresh_attack_cursor_preview()
	if _attack_targeting or _contextual_attack_hover_active:
		_set_status(_attack_preview_status())
	_refresh_all_presentation(false)


func _execute_direct_attack(target: TacticalUnitState) -> void:
	if target == null or not _selected_unit_is_player_controlled():
		return
	if not _facade.are_units_hostile(_selected_unit_id, target.unit_id):
		_select_unit(target.unit_id)
		return
	if _selected_attack_id.is_empty():
		_set_status(
			"%s has no supported basic attack."
			% _selected_hand_label(_selected_weapon_hand_kind)
		)
		_clear_contextual_attack_hover_preview()
		_refresh_hud()
		_refresh_board_view()
		return

	# Acknowledge the hostile click before any fallback preview work. This pulse
	# is presentation-only and never waits; a rejected command simply clears the
	# in-progress guard after legality is reported.
	_attack_command_in_progress = true
	_attack_click_started_usec = Time.get_ticks_usec()
	_attack_command_acknowledgements += 1
	_attack_command_dead_frames_avoided += 1
	_play_attack_command_acknowledgement(_selected_unit_id)

	# Reuse the already accepted hovered/selected exact preview when it matches
	# this click. The facade cache remains the fallback for a click that arrives
	# without a preceding hover preview, but no artificial frame is inserted
	# before either path commits.
	var preview = _attack_preview
	if (
		preview == null
		or StringName(preview.get("target_id")) != target.unit_id
		or StringName(preview.get("attacker_id")) != _selected_unit_id
		or StringName(preview.get("action_id")) != _selected_attack_id
	):
		_attack_click_preview_fallbacks += 1
		preview = _facade.preview_attack(
			_selected_unit_id,
			target.unit_id,
			_selected_attack_id,
			_power_attack_value,
			_selected_damage_channel,
			_attack_origin_override
		)
	else:
		_attack_clicks_using_primed_preview += 1
	_selected_attack_target_id = target.unit_id
	_attack_preview = preview
	_contextual_attack_hover_active = not _attack_targeting
	if preview == null or not bool(preview.get("success")):
		_attack_command_in_progress = false
		_last_attack_click_to_result_usec = (
			Time.get_ticks_usec() - _attack_click_started_usec
		)
		_attack_click_started_usec = 0
		_set_status(
			str(preview.get("reason"))
			if preview != null
			else "That target is unavailable."
		)
		_refresh_attack_cursor_preview()
		_refresh_hud()
		_refresh_board_view()
		return

	# Zero-dead-frame commitment: do not await process_frame here. The accepted
	# preview enters the authoritative handler during the same input frame.
	var result: OperationResult = _facade.execute_attack_preview(preview)
	_last_attack_click_to_result_usec = (
		Time.get_ticks_usec() - _attack_click_started_usec
	)
	_attack_command_in_progress = false
	_attack_click_started_usec = 0
	_set_status(result.message)
	_selected_attack_target_id = &""
	_attack_preview = null
	_contextual_attack_hover_active = false
	_legal_attack_target_ids.clear()
	_legal_attack_targets_dirty = true
	_hide_attack_cursor_preview()
	_refresh_weapon_attack_strip()

	if not result.success:
		# A rejected commit has no attack_resolved state signal to drive the
		# consolidated refresh. Update only the currently relevant controls.
		_refresh_hud()
		_refresh_board_view()
		return

	# state_changed already queued one consolidated reconciliation. Do not
	# rebuild contextual hover, legal targets or the complete presentation here.
	_post_attack_refreshes_avoided += 1

func _play_attack_command_acknowledgement(unit_id: StringName) -> void:
	var view := _unit_views.get(unit_id) as TacticalUnitView
	if view != null and view.has_method("play_attack_command_pulse"):
		view.call("play_attack_command_pulse")


func _clear_weapon_selection(message: String = "") -> void:
	# Escape/right-click cancels explicit targeting but never deselects the
	# character's persistent hand choice.
	_clear_attack_targeting_state()
	_context_tray.visible = false
	_active_category = &""
	_hide_attack_cursor_preview()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if not message.is_empty():
		_set_status(message)
	_refresh_contextual_hand_attack_hover_preview()
	_refresh_weapon_attack_strip()
	_refresh_all_presentation(false)


func _refresh_weapon_attack_strip() -> void:
	if _attack_mode_button == null or _facade == null:
		return
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	var attack_reason: String = ""
	if unit != null and not _selected_attack_id.is_empty():
		attack_reason = _facade.action_unavailable_reason(
			unit.unit_id,
			_selected_attack_id
		)
	var usable: bool = (
		unit != null
		and unit.is_player_controlled()
		and not unit.is_defeated()
		and _facade.state().phase_state.is_player_phase()
		and not _selected_attack_id.is_empty()
		and attack_reason.is_empty()
	)
	var mode_text: String = (
		"NONLETHAL"
		if _selected_damage_channel
			== TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
		else "LETHAL"
	)
	_attack_mode_button.text = (
		"NORMAL · %s" % mode_text
		if not _selected_attack_id.is_empty()
		else "NO WEAPON ATTACK"
	)
	_attack_mode_button.disabled = not usable
	_power_attack_down_button.disabled = not usable or _power_attack_value <= 0
	_power_attack_up_button.disabled = not usable or _power_attack_value >= _maximum_power_attack_value()
	_power_attack_value_button.disabled = not usable
	_power_attack_value_button.text = str(_power_attack_value)
	_left_hand_button.button_pressed = (
		unit != null
		and unit.is_player_controlled()
		and _selected_weapon_hand_kind
			== TacticalInventoryState.KIND_SECONDARY_HAND
	)
	_right_hand_button.button_pressed = (
		unit != null
		and unit.is_player_controlled()
		and _selected_weapon_hand_kind
			== TacticalInventoryState.KIND_PRIMARY_HAND
	)
	if usable:
		_attack_mode_button.tooltip_text = (
			"Normal %s attack for the selected hand. Hover a hostile for a preview and left-click to strike."
			% mode_text.to_lower()
		)
	elif not attack_reason.is_empty():
		_attack_mode_button.tooltip_text = attack_reason
	else:
		_attack_mode_button.tooltip_text = "Select a supported held weapon."


func _refresh_attack_cursor_preview() -> void:
	if (
		not (_attack_targeting or _contextual_attack_hover_active)
		or _selected_attack_target_id.is_empty()
		or _attack_preview == null
	):
		_hide_attack_cursor_preview()
		return
	_attack_cursor_preview.visible = true
	if bool(_attack_preview.get("success")):
		var mode_text: String = (
			"NONLETHAL"
			if StringName(_attack_preview.get("damage_channel"))
				== TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
			else "LETHAL"
		)
		var cover_label: String = String(
			_attack_preview.get("cover_category")
		).replace("_", " ").capitalize()
		if StringName(_attack_preview.get("cover_category")) == TacticalCombatGeometryResult.COVER_NONE:
			cover_label = "Exposed"
		_attack_cursor_label.text = (
			"%d%% HIT\n%s %s\n%s %+d AC · %d/%d clear\n%d ft · PA %d"
			% [
				int(_attack_preview.get("hit_chance_percent")),
				str(_attack_preview.get("damage_notation")),
				mode_text,
				cover_label,
				int(_attack_preview.get("cover_ac_bonus")),
				int(_attack_preview.get("clear_exposure_samples")),
				int(_attack_preview.get("total_exposure_samples")),
				int(_attack_preview.get("action_cost_feet")),
				int(_attack_preview.get("power_attack_value")),
			]
		)
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	else:
		_attack_cursor_label.text = "INVALID TARGET\n%s" % str(
			_attack_preview.get("reason")
		)
		Input.set_default_cursor_shape(Input.CURSOR_FORBIDDEN)
	_position_attack_cursor_preview()


func _position_attack_cursor_preview() -> void:
	if _attack_cursor_preview == null or not _attack_cursor_preview.visible:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var desired: Vector2 = (
		get_viewport().get_mouse_position() + Vector2(18.0, 18.0)
	)
	var panel_size: Vector2 = _attack_cursor_preview.size
	_attack_cursor_preview.position = Vector2(
		clampf(
			desired.x,
			4.0,
			maxf(4.0, viewport_size.x - panel_size.x - 4.0)
		),
		clampf(
			desired.y,
			4.0,
			maxf(4.0, viewport_size.y - panel_size.y - 4.0)
		)
	)


func _hide_attack_cursor_preview() -> void:
	if _attack_cursor_preview != null:
		_attack_cursor_preview.visible = false


func _begin_first_aid_targeting() -> void:
	_grapple_targeting = false
	if not _selected_unit_is_player_controlled():
		_set_status("Only an active player character can use First Aid.")
		return
	_clear_board_intent(false)
	_clear_attack_targeting_state()
	_first_aid_targeting = true
	_hide_context_tray()
	_set_status(
		"First Aid selected. Left-click an adjacent Dying character; right-click cancels."
	)
	_refresh_first_aid_hover_preview()
	_refresh_all_presentation()


func _cancel_first_aid_targeting(message: String = "") -> void:
	_first_aid_targeting = false
	_hide_attack_cursor_preview()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if not message.is_empty():
		_set_status(message)
	_refresh_all_presentation()


func _execute_first_aid_at_tile(tile: Vector2i) -> void:
	var target: TacticalUnitState = _facade.visible_unit_at_tile(tile)
	if target == null:
		_set_status("Choose an adjacent Dying character to treat.")
		return
	var result: OperationResult = _facade.first_aid(
		_selected_unit_id,
		target.unit_id
	)
	_set_status(result.message)
	if result.success:
		_first_aid_targeting = false
		_hide_attack_cursor_preview()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_refresh_all_presentation()


func _refresh_first_aid_hover_preview() -> void:
	if not _first_aid_targeting:
		return
	var target: TacticalUnitState = _facade.visible_unit_at_tile(_hovered_tile)
	_attack_cursor_preview.visible = true
	if target == null:
		_attack_cursor_label.text = "FIRST AID\nChoose adjacent Dying character"
		Input.set_default_cursor_shape(Input.CURSOR_FORBIDDEN)
	else:
		var reason: String = _facade.first_aid_unavailable_reason(
			_selected_unit_id,
			target.unit_id
		)
		if reason.is_empty():
			_attack_cursor_label.text = (
				"FIRST AID — %s\nMedicine DC 10 · Half Action"
				% target.display_name
			)
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		else:
			_attack_cursor_label.text = "FIRST AID UNAVAILABLE\n%s" % reason
			Input.set_default_cursor_shape(Input.CURSOR_FORBIDDEN)
	_position_attack_cursor_preview()


func _begin_attack_targeting(action_id: StringName, origin_override: Variant = null) -> void:
	_grapple_targeting = false
	if not _selected_unit_is_player_controlled():
		_set_status("Only player-controlled units can attack in Stage 4.0.")
		return
	if not _facade.is_stage_4_attack(action_id):
		_set_status("That attack is reserved for a later combat stage.")
		return
	var reason: String = _facade.action_unavailable_reason(
		_selected_unit_id,
		action_id
	)
	if not reason.is_empty():
		_set_status(reason)
		return

	var started_usec: int = Time.get_ticks_usec()
	_clear_board_intent()
	_attack_targeting = true
	_attack_origin_override = origin_override
	_selected_attack_id = action_id
	_selected_attack_target_id = &""
	_attack_preview = null
	_legal_attack_target_ids.clear()
	_movement_mode = &"normal"
	_context_tray.visible = false
	_active_category = &""
	_attack_targeting_generation += 1
	_attack_selections += 1
	_attack_selection_started_usec = started_usec
	var generation: int = _attack_targeting_generation
	var selected_unit_id: StringName = _selected_unit_id
	var selected_action_id: StringName = _selected_attack_id

	var attack: AttackDefinition = _facade.attack_definition(action_id)
	if attack != null:
		_selected_damage_channel = attack.default_damage_channel()
		if not attack.allows_power_attack():
			_power_attack_value = 0
	_set_status(
		"%s selected. Hover a hostile for hit chance; left-click attacks and right-click cancels targeting."
		% (attack.display_name if attack != null else "Attack")
	)
	# Cursor, HUD and attack-mode board state are published before target
	# discovery. This function now returns without building full previews.
	_refresh_attack_targeting_presentation()
	_deferred_attack_target_scans += 1
	_complete_deferred_attack_target_scan(
		generation,
		selected_unit_id,
		selected_action_id
	)


func _complete_deferred_attack_target_scan(
		generation: int,
		unit_id: StringName,
		action_id: StringName
) -> void:
	# Guarantee one rendered frame of immediate targeting feedback before even
	# the cheap candidate scan runs.
	await get_tree().process_frame
	if (
		generation != _attack_targeting_generation
		or not _attack_targeting
		or unit_id != _selected_unit_id
		or action_id != _selected_attack_id
	):
		return
	var started_usec: int = Time.get_ticks_usec()
	_refresh_legal_attack_targets()
	_last_attack_target_scan_usec = Time.get_ticks_usec() - started_usec
	_last_attack_selection_total_usec = (
		Time.get_ticks_usec() - _attack_selection_started_usec
	)
	_refresh_board_view()


func _schedule_lazy_post_attack_target_scan() -> void:
	if not _attack_targeting or not _legal_attack_targets_dirty:
		return
	var generation: int = _attack_targeting_generation
	var unit_id: StringName = _selected_unit_id
	var action_id: StringName = _selected_attack_id
	_complete_lazy_post_attack_target_scan(generation, unit_id, action_id)


func _complete_lazy_post_attack_target_scan(
	generation: int,
	unit_id: StringName,
	action_id: StringName
) -> void:
	await get_tree().process_frame
	if (
		generation != _attack_targeting_generation
		or not _attack_targeting
		or not _legal_attack_targets_dirty
		or unit_id != _selected_unit_id
		or action_id != _selected_attack_id
	):
		return
	_refresh_legal_attack_targets()
	_refresh_board_view()


func _refresh_attack_targeting_presentation() -> void:
	_targeted_attack_presentation_refreshes += 1
	_refresh_weapon_attack_strip()
	_refresh_hud()
	_refresh_board_view()


func _begin_active_hand_attack() -> void:
	if _active_hand_item_id.is_empty():
		_set_status("The selected hand is empty.")
		return
	var primary: TacticalItemInstanceState = _facade.state().get_hand_item(
		_selected_unit_id,
		TacticalInventoryState.KIND_PRIMARY_HAND
	)
	var hand_kind: StringName = TacticalInventoryState.KIND_SECONDARY_HAND
	if primary != null and primary.item_id == _active_hand_item_id:
		hand_kind = TacticalInventoryState.KIND_PRIMARY_HAND
	_select_weapon_from_hand(hand_kind)


func _active_hand_has_stage_4_attack() -> bool:
	if _active_hand_item_id.is_empty() or _facade == null:
		return false
	var item: TacticalItemInstanceState = _facade.state().get_item(
		_active_hand_item_id
	)
	if item == null or item.definition == null:
		return false
	for action_id: StringName in item.definition.granted_action_ids:
		if _facade.is_stage_4_attack(action_id):
			return true
	return false


func _refresh_legal_attack_targets() -> void:
	_legal_attack_targets_dirty = false
	_legal_attack_target_ids = _facade.legal_attack_target_ids(
		_selected_unit_id,
		_selected_attack_id,
		_power_attack_value,
		_selected_damage_channel,
		_attack_origin_override
	)


func _refresh_attack_hover_preview() -> void:
	if not _attack_targeting:
		return
	var target: TacticalUnitState = _facade.visible_unit_at_tile(
		_hovered_tile,
		_selected_unit_id
	)
	if target == null:
		_selected_attack_target_id = &""
		_attack_preview = null
		_hide_attack_cursor_preview()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	if not _facade.are_units_hostile(
		_selected_unit_id,
		target.unit_id
	):
		# A friendly unit remains directly selectable even while a weapon is
		# active. Do not construct or display an invalid attack preview.
		_selected_attack_target_id = &""
		_attack_preview = null
		_hide_attack_cursor_preview()
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		return
	var preview = _facade.preview_attack(
		_selected_unit_id,
		target.unit_id,
		_selected_attack_id,
		_power_attack_value,
		_selected_damage_channel,
		_attack_origin_override
	)
	_selected_attack_target_id = target.unit_id
	_attack_preview = preview
	_refresh_attack_cursor_preview()


func _refresh_contextual_hand_attack_hover_preview() -> void:
	if _attack_targeting or _first_aid_targeting or _grapple_targeting:
		return
	_clear_contextual_attack_hover_preview(false)
	if (
		not _selected_unit_is_player_controlled()
		or _selected_attack_id.is_empty()
		or not _map_definition.is_inside(_hovered_tile)
	):
		_refresh_attack_cursor_preview()
		return
	var target: TacticalUnitState = _facade.visible_unit_at_tile(
		_hovered_tile,
		_selected_unit_id
	)
	if (
		target == null
		or not _facade.are_units_hostile(_selected_unit_id, target.unit_id)
	):
		_refresh_attack_cursor_preview()
		return
	_selected_attack_target_id = target.unit_id
	_attack_preview = _facade.preview_attack(
		_selected_unit_id,
		target.unit_id,
		_selected_attack_id,
		_power_attack_value,
		_selected_damage_channel,
		_attack_origin_override
	)
	_contextual_attack_hover_active = true
	_legal_attack_target_ids.clear()
	if _attack_preview != null and bool(_attack_preview.get("success")):
		_legal_attack_target_ids.append(target.unit_id)
	_refresh_attack_cursor_preview()


func _clear_contextual_attack_hover_preview(
		reset_cursor: bool = true
) -> void:
	if not _contextual_attack_hover_active:
		return
	_contextual_attack_hover_active = false
	_selected_attack_target_id = &""
	_attack_preview = null
	_legal_attack_target_ids.clear()
	if reset_cursor:
		_hide_attack_cursor_preview()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _sync_selected_hand_attack() -> void:
	if not _selected_unit_is_player_controlled():
		_selected_attack_id = &""
		_selected_weapon_item_id = &""
		return
	var hand_kind: StringName = _valid_hand_kind_or_primary(
		_selected_weapon_hand_kind
	)
	var item: TacticalItemInstanceState = _facade.state().get_hand_item(
		_selected_unit_id,
		hand_kind
	)
	_selected_weapon_hand_kind = hand_kind
	_selected_weapon_item_id = item.item_id if item != null else &""
	_selected_attack_id = _stage_4_attack_id_for_item(item)


func _select_attack_target_at_tile(tile: Vector2i) -> void:
	var target: TacticalUnitState = _facade.visible_unit_at_tile(
		tile,
		_selected_unit_id
	)
	if target == null:
		_set_status("Choose a highlighted target.")
		return
	var preview = _facade.preview_attack(
		_selected_unit_id,
		target.unit_id,
		_selected_attack_id,
		_power_attack_value,
		_selected_damage_channel,
		_attack_origin_override
	)
	if preview == null or not bool(preview.get("success")):
		_set_status(
			str(preview.get("reason"))
			if preview != null
			else "That target is unavailable."
		)
		return
	_selected_attack_target_id = target.unit_id
	_attack_preview = preview
	_configure_attack_targeting_controls()
	_set_status(_attack_preview_status())
	_refresh_all_presentation()


func _configure_attack_targeting_controls() -> void:
	_active_category = &"attack_targeting"
	_context_tray.visible = true
	var confirm_label: String = "Choose Target"
	if (
		_attack_preview != null
		and bool(_attack_preview.get("success"))
		and not _selected_attack_target_id.is_empty()
	):
		confirm_label = "Confirm %s [%d ft]" % [
			String(_attack_preview.get("attack_display_name")),
			int(_attack_preview.get("action_cost_feet")),
		]
	var damage_mode_label: String = (
		"Mode: Nonlethal"
		if _selected_damage_channel
			== TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
		else "Mode: Lethal"
	)
	_configure_context_actions(
		[
			confirm_label,
			damage_mode_label,
			"Power Attack − [%d]" % _power_attack_value,
			"Power Attack + [%d]" % _power_attack_value,
			"Cancel",
		],
		[
			&"attack_confirm",
			&"damage_mode_toggle",
			&"power_attack_down",
			&"power_attack_up",
			&"attack_cancel",
		]
	)
	_refresh_context_action_availability()


func _toggle_damage_mode() -> void:
	var attack: AttackDefinition = _facade.attack_definition(_selected_attack_id)
	if attack == null or attack.damage_mode_policy != AttackDefinition.DAMAGE_POLICY_SELECTABLE:
		_set_status("This authored weapon has a fixed damage mode.")
		return
	_selected_damage_channel = (
		TacticalUnitState.DAMAGE_CHANNEL_LETHAL
		if _selected_damage_channel
			== TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
		else TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
	)
	if _attack_targeting:
		_refresh_legal_attack_targets()
	if not _selected_attack_target_id.is_empty():
		_attack_preview = _facade.preview_attack(
			_selected_unit_id,
			_selected_attack_target_id,
			_selected_attack_id,
			_power_attack_value,
			_selected_damage_channel,
			_attack_origin_override
		)
	_refresh_weapon_attack_strip()
	_refresh_attack_cursor_preview()
	_set_status(_attack_preview_status())
	_refresh_all_presentation(false)


func _maximum_power_attack_value() -> int:
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null or unit.resolved_character == null:
		return 0
	if not unit.resolved_character.has_trait(&"feat.power_attack"):
		return 0
	return mini(
		unit.resolved_character.stat_value(&"base_attack_bonus", 0),
		int(unit.resolved_character.feature_parameter(
			&"feat.power_attack", &"maximum_value", 99
		))
	)


func _adjust_power_attack(delta: int = 0) -> void:
	_power_attack_value = clampi(
		_power_attack_value + delta, 0, _maximum_power_attack_value()
	)
	if _attack_targeting:
		_refresh_legal_attack_targets()
	if not _selected_attack_target_id.is_empty():
		_attack_preview = _facade.preview_attack(
			_selected_unit_id,
			_selected_attack_target_id,
			_selected_attack_id,
			_power_attack_value,
			_selected_damage_channel,
			_attack_origin_override
		)
	_refresh_weapon_attack_strip()
	_refresh_attack_cursor_preview()
	_set_status(_attack_preview_status())
	_refresh_all_presentation(false)


func _confirm_selected_attack() -> void:
	if (
		_attack_preview == null
		or not bool(_attack_preview.get("success"))
		or _selected_attack_target_id.is_empty()
	):
		_set_status("Choose a highlighted target before confirming the attack.")
		return
	_attack_command_in_progress = true
	_attack_click_started_usec = Time.get_ticks_usec()
	_attack_command_acknowledgements += 1
	_attack_command_dead_frames_avoided += 1
	_attack_clicks_using_primed_preview += 1
	_play_attack_command_acknowledgement(_selected_unit_id)
	# Explicit confirmation already owns an accepted exact preview. Commit it in
	# this frame rather than yielding an otherwise empty acknowledgement frame.
	var result: OperationResult = _facade.execute_attack_preview(_attack_preview)
	_last_attack_click_to_result_usec = (
		Time.get_ticks_usec() - _attack_click_started_usec
	)
	_attack_command_in_progress = false
	_attack_click_started_usec = 0
	if not result.success:
		_set_status(result.message)
		_legal_attack_targets_dirty = true
		_schedule_lazy_post_attack_target_scan()
		_configure_attack_targeting_controls()
		_refresh_hud()
		_refresh_board_view()
		return
	_clear_attack_targeting_state()
	_context_tray.visible = false
	_active_category = &""
	_set_status(result.message)
	_hide_attack_cursor_preview()
	_refresh_weapon_attack_strip()
	_post_attack_refreshes_avoided += 1
	# The attack_resolved state signal owns the single deferred reconciliation.

func _cancel_attack_targeting(message: String) -> void:
	_clear_attack_targeting_state()
	_context_tray.visible = false
	_active_category = &""
	_set_status(message)
	_refresh_all_presentation()


func _clear_attack_targeting_state() -> void:
	_attack_targeting_generation += 1
	_attack_targeting = false
	_selected_attack_target_id = &""
	_legal_attack_target_ids.clear()
	_legal_attack_targets_dirty = false
	_attack_preview = null
	_attack_origin_override = null
	_contextual_attack_hover_active = false
	_sync_selected_hand_attack()
	_hide_attack_cursor_preview()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _attack_preview_status() -> String:
	if not (_attack_targeting or _contextual_attack_hover_active):
		return _last_status_message
	if _attack_preview == null:
		return (
			"Choose a highlighted hostile target · %s · Power Attack %d"
			% [
				"Nonlethal"
				if _selected_damage_channel
					== TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
				else "Lethal",
				_power_attack_value,
			]
		)
	if not bool(_attack_preview.get("success")):
		return str(_attack_preview.get("reason"))
	var damage_channel: StringName = StringName(
		_attack_preview.get("damage_channel")
	)
	var channel_label: String = "Lethal"
	if damage_channel == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL:
		if bool(_attack_preview.get("nonlethal_penalty_ignored")):
			channel_label = "Nonlethal · no penalty"
		else:
			channel_label = "Nonlethal · −4"
	var origin_label: String = " · Automatic Lean" if bool(_attack_preview.get("uses_automatic_lean")) else ""
	var reaction_label: String = ""
	var reaction_summaries: Variant = _attack_preview.get("provoking_reaction_summaries")
	if reaction_summaries is Array and not (reaction_summaries as Array).is_empty():
		reaction_label = " · Provokes %d known Reaction%s · highest %d%% hit" % [
			(reaction_summaries as Array).size(),
			"" if (reaction_summaries as Array).size() == 1 else "s",
			int(_attack_preview.get("highest_provoking_reaction_hit_chance")),
		]
	return (
		"%s vs %s%s · %+d vs AC %d + Cover %d = %d · %d%% hit · %s %s · PA %d · %d/%d ft after%s"
		% [
			String(_attack_preview.get("attack_display_name")),
			String(_attack_preview.get("target_display_name")),
			origin_label,
			int(_attack_preview.get("attack_bonus")),
			int(_attack_preview.get("base_target_armour_class")),
			int(_attack_preview.get("cover_ac_bonus")),
			int(_attack_preview.get("effective_target_armour_class")),
			int(_attack_preview.get("hit_chance_percent")),
			String(_attack_preview.get("damage_notation")),
			channel_label,
			int(_attack_preview.get("power_attack_value")),
			int(_attack_preview.get("capacity_after")),
			int(_attack_preview.get("capacity_before")),
			reaction_label,
		]
	)


func _configure_ability_actions() -> void:
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	var can_rage: bool = (
		unit != null
		and unit.resolved_character != null
		and unit.resolved_character.has_trait(&"feature.rage")
		and _facade.has_character_modifier(&"effect.rage")
	)
	var rage_label := "Rage [Quick]"
	if can_rage:
		if unit.active_character_modifier_ids.has(&"effect.rage"):
			rage_label = "End Rage [Free]"
		else:
			var rage_maximum: int = int(unit.ability_resource_maximums.get(&"resource.rage", 1))
			rage_label = "Rage [Quick · %d/%d]" % [
				unit.ability_uses(&"resource.rage"),
				rage_maximum,
			]

	var grapple_label: String = "Grapple [Half]"
	if unit != null and unit.is_grappling():
		grapple_label = "Release Grapple [Free]"
	elif unit != null and unit.is_grappled():
		grapple_label = "Break Hold [Half]"
	_configure_context_actions(
		[
			"Ready Stance [Quick]",
			rage_label if can_rage else "Class Ability",
			grapple_label,
			"Archetype Ability",
			"Spellbook",
		],
		[
			&"ready_stance",
			&"rage_toggle" if can_rage else &"class_ability",
			&"grapple",
			&"archetype_ability",
			&"spellbook",
		]
	)


func _toggle_rage() -> void:
	if not _selected_unit_is_player_controlled():
		_set_status("Only player-controlled units can activate abilities.")
		return
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return
	var activating := not unit.active_character_modifier_ids.has(&"effect.rage")
	if activating and not unit.rage_available():
		_set_status("Rage has no remaining use or the Marauder is Fatigued.")
		return
	if activating:
		var result: OperationResult = _facade.spend_action(
			unit.unit_id,
			"Rage",
			&"rage_toggle"
		)
		if not result.success:
			_set_status(result.message)
			return
	if not _facade.set_character_modifier_active(
		unit.unit_id,
		&"effect.rage",
		activating
	):
		_set_status("Rage could not be resolved for this character.")
		return
	_set_status(
		"%s. Character statistics were recalculated from their sources."
		% ("Rage activated" if activating else "Rage ended")
	)
	_hide_context_tray()
	_refresh_all_presentation()


func _begin_or_resolve_grapple() -> void:
	if _first_aid_targeting:
		_cancel_first_aid_targeting()
	if _attack_targeting:
		_clear_attack_targeting_state()
	_clear_board_intent(false)
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return
	if unit.is_grappling():
		var release_result: OperationResult = _facade.release_grapple(unit.unit_id)
		_set_status(release_result.message)
		_hide_context_tray()
		_refresh_all_presentation()
		return
	if unit.is_grappled():
		var break_result: OperationResult = _facade.break_grapple_hold(unit.unit_id)
		_set_status(break_result.message)
		_hide_context_tray()
		_refresh_all_presentation()
		return
	_grapple_targeting = true
	_hide_context_tray()
	_set_status("Grapple selected. Choose an adjacent hostile target.")
	_refresh_all_presentation()


func _cancel_grapple_targeting(message: String = "") -> void:
	_grapple_targeting = false
	if not message.is_empty():
		_set_status(message)
	_refresh_all_presentation()


func _execute_grapple_at_tile(tile: Vector2i) -> void:
	var target: TacticalUnitState = _facade.visible_unit_at_tile(tile, _selected_unit_id)
	if target == null:
		_set_status("Choose an adjacent hostile target.")
		return
	var reason: String = _facade.grapple_unavailable_reason(
		_selected_unit_id, target.unit_id
	)
	if not reason.is_empty():
		_set_status(reason)
		return
	var result: OperationResult = _facade.initiate_grapple(
		_selected_unit_id, target.unit_id
	)
	_grapple_targeting = false
	_set_status(result.message)
	_refresh_all_presentation()


func _hide_context_tray() -> void:
	_interact_mode_active = false
	if _attack_targeting:
		_clear_attack_targeting_state()
	_active_category = &""
	_active_hand_name = ""
	_active_hand_item = ""
	_active_hand_item_id = &""
	_context_tray.visible = false

func _open_hand_actions(hand_name: String, use_main_hand: bool) -> void:
	if not _selected_unit_is_player_controlled():
		_set_status("Held-item commands are unavailable for inspected non-player units.")
		return

	if _inventory_open:
		_close_inventory()

	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return

	var hand_kind := (
		TacticalInventoryState.KIND_PRIMARY_HAND
		if use_main_hand
		else TacticalInventoryState.KIND_SECONDARY_HAND
	)
	var hand_item: TacticalItemInstanceState = _facade.state().get_hand_item(unit.unit_id, hand_kind)
	var item_name := hand_item.display_name if hand_item != null else "Empty"
	if item_name.is_empty():
		item_name = "Empty"

	_active_hand_name = hand_name
	_active_hand_item = item_name
	_active_hand_item_id = hand_item.item_id if hand_item != null else &""
	_active_category = &"hand"
	_context_tray.visible = true

	if item_name.to_lower() == "empty":
		_configure_context_actions(
			[
				"Open Inventory",
				"",
				"",
				"",
			],
			[
				&"hand_open_inventory",
				&"",
				&"",
				&"",
			]
		)
		_set_status("%s is empty. Open Inventory to place an item there." % hand_name)
	else:
		var ranged_item := (
			hand_item != null
			and hand_item.definition != null
			and hand_item.definition.has_tag(&"ranged")
		)

		_configure_context_actions(
			[
				"Ranged Attack [Half]" if ranged_item else "Attack [Half]",
				"Overwatch" if ranged_item else "",
				"Drop",
				"Inspect",
			],
			[
				&"hand_attack",
				&"hand_overwatch" if ranged_item else &"",
				&"hand_drop",
				&"hand_inspect",
			]
		)
		_set_status("%s selected: %s." % [hand_name, item_name])

	_refresh_context_action_availability()
	_refresh_hud()


func _inspect_active_hand_item() -> void:
	if _active_hand_item_id.is_empty():
		_set_status("%s is empty." % _active_hand_name)
		return

	var item: TacticalItemInstanceState = _facade.state().get_item(_active_hand_item_id)
	if item == null or item.definition == null:
		_set_status("The held item's definition is unavailable.")
		return

	var tags: Array[String] = []
	for tag: StringName in item.definition.equipment_tags:
		tags.append(String(tag).replace("_", " "))
	var tag_text := (
		", ".join(PackedStringArray(tags))
		if not tags.is_empty()
		else "uncategorised"
	)
	_set_status(
		"%s: %s · %.1f lb · %s · %s."
		% [
			_active_hand_name,
			item.display_name,
			item.weight_lb,
			item.definition.description,
			tag_text,
		]
	)

func _toggle_inventory() -> void:
	if _inventory_open:
		_close_inventory()
	else:
		_open_inventory()


func _open_inventory() -> void:
	if _selected_unit_id == &"":
		_set_status("Select a unit before opening Unit Management.")
		return

	_clear_board_intent()
	_inventory_open = true
	_board_view.set_input_enabled(false)
	if (
		_combat_log != null
		and _combat_log.has_method("collapse")
	):
		_combat_log.call("collapse")
	_hide_context_tray()
	_movement_mode = &"normal"
	_unit_management_window.open_for_unit(
		_selected_unit_id,
		&"equipment"
	)
	_set_status(
		"Unit Management opened. Equipment and Character Sheet tabs are free to inspect."
	)
	_refresh_board_view()


func _close_inventory() -> void:
	if _unit_management_window != null:
		_unit_management_window.close_window()
	else:
		_inventory_open = false


func _refresh_inventory_panel() -> void:
	if _unit_management_window != null:
		_unit_management_window.refresh()


func _on_unit_management_closed() -> void:
	_inventory_open = false
	_board_view.set_input_enabled(true)
	_set_status("Unit Management closed.")
	_refresh_all_presentation()


func _on_unit_management_unit_changed(unit_id: StringName) -> void:
	if unit_id == _selected_unit_id:
		return
	_select_unit_for_management(unit_id)


func _select_unit_for_management(unit_id: StringName) -> void:
	_clear_board_intent()
	var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
	if unit == null:
		return

	_selected_unit_id = unit_id
	_movement_mode = &"normal"
	_hide_context_tray()
	if unit.is_player_controlled():
		_select_default_weapon_for_unit()
	_update_unit_selection_visuals()
	_refresh_hud()
	_refresh_board_view()
	_set_status("%s selected for inspection." % unit.display_name)


func _update_unit_selection_visuals() -> void:
	for key: Variant in _unit_views.keys():
		var view := _unit_views[key] as TacticalUnitView
		if view != null:
			view.set_selected(StringName(key) == _selected_unit_id)
	_apply_unit_cover_icons()


func _refresh_unit_status_badge_immediately(unit_id: StringName) -> void:
	if unit_id.is_empty() or _facade == null:
		return
	var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
	var view := _unit_views.get(unit_id) as TacticalUnitView
	if unit == null or view == null:
		return
	# Status badges update in the same committed state-change callback as HP.
	# This prevents an eye or hood remaining visible after a unit has already
	# become Dying, unconscious or Dead. Dying pips remain 0/0 until the unit's
	# start-of-turn check changes the track.
	view.set_status_badges(TacticalStatusBadgeProvider.for_unit(unit))
	view.set_hidden_badge(unit.shows_hidden_badge())
	view.set_aware_badge(
		unit.team_id == &"enemy"
			and not unit.squad_id.is_empty()
			and _facade.state().is_squad_aware(unit.squad_id)
	)
	_life_state_visual_signature_by_unit_id[unit_id] = (
		_life_state_visual_signature(unit)
	)


func _life_state_visual_signature(unit: TacticalUnitState) -> String:
	if unit == null:
		return ""
	return "%s|%d|%d|%s" % [
		String(unit.life_state_id()),
		unit.dying_successes,
		unit.dying_failures,
		str(unit.restrained),
	]


func _sync_life_state_visuals_from_state() -> void:
	if _facade == null:
		return
	var current_ids: Dictionary = {}
	var attack_target_became_downed: bool = false
	for unit: TacticalUnitState in _facade.state().get_units():
		if unit == null:
			continue
		current_ids[unit.unit_id] = true
		var signature: String = _life_state_visual_signature(unit)
		if str(_life_state_visual_signature_by_unit_id.get(
			unit.unit_id,
			""
		)) == signature:
			continue
		_refresh_unit_status_badge_immediately(unit.unit_id)
		if unit.is_downed() and _selected_attack_target_id == unit.unit_id:
			attack_target_became_downed = true

	for cached_id: Variant in _life_state_visual_signature_by_unit_id.keys():
		if not current_ids.has(StringName(cached_id)):
			_life_state_visual_signature_by_unit_id.erase(cached_id)

	if not attack_target_became_downed:
		return
	# A normal contextual attack must never remain armed against a unit that has
	# already crossed into Dying, unconscious, or Dead. Deliberate attacks on
	# helpless targets can later use an explicit action.
	var downed_target_id: StringName = _selected_attack_target_id
	_selected_attack_target_id = &""
	_attack_preview = null
	_contextual_attack_hover_active = false
	_legal_attack_target_ids.erase(downed_target_id)
	_hide_attack_cursor_preview()
	_refresh_weapon_attack_strip()


func _refresh_all_unit_status_badges_immediately() -> void:
	if _facade == null:
		return
	for unit: TacticalUnitState in _facade.state().get_units():
		_refresh_unit_status_badge_immediately(unit.unit_id)


func _update_unit_finished_visuals() -> void:
	var phase_state: TacticalPhaseState = _facade.state().phase_state
	for unit: TacticalUnitState in _facade.state().get_units():
		var view := _unit_views.get(unit.unit_id) as TacticalUnitView
		if view != null:
			var body_item: TacticalItemInstanceState = (
				_facade.state().body_item_for_unit(unit.unit_id)
			)
			var presentation_animating: bool = _is_unit_presentation_animating(
				unit.unit_id
			)
			if body_item != null:
				if _facade.state().should_body_token_be_visible(body_item):
					var body_cell: Vector2i = _facade.state().body_ground_cell(body_item)
					if not presentation_animating:
						view.snap_to_tile(body_cell)
					view.visible = _facade.is_tile_visible_to_player(body_cell)
				else:
					# A packed body is a real spatial inventory item and has no ground token.
					view.visible = false
			else:
				if not presentation_animating:
					view.snap_to_tile(unit.grid_position)
				view.visible = _facade.is_unit_visible_to_player(unit.unit_id)
			view.set_visibly_finished(
				unit.action_budget.is_visibly_finished() or unit.is_defeated()
			)
			view.set_status_badges(TacticalStatusBadgeProvider.for_unit(unit))
			view.set_hidden_badge(unit.shows_hidden_badge())
			view.set_aware_badge(
				not unit.squad_id.is_empty()
				and _facade.state().is_squad_aware(unit.squad_id)
			)
			view.set_active_initiative(
				phase_state.is_initiative_combat()
				and phase_state.active_unit_id() == unit.unit_id
			)
			view.set_facing(unit.facing_direction)


func _is_unit_presentation_animating(unit_id: StringName) -> bool:
	if _animating_unit_ids.has(unit_id):
		return true
	var view := _unit_views.get(unit_id) as TacticalUnitView
	return view != null and view.is_movement_animating()


func _center_camera_on_selected_unit() -> void:
	if _selected_unit_id.is_empty() or _board_view == null:
		return
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return
	_board_view.center_on_tile(unit.grid_position)
	_set_status("Camera centred on %s." % unit.display_name)


func _refresh_path_preview() -> void:
	if _attack_targeting:
		var hovered_unit: TacticalUnitState = _facade.visible_unit_at_tile(
			_hovered_tile,
			_selected_unit_id
		)
		if hovered_unit != null:
			_clear_destination_preview_visuals()
			_refresh_attack_hover_preview()
			return
	if _board_intent_mode != BoardIntentMode.MOVE_PREVIEW:
		# State changes may ask the screen to revalidate presentation, but they
		# must never manufacture a path for the merely hovered tile.
		_clear_destination_preview_visuals()
		return
	if not _map_definition.is_inside(_planned_destination):
		_clear_move_preview_state()
		return
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if (
		unit == null
		or not unit.is_player_controlled()
		or not _facade.can_unit_act(unit.unit_id)
	):
		_clear_move_preview_state()
		return
	var destination_preview: TacticalDestinationPreview = (
		_destination_preview_for(unit, _planned_destination)
	)
	if (
		destination_preview == null
		or destination_preview.path_result == null
		or not destination_preview.path_result.success
	):
		_clear_move_preview_state()
	else:
		_apply_destination_preview(destination_preview)


func _destination_preview_for(
		unit: TacticalUnitState,
		destination: Vector2i
) -> TacticalDestinationPreview:
	if unit == null or not _map_definition.is_inside(destination):
		return null
	var key: String = _destination_preview_cache_key(unit, destination)
	if _destination_preview_cache.has(key):
		var cached: TacticalDestinationPreview = (
			_destination_preview_cache[key] as TacticalDestinationPreview
		)
		if (
			cached != null
			and cached.is_valid_for(
				_facade.state(),
				_facade.visibility_revision()
			)
		):
			_destination_preview_cache_hits += 1
			return cached
	_destination_preview_cache_misses += 1
	_hover_preview_build_count += 1
	var result := TacticalDestinationPreview.new()
	result.unit_id = unit.unit_id
	result.destination = destination
	result.movement_mode = _movement_mode
	result.tactical_revision = _facade.tactical_revision()
	result.geometry_revision = _facade.geometry_revision()
	result.knowledge_revision = _facade.knowledge_revision()
	result.visibility_revision = _facade.visibility_revision()
	result.path_result = _facade.preview_movement(
		unit.unit_id,
		destination,
		_movement_mode
	)
	if result.path_result != null and result.path_result.success:
		# The clicked destination owns one bounded Stealth preview. Cursor hover
		# never reaches this path, so restoring per-tile detection information does
		# not restore the former continuous geometry workload.
		_movement_detection_preview_query_count += 1
		result.detection_preview = _facade.preview_movement_detection(
			unit.unit_id,
			result.path_result
		)
		result.reaction_preview = _facade.preview_movement_reactions(
			unit.unit_id,
			result.path_result,
			_movement_mode
		)
		_reaction_preview_query_count += 1
		var final_tile: Vector2i = result.path_result.path.back()
		# Stage 4.5e7a calculates only the deliberately clicked destination field.
		# This preserves the smooth arrival handoff without baking every walkable
		# origin synchronously during mission startup.
		_facade.prepare_visibility_for_destination(unit.unit_id, final_tile)
		result.cover_preview = _facade.preview_destination_cover(
			unit.unit_id,
			final_tile
		)
		result.cover_field = _facade.directional_cover_field(final_tile)
		result.local_cover_category = (
			result.cover_field.strongest_local_cover
			if result.cover_field != null
			else TacticalCombatGeometryResult.COVER_NONE
		)
		result.automatic_peek_origins.clear()
	if _destination_preview_cache.size() >= 128:
		_destination_preview_cache.clear()
	_destination_preview_cache[key] = result
	return result


func _destination_preview_cache_key(
		unit: TacticalUnitState,
		destination: Vector2i
) -> String:
	return "%s|%d,%d|%d,%d|%s|%d|%d|%d|%d|%d" % [
		unit.unit_id,
		unit.grid_position.x,
		unit.grid_position.y,
		destination.x,
		destination.y,
		String(_movement_mode),
		unit.action_budget.remaining_turn_capacity_feet,
		_facade.tactical_revision(),
		_facade.geometry_revision(),
		_facade.knowledge_revision(),
		_facade.visibility_revision(),
	]


func _apply_destination_preview(
		preview: TacticalDestinationPreview
) -> void:
	if preview == null:
		return
	_preview_result = preview.path_result
	_detection_preview = preview.detection_preview
	_reaction_preview = preview.reaction_preview
	_cover_preview = preview.cover_preview
	_directional_cover_field = preview.cover_field


func _refresh_selected_cover_summary() -> void:
	if _facade == null or _selected_unit_id.is_empty():
		_selected_cover_category = &"neutral"
		return
	var summary: Dictionary = _facade.selected_unit_cover_summary(
		_selected_unit_id
	)
	_selected_cover_category = StringName(summary.get(
		"cover_category",
		&"neutral"
	))


func _apply_unit_cover_icons() -> void:
	# Exactly one contextual token shield may be visible. The movement ghost is
	# drawn by TacticalBoardView, so any active movement preview hides the real
	# selected-unit icon. Exposed, Total Cover and no-threat states draw no icon.
	for key: Variant in _unit_views.keys():
		var view := _unit_views[key] as TacticalUnitView
		if view != null:
			view.set_cover_category(&"")
	if (
		_attack_preview != null
		and not _selected_attack_target_id.is_empty()
	):
		var target_view := _unit_views.get(
			_selected_attack_target_id
		) as TacticalUnitView
		if target_view != null:
			target_view.set_cover_category(_cover_icon_category(StringName(
				_attack_preview.get("cover_category")
			)))
		return
	if _preview_result != null and _preview_result.success:
		return
	if not _selected_unit_id.is_empty():
		var selected_view := _unit_views.get(
			_selected_unit_id
		) as TacticalUnitView
		if selected_view != null:
			selected_view.set_cover_category(
				_cover_icon_category(_selected_cover_category)
			)


func _cover_icon_category(category: StringName) -> StringName:
	if category in [
		TacticalCombatGeometryResult.COVER_LIGHT,
		TacticalCombatGeometryResult.COVER_HEAVY,
	]:
		return category
	return &""


func _begin_enemy_stall_watch(unit_id: StringName) -> void:
	if unit_id.is_empty():
		return
	if _enemy_stall_active_unit_id != unit_id or _enemy_highlight_started_usec <= 0:
		_enemy_stall_active_unit_id = unit_id
		_enemy_stall_thresholds_emitted.clear()
		_enemy_highlight_started_usec = Time.get_ticks_usec()


func _finish_enemy_stall_watch(unit_id: StringName) -> void:
	if (
		unit_id.is_empty()
		or _enemy_stall_active_unit_id != unit_id
		or _enemy_highlight_started_usec <= 0
	):
		return
	_last_enemy_highlight_to_action_usec = maxi(
		0,
		Time.get_ticks_usec() - _enemy_highlight_started_usec
	)
	_enemy_highlight_started_usec = 0
	_enemy_stall_active_unit_id = &""
	_enemy_stall_thresholds_emitted.clear()


func _record_enemy_stall_thresholds(unit_id: StringName) -> void:
	if (
		unit_id.is_empty()
		or _enemy_stall_active_unit_id != unit_id
		or _enemy_highlight_started_usec <= 0
	):
		return
	var elapsed_usec: int = maxi(
		0,
		Time.get_ticks_usec() - _enemy_highlight_started_usec
	)
	for threshold_usec: int in ENEMY_STALL_THRESHOLDS_USEC:
		if elapsed_usec < threshold_usec:
			break
		var threshold_key: String = str(threshold_usec)
		if _enemy_stall_thresholds_emitted.has(threshold_key):
			continue
		_enemy_stall_thresholds_emitted[threshold_key] = true
		var enemy_snapshot: Dictionary = _facade.enemy_ai_performance_snapshot()
		var planner: Dictionary = enemy_snapshot.get("last_plan", {})
		var activation_timing: Dictionary = enemy_snapshot.get(
			"activation_timing", {}
		)
		var activation_last: Dictionary = activation_timing.get("last", {})
		var handoff_warmup: Dictionary = enemy_snapshot.get(
			"handoff_warmup", {}
		)
		var pending_planning: Dictionary = enemy_snapshot.get(
			"pending_planning", {}
		)
		var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
		var entry: Dictionary = {
			"threshold_usec": threshold_usec,
			"highlight_to_action_usec": elapsed_usec,
			"unit_id": unit_id,
			"unit_type": unit.roster_role if unit != null else &"unknown",
			"ai_profile": unit.ai_profile_id if unit != null else &"",
			"planning_stage": planner.get("planning_stage", &"unknown"),
			"planning_wall_clock_usec": planner.get("total_usec", 0),
			"planning_processing_usec": planner.get("processing_usec", 0),
			"planning_slice_count": planner.get("planning_slices", 0),
			"frame_yield_count": pending_planning.get(
				"frame_yields", _enemy_planning_yield_count
			),
			"reachable_field_builds": planner.get("reachable_field_builds", 0),
			"reachable_field_expansions": planner.get("pathfinding_expansions", 0),
			"reachable_tiles_generated": planner.get("reachable_tile_count", 0),
			"targeted_melee_search_builds": planner.get(
				"targeted_melee_search_builds", 0
			),
			"targeted_melee_expansions": planner.get(
				"targeted_melee_expansions", 0
			),
			"targeted_melee_goal_count": planner.get(
				"targeted_melee_goal_count", 0
			),
			"movement_capacity_searched": planner.get(
				"targeted_melee_attack_capacity_feet", 0
			),
			"targets_considered": planner.get("target_count", 0),
			"candidate_tiles_considered": planner.get("candidate_count", 0),
			"warmup_ready": handoff_warmup.get("ready", false),
			"warmup_reused": activation_last.get("handoff_warmup_reused", false),
			"warmup_invalidation_reason": handoff_warmup.get(
				"last_invalidation_reason", &""
			),
			"perception_usec": activation_last.get("perception", 0),
			"ability_usec": activation_last.get("ability_selection", 0),
			"support_usec": activation_last.get("support_and_rescue", 0),
			"transaction_usec": activation_last.get("simulation_usec", 0),
		}
		_enemy_stall_history.append(entry)
		while _enemy_stall_history.size() > ENEMY_STALL_HISTORY_LIMIT:
			_enemy_stall_history.pop_front()
		_enemy_stall_threshold_event_count += 1
		push_warning(
			"Stage 4.7 Hotfix 5f8 enemy stall attribution: %s"
			% JSON.stringify(entry)
		)


func _print_tactical_performance_snapshot() -> void:
	var snapshot: Dictionary = _facade.performance_snapshot()
	snapshot["destination_preview"] = {
		"cache_entries": _destination_preview_cache.size(),
		"cache_hits": _destination_preview_cache_hits,
		"cache_misses": _destination_preview_cache_misses,
		"preview_builds": _hover_preview_build_count,
		"detection_preview_queries": _movement_detection_preview_query_count,
		"hover_hud_refreshes": _hover_hud_refresh_count,
		"hover_board_refreshes": _hover_board_refresh_count,
	}
	snapshot["attack_selection_screen"] = {
		"attack_selections": _attack_selections,
		"deferred_target_scans": _deferred_attack_target_scans,
		"targeted_presentation_refreshes": _targeted_attack_presentation_refreshes,
		"last_attack_selection_total_usec": _last_attack_selection_total_usec,
		"last_attack_target_scan_usec": _last_attack_target_scan_usec,
	}
	snapshot["post_attack"] = {
		"reconciliations": _post_attack_reconciliations,
		"broad_refreshes_avoided": _post_attack_refreshes_avoided,
		"immediate_impacts_presented": _immediate_combat_impacts_presented,
		"last_reconciliation_usec": _last_post_attack_reconciliation_usec,
		"reconciliation_scheduled": _post_attack_reconciliation_scheduled,
		"command_in_progress": _attack_command_in_progress,
		"command_acknowledgements": _attack_command_acknowledgements,
		"command_frame_yields": _attack_command_frame_yields,
		"dead_frames_avoided": _attack_command_dead_frames_avoided,
		"clicks_using_primed_preview": _attack_clicks_using_primed_preview,
		"click_preview_fallbacks": _attack_click_preview_fallbacks,
		"last_click_to_result_usec": _last_attack_click_to_result_usec,
		"last_click_to_impact_usec": _last_attack_click_to_impact_usec,
	}
	if _combat_log != null and _combat_log.has_method("performance_snapshot"):
		snapshot["combat_log"] = _combat_log.call("performance_snapshot")
	snapshot["movement_handoff"] = {
		"targeted_refresh_count": _targeted_post_movement_refresh_count,
		"last_refresh_usec": _last_post_movement_refresh_usec,
		"last_animation_and_refresh_usec": _last_movement_handoff_total_usec,
		"last_cadence_event": _last_cadence_event,
		"last_cadence_seconds": _last_cadence_seconds,
		"cadence_event_counts": _cadence_event_count_by_kind.duplicate(true),
	}
	snapshot["offscreen_enemy_presentation"] = {
		"unobserved_movement_batches_completed_immediately": (
			_unobserved_ai_movement_batches_completed_immediately
		),
		"unobserved_movement_events_skipped": (
			_unobserved_ai_movement_events_skipped
		),
		"partially_observed_movement_events_presented": (
			_partially_observed_ai_movement_events_presented
		),
		"observed_movement_events_presented": (
			_observed_ai_movement_events_presented
		),
		"unobserved_activation_handoffs_skipped": (
			_unobserved_ai_activation_handoffs_skipped
		),
		"unobserved_enemy_phase_handoffs_skipped": (
			_unobserved_enemy_phase_handoffs_skipped
		),
		"enemy_phase_frame_yields": _enemy_phase_frame_yields,
		"hidden_activations_batched": _enemy_phase_hidden_activations_batched,
		"side_based_activation_pulses": _side_based_enemy_activation_pulses,
		"observable_stationary_frame_yields": (
			_observable_stationary_activation_frame_yields
		),
		"last_activation_simulation_usec": _last_ai_activation_simulation_usec,
		"last_activation_presentation_usec": _last_ai_activation_presentation_usec,
		"last_activation_total_usec": _last_ai_activation_total_usec,
		"planning_slice_count": _enemy_planning_slice_count,
		"planning_yield_count": _enemy_planning_yield_count,
		"planning_max_slices_per_frame": (
			_enemy_planning_max_slices_per_frame
		),
		"hidden_planning_frames": _enemy_hidden_planning_frames,
		"destination_visibility_yield_count": (
			_destination_visibility_yield_count
		),
		"destination_visibility_same_frame_completions": (
			_destination_visibility_same_frame_completions
		),
		"destination_visibility_final_budget_overruns": (
			_destination_visibility_final_budget_overruns
		),
		"visible_activation_dead_frames_avoided": (
			_visible_activation_dead_frames_avoided
		),
		"end_phase_to_first_enemy_feedback_usec": (
			_end_phase_to_first_enemy_feedback_usec
		),
		"end_phase_to_first_visible_action_usec": (
			_end_phase_to_first_visible_action_usec
		),
		"end_phase_to_first_visible_movement_usec": (
			_end_phase_to_first_visible_movement_usec
		),
		"frames_yielded_before_first_visible_action": (
			_frames_yielded_before_first_visible_action
		),
		"hidden_actors_before_first_visible_action": (
			_hidden_actors_before_first_visible_action
		),
		"enemy_phase_commit_usec": maxi(
			0, _enemy_phase_committed_usec - _enemy_phase_requested_usec
		),
		"first_actor_feedback_started_usec": _first_actor_feedback_started_usec,
		"first_movement_tween_started_usec": _first_movement_tween_started_usec,
	}
	snapshot["empty_enemy_phase"] = {
		"hidden_auto_pass_refreshes_avoided": (
			_hidden_auto_pass_refreshes_avoided
		),
		"last_empty_enemy_phase_usec": _last_empty_enemy_phase_usec,
		"end_phase_to_player_control_restored_usec": (
			_end_phase_to_player_control_restored_usec
		),
		"enemy_phase_input_lock_usec": (
			maxi(
				0,
				Time.get_ticks_usec() - _enemy_phase_input_lock_started_usec
			)
			if _enemy_phase_input_lock_started_usec > 0
			else 0
		),
	}
	snapshot["player_to_enemy_handoff"] = {
		"handoff_requested_usec": _handoff_requested_usec,
		"feedback_started_usec": _handoff_feedback_started_usec,
		"idle_warmup_processing_usec": (
			_handoff_idle_warmup_processing_usec
		),
		"idle_warmup_frames": _handoff_idle_warmup_frames,
		"warmup_ready_frames": _handoff_warmup_ready_frames,
		"handoff_to_feedback_usec": (
			maxi(0, _handoff_feedback_started_usec - _handoff_requested_usec)
			if _handoff_feedback_started_usec > 0 and _handoff_requested_usec > 0
			else 0
		),
		"handoff_to_authoritative_commit_usec": (
			_handoff_to_authoritative_commit_usec
		),
		"handoff_to_movement_tween_usec": _handoff_to_movement_tween_usec,
		"full_refreshes_before_ai_avoided": _handoff_full_refreshes_avoided,
		"duplicate_ai_schedules_avoided": (
			_handoff_duplicate_ai_schedules_avoided
		),
		"chain_warmup_processing_usec": _chain_warmup_processing_usec,
		"chain_warmup_frames": _chain_warmup_frames,
		"chain_warmup_ready_frames": _chain_warmup_ready_frames,
		"chain_warmup_reused_count": _chain_warmup_reused_count,
		"pre_activation_handoff_validations": (
			_pre_activation_handoff_validations
		),
		"enemy_highlight_to_action_usec": (
			_last_enemy_highlight_to_action_usec
		),
		"enemy_to_enemy_handoff_usec": _last_enemy_to_enemy_handoff_usec,
		"duplicate_enemy_refreshes_avoided": (
			_duplicate_enemy_refreshes_avoided
		),
		"hidden_actor_refreshes_avoided": _hidden_actor_refreshes_avoided,
		"forced_inter_actor_frames_avoided": (
			_forced_inter_actor_frames_avoided
		),
		"presentation_wall_time_excluded_usec": (
			_presentation_wall_time_excluded_usec
		),
	}
	snapshot["enemy_runtime_stall_attribution"] = {
		"active_unit_id": _enemy_stall_active_unit_id,
		"threshold_event_count": _enemy_stall_threshold_event_count,
		"history": _enemy_stall_history.duplicate(true),
	}
	snapshot["enemy_cadence_polish"] = {
		"blocking_alert_acknowledgement_usec": (
			_blocking_alert_acknowledgement_usec
		),
		"adaptive_visible_handoff_usec": _adaptive_visible_handoff_usec,
		"adaptive_visible_handoff_count": _adaptive_visible_handoff_count,
		"last_visible_movement_duration_seconds": (
			_last_ai_visible_movement_duration_seconds
		),
	}
	snapshot["contact_transition"] = {
		"contact_detected_usec": _contact_detected_usec,
		"activation_pulse_started_usec": _contact_ai_pulse_started_usec,
		"first_movement_tween_started_usec": (
			_contact_first_movement_tween_started_usec
		),
		"contact_to_activation_pulse_usec": (
			maxi(0, _contact_ai_pulse_started_usec - _contact_detected_usec)
			if _contact_ai_pulse_started_usec > 0 and _contact_detected_usec > 0
			else 0
		),
		"activation_pulse_to_movement_tween_usec": (
			maxi(
				0,
				_contact_first_movement_tween_started_usec
				- _contact_ai_pulse_started_usec
			)
			if (
				_contact_first_movement_tween_started_usec > 0
				and _contact_ai_pulse_started_usec > 0
			)
			else 0
		),
		"warmup_started_usec": _contact_ai_warmup_started_usec,
		"warmup_completed_usec": _contact_ai_warmup_completed_usec,
		"warmup_processing_usec": _contact_ai_warmup_processing_usec,
		"warmup_frames": _contact_ai_warmup_frames,
		"warmup_abandoned": _contact_ai_warmup_abandoned,
		"duplicate_contact_refreshes_avoided": (
			_duplicate_contact_refreshes_avoided
		),
		"presentation_ready_unit_id": _contact_presentation_ready_unit_id,
	}
	if _board_view != null and _board_view.has_method("performance_snapshot"):
		snapshot["board"] = _board_view.call("performance_snapshot")
	print("Stage 4.4e performance: %s" % JSON.stringify(snapshot))


func _refresh_all_presentation(
		refresh_contextual_attack: bool = true
) -> void:
	_ensure_selected_unit_is_visible()
	if _selected_unit_is_player_controlled():
		var remembered_hand: StringName = _valid_hand_kind_or_primary(
			StringName(
				_selected_hand_by_unit_id.get(
					_selected_unit_id,
					TacticalInventoryState.KIND_PRIMARY_HAND
				)
			)
		)
		if (
			_selected_weapon_hand_kind.is_empty()
			or _selected_weapon_hand_kind != remembered_hand
		):
			_select_default_weapon_for_unit()
		else:
			_sync_selected_hand_attack()
	if refresh_contextual_attack and not _attack_targeting:
		_refresh_contextual_hand_attack_hover_preview()
	_update_unit_selection_visuals()
	_update_unit_finished_visuals()
	_refresh_hud()
	if _inventory_open:
		_refresh_inventory_panel()
	_refresh_board_view()


func _ensure_selected_unit_is_visible() -> void:
	if _selected_unit_id.is_empty():
		return
	var selected: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if selected == null:
		_selected_unit_id = &""
		return
	if selected.team_id != &"player" and not _facade.is_unit_visible_to_player(
		selected.unit_id
	):
		_selected_unit_id = &""
		_selected_attack_target_id = &""
		_attack_preview = null
		_contextual_attack_hover_active = false


func _selected_unit_is_player_controlled() -> bool:
	if _facade == null or _selected_unit_id.is_empty():
		return false
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	return unit != null and unit.is_player_controlled()


func _refresh_hud() -> void:
	var phase_state: TacticalPhaseState = _facade.state().phase_state
	var phase_name: String = "PLAYER TEAM"
	if phase_state.current_phase == TacticalPhaseState.ENEMY_PHASE:
		phase_name = "ENEMY TEAM"
	elif phase_state.is_world_phase():
		phase_name = "WORLD TEAM"

	if phase_state.is_initiative_combat():
		var active: TacticalUnitState = _facade.active_initiative_unit()
		var hidden_ai_active: bool = (
			active != null
			and active.is_ai_controlled()
			and not _facade.is_unit_visible_to_player(active.unit_id)
		)
		if hidden_ai_active:
			_phase_label.text = "ROUND %d · INITIATIVE · ENEMY ACTIVITY" % [
				phase_state.round_number,
			]
			_round_short_label.text = "Round %d\n%s" % [
				phase_state.round_number,
				"CONTACT" if phase_state.contact_round_active else "INITIATIVE",
			]
			if not _selected_unit_id.is_empty():
				var selected_hidden: TacticalUnitState = _facade.state().get_unit(
					_selected_unit_id
				)
				if (
					selected_hidden != null
					and selected_hidden.is_ai_controlled()
					and not _facade.is_unit_visible_to_player(selected_hidden.unit_id)
				):
					_selected_unit_id = &""
		else:
			var active_name: String = active.display_name if active != null else "No active unit"
			var active_total: int = (
				_facade.initiative_total(active.unit_id) if active != null else 0
			)
			_phase_label.text = "ROUND %d · INITIATIVE · %s (%d)" % [
				phase_state.round_number,
				active_name,
				active_total,
			]
			_round_short_label.text = "Round %d\n%s" % [
				phase_state.round_number,
				"CONTACT" if phase_state.contact_round_active else "INITIATIVE",
			]
	else:
		_phase_label.text = "ROUND %d · INFILTRATION · %s" % [
			phase_state.round_number,
			phase_name,
		]
		_round_short_label.text = "Round %d\n%s" % [
			phase_state.round_number,
			phase_name,
		]
	var objective_hud_text: String = _facade.objective_hud_text()
	var compact_objective_text: String = objective_hud_text.get_slice("\n", 0)
	_objective_label.text = "OBJECTIVE · %s" % compact_objective_text
	_objective_label.tooltip_text = objective_hud_text
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if phase_state.is_initiative_combat():
		_hint_label.text = _initiative_order_summary(false)
		_hint_label.tooltip_text = _initiative_order_summary(true)
	else:
		# Stage 4.2.5.4 compatibility wording: Right-click: Face (5 ft)
		_hint_label.text = (
			"Ability targeting · Left-click target · Right-click cancels"
			if _attack_targeting
			else "Selected hand: click legal hostile to attack · Left-click twice: Move · Right-click twice: Face (5 ft) · Opposite click cancels · V Perception cones · Wheel Zoom · Middle-drag / Arrows Pan"
		)
		_hint_label.tooltip_text = _hint_label.text

	_refresh_unit_buttons()
	_end_phase_button.text = (
		"END TURN" if phase_state.is_initiative_combat() else "END TEAM PHASE"
	)
	_end_phase_button.disabled = (
		_facade.mission_resolution_locked()
		or not phase_state.is_player_phase()
		or _world_phase_in_progress
		or (
			phase_state.is_initiative_combat()
			and (
				_facade.active_initiative_unit() == null
				or not _facade.active_initiative_unit().is_player_controlled()
			)
		)
	)
	_refresh_extraction_button()

	if _selected_unit_id == &"":
		_short_name_label.text = "No unit"
		_unit_health_bar.visible = false
		_unit_health_bar.call("set_values", 0, 1, 0)
		_short_hp_label.text = "AC -"
		_short_capacity_label.text = "Capacity - · Q - · R -"
		_unit_capacity_bar.max_value = 1.0
		_unit_capacity_bar.value = 0.0
		_unit_capacity_value_label.text = "— / — ft"
		_unit_capacity_value_label.tooltip_text = "No unit selected."
		_short_context_label.text = "Select a unit."
		_short_context_label.tooltip_text = "Select a unit."
		_disable_command_buttons("Select a unit first.")
		_refresh_weapon_attack_strip()
		return

	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		_disable_command_buttons("The selected unit does not exist.")
		return



	_short_name_label.text = unit.display_name
	_unit_health_bar.visible = true
	_unit_health_bar.call(
		"set_values",
		unit.current_hp,
		unit.maximum_hp,
		unit.nonlethal_damage
	)
	_short_hp_label.text = "AC %d" % unit.armour_class
	_short_capacity_label.text = (
		_life_state_short_label(unit)
		if unit.is_defeated() or unit.is_disabled()
		else "%d/%d ft · %s · %s · %s" % [
		unit.action_budget.remaining_turn_capacity_feet,
		unit.action_budget.maximum_turn_capacity_feet,
		"A ready"
			if unit.action_budget.ordinary_attack_available
			else "A spent",
		"Q ready" if unit.action_budget.quick_action_available else "Q spent",
		"R %s" % unit.action_budget.reaction_label(),
		]
	)
	_unit_capacity_bar.max_value = unit.action_budget.maximum_turn_capacity_feet
	_unit_capacity_bar.value = unit.action_budget.remaining_turn_capacity_feet
	_unit_capacity_value_label.text = "%d / %d ft" % [
		unit.action_budget.remaining_turn_capacity_feet,
		unit.action_budget.maximum_turn_capacity_feet,
	]
	_unit_capacity_value_label.tooltip_text = (
		"Turn capacity: %d / %d ft\nHalf Action threshold: %d ft"
		% [
			unit.action_budget.remaining_turn_capacity_feet,
			unit.action_budget.maximum_turn_capacity_feet,
			_facade.half_action_cost_feet(unit.unit_id),
		]
	)

	_left_hand_button.disabled = false
	_right_hand_button.disabled = false

	for command_button: Button in [
		_abilities_button,
		_tactics_button,
		_inventory_button,
		_interact_button,
		_end_unit_button,
	]:
		command_button.tooltip_text = ""

	var secondary_hand_name: String = _facade.state().hand_display_name(unit.unit_id, TacticalInventoryState.KIND_SECONDARY_HAND)
	if secondary_hand_name.is_empty():
		secondary_hand_name = "Empty"

	var primary_hand_name: String = _facade.state().hand_display_name(unit.unit_id, TacticalInventoryState.KIND_PRIMARY_HAND)
	if primary_hand_name.is_empty():
		primary_hand_name = "Empty"

	_left_hand_button.text = "SECONDARY\n%s" % secondary_hand_name
	_right_hand_button.text = "PRIMARY\n%s" % primary_hand_name
	_left_hand_button.tooltip_text = (
		"Secondary Hand: %s\nClick to keep this hand selected for contextual basic attacks."
		% secondary_hand_name
	)
	_right_hand_button.tooltip_text = (
		"Primary Hand: %s\nClick to keep this hand selected for contextual basic attacks."
		% primary_hand_name
	)

	var nearby_count: int = _facade.state().get_accessible_ground_items(unit).size()
	_inventory_button.text = (
		"Inventory (%d)" % nearby_count
		if nearby_count > 0
		else "Inventory"
	)

	var quick_text := (
		"Q ready"
		if unit.action_budget.quick_action_available
		else "Q spent"
	)
	var reaction_text := "R %s" % unit.action_budget.reaction_label()
	var path_context := _last_status_message
	if unit.is_defeated() or unit.is_disabled():
		path_context = _life_state_hud_context(unit)

	if (
		(_attack_targeting or _contextual_attack_hover_active)
		and not _selected_attack_target_id.is_empty()
	):
		path_context = _attack_preview_status()
	elif (
		_board_intent_mode == BoardIntentMode.MOVE_PREVIEW
		and _map_definition.is_inside(_planned_destination)
	):
		if _preview_result == null or not _preview_result.success:
			path_context = (
				_preview_result.failure_reason
				if _preview_result != null
				else "Unavailable"
			)
		elif _movement_mode == &"sprint":
			path_context = (
				"SPRINT: %d ft · Full Action · Reaction lost"
				% _preview_result.cost_feet
			)
		else:
			var remaining_after := (
				unit.action_budget.remaining_turn_capacity_feet
				- _preview_result.cost_feet
			)
			var half_cost: int = _facade.half_action_cost_feet(unit.unit_id)
			var action_note := (
				"Half Action remains"
				if remaining_after >= half_cost
				else "No Half Action remains"
			)
			path_context = (
				"Path: %d ft · %d ft after · %s"
				% [_preview_result.cost_feet, remaining_after, action_note]
			)

	if _detection_preview != null and _detection_preview.has_detection_risk():
		var detection_text: String
		var check_count: int = _detection_preview.risk_tile_count()
		if _detection_preview.automatic_detection:
			detection_text = (
				"Stealth checks: %d · exposed tiles show 0%% outside Stealth"
				% check_count
			)
		elif _detection_preview.has_unknown_observers:
			detection_text = (
				"Stealth checks: %d · some chances are unknown"
				% check_count
			)
		else:
			detection_text = (
				"Stealth checks: %d · worst avoid %d%% · Stealth %+d vs highest DC %d"
				% [
					check_count,
					_detection_preview.avoid_detection_chance_percent,
					_detection_preview.stealth_bonus,
					_detection_preview.effective_detection_dc,
				]
			)
		path_context += " · " + detection_text

	if _reaction_preview != null and _reaction_preview.has_reaction_risk():
		path_context += (
			" · Known Reactions: %d · highest hit %d%%"
			% [
				_reaction_preview.candidate_summaries.size(),
				_reaction_preview.highest_hit_chance(),
			]
		)

	if _facing_preview_direction != Vector2i.ZERO:
		path_context += " · Preview Face %s (%d ft) · right-click again to confirm" % [
			_facing_label(_facing_preview_direction),
			_facade.face_direction_cost_feet(),
		]
	path_context += " · Facing %s · Passive Perception %d" % [
		_facing_label(unit.facing_direction),
		unit.passive_perception(),
	]
	_short_context_label.text = "%s · %s · %s" % [
		quick_text,
		reaction_text,
		path_context,
	]
	_short_context_label.tooltip_text = _short_context_label.text

	var player_controlled: bool = (
		unit.is_player_controlled()
		and not unit.is_defeated()
		and _facade.can_unit_act(unit.unit_id)
	)
	_left_hand_button.disabled = not player_controlled
	_right_hand_button.disabled = not player_controlled
	_attack_button.disabled = true
	_abilities_button.disabled = not player_controlled
	_tactics_button.disabled = not player_controlled
	_inventory_button.disabled = false
	_interact_button.disabled = not player_controlled
	_end_unit_button.disabled = not player_controlled
	_end_unit_button.text = (
		"End Turn"
		if phase_state.is_initiative_combat()
		else (
			"Reactivate"
			if unit.action_budget.ended_activation
			else "End Unit"
		)
	)

	_refresh_context_action_availability()
	_refresh_weapon_attack_strip()


func _life_state_short_label(unit: TacticalUnitState) -> String:
	match unit.life_state_id():
		TacticalUnitState.LIFE_STATE_DISABLED:
			return "DISABLED — %d/%d ft · no Reaction" % [
				unit.action_budget.remaining_turn_capacity_feet,
				unit.action_budget.maximum_turn_capacity_feet,
			]
		TacticalUnitState.LIFE_STATE_DYING:
			return "DYING — %d/3 successes · %d/3 failures" % [
				unit.dying_successes,
				unit.dying_failures,
			]
		TacticalUnitState.LIFE_STATE_STABLE_UNCONSCIOUS:
			return "STABLE — unconscious"
		TacticalUnitState.LIFE_STATE_NONLETHAL_UNCONSCIOUS:
			return "UNCONSCIOUS — nonlethal"
		TacticalUnitState.LIFE_STATE_DEAD:
			return "DEAD"
	return "%d/%d ft" % [
		unit.action_budget.remaining_turn_capacity_feet,
		unit.action_budget.maximum_turn_capacity_feet,
	]


func _life_state_hud_context(unit: TacticalUnitState) -> String:
	match unit.life_state_id():
		TacticalUnitState.LIFE_STATE_DISABLED:
			return (
				"DISABLED at 0 HP · 50%% capacity · no Reaction · "
				+ "strenuous actions cost 1 HP after resolving"
			)
		TacticalUnitState.LIFE_STATE_DYING:
			return (
				"DYING · HP %d/%d · Fort %+d vs DC %d · "
				+ "%d/3 successes · %d/3 failures · death at %d HP"
			) % [
				unit.current_hp,
				unit.maximum_hp,
				unit.fortitude_bonus(),
				unit.dying_check_dc(),
				unit.dying_successes,
				unit.dying_failures,
				unit.death_threshold_hp(),
			]
		TacticalUnitState.LIFE_STATE_STABLE_UNCONSCIOUS:
			return (
				"STABLE · HP %d/%d · unconscious · no Dying check"
				% [unit.current_hp, unit.maximum_hp]
			)
		TacticalUnitState.LIFE_STATE_NONLETHAL_UNCONSCIOUS:
			return (
				"UNCONSCIOUS from nonlethal damage · not Dying · "
				+ "nonlethal %d"
			) % unit.nonlethal_damage
		TacticalUnitState.LIFE_STATE_DEAD:
			return "DEAD · body remains on the battlefield"
	return _last_status_message


func _initiative_order_summary(full: bool) -> String:
	var phase_state: TacticalPhaseState = _facade.state().phase_state
	if not phase_state.is_initiative_combat():
		return ""
	var order_size: int = phase_state.initiative_order.size()
	if order_size <= 0:
		return "TURN ORDER · —"
	var labels: Array[String] = []
	var entries_to_show: int = order_size if full else mini(5, order_size)
	var start_index: int = 0 if full else maxi(0, phase_state.active_initiative_index)
	for offset: int in range(entries_to_show):
		var index: int = offset if full else (start_index + offset) % order_size
		var unit_id: StringName = phase_state.initiative_order[index]
		var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
		if unit == null:
			continue
		var active_marker: String = ">" if index == phase_state.active_initiative_index else ""
		if unit.is_ai_controlled() and not _facade.is_unit_visible_to_player(unit_id):
			labels.append("%s%d Unknown enemy" % [active_marker, index + 1])
			continue
		var life_suffix: String = ""
		match unit.life_state_id():
			TacticalUnitState.LIFE_STATE_DYING:
				life_suffix = " [DYING %dS/%dF]" % [
					unit.dying_successes,
					unit.dying_failures,
				]
			TacticalUnitState.LIFE_STATE_STABLE_UNCONSCIOUS:
				life_suffix = " [STABLE]"
			TacticalUnitState.LIFE_STATE_NONLETHAL_UNCONSCIOUS:
				life_suffix = " [UNCONSCIOUS]"
			TacticalUnitState.LIFE_STATE_DEAD:
				life_suffix = " [DEAD]"
		labels.append(
			"%s%d %s%s %d" % [
				active_marker,
				index + 1,
				unit.display_name,
				life_suffix,
				phase_state.initiative_total(unit_id),
			]
		)
	if not full and order_size > entries_to_show:
		labels.append("…")
	var pending_ids: Array[StringName] = _facade.pending_initiative_order()
	if not pending_ids.is_empty():
		var pending_labels: Array[String] = []
		for pending_id: StringName in pending_ids:
			var pending_unit: TacticalUnitState = _facade.state().get_unit(
				pending_id
			)
			if pending_unit != null:
				if (
					pending_unit.is_ai_controlled()
					and not _facade.is_unit_visible_to_player(pending_id)
				):
					pending_labels.append("Unknown enemy")
				else:
					pending_labels.append("%s %d" % [
						pending_unit.display_name,
						phase_state.initiative_total(pending_id),
					])
		if not pending_labels.is_empty():
			labels.append(
				"JOINS NEXT ROUND: %s"
				% ", ".join(PackedStringArray(pending_labels))
			)
	return "TURN ORDER · %s" % "  ·  ".join(PackedStringArray(labels))


func _refresh_unit_buttons() -> void:
	var player_phase: bool = _facade.state().phase_state.is_player_phase()
	for index: int in range(_player_unit_order.size()):
		var unit_id: StringName = _player_unit_order[index]
		var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
		if unit == null:
			continue
		var button: Button = _unit_buttons.get(unit.unit_id) as Button
		if button == null:
			continue
		button.call(
			"refresh_unit",
			unit,
			index + 1,
			player_phase,
			unit.unit_id == _selected_unit_id
		)


func _disable_command_buttons(reason: String) -> void:
	for button: Button in [
		_attack_button,
		_abilities_button,
		_tactics_button,
		_interact_button,
		_end_unit_button,
	]:
		button.disabled = true
		button.tooltip_text = reason

	_inventory_button.disabled = _selected_unit_id == &""
	_inventory_button.tooltip_text = reason
	_left_hand_button.disabled = true
	_right_hand_button.disabled = true
	_attack_mode_button.disabled = true
	_power_attack_down_button.disabled = true
	_power_attack_value_button.disabled = true
	_power_attack_up_button.disabled = true


func _reset_player_to_enemy_handoff_timeline() -> void:
	_handoff_requested_usec = Time.get_ticks_usec()
	_handoff_feedback_started_usec = 0
	_handoff_to_authoritative_commit_usec = 0
	_handoff_to_movement_tween_usec = 0


func _on_end_unit_pressed() -> void:
	if not _selected_unit_is_player_controlled():
		_set_status("Only player-controlled units have activations here.")
		return

	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return

	var result: OperationResult
	if _facade.is_initiative_combat():
		_reset_player_to_enemy_handoff_timeline()
		_player_to_enemy_handoff_in_progress = true
		if _board_view != null:
			_board_view.set_input_enabled(false)
		result = _facade.end_initiative_turn(unit.unit_id)
		_player_to_enemy_handoff_in_progress = false
	else:
		if unit.action_budget.ended_activation:
			result = _facade.reactivate_unit(_selected_unit_id)
		else:
			result = _facade.end_unit(_selected_unit_id)

	_set_status(result.message)
	_movement_mode = &"normal"
	_clear_board_intent(false)
	if result.success and _facade.is_initiative_combat():
		_begin_seamless_initiative_handoff()
	else:
		_refresh_hud()
		_refresh_board_view()
		if (
			_board_view != null
			and _facade.state().phase_state.is_player_phase()
			and not _facade.mission_resolution_locked()
		):
			_board_view.set_input_enabled(true)


func _begin_seamless_initiative_handoff() -> void:
	var active: TacticalUnitState = _facade.active_initiative_unit()
	if active == null or not active.is_ai_controlled():
		_refresh_all_presentation()
		if (
			_board_view != null
			and active != null
			and active.is_player_controlled()
			and not _facade.mission_resolution_locked()
		):
			_board_view.set_input_enabled(true)
		return
	_handoff_feedback_started_usec = Time.get_ticks_usec()
	if _unit_handoff_is_observable(active):
		_selected_unit_id = active.unit_id
		_contact_presentation_ready_unit_id = active.unit_id
		_update_unit_selection_visuals()
		_update_unit_finished_visuals()
		_refresh_hud()
		if _last_handoff_pulsed_unit_id != active.unit_id:
			_play_active_unit_handoff_pulse(active.unit_id)
	else:
		_unobserved_ai_activation_handoffs_skipped += 1
		_refresh_hud()
	# The state callback was deliberately prevented from scheduling this actor.
	# Start the warmed AI coordinator immediately in the same input frame.
	_run_initiative_ai()


func _on_end_phase_pressed() -> void:
	if _facade.mission_resolution_locked():
		return
	# Compatibility text for Stage 4.0.1 validator: Enemy Turn: AI-controlled enemy units are activating.
	if _world_phase_in_progress:
		return
	if _facade.is_initiative_combat():
		var active: TacticalUnitState = _facade.active_initiative_unit()
		if active == null or not active.is_player_controlled():
			_set_status("Only the active player unit can end this initiative turn.")
			return
		_reset_player_to_enemy_handoff_timeline()
		_player_to_enemy_handoff_in_progress = true
		if _board_view != null:
			_board_view.set_input_enabled(false)
		var initiative_result: OperationResult = _facade.end_initiative_turn(
			active.unit_id
		)
		_player_to_enemy_handoff_in_progress = false
		_set_status(initiative_result.message)
		_clear_board_intent(false)
		if initiative_result.success:
			_begin_seamless_initiative_handoff()
		else:
			_refresh_all_presentation()
			if _board_view != null:
				_board_view.set_input_enabled(true)
		return

	_enemy_phase_requested_usec = Time.get_ticks_usec()
	_enemy_phase_input_lock_started_usec = _enemy_phase_requested_usec
	_end_phase_to_player_control_restored_usec = 0
	_last_empty_enemy_phase_usec = 0
	_reset_player_to_enemy_handoff_timeline()
	_enemy_phase_requested_usec = _handoff_requested_usec
	_player_to_enemy_handoff_in_progress = true
	if _board_view != null:
		_board_view.set_input_enabled(false)
	var begin_result: OperationResult = _facade.begin_enemy_phase()
	_player_to_enemy_handoff_in_progress = false
	if not begin_result.success:
		_set_status(begin_result.message)
		_refresh_all_presentation()
		if _board_view != null:
			_board_view.set_input_enabled(true)
		_enemy_phase_input_lock_started_usec = 0
		return

	_close_inventory_silently()
	if _board_view != null:
		_board_view.set_input_enabled(false)
	_clear_attack_targeting_state()
	_world_phase_in_progress = true
	_enemy_phase_had_observable_activity = _has_visible_enemy_turn_participant()
	_enemy_phase_committed_usec = Time.get_ticks_usec()
	_end_phase_to_first_enemy_feedback_usec = 0
	_end_phase_to_first_visible_action_usec = 0
	_first_enemy_feedback_recorded = false
	_first_visible_enemy_action_recorded = false
	_end_phase_to_first_visible_movement_usec = 0
	_frames_yielded_before_first_visible_action = 0
	_hidden_actors_before_first_visible_action = 0
	_first_actor_feedback_started_usec = 0
	_first_movement_tween_started_usec = 0
	_movement_mode = &"normal"
	_clear_board_intent(false)
	_set_status("Enemy Phase: AI-controlled enemy units are activating.")
	# The phase transaction already updated authoritative state. Publish only the
	# compact phase/selection delta before consuming the warmed first plan.
	_update_unit_selection_visuals()
	_update_unit_finished_visuals()
	_refresh_hud()
	_handoff_full_refreshes_avoided += 1
	if _enemy_phase_had_observable_activity:
		await _await_presentation_cadence(PresentationCadenceEvent.PHASE_HANDOFF)
	else:
		_unobserved_enemy_phase_handoffs_skipped += 1

	var enemy_result: OperationResult = await _resolve_enemy_phase_with_reaction_prompts()
	_set_status("Enemy Phase completed." if enemy_result.success else enemy_result.message)
	if not enemy_result.success:
		_world_phase_in_progress = false
		_refresh_all_presentation()
		_restore_player_input_after_phase_flow()
		return
	# Stage 4.4e3: completed animations and real Reaction choices supply pacing.
	# Hand off to the world phase immediately when no further event is pending.

	var world_result: OperationResult = _facade.begin_environment_phase()
	if not world_result.success:
		_world_phase_in_progress = false
		_set_status(world_result.message)
		_refresh_all_presentation()
		_restore_player_input_after_phase_flow()
		return
	# The current world phase has no visible authored event. Resolve it without
	# inserting an empty presentation frame; future visible world events should
	# publish their own event-specific pause instead of restoring a blanket wait.
	_set_status("World Phase: environmental and neutral activity resolves.")
	var complete_result: OperationResult = _facade.complete_world_phase()
	_world_phase_in_progress = false
	_set_status(complete_result.message)
	_select_default_weapon_for_unit()
	_refresh_all_presentation()
	_restore_player_input_after_phase_flow()
	if not _enemy_phase_had_observable_activity and _enemy_phase_requested_usec > 0:
		_last_empty_enemy_phase_usec = maxi(
			0,
			Time.get_ticks_usec() - _enemy_phase_requested_usec
		)


func _restore_player_input_after_phase_flow() -> void:
	var phase_state: TacticalPhaseState = (
		_facade.state().phase_state
		if _facade != null and _facade.state() != null
		else null
	)
	if (
		_board_view != null
		and phase_state != null
		and phase_state.is_player_phase()
		and not _facade.mission_resolution_locked()
	):
		_board_view.set_input_enabled(true)
	if _enemy_phase_input_lock_started_usec > 0:
		_end_phase_to_player_control_restored_usec = maxi(
			0,
			Time.get_ticks_usec() - _enemy_phase_input_lock_started_usec
		)
	_enemy_phase_input_lock_started_usec = 0
	_player_to_enemy_handoff_in_progress = false
	_world_phase_in_progress = false


func _refresh_extraction_button() -> void:
	if _extract_button == null:
		return
	if _facade.mission_resolution_locked():
		_extract_button.text = "RESOLVED"
		_extract_button.disabled = true
		_extract_button.tooltip_text = "Mission resolution is complete or in progress."
		return
	var manifest: TacticalExtractionManifest = (
		_facade.preview_extraction_manifest()
	)
	_extract_button.text = (
		"COMPLETE MISSION"
		if manifest.required_objectives_complete
		else "WITHDRAW"
	)
	var phase_state: TacticalPhaseState = _facade.state().phase_state
	var player_may_confirm: bool = phase_state.is_player_phase()
	if phase_state.is_initiative_combat():
		var active: TacticalUnitState = _facade.active_initiative_unit()
		player_may_confirm = active != null and active.is_player_controlled()
	_extract_button.disabled = (
		_world_phase_in_progress
		or _mission_resolution_request_in_progress
		or not player_may_confirm
		or not manifest.extraction_is_legal
	)
	_extract_button.tooltip_text = (
		"Open the extraction manifest."
		if manifest.extraction_is_legal
		else (
			manifest.rejection_reasons[0]
			if not manifest.rejection_reasons.is_empty()
			else "No valid extraction manifest."
		)
	)


func _on_extract_pressed() -> void:
	if (
		_mission_resolution_request_in_progress
		or _facade.mission_resolution_locked()
	):
		return
	var manifest: TacticalExtractionManifest = (
		_facade.preview_extraction_manifest()
	)
	if not manifest.extraction_is_legal:
		_set_status(
			manifest.rejection_reasons[0]
			if not manifest.rejection_reasons.is_empty()
			else "Extraction is not currently legal."
		)
		return
	_close_inventory_silently()
	_clear_attack_targeting_state()
	_clear_board_intent(false)
	_board_view.set_input_enabled(false)
	_mission_resolution_window.show_confirmation(
		manifest, _facade.state(), _facade.mission_setup()
	)


func _on_mission_resolution_cancelled() -> void:
	if _facade.mission_resolution_locked():
		return
	_board_view.set_input_enabled(not _inventory_open)
	_set_status("Extraction cancelled. Tactical control restored.")


func _on_mission_resolution_confirmed(
		zone_id: StringName,
		expected_tactical_revision: int
) -> void:
	if _mission_resolution_request_in_progress:
		return
	_mission_resolution_request_in_progress = true
	_set_status("Resolving extraction and committing campaign consequences...")
	var result: OperationResult = _facade.resolve_tactical_mission(
		zone_id, expected_tactical_revision
	)
	_mission_resolution_request_in_progress = false
	if not result.success:
		_set_status(result.message)
		var refreshed: TacticalExtractionManifest = (
			_facade.preview_extraction_manifest(zone_id)
		)
		_mission_resolution_window.show_confirmation(
			refreshed, _facade.state(), _facade.mission_setup()
		)
		_refresh_all_presentation()
		return
	var mission_result: MissionResult = result.data as MissionResult
	if mission_result == null:
		_set_status("Mission resolution returned no committed result.")
		return
	_world_phase_in_progress = false
	_initiative_ai_in_progress = false
	_board_view.set_input_enabled(false)
	_mission_resolution_window.show_summary(
		mission_result,
		_facade.current_campaign(),
		_facade.mission_setup()
	)
	_set_status(result.message)
	_refresh_all_presentation()


func _on_mission_summary_continue() -> void:
	# Stage 4.6 returns to the authored debug mission selector without reapplying
	# the already committed immutable MissionResult.
	_mission_resolution_window.hide()
	_board_view.set_input_enabled(false)
	_set_status("Mission committed. Returning to the authored mission selector.")
	mission_finished.emit()


func _close_inventory_silently() -> void:
	_inventory_open = false
	_board_view.set_input_enabled(true)
	if _unit_management_window != null:
		_unit_management_window.hide_silently()


func _refresh_board_view() -> void:
	if _board_view == null:
		return
	_selected_attack_geometry = null
	_apply_unit_cover_icons()
	_board_view.update_presentation(
		_selected_unit_id,
		_hovered_tile,
		_preview_result,
		_movement_mode,
		_attack_targeting or _contextual_attack_hover_active,
		_legal_attack_target_ids,
		_selected_attack_target_id,
		_detection_preview,
		_reaction_preview,
		_facing_preview_direction,
		_cover_preview,
		_directional_cover_field,
		_selected_cover_category,
		_selected_attack_geometry,
		_attack_preview,
		_interact_mode_active,
		_reaction_reservation_preview_tiles,
		_reaction_reservation_preview_kind
	)


func _facing_label(direction: Vector2i) -> String:
	var facing: Vector2i = TacticalPerceptionRules.normalized_facing(direction)
	if facing == Vector2i(0, -1):
		return "N"
	if facing == Vector2i(1, -1):
		return "NE"
	if facing == Vector2i(1, 0):
		return "E"
	if facing == Vector2i(1, 1):
		return "SE"
	if facing == Vector2i(0, 1):
		return "S"
	if facing == Vector2i(-1, 1):
		return "SW"
	if facing == Vector2i(-1, 0):
		return "W"
	if facing == Vector2i(-1, -1):
		return "NW"
	return "—"


func _refresh_open_extraction_confirmation() -> void:
	if (
		_mission_resolution_window == null
		or not _mission_resolution_window.is_confirmation_open()
		or _mission_resolution_request_in_progress
		or _facade.mission_resolution_locked()
	):
		return
	var zone_id: StringName = _mission_resolution_window.current_zone_id()
	var refreshed: TacticalExtractionManifest = (
		_facade.preview_extraction_manifest(zone_id)
	)
	_mission_resolution_window.show_confirmation(
		refreshed, _facade.state(), _facade.mission_setup()
	)


func _on_damage_committed(event: Dictionary) -> void:
	if _movement_commit_in_progress or _movement_animation_active:
		_deferred_damage_events.append(event.duplicate(true))
		return
	_apply_damage_committed_presentation(event)


func _apply_damage_committed_presentation(event: Dictionary) -> void:
	var target_id: StringName = StringName(event.get("target_id", &""))
	if target_id.is_empty():
		return
	# Stage 4.5e4 receives this from the first post-commit callback with no
	# process-frame wait in front of the attack command. Measure the complete
	# click-to-impact interval before starting the independent artwork reaction.
	if _attack_click_started_usec > 0:
		_last_attack_click_to_impact_usec = (
			Time.get_ticks_usec() - _attack_click_started_usec
		)
	_immediate_combat_impacts_presented += 1
	_refresh_unit_status_badge_immediately(target_id)
	var view := _unit_views.get(target_id) as TacticalUnitView
	if view != null:
		view.play_damage_reaction()


func _schedule_post_commit_perception_flush() -> void:
	if _post_commit_perception_flush_scheduled:
		return
	_post_commit_perception_flush_scheduled = true
	call_deferred("_flush_post_commit_perception")


func _flush_post_commit_perception() -> void:
	_post_commit_perception_flush_scheduled = false
	if _movement_commit_in_progress or _movement_animation_active:
		_schedule_post_commit_perception_flush()
		return
	var result: OperationResult = _facade.flush_requested_perception_refreshes()
	if result.commit_status == OperationResult.STATUS_COMMITTED_WITH_WARNING:
		push_warning(result.message)


func _on_state_changed_with_flags(
		reason: StringName,
		flags: TacticalInvalidationFlags
) -> void:
	# state_changed is emitted first, but attack reconciliation is intentionally
	# frame-deferred. Capture the precise flags here before that reconciliation
	# reaches the board/fog layers.
	if _movement_commit_in_progress or _movement_animation_active:
		_deferred_state_change_flags[reason] = (
			flags.duplicate_flags() if flags != null else null
		)
	if reason == &"attack_resolved":
		_pending_post_attack_flags = (
			flags.duplicate_flags() if flags != null else null
		)


func _on_state_changed(reason: StringName) -> void:
	if reason == &"hidden_enemy_auto_pass_batch":
		# The transaction changes only budgets for actors that are completely
		# hidden and guaranteed to take no visible action. The final Player Phase
		# handoff performs the one presentation refresh the player can observe.
		_hidden_auto_pass_refreshes_avoided += 1
		return
	if _movement_commit_in_progress or _movement_animation_active:
		_deferred_state_change_reasons[reason] = true
		return
	if reason == &"attack_resolved":
		_schedule_post_attack_reconciliation(reason)
		return
	_process_state_change_after_commit(reason, true)


func _schedule_post_attack_reconciliation(reason: StringName) -> void:
	_pending_post_attack_reasons[reason] = true
	if _post_attack_reconciliation_scheduled:
		return
	_post_attack_reconciliation_scheduled = true
	_flush_post_attack_reconciliation_after_frame()


func _flush_post_attack_reconciliation_after_frame() -> void:
	# A deferred call can still run before the current frame is drawn. Await an
	# actual frame boundary so the first damage-reaction frame is guaranteed to
	# appear before broad HUD, token and initiative reconciliation.
	await get_tree().process_frame

	# A player Attack of Opportunity can resolve between two authoritative enemy
	# movement segments. The enemy continuation may begin animating before this
	# post-attack task resumes. Never self-schedule with call_deferred() while that
	# animation is active: Godot drains deferred calls in the same idle cycle, so
	# a self-deferred retry can spin forever with no script error. Yield across
	# real frames until the movement handoff is safe instead.
	while (
		(_movement_commit_in_progress or _movement_animation_active)
		and is_inside_tree()
	):
		await get_tree().process_frame

	if not is_inside_tree():
		_post_attack_reconciliation_scheduled = false
		return
	_flush_post_attack_reconciliation()


func _flush_post_attack_reconciliation() -> void:
	# The only caller already waits for a safe boundary. Keep this guard as a
	# defensive no-op, but never create a same-idle-cycle deferred retry loop.
	if _movement_commit_in_progress or _movement_animation_active:
		return
	_post_attack_reconciliation_scheduled = false
	if _pending_post_attack_reasons.is_empty():
		return
	var started_usec: int = Time.get_ticks_usec()
	_pending_post_attack_reasons.clear()
	_active_state_change_flags = _pending_post_attack_flags
	_pending_post_attack_flags = null
	_post_attack_reconciliations += 1
	# Explicit targeting may still need a legal-target overlay after the attack.
	# Build the lightweight list here so the same consolidated board refresh
	# publishes it; do not schedule a second post-attack board redraw.
	if _attack_targeting and _legal_attack_targets_dirty:
		_refresh_legal_attack_targets()
	# One authoritative refresh follows all attack subevents. Contextual hover is
	# deliberately suppressed so the struck target is not previewed again merely
	# because the cursor has not moved.
	_process_state_change_after_commit(&"attack_resolved", true, false)
	_active_state_change_flags = null
	_last_post_attack_reconciliation_usec = (
		Time.get_ticks_usec() - started_usec
	)


func _process_state_change_after_commit(
		reason: StringName,
		notify_board: bool,
		refresh_contextual_attack: bool = true
) -> void:
	var selected_unit_before_change: StringName = _selected_unit_id
	var state_cadence_event: int = PresentationCadenceEvent.NONE
	_destination_preview_cache.clear()
	if reason in [
		&"unit_faced_direction",
		&"attack_resolved",
		&"opening_state_changed",
		&"structure_state_changed",
		&"structure_attacked",
	]:
		_schedule_post_commit_perception_flush()
	if (
		notify_board
		and not _player_to_enemy_handoff_in_progress
		and _board_view != null
		and _board_view.has_method("notify_state_changed")
	):
		if _active_state_change_flags != null:
			_board_view.call(
				"notify_state_changed",
				reason,
				_active_state_change_flags
			)
		else:
			_board_view.call("notify_state_changed", reason)
	_refresh_selected_cover_summary()
	if _facade != null and _facade.mission_resolution_locked():
		_sync_life_state_visuals_from_state()
		_refresh_all_presentation(refresh_contextual_attack)
		return
	_refresh_open_extraction_confirmation()
	# Update body-state emblems before selection, initiative normalisation or any
	# later presentation work. The player sees the downed state immediately on
	# the frame in which the attack/healing transaction commits.
	_sync_life_state_visuals_from_state()
	if not _facing_commit_in_progress:
		_clear_board_intent(false)
	var phase_state: TacticalPhaseState = _facade.state().phase_state
	var aware_enemy_squad_ids: Dictionary = _aware_enemy_squad_id_set()
	var new_enemy_squad_alerted: bool = false
	for squad_value: Variant in aware_enemy_squad_ids.keys():
		if not _known_aware_enemy_squad_ids.has(squad_value):
			new_enemy_squad_alerted = true
			break
	if (
		_last_tactical_mode == TacticalPhaseState.MODE_SIDE_BASED
		and phase_state.is_initiative_combat()
		and new_enemy_squad_alerted
	):
		_reset_contact_transition_metrics()
		_play_alert_flash()
		state_cadence_event = PresentationCadenceEvent.ALERT_TRIGGERED
	_known_aware_enemy_squad_ids = aware_enemy_squad_ids
	_last_tactical_mode = phase_state.tactical_mode

	if _selected_unit_is_player_controlled():
		var selected_item: TacticalItemInstanceState = _facade.state().get_hand_item(
			_selected_unit_id,
			_valid_hand_kind_or_primary(_selected_weapon_hand_kind)
		)
		if (
			selected_item == null
			and not _selected_weapon_item_id.is_empty()
		):
			_select_default_weapon_for_unit()
		elif not _attack_targeting:
			_sync_selected_hand_attack()

	var active_after_change: TacticalUnitState = null
	if phase_state.is_initiative_combat():
		active_after_change = _facade.active_initiative_unit()
		if (
			active_after_change != null
			and _unit_handoff_is_observable(active_after_change)
		):
			_selected_unit_id = active_after_change.unit_id
			if (
				active_after_change.unit_id != selected_unit_before_change
				and state_cadence_event == PresentationCadenceEvent.NONE
			):
				state_cadence_event = PresentationCadenceEvent.ACTIVATION_HANDOFF
		if (
			active_after_change != null
			and active_after_change.is_ai_controlled()
			and state_cadence_event == PresentationCadenceEvent.ALERT_TRIGGERED
		):
			_contact_presentation_ready_unit_id = active_after_change.unit_id
			_play_active_unit_handoff_pulse(active_after_change.unit_id)
		if active_after_change == null or not active_after_change.can_take_actions():
			_schedule_initiative_normalization()
	var seamless_ai_handoff: bool = (
		_player_to_enemy_handoff_in_progress
		and (
			phase_state.is_enemy_phase()
			or (
				active_after_change != null
				and active_after_change.is_ai_controlled()
			)
		)
	)
	if seamless_ai_handoff:
		# The button handler owns the immediate handoff. Publish only the small
		# phase/selection delta here; a broad board rebuild would sit directly in
		# front of the warmed AI commitment.
		_update_unit_selection_visuals()
		_update_unit_finished_visuals()
		_refresh_hud()
		if _board_view != null:
			_board_view.set_input_enabled(false)
		_handoff_full_refreshes_avoided += 1
	else:
		_refresh_all_presentation(refresh_contextual_attack)
	if _protagonist_is_dead():
		call_deferred("_resolve_campaign_defeat_if_needed")
		return
	if not _facade.player_force_can_continue():
		call_deferred("_resolve_tactical_defeat_if_needed")
		return
	if _player_to_enemy_handoff_in_progress:
		# The explicit End Turn handler starts the warmed actor exactly once after
		# the transaction returns. Do not queue cadence or a duplicate AI runner
		# from inside this state-change callback.
		_handoff_duplicate_ai_schedules_avoided += 1
		return
	if _initiative_ai_in_progress:
		# The initiative-AI coroutine owns its own move/attack and actor-handoff
		# cadence. Do not queue a second asynchronous wait from the state signal.
		return
	if state_cadence_event != PresentationCadenceEvent.NONE:
		_queue_state_change_cadence(
			state_cadence_event,
			_selected_unit_id
		)
	else:
		_schedule_initiative_ai()


func _protagonist_is_dead() -> bool:
	var setup: MissionSetupSnapshot = _facade.mission_setup()
	if setup == null or setup.protagonist_character_id.is_empty():
		return false
	var protagonist: TacticalUnitState = _facade.state().get_unit(
		setup.protagonist_character_id
	)
	return protagonist != null and protagonist.is_dead()


func _resolve_campaign_defeat_if_needed() -> void:
	if (
		_facade.mission_resolution_locked()
		or _mission_resolution_request_in_progress
		or not _protagonist_is_dead()
	):
		return
	_mission_resolution_request_in_progress = true
	_board_view.set_input_enabled(false)
	var result: OperationResult = _facade.resolve_tactical_mission()
	_mission_resolution_request_in_progress = false
	if not result.success:
		_set_status(result.message)
		return
	var mission_result: MissionResult = result.data as MissionResult
	if mission_result != null:
		_mission_resolution_window.show_summary(
			mission_result, _facade.current_campaign(), _facade.mission_setup()
		)
		_set_status("Campaign defeat resolved. Reload the last safe campaign state.")


func _resolve_tactical_defeat_if_needed() -> void:
	if (
		_facade.mission_resolution_locked()
		or _mission_resolution_request_in_progress
		or _facade.player_force_can_continue()
		or _protagonist_is_dead()
	):
		return
	_mission_resolution_request_in_progress = true
	_board_view.set_input_enabled(false)
	var result: OperationResult = _facade.resolve_tactical_mission()
	_mission_resolution_request_in_progress = false
	if not result.success:
		_set_status(result.message)
		return
	var mission_result: MissionResult = result.data as MissionResult
	if mission_result != null:
		_mission_resolution_window.show_summary(
			mission_result, _facade.current_campaign(), _facade.mission_setup()
		)
		_set_status("Tactical defeat committed. No conscious friendly can continue.")


func _aware_enemy_squad_id_set() -> Dictionary:
	var result: Dictionary = {}
	if _facade == null or _facade.state() == null:
		return result
	for squad: TacticalSquadState in _facade.state().get_squads():
		if squad.team_id == &"enemy" and squad.is_aware():
			result[squad.squad_id] = true
	return result


func _schedule_initiative_normalization() -> void:
	if _initiative_normalization_pending:
		return
	_initiative_normalization_pending = true
	call_deferred("_normalize_initiative_after_state_change")


func _normalize_initiative_after_state_change() -> void:
	_initiative_normalization_pending = false
	if not _facade.is_initiative_combat():
		return
	var result: OperationResult = _facade.normalize_initiative()
	if not result.success:
		_set_status(result.message)
		return
	_refresh_all_presentation()
	# Normalisation may skip a newly unconscious participant and expose an AI
	# unit as the new active character. Always resume through a deferred call so
	# the current state-change callback can finish first.
	call_deferred("_schedule_initiative_ai")


func _create_alert_flash() -> void:
	_alert_flash = ColorRect.new()
	_alert_flash.name = "AlertFlash"
	_alert_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_flash.color = Color(0.92, 0.12, 0.06, 0.0)
	_alert_flash.z_index = 200
	$HUD.add_child(_alert_flash)
	_alert_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _reset_contact_transition_metrics() -> void:
	if _facade != null:
		_facade.cancel_contact_ai_warmup()
	_contact_ai_warmup_started_usec = 0
	_contact_ai_warmup_completed_usec = 0
	_contact_ai_warmup_processing_usec = 0
	_contact_ai_warmup_frames = 0
	_contact_ai_warmup_abandoned = false
	_contact_detected_usec = Time.get_ticks_usec()
	_contact_ai_pulse_started_usec = 0
	_contact_first_movement_tween_started_usec = 0
	_contact_presentation_ready_unit_id = &""


func _play_alert_flash() -> void:
	if _alert_flash == null:
		return
	_alert_flash.color.a = 0.28
	var tween: Tween = create_tween()
	tween.tween_property(_alert_flash, "color:a", 0.0, ALERT_FLASH_SECONDS)


func _schedule_initiative_ai() -> void:
	if (
		_facade.mission_resolution_locked()
		or _initiative_ai_in_progress
		or _cadence_wait_depth > 0
		or _state_cadence_runner_scheduled
		or not _facade.is_initiative_combat()
	):
		return
	var active: TacticalUnitState = _facade.active_initiative_unit()
	if (
		active == null
		or not active.is_ai_controlled()
		or not active.can_take_actions()
	):
		return
	_run_initiative_ai()


func _run_initiative_ai() -> void:
	if _initiative_ai_in_progress or _facade.mission_resolution_locked():
		return
	_initiative_ai_in_progress = true
	var initiative_frame_budget_started_usec: int = Time.get_ticks_usec()
	while (
		_facade.is_initiative_combat()
		and not _facade.mission_resolution_locked()
	):
		var active: TacticalUnitState = _facade.active_initiative_unit()
		if active == null:
			var missing_result: OperationResult = _facade.normalize_initiative()
			if not missing_result.success:
				_set_status(missing_result.message)
				break
			await get_tree().process_frame
			if _facade.active_initiative_unit() == null:
				_set_status("Initiative has no valid active participant.")
				break
			continue
		if not active.is_ai_controlled():
			break
		if not active.can_take_actions():
			var skipped_result: OperationResult = _facade.normalize_initiative()
			if not skipped_result.success:
				_set_status(skipped_result.message)
				break
			continue

		var acting_unit_id: StringName = active.unit_id
		if (
			_enemy_handoff_started_usec > 0
			and _prepared_ai_presentation_unit_id == acting_unit_id
		):
			_last_enemy_to_enemy_handoff_usec = maxi(
				0, Time.get_ticks_usec() - _enemy_handoff_started_usec
			)
			_enemy_handoff_started_usec = 0
		# Validate the already-warmed plan before the enemy is highlighted. The
		# ordinary visible path then has no mission-wide signature/perception gate
		# between its pulse and the first movement or attack.
		var handoff_prepare_result: OperationResult = (
			_facade.prepare_ai_activation_handoff(acting_unit_id)
		)
		if handoff_prepare_result != null:
			_pre_activation_handoff_validations += 1
		var acting_handoff_observable: bool = _unit_handoff_is_observable(active)
		var presentation_already_prepared: bool = (
			_prepared_ai_presentation_unit_id == acting_unit_id
		)
		_clear_board_intent(false)
		if acting_handoff_observable:
			_selected_unit_id = acting_unit_id
			if _contact_presentation_ready_unit_id == acting_unit_id:
				_contact_presentation_ready_unit_id = &""
				_duplicate_contact_refreshes_avoided += 1
				_update_unit_selection_visuals()
				_update_unit_finished_visuals()
				_refresh_hud()
			elif presentation_already_prepared:
				_prepared_ai_presentation_unit_id = &""
				_duplicate_enemy_refreshes_avoided += 1
			else:
				_refresh_all_presentation()
		else:
			_prepared_ai_presentation_unit_id = &""
			_unobserved_ai_activation_handoffs_skipped += 1
			_hidden_actor_refreshes_avoided += 1
		if acting_handoff_observable:
			_begin_enemy_stall_watch(acting_unit_id)
		if (
			acting_handoff_observable
			and _last_handoff_pulsed_unit_id != acting_unit_id
		):
			_play_active_unit_handoff_pulse(acting_unit_id)
		if _facade.mission_resolution_locked():
			break

		# Re-read ownership after the presentation cadence. A life-state change or
		# initiative normalisation may have advanced past this actor already.
		if (
			not _facade.is_initiative_combat()
			or _facade.active_initiative_unit_id() != acting_unit_id
		):
			continue

		# The reaction-aware helper performs `_movement_control_owner_before_commit = acting_unit_id`
		# immediately before each committed AI segment so movement cadence remains correct.
		var ai_result: OperationResult = await _resolve_initiative_ai_with_reaction_prompts(acting_unit_id)
		_finish_enemy_stall_watch(acting_unit_id)
		_facade.cancel_contact_ai_warmup()
		if _last_ai_activation_presented_movement:
			_presentation_wall_time_excluded_usec += _last_ai_activation_presentation_usec
			initiative_frame_budget_started_usec = Time.get_ticks_usec()
			_forced_inter_actor_frames_avoided += 1
		if acting_handoff_observable:
			_set_status(ai_result.message)
		elif _last_ai_resolution_observable:
			_set_status("An unseen enemy action resolves.")
		if not ai_result.success:
			break
		# Stage 4.4e3 removes post-movement dead air. Reaction prompts pause only
		# when a legal player decision is genuinely available.
		if _facade.mission_resolution_locked():
			break

		# EnemyActionPlanner finalises its activation for logging, while
		# InitiativeTurnHandler owns advancement. Only advance if the same actor
		# is still active; otherwise a state-change normalisation already handed
		# control onward and a stale second end-turn request would stall the loop.
		if (
			_facade.is_initiative_combat()
			and _facade.active_initiative_unit_id() == acting_unit_id
		):
			# Stationary actions have little presentation time to hide work behind.
			# Spend any remaining CPU budget on the immediate next actor before the
			# initiative index advances; the partial job transfers with the handoff.
			var lookahead_remaining_usec: int = maxi(
				250,
				ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC
				- maxi(0, Time.get_ticks_usec() - initiative_frame_budget_started_usec)
			)
			var lookahead_started_usec: int = Time.get_ticks_usec()
			var lookahead_result: OperationResult = (
				_facade.warmup_next_ai_handoff(lookahead_remaining_usec)
			)
			_chain_warmup_processing_usec += maxi(
				0, Time.get_ticks_usec() - lookahead_started_usec
			)
			if lookahead_result != null:
				_chain_warmup_frames += 1
				if lookahead_result.code == &"enemy_handoff_warmup_ready":
					_chain_warmup_ready_frames += 1
			var advance_result: OperationResult = (
				_facade.end_initiative_turn(acting_unit_id)
			)
			if not advance_result.success:
				_set_status(advance_result.message)
				break
		var next_after_ai: TacticalUnitState = _facade.active_initiative_unit()
		if (
			next_after_ai != null
			and next_after_ai.unit_id != acting_unit_id
			and _unit_handoff_is_observable(next_after_ai)
		):
			_selected_unit_id = next_after_ai.unit_id
			_update_unit_selection_visuals()
			_update_unit_finished_visuals()
			_refresh_hud()
			_refresh_board_view()
			if next_after_ai.is_ai_controlled():
				_prepared_ai_presentation_unit_id = next_after_ai.unit_id
				_enemy_handoff_started_usec = Time.get_ticks_usec()
			else:
				_prepared_ai_presentation_unit_id = &""
				_enemy_handoff_started_usec = 0
			if _last_handoff_pulsed_unit_id != next_after_ai.unit_id:
				_play_active_unit_handoff_pulse(next_after_ai.unit_id)
		elif next_after_ai != null and not _unit_handoff_is_observable(next_after_ai):
			_prepared_ai_presentation_unit_id = &""
			_unobserved_ai_activation_handoffs_skipped += 1
			_hidden_actor_refreshes_avoided += 1

		var adaptive_handoff_seconds: float = _adaptive_visible_handoff_seconds(
			next_after_ai
		)
		if adaptive_handoff_seconds > 0.0:
			await _await_adaptive_visible_handoff(next_after_ai)
			# Cosmetic readability time never consumes the CPU simulation budget.
			initiative_frame_budget_started_usec = Time.get_ticks_usec()

		if (
			next_after_ai != null
			and next_after_ai.is_ai_controlled()
			and Time.get_ticks_usec() - initiative_frame_budget_started_usec
			>= ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC
		):
			_enemy_phase_frame_yields += 1
			await get_tree().process_frame
			initiative_frame_budget_started_usec = Time.get_ticks_usec()

	_initiative_ai_in_progress = false
	var next_active: TacticalUnitState = _facade.active_initiative_unit()
	if next_active != null and _unit_handoff_is_observable(next_active):
		_selected_unit_id = next_active.unit_id
	_refresh_all_presentation()
	if (
		_board_view != null
		and next_active != null
		and next_active.is_player_controlled()
		and not _facade.mission_resolution_locked()
	):
		_board_view.set_input_enabled(true)
	# If the loop yielded because an asynchronous state callback changed the
	# active actor to another AI participant, resume on the following frame.
	if (
		not _facade.mission_resolution_locked()
		and next_active != null
		and next_active.is_ai_controlled()
		and next_active.can_take_actions()
	):
		call_deferred("_schedule_initiative_ai")



func _create_reaction_prompt() -> void:
	_reaction_prompt = PanelContainer.new()
	_reaction_prompt.name = "ReactionDecisionPrompt"
	_reaction_prompt.visible = false
	_reaction_prompt.z_index = 220
	_reaction_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_reaction_prompt.position = Vector2(-210, -150)
	_reaction_prompt.custom_minimum_size = Vector2(420, 300)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_reaction_prompt.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_reaction_prompt_icon = TextureRect.new()
	_reaction_prompt_icon.custom_minimum_size = Vector2(42, 42)
	_reaction_prompt_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reaction_prompt_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_reaction_prompt_icon)
	_reaction_prompt_title = Label.new()
	_reaction_prompt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reaction_prompt_title.add_theme_font_size_override("font_size", 20)
	column.add_child(_reaction_prompt_title)
	_reaction_prompt_body = RichTextLabel.new()
	_reaction_prompt_body.bbcode_enabled = true
	_reaction_prompt_body.fit_content = false
	_reaction_prompt_body.custom_minimum_size = Vector2(384, 190)
	_reaction_prompt_body.scroll_active = false
	column.add_child(_reaction_prompt_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	_reaction_prompt_primary = Button.new()
	_reaction_prompt_primary.custom_minimum_size = Vector2(150, 36)
	_reaction_prompt_primary.pressed.connect(_resolve_visible_reaction_prompt.bind(true))
	row.add_child(_reaction_prompt_primary)
	_reaction_prompt_secondary = Button.new()
	_reaction_prompt_secondary.custom_minimum_size = Vector2(150, 36)
	_reaction_prompt_secondary.pressed.connect(_resolve_visible_reaction_prompt.bind(false))
	row.add_child(_reaction_prompt_secondary)
	$HUD.add_child(_reaction_prompt)


func _on_reaction_decision_requested(request: ReactionDecisionRequest) -> void:
	if request == null:
		return
	_reaction_prompt_request = request
	_reaction_decision_serial += 1
	var reactor: TacticalUnitState = _facade.state().get_unit(request.reacting_unit_id)
	var target: TacticalUnitState = _facade.state().get_unit(request.triggering_unit_id)
	var icon_texture: Texture2D = REACTION_AOO_ICON
	if request.candidate != null:
		match request.candidate.reaction_kind:
			ReactionCandidate.KIND_OVERWATCH:
				icon_texture = REACTION_OVERWATCH_BOW_ICON
			ReactionCandidate.KIND_BRACE:
				icon_texture = REACTION_BRACE_SPEAR_ICON
	_reaction_prompt_icon.texture = icon_texture
	_reaction_prompt_title.text = request.reaction_display_name.to_upper()
	var modifier_text: String = ""
	if not request.modifier_lines.is_empty():
		modifier_text = "\n" + "\n".join(PackedStringArray(request.modifier_lines))
	_reaction_prompt_body.text = (
		"[center][b]%s[/b][/center]\n\n"
		+ "Reacting character: %s\n"
		+ "Target: %s\n"
		+ "Trigger: %s\n"
		+ "Weapon: %s\n\n"
		+ "[b]Chance to hit: %d%%[/b]\n"
		+ "Expected damage: %s\n"
		+ "Reaction: %s → Spent if used%s"
	) % [
		request.reaction_display_name,
		reactor.display_name if reactor != null else String(request.reacting_unit_id),
		target.display_name if target != null else String(request.triggering_unit_id),
		request.triggering_action_name,
		request.weapon_display_name,
		request.predicted_hit_chance,
		request.predicted_damage_text,
		reactor.action_budget.reaction_label() if reactor != null else "Ready",
		modifier_text,
	]
	_reaction_prompt_primary.text = request.use_label
	_reaction_prompt_secondary.text = request.decline_label
	_reaction_prompt.visible = true
	if _board_view != null:
		_board_view.set_input_enabled(false)
	_reaction_prompt_primary.grab_focus()


func _on_reaction_decision_cleared(request_id: StringName) -> void:
	if _reaction_prompt_request == null or _reaction_prompt_request.request_id != request_id:
		return
	_reaction_prompt.visible = false
	_reaction_prompt_request = null
	_reaction_decision_resolved_serial = _reaction_decision_serial


func _resolve_visible_reaction_prompt(use_primary: bool) -> void:
	if _reaction_prompt_request == null:
		return
	var request: ReactionDecisionRequest = _reaction_prompt_request
	var choice: StringName = request.use_choice if use_primary else request.decline_choice
	var result: OperationResult = _facade.resolve_reaction_decision(request.request_id, choice)
	if not result.success:
		_set_status(result.message)
		return
	_set_status(result.message)
	_reaction_prompt.visible = false
	_reaction_prompt_request = null
	_reaction_decision_resolved_serial = _reaction_decision_serial
	_refresh_all_presentation()


func _await_reaction_prompt_resolution(serial: int) -> void:
	while _reaction_decision_resolved_serial < serial and not _facade.mission_resolution_locked():
		await get_tree().process_frame


func _begin_reaction_reservation_preview(kind: StringName) -> void:
	if _selected_unit_id.is_empty():
		_set_status("Select a player-controlled unit first.")
		return
	var reason: String = _facade.reaction_unavailable_reason(_selected_unit_id, kind)
	if not reason.is_empty():
		_set_status(reason)
		return
	_clear_board_intent(false)
	_board_intent_mode = (
		BoardIntentMode.OVERWATCH_PREVIEW
		if kind == ReactionReservationState.KIND_OVERWATCH
		else BoardIntentMode.BRACE_PREVIEW
	)
	_reaction_reservation_preview_kind = kind
	_hide_context_tray()
	_set_status(
		"Choose a direction for %s, then left-click to confirm; right-click cancels."
		% ("Overwatch" if kind == ReactionReservationState.KIND_OVERWATCH else "Brace")
	)
	_update_reaction_reservation_preview(_hovered_tile)
	_refresh_hud()
	_refresh_board_view()


func _update_reaction_reservation_preview(tile: Vector2i) -> void:
	_reaction_reservation_preview_tiles.clear()
	if _selected_unit_id.is_empty() or not _map_definition.is_inside(tile):
		return
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return
	var direction: Vector2i = TacticalPerceptionRules.normalized_facing(tile - unit.grid_position)
	if direction == Vector2i.ZERO:
		return
	_reaction_reservation_preview_tiles = _facade.preview_reaction_reservation_tiles(
		unit.unit_id,
		_reaction_reservation_preview_kind,
		direction
	)


func _confirm_reaction_reservation_preview(tile: Vector2i) -> void:
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		_cancel_reaction_reservation_preview("The selected unit is unavailable.")
		return
	var direction: Vector2i = TacticalPerceptionRules.normalized_facing(tile - unit.grid_position)
	if direction == Vector2i.ZERO:
		_set_status("Choose a different tile to set the Reaction direction.")
		return
	var result: OperationResult = (
		_facade.prepare_overwatch(unit.unit_id, direction)
		if _reaction_reservation_preview_kind == ReactionReservationState.KIND_OVERWATCH
		else _facade.prepare_brace(unit.unit_id, direction)
	)
	_set_status(result.message)
	if result.success:
		_cancel_reaction_reservation_preview()
	_refresh_all_presentation()


func _cancel_reaction_reservation_preview(message: String = "") -> void:
	if _board_intent_mode in [BoardIntentMode.OVERWATCH_PREVIEW, BoardIntentMode.BRACE_PREVIEW]:
		_board_intent_mode = BoardIntentMode.NONE
	_reaction_reservation_preview_tiles.clear()
	_reaction_reservation_preview_kind = &""
	if not message.is_empty():
		_set_status(message)
	_refresh_hud()
	_refresh_board_view()


func _present_pending_ai_movement_events() -> void:
	_last_ai_activation_presented_movement = false
	_last_ai_visible_movement_duration_seconds = 0.0
	if not _pending_ai_movement_events.is_empty():
		var movement_events: Array[Dictionary] = []
		for movement_event: Dictionary in _pending_ai_movement_events:
			movement_events.append(movement_event.duplicate(true))
		_pending_ai_movement_events.clear()
		if _ai_movement_batch_is_completely_unobserved(movement_events):
			# There is no tween to hide preparation behind, so finish only the
			# authoritative destination field before releasing the movement boundary.
			_complete_pending_ai_destination_visibility_same_frame(
				HIDDEN_AI_VISIBILITY_FAST_BUDGET_USEC
			)
			_complete_unobserved_ai_movement_batch(movement_events)
			return
		_last_ai_activation_presented_movement = true
		_begin_movement_presentation_batch(movement_events)
		await movement_presentation_finished
	else:
		# A plan that produced no movement must not leave an obsolete destination
		# field alive for the next actor.
		_facade.cancel_pending_enemy_destination_visibility()
		_last_ai_resolution_observable = (
			_last_ai_resolution_observable
			or _has_player_observable_deferred_damage()
			or _has_observable_ai_state_transition()
		)
		_movement_commit_in_progress = true
		_facade.end_visibility_recalculation_deferral()
		_movement_commit_in_progress = false
		_flush_deferred_state_changes_without_animation()


func _ai_movement_batch_is_completely_unobserved(
		events: Array[Dictionary]
) -> bool:
	if _has_player_observable_deferred_damage() or _has_observable_ai_state_transition():
		return false
	for event: Dictionary in events:
		if _ai_movement_event_visibility(event) != TacticalPresentationVisibility.UNOBSERVED:
			return false
	return true


func _complete_unobserved_ai_movement_batch(
		events: Array[Dictionary]
) -> void:
	var moved_unit_ids: Array[StringName] = []
	for event: Dictionary in events:
		var unit_id: StringName = StringName(event.get("unit_id", &""))
		if unit_id.is_empty() or moved_unit_ids.has(unit_id):
			continue
		moved_unit_ids.append(unit_id)
		_unobserved_ai_movement_events_skipped += 1
	_unobserved_ai_movement_batches_completed_immediately += 1
	_last_ai_resolution_observable = false
	_movement_commit_in_progress = true
	_facade.end_visibility_recalculation_deferral_for_units(
		moved_unit_ids,
		_deferred_visibility_requires_full_rebuild()
	)
	_movement_commit_in_progress = false
	_flush_deferred_state_changes_without_animation()
	_visible_enemy_unit_ids_before_movement.clear()
	_movement_control_owner_before_commit = &""
	_movement_interruption_pending = false


func _has_player_observable_deferred_damage() -> bool:
	for event: Dictionary in _deferred_damage_events:
		var target_id: StringName = StringName(event.get("target_id", &""))
		var target: TacticalUnitState = _facade.state().get_unit(target_id)
		if (
			target != null
			and (
				target.is_player_controlled()
				or _facade.is_unit_visible_to_player(target.unit_id)
			)
		):
			return true
	return false


func _has_observable_ai_state_transition() -> bool:
	if _facade == null or _facade.state() == null:
		return false
	var phase_state: TacticalPhaseState = _facade.state().phase_state
	return (
		_last_tactical_mode == TacticalPhaseState.MODE_SIDE_BASED
		and phase_state.is_initiative_combat()
	)


func _begin_side_based_enemy_activation_feedback(
		unit_id: StringName
) -> void:
	if unit_id.is_empty():
		return
	if _prepared_ai_presentation_unit_id == unit_id:
		_prepared_ai_presentation_unit_id = &""
		_duplicate_enemy_refreshes_avoided += 1
		_last_ai_resolution_observable = true
		return
	var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
	if not _select_unit_for_observable_handoff(unit):
		_unobserved_ai_activation_handoffs_skipped += 1
		return
	_last_ai_resolution_observable = true
	_begin_enemy_stall_watch(unit_id)
	if _handoff_feedback_started_usec == 0 and _handoff_requested_usec > 0:
		_handoff_feedback_started_usec = Time.get_ticks_usec()
	if (
		not _first_enemy_feedback_recorded
		and _enemy_phase_requested_usec > 0
	):
		_first_enemy_feedback_recorded = true
		_first_actor_feedback_started_usec = Time.get_ticks_usec()
		_end_phase_to_first_enemy_feedback_usec = maxi(
			0,
			Time.get_ticks_usec() - _enemy_phase_requested_usec
		)
	# Selection and pulse are enough to identify the acting visible enemy. Avoid a
	# full HUD and board rebuild before read-only planning; the consolidated action
	# handoff performs the complete refresh once.
	_update_unit_selection_visuals()
	_update_unit_finished_visuals()
	_play_active_unit_handoff_pulse(unit_id)
	_side_based_enemy_activation_pulses += 1


func _begin_side_based_enemy_activation_presentation(
		result: OperationResult
) -> void:
	if (
		result == null
		or not result.success
		or result.code not in [
			&"enemy_activation_completed",
			&"reaction_pending",
		]
	):
		return
	var unit_id: StringName = &""
	if result.data is Dictionary:
		var result_data: Dictionary = result.data
		unit_id = StringName(result_data.get("unit_id", &""))
	else:
		var pending: PendingMovementReactionState = (
			result.data as PendingMovementReactionState
		)
		if pending != null:
			unit_id = pending.mover_unit_id
	if unit_id.is_empty():
		return
	_finish_enemy_stall_watch(unit_id)
	if _last_handoff_pulsed_unit_id == unit_id:
		return
	var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
	if not _select_unit_for_observable_handoff(unit):
		_unobserved_ai_activation_handoffs_skipped += 1
		return
	_last_ai_resolution_observable = true
	if (
		not _first_enemy_feedback_recorded
		and _enemy_phase_requested_usec > 0
	):
		_first_enemy_feedback_recorded = true
		_first_actor_feedback_started_usec = Time.get_ticks_usec()
		_end_phase_to_first_enemy_feedback_usec = maxi(
			0,
			Time.get_ticks_usec() - _enemy_phase_requested_usec
		)
	_update_unit_selection_visuals()
	_update_unit_finished_visuals()
	_play_active_unit_handoff_pulse(unit_id)
	_side_based_enemy_activation_pulses += 1


func _resolve_enemy_phase_with_reaction_prompts() -> OperationResult:
	var result: OperationResult
	var frame_budget_started_usec: int = Time.get_ticks_usec()
	var planning_slices_this_frame: int = 0
	while true:
		var had_pending_planning: bool = _facade.has_pending_enemy_planning()
		var plan_ready: bool = _facade.enemy_planning_ready_to_commit()
		var resuming_reaction: bool = _facade.has_pending_ai_reaction()
		if not had_pending_planning and not resuming_reaction:
			_pending_ai_movement_events.clear()
			_last_ai_resolution_observable = false
			var next_actor_id: StringName = (
				_facade.peek_next_enemy_activation_unit_id()
			)
			if not next_actor_id.is_empty():
				_facade.prepare_ai_activation_handoff(next_actor_id)
			_begin_side_based_enemy_activation_feedback(next_actor_id)

		var frame_processing_before_call: int = maxi(
			0, Time.get_ticks_usec() - frame_budget_started_usec
		)
		var remaining_budget_usec: int = maxi(
			250,
			ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC
			- frame_processing_before_call
		)
		var deferral_started: bool = false
		var activation_started_usec: int = Time.get_ticks_usec()
		# Read-only planning does not own a visibility or perception deferral. The
		# boundary opens once, immediately before authoritative commitment.
		if resuming_reaction or plan_ready:
			if (
				plan_ready
				and _handoff_to_authoritative_commit_usec == 0
				and _handoff_requested_usec > 0
			):
				_handoff_to_authoritative_commit_usec = maxi(
					0,
					Time.get_ticks_usec() - _handoff_requested_usec
				)
			_pending_ai_movement_events.clear()
			_facade.begin_visibility_recalculation_deferral()
			deferral_started = true
			_movement_commit_in_progress = true
		result = (
			_facade.resume_ai_after_reaction()
			if resuming_reaction
			else (
				_facade.commit_ready_enemy_activation()
				if plan_ready
				else _facade.resolve_next_enemy_activation(remaining_budget_usec)
			)
		)
		_movement_commit_in_progress = false

		if result == null:
			if deferral_started:
				_release_ai_planning_only_deferral()
			return OperationResult.fail(
				&"enemy_activation_result_missing",
				"The Enemy Phase returned no activation result."
			)

		if result.code == &"enemy_planning_pending":
			_record_enemy_stall_thresholds(_enemy_stall_active_unit_id)
			if deferral_started:
				_release_ai_planning_only_deferral()
			_enemy_planning_slice_count += 1
			planning_slices_this_frame += 1
			_enemy_planning_max_slices_per_frame = maxi(
				_enemy_planning_max_slices_per_frame,
				planning_slices_this_frame
			)
			var frame_processing_usec: int = maxi(
				0,
				Time.get_ticks_usec() - frame_budget_started_usec
			)
			if frame_processing_usec < ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC:
				continue
			_enemy_planning_yield_count += 1
			_enemy_phase_frame_yields += 1
			_facade.record_enemy_planning_frame_yield(
				planning_slices_this_frame,
				not _last_ai_resolution_observable
			)
			if not _last_ai_resolution_observable:
				_enemy_hidden_planning_frames += 1
			if _facade.pending_enemy_planning_is_visibility():
				_destination_visibility_yield_count += 1
			if not _first_visible_enemy_action_recorded:
				_frames_yielded_before_first_visible_action += 1
			await get_tree().process_frame
			frame_budget_started_usec = Time.get_ticks_usec()
			planning_slices_this_frame = 0
			continue

		if result.code == &"enemy_plan_ready":
			if deferral_started:
				_release_ai_planning_only_deferral()
			_enemy_planning_slice_count += 1
			planning_slices_this_frame += 1
			_enemy_planning_max_slices_per_frame = maxi(
				_enemy_planning_max_slices_per_frame,
				planning_slices_this_frame
			)
			# A completed plan commits immediately. Destination FOV preparation now
			# overlaps movement, so there is no empty plan/commit render boundary.
			continue

		if (
			_last_ai_resolution_observable
			and not _first_visible_enemy_action_recorded
			and _enemy_phase_requested_usec > 0
		):
			_first_visible_enemy_action_recorded = true
			_end_phase_to_first_visible_action_usec = maxi(
				0,
				Time.get_ticks_usec() - _enemy_phase_requested_usec
			)

		_begin_side_based_enemy_activation_presentation(result)
		_capture_last_ai_simulation_timing()
		var presentation_started_usec: int = Time.get_ticks_usec()
		if deferral_started:
			await _present_pending_ai_movement_events()
		if (
			_last_ai_resolution_observable
			and not _first_visible_enemy_action_recorded
			and _enemy_phase_requested_usec > 0
		):
			_first_visible_enemy_action_recorded = true
			_end_phase_to_first_visible_action_usec = maxi(
				0,
				Time.get_ticks_usec() - _enemy_phase_requested_usec
			)
		_last_ai_activation_presentation_usec = maxi(
			0, Time.get_ticks_usec() - presentation_started_usec
		)
		if (
			result.success
			and result.code != &"enemy_turn_completed"
		):
			_facade.record_last_ai_presentation_timing(
				_last_ai_activation_presentation_usec
			)
			_last_ai_activation_total_usec = maxi(
				0, Time.get_ticks_usec() - activation_started_usec
			)
		_enemy_phase_had_observable_activity = (
			_enemy_phase_had_observable_activity
			or _last_ai_resolution_observable
		)
		if not result.success:
			return result
		if result.code == &"reaction_pending":
			var opened: OperationResult = _facade.open_pending_ai_reaction_decision()
			if not opened.success:
				return opened
			var serial: int = _reaction_decision_serial
			await _await_reaction_prompt_resolution(serial)
			frame_budget_started_usec = Time.get_ticks_usec()
			planning_slices_this_frame = 0
			continue
		if result.code == &"enemy_turn_completed":
			return result

		# Side-based actors use the same one-actor pipeline. Moving actors are
		# warmed during their tween by _process(); stationary actors receive any
		# CPU budget still available in this frame.
		var side_lookahead_remaining_usec: int = maxi(
			250,
			ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC
			- maxi(0, Time.get_ticks_usec() - frame_budget_started_usec)
		)
		var side_lookahead_started_usec: int = Time.get_ticks_usec()
		var side_lookahead: OperationResult = _facade.warmup_next_ai_handoff(
			side_lookahead_remaining_usec
		)
		_chain_warmup_processing_usec += maxi(
			0, Time.get_ticks_usec() - side_lookahead_started_usec
		)
		if side_lookahead != null:
			_chain_warmup_frames += 1
			if side_lookahead.code == &"enemy_handoff_warmup_ready":
				_chain_warmup_ready_frames += 1

		var next_side_actor_id: StringName = (
			_facade.peek_next_enemy_activation_unit_id()
		)
		var next_side_actor: TacticalUnitState = _facade.state().get_unit(
			next_side_actor_id
		)
		var adaptive_side_seconds: float = _adaptive_visible_handoff_seconds(
			next_side_actor
		)
		if adaptive_side_seconds > 0.0:
			_facade.prepare_ai_activation_handoff(next_side_actor_id)
			_begin_side_based_enemy_activation_feedback(next_side_actor_id)
			_prepared_ai_presentation_unit_id = next_side_actor_id
			await _await_adaptive_visible_handoff(next_side_actor)
			frame_budget_started_usec = Time.get_ticks_usec()
			planning_slices_this_frame = 0

		# Visible movement already supplied its own rendered frames. Stationary
		# attacks, pulses, damage reactions and badge changes are non-blocking and may
		# overlap the next actor's planning. Never add a compulsory dead frame merely
		# because the completed activation was observable.
		if not _last_ai_resolution_observable and not _first_visible_enemy_action_recorded:
			_hidden_actors_before_first_visible_action += 1
		if _last_ai_resolution_observable:
			_visible_activation_dead_frames_avoided += 1
			if _last_ai_activation_presented_movement:
				# The tween elapsed in real time, so restart the CPU budget and begin the
				# next actor immediately rather than paying another rendered frame.
				frame_budget_started_usec = Time.get_ticks_usec()
				planning_slices_this_frame = 0
				continue
		var frame_simulation_usec: int = maxi(
			0, Time.get_ticks_usec() - frame_budget_started_usec
		)
		if frame_simulation_usec < ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC:
			_enemy_phase_hidden_activations_batched += 1
			continue
		_enemy_phase_frame_yields += 1
		if not _first_visible_enemy_action_recorded:
			_frames_yielded_before_first_visible_action += 1
		await get_tree().process_frame
		frame_budget_started_usec = Time.get_ticks_usec()
		planning_slices_this_frame = 0
	return OperationResult.fail(
		&"reaction_resolution_ended_unexpectedly",
		"Enemy-phase Reaction resolution ended without a result."
	)


func _release_ai_planning_only_deferral() -> void:
	# Planning is read-only. Release the one precautionary boundary opened for a
	# new actor without invoking movement presentation or inserting a frame wait.
	_movement_commit_in_progress = true
	_facade.end_visibility_recalculation_deferral()
	_movement_commit_in_progress = false
	_flush_deferred_state_changes_without_animation()


func _capture_last_ai_simulation_timing() -> void:
	var enemy_snapshot: Dictionary = _facade.enemy_ai_performance_snapshot()
	var activation_timing: Dictionary = enemy_snapshot.get("activation_timing", {})
	var last: Dictionary = activation_timing.get("last", {})
	if bool(last.get("chain_warmup_reused", false)):
		_chain_warmup_reused_count += 1
	_last_ai_activation_simulation_usec = int(
		last.get("simulation_usec", last.get("total", last.get("total_usec", 0)))
	)


func _resolve_initiative_ai_with_reaction_prompts(
		acting_unit_id: StringName
) -> OperationResult:
	var result: OperationResult
	var frame_budget_started_usec: int = Time.get_ticks_usec()
	var planning_slices_this_frame: int = 0
	while true:
		var had_pending_planning: bool = _facade.has_pending_enemy_planning()
		var plan_ready: bool = _facade.enemy_planning_ready_to_commit()
		var resuming_reaction: bool = _facade.has_pending_ai_reaction()
		if not had_pending_planning and not resuming_reaction:
			_pending_ai_movement_events.clear()
			_last_ai_resolution_observable = false
		_movement_control_owner_before_commit = acting_unit_id

		var frame_processing_before_call: int = maxi(
			0, Time.get_ticks_usec() - frame_budget_started_usec
		)
		var remaining_budget_usec: int = maxi(
			250,
			ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC
			- frame_processing_before_call
		)
		var deferral_started: bool = false
		if resuming_reaction or plan_ready:
			if (
				plan_ready
				and _handoff_to_authoritative_commit_usec == 0
				and _handoff_requested_usec > 0
			):
				_handoff_to_authoritative_commit_usec = maxi(
					0,
					Time.get_ticks_usec() - _handoff_requested_usec
				)
			_pending_ai_movement_events.clear()
			_facade.begin_visibility_recalculation_deferral()
			deferral_started = true
			_movement_commit_in_progress = true
		result = (
			_facade.resume_ai_after_reaction()
			if resuming_reaction
			else (
				_facade.commit_ready_enemy_activation()
				if plan_ready
				else _facade.resolve_active_ai_initiative(remaining_budget_usec)
			)
		)
		_movement_commit_in_progress = false

		if result == null:
			if deferral_started:
				_release_ai_planning_only_deferral()
			return OperationResult.fail(
				&"initiative_ai_result_missing",
				"The initiative AI returned no activation result."
			)

		if result.code == &"enemy_planning_pending":
			_record_enemy_stall_thresholds(_enemy_stall_active_unit_id)
			if deferral_started:
				_release_ai_planning_only_deferral()
			_enemy_planning_slice_count += 1
			planning_slices_this_frame += 1
			_enemy_planning_max_slices_per_frame = maxi(
				_enemy_planning_max_slices_per_frame,
				planning_slices_this_frame
			)
			if (
				Time.get_ticks_usec() - frame_budget_started_usec
				< ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC
			):
				continue
			_enemy_planning_yield_count += 1
			_enemy_phase_frame_yields += 1
			_facade.record_enemy_planning_frame_yield(
				planning_slices_this_frame,
				false
			)
			if _facade.pending_enemy_planning_is_visibility():
				_destination_visibility_yield_count += 1
			await get_tree().process_frame
			frame_budget_started_usec = Time.get_ticks_usec()
			planning_slices_this_frame = 0
			continue

		if result.code == &"enemy_plan_ready":
			if deferral_started:
				_release_ai_planning_only_deferral()
			_enemy_planning_slice_count += 1
			planning_slices_this_frame += 1
			_enemy_planning_max_slices_per_frame = maxi(
				_enemy_planning_max_slices_per_frame,
				planning_slices_this_frame
			)
			continue

		_capture_last_ai_simulation_timing()
		var presentation_started_usec: int = Time.get_ticks_usec()
		if deferral_started:
			await _present_pending_ai_movement_events()
		_last_ai_activation_presentation_usec = maxi(
			0, Time.get_ticks_usec() - presentation_started_usec
		)
		if result.success:
			_facade.record_last_ai_presentation_timing(
				_last_ai_activation_presentation_usec
			)
			_last_ai_activation_total_usec = (
				_last_ai_activation_simulation_usec
				+ _last_ai_activation_presentation_usec
			)
		if not result.success:
			return result
		if result.code != &"reaction_pending":
			return result
		var opened: OperationResult = _facade.open_pending_ai_reaction_decision()
		if not opened.success:
			return opened
		var serial: int = _reaction_decision_serial
		await _await_reaction_prompt_resolution(serial)
		frame_budget_started_usec = Time.get_ticks_usec()
		planning_slices_this_frame = 0
	return OperationResult.fail(
		&"reaction_resolution_ended_unexpectedly",
		"Initiative AI Reaction resolution ended without a result."
	)


func _set_status(message: String) -> void:
	_last_status_message = message
	if _short_context_label != null:
		_short_context_label.text = message
		_short_context_label.tooltip_text = message
