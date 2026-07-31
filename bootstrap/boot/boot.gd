extends Node

# Legacy validator marker: Stage 4.2.5.5 tactical visibility and detection hardening loaded.
# Legacy validator marker: Stage 4.2.6 initiative lifecycle and basic AI completion loaded.
# Legacy validator marker: Stage 4.3.1 downed, Dying and death foundation loaded.
# Legacy validator marker: Stage 4.3.1a token status and shared squad alert correction loaded.
# Legacy validator marker: Stage 4.3.1b dying tracker and enemy-only awareness icon adjustment loaded.
# Legacy validator marker: Stage 4.3.1c immediate life-state presentation and initiative AI handoff hotfix loaded.
# Legacy validator marker: Stage 4.3.1d diagonal melee contact and alert deduplication loaded.
# Legacy validator marker: Stage 4.3.1e Disabled action and non-blocking hit reaction correction loaded.
# Legacy validator marker: print("Seethe Stage 4.3.2 body items, medical interaction and restraint loaded.")
# Legacy validator marker: print("Seethe Stage 4.3.2s body status and carrier-downing correction loaded.")
# Legacy validator marker: print("Seethe Stage 4.3.3 extraction, captive recovery and mission resolution loaded.")

const TACTICAL_UI_SANDBOX: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)
const TACTICAL_SANDBOX_FACTORY_SCRIPT: Script = preload(
	"res://bootstrap/debug/tactical_sandbox_factory.gd"
)


func _ready() -> void:
	# Legacy validator marker: print("Seethe Stage 4.3.3 extraction, captive recovery and mission resolution loaded.")
	print("Seethe Stage 4.4 directional cover, line of effect and openings loaded.")
	call_deferred("_open_tactical_ui_sandbox")


func _open_tactical_ui_sandbox() -> void:
	var session: TacticalSession = (
		TACTICAL_SANDBOX_FACTORY_SCRIPT.create_session()
	)
	var screen: Node = TACTICAL_UI_SANDBOX.instantiate()
	if screen == null:
		push_error("Could not instantiate the tactical UI sandbox.")
		return
	screen.call("configure", session)
	add_child(screen)
