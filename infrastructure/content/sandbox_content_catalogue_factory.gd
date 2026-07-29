class_name SandboxContentCatalogueFactory
extends RefCounted

const ITEM_DEFINITIONS = [
	preload("res://content/items/training_axe.tres"),
	preload("res://content/items/training_shortbow.tres"),
	preload("res://content/items/shortbow_quiver.tres"),
	preload("res://content/items/training_spear.tres"),
	preload("res://content/items/dagger.tres"),
	preload("res://content/items/knife.tres"),
	preload("res://content/items/sling.tres"),
	preload("res://content/items/buckler.tres"),
	preload("res://content/items/bandage.tres"),
	preload("res://content/items/rope.tres"),
	preload("res://content/items/manacles.tres"),
	preload("res://content/items/rations.tres"),
	preload("res://content/items/smoke_pellet.tres"),
	preload("res://content/items/spare_arrows.tres"),
	preload("res://content/items/chalk.tres"),
	preload("res://content/items/lockpicks.tres"),
	preload("res://content/items/empty_sack.tres"),
	preload("res://content/items/grain_crate.tres"),
	preload("res://content/items/raiders_axe.tres"),
	preload("res://content/items/mace.tres"),
	preload("res://content/items/reaver_dagger.tres"),
]

const ACTION_DEFINITIONS = [
	preload("res://content/actions/training_axe_attack.tres"),
	preload("res://content/actions/training_shortbow_attack.tres"),
	preload("res://content/actions/training_spear_attack.tres"),
	preload("res://content/actions/dagger_attack.tres"),
	preload("res://content/actions/knife_attack.tres"),
	preload("res://content/actions/sling_attack.tres"),
	preload("res://content/actions/unarmed_strike.tres"),
	preload("res://content/actions/overwatch.tres"),
	preload("res://content/actions/use_bandage.tres"),
	preload("res://content/actions/use_smoke_pellet.tres"),
	preload("res://content/actions/raiders_axe_attack.tres"),
	preload("res://content/actions/mace_attack.tres"),
	preload("res://content/actions/reaver_dagger_attack.tres"),
	preload("res://content/actions/reaver_thrown_dagger_attack.tres"),
]

const DEFENCE_PROFILES = [
	preload("res://content/defences/hide_armour.tres"),
	preload("res://content/defences/leather_armour.tres"),
	preload("res://content/defences/light_armour.tres"),
	preload("res://content/defences/patchwork_raider_armour.tres"),
	preload("res://content/defences/practice_dummy.tres"),
]

const CHARACTER_TEMPLATES = [
	preload("res://content/characters/reaver/marauder_tier_1.tres"),
	preload("res://content/characters/prototypes/archer.tres"),
	preload("res://content/characters/prototypes/scout.tres"),
	preload("res://content/characters/prototypes/guard_enemy.tres"),
	preload("res://content/characters/prototypes/farmhand_neutral.tres"),
	preload("res://content/characters/prototypes/practice_dummy.tres"),
]

const CHARACTER_MODIFIERS = [
	preload("res://content/character_effects/rage.tres"),
]


static func create_catalogue() -> ContentCatalogue:
	var catalogue: ContentCatalogue = ContentCatalogue.new()
	var load_errors: Array[String] = GodotContentLoader.populate_catalogue(
		catalogue,
		ITEM_DEFINITIONS,
		ACTION_DEFINITIONS,
		DEFENCE_PROFILES,
		CHARACTER_TEMPLATES,
		CHARACTER_MODIFIERS
	)
	if not load_errors.is_empty():
		push_error("Sandbox content loading failed: %s" % load_errors[0])

	var validation_errors: Array[String] = catalogue.validate_catalogue()
	if not validation_errors.is_empty():
		push_error("Sandbox content catalogue invalid: %s" % validation_errors[0])

	catalogue.freeze()
	return catalogue
