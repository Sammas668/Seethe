class_name Stage54AStorageShopTests
extends RefCounted

const TEST_SAVE_PATH: String = "user://stage_5_4a_storage_shop_tests.json"
const MARAUDER_ID: StringName = &"character.reaver.marauder.0001"
const RAIDERS_SACK_ID: StringName = &"item.raiders_sack"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_shop_buy_sell_and_save_round_trip(failures)
	_test_protected_and_reserved_items_are_blocked(failures)
	_test_general_storage_dismantling(failures)
	_test_textiles_storage_and_resource_sales(failures)
	_test_storage_location_views(failures)
	_test_raiders_sack_tier_fixture(failures)
	return failures


static func _test_shop_buy_sell_and_save_round_trip(
		failures: Array[String]
) -> void:
	var session := CampaignSession.new()
	session.configure(TEST_SAVE_PATH)
	session.repository.clear_save()
	var created: OperationResult = session.create_new_campaign(5401)
	_expect(created.success, "New campaign creation failed: %s" % created.message, failures)
	var campaign: CampaignState = session.current_campaign()
	if campaign == null:
		failures.append("Stage 5.4A created no CampaignState.")
		session.repository.clear_save()
		return

	var catalogue_entries: Array[Dictionary] = session.shop_buy_entries()
	_expect(not catalogue_entries.is_empty(), "The starting Shop catalogue is empty.", failures)
	var dagger_entry: Dictionary = {}
	for entry: Dictionary in catalogue_entries:
		if StringName(entry.get("definition_id", &"")) == &"item.dagger":
			dagger_entry = entry
			break
	_expect(not dagger_entry.is_empty(), "The starting Shop catalogue does not contain the Dagger.", failures)
	if dagger_entry.is_empty():
		session.repository.clear_save()
		return

	var gold_before: int = campaign.resources.amount(&"gold")
	var buy_preview: OperationResult = session.preview_shop_buy(&"item.dagger", 1)
	_expect(buy_preview.success, "The Dagger purchase preview failed: %s" % buy_preview.message, failures)
	var purchased: OperationResult = session.buy_shop_item(&"item.dagger", 1)
	_expect(purchased.success, "The Dagger purchase failed: %s" % purchased.message, failures)
	campaign = session.current_campaign()
	var buy_price: int = int(dagger_entry.get("buy_price_gold", 0))
	_expect(
		campaign.resources.amount(&"gold") == gold_before - buy_price,
		"Buying did not deduct the exact authored Gold price.",
		failures
	)
	var transactions: Array = campaign.get_shop_transactions()
	_expect(transactions.size() == 1, "Buying did not create exactly one Shop transaction.", failures)
	if transactions.is_empty():
		session.repository.clear_save()
		return
	var purchase_transaction = transactions[0]
	_expect(
		purchase_transaction.transaction_kind == ShopTransactionState.KIND_BUY,
		"The first Shop transaction was not a purchase.",
		failures
	)
	_expect(
		purchase_transaction.item_ids.size() == 1,
		"A one-item purchase did not record one stable item identity.",
		failures
	)
	if purchase_transaction.item_ids.is_empty():
		session.repository.clear_save()
		return
	var purchased_item_id: StringName = purchase_transaction.item_ids[0]
	var purchased_item: CampaignItemState = campaign.get_item(purchased_item_id) as CampaignItemState
	_expect(purchased_item != null, "The purchased exact item was not created.", failures)
	if purchased_item != null:
		_expect(
			purchased_item.location != null and purchased_item.location.is_stronghold_storage(),
			"The purchased item did not enter Stronghold Storage.",
			failures
		)

	var sell_preview: OperationResult = session.preview_shop_sell(purchased_item_id, 1)
	_expect(sell_preview.success, "The purchased Dagger could not be sold: %s" % sell_preview.message, failures)
	var sold: OperationResult = session.sell_shop_item(purchased_item_id, 1)
	_expect(sold.success, "Selling the exact Dagger failed: %s" % sold.message, failures)
	campaign = session.current_campaign()
	_expect(campaign.get_item(purchased_item_id) == null, "Selling did not remove the exact stored item.", failures)
	_expect(
		campaign.resources.amount(&"gold") <= gold_before,
		"Buying and immediately reselling generated a Gold profit.",
		failures
	)
	transactions = campaign.get_shop_transactions()
	_expect(transactions.size() == 2, "The sale did not create exactly one additional transaction.", failures)

	var restored := CampaignState.from_dictionary(campaign.to_dictionary())
	_expect(
		restored.get_shop_transactions().size() == campaign.get_shop_transactions().size(),
		"Save round-trip lost Shop transaction history.",
		failures
	)
	_expect(
		restored.resources.amount(&"gold") == campaign.resources.amount(&"gold"),
		"Save round-trip changed the Storage-owned Gold balance.",
		failures
	)
	session.repository.clear_save()


