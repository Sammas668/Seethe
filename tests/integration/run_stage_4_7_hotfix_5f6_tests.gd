extends SceneTree

const HOTFIX_5F6_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5f6_continuous_enemy_pipeline_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(await HOTFIX_5F6_TESTS.run(self))
	if failures.is_empty():
		print("Stage 4.7 Hotfix 5f6 continuous enemy-pipeline tests passed.")
		quit(0)
		return
	print("Stage 4.7 Hotfix 5f6 continuous enemy-pipeline tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
