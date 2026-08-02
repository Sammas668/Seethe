class_name TacticalUnitView
extends Node2D

signal movement_animation_finished(unit_id: StringName)
signal movement_reaction_presentation(event: Dictionary)

const STEALTH_HOOD_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/stealth_hood_icon.svg"
)
const UNCONSCIOUS_ZZZ_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/status_unconscious_zzz.svg"
)
const DYING_SKULL_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/status_dying_skull.svg"
)
const DEAD_SKULL_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/status_dead_skull.svg"
)

const COMMITTED_TURN_DURATION: float = 0.12
const PREVIEW_TURN_DURATION: float = 0.12
const CANCEL_TURN_DURATION: float = 0.10
const DAMAGE_REACTION_DURATION: float = 0.8
const DAMAGE_REACTION_SHAKE_PIXELS: float = 2.2
const DAMAGE_REACTION_CYCLES: float = 7.0
const ACTIVE_HANDOFF_PULSE_DURATION: float = 0.35
const ACTIVE_HANDOFF_PULSE_RADIUS: float = 4.0
const ATTACK_COMMAND_PULSE_DURATION: float = 0.18
const ATTACK_COMMAND_PULSE_RADIUS: float = 3.0

# Every token-state badge uses the same footprint so no condition visually
# overwhelms awareness or Stealth. The colourful inked artwork is scaled
# inside this common 14 px diameter frame.
const TOKEN_BADGE_RADIUS: float = 7.0
const TOKEN_BADGE_ICON_SIZE: float = 12.0
const TOKEN_BADGE_OUTLINE_WIDTH: float = 1.3
const DYING_TRACK_PIP_RADIUS: float = 1.15
const DYING_TRACK_PIP_HORIZONTAL_OFFSET: float = 9.2
const DYING_TRACK_PIP_VERTICAL_SPACING: float = 3.2
const DYING_SKULL_ART_SIZE: float = 11.5

const BADGE_KIND_NONE: StringName = &"none"
const BADGE_KIND_HIDDEN: StringName = &"hidden"
const BADGE_KIND_AWARE: StringName = &"aware"
const BADGE_KIND_UNCONSCIOUS: StringName = &"unconscious"
const BADGE_KIND_DYING: StringName = &"dying"
const BADGE_KIND_DEAD: StringName = &"dead"

@export var unit_color: Color = Color(0.15, 0.48, 0.92, 1.0)
@export var unit_radius: float = 11.0

var unit_id: StringName = &""
var _selected: bool = false
var _visibly_finished: bool = false
var _hidden_badge: bool = false
var _aware_badge: bool = false
var _life_state: StringName = TacticalUnitState.LIFE_STATE_NORMAL
var _restrained: bool = false
var _condition_badge_kind: StringName = TacticalStatusBadgeProvider.CONDITION_KIND_NONE
var _rage_rounds_remaining: int = 0
var _stable: bool = false
var _dying_successes: int = 0
var _dying_failures: int = 0
var _active_initiative: bool = false
var _cover_category: StringName = &""
var _team_id: StringName = &"neutral"
var _committed_facing_direction: Vector2i = Vector2i(0, 1)
var _preview_facing_active: bool = false
var _tile_size: float = 32.0
var _board_origin: Vector2 = Vector2.ZERO
var _movement_tween: Tween
var _facing_tween: Tween
var _damage_reaction_tween: Tween
var _active_handoff_pulse_tween: Tween
var _attack_command_pulse_tween: Tween
var _active_handoff_pulse_progress: float = 1.0:
	set(value):
		_active_handoff_pulse_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var _attack_command_pulse_progress: float = 1.0:
	set(value):
		_attack_command_pulse_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var _damage_reaction_progress: float = 1.0:
	set(value):
		_damage_reaction_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var _visual_facing_angle: float = PI * 0.5:
	set(value):
		_visual_facing_angle = value
		queue_redraw()


