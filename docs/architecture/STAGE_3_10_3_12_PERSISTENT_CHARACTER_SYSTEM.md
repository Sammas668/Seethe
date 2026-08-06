# Stage 3.10–3.12 Persistent Character System

## Architectural rule

A tactical unit is not the character definition. It is a mission-local deployment of a named character whose rules have been resolved from authored and persistent sources.

```text
CharacterTemplateDefinition
        +
PersistentCharacterState
        +
Equipment / defence profile
        +
Injuries and progression
        +
Active CharacterModifierDefinition resources
        ↓
ResolvedCharacterSnapshot
        ↓
TacticalUnitState
```

This pipeline is identical for player characters, enemies and neutrals. Their role and persistence scope are data, not separate class hierarchies.

## 1. Authored template

`CharacterTemplateDefinition` is a Godot `Resource`. It describes one reusable type such as Tier I Reaver Marauder, Settlement Guard or Farmhand. It contains base ability scores, level, BAB, save bases, HP components, movement, perception, carrying capacity, default defence, innate actions, skills, ability descriptions, default loadout definitions and visual references.

Templates are identity-free. A template may say that a Marauder starts with a Raider's Axe, but it may not contain the persistent ID of a particular axe. `validate_definition()` rejects an `instance_id` authored inside a template loadout.

## 2. Persistent individual

`PersistentCharacterState` represents one named person or creature. Important fields include:

```text
character_id
template_id
display_name
faction_id
team_id
roster_role
persistence_scope
xp
level_adjustment
ability_adjustments
stat_adjustments
equipped_defence_profile_id
loadout_entries
injury_entries
permanent_condition_entries
history_entries
trait_entries
deployment_count
is_dead
```

The character factory turns template loadout entries into unique item instances derived from the character ID. Two Marauders therefore share one template but never share the same axe, dagger, injury list, XP total or history.

## 3. Roles and persistence scopes

Roles:

- `player`
- `enemy`
- `neutral`

Persistence scopes:

- `campaign` — saved until removed or killed.
- `region` — saved and suitable for recurring local NPCs or enemies.
- `mission` — generated for the current mission and omitted from the roster save.

`CharacterFactory.create_player_character`, `create_enemy_character` and `create_neutral_character` are convenience entry points into the same generic `create_character` function.

## 4. Resolution

`CharacterResolutionService` loads the template, defence profile, item definitions and active modifiers, then delegates to `CharacterResolver`.

Every important value is a `ResolvedStat` containing `StatModifierLine` entries. The final value is the sum of those lines. For example:

```text
Armour Class 14
Base                         +10
Dexterity                     +1
Patchwork Raider Armour       +3
```

Rage is represented as a `CharacterModifierDefinition`. Activating it adds source lines and triggers a complete re-resolution. Because HP, saves, attacks and other values derive from ability scores, one modifier changes every dependent statistic consistently.

## 5. Tactical deployment

`TacticalCharacterDeploymentService.deploy_character()`:

1. Resolves the character.
2. Creates a `TacticalUnitState` using the persistent character ID.
3. Copies team, faction, role, scope and footprint from the snapshot.
4. Initializes mission HP and action capacity.
5. Creates tactical item states from the individual's persistent loadout.
6. Adds deployment history to the character.

`TacticalUnitState` retains map position, current HP, spent capacity, Quick Action, Reaction, active mission modifiers and tactical inventory. Re-resolution preserves damage and spent action state.

## 6. Character Sheet compatibility

The scene file `presentation/tactical/unit_management_window.tscn` was not redesigned or replaced. `TacticalCharacterSheetState` is now only an adapter over `ResolvedCharacterSnapshot` for old presentation calls.

The existing Character Sheet panels show resolved values. Links within the existing RichTextLabels expand and collapse modifier lines. Ability score labels use tooltips for their source breakdowns. No rule calculation occurs in the UI.

## 7. Save/load

`CharacterRosterRepository` writes JSON to:

```text
user://seethe_stage_3_12_character_roster.json
```

The serializer explicitly converts `StringName` item IDs and `Vector2i` inventory positions into JSON-compatible values, then rebuilds them on load. Mission-scoped characters are excluded. Campaign- and region-scoped characters retain identity and equipment instance IDs across redeployment.

Inventory transfers update the persistent loadout and save the roster. Character systems that later award XP, create injuries, change levels or mark death should mutate `PersistentCharacterState` through an application service and call the repository's `save_roster()` or the tactical persistence service's `save_now()`.

## 8. Current sandbox examples

Player campaign characters:

- Hakon Rusk — Tier I Reaver Marauder.
- Elira Venn — prototype Archer.
- Mara Quill — prototype Scout.

Mission-generated non-player examples:

- Generated Settlement Guard — enemy.
- Generated Farmhand — neutral.

The enemy and neutral units are placed away from the starting squad and are not included in player activation order. They can be inspected through the same Character Sheet but cannot be moved or have inventory manipulated during the player phase.

## 9. Extension contract

To add another player troop, enemy or neutral:

1. Create a `CharacterTemplateDefinition` `.tres` resource.
2. Register it in the content catalogue.
3. Generate a `PersistentCharacterState` with the desired role and scope.
4. Add the individual to the appropriate roster.
5. Deploy it through `TacticalCharacterDeploymentService`.

No tactical unit-specific stat block or separate enemy character class is required.

## 10. Deliberately deferred

This stage stores XP and level adjustment but does not define final XP thresholds or class progression tables. It stores injuries but does not yet create them from combat results. It authors Marauder attacks and their sheet calculations, but Stage 4.0 remains responsible for target selection, attack rolls, damage application, critical resolution and nonlethal defeat.
