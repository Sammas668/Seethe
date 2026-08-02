extends Node

const TACTICAL_SCREEN_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)
const MISSION_SELECTOR_SCENE: PackedScene = preload(
	"res://presentation/debug/debug_mission_selector.tscn"
)
const AUTHORED_MISSION_FACTORY_SCRIPT: Script = preload(
	"res://bootstrap/debug/authored_mission_factory.gd"
)

var _loading_layer: CanvasLayer
var _mission_selector: DebugMissionSelector
var _tactical_screen: Node


func _ready() -> void:
	print("Seethe Stage 4.7 Hotfix 5f enemy movement pipeline and cadence optimisation loaded.")
	call_deferred("_open_mission_selector")


func _open_mission_selector() -> void:
	if _tactical_screen != null:
		_tactical_screen.queue_free()
		_tactical_screen = null
	if _mission_selector == null:
		_mission_selector = MISSION_SELECTOR_SCENE.instantiate() as DebugMissionSelector
		if _mission_selector == null:
			push_error("Could not instantiate the Stage 4.6 mission selector.")
			return
		_mission_selector.launch_requested.connect(_on_mission_launch_requested)
		add_child(_mission_selector)
	_mission_selector.prepare_for_display()


func _on_mission_launch_requested(
		mission_definition: MissionDefinition,
		selected_character_ids: Array[StringName]
) -> void:
	if mission_definition == null:
		return
	_show_loading_screen(
		"Finalising mission setup and assembling %s…" % mission_definition.display_name
	)
	await get_tree().process_frame
	var session: TacticalSession = AUTHORED_MISSION_FACTORY_SCRIPT.create_session(
		mission_definition,
		selected_character_ids
	)
	if session == null:
		_close_loading_screen()
		push_error("Could not create the authored mission session.")
		if _mission_selector != null:
			_mission_selector.report_launch_failure(
				"Mission assembly failed. Review the error log, then try again."
			)
		return
	_mission_selector.hide()
	_tactical_screen = TACTICAL_SCREEN_SCENE.instantiate()
	if _tactical_screen == null:
		_close_loading_screen()
		push_error("Could not instantiate the tactical screen.")
		return
	_tactical_screen.call("configure", session)
	if _tactical_screen.has_signal("mission_finished"):
		_tactical_screen.connect("mission_finished", _on_mission_finished)
	add_child(_tactical_screen)
	_close_loading_screen()


func _on_mission_finished() -> void:
	_open_mission_selector()


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
	background.add_child(label)


func _close_loading_screen() -> void:
	if _loading_layer != null:
		_loading_layer.queue_free()
		_loading_layer = null
