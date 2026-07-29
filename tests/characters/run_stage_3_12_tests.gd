extends SceneTree

const TEST_SUITE = preload(
	"res://tests/characters/stage_3_12_character_system_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TEST_SUITE.run_all()
	if failures.is_empty():
		print("Stage 3.10–3.12 persistent character tests passed.")
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)
