# Stage 5.3F5 — Carried Mission Loot Recovery Hotfix

## Reported fault

At mission extraction, Barbarian troops could have Grain Sacks, Grain Crates and
other authored objective items physically stored in their Backpacks. Captives were
registered, but the stolen items were omitted from the recovered-loot report and
could fail to survive the strategic recovery-selection transaction.

## Root causes

Two independent classification errors combined:

1. `MissionSetupSnapshot` contains both the squad's immutable outbound loadout and
   authored mission-ground items. `MissionResultBuilder` treated any item present in
   the setup as equipment taken from the stronghold. Grain and other authored props
   were therefore not added to `MissionCharacterResult.loot_item_ids` after a troop
   picked them up.
2. `MissionRecoverySelectionService` subtracted every item in a survivor's final
   Backpack from remaining Light Load, including newly stolen loot, and then charged
   the same loot again when validating optional cargo. Carried loot could therefore
   consume twice its real weight and be rejected or automatically left behind.

## Corrected contract

- An item is outbound squad equipment only when its immutable setup location belongs
  to a deployed player character.
- Authored mission-ground items remain mission loot even though they also exist in the
  immutable setup snapshot.
- Moving an authored Grain Sack, Grain Crate, weapon, furnishing or other objective
  item into an extracting troop's Backpack keeps its exact item identity and records
  it in both the character's final equipment manifest and `loot_item_ids`.
- Recovery capacity subtracts mandatory outbound equipment from each conscious survivor’s maximum carried load.
- Newly acquired loot is then charged once, and only once, when selected for the
  return journey. Stage 5.3G1 explicitly permits medium and heavy return loads up to the resolved maximum load.
- Selected carried loot retains its final character inventory location through the
  mission-result commit. It is not silently deleted or converted into a captive-only
  result.
- The mission summary lists selected carried mission items under **NEW LOOT
  RECOVERED**, while original squad equipment remains hidden under automatic returns.

## Files changed

- `application/missions/mission_result_builder.gd`
- `application/missions/mission_recovery_selection_service.gd`
- `tests/integration/stage_5_3f5_carried_loot_recovery_tests.gd`
- `tests/integration/run_stage_5_3f5_tests.gd`
- `tests/content/validate_stage_5_3f5_carried_loot_recovery_hotfix.py`

## Regression coverage

The included runtime test reproduces the fault by moving the authored sandbox Grain
Crate into the Marauder's Backpack before extraction. It verifies that:

1. the item is present in the physical extraction manifest;
2. the item remains in the troop's final Backpack manifest;
3. the item is classified as newly acquired loot rather than outbound equipment;
4. the recovery screen exposes it as recovered cargo;
5. selection succeeds without charging its weight twice.