static func _test_protected_and_reserved_items_are_blocked(
		failures: Array[String]
) -> void:
	var session := CampaignSession.new()
	session.configure(TEST_SAVE_PATH)
	session.repository.clear_save()
	var created: OperationResult = session.create_new_campaign(5402)
	_expect(created.success, "Protected-item test campaign failed: %s" % created.message, failures)
	var bought: OperationResult = session.buy_shop_item(&"item.rope", 1)
	_expect(bought.success, "The Rope fixture could not be bought: %s" % bought.message, failures)
	var campaign: CampaignState = session.current_campaign()
	if campaign == null or campaign.get_shop_transactions().is_empty():
		failures.append("The Rope fixture created no Shop transaction.")
		session.repository.clear_save()
		return
	var rope_transaction = campaign.get_shop_transactions()[-1]
	var rope_id: StringName = rope_transaction.item_ids[0]
	var protected_result: OperationResult = session.set_item_protected(rope_id, true)
	_expect(protected_result.success, "The Rope could not be protected: %s" % protected_result.message, failures)
	var protected_preview: OperationResult = session.preview_shop_sell(rope_id, 1)
	_expect(
		not protected_preview.success and protected_preview.code == &"shop_item_protected",
		"A protected item remained sellable.",
		failures
	)
	var unprotected_result: OperationResult = session.set_item_protected(rope_id, false)
	_expect(unprotected_result.success, "The Rope could not be unprotected.", failures)
	campaign = session.current_campaign()
	var reservation := StrategicReservationState.new()
	reservation.reservation_id = &"reservation.stage_5_4a.rope"
	reservation.purpose = StrategicReservationState.PURPOSE_CONSTRUCTION_INPUT
	reservation.owner_id = &"project.stage_5_4a.fixture"
	reservation.display_name = "Fixture construction"
	reservation.created_tick = campaign.campaign_tick
	reservation.item_ids.append(rope_id)
	_expect(campaign.upsert_strategic_reservation(reservation), "The sale-lock reservation could not be created.", failures)
	var reserved_preview: OperationResult = session.preview_shop_sell(rope_id, 1)
	_expect(not reserved_preview.success, "A reserved exact item remained sellable.", failures)
	_expect(campaign.get_item(rope_id) != null, "Rejected sale removed the reserved item.", failures)
	session.repository.clear_save()


static func _test_general_storage_dismantling(
		failures: Array[String]
) -> void:
	var session := CampaignSession.new()
	session.configure(TEST_SAVE_PATH)
	session.repository.clear_save()
	var created: OperationResult = session.create_new_campaign(5403)
	_expect(created.success, "Dismantling test campaign failed: %s" % created.message, failures)
	var campaign: CampaignState = session.current_campaign()
	if campaign == null:
		failures.append("Dismantling test created no CampaignState.")
		session.repository.clear_save()
		return
	var grain_id: StringName = &"item.instance.stage_5_4a.grain_sack"
	var grain := CampaignItemState.new(
		grain_id,
		&"item.grain_sack",
		1,
		1.0,
		CampaignItemLocationState.stronghold_storage()
	)
	_expect(campaign.add_item(grain), "The Grain Sack fixture could not enter Storage.", failures)
	var protected_result: OperationResult = session.set_item_protected(grain_id, true)
	_expect(protected_result.success, "The Grain Sack could not be protected.", failures)
	var protected_preview: OperationResult = session.preview_dismantle_item(grain_id)
	_expect(not protected_preview.success, "A protected Grain Sack remained dismantlable.", failures)
	var unprotected_result: OperationResult = session.set_item_protected(grain_id, false)
	_expect(unprotected_result.success, "The Grain Sack could not be unprotected.", failures)
	campaign = session.current_campaign()
	var food_before: int = campaign.resources.amount(&"food")
	var textiles_before: int = campaign.resources.amount(&"textiles")
	var preview: OperationResult = session.preview_dismantle_item(grain_id)
	_expect(preview.success, "General Storage dismantling was unavailable: %s" % preview.message, failures)
	var dismantled: OperationResult = session.dismantle_item(grain_id)
	_expect(dismantled.success, "The Grain Sack did not dismantle: %s" % dismantled.message, failures)
	campaign = session.current_campaign()
	_expect(campaign.get_item(grain_id) == null, "Dismantling did not consume the exact Grain Sack.", failures)
	_expect(
		campaign.resources.amount(&"food") == food_before + 3,
		"Grain Sack dismantling did not add the authored Food yield.",
		failures
	)
	_expect(
		campaign.resources.amount(&"textiles") == textiles_before + 1,
		"Grain Sack dismantling did not reclaim the authored Textiles yield.",
		failures
	)
	var repeated: OperationResult = session.dismantle_item(grain_id)
	_expect(not repeated.success, "The same Grain Sack dismantled twice.", failures)
	_expect(
		campaign.resources.amount(&"food") == food_before + 3,
		"Repeated dismantling duplicated Food.",
		failures
	)
	_expect(
		campaign.resources.amount(&"textiles") == textiles_before + 1,
		"Repeated dismantling duplicated Textiles.",
		failures
	)
	session.repository.clear_save()


