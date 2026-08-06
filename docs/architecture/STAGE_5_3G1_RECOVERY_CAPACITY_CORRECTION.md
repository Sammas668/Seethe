# Stage 5.3G1 — Mission Recovery Carrying-Capacity Correction

## Purpose

Correct the post-mission recovery allowance so a successful raiding squad can
actually return with meaningful cargo. The previous implementation pooled each
conscious survivor's unused **Light Load**. This was mathematically consistent
with the earlier Stage 5.3D rule, but it was too restrictive for the intended
recovery loop: ordinary weapons, armour, grain, furniture and objectives could
consume the entire allowance even when the troops remained far below their real
maximum carrying limits.

Stage 5.3G1 deliberately supersedes the Light-Load recovery rule.

> **Stage 5.3G2 supersession:** the survivor maximum-load pool remains the Walking rule. When a dedicated transport is assigned, its cargo rating replaces the survivor pool rather than being added to it.

## Locked recovery rule

Post-mission recovery is a hauling operation rather than normal tactical
movement. Every conscious persistent player character who physically extracts
contributes:

`resolved maximum carried load − mandatory outbound equipment still returning`

The complete optional recovery allowance is:

`Walking: survivors' remaining maximum load − manual burdens`

`Assigned transport: dedicated transport cargo − cargo burdens`

Mandatory manual burdens include:

- recovered unconscious or dead allies not carried by dedicated support;
- selected captives beyond dedicated captive capacity;
- mandatory returning items not already counted in a survivor's outbound load.

Optional selected loot is then charged once against the remaining allowance.

## Encumbrance meaning

The recovery screen may use a survivor's medium or heavy load range. It does not
permit the survivor pool to exceed the resolved maximum load.

This correction does not change tactical movement during the mission. Light,
medium and heavy encumbrance continue to affect tactical movement through the
existing character and inventory rules. It only changes the strategic return
allowance after extraction.

The first implementation keeps the existing authored return duration. A later
transport pass may add transparent return-time penalties for heavily burdened
walking expeditions, but such a penalty must not be hidden inside the cargo
calculation.

## Authoritative inputs

The calculation uses:

- the immutable deployed character states from `MissionSetupSnapshot`;
- each character's resolved `maximum_weight_lb`, including active Tier carrying
  features;
- the exact outbound items that survive extraction;
- the exact selected optional item IDs;
- the exact mission transport assignment;
- selected captives and recovered casualties.

The current campaign state is only a fallback when a legacy result lacks the
immutable deployed character record.

## Item counting rules

- Outbound equipment is deducted once from survivor capacity.
- Newly stolen loot is not deducted as outbound equipment.
- Selected optional loot is charged once.
- Dedicated transport cargo is used once as the sole capacity source when transport is assigned.
- Mandatory unallocated objects are deducted once.
- Captives and casualties consume either dedicated support or their authored
  manual burden, never both.

## Recovery presentation

The recovery screen displays:

- the active capacity source: dedicated transport cargo or survivors' combined remaining carrying capacity;
- mandatory carried burden;
- final optional recovery capacity;
- selected optional cargo weight;
- a per-survivor breakdown showing maximum load, outbound equipment and
  remaining contribution.

This breakdown is intentionally visible so an unexpectedly low capacity can be
diagnosed without guessing which hidden value was used.

## Compatibility

Pending mission-recovery sidecars do not store the derived capacity snapshot.
They store the immutable envelope and selection. On load the snapshot is rebuilt,
so an existing pending recovery automatically receives the corrected calculation.
No campaign-save migration is required.

## Acceptance tests

Stage 5.3G1 verifies that:

1. survivor capacity equals the sum of remaining resolved maximum loads;
2. cargo heavier than the old Light-Load allowance but within maximum load is
   accepted;
3. outbound equipment and optional loot are each charged once;
4. assigned transport capacity replaces rather than adds to survivor capacity;
5. the recovery UI exposes the per-survivor calculation;
6. existing Stage 5.3G exact-once mission commitment remains unchanged.

Runtime entry point:

`res://tests/integration/run_stage_5_3g_tests.gd`
