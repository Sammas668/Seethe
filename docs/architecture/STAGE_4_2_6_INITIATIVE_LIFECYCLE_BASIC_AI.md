# Stage 4.2.6 — Initiative Lifecycle and Basic AI Completion

## Purpose

Stage 4.2.6 formalises the transition from side-based infiltration to stable
unit-by-unit initiative combat. It preserves the existing binary awareness,
per-squad revelation, Stealth, facing and Last Seen Position rules.

## Initiative lifecycle

`TacticalPhaseState` now distinguishes active-round participants from units that
have rolled initiative but must wait until the following round. A newly aware
squad is presented immediately in the turn-order HUD as **Joins Next Round**.
It does not interrupt a partially completed round with a fresh activation.

The contact round preserves every participant's existing action budget. At the
first full-round boundary, normal capacity, Quick Actions, Reactions and ordinary
attack allowance refresh together. Initiative ties resolve by:

1. higher final initiative total;
2. higher Initiative modifier;
3. higher Dexterity score;
4. stable unit ID.

Defeated, incapacitated or missing participants are removed before they can act.
Removing the active unit advances to the next legal participant and performs the
round boundary exactly once when the removed unit occupied the last slot.

## Squad-limited joining

Contact initiative includes every active player character, including characters
that remain hidden, plus members of the detecting squad or enemy squads already participating in the
current combat. Persistent awareness alone never pulls a distant squad into an
unrelated encounter. Joining initiative does not add revelation. AI target selection continues to
receive only hostiles revealed to its own squad.

## Combat ending and search

Squad awareness remains binary. Searching is a bounded behaviour represented by
`search_rounds_remaining` on an Aware squad.

When an aware squad loses every revealed target but retains a Last Seen Position,
it searches that historical position for a limited number of initiative rounds.
If no target is reacquired before the duration expires, initiative ends and the
mission returns to the side-based Player Team Phase. The squad remains Aware and
retains Last Seen Position history. During its next side-based Enemy Team Phase,
the simple planner returns members toward their authored task positions.

## Basic enemy planners

The current vertical-slice planners deliberately remain simple:

- melee guard: closest revealed reachable hostile; attack now, move-and-attack,
  or approach;
- settlement archer: fire from the current legal position, otherwise approach a
  legal firing position;
- searching guard: move toward the best Last Seen Position;
- returning guard: move toward `assigned_task_position`.

Advanced cover evaluation, flanking, retreat, formations and coordinated focus
fire remain outside this stage.

## Ranged attack support

The generic attack preview accepts authored normal ranged weapon attacks. It
checks maximum range, shared line of sight, and applies the familiar -2 penalty
for every range increment after the first. The detailed roll log includes that
penalty. The first settlement-archer character template uses the Training
Shortbow through the same data-driven action pipeline as player weapons.

## Regression coverage

`Stage426InitiativeLifecycleAITests` covers:

- contact-round preservation and full-round refresh;
- deterministic ties;
- next-round squad joining without hidden-unit revelation;
- incapacitated and removed participant safety;
- melee and ranged planners;
- five combat rounds with two player characters and two enemy squads;
- clean combat termination after bounded searches.