static func _test_textiles_storage_and_resource_sales(
		failures: Array[String]
) -> void:
	var session := CampaignSession.new()
	session.configure(TEST_SAVE_PATH)
	session.repository.clear_save()
	var created: OperationResult = session.create_new_campaign(5404)
	_expect(created.success, "Resource-sale test campaign failed: %s" % created.message, failures)
	var campaign: CampaignState = session.current_campaign()
	if campaign == null:
		failures.append("Resource-sale test created no CampaignState.")
		session.repository.clear_save()
		return

	campaign.resources.set_amount(&"textiles", 0)
	var zero_snapshot: Dictionary = session.storage_capacity_snapshot()
	campaign.resources.set_amount(&"textiles", 1)
	var one_snapshot: Dictionary = session.storage_capacity_snapshot()
	_expect(
		int(one_snapshot.get("resource_used", 0)) == int(zero_snapshot.get("resource_used", 0)) + 1,
		"The first stored Textile unit did not consume one Storage Space.",
		failures
	)
	campaign.resources.set_amount(&"textiles", 100)
	var hundred_snapshot: Dictionary = session.storage_capacity_snapshot()
	_expect(
		int(hundred_snapshot.get("resource_used", 0)) == int(one_snapshot.get("resource_used", 0)),
		"One hundred Textiles did not remain within one Storage Space.",
		failures
	)
	campaign.resources.set_amount(&"textiles", 101)
	var hundred_one_snapshot: Dictionary = session.storage_capacity_snapshot()
	_expect(
		int(hundred_one_snapshot.get("resource_used", 0)) == int(one_snapshot.get("resource_used", 0)) + 1,
		"The 101st Textile unit did not consume a second Storage Space.",
		failures
	)

	campaign.resources.set_amount(&"wood", 120)
	var gold_before: int = campaign.resources.amount(&"gold")
	var preview: OperationResult = session.preview_shop_sell_resource(&"wood", 2)
	_expect(preview.success, "Two Wood lots could not be previewed: %s" % preview.message, failures)
	var sold: OperationResult = session.sell_shop_resource(&"wood", 2)
	_expect(sold.success, "Two Wood lots could not be sold: %s" % sold.message, failures)
	campaign = session.current_campaign()
	_expect(campaign.resources.amount(&"wood") == 100, "Selling two Wood lots did not remove 20 Wood.", failures)
	_expect(campaign.resources.amount(&"gold") == gold_before + 4, "Selling 20 Wood did not grant 4 Gold.", failures)
	var transactions: Array = campaign.get_shop_transactions()
	_expect(not transactions.is_empty(), "Resource sale created no Shop transaction.", failures)
	if not transactions.is_empty():
		var transaction = transactions[-1]
		_expect(transaction.is_resource_transaction(), "Resource sale was recorded as an item transaction.", failures)
		_expect(transaction.resource_id == &"wood", "Resource sale recorded the wrong resource.", failures)
		_expect(transaction.resource_amount == 20, "Resource sale recorded the wrong amount.", failures)

	var gold_preview: OperationResult = session.preview_shop_sell_resource(&"gold", 1)
	_expect(not gold_preview.success, "Gold was incorrectly sellable for Gold.", failures)
	var restored := CampaignState.from_dictionary(campaign.to_dictionary())
	_expect(restored.resources.amount(&"textiles") == 101, "Save round-trip lost Textiles.", failures)
	_expect(restored.get_shop_transactions().size() == transactions.size(), "Save round-trip lost resource-sale history.", failures)
	session.repository.clear_save()


