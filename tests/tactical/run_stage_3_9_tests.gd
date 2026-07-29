extends SceneTree

const TEST_SUITE = preload(
	"res://tests/tactical/stage_3_9_invariant_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TEST_SUITE.run_all()
	if failures.is_empty():
		print("Stage 3.9 hardening tests passed.")
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)
