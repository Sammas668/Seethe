extends SceneTree

const TEST_SCRIPT: Script = preload(
	"res://tests/characters/stage_4_2_1_constructor_hotfix_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TEST_SCRIPT.run_all()
	if failures.is_empty():
		print("Stage 4.2.1 constructor hotfix tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
