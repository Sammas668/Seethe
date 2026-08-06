# Stage 3.17 — Combat Foundation Lock

Stage 3.17 is the final narrow foundation pass before the first attack implementation.
It does not add combat execution. It protects the state boundaries that combat will use.

## Campaign commit ownership

`CampaignStateStore` owns the active campaign root. A `CampaignChangeSet` is applied to
a deserialized candidate rather than the live root. The candidate is validated, safely
saved, and only then replaces the active campaign. One successful campaign operation
advances campaign revision exactly once.

`CampaignResultCommitService` now commits mission results through this store. It no
longer mutates the live root and then reconstructs it for rollback.

## Finalized mission setup

`MissionSetupBuilder` creates a mutable draft. Before deployment, the builder records
the complete intended participant manifest and finalizes the setup. A finalized setup:

- rejects further characters, items, ground loot and participant changes;
- returns defensive copies of characters and items;
- remains the trusted baseline for mission-result validation;
- records a stable setup hash for diagnostics.

## Item-instance-aware resolution

`ResolvedEquipmentInput` preserves the item ID, definition, location, quantity,
condition, persistent modifiers and whether the item is actually equipped or merely
carried. Character resolution no longer deduplicates items by definition ID.

Only equipped item instances may contribute combat statistics. Carried items can still
appear as available/stowed Character Sheet actions.

## Armour Class authority

The resolved character snapshot is the sole Armour Class authority:

```text
base defence
+ Dexterity
+ equipped armour DefenceProfile
+ equipped shield/item instance modifiers
+ persistent character modifiers
+ active effects
= resolved Armour Class
```

`TacticalUnitState.armour_class` is a runtime cache rebuilt from that resolved value.
`PersistentCharacterState.equipped_defence_profile_id` remains a clearly marked
compatibility fallback until every old template owns a real armour item.

## Stage boundary

Stage 3.17 is complete when the project opens cleanly, movement and inventory still
work, the Character Sheet retains its existing presentation, and all static validators
from Stage 3.9 through Stage 3.17 pass. The next milestone is Stage 4.0: one Raider's
Axe attack against a stationary Practice Dummy.