func configure(
		unit_state: TacticalUnitState,
		board_origin: Vector2,
		tile_size: float,
		display_color: Color
) -> void:
	unit_id = unit_state.unit_id
	unit_color = display_color
	_team_id = unit_state.team_id
	_committed_facing_direction = unit_state.facing_direction
	_visual_facing_angle = _direction_to_angle(_committed_facing_direction)
	_board_origin = board_origin
	_tile_size = tile_size
	position = _tile_to_world(unit_state.grid_position)
	_visibly_finished = unit_state.action_budget.is_visibly_finished()
	_hidden_badge = unit_state.shows_hidden_badge()
	set_status_badges(TacticalStatusBadgeProvider.for_unit(unit_state))
	queue_redraw()


func set_selected(selected: bool) -> void:
	_selected = selected
	queue_redraw()


func set_visibly_finished(finished: bool) -> void:
	_visibly_finished = finished
	queue_redraw()


func set_hidden_badge(visible: bool) -> void:
	_hidden_badge = visible
	queue_redraw()


func set_aware_badge(visible: bool) -> void:
	_aware_badge = visible
	queue_redraw()


func set_life_state(
		state_id: StringName,
		successes: int = 0,
		failures: int = 0
) -> void:
	_life_state = state_id
	_stable = state_id == TacticalUnitState.LIFE_STATE_STABLE_UNCONSCIOUS
	_dying_successes = clampi(successes, 0, 3)
	_dying_failures = clampi(failures, 0, 3)
	queue_redraw()


func set_restrained(value: bool) -> void:
	_restrained = value
	queue_redraw()


func set_status_badges(snapshot: Dictionary) -> void:
	_life_state = StringName(snapshot.get(
		"life_state",
		TacticalUnitState.LIFE_STATE_NORMAL
	))
	_dying_successes = clampi(int(snapshot.get("dying_successes", 0)), 0, 3)
	_dying_failures = clampi(int(snapshot.get("dying_failures", 0)), 0, 3)
	_stable = bool(snapshot.get("stable", false))
	_restrained = bool(snapshot.get("restrained", false))
	_condition_badge_kind = StringName(snapshot.get(
		"condition_kind", TacticalStatusBadgeProvider.CONDITION_KIND_NONE
	))
	_rage_rounds_remaining = int(snapshot.get("rage_rounds_remaining", 0))
	queue_redraw()


func set_active_initiative(active: bool) -> void:
	_active_initiative = active
	queue_redraw()




func play_active_handoff_pulse() -> void:
	# Presentation-only and non-blocking. A repeated handoff restarts the pulse
	# without changing initiative, selection, visibility or input ownership.
	if _active_handoff_pulse_tween != null and _active_handoff_pulse_tween.is_valid():
		_active_handoff_pulse_tween.kill()
	_active_handoff_pulse_progress = 0.0
	_active_handoff_pulse_tween = create_tween()
	_active_handoff_pulse_tween.set_trans(Tween.TRANS_SINE)
	_active_handoff_pulse_tween.set_ease(Tween.EASE_OUT)
	_active_handoff_pulse_tween.tween_property(
		self,
		"_active_handoff_pulse_progress",
		1.0,
		ACTIVE_HANDOFF_PULSE_DURATION
	)


func _active_handoff_pulse_strength() -> float:
	if _active_handoff_pulse_progress >= 1.0:
		return 0.0
	return sin(_active_handoff_pulse_progress * PI) * (
		1.0 - 0.25 * _active_handoff_pulse_progress
	)


func play_attack_command_pulse() -> void:
	# Immediate input acknowledgement only. It confirms that the attack command
	# was accepted but does not imply a hit and never blocks combat resolution.
	if _attack_command_pulse_tween != null and _attack_command_pulse_tween.is_valid():
		_attack_command_pulse_tween.kill()
	_attack_command_pulse_progress = 0.0
	_attack_command_pulse_tween = create_tween()
	_attack_command_pulse_tween.set_trans(Tween.TRANS_SINE)
	_attack_command_pulse_tween.set_ease(Tween.EASE_OUT)
	_attack_command_pulse_tween.tween_property(
		self,
		"_attack_command_pulse_progress",
		1.0,
		ATTACK_COMMAND_PULSE_DURATION
	)


