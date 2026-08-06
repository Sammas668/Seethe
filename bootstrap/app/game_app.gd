class_name GameApp
extends Node

const MAIN_MENU_SCENE: PackedScene = preload(
	"res://presentation/campaign/main_menu.tscn"
)
const CAMPAIGN_SHELL_SCENE: PackedScene = preload(
	"res://presentation/campaign/campaign_shell.tscn"
)
const TACTICAL_SCREEN_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)
const REGION_AUTHORING_SCENE: PackedScene = preload(
	"res://tools/region_authoring/region_authoring_screen.tscn"
)

var campaign_session: CampaignSession
var _main_menu: SeetheMainMenu
var _campaign_shell: CampaignShell
var _tactical_screen: Node
var _region_authoring_screen: RegionAuthoringScreen
var _loading_layer: CanvasLayer
var _pending_commit_envelope: MissionCommitEnvelope
var _commit_retry_layer: CanvasLayer


func _ready() -> void:
	print("Seethe Stage 5.1d Mission Routes and Notoriety loaded.")
	campaign_session = CampaignSession.new()
	campaign_session.configure()
	campaign_session.squad_arrived.connect(_on_squad_arrived)
	call_deferred("_open_main_menu")


func _open_main_menu(status_message: String = "") -> void:
	_close_loading_screen()
	_close_commit_retry_overlay()
	_free_tactical_screen()
	_free_region_authoring_screen()
	if _campaign_shell != null:
		_campaign_shell.queue_free()
		_campaign_shell = null
	if _main_menu == null:
		_main_menu = MAIN_MENU_SCENE.instantiate() as SeetheMainMenu
		if _main_menu == null:
			push_error("Could not instantiate the Stage 5.1d Main Menu.")
			return
		_main_menu.new_campaign_requested.connect(_on_new_campaign_requested)
		_main_menu.load_campaign_requested.connect(_on_load_campaign_requested)
		_main_menu.region_authoring_requested.connect(_on_region_authoring_requested)
		add_child(_main_menu)
	_main_menu.show()
	_main_menu.configure(campaign_session.has_saved_campaign(), status_message)


func _on_region_authoring_requested() -> void:
	if not bool(ProjectSettings.get_setting("seethe/development/enable_region_authoring", false)):
		return
	if _main_menu != null:
		_main_menu.hide()
	_free_region_authoring_screen()
	_region_authoring_screen = REGION_AUTHORING_SCENE.instantiate() as RegionAuthoringScreen
	if _region_authoring_screen == null:
		_open_main_menu("Could not open the Region Authoring Tool.")
		return
	_region_authoring_screen.close_requested.connect(_on_region_authoring_closed)
	add_child(_region_authoring_screen)


func _on_region_authoring_closed() -> void:
	_free_region_authoring_screen()
	if _main_menu != null:
		_main_menu.show()
	else:
		_open_main_menu("Region Authoring Tool closed.")


func _free_region_authoring_screen() -> void:
	if _region_authoring_screen != null:
		_region_authoring_screen.queue_free()
		_region_authoring_screen = null


func _on_new_campaign_requested() -> void:
	_show_loading_screen("Awakening the Fifth-God ruin and creating a new campaign…")
	await get_tree().process_frame
	var result: OperationResult = campaign_session.create_new_campaign()
	if not result.success:
		_open_main_menu(result.message)
		return
	_open_campaign_shell("New campaign created and autosaved.")


func _on_load_campaign_requested() -> void:
	_show_loading_screen("Loading campaign state…")
	await get_tree().process_frame
	var result: OperationResult = campaign_session.load_campaign()
	if not result.success:
		_open_main_menu(result.message)
		return
	var message: String = "Campaign loaded."
	if campaign_session.repository.recovered_from_backup:
		message = "The current save was damaged; the last valid backup was loaded."
	_open_campaign_shell(message)


