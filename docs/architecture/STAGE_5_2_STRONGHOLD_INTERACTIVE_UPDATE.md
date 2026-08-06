# Stage 5.2 Stronghold Interactive Update

## Authoritative prototype layout

The first stronghold is an authored 7 × 7 grid. The Fifth-God Heart occupies the true centre at `(3, 3)` as one fixed 1 × 1 facility. The Stables occupy `(2, 5)` through `(3, 6)` as one fixed 2 × 2 facility. Every remaining plot begins `AVAILABLE`.

The Stables replace the former fixed Entrance in the prototype. `StrongholdDefinition.primary_access_coord` identifies the logistics/access anchor without reintroducing a hidden Entrance facility.

## Facility identity

`StrongholdFacilityDefinition` describes authored facility type, footprint, levels and demolition policy. `StrongholdFacilityState` describes one persistent facility instance. Plot states reference the instance ID; the instance references the definition ID.

This separation allows several Storehouses to coexist without causing presentation definitions, upgrades or save records to collide.

## Prototype rule boundary

`StrongholdPrototypeRules` owns temporary conveniences:

- open grid;
- all current facilities unlocked;
- all current upgrades unlocked;
- ignored construction costs;
- instant construction;
- instant upgrades.

The UI does not contain development-only mutation branches. Disabling these rules later retains the same build catalogue, preview and facility-management interactions while ordinary requirements are restored.

## Mutation flow

```
UI intent
→ CampaignSession
→ CampaignChangeSet
→ detached CampaignState candidate
→ StrongholdConstructionService validation/mutation
→ CampaignStateStore validation and persistence
→ authoritative campaign replacement
```

Construction, upgrading and demolition never mutate plot controls directly.

## Rendering

Empty plots draw deterministic illustrated ruin-room textures. Facilities draw once per facility instance across the complete rectangular footprint. Internal plot borders and internal connection markers remain hidden. Build previews use the same complete-footprint presentation contract.
