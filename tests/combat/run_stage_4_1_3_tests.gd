extends SceneTree

const TEST_SCRIPT: Script = preload(
	"res://tests/combat/stage_4_1_3_combat_integrity_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TEST_SCRIPT.run_all()
	if failures.is_empty():
		print("Stage 4.1.3 combat integrity tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