func _open_campaign_shell(status_message: String = "", restore_pending_recovery: bool = true) -> void:
	_close_loading_screen()
	if _main_menu != null:
		_main_menu.queue_free()
		_main_menu = null
	if _campaign_shell == null:
		_campaign_shell = CAMPAIGN_SHELL_SCENE.instantiate() as CampaignShell
		if _campaign_shell == null:
			push_error("Could not instantiate the Stage 5.1d Campaign Shell.")
			return
		_campaign_shell.deploy_requested.connect(_on_deploy_requested)
		_campaign_shell.restart_registered_mission_requested.connect(
			_on_restart_registered_mission_requested
		)
		_campaign_shell.load_current_campaign_requested.connect(
			_on_load_current_campaign_from_shell
		)
		_campaign_shell.return_to_main_menu_requested.connect(_on_return_to_main_menu)
		_campaign_shell.reload_safe_checkpoint_requested.connect(_on_reload_safe_checkpoint)
		_campaign_shell.quit_requested.connect(_on_quit_requested)
		_campaign_shell.mission_recovery_confirmed.connect(_on_mission_recovery_confirmed)
		_campaign_shell.mission_recovery_selection_changed.connect(
			_on_mission_recovery_selection_changed
		)
		add_child(_campaign_shell)
		_campaign_shell.configure(campaign_session)
	_campaign_shell.show()
	var restored_recovery: bool = (
		_restore_pending_mission_recovery() if restore_pending_recovery else false
	)
	if not restored_recovery and not status_message.is_empty():
		_campaign_shell.show_region_map(status_message)


func _restore_pending_mission_recovery() -> bool:
	if campaign_session == null or _campaign_shell == null:
		return false
	var pending: Dictionary = campaign_session.load_pending_mission_recovery()
	if pending.is_empty():
		return false
	var envelope: MissionCommitEnvelope = pending.get("envelope") as MissionCommitEnvelope
	if envelope == null or envelope.result == null:
		campaign_session.clear_pending_mission_recovery()
		return false
	_pending_commit_envelope = envelope
	if envelope.result.mission_outcome == MissionOutcome.CAMPAIGN_DEFEAT:
		_show_loading_screen("Restoring the final mission result…")
		call_deferred("_attempt_pending_result_commit")
		return true
	var snapshot: Dictionary = campaign_session.build_mission_recovery_snapshot(envelope)
	if snapshot.is_empty():
		_show_commit_retry_overlay("The saved mission recovery manifest could not be rebuilt.")
		return true
	var selected_ids: Array[StringName] = []
	for raw_item_id: Variant in pending.get("selected_optional_item_ids", []) as Array:
		var item_id := StringName(raw_item_id)
		if not item_id.is_empty():
			selected_ids.append(item_id)
	var selected_captive_ids: Array[StringName] = []
	for raw_captive_id: Variant in pending.get("selected_captive_ids", []) as Array:
		var captive_id := StringName(raw_captive_id)
		if not captive_id.is_empty():
			selected_captive_ids.append(captive_id)
	_campaign_shell.show_mission_recovery(
		envelope.result,
		snapshot,
		selected_ids,
		selected_captive_ids,
		bool(pending.get("selection_initialized", false))
	)
	return true


func _on_deploy_requested(
		mission_instance_id: StringName,
		selected_character_ids: Array[StringName]
) -> void:
	_show_loading_screen("Registering immutable mission setup and assembling the Farm Raid…")
	await get_tree().process_frame
	var result: OperationResult = campaign_session.register_mission_and_create_session(
		mission_instance_id,
		selected_character_ids
	)
	if not result.success:
		_close_loading_screen()
		_campaign_shell.show_error(result.message)
		return
	_launch_tactical_session(result.data as TacticalSession)


func _on_squad_arrived(mission_instance_id: StringName) -> void:
	_show_loading_screen("The warband has reached the mission site…")
	await get_tree().process_frame
	var result: OperationResult = campaign_session.restart_registered_mission(
		mission_instance_id
	)
	if not result.success:
		_close_loading_screen()
		if _campaign_shell != null:
			_campaign_shell.show()
			_campaign_shell.show_error(result.message)
		return
	_launch_tactical_session(result.data as TacticalSession)


func _on_restart_registered_mission_requested() -> void:
	_show_loading_screen("Rebuilding the registered Farm Raid from its immutable setup…")
	await get_tree().process_frame
	var result: OperationResult = campaign_session.restart_registered_mission()
	if not result.success:
		_close_loading_screen()
		_campaign_shell.show_error(result.message)
		return
	_launch_tactical_session(result.data as TacticalSession)


