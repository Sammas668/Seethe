# Stage 5.3G — Persistent Mission Lifecycle Hardening

## Purpose

Stage 5.3G closes the persistent-character round trip before the campaign moves
on to stronghold attacks. The same named recruit must survive one authoritative
lifecycle:

`hire → equip → deploy → resolve mission → recover cargo and captives → gain XP → heal → level up → Prestige → redeploy → die → Memorial`

The central rule is that tactical retirement produces one immutable
`MissionCommitEnvelope`. Character outcomes, item identities, captives,
objectives, XP, injuries and history are not committed through separate paths.

## Authoritative transaction boundary

The campaign root is never mutated directly by tactical presentation code.

1. `MissionResultBuilder` records physical extraction outcomes and exact item
   destinations.
2. `MissionCharacterOutcomeService` adds per-character objective and
   contribution provenance while the tactical event journal still exists.
3. `MissionExperienceAwardService` produces and stores the authoritative XP
   amount and itemised calculation.
4. `MissionRecoverySelectionService` clones the immutable result and removes
   unselected optional cargo or captives. It then rebuilds capture statistics,
   XP and permanent history before the filtered envelope can be saved.
5. `CampaignResultCommitService` applies the complete result to a detached
   `CampaignState` candidate.
6. The candidate is audited against the immutable result.
7. Only a fully valid and successfully persisted candidate replaces the
   authoritative campaign root.

A failed validation, audit or disk save leaves the original campaign unchanged.
A previously applied `result_id` or resolved `mission_id` is a successful no-op.

## Character outcome provenance

Each `MissionCharacterResult` now persists:

- personal mission statistics;
- completed and failed objective IDs;
- itemised XP award lines;
- exact extraction and survival outcome;
- persistent injury entries;
- one immutable history entry.

Initial statistics are:

- `kills`;
- `incapacitations`;
- `captures`;
- `allies_stabilised`;
- `objectives_completed`;
- `objectives_failed`.

Combat and First Aid contributions are reconstructed from the tactical event
journal before the scene is retired. Capture credit comes from each captive's
`captor_character_id`. Recovery selection can therefore remove a captive and
rebuild the captor's statistics, XP and history together.

## XP authority

Only a persistent player character who was deployed, survived, physically
extracted and was not captured receives mission XP.

The first Stage 5.3G award schedule is:

- Victory: 100 XP;
- Withdrawal: 50 XP;
- completed objective: 25 XP each;
- kills: 5 XP each, capped at 50;
- incapacitations: 5 XP each, capped at 50;
- returned captives: 10 XP each, capped at 30;
- successful ally stabilisations: 5 XP each, capped at 25.

The result stores both the total and breakdown. Context validation recalculates
both before campaign commitment. Presentation never invents or mutates XP.

## Item identity and ownership

Every item keeps one stable `item_id` from mission setup or tactical provenance
through campaign commitment.

- Returning equipped, belt and Backpack items retain the extracting character's
  exact container and grid position.
- Newly acquired mission items remain distinct from outbound equipment.
- Selected optional loot and selected captives are committed in the same
  candidate transaction.
- Unselected optional items become abandoned.
- Items on dead or unrecovered characters do not return automatically.
- Lost and consumed outbound items must be absent from the candidate campaign.
- Armour that is recoverable strategically returns serviceable under the
  existing armour rule.

The post-application audit compares definition, quantity, condition and final
location for every extracted item and rejects any mismatch.

## Health, injuries, absence and death

Mission extraction assigns persistent readiness outcomes:

- extracted below full health or with nonlethal damage: the result is shown as
  Wounded, while exact current HP and nonlethal damage remain authoritative;
- extracted in a critical/body state: the result is shown as Gravely Wounded,
  while exact persistent health remains authoritative;
- alive but not extracted: `Missing / Unrecovered`;
- dead: permanent `is_dead` state.

Generic Wounded and Gravely Wounded labels are not added as lasting injuries.
Authored injury entries remain separate and persist when supplied by mission
rules. Missing characters stay in the campaign record and history but cannot
deploy. Dead persistent characters remain available to the Memorial
presentation and do not receive XP. A troop's current HP and nonlethal damage
continue through the normal strategic recovery system.

## Mission summary

The committed mission summary shows, per deployed troop:

- outcome;
- XP total;
- personal kills, incapacitations, captures and stabilisations when non-zero;
- XP award breakdown;
- immediate `LEVEL UP AVAILABLE` status based on the committed character state.

Recovered new loot is still separated from automatically returned squad
equipment.

## Pending-recovery migration

Pending recovery files written before Stage 5.3G have no per-character
statistics or XP breakdown. On load, the immutable setup and result are used to
normalise:

- objective lists;
- selected-captive contribution;
- authoritative XP and breakdown;
- permanent history.

Personal combat contributions cannot be reconstructed after an older tactical
scene has been retired, so those legacy fields default to zero. The normalised
envelope is saved back before recovery continues.

## Recruitment and Prestige invariants retained

Stage 5.3G does not alter the final Stage 5.3F rules:

- hiring is instant through the Roster recruitment market;
- candidates are generated from protagonist classes;
- the market refreshes every 30 campaign days;
- Barbarian Henchman → Marauder requires Muster Hall I;
- later Reaver tiers require their authored Warcamp level;
- Level, XP, ordinary class progression, learned feats, abilities, spells,
  equipment, injuries and history remain through Prestige;
- only the previous active troop Tier's starting feats and associated Tier
  parameters are replaced by the new Tier's starting package.

## Acceptance tests

The included Stage 5.3G integration test covers:

- two extracted troops carrying different authored mission items;
- stable item ID and carrier-location persistence;
- wounded extraction and persistent history;
- dead unrecovered troop and Memorial death state;
- alive unrecovered troop remaining unavailable;
- itemised XP and exact-once retry;
- pending-result and post-commit save round trips;
- recovery deselection rebuilding cargo, captive credit, XP and history;
- a forced repository save failure leaving the authoritative campaign unchanged;
- migration of a pre-Stage-5.3G pending result.

The runtime test entry point is:

`res://tests/integration/run_stage_5_3g_tests.gd`

## Stage 5.3G1 recovery-capacity addendum

The former rule that optional recovery used cumulative unused Light Load has
been superseded. Post-mission recovery now uses each conscious extracting
survivor's remaining resolved maximum carried load. See
`STAGE_5_3G1_RECOVERY_CAPACITY_CORRECTION.md` for the authoritative formula,
visible breakdown and regression tests.
