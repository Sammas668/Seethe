extends SceneTree

const TestSuite = preload(
	"res://tests/campaign/stage_5_3_storage_grouping_dismantling_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TestSuite.run_all()
	if failures.is_empty():
		print("PASS — Stage 5.3 Storage grouping and dismantling tests")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
