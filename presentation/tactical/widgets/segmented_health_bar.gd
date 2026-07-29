extends Control

const DEFAULT_GREEN: Color = Color(0.16, 0.60, 0.31, 1.0)
const DEFAULT_RED: Color = Color(0.66, 0.13, 0.13, 1.0)
const DEFAULT_WHITE: Color = Color(0.92, 0.92, 0.88, 0.98)
const DEFAULT_BACKGROUND: Color = Color(0.025, 0.032, 0.04, 1.0)
const DEFAULT_BORDER: Color = Color(0.26, 0.31, 0.35, 1.0)

var _maximum_hp: int = 1
var _current_hp: int = 0
var _nonlethal_damage: int = 0

var _background: ColorRect
var _health_fill: ColorRect
var _lethal_fill: ColorRect
var _nonlethal_fill: ColorRect
var _border: Panel
var _value_label: Label
var _built: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(0.0, 18.0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true


func _ready() -> void:
	_ensure_built()
	_update_visuals()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		_layout_segments()


func set_values(
		current_hp: int,
		maximum_hp: int,
		nonlethal_damage: int = 0
) -> void:
	_maximum_hp = maxi(1, maximum_hp)
	_current_hp = clampi(current_hp, 0, _maximum_hp)
	_nonlethal_damage = maxi(0, nonlethal_damage)
	_ensure_built()
	_update_visuals()


func _ensure_built() -> void:
	if _built:
		return
	_built = true

	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = DEFAULT_BACKGROUND
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_health_fill = ColorRect.new()
	_health_fill.name = "HealthFill"
	_health_fill.color = DEFAULT_GREEN
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_fill)

	_lethal_fill = ColorRect.new()
	_lethal_fill.name = "LethalDamageFill"
	_lethal_fill.color = DEFAULT_RED
	_lethal_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lethal_fill)

	_nonlethal_fill = ColorRect.new()
	_nonlethal_fill.name = "NonlethalDamageFill"
	_nonlethal_fill.color = DEFAULT_WHITE
	_nonlethal_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_nonlethal_fill)

	_border = Panel.new()
	_border.name = "Border"
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border_style: StyleBoxFlat = StyleBoxFlat.new()
	border_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	border_style.border_width_left = 1
	border_style.border_width_top = 1
	border_style.border_width_right = 1
	border_style.border_width_bottom = 1
	border_style.border_color = DEFAULT_BORDER
	_border.add_theme_stylebox_override("panel", border_style)
	add_child(_border)

	_value_label = Label.new()
	_value_label.name = "ValueLabel"
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value_label.add_theme_font_size_override("font_size", 11)
	_value_label.add_theme_color_override("font_color", Color.WHITE)
	_value_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_value_label.add_theme_constant_override("outline_size", 3)
	add_child(_value_label)

	_layout_segments()


func _update_visuals() -> void:
	if not _built:
		return

	_value_label.text = "%d / %d" % [_current_hp, _maximum_hp]
	var lethal_damage: int = maxi(0, _maximum_hp - _current_hp)
	tooltip_text = (
		"Health: %d / %d\nLethal damage: %d\nNonlethal damage: %d"
		% [
			_current_hp,
			_maximum_hp,
			lethal_damage,
			_nonlethal_damage,
		]
	)
	_layout_segments()


func _layout_segments() -> void:
	if not _built:
		return

	var full_size: Vector2 = size
	_background.position = Vector2.ZERO
	_background.size = full_size
	_border.position = Vector2.ZERO
	_border.size = full_size
	_value_label.position = Vector2.ZERO
	_value_label.size = full_size

	var health_ratio: float = float(_current_hp) / float(_maximum_hp)
	var nonlethal_ratio: float = clampf(
		float(_nonlethal_damage) / float(_maximum_hp),
		0.0,
		1.0
	)
	var health_width: float = full_size.x * health_ratio
	var nonlethal_width: float = full_size.x * nonlethal_ratio

	# Green remains on the left. Red occupies lost HP on the right and therefore
	# advances right-to-left as lethal damage accumulates.
	_health_fill.position = Vector2.ZERO
	_health_fill.size = Vector2(health_width, full_size.y)
	_lethal_fill.position = Vector2(health_width, 0.0)
	_lethal_fill.size = Vector2(maxf(0.0, full_size.x - health_width), full_size.y)

	# White begins at the left edge and advances left-to-right as nonlethal
	# damage accumulates. Reaching the green/red boundary visually shows that
	# nonlethal damage has caught up with the unit's current HP.
	_nonlethal_fill.position = Vector2.ZERO
	_nonlethal_fill.size = Vector2(nonlethal_width, full_size.y)
