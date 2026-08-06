extends SceneTree

const TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5d_offscreen_enemy_turn_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await TESTS.run(self)
	if failures.is_empty():
		print("Stage 4.7 Hotfix 5d off-screen enemy-turn tests passed.")
		quit(0)
		return
	print("Stage 4.7 Hotfix 5d off-screen enemy-turn tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
