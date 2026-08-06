class_name StrongholdConnectivityService
extends RefCounted

const StrongholdDefinitionScript = preload("res://domain/stronghold/stronghold_definition.gd")
const StrongholdStateScript = preload("res://domain/stronghold/stronghold_state.gd")
const StrongholdPlotStateScript = preload("res://domain/stronghold/stronghold_plot_state.gd")
const StrongholdPlotDefinitionScript = preload("res://domain/stronghold/stronghold_plot_definition.gd")


const ORTHOGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]


func build_snapshot(
	definition: StrongholdDefinitionScript,
	state: StrongholdStateScript
) -> Dictionary:
	var snapshot: Dictionary = {
		"adjacent": {},
		"connectors": [],
		"connected_to_heart": {},
		"connected_to_access": {},
		"connected_to_entrance": {},
		"connected": {},
		"isolated": {},
		"accessible_plot_count": 0,
		"connected_plot_count": 0,
	}
	if definition == null or state == null:
		return snapshot
	var adjacency: Dictionary = {}
	var accessible: Dictionary = {}
	for plot_state: StrongholdPlotStateScript in state.get_plots():
		if StrongholdPlotDefinitionScript.is_accessible_state(plot_state.current_state):
			accessible[plot_state.key()] = true
			adjacency[plot_state.key()] = []
	for raw_key: Variant in accessible.keys():
		var key := StringName(raw_key)
		var plot_state: StrongholdPlotStateScript = state.plots_by_key.get(key) as StrongholdPlotStateScript
		if plot_state == null:
			continue
		for direction: Vector2i in ORTHOGONAL_DIRECTIONS:
			var neighbour_key: StringName = StrongholdDefinitionScript.coord_key(plot_state.coord + direction)
			if accessible.has(neighbour_key):
				(adjacency[key] as Array).append(neighbour_key)
	snapshot["adjacent"] = adjacency
	var heart_starts: Array[StringName] = []
	for plot_state: StrongholdPlotStateScript in state.get_plots():
		if plot_state.current_state == StrongholdPlotDefinitionScript.FIXED_HEART:
			heart_starts.append(plot_state.key())
	var access_starts: Array[StringName] = [StrongholdDefinitionScript.coord_key(definition.primary_access_coord)]
	var from_heart: Dictionary = _reachable(adjacency, heart_starts)
	var from_access: Dictionary = _reachable(adjacency, access_starts)
	var connected: Dictionary = {}
	var isolated: Dictionary = {}
	for raw_key: Variant in accessible.keys():
		var key := StringName(raw_key)
		if from_heart.has(key) and from_access.has(key):
			connected[key] = true
		else:
			isolated[key] = true
	var connectors: Array[Dictionary] = []
	var seen_pairs: Dictionary = {}
	for raw_key: Variant in connected.keys():
		var key := StringName(raw_key)
		for raw_neighbour: Variant in adjacency.get(key, []):
			var neighbour := StringName(raw_neighbour)
			if not connected.has(neighbour):
				continue
			var pair: Array[String] = [String(key), String(neighbour)]
			pair.sort()
			var pair_key := StringName("%s|%s" % [pair[0], pair[1]])
			if seen_pairs.has(pair_key):
				continue
			seen_pairs[pair_key] = true
			connectors.append({"a": key, "b": neighbour})
	snapshot["connectors"] = connectors
	snapshot["connected_to_heart"] = from_heart
	snapshot["connected_to_access"] = from_access
	# Backward-compatible alias for presentation code and older tests.
	snapshot["connected_to_entrance"] = from_access
	snapshot["connected"] = connected
	snapshot["isolated"] = isolated
	snapshot["accessible_plot_count"] = accessible.size()
	snapshot["connected_plot_count"] = connected.size()
	return snapshot


func validate_state(
	definition: StrongholdDefinitionScript,
	state: StrongholdStateScript
) -> Array[String]:
	var errors: Array[String] = []
	if definition == null:
		return ["Stronghold definition is missing."]
	if state == null:
		return ["Campaign stronghold state is missing."]
	if state.definition_id != definition.id:
		errors.append(
			"Campaign stronghold uses %s but the authored definition is %s."
			% [state.definition_id, definition.id]
		)
	if state.definition_layout_version != definition.layout_version:
		errors.append(
			"Campaign stronghold uses layout version %d but the authored definition is version %d."
			% [state.definition_layout_version, definition.layout_version]
		)
	if state.plots_by_key.size() != definition.plots_by_key.size():
		errors.append(
			"Campaign stronghold has %d plots; expected %d."
			% [state.plots_by_key.size(), definition.plots_by_key.size()]
		)
	for definition_plot: StrongholdPlotDefinitionScript in definition.all_plots():
		var plot_state: StrongholdPlotStateScript = state.get_plot(definition_plot.coord)
		if plot_state == null:
			errors.append("Campaign stronghold is missing plot %s." % definition_plot.key())
			continue
		if definition_plot.authored_state in [StrongholdPlotDefinitionScript.FIXED_HEART, StrongholdPlotDefinitionScript.PERMANENT_BLOCK] and plot_state.current_state != definition_plot.authored_state:
			errors.append(
				"Fixed stronghold plot %s changed from %s to %s."
				% [definition_plot.key(), definition_plot.authored_state, plot_state.current_state]
			)
	var snapshot: Dictionary = build_snapshot(definition, state)
	if int(snapshot.get("connected_plot_count", 0)) != int(snapshot.get("accessible_plot_count", 0)):
		errors.append("The accessible stronghold network is not fully connected to both the Heart and Stables access anchor.")
	return errors


func _reachable(adjacency: Dictionary, starts: Array[StringName]) -> Dictionary:
	var reached: Dictionary = {}
	var queue: Array[StringName] = []
	for start: StringName in starts:
		if adjacency.has(start) and not reached.has(start):
			reached[start] = true
			queue.append(start)
	var index: int = 0
	while index < queue.size():
		var current: StringName = queue[index]
		index += 1
		for raw_neighbour: Variant in adjacency.get(current, []):
			var neighbour := StringName(raw_neighbour)
			if reached.has(neighbour):
				continue
			reached[neighbour] = true
			queue.append(neighbour)
	return reached
