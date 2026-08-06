class_name CharacterResolutionService
extends RefCounted

const CHARACTER_RESOLVER_SCRIPT: Script = preload(
	"res://domain/characters/resolution/character_resolver.gd"
)
const RESOLVED_EQUIPMENT_INPUT_SCRIPT: Script = preload(
	"res://domain/characters/resolution/resolved_equipment_input.gd"
)

var _catalogue: ContentCatalogue
var _resolver: RefCounted


func _init() -> void:
	pass


func configure(
		catalogue: ContentCatalogue,
		resolver: RefCounted = null
) -> void:
	_catalogue = catalogue
	_resolver = (
		resolver
		if resolver != null
		else CHARACTER_RESOLVER_SCRIPT.new() as RefCounted
	)


func set_resolver_for_tests(resolver: RefCounted) -> void:
	if resolver != null:
		_resolver = resolver


func resolve_character(
		character: PersistentCharacterState,
		active_modifier_ids: Array[StringName] = [],
		item_states: Array = []
) -> ResolvedCharacterSnapshot:
	if character == null or _catalogue == null or _resolver == null:
		return ResolvedCharacterSnapshot.new()

	var template: CharacterTemplateDefinition = _catalogue.character_template(
		character.template_id
	)
	if template == null:
		return ResolvedCharacterSnapshot.new()

	var equipment_inputs: Array = _equipment_inputs(item_states)
	var defence_profile: DefenceProfile = _resolve_defence_profile(
		character,
		template,
		equipment_inputs
	)
	var active_modifiers: Array[CharacterModifierDefinition] = []
	for modifier_id: StringName in active_modifier_ids:
		var modifier: CharacterModifierDefinition = (
			_catalogue.character_modifier(modifier_id)
		)
		if modifier != null:
			active_modifiers.append(modifier)

	var resolved_value: Variant = _resolver.call(
		"resolve",
		character,
		template,
		defence_profile,
		equipment_inputs,
		active_modifiers
	)
	var resolved: ResolvedCharacterSnapshot = (
		resolved_value as ResolvedCharacterSnapshot
	)
	return resolved if resolved != null else ResolvedCharacterSnapshot.new()


func refresh_tactical_unit(
		unit: TacticalUnitState,
		character: PersistentCharacterState,
		tactical_items: Array[TacticalItemInstanceState] = []
) -> void:
	if unit == null or character == null:
		return
	var snapshot: ResolvedCharacterSnapshot = resolve_character(
		character,
		unit.active_character_modifier_ids,
		tactical_items
	)
	unit.configure_resolved_character(snapshot, true)


func _resolve_defence_profile(
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition,
		equipment_inputs: Array
) -> DefenceProfile:
	# Equipped armour items are authoritative. The persistent/template profile
	# remains only as a Stage 3 compatibility fallback until every old template
	# owns a real armour item.
	for equipment_value: Variant in equipment_inputs:
		var equipment: RefCounted = equipment_value as RefCounted
		if equipment == null or not bool(equipment.get("equipped")):
			continue
		var definition: ItemDefinition = equipment.get("definition") as ItemDefinition
		if definition == null or definition.defence_profile_id.is_empty():
			continue
		var equipped_profile: DefenceProfile = _catalogue.defence_profile(
			definition.defence_profile_id
		)
		if equipped_profile != null:
			return equipped_profile

	return _catalogue.defence_profile(
		character.effective_defence_profile_id(template)
	)


func _equipment_inputs(item_states: Array) -> Array:
	var result: Array = []
	for raw_item: Variant in item_states:
		var item_id: StringName = &""
		var definition_id: StringName = &""
		var location_type: StringName = &""
		var container_id: StringName = &""
		var quantity: int = 1
		var condition: float = 1.0
		var modifiers: Dictionary = {}
		var equipped: bool = false
		var carried: bool = false

		if raw_item is CampaignItemState:
			var campaign_item: CampaignItemState = raw_item as CampaignItemState
			item_id = campaign_item.item_id
			definition_id = campaign_item.definition_id
			quantity = campaign_item.quantity
			condition = campaign_item.condition
			modifiers = campaign_item.persistent_modifiers.duplicate(true)
			if campaign_item.location != null:
				location_type = campaign_item.location.location_type
				container_id = campaign_item.location.container_id
				equipped = (
					location_type
					== CampaignItemLocationState.LOCATION_CHARACTER_EQUIPMENT
				)
				carried = campaign_item.location.belongs_to_character(
					campaign_item.location.owner_id
				)
		elif raw_item is TacticalItemInstanceState:
			var tactical_item: TacticalItemInstanceState = (
				raw_item as TacticalItemInstanceState
			)
			item_id = tactical_item.item_id
			definition_id = tactical_item.definition_id
			quantity = tactical_item.quantity
			condition = tactical_item.condition
			modifiers = tactical_item.tactical_modifiers.duplicate(true)
			if tactical_item.location != null:
				location_type = tactical_item.location.location_type
				container_id = tactical_item.location.container_kind
				equipped = (
					location_type
					== TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT
				)
				carried = location_type in [
					TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
					TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
				]
		elif raw_item is Dictionary:
			var item_data: Dictionary = raw_item as Dictionary
			item_id = StringName(item_data.get("item_id", item_data.get("instance_id", &"")))
			definition_id = StringName(item_data.get("definition_id", &""))
			location_type = StringName(item_data.get("location_type", &""))
			container_id = StringName(item_data.get("container_id", item_data.get("container_kind", &"")))
			quantity = maxi(1, int(item_data.get("quantity", 1)))
			condition = clampf(float(item_data.get("condition", 1.0)), 0.0, 1.0)
			modifiers = (item_data.get("persistent_modifiers", {}) as Dictionary).duplicate(true)
			equipped = bool(item_data.get("equipped", false))
			carried = bool(item_data.get("carried", equipped))
		else:
			continue

		var definition: ItemDefinition = _catalogue.item_definition(definition_id)
		if definition == null or item_id.is_empty():
			continue
		if (
			raw_item is CampaignItemState
			and (
				definition.can_equip_in_slot(CampaignItemLocationState.CONTAINER_ARMOUR)
				or not definition.defence_profile_id.is_empty()
			)
		):
			condition = 1.0
		var equipment: RefCounted = RESOLVED_EQUIPMENT_INPUT_SCRIPT.new() as RefCounted
		equipment.call(
			"configure",
			item_id,
			definition,
			location_type,
			container_id,
			quantity,
			condition,
			modifiers,
			equipped,
			carried
		)
		result.append(equipment)
	return result


func _item_definitions(item_states: Array) -> Array[ItemDefinition]:
	# Historical compatibility helper retained for Stage 3.14 tests. Runtime
	# resolution uses full ResolvedEquipmentInput records instead.
	var result: Array[ItemDefinition] = []
	for equipment_value: Variant in _equipment_inputs(item_states):
		var equipment: RefCounted = equipment_value as RefCounted
		if equipment == null:
			continue
		var definition: ItemDefinition = equipment.get("definition") as ItemDefinition
		if definition != null:
			result.append(definition)
	return result
