extends RefCounted

const SCREEN_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var screen: Node = SCREEN_SCENE.instantiate()

	var bottom_deck: Control = screen.get_node("HUD/BottomDeck") as Control
	var context_label: Label = screen.get_node(
		"HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortContextLabel"
	) as Label
	var capacity_container: Control = screen.get_node(
		"HUD/BottomDeck/Margin/MainRow/UnitBlock/UnitCapacityBarContainer"
	) as Control
	var capacity_label: Label = screen.get_node(
		"HUD/BottomDeck/Margin/MainRow/UnitBlock/UnitCapacityBarContainer/UnitCapacityValueLabel"
	) as Label

	if bottom_deck.offset_top > 570.0:
		failures.append("Bottom deck was not enlarged for wrapped UnitBlock text.")
	if context_label.custom_minimum_size.y < 52.0:
		failures.append("UnitBlock context did not reserve enough wrapped-text height.")
	if context_label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		failures.append("UnitBlock context wrapping is disabled.")
	if capacity_container.custom_minimum_size.y < 18.0:
		failures.append("Movement bar is too short to contain a numerical value.")
	if capacity_label.text != "30 / 30 ft":
		failures.append("Movement bar does not contain the authored numerical value.")
	if capacity_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		failures.append("Movement value is not horizontally centred.")
	if capacity_label.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
		failures.append("Movement value is not vertically centred.")

	screen.free()
	return failures
