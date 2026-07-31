extends SceneTree

const PREVIOUS_TEST_SCRIPT: Script = preload(
	"res://tests/tactical/stage_4_4e_tactical_geometry_performance_cover_presentation_tests.gd"
)
const STAGE_4_4E1_TEST_SCRIPT: Script = preload(
	"res://tests/tactical/stage_4_4e1_cover_ui_movement_animation_hotfix_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = []
	failures.append_array(PREVIOUS_TEST_SCRIPT.run_all())
	failures.append_array(STAGE_4_4E1_TEST_SCRIPT.run_all())
	if failures.is_empty():
		print("Stage 4.4e1 cover UI and movement-animation hotfix tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
