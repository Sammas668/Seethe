# Stage 4.7 — Starter Troop and Enemy Content

Stage 4.7 replaces the farm raid's prototype tactical actors with the first production-ready Reaver followers and Life-realm defenders. The protagonist remains an explicitly provisional fixed campaign character; class-rank progression and archetype selection are reserved for Stage 5.0f.

## Production roster

The authored raid deploys the provisional Scorned Champion, Hakon Rusk and Svala Thorn against two Settlement Guards, one Settlement Archer, one Patrol Leader, one Novice Mercy-Bearer and two Farmhands.

Every unit is built from a `CharacterTemplateDefinition`, an individual `PersistentCharacterState`, authoritative item instances, the shared `CharacterResolver`, a `ResolvedCharacterSnapshot` and finally `TacticalUnitState`. Mission placement selects identities and positions but does not restate statistics.

## Tier I Marauder

The shared production definition resolves a Human Barbarian 3 with 32 HP, AC 14, Initiative +1, BAB +3, Fortitude +4, Reflex +1, Will +1, 80 ft turn capacity, a 40 ft Half Action and a 120 ft Sprint. Mace attacks resolve to +5 and 1d6+2 blunt damage.

`Take Them Alive` removes the ordinary nonlethal penalty and lets an eligible adjacent helpless target be Restrained with a Quick Action through the shared body-action handler. `Raider's Burden` adds four effective Strength only to carrying calculations. Rage remains a shared character modifier and explicitly contributes to Manoeuvre and Manoeuvre Defence.

Hakon and Svala have separate persistent IDs, equipment instances, XP, injury, history and permanent-death fields while sharing one troop definition.

## Life-realm roles

- Farmhands are world-controlled civilians and witnesses rather than weak enemy combatants.
- Settlement Guards are defensive melee units with spear and shield equipment.
- The Settlement Archer has a bow, arrows, melee fallback and ranged-defender AI metadata.
- The Patrol Leader emphasises perception, initiative, alert coordination and defensive command.
- The Novice Mercy-Bearer uses one medical satchel through the shared body-action system before defaulting to its weak staff attack.

Player units never receive Enemy Turns. Enemy combatants are AI-controlled. Farmhands remain world-controlled.

## Equipment and calculations

Weapons and shields are persistent item definitions and instances. The Settlement Shortbow declares an arrow ammunition tag and consumes one arrow in the same attack transaction; rollback restores ammunition when the attack transaction fails.

The tactical character sheet displays role, troop tier, classification, AI profile, Reaction state, Manoeuvre, Manoeuvre Defence, proficiencies, role tags and the separate carrying calculation. This information is added inside the existing scrollable management window; `tactical_screen.tscn` is unchanged.

Attack preview and committed combat events continue to use the same resolved calculation records rather than independent UI totals.

## Validation

Static content validation:

```text
python tests/content/validate_stage_4_7_character_content.py --project .
```

Stage validation without a Godot executable:

```text
python tools/testing/run_stage_4_7_validation.py --skip-runtime
```

Runtime integration test:

```text
Godot_v4.7.1 --headless --path . --script res://tests/integration/run_stage_4_7_tests.gd
```

## Deferred work

The protagonist's level 1–3 progression, XP application, class-rank allocation, archetype choice and campaign character builder are not part of Stage 4.7. Final morale behaviour, full civilian routines and a complete spell catalogue also remain later milestones.
