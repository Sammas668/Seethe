extends Node

const TACTICAL_UI_SANDBOX: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)
const TACTICAL_SANDBOX_FACTORY_SCRIPT: Script = preload(
	"res://bootstrap/debug/tactical_sandbox_factory.gd"
)


func _ready() -> void:
	print("Seethe Stage 4.1.2 friendly selection targeting fix loaded.")
	call_deferred("_open_tactical_ui_sandbox")


func _open_tactical_ui_sandbox() -> void:
	var session: TacticalSession = TACTICAL_SANDBOX_FACTORY_SCRIPT.create_session()
	var screen: Node = TACTICAL_UI_SANDBOX.instantiate()
	if screen == null:
		push_error("Could not instantiate the tactical UI sandbox.")
		return
	screen.call("configure", session)
	add_child(screen)
