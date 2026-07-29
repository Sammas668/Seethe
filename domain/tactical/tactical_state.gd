class_name TacticalState
extends RefCounted

var phase_state: TacticalPhaseState = TacticalPhaseState.new()
var units_by_id: Dictionary = {}
var items_by_id: Dictionary = {}
var unit_id_by_cell: Dictionary = {}
var ground_item_ids_by_cell: Dictionary = {}
var revision: int = 0


func add_unit(
		unit_state: TacticalUnitState,
		map_definition: TacticalMapDefinition = null,
		increment_revision: bool = true
) -> bool:
	if unit_state == null or unit_state.unit_id.is_empty():
		return false
	if units_by_id.has(unit_state.unit_id):
		return false
	if not can_place_unit(
		unit_state,
		unit_state.grid_position,
		map_definition,
		unit_state.unit_id
	):
		return false

	units_by_id[unit_state.unit_id] = unit_state
	var occupancy_errors := rebuild_unit_occupancy()
	if not occupancy_errors.is_empty():
		units_by_id.erase(unit_state.unit_id)
		rebuild_unit_occupancy()
		return false

	if increment_revision:
		revision += 1
	return true


func remove_unit(
		unit_id: StringName,
		increment_revision: bool = true
) -> bool:
	if not units_by_id.has(unit_id):
		return false
	units_by_id.erase(unit_id)
	rebuild_unit_occupancy()
	if increment_revision:
		revision += 1
	return true


func get_unit(unit_id: StringName) -> TacticalUnitState:
	return units_by_id.get(unit_id) as TacticalUnitState


func get_units() -> Array[TacticalUnitState]:
	var result: Array[TacticalUnitState] = []
	for value: Variant in units_by_id.values():
		var unit := value as TacticalUnitState
		if unit != null:
			result.append(unit)
	result.sort_custom(func(a: TacticalUnitState, b: TacticalUnitState) -> bool:
		return String(a.unit_id) < String(b.unit_id)
	)
	return result


func get_player_units() -> Array[TacticalUnitState]:
	var result: Array[TacticalUnitState] = []
	for unit: TacticalUnitState in get_units():
		if unit.team_id == &"player":
			result.append(unit)
	return result


func get_enemy_units() -> Array[TacticalUnitState]:
	var result: Array[TacticalUnitState] = []
	for unit: TacticalUnitState in get_units():
		if unit.team_id == &"enemy":
			result.append(unit)
	return result


func get_enemy_turn_units() -> Array[TacticalUnitState]:
	var result: Array[TacticalUnitState] = []
	for unit: TacticalUnitState in get_enemy_units():
		if unit.should_receive_enemy_turn():
			result.append(unit)
	return result


