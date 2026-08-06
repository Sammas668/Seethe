extends SceneTree

const Stage53DeploymentReservationTestsScript = preload(
	"res://tests/campaign/stage_5_3_deployment_reservation_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = (
		Stage53DeploymentReservationTestsScript.run_all()
	)
	if failures.is_empty():
		print("Stage 5.3 deployment reservation tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
