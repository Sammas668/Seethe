extends RefCounted

const SCREEN_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var screen: Node = SCREEN_SCENE.instantiate()
	var attack_tab: Button = screen.get_node(
		"HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/AttackButton"
	) as Button
	var mode_button: Button = screen.get_node(
		"HUD/BottomDeck/Margin/MainRow/HandBlock/AttackOptions/AttackModeButton"
	) as Button
	var primary_button: Button = screen.get_node(
		"HUD/BottomDeck/Margin/MainRow/HandBlock/HandRow/RightHandButton"
	) as Button
	var cursor_preview: PanelContainer = screen.get_node(
		"HUD/AttackCursorPreview"
	) as PanelContainer

	if attack_tab.visible:
		failures.append("The obsolete Attack tab is still visible.")
	if mode_button.text != "NORMAL · LETHAL":
		failures.append("The attack-mode button has the wrong authored default.")
	if not primary_button.toggle_mode:
		failures.append("Held weapons are not selectable toggle buttons.")
	if cursor_preview.visible:
		failures.append("The cursor attack preview should start hidden.")

	screen.free()
	return failures
