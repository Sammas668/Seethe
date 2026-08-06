extends SceneTree

const TESTS: Script = preload(
	"res://tests/tactical/stage_4_5f_authoritative_interrupted_movement_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = TESTS.run(self)
	if failures.is_empty():
		print("Stage 4.5f Authoritative Interrupted Movement tests passed.")
		quit(0)
		return
	print("Stage 4.5f Authoritative Interrupted Movement tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