func _launch_tactical_session(session: TacticalSession) -> void:
	if session == null:
		_close_loading_screen()
		_campaign_shell.show_error("The tactical session could not be created.")
		return
	if _campaign_shell != null:
		_campaign_shell.hide()
	_free_tactical_screen()
	_tactical_screen = TACTICAL_SCREEN_SCENE.instantiate()
	if _tactical_screen == null:
		_close_loading_screen()
		_campaign_shell.show()
		_campaign_shell.show_error("Could not instantiate the tactical screen.")
		return
	_tactical_screen.call("configure", session)
	if _tactical_screen.has_signal("mission_result_ready"):
		_tactical_screen.connect("mission_result_ready", _on_mission_result_ready)
	add_child(_tactical_screen)
	_close_loading_screen()


func _on_mission_result_ready(envelope: MissionCommitEnvelope) -> void:
	_pending_commit_envelope = envelope
	_retire_tactical_presentation_for_recovery()
	if envelope == null or envelope.result == null:
		_show_commit_retry_overlay("The tactical mission returned no complete result envelope.")
		return
	var persisted: OperationResult = campaign_session.save_pending_mission_recovery(envelope)
	if not persisted.success:
		_show_commit_retry_overlay(persisted.message)
		return
	# The immutable result is now persisted independently of the tactical scene.
	# Remove the complete tactical presentation before revealing strategic UI so
	# no HUD CanvasLayer can remain above the Recovery screen.
	_free_tactical_screen()
	if _campaign_shell == null:
		_open_campaign_shell("", false)
	else:
		_campaign_shell.show()
	if envelope.result.mission_outcome == MissionOutcome.CAMPAIGN_DEFEAT:
		# Defeat still requires the exact-once campaign commit so permanent death,
		# mission history and the campaign status are stored before showing defeat.
		_show_loading_screen("Committing the final mission result…")
		await get_tree().process_frame
		_attempt_pending_result_commit()
		return
	var recovery_snapshot: Dictionary = campaign_session.build_mission_recovery_snapshot(envelope)
	if recovery_snapshot.is_empty():
		_show_commit_retry_overlay("The mission recovery manifest could not be assembled.")
		return
	_campaign_shell.show_mission_recovery(envelope.result, recovery_snapshot)


func _on_mission_recovery_selection_changed(
	selected_item_ids: Array[StringName],
	selected_captive_ids: Array[StringName]
) -> void:
	if _pending_commit_envelope == null or campaign_session == null:
		return
	var saved: OperationResult = campaign_session.save_pending_mission_recovery(
		_pending_commit_envelope,
		selected_item_ids,
		selected_captive_ids,
		true
	)
	if not saved.success and _campaign_shell != null:
		_campaign_shell.show_error(saved.message)


func _on_mission_recovery_confirmed(
	selected_item_ids: Array[StringName],
	selected_captive_ids: Array[StringName]
) -> void:
	if _pending_commit_envelope == null:
		return
	var prepared: OperationResult = campaign_session.prepare_mission_recovery_envelope(
		_pending_commit_envelope,
		selected_item_ids,
		selected_captive_ids
	)
	if not prepared.success:
		if _campaign_shell != null:
			_campaign_shell.show_error(prepared.message)
		return
	_pending_commit_envelope = prepared.data as MissionCommitEnvelope
	var persisted: OperationResult = campaign_session.save_pending_mission_recovery(
		_pending_commit_envelope,
		selected_item_ids,
		selected_captive_ids,
		true
	)
	if not persisted.success:
		if _campaign_shell != null:
			_campaign_shell.show_error(persisted.message)
		return
	_show_loading_screen("Committing survivors, injuries and confirmed recovered cargo…")
	await get_tree().process_frame
	_attempt_pending_result_commit()


func _attempt_pending_result_commit() -> void:
	if _pending_commit_envelope == null:
		_close_loading_screen()
		return
	var result: OperationResult = campaign_session.commit_tactical_envelope(
		_pending_commit_envelope
	)
	if not result.success:
		_close_loading_screen()
		_show_commit_retry_overlay(result.message)
		return
	var mission_result: MissionResult = result.data as MissionResult
	campaign_session.clear_pending_mission_recovery()
	_pending_commit_envelope = null
	_close_loading_screen()
	_free_tactical_screen()
	if _campaign_shell == null:
		_open_campaign_shell()
	else:
		_campaign_shell.show()
	if result.code == &"campaign_defeat" or (
		mission_result != null
		and mission_result.mission_outcome == MissionOutcome.CAMPAIGN_DEFEAT
	):
		_campaign_shell.show_campaign_defeat(mission_result)
	else:
		_campaign_shell.show_mission_summary(mission_result)


