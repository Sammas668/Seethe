extends SceneTree

const HOTFIX_5F6_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5f6_continuous_enemy_pipeline_tests.gd"
)
const HOTFIX_5F7_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5f7_first_enemy_gate_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(await HOTFIX_5F6_TESTS.run(self))
	failures.append_array(await HOTFIX_5F7_TESTS.run(self))
	if failures.is_empty():
		print("Stage 4.7 Hotfix 5f7 first-enemy activation-gate tests passed.")
		quit(0)
		return
	print("Stage 4.7 Hotfix 5f7 first-enemy activation-gate tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
