# Stage 5.3G2 — Transport Recovery Capacity Separation

## Purpose

Prevent recovery capacity from becoming artificially high when a squad uses an assigned transport. A transported squad is already carried through the transport's passenger allowance. Its individual carrying capacities must therefore not be added on top of the vehicle or beast train's dedicated cargo rating.

Stage 5.3G2 supersedes the Stage 5.3G1 formula only when a non-Walking transport is assigned. Stage 5.3G1 remains authoritative for Walking expeditions.

## Locked capacity modes

Recovery has exactly one ordinary-capacity source.

### Walking

`sum of conscious extracting survivors' remaining maximum loads − manual burdens`

Walking uses individual carrying statistics because there is no dedicated cargo asset.

### Assigned transport

`assigned transport cargo rating − cargo burdens`

Transported recovery does not add:

- survivor Strength-based carrying limits;
- Tier carrying bonuses;
- unused backpack weight allowance;
- the carrying capacity of mounts represented by the passenger transport;
- recovered squad casualties as a second cargo burden.

The passenger allowance already carries:

- every deployed squad member within the validated passenger limit;
- their equipped weapons, armour, belt and Backpack loadout brought from the stronghold;
- a recovered unconscious or dead member of that same deployed squad.

## What consumes transport cargo

- every selected optional item acquired during the mission;
- objective or required cargo not classified as a deployed character's personal outbound equipment;
- captives beyond dedicated captive capacity;
- cages or oversized items beyond specialist slots, using their normal item weight;
- other authored ordinary cargo burdens.

The item consumes transport cargo even if it happened to be inside a troop's Backpack at the moment of extraction. Tactical location determines extraction and identity; it does not create extra strategic transport capacity.

## Specialist capacity

Monster and siege cargo still require their authored specialist spaces. Ordinary cargo weight cannot replace those spaces.

Cages and oversized assets may exceed dedicated specialist slots only when their normal weight fits the active ordinary recovery allowance:

- survivor maximum-load allowance while Walking;
- transport cargo allowance when transported.

## Casualties and captives

The deployed squad's passenger places are reserved for the return journey. A recovered squad casualty therefore does not reduce transport cargo.

Captives are additional people, not members of the deployed passenger manifest. They use:

1. dedicated captive capacity first;
2. ordinary cargo burden at the authored person-weight value for any excess.

Walking expeditions continue to treat both recovered casualties and captives as manual burdens.

## Recovery UI

The capacity panel must never imply that transport and personal carrying stack.

Walking displays:

- survivor remaining carrying capacity;
- manual burden;
- optional recovery capacity;
- per-survivor calculation.

Assigned transport displays:

- transport cargo capacity;
- confirmation that squad and personal equipment use passenger allowance;
- survivor contribution as ignored;
- mandatory cargo burden;
- optional recovery capacity.

## Save and transaction boundary

The rule is derived from the immutable mission setup, exact transport assignment and pending mission result. No derived capacity is persisted as campaign authority. Loading a pending recovery rebuilds the snapshot and receives the corrected rule automatically.

The final selected item IDs and captive IDs remain part of the atomic, idempotent mission-result commit.

## Acceptance tests

1. Walking still uses survivors' remaining maximum loads.
2. Assigned transport uses exactly its dedicated cargo rating.
3. Survivor carrying capacity is zero in the transported recovery snapshot.
4. Cargo above the transport rating is rejected even when the squad could personally carry it.
5. A recovered deployed squad casualty uses passenger allowance rather than cargo.
6. Optional loot is charged once and outbound personal equipment is not charged as new cargo.
7. Existing mission commit, item identity, captive and XP safeguards remain unchanged.
