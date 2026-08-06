class_name Stage53F4InstantHiringMonthlyMarketTests
extends RefCounted

const TEST_SAVE_PATH: String = "user://stage_5_3f4_instant_hiring_monthly_market_tests.json"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var session := CampaignSession.new()
	session.configure(TEST_SAVE_PATH)
	session.repository.clear_save()
	var created: OperationResult = session.create_new_campaign(5304)
	_expect(created.success, "New campaign creation failed: %s" % created.message, failures)
	var campaign: CampaignState = session.current_campaign()
	if campaign == null:
		failures.append("New campaign did not bind a CampaignState.")
		session.repository.clear_save()
		return failures

	var offers_before: Array[Dictionary] = session.recruitment_market()
	_expect(offers_before.size() == 4, "The initial Barbarian recruitment market did not contain four candidates.", failures)
	if offers_before.is_empty():
		session.repository.clear_save()
		return failures
	var first_offer: HenchmanRecruitmentOfferState = offers_before[0].get("offer") as HenchmanRecruitmentOfferState
	_expect(first_offer != null, "The first recruitment preview had no offer state.", failures)
	if first_offer == null:
		session.repository.clear_save()
		return failures

	var roster_before: int = campaign.active_roster_count()
	var hired: OperationResult = session.begin_henchman_recruitment(first_offer.offer_id)
	_expect(hired.success, "Instant hiring failed: %s" % hired.message, failures)
	campaign = session.current_campaign()
	_expect(campaign.active_roster_count() == roster_before + 1, "Hiring did not add the recruit to the Roster in the same transaction.", failures)
	_expect(campaign.get_recruitment_offer(first_offer.offer_id) == null, "The hired candidate remained in the recruitment market.", failures)
	_expect(campaign.get_recruitment_projects().is_empty(), "Instant hiring created a timed RecruitmentProject.", failures)
	var recruited: PersistentCharacterState = hired.data as PersistentCharacterState
	_expect(recruited != null, "Instant hiring did not return the recruited persistent character.", failures)
	if recruited != null:
		_expect(recruited.career_id == ReaverCareerContent.CAREER_ID, "The recruit did not receive the Reaver career.", failures)
		_expect(recruited.troop_tier == 0, "The recruit did not enter at base Tier 0.", failures)
		_expect(recruited.class_rank(&"class.barbarian") == 1, "The recruit did not enter as a Level 1 Barbarian henchman.", failures)

	var offers_after_hire: Array[StringName] = []
	for offer: HenchmanRecruitmentOfferState in campaign.get_recruitment_offers():
		offers_after_hire.append(offer.offer_id)
	var market_revision_after_hire: int = campaign.recruitment_market_revision
	_expect(not session.henchman_recruitment_service.ensure_market_candidate(campaign), "A depleted same-month market refreshed before the monthly boundary.", failures)
	_expect(campaign.recruitment_market_revision == market_revision_after_hire, "The recruitment market revision changed inside the same month.", failures)

	campaign.campaign_tick = HenchmanRecruitmentService.CAMPAIGN_MONTH_TICKS - 1
	_expect(not session.henchman_recruitment_service.refresh_market_if_due_candidate(campaign), "The recruitment market refreshed one tick before the monthly boundary.", failures)
	campaign.campaign_tick += 1
	_expect(session.henchman_recruitment_service.refresh_market_if_due_candidate(campaign), "The recruitment market did not refresh at the 30-day boundary.", failures)
	_expect(campaign.recruitment_market_month_index == 1, "The recruitment market did not advance to campaign month index 1.", failures)
	_expect(campaign.get_recruitment_offers().size() == 4, "The monthly refresh did not generate a complete new candidate list.", failures)
	var refreshed_offer_ids: Array[StringName] = []
	for offer: HenchmanRecruitmentOfferState in campaign.get_recruitment_offers():
		refreshed_offer_ids.append(offer.offer_id)
	_expect(refreshed_offer_ids != offers_after_hire, "The monthly refresh reused the depleted previous candidate list.", failures)

	var restored := CampaignState.from_dictionary(campaign.to_dictionary())
	_expect(restored.recruitment_market_month_index == campaign.recruitment_market_month_index, "Save round-trip lost the recruitment market month index.", failures)
	_expect(restored.get_recruitment_offers().size() == campaign.get_recruitment_offers().size(), "Save round-trip lost monthly recruitment offers.", failures)

	session.repository.clear_save()
	return failures


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
