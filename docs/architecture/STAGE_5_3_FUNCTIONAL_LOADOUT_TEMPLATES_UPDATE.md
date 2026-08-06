# Stage 5.3 — Functional Equipment Preparation and Loadout Templates

## Purpose

Turns the Xenonauts-inspired Equip Troops presentation into a functional Seethe preparation workflow while retaining exact persistent item identity.

## Authority boundaries

- `CampaignState` owns characters, exact item instances, locations, spatial positions, rotation, player templates and template preferences.
- `StrategicEquipmentService` validates slots, proficiency, two-handed conflicts, carrying capacity and spatial placement.
- `InventoryService` performs authoritative item-location mutations.
- `LoadoutService` resolves authored or player template rules against actual available item instances and never owns equipment.
- `CharacterProgressionService` previews and commits one authored Level at a time.
- Presentation creates requests and previews only; it does not directly edit campaign records.

## Functional equipment screen

- exact numerical statistics replace unexplained bars;
- candidate equipment previews compare resulting statistics and carried weight;
- armour uses an exact-instance selector;
- hands support click and drag assignment with two-handed linking;
- Belt and Backpack reuse the tactical spatial-grid rules;
- item positions and rotation survive save/load and are copied into mission setup;
- auto-pack, clear, return-all, undo and screen-open restoration reduce repetitive work;
- the same loadout-status validator supports equipment preparation and deployment readiness.

## Progression

Troop Tier and individual Level remain separate. The UI queries authored progression data, shows automatic gains and any talent choice, then commits one Level atomically. Several pending Levels resolve in sequence.

## Templates

A template is a campaign-persistent set of rules, not a set of item references. It can request exact personal items, definitions, tags, quantities, containers, positions, rotation and substitution behaviour. Applying a template resolves real item instances, previews shortages, then commits through the existing equipment and inventory services.

Authored templates are immutable. Players may duplicate them, create blank templates, save a current loadout, update player templates, change substitution policy and apply a template to one character or a compatible troop group.
