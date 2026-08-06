# Stage 5.3D — Corrected Transport, Stable Capacity and Mission Recovery

## Authority boundaries

The implementation separates four concerns:

- **Walking** is an unconditional squad option.
- **Stable facilities** provide Stable Space and therefore determine how many persistent transport assets the stronghold can support.
- **Research knowledge** unlocks transport definitions; it does not create an asset.
- **Owned transport instances** are acquired separately, housed, supported, reserved, damaged and returned as exact campaign state.

Stable level never grants a named transport automatically. A completed Research ID remains campaign knowledge if the Stable is damaged. The initial campaign begins with Pack Beast handling known and one exact Pack Beast Train; later methods remain gated for the future Research workflow.

## Stable Space

Each operational or upgrading Stable contributes its authored `stable_space_by_level`. Every supported transport consumes `stable_space_required`. The starting Stable provides 2/4/7 Stable Space at levels I/II/III.

The player explicitly enables or stands down support for each asset. If enabled assets exceed current capacity, none may deploy until the player chooses which assets to stand down; the game does not silently select winners by list order. Damaged or disabled Stables contribute no capacity, but excess assets remain owned.

## Persistent transport assets

`TransportState` preserves exact identity, housed Stable, condition, support choice, current status, mission reservation, journey and history. The lifecycle is:

`AVAILABLE → RESERVED → TRAVELLING_OUT → DEPLOYED → RETURNING → AVAILABLE`

Damage, repair, unsupported, lost and destroyed states are also authored in the model. Exact instance IDs remain attached to `SquadTravelOperationState` throughout the lifecycle.

## Transport definitions

Each method defines:

- passenger capacity;
- strategic speed multiplier;
- dedicated cargo capacity;
- percentage modifier applied once to the complete journey Notoriety;
- captive, cage, monster, siege and oversized support;
- Stable Space requirement;
- terrain travel-time modifiers;
- genuinely impassable terrain tags;
- condition and repair metadata.

Multiple instances of one type add passenger, cargo and specialist capacity. They do not multiply speed or the percentage Notoriety modifier. Mixed convoys are intentionally deferred.

## Roads and terrain

The roadless Fifth-God stronghold never prevents departure. Roads and terrain affect journey duration through authored multipliers. No generic route-viability score or road-required transport rule remains. Only terrain that is explicitly impassable to a method may block it.

## Journey Notoriety

Route geography and squad footprint first produce the ordinary itemised base journey Notoriety. The selected method then applies one transparent percentage modifier to that overall total:

`final = round(base × (1 + modifier / 100))`, with a minimum of zero.

The preview and report preserve the pre-transport subtotal, percentage, numerical adjustment and final value. A Covered Wagon may reduce the whole journey; a Mounted Troop may increase it. The modifier is not hidden and is not applied once per vehicle.

## Walking and recovery capacity

Walking has no dedicated cargo capacity. Optional recovery capacity is the sum of each conscious extracting survivor’s unused maximum carried load after their mandatory outbound equipment is accounted for. Post-mission return hauling may use medium or heavy encumbrance. When a non-Walking transport is assigned, survivor carrying capacity is ignored: passenger capacity carries the squad and personal equipment, while optional recovered assets use only the transport’s dedicated cargo rating.

With a transport, its dedicated cargo capacity is added to that personal allowance. Mandatory burdens are deducted before optional loot:

- manually carried unconscious or dead allies;
- captives beyond dedicated captive spaces;
- mandatory items not already included in a survivor’s equipment burden.

Monsters and siege engines require dedicated specialist support. Cages and oversized furniture may exceed dedicated anchors when their normal weight still fits the physical carrying allowance; the recovery screen reports the excess as manually carried.

## Crash-safe mission handoff

The tactical mission produces an immutable `MissionCommitEnvelope`. It is written to an atomic recovery sidecar before the tactical screen can be discarded. The recovery selection and current selected IDs are also persisted.

The flow is:

`TACTICAL RESULT → PENDING RECOVERY SIDECAR → PLAYER SELECTION → VALIDATED FILTERED ENVELOPE → EXACT-ONCE COMMIT → RETURN JOURNEY`

Loading a campaign with a pending sidecar reconstructs the same recovery screen. Failed commits retain the envelope for retry. Safe-checkpoint restoration explicitly clears it. Campaign revision may advance through legitimate strategic time and travel while a mission is active; commit rejects revision rollback, while setup hashes, active mission registration, reservations, authority snapshots and provenance protect the relevant immutable boundary.

Campaign defeat is committed exactly once before the defeat screen appears.

## Recovery selection

The player sees every optional extracted item with quantity, weight, Storage usage, cargo category and specialist requirement. Surviving permanent characters, their owned equipment, required extraction objects and accepted restrained captives remain mandatory.

The Confirm action is unavailable while selected weight or hard specialist requirements exceed capacity. Deselecting an object adds its exact ID to the mission’s abandoned record and removes all character and generated-provenance references before commit. No selected object is silently deleted.

## Return journey

Committing recovery starts a reversed timed journey using the same surviving transport assignment and route duration. Transport assets, characters and their reserved equipment remain unavailable. Recovered storage-bound objects use `return_transit` location, and captives use a return-transit holding location. On arrival:

- cargo enters stronghold storage;
- captives enter temporary stronghold holding;
- deployment reservations release;
- exact transports return to availability if operational.

## Migration

Legacy Foot Column, Pack Train, Wagon Train and Mounted Column assignments are cleared to Walking while preserving mission, route, characters and items. Stable facility state is retained, but no Stable level grants those obsolete methods.

## Deferred work

A complete general Research screen and timed Research projects are outside Stage 5.3. This update provides the permanent Research IDs and authoritative transport-acquisition gate so that later Research completion can unlock methods without changing Stable logic.