func _show_commit_retry_overlay(message: String) -> void:
	_close_commit_retry_overlay()
	_commit_retry_layer = CanvasLayer.new()
	_commit_retry_layer.layer = 1200
	add_child(_commit_retry_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.02, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_commit_retry_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-310, -150)
	panel.size = Vector2(620, 300)
	shade.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	var title := Label.new()
	title.text = "CAMPAIGN COMMIT FAILED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	content.add_child(title)
	var body := Label.new()
	body.text = message + "\n\nThe immutable tactical result is still held in memory and has not been discarded."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(body)
	var retry := Button.new()
	retry.text = "RETRY RESULT COMMIT"
	retry.pressed.connect(_on_retry_result_commit_pressed)
	content.add_child(retry)
	var safe := Button.new()
	safe.text = "RESTORE LAST SAFE STATE"
	safe.pressed.connect(_on_restore_after_commit_failure_pressed)
	content.add_child(safe)


func _on_retry_result_commit_pressed() -> void:
	_close_commit_retry_overlay()
	_show_loading_screen("Retrying exact-once campaign commitment…")
	await get_tree().process_frame
	_attempt_pending_result_commit()


func _on_restore_after_commit_failure_pressed() -> void:
	_pending_commit_envelope = null
	campaign_session.clear_pending_mission_recovery()
	_close_commit_retry_overlay()
	_on_reload_safe_checkpoint()


func _close_commit_retry_overlay() -> void:
	if _commit_retry_layer != null:
		_commit_retry_layer.queue_free()
		_commit_retry_layer = null


func _on_reload_safe_checkpoint() -> void:
	_show_loading_screen("Restoring the last safe campaign state…")
	await get_tree().process_frame
	_pending_commit_envelope = null
	campaign_session.clear_pending_mission_recovery()
	_close_commit_retry_overlay()
	var result: OperationResult = campaign_session.restore_safe_checkpoint()
	_close_loading_screen()
	_free_tactical_screen()
	if not result.success:
		if _campaign_shell != null:
			_campaign_shell.show()
			_campaign_shell.show_error(result.message)
		else:
			_open_main_menu(result.message)
		return
	if _campaign_shell == null:
		_open_campaign_shell(result.message)
	else:
		_campaign_shell.show()
		_campaign_shell.show_region_map(result.message)


func _on_load_current_campaign_from_shell() -> void:
	_show_loading_screen("Loading the current campaign save…")
	await get_tree().process_frame
	var result: OperationResult = campaign_session.load_campaign()
	_close_loading_screen()
	if not result.success:
		_campaign_shell.show_error(result.message)
		return
	_pending_commit_envelope = null
	if not _restore_pending_mission_recovery():
		_campaign_shell.show_region_map(result.message)


func _on_quit_requested() -> void:
	get_tree().quit()


func _on_return_to_main_menu() -> void:
	campaign_session.pause_clock()
	_open_main_menu()


func _retire_tactical_presentation_for_recovery() -> void:
	if _tactical_screen == null:
		return
	# TacticalScreen is a Node2D with its HUD in a CanvasLayer. Hiding only the
	# Node2D does not reliably hide or disable a child CanvasLayer, so explicitly
	# disable processing/input and hide both presentation roots immediately.
	_tactical_screen.process_mode = Node.PROCESS_MODE_DISABLED
	_tactical_screen.set_process(false)
	_tactical_screen.set_physics_process(false)
	_tactical_screen.set_process_input(false)
	_tactical_screen.set_process_unhandled_input(false)
	_tactical_screen.set_process_unhandled_key_input(false)
	var hud: CanvasLayer = _tactical_screen.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	if _tactical_screen is CanvasItem:
		(_tactical_screen as CanvasItem).visible = false


func _free_tactical_screen() -> void:
	if _tactical_screen != null:
		_tactical_screen.queue_free()
		_tactical_screen = null


func _show_loading_screen(message: String) -> void:
	_close_loading_screen()
	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 1000
	add_child(_loading_layer)
	var background := ColorRect.new()
	background.color = Color(0.025, 0.02, 0.03, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_layer.add_child(background)
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 22)
	background.add_child(label)


func _close_loading_screen() -> void:
	if _loading_layer != null:
		_loading_layer.queue_free()
		_loading_layer = null
