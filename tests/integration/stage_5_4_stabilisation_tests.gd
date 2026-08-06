class_name Stage54StabilisationTests
extends RefCounted

const StrongholdDefinitionRegistryScript = preload(
	"res://application/stronghold/stronghold_definition_registry.gd"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_starting_stables_are_preplaced_not_buildable(failures)
	_test_current_stage_5_4_behavioural_suites(failures)
	return failures


static func _test_starting_stables_are_preplaced_not_buildable(
		failures: Array[String]
) -> void:
	var registry = StrongholdDefinitionRegistryScript.new()
	var registry_errors: Array[String] = registry.configure()
	_expect(
		registry_errors.is_empty(),
		"Starting stronghold registry failed validation: %s" % "; ".join(PackedStringArray(registry_errors)),
		failures
	)
	var definition = registry.starting_definition()
	_expect(definition != null, "Starting stronghold definition is missing.", failures)
	if definition == null:
		return
	var stables = definition.facility_definition(&"facility.stables")
	_expect(stables != null, "Starting Stables definition is missing.", failures)
	if stables == null:
		return
	_expect(not stables.buildable, "Starting Stables incorrectly appear in the build catalogue.", failures)
	_expect(stables.starting_facility, "Stables are not marked as authored starting infrastructure.", failures)
	_expect(stables.footprint == Vector2i(2, 2), "Starting Stables do not use the locked 2×2 footprint.", failures)

	var buildable_ids: Dictionary = {}
	for facility in definition.buildable_facilities():
		buildable_ids[facility.id] = true
	_expect(not buildable_ids.has(&"facility.stables"), "Buildable catalogue contains Stables.", failures)
	_expect(buildable_ids.has(&"facility.living_quarters"), "Buildable catalogue lost Living Quarters.", failures)

	var state = registry.create_initial_state()
	_expect(state != null, "Starting stronghold state could not be created.", failures)
	if state == null:
		return
	var stable_state = state.get_facility(&"facility.stables")
	_expect(stable_state != null, "Starting state did not instantiate the authored Stables.", failures)
	if stable_state != null:
		_expect(stable_state.is_starting_facility, "Starting Stables state lost its starting-facility flag.", failures)
		_expect(stable_state.condition == &"operational", "Starting Stables are not operational.", failures)
		_expect(stable_state.origin == Vector2i(2, 5), "Starting Stables origin changed from the authored edge position.", failures)


static func _test_current_stage_5_4_behavioural_suites(failures: Array[String]) -> void:
	failures.append_array(Stage54BManufacturingPersonnelRepairTests.run_all())
	failures.append_array(Stage54CResearchOrganisationalUnlocksTests.run_all())


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
