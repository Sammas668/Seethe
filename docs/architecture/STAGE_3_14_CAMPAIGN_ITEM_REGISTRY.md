# Stage 3.14 — Campaign Item Registry

## Authoritative ownership

```text
CampaignState
├── characters_by_id
├── items_by_id
└── applied_result_ids
```

A persistent item exists once in `CampaignState.items_by_id`. Its location determines whether it is equipped, carried, stored in the stronghold, assigned to a mission, unassigned or lost.

```text
CampaignItemState
├── item_id
├── definition_id
├── quantity
├── condition
├── persistent_modifiers
└── location
```

```text
CampaignItemLocationState
├── location_type
├── owner_id
├── container_id
├── grid_position
├── map_position
└── source_label
```

## Locked implementation rules

1. `PersistentCharacterState` contains progression, identity, injuries and history, but no item-instance dictionaries.
2. Character equipment and inventory are queried through `CampaignState.items_for_character(character_id)`.
3. Stronghold storage is queried through `CampaignState.items_in_stronghold(storage_id)`.
4. Moving an item between a character and storage changes the location on the same `CampaignItemState`; it does not create a copy.
5. Character templates author identity-free default loadout entries. `CharacterFactory` creates individually identified campaign items from those entries.
6. `MissionSetupSnapshot` deep-copies selected characters and items into mission-local state. Tactical actions do not mutate `CampaignState`.
7. `MissionResult` contains the complete extracted item records needed to reconcile campaign ownership.
8. `CampaignResultCommitService` removes lost items, restores extracted items at their final locations and applies each result ID exactly once.
9. Mission-only enemies and neutrals can use the same item pipeline without being serialized into the campaign save.
10. The Character Sheet and tactical UI remain presentation clients; they do not own or duplicate persistent item state.

## Shared character and stronghold operations

```text
Stronghold storage item
    ↓ assign_item_to_character()
Character equipment/inventory
    ↓ move_item_to_stronghold()
Stronghold storage item
```

Both operations retain the same item ID, quantity, condition and persistent modifiers.

## Mission flow

```text
CampaignState.items_by_id
        ↓ isolated copy
MissionSetupSnapshot.items_by_id
        ↓ tactical conversion
TacticalState.items_by_id
        ↓ extraction result
MissionResult.extracted_item_entries
        ↓ exactly-once commit
CampaignState.items_by_id
```

## Save migration

`CharacterRosterRepository.load_campaign()` continues reading the historical Stage 3.12 save path. `CampaignState.from_dictionary()` migrates:

- every legacy character `loadout_entries` record to a character-owned campaign item;
- every legacy `campaign_loot_entries` record to stronghold storage;
- existing applied mission-result IDs and character progression without alteration.

The migrated save is normalized when next written. Characters no longer serialize `loadout_entries`, and the campaign no longer serializes `campaign_loot_entries`.

## Scope boundary

Stage 3.14 establishes persistent item ownership and location. It does not yet implement the full stronghold inventory screen, manufacturing, reservations, sale, dismantling or equipment-repair workflows. Those systems should operate on this same registry rather than introduce parallel item stores.
