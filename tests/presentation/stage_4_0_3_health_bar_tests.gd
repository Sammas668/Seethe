extends RefCounted

const HEALTH_BAR_SCRIPT: Script = preload(
	"res://presentation/tactical/widgets/segmented_health_bar.gd"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_directional_segments(failures)
	_test_value_label(failures)
	return failures


static func _test_directional_segments(failures: Array[String]) -> void:
	var bar: Control = HEALTH_BAR_SCRIPT.new()
	bar.size = Vector2(200.0, 20.0)
	bar.call("set_values", 30, 40, 10)

	var health: ColorRect = bar.get_node("HealthFill") as ColorRect
	var lethal: ColorRect = bar.get_node("LethalDamageFill") as ColorRect
	var nonlethal: ColorRect = bar.get_node("NonlethalDamageFill") as ColorRect
	if not is_equal_approx(health.size.x, 150.0):
		failures.append("Green health did not retain the left 75 percent.")
	if not is_equal_approx(lethal.position.x, 150.0):
		failures.append("Red lethal damage did not begin at the current-HP boundary.")
	if not is_equal_approx(lethal.size.x, 50.0):
		failures.append("Red lethal damage did not occupy the rightmost 25 percent.")
	if not is_equal_approx(nonlethal.position.x, 0.0):
		failures.append("White nonlethal damage did not begin at the left edge.")
	if not is_equal_approx(nonlethal.size.x, 50.0):
		failures.append("White nonlethal damage did not fill left-to-right.")


static func _test_value_label(failures: Array[String]) -> void:
	var bar: Control = HEALTH_BAR_SCRIPT.new()
	bar.size = Vector2(160.0, 18.0)
	bar.call("set_values", 22, 32, 0)
	var label: Label = bar.get_node("ValueLabel") as Label
	if label.text != "22 / 32":
		failures.append("Health bar did not display the numerical HP value inside it.")
