extends SceneTree

const TEST_SCRIPT: Script = preload(
	"res://tests/presentation/stage_4_1_1_direct_weapon_targeting_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TEST_SCRIPT.run_all()
	if failures.is_empty():
		print("Stage 4.1.1 direct weapon targeting tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
