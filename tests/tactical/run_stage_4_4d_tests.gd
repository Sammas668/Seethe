extends SceneTree

const PREVIOUS_TEST_SCRIPT: Script = preload(
	"res://tests/tactical/stage_4_4_cover_openings_breaching_tests.gd"
)
const STAGE_4_4D_TEST_SCRIPT: Script = preload(
	"res://tests/tactical/stage_4_4d_cover_readability_automatic_opening_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = []
	failures.append_array(PREVIOUS_TEST_SCRIPT.run_all())
	failures.append_array(STAGE_4_4D_TEST_SCRIPT.run_all())
	if failures.is_empty():
		print("Stage 4.4d cover readability, automatic Peek/Lean and Interact tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
