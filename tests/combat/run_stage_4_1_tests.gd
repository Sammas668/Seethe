extends SceneTree

const TEST_SUITE: Script = preload(
	"res://tests/combat/stage_4_1_active_enemy_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TEST_SUITE.run_all()
	if failures.is_empty():
		print("Stage 4.1 first active enemy tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
