extends SceneTree

const TEST_SUITE: Script = preload(
	"res://tests/combat/stage_4_0_practice_dummy_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TEST_SUITE.run_all()
	if failures.is_empty():
		print("Stage 4.0 Practice Dummy combat tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
