# Stage 4.7 Hotfix 5c — Raider's Sack 4×3 Body Grid

The Raider's Sack retains its fixed **2×2 external Belt footprint** at Belt origin `(5, 0)`. Left-clicking the item opens a presentation-only popup whose authoritative internal container is **4 cells wide × 3 cells high**.

Medium tactical body items now use the matching **4×3 inventory footprint**. One Medium restrained body therefore fits exactly in the Sack. The Sack remains single-entity-only and rejects ordinary loot, a second body, and any entity whose footprint exceeds the 4×3 container.

The size contract is shared by:

- `ItemDefinition.internal_container_size` for `item.raiders_sack`;
- `TacticalInventoryState.RAIDER_SACK_WIDTH/HEIGHT`;
- `TacticalItemInstanceState.create_body()`;
- transfer and fit validation;
- the floating Raider's Sack inventory grid;
- static and integration tests.

Opening or closing the popup remains presentation-only and does not spend an action or advance tactical revision.
