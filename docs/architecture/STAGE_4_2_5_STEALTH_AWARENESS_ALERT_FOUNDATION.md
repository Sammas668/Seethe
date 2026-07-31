# Stage 4.2.5 — Stealth, Awareness and Alert Foundation

> **Range revision:** Stage 4.2.5.3 supersedes the sight, focused-cone and close-awareness distances recorded here.


## Implemented player loop

Stage 4.2.5 establishes the first complete infiltration-to-combat transition:

1. The mission begins in side-based mode. All player units share the Player Team Phase.
2. A player-controlled unit may spend its Quick Action to **Enter Stealth** from the Tactics menu whenever it is outside every guard's current perception.
3. A hidden player token displays a compact robber-mask badge.
4. Known unaware guards use a wall-blocked 90-degree focused vision cone plus a 10-foot close-awareness area.
5. Existing movement colours remain authoritative for movement capacity. A risky hovered destination adds a die-and-mask badge showing the exact known chance to **avoid detection**.
6. Movement resolves one Stealth check against all relevant visual observers on the continuous route.
7. Success preserves the mask. Failure reveals that unit to the detecting squad, gives that squad eye badges and changes tactical play to individual initiative.
8. The triggering action finishes before initiative begins. Already-spent normal capacity, Quick Actions and Reactions are preserved for the contact round.
9. The top-right controls hint is replaced by the initiative order while combat is active.
10. An aware guard targets the closest hostile currently revealed to its own squad. If no hostile remains revealed, it searches the squad's Last Seen Position and then returns toward its prior assigned task.
11. A detected character may re-enter Stealth later by breaking every guard's current perception and spending an available Quick Action.

## Deliberately binary awareness

Enemy squad awareness has only two values:

- `UNAWARE`
- `AWARE`

Search is an AI task, not another awareness state. An aware squad remains aware while it moves to a Last Seen Position or returns to its guard post.

Player knowledge is relative to each squad:

- currently revealed to that squad;
- not currently revealed to that squad.

A separate Last Seen Position stores where an aware squad last had visual contact. It does not expose the hidden unit's live location. There are no Suspicious or Investigating awareness states and no suspected-location markers.

## State ownership

- `TacticalSquadState` owns binary awareness, stable member IDs and Last Seen Positions.
- `TacticalUnitState` owns facing, whether Stealth is enabled, the squad IDs to which the unit is currently revealed and its assigned prior-task position.
- `TacticalPhaseState` owns side-based versus initiative mode, initiative order, totals, active index and contact-round state.
- `TacticalDetectionService` calculates previews, resolves visual checks, removes exact revelation when sight is lost and prepares atomic alert results.
- `StealthHandler` permits initial entry or re-entry only when no enemy squad currently perceives the unit and the Quick Action is available.
- Presentation reads committed state. Token badges never author awareness or revelation.

This relative-revelation model prevents an aware squad from targeting player units that another squad discovered, and prevents AI from reading a hidden unit's real coordinates after line of sight is broken.

## Perception rules in this slice

Unaware guards use:

- a focused 90-degree cone;
- a 10-foot all-around close-awareness area;
- wall-blocked line of sight;
- focused range of `60 ft + 5 ft × (Passive Perception − 10)`, minimum 15 ft;
- near/normal/far bands, with +2/0/−2 to the effective Detection DC;
- a +4 Detection DC bonus inside the 10-foot close-awareness area.

Close awareness is not automatic detection. A unit already in Stealth makes the same check used elsewhere:

`d20 + Stealth modifier >= effective Detection DC`

Moving through a guard's perception while not in Stealth remains automatic detection. The preview therefore displays 0% chance to avoid detection and crosses the mask symbol until the unit enters Stealth.

The displayed percentage counts the d20 faces that succeed. It is always the chance to **avoid detection**, not the chance to be detected. Skill checks do not use automatic success or failure on natural 20 or natural 1.

The complete 3.5e skill-rank implementation is not yet present. The resolved authored Stealth bonus is used when available; Dexterity modifier remains the explicit fallback.

## HUD contract

Always visible when applicable:

- robber-mask badge on a player token currently in Stealth and hidden from all squads;
- eye badge on known members of an aware enemy squad;
- active-initiative ring on the current unit;
- current mode, round and active initiative unit in the existing phase area;
- horizontal turn order in the existing top-right hint area during initiative combat.

Contextual:

- hover a visible enemy or hold `V` to show known guard perception tiles;
- hover a risky movement destination to show a small d20 symbol, the same robber-mask language used on hidden tokens and the percentage chance to avoid detection;
- close-awareness tiles remain a stronger-coloured part of the visual overlay but still use a roll;
- the existing contextual inspector explains Stealth bonus and effective Detection DC;
- the combat log records the resolved check and newly aware squad;
- a short red screen flash marks the transition without stopping play.

## Re-entering Stealth

Detection breaks the unit's current Stealth state and removes its mask. Detection does not permanently forbid that character from hiding again.

`Enter Stealth` becomes available again when all of the following are true:

- the character is the active player unit;
- it has an available Quick Action;
- no enemy squad currently has a valid perception line to its tile.

Re-entering Stealth removes the unit's exact live position from squads that had revealed it. Those squads retain their Last Seen Position and search that location instead.

## Alerted AI contract

The initial aware AI remains deliberately small and deterministic:

1. Filter hostile units to those currently revealed to the acting guard's squad.
2. Choose the target with the lowest path cost to a legal attack position.
3. Break ties by stable unit ID.
4. Attack immediately when legal.
5. Otherwise move to a legal attack position while preserving the attack cost, then attack.
6. Otherwise move as far as affordable toward that position.
7. If no hostile is currently revealed, choose the nearest Last Seen Position owned by the squad.
8. Move to that tile or a legal adjacent inspection tile.
9. Refresh perception after moving; attack immediately only if a hostile is reacquired and already attackable.
10. If the Last Seen Position is reached without reacquiring anyone, clear that memory.
11. With no revealed hostile or Last Seen Position, move back toward the unit's assigned prior-task position.

The planner does not yet seek cover, flank, focus wounded targets, coordinate multi-guard searches, protect objectives or evaluate spells.

## Contact-round rule

Entering initiative does not refresh any participant. A unit retains exactly the normal capacity, Quick Action and Reaction it had after the triggering action. When initiative wraps to the next complete round, all participants refresh normally.

## Deferred work

- noise and acoustic propagation;
- authored patrol routes and guard rotation schedules beyond the current return anchor;
- doors and quiet/forceful interactions;
- ranged combat-position planning;
- alarms and information transfer between squads;
- coordinated search patterns and search durations;
- returning from initiative combat to side-based mode;
- full 3.5e skill ranks and conditional Stealth modifiers.
