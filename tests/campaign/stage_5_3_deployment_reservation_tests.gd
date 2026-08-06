class_name Stage53DeploymentReservationTests
extends RefCounted

const StrategicReservationServiceScript = preload(
	"res://application/inventory/strategic_reservation_service.gd"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_exact_deployment_reservation_round_trip(failures)
	_test_release_restores_availability(failures)
	_test_unchanged_reserved_location_is_idempotent(failures)
	return failures


static func _test_exact_deployment_reservation_round_trip(
		failures: Array[String]
) -> void:
	var campaign: CampaignState = _campaign_with_character_and_item()
	var service = StrategicReservationServiceScript.new()
	var result: OperationResult = service.reserve_deployment_candidate(
		campaign,
		&"reservation.test.deployment",
		&"operation.test.deployment",
		&"mission.test.deployment",
		"Farm Raid",
		[&"character.test.deployed"],
		[&"item.test.deployed"]
	)
	_expect(result.success, "A valid deployment must reserve successfully.", failures)
	_expect(
		not bool(service.character_availability(
			campaign, &"character.test.deployed"
		).get("available", true)),
		"The deployed character must become unavailable.",
		failures
	)
	_expect(
		not bool(service.item_availability(
			campaign, &"item.test.deployed"
		).get("available", true)),
		"The exact deployed item must become unavailable.",
		failures
	)
	var restored := CampaignState.from_dictionary(campaign.to_dictionary())
	var reservation = restored.get_strategic_reservation(
		&"reservation.test.deployment"
	)
	_expect(
		reservation != null and reservation.is_active(),
		"Save/load must preserve the active reservation.",
		failures
	)
	_expect(
		reservation != null and reservation.item_ids == [&"item.test.deployed"],
		"Save/load must preserve exact reserved item identity.",
		failures
	)


static func _test_release_restores_availability(
		failures: Array[String]
) -> void:
	var campaign: CampaignState = _campaign_with_character_and_item()
	var service = StrategicReservationServiceScript.new()
	service.reserve_deployment_candidate(
		campaign,
		&"reservation.test.release",
		&"operation.test.release",
		&"mission.test.release",
		"Storehouse Raid",
		[&"character.test.deployed"],
		[&"item.test.deployed"]
	)
	var released: OperationResult = service.release_reservation_candidate(
		campaign,
		&"reservation.test.release"
	)
	_expect(released.success, "A deployment reservation must release once.", failures)
	_expect(
		bool(service.character_availability(
			campaign, &"character.test.deployed"
		).get("available", false)),
		"The character must become available after release.",
		failures
	)
	_expect(
		bool(service.item_availability(
			campaign, &"item.test.deployed"
		).get("available", false)),
		"The exact item must become available after release.",
		failures
	)


static func _test_unchanged_reserved_location_is_idempotent(
		failures: Array[String]
) -> void:
	var campaign: CampaignState = _campaign_with_character_and_item()
	var service = StrategicReservationServiceScript.new()
	service.reserve_deployment_candidate(
		campaign,
		&"reservation.test.location",
		&"operation.test.location",
		&"mission.test.location",
		"Farm Raid",
		[&"character.test.deployed"],
		[&"item.test.deployed"]
	)
	var item: CampaignItemState = campaign.get_item(
		&"item.test.deployed"
	) as CampaignItemState
	var unchanged: OperationResult = service.validate_location_change(
		campaign,
		item.item_id,
		item.location.clone()
	)
	_expect(
		unchanged.success,
		"Restoring an unchanged reserved location must remain idempotent.",
		failures
	)
	var moved: OperationResult = service.validate_location_change(
		campaign,
		item.item_id,
		CampaignItemLocationState.stronghold_storage()
	)
	_expect(
		not moved.success,
		"A reserved item must reject a real location change.",
		failures
	)


static func _campaign_with_character_and_item() -> CampaignState:
	var campaign := CampaignState.new()
	var character := PersistentCharacterState.new()
	character.character_id = &"character.test.deployed"
	character.template_id = &"character_template.test"
	character.display_name = "Test Marauder"
	character.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
	character.roster_role = PersistentCharacterState.ROLE_PLAYER
	campaign.add_character(character)
	var item := CampaignItemState.new(
		&"item.test.deployed",
		&"item.test.weapon",
		1,
		1.0,
		CampaignItemLocationState.character_slot(
			character.character_id,
			CampaignItemLocationState.CONTAINER_PRIMARY_HAND
		)
	)
	campaign.add_item(item)
	return campaign


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
