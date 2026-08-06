class_name CaptivePolicyRegistry
extends RefCounted

var _policies_by_template_id: Dictionary = {}
var _default_policy: CaptivePolicyDefinition


func _init() -> void:
	_default_policy = _make_policy(&"captive_policy.default", false, 0, 0)
	_register(&"character_template.life.patrol_leader", _make_policy(
		&"captive_policy.life_officer", true, 180, -2
	))
	_register(&"character_template.life.mercy_bearer", _make_policy(
		&"captive_policy.life_mercy_bearer", true, 160, -1
	))
	_register(&"character_template.life.novice_mercy_bearer", _make_policy(
		&"captive_policy.life_novice_mercy_bearer", true, 100, -1
	))
	_register(&"character_template.life.settlement_guard", _make_policy(
		&"captive_policy.life_guard", false, 0, 0
	))
	_register(&"character_template.life.settlement_archer", _make_policy(
		&"captive_policy.life_guard", false, 0, 0
	))
	_register(&"character_template.life.sanctuary_spear_guard", _make_policy(
		&"captive_policy.life_guard", false, 0, 0
	))
	_register(&"character_template.life.sanctuary_archer", _make_policy(
		&"captive_policy.life_guard", false, 0, 0
	))


func policy_for(source_definition_id: StringName) -> CaptivePolicyDefinition:
	var policy: CaptivePolicyDefinition = _policies_by_template_id.get(source_definition_id) as CaptivePolicyDefinition
	return policy if policy != null else _default_policy


func apply_to_captive(captive: CampaignCaptiveState) -> bool:
	if captive == null:
		return false
	var policy: CaptivePolicyDefinition = policy_for(captive.source_definition_id)
	captive.cell_cost = policy.cell_cost
	captive.containment_profile_id = policy.containment_profile_id
	captive.containment_tags = policy.containment_tags.duplicate()
	captive.ransom_allowed = policy.ransom_allowed
	captive.ransom_value = policy.ransom_value
	captive.ransom_faction_id = (
		policy.ransom_faction_id
		if not policy.ransom_faction_id.is_empty()
		else captive.faction_id
	)
	captive.release_allowed = policy.release_allowed
	captive.release_notoriety_delta = policy.release_notoriety_delta
	captive.available_action_ids = policy.available_action_ids.duplicate()
	if captive.ransom_allowed and not captive.available_action_ids.has(&"ransom"):
		captive.available_action_ids.append(&"ransom")
	if captive.release_allowed and not captive.available_action_ids.has(&"release"):
		captive.available_action_ids.append(&"release")
	return true


func _register(template_id: StringName, policy: CaptivePolicyDefinition) -> void:
	if template_id.is_empty() or policy == null:
		return
	_policies_by_template_id[template_id] = policy


func _make_policy(
	policy_id: StringName,
	ransom_allowed: bool,
	ransom_value: int,
	release_notoriety_delta: int
) -> CaptivePolicyDefinition:
	var policy := CaptivePolicyDefinition.new()
	policy.policy_id = policy_id
	policy.ransom_allowed = ransom_allowed
	policy.ransom_value = maxi(0, ransom_value)
	policy.release_notoriety_delta = release_notoriety_delta
	policy.available_action_ids = [&"release"]
	if ransom_allowed:
		policy.available_action_ids.append(&"ransom")
	return policy
