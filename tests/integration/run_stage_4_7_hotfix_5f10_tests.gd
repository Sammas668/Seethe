extends SceneTree

const HOTFIX_5F8_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5f8_targeted_melee_stall_tests.gd"
)
const HOTFIX_5F9_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5f9_cadence_polish_tests.gd"
)
const HOTFIX_5F10_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5f10_hidden_auto_pass_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(await HOTFIX_5F8_TESTS.run(self))
	failures.append_array(await HOTFIX_5F9_TESTS.run(self))
	failures.append_array(await HOTFIX_5F10_TESTS.run(self))
	if failures.is_empty():
		print("Stage 4.7 Hotfix 5f10 hidden-auto-pass tests passed.")
		quit(0)
		return
	print("Stage 4.7 Hotfix 5f10 hidden-auto-pass tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