func _attack_command_pulse_strength() -> float:
	if _attack_command_pulse_progress >= 1.0:
		return 0.0
	return sin(_attack_command_pulse_progress * PI) * (
		1.0 - 0.35 * _attack_command_pulse_progress
	)


func set_cover_category(category: StringName) -> void:
	if _cover_category == category:
		return
	_cover_category = category
	queue_redraw()


func set_facing(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	var direction_changed: bool = (
		direction != _committed_facing_direction
	)
	_committed_facing_direction = direction
	if direction_changed and not _preview_facing_active:
		_animate_visual_facing(direction, COMMITTED_TURN_DURATION)


func preview_facing(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	# Preview changes the cone and chevron through the board presentation only.
	# The counter remains at its committed orientation until the second click.
	_preview_facing_active = true


func cancel_facing_preview() -> void:
	if not _preview_facing_active:
		return
	# No return animation is required because preview never rotates the counter.
	_preview_facing_active = false


func commit_facing_preview(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		_preview_facing_active = false
		return
	_committed_facing_direction = direction
	_preview_facing_active = false
	# Confirmation is the only point at which a manual facing command animates.
	_animate_visual_facing(direction, COMMITTED_TURN_DURATION)


func clear_facing_preview_immediately() -> void:
	_preview_facing_active = false
	if _facing_tween != null and _facing_tween.is_valid():
		_facing_tween.kill()
	_visual_facing_angle = _direction_to_angle(
		_committed_facing_direction
	)


func snap_to_tile(tile: Vector2i) -> void:
	if is_movement_animating():
		# Stage 4.4e1: authoritative state may already be at the destination, but
		# presentation must not kill or snap an in-flight movement tween.
		return
	position = _tile_to_world(tile)


func is_movement_animating() -> bool:
	return _movement_tween != null and _movement_tween.is_valid()


func animate_path(
	path: Array[Vector2i],
	reaction_events: Array[Dictionary] = [],
	total_movement_duration: float = -1.0
) -> bool:
	if path.size() <= 1:
		return false

	if is_movement_animating():
		_movement_tween.kill()

	# State commits before presentation animates. Reset the counter to the
	# committed path origin so the visual never jumps from the destination
	# backwards through the route.
	position = _tile_to_world(path[0])
	_movement_tween = create_tween()
	var movement_steps: int = maxi(1, path.size() - 1)
	var step_duration: float = 0.08
	if total_movement_duration >= 0.0:
		step_duration = total_movement_duration / float(movement_steps)

	for index: int in range(1, path.size()):
		for reaction_event: Dictionary in reaction_events:
			if (
				int(reaction_event.get("path_index", -1)) == index
				and StringName(reaction_event.get("timing_kind", &""))
				== ReactionCandidate.TIMING_BEFORE_ENTRY
			):
				_movement_tween.tween_callback(
					_emit_movement_reaction_presentation.bind(reaction_event)
				)
				_movement_tween.tween_interval(0.10)
		var movement_step: PropertyTweener = _movement_tween.tween_property(
			self,
			"position",
			_tile_to_world(path[index]),
			step_duration
		)
		if index == path.size() - 1:
			# A slight final settle keeps the destination readable without making the
			# counter accelerate and decelerate at every tile boundary.
			movement_step.set_trans(Tween.TRANS_SINE)
			movement_step.set_ease(Tween.EASE_OUT)
		else:
			movement_step.set_trans(Tween.TRANS_LINEAR)
			movement_step.set_ease(Tween.EASE_IN_OUT)
		for reaction_event: Dictionary in reaction_events:
			if (
				int(reaction_event.get("path_index", -1)) == index
				and StringName(reaction_event.get("timing_kind", &""))
				== ReactionCandidate.TIMING_AFTER_ENTRY
			):
				_movement_tween.tween_callback(
					_emit_movement_reaction_presentation.bind(reaction_event)
				)
				_movement_tween.tween_interval(0.10)
	_movement_tween.finished.connect(_on_movement_tween_finished)
	return true


func _emit_movement_reaction_presentation(event: Dictionary) -> void:
	movement_reaction_presentation.emit(event.duplicate(true))


func _on_movement_tween_finished() -> void:
	_movement_tween = null
	movement_animation_finished.emit(unit_id)


func play_damage_reaction() -> void:
	# Presentation-only and fire-and-forget. Repeated hits restore the normal
	# baseline, kill the old tween and restart from full intensity.
	if _damage_reaction_tween != null and _damage_reaction_tween.is_valid():
		_damage_reaction_tween.kill()
	_damage_reaction_progress = 1.0
	_damage_reaction_progress = 0.0
	_damage_reaction_tween = create_tween()
	_damage_reaction_tween.set_trans(Tween.TRANS_SINE)
	_damage_reaction_tween.set_ease(Tween.EASE_OUT)
	_damage_reaction_tween.tween_property(
		self,
		"_damage_reaction_progress",
		1.0,
		DAMAGE_REACTION_DURATION
	)


func _damage_reaction_strength() -> float:
	if _damage_reaction_progress >= 1.0:
		return 0.0
	var fade: float = 1.0 - _damage_reaction_progress
	var pulse: float = 0.72 + 0.28 * abs(
		cos(_damage_reaction_progress * PI * 4.0)
	)
	return fade * pulse


func _damage_reaction_offset() -> Vector2:
	var strength: float = _damage_reaction_strength()
	if strength <= 0.0:
		return Vector2.ZERO
	var phase: float = (
		_damage_reaction_progress * TAU * DAMAGE_REACTION_CYCLES
	)
	return Vector2(
		sin(phase),
		cos(phase * 1.37)
	) * DAMAGE_REACTION_SHAKE_PIXELS * strength


func _animate_visual_facing(
		direction: Vector2i,
		duration: float
) -> void:
	var target_angle: float = _direction_to_angle(direction)
	var shortest_delta: float = wrapf(
		target_angle - _visual_facing_angle,
		-PI,
		PI
	)
	var unwrapped_target: float = _visual_facing_angle + shortest_delta
	if _facing_tween != null and _facing_tween.is_valid():
		_facing_tween.kill()
	if duration <= 0.0 or is_zero_approx(shortest_delta):
		_visual_facing_angle = unwrapped_target
		return
	_facing_tween = create_tween()
	_facing_tween.set_trans(Tween.TRANS_SINE)
	_facing_tween.set_ease(Tween.EASE_OUT)
	_facing_tween.tween_property(
		self,
		"_visual_facing_angle",
		unwrapped_target,
		duration
	)


func _direction_to_angle(direction: Vector2i) -> float:
	var vector: Vector2 = Vector2(direction).normalized()
	if vector == Vector2.ZERO:
		return PI * 0.5
	return atan2(vector.y, vector.x)


func _visual_facing_vector() -> Vector2:
	return Vector2(
		cos(_visual_facing_angle),
		sin(_visual_facing_angle)
	)


func _draw() -> void:
	var visible_color := unit_color
	if _life_state in [
		TacticalUnitState.LIFE_STATE_DYING,
		TacticalUnitState.LIFE_STATE_STABLE_UNCONSCIOUS,
		TacticalUnitState.LIFE_STATE_NONLETHAL_UNCONSCIOUS,
		TacticalUnitState.LIFE_STATE_DEAD,
	]:
		visible_color = Color(
			unit_color.r * 0.48,
			unit_color.g * 0.48,
			unit_color.b * 0.48,
			0.82
		)
	elif _visibly_finished:
		visible_color = Color(
			unit_color.r * 0.42,
			unit_color.g * 0.42,
			unit_color.b * 0.42,
			0.9
		)

	var reaction_strength: float = _damage_reaction_strength()
	if reaction_strength > 0.0:
		visible_color = visible_color.lerp(
			Color(1.0, 0.08, 0.06, visible_color.a),
			0.72 * reaction_strength
		)
	# Selection rings, initiative rings and all state badges remain fixed and readable.
	# Only token artwork uses this local drawing transform.
	draw_set_transform(
		_damage_reaction_offset(),
		0.0,
		Vector2.ONE
	)
	draw_circle(Vector2.ZERO, unit_radius, visible_color)
	draw_arc(
		Vector2.ZERO,
		unit_radius,
		0.0,
		TAU,
		32,
		Color(0.04, 0.08, 0.13, 1.0),
		2.0,
		true
	)

	var body_state_active: bool = _life_state in [
		TacticalUnitState.LIFE_STATE_DYING,
		TacticalUnitState.LIFE_STATE_STABLE_UNCONSCIOUS,
		TacticalUnitState.LIFE_STATE_NONLETHAL_UNCONSCIOUS,
		TacticalUnitState.LIFE_STATE_DEAD,
	]
	if not body_state_active:
		_draw_counter_front()
		_draw_facing_tick()

	if _visibly_finished and not body_state_active:
		draw_line(
			Vector2(-7.0, 7.0),
			Vector2(7.0, -7.0),
			Color(0.88, 0.88, 0.88, 0.9),
			2.0
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var attack_command_strength: float = _attack_command_pulse_strength()
	if attack_command_strength > 0.0:
		draw_arc(
			Vector2.ZERO,
			unit_radius + 4.0 + ATTACK_COMMAND_PULSE_RADIUS * attack_command_strength,
			0.0,
			TAU,
			40,
			Color(1.0, 0.86, 0.34, 0.9 - 0.35 * attack_command_strength),
			2.0 + 1.4 * attack_command_strength,
			true
		)

	if _active_initiative:
		var handoff_strength: float = _active_handoff_pulse_strength()
		draw_arc(
			Vector2.ZERO,
			unit_radius + 8.0 + ACTIVE_HANDOFF_PULSE_RADIUS * handoff_strength,
			0.0,
			TAU,
			48,
			Color(1.0, 0.32, 0.12, 1.0 - 0.28 * handoff_strength),
			3.0 + 1.2 * handoff_strength,
			true
		)

	if _selected:
		draw_arc(
			Vector2.ZERO,
			unit_radius + 5.0,
			0.0,
			TAU,
			40,
			Color(1.0, 0.82, 0.22, 1.0),
			3.0,
			true
		)

	if not _cover_category.is_empty() and not body_state_active:
		_draw_cover_badge()

	# Body-state badges override awareness and stealth. Badges are drawn in local screen orientation
	# so the colourful inked emblems remain upright.
	match displayed_badge_kind():
		BADGE_KIND_DEAD:
			_draw_dead_badge()
		BADGE_KIND_DYING:
			_draw_dying_badge()
		BADGE_KIND_UNCONSCIOUS:
			_draw_unconscious_badge()
		BADGE_KIND_HIDDEN:
			_draw_mask_badge()
		BADGE_KIND_AWARE:
			_draw_eye_badge()
	if _restrained:
		_draw_restrained_badge()
	if displayed_badge_kind() not in [BADGE_KIND_DEAD, BADGE_KIND_DYING, BADGE_KIND_UNCONSCIOUS]:
		_draw_condition_badge()
	if _stable:
		_draw_stable_marker()


func _draw_cover_badge() -> void:
	# Stage 4.4e1 intentionally supports only two readable cover emblems.
	# TacticalCombatGeometryResult.COVER_TOTAL and &"neutral" remain recognised by the rules/UI contract, but
	# are not drawn as token shields; Total Cover is reported as Blocked in the
	# attack preview, while Exposed/no-threat states show no icon.
	if _cover_category not in [
		TacticalCombatGeometryResult.COVER_LIGHT,
		TacticalCombatGeometryResult.COVER_HEAVY,
	]:
		return
	var centre := Vector2(-unit_radius + 1.5, unit_radius - 1.5)
	var size: float = 5.5
	var background := Color(0.035, 0.045, 0.065, 0.94)
	var color := (
		Color(0.48, 0.90, 0.96, 0.95)
		if _cover_category == TacticalCombatGeometryResult.COVER_LIGHT
		else Color(0.26, 0.78, 0.92, 0.98)
	)
	draw_circle(centre, size + 1.7, background)
	var shield := PackedVector2Array([
		centre + Vector2(-size * 0.70, -size * 0.55),
		centre + Vector2(size * 0.70, -size * 0.55),
		centre + Vector2(size * 0.58, size * 0.30),
		centre + Vector2(0.0, size),
		centre + Vector2(-size * 0.58, size * 0.30),
	])
	var outline := PackedVector2Array([
		shield[0], shield[1], shield[2], shield[3], shield[4], shield[0]
	])
	if _cover_category == TacticalCombatGeometryResult.COVER_LIGHT:
		var fill := Color(color.r, color.g, color.b, 0.24)
		draw_colored_polygon(shield, fill)
		draw_polyline(outline, color, 1.25, true)
		# Mask the lower half so Light Cover reads as one unmistakable half shield.
		draw_rect(
			Rect2(centre + Vector2(-size, 0.0), Vector2(size * 2.0, size + 1.5)),
			background,
			true
		)
	else:
		draw_colored_polygon(shield, color)
		draw_polyline(outline, Color(0.94, 0.98, 1.0, 0.95), 0.8, true)


func displayed_badge_kind() -> StringName:
	var primary_kind: StringName = (
		TacticalStatusBadgeProvider.primary_kind_for_life_state(_life_state)
	)
	match primary_kind:
		TacticalStatusBadgeProvider.BADGE_KIND_DEAD:
			return BADGE_KIND_DEAD
		TacticalStatusBadgeProvider.BADGE_KIND_DYING:
			return BADGE_KIND_DYING
		TacticalStatusBadgeProvider.BADGE_KIND_UNCONSCIOUS:
			return BADGE_KIND_UNCONSCIOUS
	if _hidden_badge:
		return BADGE_KIND_HIDDEN
	# Awareness eyes communicate active enemy patrol combat only. Player
	# characters never show this badge because their engagement state is already
	# explicit through player control and the initiative HUD.
	if _aware_badge and _team_id == &"enemy":
		return BADGE_KIND_AWARE
	return BADGE_KIND_NONE


func _draw_counter_front() -> void:
	var direction: Vector2 = _visual_facing_vector()
	var side := Vector2(-direction.y, direction.x)
	var front: Vector2 = direction * (unit_radius - 1.5)
	var points := PackedVector2Array([
		front + direction * 2.5,
		front - direction * 3.0 + side * 4.0,
		front - direction * 3.0 - side * 4.0,
	])
	draw_colored_polygon(points, Color(0.96, 0.92, 0.75, 0.82))


func _draw_facing_tick() -> void:
	var direction: Vector2 = _visual_facing_vector()
	var start: Vector2 = direction * (unit_radius - 2.0)
	var finish: Vector2 = direction * (unit_radius + 5.0)
	draw_line(
		start,
		finish,
		Color(0.96, 0.92, 0.75, 0.95),
		2.0,
		true
	)


func _token_badge_centre() -> Vector2:
	return Vector2(unit_radius - 1.0, -unit_radius + 1.0)


func _draw_token_badge_backplate(
		centre: Vector2,
		background_color: Color,
		outline_color: Color
) -> void:
	draw_circle(centre, TOKEN_BADGE_RADIUS, background_color)
	draw_arc(
		centre,
		TOKEN_BADGE_RADIUS,
		0.0,
		TAU,
		24,
		outline_color,
		TOKEN_BADGE_OUTLINE_WIDTH,
		true
	)


func _draw_mask_badge() -> void:
	var centre: Vector2 = _token_badge_centre()
	_draw_token_badge_backplate(
		centre,
		Color(0.035, 0.045, 0.065, 0.98),
		Color(0.76, 0.84, 0.95, 1.0)
	)
	draw_texture_rect(
		STEALTH_HOOD_ICON,
		Rect2(
			centre - Vector2.ONE * (TOKEN_BADGE_ICON_SIZE * 0.5),
			Vector2.ONE * TOKEN_BADGE_ICON_SIZE
		),
		false
	)


func _draw_eye_badge() -> void:
	var centre: Vector2 = _token_badge_centre()
	_draw_token_badge_backplate(
		centre,
		Color(0.12, 0.035, 0.025, 0.98),
		Color(1.0, 0.57, 0.19, 1.0)
	)
	var eye_points := PackedVector2Array([
		centre + Vector2(-4.5, 0.0),
		centre + Vector2(0.0, -3.0),
		centre + Vector2(4.5, 0.0),
		centre + Vector2(0.0, 3.0),
	])
	draw_colored_polygon(eye_points, Color(1.0, 0.78, 0.32, 1.0))
	draw_circle(centre, 1.8, Color(0.18, 0.04, 0.02, 1.0))


func _draw_unconscious_badge() -> void:
	var centre: Vector2 = _token_badge_centre()
	_draw_token_badge_backplate(
		centre,
		Color(0.08, 0.075, 0.18, 0.98),
		Color(0.56, 0.70, 0.98, 1.0)
	)
	draw_texture_rect(
		UNCONSCIOUS_ZZZ_ICON,
		Rect2(
			centre - Vector2.ONE * (TOKEN_BADGE_ICON_SIZE * 0.5),
			Vector2.ONE * TOKEN_BADGE_ICON_SIZE
		),
		false
	)


func _draw_dying_badge() -> void:
	var centre: Vector2 = _token_badge_centre()
	_draw_token_badge_backplate(
		centre,
		Color(0.16, 0.025, 0.035, 0.98),
		Color(0.94, 0.28, 0.25, 1.0)
	)

	# The central skull now carries the same visual weight as the eye, hood and
	# ZZZ artwork. The three-step tracks sit just outside the common badge frame
	# so the colourful inked skull remains readable at tactical scale.
	var skull_size := Vector2.ONE * DYING_SKULL_ART_SIZE
	draw_texture_rect(
		DYING_SKULL_ICON,
		Rect2(centre - skull_size * 0.5, skull_size),
		false
	)
	for index: int in range(3):
		var y: float = (
			centre.y
			- DYING_TRACK_PIP_VERTICAL_SPACING
			+ float(index) * DYING_TRACK_PIP_VERTICAL_SPACING
		)
		_draw_track_pip(
			Vector2(
				centre.x - DYING_TRACK_PIP_HORIZONTAL_OFFSET,
				y
			),
			index < _dying_successes,
			Color(0.24, 0.78, 0.35, 1.0),
			Color(0.10, 0.24, 0.13, 1.0)
		)
		_draw_track_pip(
			Vector2(
				centre.x + DYING_TRACK_PIP_HORIZONTAL_OFFSET,
				y
			),
			index < _dying_failures,
			Color(0.92, 0.16, 0.19, 1.0),
			Color(0.38, 0.10, 0.12, 1.0)
		)


func _draw_dead_badge() -> void:
	var centre: Vector2 = _token_badge_centre()
	_draw_token_badge_backplate(
		centre,
		Color(0.075, 0.07, 0.08, 0.98),
		Color(0.62, 0.59, 0.58, 1.0)
	)
	draw_texture_rect(
		DEAD_SKULL_ICON,
		Rect2(
			centre - Vector2.ONE * (TOKEN_BADGE_ICON_SIZE * 0.5),
			Vector2.ONE * TOKEN_BADGE_ICON_SIZE
		),
		false
	)


func _condition_badge_centre() -> Vector2:
	return Vector2(-unit_radius + 1.0, -unit_radius + 1.0)


func _draw_condition_badge() -> void:
	if _condition_badge_kind == TacticalStatusBadgeProvider.CONDITION_KIND_NONE:
		return
	var centre: Vector2 = _condition_badge_centre()
	if _condition_badge_kind == TacticalStatusBadgeProvider.CONDITION_KIND_RAGE:
		_draw_token_badge_backplate(centre, Color(0.22, 0.025, 0.015, 0.98), Color(1.0, 0.34, 0.08, 1.0))
		var flame := PackedVector2Array([
			centre + Vector2(0.0, -4.8), centre + Vector2(3.2, -0.8),
			centre + Vector2(1.4, 4.5), centre + Vector2(-2.8, 2.3),
			centre + Vector2(-3.7, -1.2),
		])
		draw_colored_polygon(flame, Color(1.0, 0.38, 0.06, 1.0))
		draw_circle(centre + Vector2(0.2, 1.0), 1.7, Color(1.0, 0.86, 0.18, 1.0))
	else:
		_draw_token_badge_backplate(centre, Color(0.08, 0.09, 0.10, 0.98), Color(0.62, 0.68, 0.72, 1.0))
		draw_line(centre + Vector2(-3.5, -1.8), centre + Vector2(3.5, -1.8), Color(0.78, 0.82, 0.84, 1.0), 1.3, true)
		draw_line(centre + Vector2(-2.8, 1.2), centre + Vector2(2.8, 1.2), Color(0.58, 0.64, 0.68, 1.0), 1.3, true)
		draw_line(centre + Vector2(-1.8, 4.0), centre + Vector2(1.8, 4.0), Color(0.42, 0.48, 0.52, 1.0), 1.3, true)


func _draw_restrained_badge() -> void:
	var centre := Vector2(unit_radius - 1.0, unit_radius - 1.0)
	draw_circle(centre, 6.0, Color(0.13, 0.09, 0.04, 0.98))
	draw_arc(centre, 6.0, 0.0, TAU, 20, Color(0.86, 0.68, 0.28, 1.0), 1.5, true)
	# Two linked loops read as rope/manacles without replacing the life badge.
	draw_arc(centre + Vector2(-1.8, 0.0), 2.4, 0.0, TAU, 16, Color(0.94, 0.83, 0.48, 1.0), 1.2, true)
	draw_arc(centre + Vector2(1.8, 0.0), 2.4, 0.0, TAU, 16, Color(0.94, 0.83, 0.48, 1.0), 1.2, true)


func _draw_stable_marker() -> void:
	var centre := _token_badge_centre() + Vector2(-5.0, 5.0)
	var radius: float = 3.5
	draw_circle(centre, radius, Color(0.055, 0.17, 0.085, 0.99))
	draw_arc(
		centre,
		radius,
		0.0,
		TAU,
		16,
		Color(0.34, 0.88, 0.48, 1.0),
		1.0,
		true
	)
	draw_polyline(
		PackedVector2Array([
			centre + Vector2(-1.7, 0.0),
			centre + Vector2(-0.3, 1.3),
			centre + Vector2(1.9, -1.6),
		]),
		Color(0.72, 1.0, 0.76, 1.0),
		1.0,
		true
	)


func _draw_track_pip(
		centre: Vector2,
		filled: bool,
		fill_color: Color,
		empty_color: Color
) -> void:
	draw_circle(
		centre,
		DYING_TRACK_PIP_RADIUS,
		fill_color if filled else empty_color
	)
	draw_arc(
		centre,
		DYING_TRACK_PIP_RADIUS,
		0.0,
		TAU,
		10,
		Color(0.95, 0.88, 0.74, 0.9),
		0.55,
		true
	)


func _tile_to_world(tile: Vector2i) -> Vector2:
	return (
		_board_origin
		+ Vector2(tile) * _tile_size
		+ Vector2.ONE * (_tile_size * 0.5)
	)
