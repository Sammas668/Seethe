class_name TacticalPerceptionRules
extends RefCounted

const TacticalGridDistance: Script = preload(
	"res://domain/tactical/tactical_grid_distance.gd"
)
const TacticalLineOfSightRules: Script = preload(
	"res://domain/tactical/visibility/tactical_line_of_sight_rules.gd"
)

const BAND_CLOSE: StringName = &"close"
const BAND_NEAR: StringName = &"near"
const BAND_NORMAL: StringName = &"normal"
const BAND_FAR: StringName = &"far"
const BAND_OUTSIDE: StringName = &"outside"

const CLOSE_AWARENESS_TILES: int = TacticalGridDistance.CLOSE_AWARENESS_RADIUS_TILES
const BASE_FOCUSED_RANGE_TILES: int = TacticalGridDistance.UNAWARE_FOCUSED_RANGE_TILES
const AWARE_SIGHT_RADIUS_TILES: int = TacticalGridDistance.GENERAL_SIGHT_RADIUS_TILES
const CONE_DOT_THRESHOLD: float = 0.70710678


static func normalized_facing(direction: Vector2i) -> Vector2i:
	if direction == Vector2i.ZERO:
		return Vector2i(0, 1)
	return Vector2i(signi(direction.x), signi(direction.y))


static func passive_perception(observer: TacticalUnitState) -> int:
	if observer == null or observer.resolved_character == null:
		return 10
	return observer.resolved_character.stat_value(&"passive_perception", 10)


static func focused_range_tiles(_observer: TacticalUnitState) -> int:
	return BASE_FOCUSED_RANGE_TILES


static func aware_sight_radius_tiles() -> int:
	return AWARE_SIGHT_RADIUS_TILES


static func stealth_bonus(unit: TacticalUnitState) -> int:
	return unit.stealth_bonus() if unit != null else 0


static func initiative_modifier(unit: TacticalUnitState) -> int:
	if unit == null or unit.resolved_character == null:
		return 0
	return unit.resolved_character.stat_value(&"initiative", 0)


static func is_close_awareness(
		observer: TacticalUnitState,
		tile: Vector2i,
		map_definition: TacticalMapDefinition,
		tactical_state: TacticalState = null
) -> bool:
	if observer == null or map_definition == null:
		return false
	if not TacticalGridDistance.is_within_steps(
		observer.grid_position,
		tile,
		CLOSE_AWARENESS_TILES
	):
		return false
	return TacticalLineOfSightRules.has_line_of_sight(
		observer.grid_position, tile, map_definition, tactical_state
	)


static func is_in_focused_cone(
		observer: TacticalUnitState,
		tile: Vector2i,
		map_definition: TacticalMapDefinition,
		tactical_state: TacticalState = null
) -> bool:
	return is_in_focused_cone_with_facing(
		observer,
		tile,
		map_definition,
		observer.facing_direction if observer != null else Vector2i.ZERO,
		tactical_state
	)


static func is_in_focused_cone_with_facing(
		observer: TacticalUnitState,
		tile: Vector2i,
		map_definition: TacticalMapDefinition,
		facing_override: Vector2i,
		tactical_state: TacticalState = null
) -> bool:
	if observer == null or map_definition == null:
		return false
	var delta: Vector2i = tile - observer.grid_position
	if delta == Vector2i.ZERO:
		return true
	var distance: int = TacticalGridDistance.steps_between(
		observer.grid_position,
		tile
	)
	if distance > focused_range_tiles(observer):
		return false
	var facing: Vector2 = Vector2(normalized_facing(facing_override)).normalized()
	var direction: Vector2 = Vector2(delta).normalized()
	if facing.dot(direction) + 0.0001 < CONE_DOT_THRESHOLD:
		return false
	return TacticalLineOfSightRules.has_line_of_sight(
		observer.grid_position, tile, map_definition, tactical_state
	)


static func is_in_aware_radius(
		observer: TacticalUnitState,
		tile: Vector2i,
		map_definition: TacticalMapDefinition,
		tactical_state: TacticalState = null
) -> bool:
	if observer == null or map_definition == null:
		return false
	if not TacticalGridDistance.is_within_steps(
		observer.grid_position,
		tile,
		aware_sight_radius_tiles()
	):
		return false
	return TacticalLineOfSightRules.has_line_of_sight(
		observer.grid_position, tile, map_definition, tactical_state
	)


static func perception_band(
		observer: TacticalUnitState,
		tile: Vector2i
) -> StringName:
	if observer == null:
		return BAND_OUTSIDE
	var distance_tiles: int = TacticalGridDistance.steps_between(
		observer.grid_position,
		tile
	)
	if distance_tiles <= CLOSE_AWARENESS_TILES:
		return BAND_CLOSE
	var maximum: float = float(focused_range_tiles(observer))
	if distance_tiles <= maximum / 3.0:
		return BAND_NEAR
	if distance_tiles <= maximum * 2.0 / 3.0:
		return BAND_NORMAL
	if float(distance_tiles) <= maximum:
		return BAND_FAR
	return BAND_OUTSIDE


static func detection_dc(
		observer: TacticalUnitState,
		tile: Vector2i
) -> int:
	var result: int = passive_perception(observer)
	match perception_band(observer, tile):
		BAND_CLOSE:
			# Close awareness remains a normal opposed Stealth check. The +4
			# reflects how difficult it is to stay hidden within 5 feet without
			# turning proximity into automatic detection.
			result += 4
		BAND_NEAR:
			result += 2
		BAND_FAR:
			result -= 2
	return maxi(1, result)


static func avoid_detection_chance_percent(stealth_modifier: int, dc: int) -> int:
	var minimum_success_roll: int = dc - stealth_modifier
	var failed_faces: int = clampi(minimum_success_roll - 1, 0, 20)
	return 100 - failed_faces * 5


static func visible_tiles_for_observer(
		observer: TacticalUnitState,
		aware: bool,
		map_definition: TacticalMapDefinition,
		facing_override: Vector2i = Vector2i.ZERO,
		tactical_state: TacticalState = null
) -> Dictionary:
	var close_tiles: Array[Vector2i] = []
	var focused_tiles: Array[Vector2i] = []
	var aware_tiles: Array[Vector2i] = []
	var result: Dictionary = {
		"close": close_tiles,
		"focused": focused_tiles,
		"aware": aware_tiles,
	}
	if observer == null or map_definition == null:
		return result
	var radius: int = aware_sight_radius_tiles() if aware else focused_range_tiles(observer)
	var resolved_facing: Vector2i = (
		observer.facing_direction
		if facing_override == Vector2i.ZERO
		else facing_override
	)
	for y: int in range(observer.grid_position.y - radius, observer.grid_position.y + radius + 1):
		for x: int in range(observer.grid_position.x - radius, observer.grid_position.x + radius + 1):
			var tile := Vector2i(x, y)
			if not map_definition.is_inside(tile):
				continue
			if is_close_awareness(observer, tile, map_definition, tactical_state):
				close_tiles.append(tile)
				continue
			if is_in_focused_cone_with_facing(
				observer,
				tile,
				map_definition,
				resolved_facing,
				tactical_state
			):
				focused_tiles.append(tile)
				continue
			if aware and is_in_aware_radius(observer, tile, map_definition, tactical_state):
				aware_tiles.append(tile)
	return result
