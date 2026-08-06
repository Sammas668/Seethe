class_name NewCampaignService
extends RefCounted

const StrongholdDefinitionRegistryScript = preload("res://application/stronghold/stronghold_definition_registry.gd")


const PROTAGONIST_ID: StringName = &"character.protagonist.placeholder.0001"
const MARAUDER_ONE_ID: StringName = &"character.reaver.marauder.0001"
const MARAUDER_TWO_ID: StringName = &"character.reaver.marauder.0002"

const PROTAGONIST_TEMPLATE_ID: StringName = &"character_template.protagonist.provisional_scorned_champion"
const MARAUDER_TEMPLATE_ID: StringName = &"character_template.reaver.marauder_tier_1"
const STARTING_REGION_ID: StringName = &"region.life.starter"
const HAKON_PORTRAIT_ID: StringName = &"portrait.hakon_rusk"

var _catalogue: ContentCatalogue
var _region_registry: RegionDefinitionRegistry
var _stronghold_registry: StrongholdDefinitionRegistryScript


func configure(
	catalogue: ContentCatalogue,
	region_registry: RegionDefinitionRegistry = null,
	stronghold_registry: StrongholdDefinitionRegistryScript = null
) -> void:
	_catalogue = catalogue
	_region_registry = region_registry
	_stronghold_registry = stronghold_registry


func create_campaign(seed_value: int = -1) -> CampaignState:
	if _catalogue == null:
		push_error("NewCampaignService requires a content catalogue.")
		return null
	var seed: int = seed_value
	if seed < 0:
		seed = int(Time.get_unix_time_from_system())
		seed ^= int(Time.get_ticks_usec() & 0x7fffffff)
	seed = absi(seed)

	var campaign := CampaignState.new()
	campaign.campaign_seed = seed
	campaign.campaign_id = StringName("seethe.%d" % seed)
	campaign.campaign_status = CampaignStatus.ACTIVE
	campaign.campaign_tick = 8 * 60
	campaign.protagonist_character_id = PROTAGONIST_ID
	campaign.current_region_id = STARTING_REGION_ID
	campaign.resources = CampaignResourceBalances.new()
	campaign.resources.wood = 40
	campaign.resources.stone = 30
	campaign.resources.metal = 12
	campaign.resources.food = 80
	campaign.resources.textiles = 0
	campaign.resources.magic = 5
	campaign.resources.gold = 150

	_add_protagonist(campaign)
	_add_marauder(campaign, MARAUDER_ONE_ID, "Hakon Rusk", &"instance.marauder")
	_add_marauder(campaign, MARAUDER_TWO_ID, "Svala Thorn", &"instance.marauder_two")

	_add_starting_agent(campaign)
	_initialize_subregion_notoriety(campaign)
	_initialize_stronghold(campaign)
	var transport_service := SquadTransportService.new()
	transport_service.configure(_stronghold_registry)
	transport_service.ensure_campaign_transport_state(campaign)
	var squad_service := SquadManagementService.new()
	squad_service.ensure_campaign_squads(campaign)
	var bay_service := StableBayService.new()
	bay_service.configure(transport_service, _stronghold_registry)
	bay_service.ensure_campaign_bays(campaign)
	var supported_bays: Array[StableBayState] = bay_service.supported_bays(campaign)
	var first_bay: StableBayState = supported_bays[0] if not supported_bays.is_empty() else null
	var first_squad: CampaignSquadState = campaign.get_squad(SquadManagementService.FIRST_SQUAD_ID)
	if first_bay != null and first_squad != null:
		var starter_transport: TransportState = campaign.get_transport(SquadTransportService.STARTER_TRANSPORT_ID)
		if starter_transport != null:
			bay_service.assign_transport_asset(campaign, first_bay.bay_id, starter_transport.transport_id)
		bay_service.assign_squad(campaign, first_bay.bay_id, first_squad.squad_id)

	# New-campaign creation is one authored baseline, not a sequence of player
	# commands. Start the persistent root at revision zero after assembly.
	campaign.revision = 0
	var errors: Array[String] = campaign.validate_campaign()
	if not errors.is_empty():
		push_error("New campaign is invalid: %s" % errors[0])
		return null
	return campaign


func _initialize_stronghold(campaign: CampaignState) -> void:
	if campaign == null or _stronghold_registry == null:
		return
	campaign.stronghold = _stronghold_registry.create_initial_state()

func _initialize_subregion_notoriety(campaign: CampaignState) -> void:
	if campaign == null or _region_registry == null:
		return
	var region: RegionMapDefinition = _region_registry.definition(STARTING_REGION_ID)
	if region == null:
		return
	SubregionNotorietyService.new().ensure_region_states(campaign, region)


func _add_starting_agent(campaign: CampaignState) -> void:
	if campaign == null or _region_registry == null:
		return
	var region: RegionMapDefinition = _region_registry.definition(STARTING_REGION_ID)
	var stronghold: RegionSiteDefinition = (
		region.site(region.fifth_god_ruin_site_id) if region != null else null
	)
	if stronghold == null or stronghold.coord == null:
		push_error("Starter Agent could not locate the Fifth-God stronghold.")
		return
	var agent := AgentState.new()
	agent.agent_id = AgentService.STARTING_AGENT_ID
	agent.display_name = AgentService.STARTING_AGENT_NAME
	agent.current_region_id = STARTING_REGION_ID
	agent.current_hex = stronghold.coord.duplicate_coord()
	agent.status = AgentState.STATUS_AT_STRONGHOLD
	campaign.upsert_agent(agent)


func _add_protagonist(campaign: CampaignState) -> void:
	var template: CharacterTemplateDefinition = _catalogue.character_template(
		PROTAGONIST_TEMPLATE_ID
	)
	if template == null:
		push_error("Starter protagonist template is missing.")
		return
	var character := CharacterFactory.create_player_character(
		template,
		PROTAGONIST_ID,
		"The Scorned Champion"
	)
	character.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
	character.add_history("Awakened the surviving Heart of the forgotten Fifth God.")
	campaign.add_character(character)
	CharacterFactory.add_default_loadout_to_campaign(
		campaign,
		character,
		template,
		{
			&"item.raiders_axe": &"instance.protagonist.axe",
			&"item.rope": &"instance.protagonist.rope",
			&"item.bandage": &"instance.protagonist.bandage",
		}
	)


func _add_marauder(
		campaign: CampaignState,
		character_id: StringName,
		display_name: String,
		instance_prefix: StringName
) -> void:
	var template: CharacterTemplateDefinition = _catalogue.character_template(
		MARAUDER_TEMPLATE_ID
	)
	if template == null:
		push_error("Starter Marauder template is missing.")
		return
	var character := CharacterFactory.create_player_character(
		template,
		character_id,
		display_name
	)
	character.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN
	character.add_history("Joined the first raiding party at the Fifth-God ruin.")
	character.set_portrait_override_id(HAKON_PORTRAIT_ID)
	campaign.add_character(character)
	CharacterFactory.add_default_loadout_to_campaign(
		campaign,
		character,
		template,
		{
			&"item.raiders_axe": StringName("%s.axe" % instance_prefix),
			&"item.mace": StringName("%s.mace" % instance_prefix),
			&"item.reaver_dagger": StringName("%s.dagger" % instance_prefix),
			&"item.manacles": StringName("%s.manacles" % instance_prefix),
			&"item.rope": StringName("%s.rope" % instance_prefix),
		}
	)
	MarauderLoadoutMigration.repair_character(campaign, character, instance_prefix)
