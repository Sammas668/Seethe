extends SceneTree

const HOTFIX_5F7_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5f7_first_enemy_gate_tests.gd"
)
const HOTFIX_5F8_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5f8_targeted_melee_stall_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(await HOTFIX_5F7_TESTS.run(self))
	failures.append_array(await HOTFIX_5F8_TESTS.run(self))
	if failures.is_empty():
		print("Stage 4.7 Hotfix 5f8 targeted-melee and stall-attribution tests passed.")
		quit(0)
		return
	print("Stage 4.7 Hotfix 5f8 targeted-melee and stall-attribution tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