static func _test_storage_location_views(failures: Array[String]) -> void:
	var session := CampaignSession.new()
	session.configure(TEST_SAVE_PATH)
	session.repository.clear_save()
	var created: OperationResult = session.create_new_campaign(5405)
	_expect(created.success, "Storage-view test campaign failed: %s" % created.message, failures)
	if not created.success:
		return
	var stored_groups: Array[Dictionary] = session.storage_group_snapshots(
		&"all", &"all", "", &"name", &"storage"
	)
	var equipped_groups: Array[Dictionary] = session.storage_group_snapshots(
		&"all", &"all", "", &"name", &"equipped"
	)
	_expect(not stored_groups.is_empty(), "The In Storage view returned no stored items.", failures)
	_expect(not equipped_groups.is_empty(), "The Equipped & Carried view returned no carried items.", failures)
	for group: Dictionary in stored_groups:
		for raw_instance: Variant in group.get("visible_instances", []) as Array:
			if raw_instance is Dictionary:
				_expect(
					StringName((raw_instance as Dictionary).get("location_type", &""))
					== CampaignItemLocationState.LOCATION_STRONGHOLD_STORAGE,
					"The In Storage view included an equipped or carried item.",
					failures
				)
	for group: Dictionary in equipped_groups:
		for raw_instance: Variant in group.get("visible_instances", []) as Array:
			if raw_instance is Dictionary:
				_expect(
					StringName((raw_instance as Dictionary).get("location_type", &"")) in [
						CampaignItemLocationState.LOCATION_CHARACTER_EQUIPMENT,
						CampaignItemLocationState.LOCATION_CHARACTER_INVENTORY,
					],
					"The Equipped & Carried view included a Storage item.",
					failures
				)
	var sack_group: Dictionary = session.storage_group_snapshot(RAIDERS_SACK_ID, &"equipped")
	_expect(not sack_group.is_empty(), "Raider's Sack is missing from Equipped & Carried.", failures)
	var stored_sack_group: Dictionary = session.storage_group_snapshot(RAIDERS_SACK_ID, &"storage")
	_expect(stored_sack_group.is_empty(), "Raider's Sack incorrectly appears in Stronghold Storage.", failures)
	session.repository.clear_save()


