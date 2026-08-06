extends SceneTree

const TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5_marauder_mechanics_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = TESTS.run(self)
	if failures.is_empty():
		print("Stage 4.7 Hotfix 5 Marauder mechanics tests passed.")
		quit(0)
		return
	print("Stage 4.7 Hotfix 5 Marauder mechanics tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
