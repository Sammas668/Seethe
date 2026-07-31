extends SceneTree

const PREVIOUS_TEST_SCRIPT: Script = preload(
	"res://tests/tactical/stage_4_3_3_extraction_mission_tests.gd"
)
const STABILISATION_TEST_SCRIPT: Script = preload(
	"res://tests/tactical/stage_4_3_3c_mission_loop_stabilisation_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = []
	failures.append_array(PREVIOUS_TEST_SCRIPT.run_all())
	failures.append_array(STABILISATION_TEST_SCRIPT.run_all())
	if failures.is_empty():
		print("Stage 4.3.3c mission-loop stabilisation tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
