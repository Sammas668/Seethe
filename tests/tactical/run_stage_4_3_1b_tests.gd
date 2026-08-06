extends SceneTree

const TEST_SCRIPT: Script = preload(
	"res://tests/tactical/stage_4_3_1a_token_status_squad_alert_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TEST_SCRIPT.run_all()
	if failures.is_empty():
		print("Stage 4.3.1b dying tracker and enemy-only awareness icon tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
