# Stage 4.7 Hotfix 1 — Approved Character-Sheet Fidelity

## Purpose

Stage 4.7 created the production content pipeline but substituted simplified generic roles for several already-approved Life-realm sheets. This correction retains the pipeline and replaces production use with exact authored definitions.

## Production roster

The farm raid now uses the provisional protagonist, two persistent Tier I Marauders, two Sanctuary Spear Guards, one Sanctuary Archer, one Mercy-Bearer and two Farmhands. The invented Patrol Leader and the Adept-style novice healer are not registered or placed in the production mission.

## Approved sheets

### Tier I Marauder — Human Barbarian 3

Resolved chassis: STR 15, DEX 12, CON 14, INT 10, WIS 12, CHA 10; HP 32; AC 14; Initiative +1; BAB +3; Fortitude +4; Reflex +1; Will +1; turn capacity 80 feet; Half Action threshold 40 feet; Sprint 120 feet. The Mace resolves at +5 for 1d6+2 blunt damage and supports lethal or nonlethal selection.

Power Attack requires `feat.power_attack`. **Superseded by Hotfix 4:** Rage is a Quick Action with one mission use and a seven-round duration. The corrected Rage package is resolved through `effect.rage`; ending it causes encounter Fatigue. Take Them Alive removes the ordinary suitable-weapon nonlethal penalty and uses the existing Quick Action restraint path. Raider's Burden adds four effective Strength only to carrying capacity.

### Sanctuary Spear Guard — Human Warrior 1

Resolved chassis: STR 14, DEX 10, CON 14; HP 10; AC 16; BAB +1; Fortitude +4; Reflex +0; Will +0. Capture Spear: +3, 1d6+2 nonlethal. Sanctuary Blackjack: +4, 1d6+2 nonlethal. Weapon Focus applies only to the Blackjack. Subdual Takedown marks a successfully struck target for the approved +2 next Grapple, Trip or Shove modifier during that activation. Brace, Grapple, Trip, Shove, Restrain and First Aid are shared authored actions.

### Sanctuary Archer — Human Warrior 1

Resolved chassis: STR 10, DEX 14, CON 12, WIS 12; HP 9; AC 15; Initiative +2; BAB +1; Fortitude +3; Reflex +2; Will +1. Capture Bow: +4, 1d6 nonlethal, 60-foot increment, padded ammunition. Sanctuary Blackjack: +1, 1d6 nonlethal. Patient Overwatch changes the normal Overwatch modifier to -1, producing the approved +3 reaction attack. Padded arrows are authoritative inventory and are consumed only by a committed shot.

### Mercy-Bearer — Human Cleric 3

Resolved chassis: STR 12, DEX 10, CON 14, WIS 16, CHA 14; HP 24; AC 17; BAB +2; Fortitude +5; Reflex +1; Will +6. Sanctuary Blackjack: +3, 1d6+1 nonlethal. Equipment includes the approved breastplate profile, Cradling Shield, field kit, manacles and divine focus.

The authored package includes Combat Casting, Augmented Healing, Spell Focus — Compulsion, Mercy Intercession, Cure Light Wounds, Cure Moderate Wounds, Command: Kneel, Sanctuary, Hold Person, Mercy's Rebuke, Guidance, Resistance, Detect Poison and Light. Ability costs, resources, ranges, DCs, healing/damage dice and timed conditions are held in `TacticalAbilityDefinition` resources and committed through `TacticalAbilityService`.

Mercy Intercession uses the existing reaction resource and reduces eligible incoming lethal damage by 1d8+3 before final HP application. The current farm Mercy-Bearer is AI-controlled, so this release resolves the available intercession deterministically through the AI reaction path rather than adding a second player-prompt architecture.

## Authority and validation

`content/characters/specifications/stage_4_7_approved_sheets.json` is the immutable conformance fixture. It does not replace the runtime character system. The static validator checks authored resources, catalogue registration, farm mission references, forbidden substitute references and required mechanical hooks. The Godot integration test resolves all four sheets in an authored mission session and checks exact statistics, attacks, resources, Rage transitions and controller ownership.

## Deferred content

The Warden, Green Steward and Reckoner remain deferred until an authored mission needs their approved sheets. The old generic substitute resources may remain in the repository for historical reference but are unregistered and unused in production content.

## Runtime requirement

Run `res://tests/integration/run_stage_4_7_hotfix_1_tests.gd` in Godot 4.7.1 before marking the hotfix runtime-locked.
