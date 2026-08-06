extends SceneTree

const TestsScript = preload(
	"res://tests/campaign/stage_5_3c_persistent_health_recovery_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TestsScript.run_all()
	if failures.is_empty():
		print("Stage 5.3c persistent health and recovery tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
