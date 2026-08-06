extends Button

const HEALTH_BAR_SCRIPT: Script = preload(
	"res://presentation/tactical/widgets/segmented_health_bar.gd"
)

var _name_label: Label
var _health_bar: Control
var _status_label: Label
var _built: bool = false


func _init() -> void:
	text = ""
	custom_minimum_size = Vector2(0.0, 94.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_ensure_built()


func refresh_unit(
		unit: TacticalUnitState,
		shortcut_number: int,
		player_phase: bool,
		selected: bool = false
) -> void:
	_ensure_built()
	if unit == null:
		visible = false
		return

	visible = true
	_name_label.text = "%d  %s" % [shortcut_number, unit.display_name]
	_health_bar.call(
		"set_values",
		unit.current_hp,
		unit.maximum_hp,
		unit.nonlethal_damage
	)

	var state_text: String = "READY"
	match unit.life_state_id():
		TacticalUnitState.LIFE_STATE_DEAD:
			state_text = "DEAD"
		TacticalUnitState.LIFE_STATE_DYING:
			state_text = "DYING %dS/%dF" % [
				unit.dying_successes,
				unit.dying_failures,
			]
		TacticalUnitState.LIFE_STATE_STABLE_UNCONSCIOUS:
			state_text = "STABLE"
		TacticalUnitState.LIFE_STATE_NONLETHAL_UNCONSCIOUS:
			state_text = "UNCONSCIOUS"
		TacticalUnitState.LIFE_STATE_DISABLED:
			state_text = "DISABLED"
		_:
			if unit.action_budget.ended_activation:
				state_text = "ENDED"
			elif not unit.action_budget.has_any_option_remaining():
				state_text = "SPENT"
			elif not unit.action_budget.ordinary_attack_available:
				state_text = "MOVE ONLY"

	_status_label.text = "%d / %d ft · %s" % [
		unit.action_budget.remaining_turn_capacity_feet,
		unit.action_budget.maximum_turn_capacity_feet,
		state_text,
	]
	disabled = not player_phase
	button_pressed = selected
	tooltip_text = (
		"%s\nHP %d / %d\nState: %s\n%s\nNonlethal damage %d\nCapacity %d / %d ft\nNormal attack: %s"
		% [
			unit.display_name,
			unit.current_hp,
			unit.maximum_hp,
			String(unit.life_state_id()).replace("_", " ").capitalize(),
			_life_state_detail(unit),
			unit.nonlethal_damage,
			unit.action_budget.remaining_turn_capacity_feet,
			unit.action_budget.maximum_turn_capacity_feet,
			"ready"
				if unit.action_budget.ordinary_attack_available
				else "spent",
		]
	)


func _life_state_detail(unit: TacticalUnitState) -> String:
	match unit.life_state_id():
		TacticalUnitState.LIFE_STATE_DYING:
			return "Fort %+d vs DC %d · %d/3 successes · %d/3 failures · death at %d HP" % [
				unit.fortitude_bonus(),
				unit.dying_check_dc(),
				unit.dying_successes,
				unit.dying_failures,
				unit.death_threshold_hp(),
			]
		TacticalUnitState.LIFE_STATE_STABLE_UNCONSCIOUS:
			return "Stable and unconscious; no Dying check."
		TacticalUnitState.LIFE_STATE_NONLETHAL_UNCONSCIOUS:
			return "Unconscious from nonlethal damage; not Dying."
		TacticalUnitState.LIFE_STATE_DISABLED:
			return "Half capacity, no Reaction; strenuous actions cost 1 HP."
		TacticalUnitState.LIFE_STATE_DEAD:
			return "Dead."
	return "Conscious."


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	toggle_mode = true

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "CardMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 7.0
	margin.offset_top = 5.0
	margin.offset_right = -7.0
	margin.offset_bottom = -5.0
	add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "CardColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)

	_name_label = Label.new()
	_name_label.name = "UnitName"
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.custom_minimum_size = Vector2(0.0, 28.0)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 15)
	column.add_child(_name_label)

	_health_bar = HEALTH_BAR_SCRIPT.new()
	_health_bar.name = "HealthBar"
	_health_bar.custom_minimum_size = Vector2(0.0, 18.0)
	_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_health_bar)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0.0, 22.0)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 12)
	column.add_child(_status_label)
