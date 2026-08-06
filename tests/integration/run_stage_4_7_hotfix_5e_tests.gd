extends SceneTree

const HOTFIX_5D_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5d_offscreen_enemy_turn_tests.gd"
)
const HOTFIX_5E_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5e_enemy_turn_responsiveness_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(await HOTFIX_5D_TESTS.run(self))
	failures.append_array(await HOTFIX_5E_TESTS.run(self))
	if failures.is_empty():
		print("Stage 4.7 Hotfix 5e enemy-turn responsiveness tests passed.")
		quit(0)
		return
	print("Stage 4.7 Hotfix 5e enemy-turn responsiveness tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
