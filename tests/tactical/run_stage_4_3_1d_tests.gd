extends SceneTree

const TEST_SCRIPT: Script = preload(
	"res://tests/tactical/stage_4_3_1d_diagonal_melee_alert_dedup_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TEST_SCRIPT.run_all()
	if failures.is_empty():
		print("Stage 4.3.1d diagonal melee and alert deduplication tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
