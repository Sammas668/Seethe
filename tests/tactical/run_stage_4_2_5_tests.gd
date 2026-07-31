extends SceneTree

const TEST_SCRIPT: Script = preload(
	"res://tests/tactical/stage_4_2_5_stealth_awareness_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TEST_SCRIPT.run_all()
	if failures.is_empty():
		print("Stage 4.2.5 stealth, awareness and alert tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
