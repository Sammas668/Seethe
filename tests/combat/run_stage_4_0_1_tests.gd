extends SceneTree

const TEST_SUITE: Script = preload(
	"res://tests/combat/stage_4_0_1_team_control_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = TEST_SUITE.run_all()
	if failures.is_empty():
		print("Stage 4.0.1 team-control and Enemy Turn tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
