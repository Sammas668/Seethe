extends SceneTree

const TESTS: Script = preload(
	"res://tests/integration/stage_4_5g_foundation_lock_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = TESTS.run(self)
	if failures.is_empty():
		print("Stage 4.5g Foundation Lock tests passed.")
		quit(0)
		return
	print("Stage 4.5g Foundation Lock tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
