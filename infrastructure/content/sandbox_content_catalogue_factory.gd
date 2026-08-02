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
	preload("res://content/items/minor_healing_potion.tres"),
	preload("res://content/items/rope.tres"),
	preload("res://content/items/manacles.tres"),
	preload("res://content/items/smoke_pellet.tres"),
	preload("res://content/items/spare_arrows.tres"),
	preload("res://content/items/chalk.tres"),
	preload("res://content/items/lockpicks.tres"),
	preload("res://content/items/empty_sack.tres"),
	preload("res://content/items/grain_crate.tres"),
	preload("res://content/items/grain_sack.tres"),
	preload("res://content/items/storehouse_table.tres"),
	preload("res://content/items/raiders_axe.tres"),
	preload("res://content/items/mace.tres"),
	preload("res://content/items/reaver_dagger.tres"),
	preload("res://content/items/patchwork_raider_armour_item.tres"),
	preload("res://content/items/marauder_keys.tres"),
	preload("res://content/items/raiders_sack.tres"),
	preload("res://content/items/rations.tres"),
	preload("res://content/items/reinforced_captive_carrying_belt.tres"),
	preload("res://content/items/sanctuary_capture_spear.tres"),
	preload("res://content/items/sanctuary_capture_bow.tres"),
	preload("res://content/items/sanctuary_blackjack.tres"),
	preload("res://content/items/padded_arrows.tres"),
	preload("res://content/items/guard_shield.tres"),
	preload("res://content/items/cradling_shield.tres"),
	preload("res://content/items/mercy_field_kit.tres"),
	preload("res://content/items/mercy_divine_focus.tres"),
	preload("res://content/items/broken_timber.tres"),
	preload("res://content/items/stone_rubble.tres"),
	preload("res://content/items/scrap_metal.tres"),
	preload("res://content/items/glass_shards.tres"),
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
	preload("res://content/actions/brace.tres"),
	preload("res://content/actions/use_bandage.tres"),
	preload("res://content/actions/use_smoke_pellet.tres"),
	preload("res://content/actions/raiders_axe_attack.tres"),
	preload("res://content/actions/mace_attack.tres"),
	preload("res://content/actions/reaver_dagger_attack.tres"),
	preload("res://content/actions/reaver_thrown_dagger_attack.tres"),
	preload("res://content/actions/capture_spear_attack.tres"),
	preload("res://content/actions/sanctuary_blackjack_attack.tres"),
	preload("res://content/actions/capture_bow_attack.tres"),
	preload("res://content/actions/grapple.tres"),
	preload("res://content/actions/trip.tres"),
	preload("res://content/actions/shove.tres"),
	preload("res://content/actions/restrain.tres"),
	preload("res://content/actions/first_aid.tres"),
	preload("res://content/actions/subdual_takedown.tres"),
	preload("res://content/actions/mercy_intercession.tres"),
	preload("res://content/actions/mercy/cure_light_wounds.tres"),
	preload("res://content/actions/mercy/cure_moderate_wounds.tres"),
	preload("res://content/actions/mercy/command_kneel.tres"),
	preload("res://content/actions/mercy/sanctuary.tres"),
	preload("res://content/actions/mercy/hold_person.tres"),
	preload("res://content/actions/mercy/mercys_rebuke.tres"),
	preload("res://content/actions/mercy/guidance.tres"),
	preload("res://content/actions/mercy/resistance.tres"),
	preload("res://content/actions/mercy/detect_poison.tres"),
	preload("res://content/actions/mercy/light.tres"),
]

const DEFENCE_PROFILES = [
	preload("res://content/defences/hide_armour.tres"),
	preload("res://content/defences/leather_armour.tres"),
	preload("res://content/defences/light_armour.tres"),
	preload("res://content/defences/patchwork_raider_armour.tres"),
	preload("res://content/defences/sanctuary_guard_armour.tres"),
	preload("res://content/defences/mercy_bearer_breastplate.tres"),
	preload("res://content/defences/practice_dummy.tres"),
]

const CHARACTER_TEMPLATES = [
	preload("res://content/characters/protagonist/provisional_scorned_champion.tres"),
	preload("res://content/characters/reaver/marauder_tier_1.tres"),
	preload("res://content/characters/life/farmhand.tres"),
	preload("res://content/characters/life/sanctuary_spear_guard.tres"),
	preload("res://content/characters/life/sanctuary_archer.tres"),
	preload("res://content/characters/life/mercy_bearer.tres"),
	preload("res://content/characters/prototypes/archer.tres"),
	preload("res://content/characters/prototypes/scout.tres"),
	preload("res://content/characters/prototypes/guard_enemy.tres"),
	preload("res://content/characters/prototypes/guard_archer_enemy.tres"),
	preload("res://content/characters/prototypes/farmhand_neutral.tres"),
	preload("res://content/characters/prototypes/practice_dummy.tres"),
]

const CHARACTER_MODIFIERS = [
	preload("res://content/character_effects/rage.tres"),
	preload("res://content/character_effects/fatigued.tres"),
]

const AI_PROFILES = [
	preload("res://content/ai_profiles/reaver_marauder_aggressive.tres"),
	preload("res://content/ai_profiles/civilian_farm_worker.tres"),
	preload("res://content/ai_profiles/life_sanctuary_spear_guard.tres"),
	preload("res://content/ai_profiles/life_sanctuary_archer.tres"),
	preload("res://content/ai_profiles/life_mercy_bearer.tres"),
]


static func create_catalogue() -> ContentCatalogue:
	var catalogue: ContentCatalogue = ContentCatalogue.new()
	var load_errors: Array[String] = GodotContentLoader.populate_catalogue(
		catalogue,
		ITEM_DEFINITIONS,
		ACTION_DEFINITIONS,
		DEFENCE_PROFILES,
		CHARACTER_TEMPLATES,
		CHARACTER_MODIFIERS,
		AI_PROFILES
	)
	if not load_errors.is_empty():
		push_error("Sandbox content loading failed: %s" % load_errors[0])

	var validation_errors: Array[String] = catalogue.validate_catalogue()
	if not validation_errors.is_empty():
		push_error("Sandbox content catalogue invalid: %s" % validation_errors[0])

	catalogue.freeze()
	return catalogue