static func _test_raiders_sack_tier_fixture(failures: Array[String]) -> void:
	var session := CampaignSession.new()
	session.configure(TEST_SAVE_PATH)
	session.repository.clear_save()
	var created: OperationResult = session.create_new_campaign(5406)
	_expect(created.success, "Raider's Sack fixture test campaign failed: %s" % created.message, failures)
	var campaign: CampaignState = session.current_campaign()
	if campaign == null:
		failures.append("Raider's Sack fixture test created no campaign.")
		return
	var marauder: PersistentCharacterState = campaign.get_character(MARAUDER_ID)
	_expect(marauder != null, "The starter Marauder is missing.", failures)
	if marauder == null:
		return
	var sacks: Array[CampaignItemState] = _raiders_sacks_for(campaign, MARAUDER_ID)
	_expect(sacks.size() == 1, "The Marauder does not own exactly one Raider's Sack.", failures)
	if sacks.is_empty():
		return
	var sack: CampaignItemState = sacks[0]
	_expect(
		sack.location.container_id == CampaignItemLocationState.CONTAINER_BELT
		and sack.location.grid_position == Vector2i(5, 0)
		and not sack.location.is_rotated,
		"Raider's Sack is not fixed in the rightmost 2x2 Belt cells.",
		failures
	)
	var unequip: OperationResult = session.preview_strategic_unequip(sack.item_id)
	_expect(not unequip.success and unequip.code == &"fixed_inventory_fixture", "Raider's Sack remained removable.", failures)
	var sell: OperationResult = session.preview_shop_sell(sack.item_id, 1)
	_expect(not sell.success and sell.code == &"shop_fixed_fixture", "Raider's Sack remained sellable.", failures)
	var dismantle: OperationResult = session.preview_dismantle_item(sack.item_id)
	_expect(not dismantle.success and dismantle.code == &"dismantle_fixed_fixture", "Raider's Sack remained dismantlable.", failures)

	# Save migration must preserve the player's ordinary Marauder loadout rather
	# than rebuilding every item around the fixed sack. It must also leave
	# similarly named supplies owned by unrelated characters untouched.
	var unrelated_character: PersistentCharacterState = null
	for candidate_character: PersistentCharacterState in campaign.get_characters():
		if candidate_character != null and candidate_character.character_id != MARAUDER_ID:
			unrelated_character = candidate_character
			break
	var unrelated_sack: CampaignItemState = null
	if unrelated_character != null:
		unrelated_sack = CampaignItemState.new(
			campaign.unique_item_id(&"instance.test.unrelated_empty_sack"),
			&"item.empty_sack",
			1,
			1.0,
			CampaignItemLocationState.character_slot(
				unrelated_character.character_id,
				CampaignItemLocationState.CONTAINER_BACKPACK,
				Vector2i(5, 3)
			)
		)
		campaign.add_item(unrelated_sack)
	var mace: CampaignItemState = null
	for item: CampaignItemState in campaign.items_for_character(MARAUDER_ID):
		if item != null and item.definition_id == &"item.mace":
			mace = item
			break
	if mace != null:
		mace.set_location(CampaignItemLocationState.stronghold_storage())
		campaign.upsert_item(mace)
		MarauderLoadoutMigration.repair_existing_marauders(campaign, session.catalogue)
		_expect(mace.location.is_stronghold_storage(), "Save migration rebuilt an ordinary Marauder loadout item.", failures)
	if unrelated_sack != null:
		_expect(
			campaign.get_item(unrelated_sack.item_id) != null,
			"Marauder migration removed an unrelated character's ordinary Empty Sack.",
			failures
		)

	# Replacing the Marauder Tier starting package removes only its physical
	# fixture. Levels and unrelated learned features remain untouched.
	var level_before: int = marauder.level_adjustment
	marauder.prestige_ability_ids.append(&"ability.test.learned")
	marauder.active_tier_starting_feat_ids = [&"feat.heaving_cast", &"feat.binding_line"]
	marauder.current_troop_type_id = &"troop.reaver.harpooner"
	marauder.troop_tier = 2
	MarauderLoadoutMigration.repair_raiders_sack_fixture(campaign, marauder, session.catalogue)
	_expect(_raiders_sacks_for(campaign, MARAUDER_ID).is_empty(), "Raider's Sack survived replacement of Raider's Burden.", failures)
	_expect(marauder.level_adjustment == level_before, "Tier fixture replacement changed troop Level.", failures)
	_expect(marauder.prestige_ability_ids.has(&"ability.test.learned"), "Tier fixture replacement removed a learned ability.", failures)

	# Entering Marauder again in an isolated migration fixture creates exactly one
	# sack and fixes it without duplicating the item.
	marauder.active_tier_starting_feat_ids = [&"trait.take_them_alive", &"trait.raiders_burden"]
	marauder.current_troop_type_id = &"troop.reaver.marauder"
	marauder.troop_tier = 1
	MarauderLoadoutMigration.repair_raiders_sack_fixture(campaign, marauder, session.catalogue)
	MarauderLoadoutMigration.repair_raiders_sack_fixture(campaign, marauder, session.catalogue)
	sacks = _raiders_sacks_for(campaign, MARAUDER_ID)
	_expect(sacks.size() == 1, "Raider's Sack fixture synchronisation duplicated the sack.", failures)
	var validation_errors: Array[String] = CampaignItemValidator.validate_campaign(campaign, session.catalogue)
	_expect(validation_errors.is_empty(), "Raider's Sack fixture campaign validation failed: %s" % (validation_errors[0] if not validation_errors.is_empty() else ""), failures)
	session.repository.clear_save()


static func _raiders_sacks_for(
		campaign: CampaignState,
		character_id: StringName
) -> Array[CampaignItemState]:
	var result: Array[CampaignItemState] = []
	for item: CampaignItemState in campaign.items_for_character(character_id):
		if item != null and item.definition_id == RAIDERS_SACK_ID:
			result.append(item)
	return result


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
