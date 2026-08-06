extends SceneTree

const TEST_SUITE = preload(
	"res://tests/integration/stage_3_15_integrity_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TEST_SUITE.run_all()
	if failures.is_empty():
		print("Stage 3.15 mission/save/transaction tests passed.")
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)
