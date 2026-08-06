# Stage 4.0 — Practice Dummy Combat

## Purpose

Stage 4.0 proves that the persistent-character, resolved-statistic, equipment, tactical transaction and event-journal foundations can support a real attack without expanding into full combat.

## Implemented sequence

```text
select supported equipped melee attack
→ query legal targets
→ highlight the Practice Dummy
→ preview attack, AC, chance, damage and capacity
→ choose Power Attack 0–3
→ confirm against the preview revision
→ roll d20
→ resolve natural 1 / natural 20
→ confirm a critical threat
→ roll damage
→ stage action expenditure and HP change
→ validate and commit once through TacticalStateStore
→ publish one structured combat event
```

## Supported attacks

| Attack | Normal bonus | Damage | Critical | Cost |
|---|---:|---:|---:|---:|
| Raider's Axe | +5 | 1d8+2 slashing | 20/×3 | 40 ft |
| Mace — Lethal | +5 | 1d6+2 blunt | 20/×2 | 40 ft |
| Dagger | +5 | 1d4+2 piercing/slashing | 19–20/×2 | 40 ft |

Mace and Dagger attacks become available only while the corresponding item is in a hand. Mace nonlethal and thrown Dagger remain deliberately excluded.

## Preview authority

`AttackPreviewQuery` is shared by highlighting, UI preview and execution revalidation. It verifies:

- current player phase;
- player-controlled attacker;
- hostile and active target;
- supported melee action;
- attack granted by an equipped hand item;
- sufficient action capacity;
- target inside authored melee reach;
- expected tactical revision.

The preview reports the final attack bonus, target AC, exact d20 hit probability including automatic 1 and 20 rules, critical profile, damage notation, range, action cost and remaining capacity.

## Resolution and transaction

`AttackHandler` rolls before mutation, then creates one `TacticalChangeSet` containing:

1. payment of the authored Half Action cost;
2. application of final lethal damage;
3. post-mutation validation;
4. structured journal publication after a successful commit.

A miss still spends the action. A failed or stale commit changes neither capacity nor HP. Stage 4.0 clamps HP to zero but does not remove the target or create a death state.

## Criticals

- Natural 1 always misses.
- Natural 20 always hits and threatens.
- Other rolls threaten when they fall within the weapon's critical range and hit.
- Confirmation uses another d20 with the same final attack bonus against the same AC.
- A confirmation natural 1 fails and natural 20 succeeds.
- Confirmed criticals multiply total resolved damage by the authored weapon multiplier.

## Power Attack and Rage

Power Attack is selected from 0 to 3. Each point applies −1 to the attack roll and +1 to damage. Rage continues to use the shared character modifier and resolution pipeline; no combat-only duplicate values are introduced.

## Structured event record

The committed event contains:

- attacker, target, action and source item IDs;
- attack d20 and modifier records;
- optional critical-confirmation roll;
- damage dice and modifiers;
- natural-1, natural-20 and critical metadata;
- target HP before and after;
- action capacity before and after;
- Power Attack and damage type.

## Deterministic testing

`TacticalDiceRoller` supports both seeded random generation and exact scripted outcomes. The Stage 4.0 suite tests normal hits, natural 1, natural 20 with confirmation, Power Attack, Rage, equipment-granted attacks, legal-target highlighting, one-revision commits and structured log output.

## Explicitly deferred

- nonlethal damage and unconsciousness;
- enemy turns and AI;
- downed, death, corpses and victory;
- reactions and opportunity attacks;
- stealth transitions;
- ranged attacks and ammunition;
- area attacks;
- restraint and capture;
- generated loot;
- multiple-target or iterative Full Attacks.
