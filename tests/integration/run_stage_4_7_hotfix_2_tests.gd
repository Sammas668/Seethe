extends SceneTree

const TESTS: Script = preload(
	"res://tests/integration/stage_4_7_character_sheet_conformance_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = TESTS.run(self)
	if failures.is_empty():
		print("Stage 4.7 Hotfix 2 loadout legality and character-sheet tests passed.")
		quit(0)
		return
	print("Stage 4.7 Hotfix 2 tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