func occupied_cells_for_unit(
		unit: TacticalUnitState
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null:
		return result
	return occupied_cells_for_unit_at(unit, unit.grid_position)


func occupied_cells_for_unit_at(
		unit: TacticalUnitState,
		origin: Vector2i
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null:
		return result
	if unit.footprint.x <= 0 or unit.footprint.y <= 0:
		return result

	for y: int in range(unit.footprint.y):
		for x: int in range(unit.footprint.x):
			result.append(origin + Vector2i(x, y))
	return result


func can_place_unit(
		unit: TacticalUnitState,
		destination: Vector2i,
		map_definition: TacticalMapDefinition = null,
		except_unit_id: StringName = &""
) -> bool:
	if unit == null:
		return false
	if unit.footprint.x <= 0 or unit.footprint.y <= 0:
		return false

	for cell: Vector2i in occupied_cells_for_unit_at(unit, destination):
		if map_definition != null:
			if not map_definition.is_inside(cell):
				return false
			if map_definition.is_blocked(cell):
				return false
		var occupying_id := StringName(unit_id_by_cell.get(cell, &""))
		if not occupying_id.is_empty() and occupying_id != except_unit_id:
			return false
	return true


func rebuild_unit_occupancy() -> Array[String]:
	var errors: Array[String] = []
	unit_id_by_cell.clear()

	for unit: TacticalUnitState in get_units():
		for cell: Vector2i in occupied_cells_for_unit(unit):
			if unit_id_by_cell.has(cell):
				errors.append(
					"Units %s and %s overlap at %s."
					% [unit_id_by_cell[cell], unit.unit_id, cell]
				)
				continue
			unit_id_by_cell[cell] = unit.unit_id

	return errors


func set_unit_position(
		unit_id: StringName,
		destination: Vector2i,
		map_definition: TacticalMapDefinition = null,
		increment_revision: bool = true
) -> bool:
	var unit := get_unit(unit_id)
	if unit == null:
		return false
	if not can_place_unit(unit, destination, map_definition, unit_id):
		return false

	var previous_position := unit.grid_position
	unit.grid_position = destination
	var occupancy_errors := rebuild_unit_occupancy()
	if not occupancy_errors.is_empty():
		unit.grid_position = previous_position
		rebuild_unit_occupancy()
		return false

	if increment_revision:
		revision += 1
	return true


func get_unit_at_tile(
		tile: Vector2i,
		except_unit_id: StringName = &""
) -> TacticalUnitState:
	var unit_id := StringName(unit_id_by_cell.get(tile, &""))
	if unit_id.is_empty() or unit_id == except_unit_id:
		return null
	return get_unit(unit_id)


func add_item(
		item_state: TacticalItemInstanceState,
		map_definition: TacticalMapDefinition = null,
		increment_revision: bool = true
) -> bool:
	if item_state == null or item_state.item_id.is_empty():
		return false
	if items_by_id.has(item_state.item_id):
		return false
	if item_state.definition == null or item_state.definition_id.is_empty():
		return false

	items_by_id[item_state.item_id] = item_state
	rebuild_ground_item_index()
	var errors := validate_item_invariants(map_definition)
	if not errors.is_empty():
		items_by_id.erase(item_state.item_id)
		rebuild_ground_item_index()
		return false

	if increment_revision:
		revision += 1
	return true


func remove_item(
		item_id: StringName,
		increment_revision: bool = true
) -> bool:
	if not items_by_id.has(item_id):
		return false
	items_by_id.erase(item_id)
	rebuild_ground_item_index()
	if increment_revision:
		revision += 1
	return true


func get_item(item_id: StringName) -> TacticalItemInstanceState:
	return items_by_id.get(item_id) as TacticalItemInstanceState


func get_items() -> Array[TacticalItemInstanceState]:
	var result: Array[TacticalItemInstanceState] = []
	for value: Variant in items_by_id.values():
		var item := value as TacticalItemInstanceState
		if item != null:
			result.append(item)
	result.sort_custom(func(a: TacticalItemInstanceState, b: TacticalItemInstanceState) -> bool:
		return String(a.item_id) < String(b.item_id)
	)
	return result


func move_item(
		item_id: StringName,
		target_location: TacticalItemLocationState,
		increment_revision: bool = true
) -> bool:
	var item := get_item(item_id)
	if item == null or target_location == null:
		return false
	item.location = target_location.clone()
	rebuild_ground_item_index()
	if increment_revision:
		revision += 1
	return true


func rebuild_ground_item_index() -> void:
	ground_item_ids_by_cell.clear()
	for item: TacticalItemInstanceState in get_items():
		if item.location == null:
			continue
		if item.location.location_type != TacticalItemLocationState.LOCATION_TACTICAL_GROUND:
			continue
		var cell := item.location.map_position
		var ids: Array[StringName] = []
		var existing_values: Array = ground_item_ids_by_cell.get(cell, [])
		for existing_value: Variant in existing_values:
			ids.append(StringName(existing_value))
		ids.append(item.item_id)
		ground_item_ids_by_cell[cell] = ids


func get_ground_items() -> Array[TacticalItemInstanceState]:
	var result: Array[TacticalItemInstanceState] = []
	for item: TacticalItemInstanceState in get_items():
		if (
			item.location != null
			and item.location.location_type
			== TacticalItemLocationState.LOCATION_TACTICAL_GROUND
		):
			result.append(item)
	return result


func get_accessible_ground_items(
		unit: TacticalUnitState
) -> Array[TacticalItemInstanceState]:
	var result: Array[TacticalItemInstanceState] = []
	if unit == null:
		return result

	for y: int in range(
		unit.grid_position.y - 1,
		unit.grid_position.y + unit.footprint.y + 1
	):
		for x: int in range(
			unit.grid_position.x - 1,
			unit.grid_position.x + unit.footprint.x + 1
		):
			var cell := Vector2i(x, y)
			var indexed_values: Array = ground_item_ids_by_cell.get(cell, [])
			for indexed_value: Variant in indexed_values:
				var item := get_item(StringName(indexed_value))
				if item != null:
					result.append(item)

	result.sort_custom(func(a: TacticalItemInstanceState, b: TacticalItemInstanceState) -> bool:
		if a.source_label == b.source_label:
			return a.display_name < b.display_name
		return a.source_label < b.source_label
	)
	return result


func item_is_accessible_to_unit(
		item: TacticalItemInstanceState,
		unit: TacticalUnitState
) -> bool:
	if item == null or unit == null or item.location == null:
		return false
	if item.location.location_type != TacticalItemLocationState.LOCATION_TACTICAL_GROUND:
		return false

	var minimum := unit.grid_position - Vector2i.ONE
	var maximum := unit.grid_position + unit.footprint
	var position := item.location.map_position
	return (
		position.x >= minimum.x
		and position.y >= minimum.y
		and position.x <= maximum.x
		and position.y <= maximum.y
	)


func get_unit_container_items(
		unit_id: StringName,
		container_kind: StringName
) -> Array[TacticalItemInstanceState]:
	var result: Array[TacticalItemInstanceState] = []
	for item: TacticalItemInstanceState in get_items():
		if item.location == null:
			continue
		if item.location.owner_id != unit_id:
			continue
		if item.location.container_kind != container_kind:
			continue
		if item.location.location_type not in [
			TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
			TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
		]:
			continue
		result.append(item)

	result.sort_custom(func(a: TacticalItemInstanceState, b: TacticalItemInstanceState) -> bool:
		if a.location.grid_position.y == b.location.grid_position.y:
			if a.location.grid_position.x == b.location.grid_position.x:
				return String(a.item_id) < String(b.item_id)
			return a.location.grid_position.x < b.location.grid_position.x
		return a.location.grid_position.y < b.location.grid_position.y
	)
	return result


func get_hand_item(
		unit_id: StringName,
		hand_kind: StringName
) -> TacticalItemInstanceState:
	var items := get_unit_container_items(unit_id, hand_kind)
	return items[0] if not items.is_empty() else null


func calculated_carried_weight(unit_id: StringName) -> float:
	var total := 0.0
	for item: TacticalItemInstanceState in get_items():
		if item.location == null or item.location.owner_id != unit_id:
			continue
		if item.location.location_type in [
			TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
			TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
		]:
			total += item.weight_lb
	return total


func hand_display_name(unit_id: StringName, hand_kind: StringName) -> String:
	var primary := get_hand_item(
		unit_id,
		TacticalInventoryState.KIND_PRIMARY_HAND
	)
	if (
		hand_kind == TacticalInventoryState.KIND_SECONDARY_HAND
		and primary != null
		and primary.two_handed
	):
		return "Reserved by %s" % primary.display_name

	var item := get_hand_item(unit_id, hand_kind)
	return item.display_name if item != null else "Empty"


func container_summary(unit_id: StringName, container_kind: StringName) -> String:
	var items := get_unit_container_items(unit_id, container_kind)
	if items.is_empty():
		return "Empty"
	var names: Array[String] = []
	for item: TacticalItemInstanceState in items:
		names.append(item.compact_display_name())
	return ", ".join(PackedStringArray(names))


func granted_action_ids_for_unit(unit_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var seen: Dictionary = {}
	var unit := get_unit(unit_id)
	if unit == null:
		return result

	for action_id: StringName in unit.resolved_character.innate_action_ids:
		if not seen.has(action_id):
			seen[action_id] = true
			result.append(action_id)

	for hand_kind: StringName in [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
	]:
		var item := get_hand_item(unit_id, hand_kind)
		if item == null or item.definition == null:
			continue
		for action_id: StringName in item.definition.granted_action_ids:
			if not seen.has(action_id):
				seen[action_id] = true
				result.append(action_id)

	return result


func can_place_item(
		unit: TacticalUnitState,
		item: TacticalItemInstanceState,
		container_kind: StringName,
		position: Vector2i,
		ignore_item_id: StringName = &""
) -> bool:
	if unit == null or item == null:
		return false
	if container_kind == TacticalInventoryState.KIND_BELT and not item.belt_allowed:
		return false
	if container_kind == TacticalInventoryState.KIND_BACKPACK and not item.backpack_allowed:
		return false
	if container_kind not in [
		TacticalInventoryState.KIND_BELT,
		TacticalInventoryState.KIND_BACKPACK,
	]:
		return false

	var width := unit.inventory.container_width(container_kind)
	var height := unit.inventory.container_height(container_kind)
	if position.x < 0 or position.y < 0:
		return false
	if position.x + item.footprint.x > width:
		return false
	if position.y + item.footprint.y > height:
		return false

	var proposed := Rect2i(position, item.footprint)
	for other: TacticalItemInstanceState in get_unit_container_items(
		unit.unit_id,
		container_kind
	):
		if other.item_id == ignore_item_id:
			continue
		var occupied := Rect2i(other.location.grid_position, other.footprint)
		if proposed.intersects(occupied):
			return false
	return true


func first_fit(
		unit: TacticalUnitState,
		item: TacticalItemInstanceState,
		container_kind: StringName,
		ignore_item_id: StringName = &""
) -> Vector2i:
	if unit == null or item == null:
		return Vector2i(-1, -1)
	var width := unit.inventory.container_width(container_kind)
	var height := unit.inventory.container_height(container_kind)
	for y: int in range(height):
		for x: int in range(width):
			var candidate := Vector2i(x, y)
			if can_place_item(
				unit,
				item,
				container_kind,
				candidate,
				ignore_item_id
			):
				return candidate
	return Vector2i(-1, -1)


func validate_unit_invariants(
		map_definition: TacticalMapDefinition
) -> Array[String]:
	var errors: Array[String] = []
	var occupied: Dictionary = {}

	for key: Variant in units_by_id.keys():
		var unit_id := StringName(key)
		var unit := get_unit(unit_id)
		if unit == null:
			errors.append("Unit registry contains a null entry: %s" % unit_id)
			continue
		if unit.unit_id != unit_id:
			errors.append("Unit registry key does not match unit ID: %s" % unit_id)
		if unit.footprint.x <= 0 or unit.footprint.y <= 0:
			errors.append("Unit %s has a non-positive footprint." % unit_id)
			continue
		if unit.inventory == null:
			errors.append("Unit %s has no inventory state." % unit_id)
		if unit.action_budget == null:
			errors.append("Unit %s has no action budget." % unit_id)
		if unit.nonlethal_damage < 0:
			errors.append("Unit %s has negative nonlethal damage." % unit_id)
		if unit.combat_state not in [
			TacticalUnitState.COMBAT_STATE_ACTIVE,
			TacticalUnitState.COMBAT_STATE_DEFEATED,
		]:
			errors.append("Unit %s has an unknown combat state." % unit_id)
		if unit.current_hp <= 0 and not unit.is_defeated():
			errors.append("Unit %s has 0 HP but is not Defeated." % unit_id)
		if unit.current_hp > 0 and unit.combat_state == TacticalUnitState.COMBAT_STATE_DEFEATED:
			errors.append("Unit %s is Defeated while it still has HP." % unit_id)
		if unit.controller_type not in [
			TacticalUnitState.CONTROLLER_PLAYER,
			TacticalUnitState.CONTROLLER_AI,
			TacticalUnitState.CONTROLLER_WORLD,
		]:
			errors.append("Unit %s has an unknown controller type." % unit_id)
		if unit.turn_behavior not in [
			TacticalUnitState.TURN_BEHAVIOR_STANDARD,
			TacticalUnitState.TURN_BEHAVIOR_AUTO_PASS,
			TacticalUnitState.TURN_BEHAVIOR_NONE,
		]:
			errors.append("Unit %s has an unknown turn behaviour." % unit_id)
		if unit.is_player_controlled() and unit.team_id != &"player":
			errors.append("Unit %s is player-controlled but not on the player team." % unit_id)
		if unit.participates_in_enemy_turn and unit.team_id != &"enemy":
			errors.append("Unit %s receives Enemy Turns but is not on the enemy team." % unit_id)

		for cell: Vector2i in occupied_cells_for_unit(unit):
			if map_definition != null:
				if not map_definition.is_inside(cell):
					errors.append("Unit %s occupies out-of-bounds cell %s." % [unit_id, cell])
				elif map_definition.is_blocked(cell):
					errors.append("Unit %s occupies blocked cell %s." % [unit_id, cell])
			if occupied.has(cell):
				errors.append(
					"Units %s and %s overlap at %s."
					% [occupied[cell], unit_id, cell]
				)
			else:
				occupied[cell] = unit_id

	for cell: Variant in unit_id_by_cell.keys():
		var indexed_id := StringName(unit_id_by_cell[cell])
		if not occupied.has(cell):
			errors.append("Occupancy index contains stale cell %s." % cell)
		elif StringName(occupied[cell]) != indexed_id:
			errors.append("Occupancy index disagrees at cell %s." % cell)

	return errors


func validate_item_invariants(
		map_definition: TacticalMapDefinition = null
) -> Array[String]:
	var errors: Array[String] = []
	var occupied_by_unit_container: Dictionary = {}
	var valid_location_types := [
		TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
		TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
		TacticalItemLocationState.LOCATION_TACTICAL_GROUND,
		TacticalItemLocationState.LOCATION_TACTICAL_CONTAINER,
		TacticalItemLocationState.LOCATION_DESTROYED,
	]
	var valid_container_kinds := [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
		TacticalInventoryState.KIND_BELT,
		TacticalInventoryState.KIND_BACKPACK,
		TacticalItemLocationState.CONTAINER_GROUND,
	]

	for key: Variant in items_by_id.keys():
		var item_id := StringName(key)
		var item := get_item(item_id)
		if item == null:
			errors.append("Item registry contains a null entry: %s" % item_id)
			continue
		if item.item_id != item_id:
			errors.append("Item registry key does not match instance ID: %s" % item_id)
		if item.definition == null:
			errors.append("Item %s has no ItemDefinition." % item_id)
		else:
			if item.definition_id != item.definition.id:
				errors.append("Item %s has a mismatched definition ID." % item_id)
			if item.definition.id.is_empty():
				errors.append("Item %s uses a definition with an empty ID." % item_id)
			if item.quantity > 1 and not item.definition.stackable:
				errors.append("Non-stackable item %s has quantity %d." % [item_id, item.quantity])
			if item.quantity > item.definition.maximum_stack_size:
				errors.append(
					"Item %s exceeds maximum stack size %d."
					% [item_id, item.definition.maximum_stack_size]
				)
		if item.quantity < 1:
			errors.append("Item %s has an invalid quantity." % item_id)
		if item.condition < 0.0 or item.condition > 1.0:
			errors.append("Item %s has condition outside 0–1." % item_id)
		if item.location == null:
			errors.append("Item %s has no location." % item_id)
			continue

		var location := item.location
		if location.location_type not in valid_location_types:
			errors.append(
				"Item %s has unknown location type %s."
				% [item_id, location.location_type]
			)
			continue
		if (
			not location.container_kind.is_empty()
			and location.container_kind not in valid_container_kinds
			and location.location_type
			!= TacticalItemLocationState.LOCATION_TACTICAL_CONTAINER
		):
			errors.append(
				"Item %s has unknown container kind %s."
				% [item_id, location.container_kind]
			)

		match location.location_type:
			TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT:
				var owner := get_unit(location.owner_id)
				if location.owner_id.is_empty() or owner == null:
					errors.append("Equipment item %s references a missing owner." % item_id)
					continue
				if location.container_kind not in [
					TacticalInventoryState.KIND_PRIMARY_HAND,
					TacticalInventoryState.KIND_SECONDARY_HAND,
				]:
					errors.append("Item %s uses an invalid equipment container." % item_id)
				if item.definition != null and not item.definition.can_equip_in_hand():
					errors.append("Item %s cannot legally be equipped in a hand." % item_id)
				if item.quantity != 1:
					errors.append("Equipped item %s must have quantity 1." % item_id)
				if (
					location.container_kind
					== TacticalInventoryState.KIND_SECONDARY_HAND
					and item.two_handed
				):
					errors.append("Two-handed item %s is equipped in Secondary Hand." % item_id)

			TacticalItemLocationState.LOCATION_UNIT_INVENTORY:
				var inventory_owner := get_unit(location.owner_id)
				if location.owner_id.is_empty() or inventory_owner == null:
					errors.append("Inventory item %s references a missing owner." % item_id)
					continue
				if location.container_kind not in [
					TacticalInventoryState.KIND_BELT,
					TacticalInventoryState.KIND_BACKPACK,
				]:
					errors.append("Item %s uses an invalid inventory container." % item_id)
					continue
				if (
					location.container_kind == TacticalInventoryState.KIND_BELT
					and not item.belt_allowed
				):
					errors.append("Item %s is not allowed on the Belt." % item_id)
				if (
					location.container_kind == TacticalInventoryState.KIND_BACKPACK
					and not item.backpack_allowed
				):
					errors.append("Item %s is not allowed in the Backpack." % item_id)

				var width := inventory_owner.inventory.container_width(
					location.container_kind
				)
				var height := inventory_owner.inventory.container_height(
					location.container_kind
				)
				var rect := Rect2i(location.grid_position, item.footprint)
				var rect_end := rect.position + rect.size
				if rect.position.x < 0 or rect.position.y < 0:
					errors.append("Item %s has a negative grid position." % item_id)
				if rect_end.x > width or rect_end.y > height:
					errors.append("Item %s is outside its inventory grid." % item_id)
				for y: int in range(rect.position.y, rect_end.y):
					for x: int in range(rect.position.x, rect_end.x):
						var occupancy_key := "%s|%s|%d|%d" % [
							location.owner_id,
							location.container_kind,
							x,
							y,
						]
						if occupied_by_unit_container.has(occupancy_key):
							errors.append(
								"Items %s and %s overlap at %s."
								% [
									occupied_by_unit_container[occupancy_key],
									item_id,
									occupancy_key,
								]
							)
						else:
							occupied_by_unit_container[occupancy_key] = item_id

			TacticalItemLocationState.LOCATION_TACTICAL_GROUND:
				if not location.owner_id.is_empty():
					errors.append("Ground item %s still has an owner." % item_id)
				if location.container_kind != TacticalItemLocationState.CONTAINER_GROUND:
					errors.append("Ground item %s has an invalid container." % item_id)
				if map_definition != null and not map_definition.is_inside(location.map_position):
					errors.append("Ground item %s is outside the tactical map." % item_id)

			TacticalItemLocationState.LOCATION_TACTICAL_CONTAINER:
				if location.owner_id.is_empty():
					errors.append("Container item %s has no source object ID." % item_id)
				if location.container_kind.is_empty():
					errors.append("Container item %s has no container kind." % item_id)
				if map_definition != null and not map_definition.is_inside(location.map_position):
					errors.append("Container item %s is outside the tactical map." % item_id)

			TacticalItemLocationState.LOCATION_DESTROYED:
				if not location.owner_id.is_empty():
					errors.append("Destroyed item %s still has an owner." % item_id)
				if not location.container_kind.is_empty():
					errors.append("Destroyed item %s still has a container." % item_id)

	for unit: TacticalUnitState in get_units():
		var primary_items := get_unit_container_items(
			unit.unit_id,
			TacticalInventoryState.KIND_PRIMARY_HAND
		)
		var secondary_items := get_unit_container_items(
			unit.unit_id,
			TacticalInventoryState.KIND_SECONDARY_HAND
		)
		if primary_items.size() > 1:
			errors.append("%s has more than one Primary Hand item." % unit.display_name)
		if secondary_items.size() > 1:
			errors.append("%s has more than one Secondary Hand item." % unit.display_name)
		var primary := primary_items[0] if not primary_items.is_empty() else null
		var secondary := secondary_items[0] if not secondary_items.is_empty() else null
		if primary != null and primary.two_handed and secondary != null:
			errors.append(
				"%s has a two-handed Primary item and an occupied Secondary Hand."
				% unit.display_name
			)
		if calculated_carried_weight(unit.unit_id) > unit.inventory.maximum_weight_lb + 0.001:
			errors.append("%s exceeds its carrying limit." % unit.display_name)

	return errors


func validate_phase_invariants() -> Array[String]:
	var errors: Array[String] = []
	if phase_state == null:
		errors.append("Tactical state has no phase state.")
		return errors
	if phase_state.round_number < 1:
		errors.append("Tactical round number must be at least 1.")
	if phase_state.current_phase not in [
		TacticalPhaseState.PLAYER_PHASE,
		TacticalPhaseState.WORLD_PHASE,
	]:
		errors.append("Tactical state has an unknown phase.")
	return errors


func shallow_copy_for_assembly_validation() -> TacticalState:
	# This copy shares existing unit/item records and is safe only while mission
	# assembly validation adds new records without mutating existing ones.
	var result := TacticalState.new()
	result.phase_state = phase_state
	result.units_by_id = units_by_id.duplicate()
	result.items_by_id = items_by_id.duplicate()
	result.revision = revision
	result.rebuild_unit_occupancy()
	result.rebuild_ground_item_index()
	return result


func validate_all(
		map_definition: TacticalMapDefinition
) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(validate_unit_invariants(map_definition))
	errors.append_array(validate_item_invariants(map_definition))
	errors.append_array(validate_phase_invariants())
	return errors
