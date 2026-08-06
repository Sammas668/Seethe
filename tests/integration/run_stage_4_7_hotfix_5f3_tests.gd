extends SceneTree

const HOTFIX_5F3_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5f3_rapid_enemy_cadence_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(await HOTFIX_5F3_TESTS.run(self))
	if failures.is_empty():
		print("Stage 4.7 Hotfix 5f3 rapid enemy cadence tests passed.")
		quit(0)
		return
	print("Stage 4.7 Hotfix 5f3 rapid enemy cadence tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
