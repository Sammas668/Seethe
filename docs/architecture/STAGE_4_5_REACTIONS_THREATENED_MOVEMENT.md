# Stage 4.5 — Reactions and Threatened Movement

## Final Detailed Design and Implementation Brief

**Starting build:** Stage 4.4e3b2
**Milestone purpose:** Complete Seethe’s shared Reaction framework through Attacks of Opportunity, Disengage, Overwatch and Brace while preserving the responsive movement, Stealth-preview and presentation improvements established during Stage 4.4.

The Tactical Rules Bible defines Reactions as actions taken outside a unit’s turn in response to explicit triggers. Units normally receive one Reaction, shared between Attacks of Opportunity, Overwatch, Brace and later abilities such as Counterspell, Intercept and Guard Ally. Reactions must use the same event, attack, perception and presentation systems rather than becoming separate ability-specific implementations. 

---

# 1. Milestone goals

Stage 4.5 must deliver four connected packages:

## Stage 4.5a — Shared Reaction Pipeline

Implement:

* authoritative Available, Reserved and Spent states;
* correct Reaction refresh;
* trigger-event collection;
* Interrupt, Movement Interrupt and Response timing;
* deterministic priority;
* reaction ownership by the current controller;
* player Reaction decision requests and prompt resolution;
* reaction previews and combat-log records;
* save/load and snapshot migration.

## Stage 4.5b — Attacks of Opportunity and Disengage

Implement:

* threatened spaces;
* leaving-threat triggers;
* provoking actions;
* opportunity attacks;
* movement continuation and interruption;
* Disengage;
* diagonal reach legality;
* perception and incapacity restrictions.

## Stage 4.5c — Overwatch and Brace

Implement:

* directional reservation areas;
* Reaction reservation;
* Overwatch with a **bow icon**;
* Brace with a spear icon;
* first-valid-trigger decision behaviour;
* player Fire/Hold and Brace/Hold prompts;
* attack modifiers;
* cancellation rules;
* infiltration preservation;
* AI preparation and triggering.

## Stage 4.5d — Reaction Readability and Performance Lock

Implement:

* clicked-path reaction previews;
* centre-tile tactical badges;
* icon with percentage underneath;
* hidden-target interaction;
* readable Use/Decline and Fire/Hold prompts;
* roll-log detail;
* immediate hit feedback;
* AI use;
* performance safeguards;
* regression tests.

---

# 2. Intended player experience

The player-facing movement sequence should be:

```text
Hover destination
→ ordinary tile highlight only

First left-click
→ path locks
→ movement cost appears
→ Stealth and known reaction risks appear
→ no movement occurs

Second left-click
→ movement begins
→ each path step resolves authoritatively
→ a viable player-controlled Reaction pauses the triggering event
→ the player chooses Use/Decline or Fire/Hold
→ selected reactions occur at the correct spatial moment
→ movement continues or stops
```

The player should understand:

* what reaction is threatening a step;
* which enemy can perform it;
* the predicted chance that it hits;
* whether the mover is currently hidden from that enemy;
* where along the route it triggers;
* whether the reactor’s Reaction is Ready, Reserved or Spent;
* whether using the Reaction is optional;
* what is preserved when the player declines or holds;
* why movement continues or stops afterward.

Reactions must make positioning consequential without returning the tactical loop to constant pauses or irrelevant confirmation windows. A prompt is justified when a genuine optional Reaction becomes legal during another unit’s action. The game must not ask when no legal choice exists, when the Reaction is mandatory, or when the reacting unit is AI-controlled.

---

# 3. Locked Reaction resource

## 3.1 Authoritative states

Replace the current boolean-only representation with:

```gdscript
enum ReactionResourceState {
	AVAILABLE,
	RESERVED,
	SPENT,
}
```

Meaning:

```text
AVAILABLE
The unit may use an immediate Reaction or prepare a reservation.

RESERVED
The Reaction is committed to Overwatch, Brace or another prepared effect.

SPENT
The unit cannot react until its Reaction refreshes.
```

The Reaction resource is shared. A unit with Overwatch reserved cannot also make an Attack of Opportunity unless an explicit later feature grants an additional Reaction.

## 3.2 Reservation state

```gdscript
class_name ReactionReservationState

var reaction_definition_id: StringName
var source_unit_id: StringName
var controller_id: StringName
var reserved_weapon_item_id: StringName

var area_kind: StringName
var covered_tiles: Array[Vector2i]
var direction: Vector2i

var created_round: int
var created_activation_id: StringName

var cancellation_tags: Array[StringName]
var presentation_profile_id: StringName
```

The reservation belongs to the Reaction resource rather than to the board or token presentation.

## 3.3 Refresh timing

During initiative combat:

```text
Start of the unit’s turn
→ Reaction refreshes to Available
```

During infiltration:

```text
Start of the unit’s side phase
→ Reaction refreshes to Available
```

The Tactical Rules Bible establishes Reaction refresh alongside normal capacity and Quick Action refresh. Spent Reactions remain spent through the alert/contact-round transition, and a Surprised unit has no Reaction until its first turn. 

## 3.4 Conditions affecting Reactions

A unit cannot react when:

* Dead;
* Dying;
* Unconscious;
* Stunned;
* otherwise unable to perform the required attack;
* unaware of the target;
* unable to perceive the target;
* lacking the required weapon or anatomy.

These restrictions do not require separate stored resource states. They temporarily make the current state unusable and cancel reservations where necessary.

---

# 4. Shared Reaction definitions

```gdscript
class_name ReactionDefinition

var id: StringName
var display_name: String

var trigger_kind: StringName
var timing_kind: StringName
var requires_reservation: bool

var attack_definition_id: StringName
var required_weapon_tags: Array[StringName]
var target_filters: Array[StringName]
var movement_kind_filters: Array[StringName]

var priority_override: int
var once_per_triggering_action: bool
var suppress_reaction_chains: bool = true

var optional_for_controller: bool = true
var explicitly_automatic: bool = false
var decline_policy: StringName

var presentation_profile_id: StringName
```

Initial trigger kinds:

```text
LEAVING_THREATENED_TILE
PROVOKING_ACTION
ENTERING_OVERWATCH_AREA
ENTERING_BRACE_AREA
```

Initial timing kinds:

```text
INTERRUPT
MOVEMENT_INTERRUPT
RESPONSE
```

The Rules Bible distinguishes Interrupts before completion, Movement Interrupts between movement tiles and Responses after a result. It also states that a Reaction cannot normally trigger another Reaction. 

---

# 5. Atomic event architecture

## 5.1 Universal event sequence

Every action capable of triggering a Reaction should use:

```text
Declare
→ Validate
→ Commit costs
→ Open Interrupt window
→ Revalidate
→ Resolve primary event
→ Perform state check
→ Open Response window
→ Perform final state check
→ Continue or end
```

Committed costs are normally not refunded when an Interrupt prevents the action from completing.

## 5.2 Movement must resolve step by step

A confirmed movement path must not be resolved as one indivisible teleport from start to destination.

For every voluntary step:

```text
1. Confirm the next tile remains legal
2. Commit that step’s movement cost
3. Leave the previous tile
4. Resolve leaving-tile Interrupts
5. Revalidate movement
6. Enter the new tile
7. Resolve entering-area Interrupts
8. Resolve hazards and detection
9. Update sight, cover and threat relationships
10. Continue when still legal
```

This is the authoritative sequence in the Tactical Rules Bible. Opportunity attacks occur before the mover enters the next tile. Overwatch and Brace occur after the target enters their triggering tile but before movement continues. 

## 5.3 Movement resolution record

```gdscript
class_name TacticalMovementResolution

var unit_id: StringName
var planned_path: Array[Vector2i]
var committed_path: Array[Vector2i]

var step_resolutions: Array[TacticalMovementStepResolution]
var reaction_resolutions: Array[ReactionResolution]
var detection_resolutions: Array

var final_position: Vector2i
var movement_stopped: bool
var stop_reason: StringName
```

```gdscript
class_name TacticalMovementStepResolution

var step_index: int
var origin: Vector2i
var attempted_destination: Vector2i
var movement_kind: StringName
var cost_feet: int

var leaving_reactions: Array[ReactionResolution]
var entered_destination: bool
var entering_reactions: Array[ReactionResolution]

var detection_result: Variant
var resulting_position: Vector2i
var may_continue: bool
```

The movement tween presents this completed authoritative result. It must never decide whether a Reaction triggers.

---

# 6. Reaction candidate collection

```gdscript
class_name ReactionCandidate

var reaction_definition_id: StringName
var source_unit_id: StringName
var target_unit_id: StringName
var triggering_event_id: StringName

var trigger_origin: Vector2i
var trigger_destination: Vector2i
var timing_kind: StringName

var legal: bool
var invalidity_reason: String
var priority_key: Array
```

A legal optional candidate belonging to a player-controlled unit creates a decision request:

```gdscript
class_name ReactionDecisionRequest

var request_id: StringName
var candidate: ReactionCandidate

var controller_id: StringName
var reacting_unit_id: StringName
var triggering_unit_id: StringName
var triggering_action_name: String

var reaction_display_name: String
var weapon_display_name: String
var predicted_hit_chance: int
var predicted_damage_text: String
var modifier_lines: Array[String]

var use_label: String
var decline_label: String
var decline_keeps_reservation: bool

var created_event_id: StringName
var resolved: bool
```

```gdscript
class_name ReactionDecisionResolution

var request_id: StringName
var choice: StringName
var resolved_by_controller_id: StringName
var candidate_selected: bool
var reaction_state_changed: bool
```

A candidate is legal only when:

```text
Reaction state permits it
AND source is capable of reacting
AND source currently perceives the target
AND target satisfies allegiance and target filters
AND required weapon remains equipped and usable
AND range or reserved area is valid
AND line of sight and line of effect requirements are satisfied
AND the triggering movement or action kind qualifies
```

## Reaction window

```text
Collect candidates
→ discard illegal candidates
→ sort deterministically
→ inspect the first candidate
→ player-controlled optional candidate: create one decision request
→ AI-controlled optional candidate: apply deterministic AI policy
→ mandatory or explicitly automatic candidate: select automatically
→ resolve or decline the candidate
→ perform state check
→ remove candidates whose trigger no longer exists
→ continue until the window closes
```

A later candidate whose trigger is removed is not spent and is not presented.

## Player Reaction decision contract

When a valid optional Reaction belongs to a player-controlled unit:

```text
triggering event reaches the Reaction window
→ authoritative event resolution pauses
→ movement or action presentation pauses at the matching spatial moment
→ one Reaction prompt opens
→ player chooses the offered action or declines/holds
→ the choice is submitted as a Reaction decision command
→ the event queue revalidates the candidate
→ the selected Reaction resolves, or the original event continues
```

The prompt must not be implemented as a presentation-only callback that directly performs an attack. It returns a choice to the shared Reaction pipeline.

The prompt has no countdown in the single-player game.

Default controls:

```text
Left-click the primary button or press Enter
→ use the Reaction

Right-click, Escape or the secondary button
→ decline or hold
```

While a Reaction decision is pending:

* normal tactical input is locked;
* camera inspection and combat-log scrolling may remain available;
* no other unit may begin an action;
* AI processing waits;
* the current movement/action animation remains paused;
* the pending candidate is revalidated after the player chooses.

Declining an ordinary optional Reaction:

* does not spend the Reaction;
* does not execute the attack or effect;
* closes that candidate for the current atomic trigger;
* allows the triggering event to continue;
* does not prompt again for the same candidate during that same trigger.

Holding a reserved Reaction:

* does not spend the Reaction;
* does not spend ammunition;
* keeps the reservation active;
* suppresses repeated prompts against the same target during the same continuous movement action;
* permits a later target, a later re-entry, or a separate movement action to create another valid prompt.

A later candidate whose trigger is removed is not spent and is not presented.

---

# 7. Deterministic Reaction priority

Use the following order:

1. Explicit ability-priority override.
2. Timing category:

   * prevent the triggering event;
   * change target or position;
   * modify a roll;
   * apply damage or a condition;
   * after-result Response.
3. Higher current initiative.
4. Higher Initiative modifier.
5. Higher Dexterity.
6. Fixed encounter tie-break value.

The tie-break must be generated once for the encounter and saved. It must not reroll each time two units compete.

---

# 8. Perception, Stealth and Reaction legality

This is a critical Stage 4.5 rule:

> **A sight-dependent character cannot react to a character it does not currently perceive.**

The existing perception implementation already distinguishes hidden-target detection from ordinary revealed-target sight and stores revelation symmetrically by squad. Stage 4.5 must consume that same authoritative perception state rather than introducing a separate “reaction awareness” calculation. 

## 8.1 Hidden movement

When the mover is hidden from a potential reactor:

* no Attack of Opportunity is generated;
* Overwatch does not trigger;
* Brace does not trigger;
* no reaction warning appears for that reactor;
* Stealth information occupies the tile-centre badge.

A reactor cannot make a Reaction retroactively after the hidden character has already completed the triggering step.

## 8.2 Detection during movement

The movement event order matters:

```text
Enter tile while hidden
→ no Overwatch or Brace from enemies that cannot perceive the mover
→ detection check resolves
→ successful Stealth: remain hidden
→ failed Stealth: become perceived
→ later movement steps may trigger reactions
```

Detection on a tile does not cause an Overwatch shot retroactively on that same entry event.

## 8.3 Alternative senses

A creature may react to a nominally hidden unit when it possesses a sense that:

* currently perceives the unit;
* identifies the exact target or tile;
* permits the required attack.

Blindsight may qualify. A vague sense that only reports general presence may not.

## 8.4 Unalerted enemies

Ordinary unalerted enemies do not use combat Reactions.

The triggering action finishes before alert transition. An enemy does not receive a retroactive Attack of Opportunity or Overwatch shot for movement completed while it was Unaware. 

---

# 9. Stage 4.5a — Shared Reaction Pipeline

## 9.1 Required implementation

Create shared systems for:

* resource state;
* reservation state;
* trigger events;
* candidate collection;
* priority resolution;
* execution;
* cancellation;
* refresh;
* preview;
* logging.

Suggested structure:

```text
domain/tactical/reactions/
    reaction_resource_state.gd
    reaction_reservation_state.gd
    reaction_definition.gd
    reaction_trigger_event.gd
    reaction_candidate.gd
    reaction_resolution.gd

application/tactical/reactions/
    reaction_service.gd
    reaction_candidate_query.gd
    reaction_priority_resolver.gd
    reaction_execution_service.gd
    reaction_preview_query.gd
```

## 9.2 Shared execution context

Reaction attacks must reuse normal attack resolution:

```gdscript
class_name TacticalAttackContext

var action_source: StringName = &"reaction"
var triggering_event_id: StringName

var consumes_normal_capacity: bool = false
var consumes_ordinary_attack: bool = false
var repeated_attack_penalty: int = 0

var reaction_attack_modifier: int = 0
var suppress_reaction_chains: bool = true
```

Do not duplicate:

* hit calculations;
* critical confirmation;
* damage;
* resistance;
* life-state changes;
* cover;
* immediate hit reactions;
* attack logging.

## 9.3 Controller ownership and decision policy

The unit’s current controller decides whether to use an optional Reaction.

Control transfer must preserve:

* Available, Reserved or Spent state;
* reservation;
* triggering event;
* priority position;
* any pending Reaction decision request that already belongs to the new controller.

Locked implementation policy:

```text
Player-controlled Attack of Opportunity
→ prompt: Use Reaction / Decline

Player-controlled reserved Overwatch
→ prompt: Fire / Hold Fire

Player-controlled reserved Brace
→ prompt: Use Brace / Hold Brace

AI-controlled optional Reaction
→ deterministic AI policy with no player prompt

Mandatory or explicitly automatic effect
→ resolve automatically through the same pipeline
```

Only effects whose definition explicitly marks them mandatory or automatic bypass the player prompt.

The player is not asked merely because a unit has a Reaction available. A prompt is created only when a complete legal candidate exists.

## 9.4 Pending decision state

The tactical session must own at most one active player Reaction decision request:

```gdscript
var pending_reaction_decision: ReactionDecisionRequest
```

Opening the request publishes presentation data but does not spend the Reaction.

The UI returns a command such as:

```gdscript
ResolveReactionDecisionCommand
|- request_id
|- controller_id
`- choice
```

The application layer must reject:

* stale request IDs;
* choices from the wrong controller;
* duplicate submissions;
* choices made after the candidate became invalid;
* unsupported choices for the prompt type.

If the candidate became invalid while the prompt was open, the request closes, no Reaction is spent, and the triggering event continues or ends according to the new authoritative state.

## 9.5 Logging

The event journal should record:

```text
Reaction became Available
Reaction reserved: Overwatch
Reaction reserved: Brace
Reaction offered
Reaction used
Reaction declined
Overwatch held
Brace held
Reaction spent
Reservation cancelled
Trigger invalidated; Reaction retained
Reaction refreshed
```

---

# 10. Stage 4.5b — Attacks of Opportunity

## 10.1 Threatened spaces

A creature threatens every tile where it could currently make a legal melee Reaction.

Threats use the same:

* footprint calculations;
* melee reach;
* weapon profile;
* diagonal legality;
* wall and corner blocking;
* perception;
* life and condition state

as normal melee attacks.

Do not implement a separate simplified threat-distance system.

## 10.2 Diagonal threats

Diagonal threats are legal when:

* melee reach covers the target;
* the diagonal gap is not sealed by two solid obstacles;
* line and body geometry permit the attack.

This must match existing diagonal melee legality.

## 10.3 Trigger types

An Attack of Opportunity triggers when a perceived hostile:

1. voluntarily leaves a threatened tile; or
2. performs an action tagged `Provokes` while threatened.

Provoking actions initially include:

* ranged attack while engaged;
* designated spellcasting;
* standing from Prone;
* reloading;
* administering an item;
* complex inventory transfer;
* authored objective interactions.

Use a shared tag:

```gdscript
&"provokes_opportunity"
```

Do not retain unrelated custom booleans in each handler.

## 10.4 Non-provoking movement

The following do not normally provoke:

* forced movement;
* falling;
* teleportation;
* summon arrival;
* five-foot adjustment;
* movement protected by Disengage.

## 10.5 Attack resolution

The Attack of Opportunity:

* spends the reactor’s Reaction;
* makes one melee attack;
* uses the highest normal attack bonus;
* consumes no normal capacity;
* does not consume the normal attack allowance;
* does not take the repeated-attack `−5` sequence;
* cannot trigger an ordinary Reaction chain.

## 10.6 Spatial timing

```text
Mover attempts to leave threatened tile
→ step cost commits
→ mover remains visually on old tile
→ legal player-controlled Attack of Opportunity opens a Use/Decline prompt
→ selected Attack of Opportunity resolves
→ declined Attack of Opportunity retains the Reaction
→ state check
→ mover enters next tile only when still legal
```

## 10.7 Movement continuation

A miss normally allows movement to continue.

A hit also allows movement to continue unless it causes:

* Unconsciousness;
* death;
* Stunned;
* Restrained;
* Immobilised;
* route-invalidating Prone;
* forced displacement;
* loss of a required movement mode.

After the attack:

```text
damage applies
→ red pulse and vibration begin immediately
→ movement is revalidated
→ animation continues or stops
```

## 10.8 Multiple defenders

Several defenders may react to the same leaving event.

They resolve in priority order. If the first reaction incapacitates or removes the mover, later invalidated reactions are not spent.

## 10.9 One defender per movement action

One defender cannot make multiple Attacks of Opportunity during the same continuous movement action after using its Reaction.

A defender that declines a legal Attack of Opportunity is not repeatedly prompted for that same defender-target pair during the same continuous movement action. A later separate movement action may create another prompt while the Reaction remains Available.

## 10.10 Player Attack of Opportunity prompt

Example:

```text
USE REACTION?

Marauder — Attack of Opportunity
Target: Spear Guard
Trigger: Target is leaving your threatened area

Hit chance: 65%
Damage: 1d6+2 blunt
Reaction: Ready → Spent if used

[Use Reaction]    [Decline]
```

Choosing **Use Reaction**:

* revalidates the candidate;
* changes the Reaction to Spent;
* resolves one melee attack;
* applies immediate hit feedback;
* continues or stops movement according to the result.

Choosing **Decline**:

* leaves the Reaction Available;
* performs no attack;
* closes this candidate for the continuous movement action;
* allows the target to enter the next tile.

---

# 11. Disengage

Disengage is a Half Action.

It applies:

```text
Protected from ordinary movement-based Attacks of Opportunity
until the end of the unit’s current turn
```

Disengage does not protect against:

* Overwatch;
* Brace;
* traps;
* hazards;
* explicit Intercept abilities;
* actions that separately have the `Provokes` tag.

Example:

```text
Unit uses Disengage
→ leaves melee without provoking

Unit then reloads while still threatened
→ reload may still provoke
```

AI should use Disengage when retreating from a dangerous melee engagement, repositioning a ranged combatant or preserving a badly injured unit.

---

# 12. Stage 4.5c — Overwatch

## 12.1 Setup

Overwatch is a Half Action that reserves the unit’s Reaction.

Requirements:

* Reaction Available;
* loaded ranged weapon;
* unit capable of acting;
* valid directional area;
* sufficient normal capacity.

Selection flow:

```text
Select Overwatch
→ enter directional targeting mode
→ cursor selects direction
→ cone preview appears
→ left-click confirms
→ Half Action spent
→ Reaction becomes Reserved
```

Right-click or Escape cancels before commitment.

## 12.2 Area

Initial implementation:

* 90-degree directional cone;
* begins at the shooter;
* extends to the first range increment;
* uses current terrain and visibility;
* actual attack legality is revalidated on trigger.

The reservation area does not create persistent ordinary character facing. It belongs to the prepared Overwatch action.

## 12.3 Trigger

Overwatch creates a valid candidate when a perceived hostile voluntarily enters or moves through the reserved area.

```text
Mover enters triggering tile
→ Overwatch candidate is collected
→ sight, effect, weapon and target revalidate
→ player-controlled shooter: Fire/Hold Fire prompt
→ AI-controlled shooter: deterministic AI decision
→ selected shot resolves
→ held shot leaves the reservation active
→ movement continues or stops
```

The first eligible trigger does not force a player-controlled unit to fire. It presents the first valid decision opportunity.

## 12.4 Player Fire/Hold decision

Example:

```text
USE OVERWATCH?

Archer
Target: Guard Warrior
Weapon: Shortbow

Hit chance: 50%
Modifier: Overwatch −2
Ammunition if fired: 1 arrow
Reaction: Overwatch → Spent if fired

[Fire]    [Hold Fire]
```

Choosing **Fire**:

* revalidates the candidate;
* spends the Reaction;
* spends ammunition;
* resolves the shot;
* ends the reservation.

Choosing **Hold Fire**:

* spends no Reaction;
* spends no ammunition;
* keeps Overwatch Reserved;
* keeps the reserved area active;
* suppresses another prompt against the same target during the same continuous movement action.

The same target may create another prompt only after leaving and re-entering the area, or during a separate movement action.

## 12.5 Attack rules

The Overwatch shot:

* receives the standard `−2` attack modifier;
* spends the Reaction when fired;
* spends ammunition when fired;
* ends the reservation;
* cannot create an ordinary Reaction chain.

## 12.6 Exclusions

Overwatch does not trigger from:

* forced movement;
* teleportation;
* falling;
* summon arrival;
* movement the shooter cannot perceive;
* non-movement actions;
* a target that does not enter the reserved area.

## 12.7 Cancellation

Overwatch ends when the unit:

* voluntarily moves;
* changes or loses the reserved weapon;
* reloads or changes weapon state incompatibly;
* loses the perception required to maintain it;
* becomes incapacitated;
* spends the Reaction elsewhere;
* begins its next turn.

When cancelled without firing:

* the Half Action remains spent;
* the Reaction returns to Available only when it has not otherwise been spent;
* the reservation area is removed immediately.

## 12.8 Infiltration

A player unit may prepare Overwatch during infiltration.

It can trigger during the world phase. The shot resolves before alert transition, and its spent Half Action and Reaction carry into the contact round. The Tactical Rules Bible explicitly preserves this infiltration behaviour. 

---

# 13. Stage 4.5c — Brace

Brace is the melee counterpart to Overwatch.

Requirements:

* Reaction Available;
* suitable weapon or explicit trait;
* Half Action;
* valid forward reaction area.

Initial implementation:

* weapons require a `brace_capable` tag;
* the player selects a forward melee sector;
* the first perceived hostile entering the sector creates a valid Brace decision opportunity;
* player-controlled braced units receive a Use Brace/Hold Brace prompt;
* AI-controlled braced units use deterministic AI policy;
* one normal melee attack resolves only when Brace is selected;
* the Reaction is spent and the reservation ends only when the attack is used.

Brace triggers after entry into the triggering tile but before movement continues.

It does not trigger from:

* forced movement;
* falling;
* teleportation;
* summon arrival;
* movement the braced unit cannot perceive.

Choosing **Hold Brace** preserves the reserved Reaction and area, spends nothing, and suppresses repeated prompts against the same target during the same continuous movement action.

Example:

```text
USE BRACE?

Spear Guard
Target: Marauder
Weapon: Spear

Hit chance: 70%
Damage: 1d8+2 piercing
Reaction: Brace → Spent if used

[Use Brace]    [Hold Brace]
```

Additional charge damage, lance multipliers and specialist Brace talents are deferred.

---

# 14. Stage 4.5d — Path-preview visual language

## 14.1 Locked centre-tile badge system

Reaction warnings use the **same layout structure as the existing Stealth warning**.

```text
[ danger icon ]
      percentage
```

The icon identifies the type of danger. The percentage beneath it shows the relevant adverse or protective probability.

### Stealth

```text
[ hood icon ]
     55%
```

The percentage is the chance to remain undetected.

### Attack of Opportunity

```text
[ crossed melee-weapons icon ]
             65%
```

The percentage is the predicted chance that the Attack of Opportunity hits.

### Overwatch

```text
[ bow icon ]
     50%
```

**Overwatch must use a clear bow icon.**

Do not use:

* an eye icon;
* a generic ranged reticle;
* a shield;
* crossed swords;
* a combined bow-and-eye symbol.

The bow alone communicates a prepared ranged shot and remains visually distinct from Stealth and perception markers.

The percentage includes the normal Overwatch `−2` attack modifier.

### Brace

```text
[ spear icon ]
     70%
```

The spear should read as planted or braced rather than as a generic melee weapon.

## 14.2 One tactical badge per tile

A tile must not stack:

* Stealth badge;
* reaction badge;
* cover shield.

Priority:

```text
1. Invalid or interrupted movement
2. Stealth check
3. Known legal reaction
4. Cover shield
5. Ordinary path decoration
```

## 14.3 Hidden movement display

When the mover is hidden from the relevant potential reactor:

```text
show Stealth badge
suppress reaction badge
suppress cover shield
```

The enemy cannot currently react and must not be presented as though it can.

## 14.4 Revealed movement display

When the mover is currently perceived and a known reaction is legal:

```text
show reaction icon
show predicted hit chance beneath it
suppress cover shield
```

## 14.5 Mixed-risk edge case

Where one path step contains both:

* a legal immediate Reaction from an enemy that perceives the mover; and
* a Stealth check involving another observer,

the central badge shows the event that resolves first in the authoritative movement sequence.

The route inspector lists the secondary risk.

This prevents overlapping badges while remaining rules-accurate.

## 14.6 Multiple reactions on one step

Show the reaction with the highest predicted hit chance and a small count marker:

```text
[ bow icon ] ×2
      60%
```

The route inspector lists each legal reaction separately.

Do not draw several icons inside one tile.

---

# 15. Reaction-preview information

## 15.1 Click-locked preview only

Reaction risk is calculated when the player first clicks and locks a destination.

Cursor hover must remain cheap:

```text
Hover:
0 pathfinding queries
0 Stealth-preview queries
0 reaction-preview queries
```

First destination click:

```text
1 path query
1 Stealth-preview query
1 reaction-preview query
```

Moving the cursor after locking the path:

```text
0 additional path queries
0 additional reaction queries
```

Clicking another destination replaces the preview once.

## 15.2 Information security

Reaction previews must not reveal:

* hidden enemies;
* hidden Overwatch reservations;
* unknown Brace areas;
* unknown weapon statistics;
* exact positions of unobserved units;
* perception relationships the player has not discovered.

A reaction warning appears only when:

```text
reactor is known
AND reservation or Reaction availability is legitimately known
AND reactor currently perceives the mover
AND the trigger is currently legal
```

Where exact hit chance is not legitimately available, use:

```text
[ reaction icon ]
        ?
```

## 15.3 Route inspector

Example:

```text
Known reaction risks

Spear Guard
Attack of Opportunity
65% chance to hit
Trigger: leaving tile (12, 8)

Archer
Overwatch
50% chance to hit
Modifier: Overwatch −2
Trigger: entering tile (14, 8)
```

A route-wide summary may show:

```text
Known reactions: 2
Highest chance to be hit: 65%
```

---

# 16. Attack-preview reaction warnings

Actions tagged `Provokes` must show reaction risk before commitment.

Example:

```text
Reload

Cost: Half Action
Provokes: Spear Guard
Predicted Attack of Opportunity: 65% hit
```

The attack preview should similarly show known reactions triggered by:

* firing a ranged weapon while engaged;
* provoking spellcasting;
* standing from Prone;
* item use;
* complex interaction.

The Tactical Rules Bible requires attack previews to include known Reactions that may trigger. 

---

# 17. Reaction presentation

## 17.1 Shared player decision prompt

A player prompt appears only after the triggering event reaches the correct atomic Reaction window.

The compact prompt must show:

* reacting character;
* Reaction type and matching icon;
* triggering target and action;
* weapon or ability;
* predicted hit chance;
* expected damage where known;
* important modifiers;
* current Reaction state;
* state after using the Reaction;
* primary and secondary choices.

The tactical board remains visible behind the prompt. The triggering tile, reactor and target should remain highlighted without adding a permanent overlay.

## 17.2 Attack of Opportunity

```text
Mover reaches leaving edge
→ movement animation pauses on old tile
→ reactor’s token/ring pulses briefly
→ player prompt opens when the reactor is player-controlled
→ Use: attack animation resolves
→ Decline: no attack and movement resumes
→ hit feedback begins immediately when damage occurs
→ state check
→ mover continues or stops
```

## 17.3 Overwatch

```text
Mover enters triggering tile
→ movement pauses
→ Overwatch reactor pulses with the bow motif
→ player prompt opens when the shooter is player-controlled
→ Fire: bow shot resolves and reservation ends
→ Hold Fire: reservation remains and movement resumes
→ immediate hit feedback when damage occurs
→ state check
→ movement continues or stops
```

## 17.4 Brace

```text
Mover enters triggering tile
→ movement pauses
→ braced unit pulses with the spear motif
→ player prompt opens when the reactor is player-controlled
→ Use Brace: spear attack resolves and reservation ends
→ Hold Brace: reservation remains and movement resumes
→ immediate hit feedback when damage occurs
→ state check
→ movement continues or stops
```

## 17.5 Cadence

Do not add a blanket post-reaction timer.

The decision prompt itself is not followed by an artificial delay. After a choice, the reaction attack animation and immediate red pulse/vibration provide the readability beat. A declined or held Reaction resumes the triggering event immediately. Existing activation and alert cadence remains event-driven.

## 17.6 Camera

Do not recenter when both units are visible.

Temporarily frame the reaction only when:

* the reactor is off-screen;
* the target is off-screen;
* the event would otherwise be missed.

Return control without permanently changing the player’s camera focus.

---

# 18. HUD and token presentation

Reaction resource display:

```text
R Ready
R Overwatch
R Brace
R Spent
```

Tooltips should identify:

* reserved action;
* reserved weapon;
* area;
* cancellation conditions.

A small token-level reservation marker may be used, but it must not compete with:

* life-state markers;
* active-unit ring;
* hidden badge;
* immediate hit reaction;
* tile-centre path badges.

The reserved Overwatch token marker should also use a bow motif for consistency.

## Player Reaction prompt presentation

The prompt should be compact and must not hide the triggering board position unnecessarily.

Prompt labels are Reaction-specific:

```text
Attack of Opportunity
[Use Reaction] [Decline]

Overwatch
[Fire] [Hold Fire]

Brace
[Use Brace] [Hold Brace]
```

No countdown is used.

The prompt must display the bow icon for Overwatch and the spear icon for Brace. The same icon family used in path previews should be reused in the prompt.

---

# 19. Combat-log contract

## Decision records

Every offered player Reaction records the decision without cluttering the main log with redundant lines.

Examples:

```text
Marauder — Attack of Opportunity offered
Decision: Declined
Reaction remains Ready
```

```text
Archer — Overwatch offered
Decision: Hold Fire
Reaction remains Reserved
Ammunition spent: 0
```

Used Reactions continue into the complete attack calculation entries below.

## Attack of Opportunity

```text
Spear Guard — Attack of Opportunity

Trigger:
Marauder voluntarily left a threatened tile

Reaction:
Ready → Spent

Attack:
d20 12 + 5 = 17
Target AC: 14
Hit chance preview: 65%

Result:
Hit

Damage:
1d8 + 2 = 6 piercing

Movement:
Continues
```

## Overwatch

```text
Archer — Overwatch

Trigger:
Marauder entered the reserved Overwatch area

Reaction:
Overwatch → Spent

Weapon:
Shortbow

Attack:
d20 11 + 5 − 2 Overwatch = 14
Target AC: 14

Result:
Hit

Ammunition:
1 arrow spent

Movement:
Continues
```

## Brace

```text
Spear Guard — Brace

Trigger:
Marauder entered the braced sector

Reaction:
Brace → Spent

Attack:
d20 9 + 6 = 15
Target AC: 14

Result:
Hit

Movement:
Stopped — target became Prone
```

---

# 20. AI policy

## Attacks of Opportunity

AI evaluates a legal basic Attack of Opportunity automatically through deterministic policy. It receives no player prompt.

It receives no knowledge of hidden or unperceived movement through the Reaction system.

## Disengage

AI considers Disengage when:

* a ranged unit wants to leave melee;
* retreating from a stronger melee enemy;
* preserving a low-HP unit;
* reaching an objective is worth the Half Action.

It avoids Disengage when:

* the enemy has no available Reaction;
* the route does not leave a threatened tile;
* the AI intends to remain engaged;
* the movement is already non-provoking.

## Overwatch

Ranged AI may prepare Overwatch when:

* no strong immediate shot exists;
* guarding a doorway or route;
* protecting an objective;
* expecting a known enemy approach;
* remaining stationary is tactically sensible.

AI cannot place Overwatch based on the player’s uncommitted preview route.

## Brace

Brace-capable AI may prepare Brace when:

* guarding a choke point;
* defending an archer;
* protecting an objective;
* expecting a visible melee approach.

---

# 21. Performance architecture

## 21.1 Threat cache

Cache each unit’s threatened-space contribution from:

```text
position
footprint
melee reach
weapon state
life and condition state
Reaction state
perception eligibility
```

Invalidate only when one of those inputs changes.

Do not recalculate every unit’s threatened spaces whenever one unrelated unit moves.

## 21.2 Reserved-area index

Register Overwatch and Brace areas when reserved.

Remove them when:

* triggered;
* cancelled;
* spent;
* refreshed;
* source becomes invalid.

Movement should query only reserved areas intersecting the current step.

## 21.3 Nearby candidate lookup

Opportunity attacks should inspect nearby hostile threat contributors rather than scan every active unit on the map.

## 21.4 Presentation refresh

A Reaction may update:

* reactor Reaction state;
* attacker and target token presentation;
* damage;
* life state;
* committed movement path;
* combat log.

A pending player decision may pause event advancement, but it must not cause repeated geometry, path, Stealth or reaction-preview recalculation while the prompt is open.

It must not automatically cause:

* full visibility recalculation;
* static terrain redraw;
* full unit-status reconciliation;
* complete HUD rebuild;
* unrelated extraction recalculation.

## 21.5 Development counters

Track:

```text
reaction windows opened
reaction candidates examined
valid reactions resolved
threat-cache rebuilds
Overwatch-area intersections
Brace-area intersections
reaction chains suppressed
player Reaction prompts opened
player Reactions used
player Reactions declined or held
stale Reaction decisions rejected
movement steps resolved
reaction-preview queries
full board refreshes
post-reaction processing milliseconds
```

---

# 22. Save, load and migration

Existing data using:

```gdscript
reaction_available: bool
```

must migrate as:

```text
true  → AVAILABLE
false → SPENT
```

Old saves contain no reservation and therefore initialise:

```gdscript
reaction_reservation = null
```

Snapshots, rollback state, mission setup and persistent tactical serialization must preserve:

* resource state;
* reservation;
* reserved weapon;
* reserved area;
* creation turn;
* cancellation rules.

The tactical session must also preserve a pending Reaction decision request across controller-level rollback or presentation rebuilds. Ordinary campaign saves may either serialize that request completely or remain disabled until the active Reaction window closes; they must never save a half-resolved attack with no recoverable decision state.

Direct writes to obsolete `reaction_available` storage should be prohibited once migration is complete. A compatibility getter may remain temporarily.

---

# 23. Scope exclusions

Stage 4.5 does not implement:

* Counterspell;
* Guard Ally;
* Intercept;
* Pursuit;
* Sidestep;
* multiple Reactions per round;
* suppression fire;
* multiple Overwatch shots;
* custom cone widths;
* manually painted Overwatch areas;
* prepared spell reactions;
* full Ready Action;
* charge or lance damage multipliers;
* reaction chains;
* reactions to teleportation;
* reactions to summon arrival;
* configurable global Auto-React, Never-React or per-ability prompt preferences;
* reaction time limits or countdowns;
* multiplayer Reaction-decision handling.

Player Use/Decline and Fire/Hold prompts for the optional Reactions implemented in Stage 4.5 are in scope and required.

The architecture must support later additions without implementing them now.

---

# 24. Validation plan

## Stage 4.5a

1. Available can become Reserved.
2. Reserved can become Spent.
3. A legal cancellation can return Reserved to Available.
4. Start-of-turn refresh restores Available.
5. Contact-round transition preserves Spent.
6. Surprised units cannot react before their first turn.
7. Sprint correctly removes Reaction availability.
8. Deterministic priority produces repeatable results.
9. Invalidated candidates retain their Reaction.
10. Reaction attacks cannot trigger ordinary reaction chains.
11. Controller changes preserve state.
12. A player-controlled optional candidate creates exactly one decision request.
13. AI-controlled candidates create no player prompt.
14. Mandatory or explicitly automatic candidates bypass the prompt.
15. Declining does not spend the Reaction.
16. Stale or duplicate decision commands are rejected.
17. Legacy boolean saves migrate correctly.

## Stage 4.5b

1. Orthogonal departure from threat provokes.
2. Legal diagonal departure provokes.
3. Sealed diagonal corners do not create threat.
4. Forced movement does not provoke.
5. Teleportation does not provoke.
6. Five-foot adjustment does not provoke.
7. Hidden movement does not provoke from an unaware defender.
8. Disengage prevents movement-based AoO.
9. Disengage does not suppress separately provoking actions.
10. One defender reacts only once per continuous move.
11. Multiple defenders resolve by priority.
12. Miss allows movement to continue.
13. Incapacitation stops movement.
14. The attack uses the highest normal bonus.
15. Ordinary attack availability remains unchanged.
16. A player-controlled Attack of Opportunity pauses before tile entry.
17. Choosing Use spends the Reaction and resolves the attack.
18. Choosing Decline leaves the Reaction Available.
19. Declining suppresses repeat prompts for the same defender-target pair during that continuous movement action.

## Stage 4.5c

1. Overwatch requires a loaded ranged weapon.
2. Preparing it spends a Half Action.
3. Reaction becomes Reserved.
4. First eligible perceived target triggers.
5. Hidden movement does not trigger.
6. Shot receives `−2`.
7. Ammunition is spent only on firing.
8. Forced movement does not trigger.
9. Shooter movement cancels reservation.
10. Weapon change cancels reservation.
11. Incapacitation cancels reservation.
12. Infiltration Overwatch resolves before alert.
13. Spent Reaction carries into contact round.
14. Brace requires a compatible weapon.
15. Brace creates a decision on perceived entry.
16. Player Overwatch offers Fire/Hold Fire.
17. Hold Fire spends no ammunition and keeps the reservation.
18. The same target does not repeatedly prompt during one continuous movement action.
19. Player Brace offers Use Brace/Hold Brace.
20. Hold Brace keeps the reservation.
21. AI Overwatch and Brace use deterministic policy without player prompts.
22. Reserved Overwatch or Brace prevents ordinary AoO.

## Stage 4.5d

1. Hover causes no reaction-preview query.
2. First click builds one reaction preview.
3. Cursor movement does not rebuild it.
4. Hidden enemies are not revealed.
5. Hidden movement shows Stealth, not reaction risk.
6. Attack of Opportunity uses the crossed-weapons icon.
7. **Overwatch uses the bow icon.**
8. Brace uses the spear icon.
9. Predicted hit chance appears below each reaction icon.
10. Reaction badges occupy the tile centre.
11. Cover shields are suppressed when the centre badge is present.
12. Multiple reactions use one icon plus a count.
13. Hit confirmation begins immediately.
14. Movement pauses on the correct side of the trigger.
15. Player prompts show reactor, target, trigger, hit chance, damage and Reaction-state consequence.
16. Attack of Opportunity uses Use Reaction/Decline labels.
17. Overwatch uses Fire/Hold Fire labels and the bow icon.
18. Brace uses Use Brace/Hold Brace labels and the spear icon.
19. Right-click or Escape performs the safe decline/hold choice.
20. Declined or held Reactions resume the triggering event without an added timer.
21. Several player candidates are presented one at a time in deterministic priority order.
22. Invalidated later candidates are not presented or spent.
23. AI does not use hidden route information.
24. No broad refresh occurs per movement step or while a prompt is open.
25. Existing Stealth, alert, doors and initiative tests continue to pass.

---

# 25. Final acceptance criteria

Stage 4.5 is complete only when:

1. One shared Reaction resource serves all implemented reaction types.
2. Available, Reserved and Spent are authoritative.
3. Reaction refresh occurs at the correct turn or phase boundary.
4. Movement resolves through atomic steps.
5. Opportunity attacks occur before the next tile is entered.
6. Overwatch and Brace occur after the trigger tile is entered.
7. Hidden characters cannot trigger sight-dependent reactions from enemies that cannot perceive them.
8. Detection never causes a retroactive Reaction on a completed step.
9. Disengage prevents only ordinary movement-based opportunity attacks.
10. Reaction attacks reuse normal attack resolution.
11. Reaction chains are suppressed.
12. Candidate priority is deterministic.
13. Invalidated reactions are not spent.
14. Reaction previews appear only on clicked, locked paths.
15. Reaction warnings use a centre icon with hit percentage underneath.
16. Attack of Opportunity uses a melee-reaction icon.
17. **Overwatch uses a bow icon.**
18. Brace uses a spear icon.
19. Stealth uses the existing hood icon and avoidance percentage.
20. Cover shields never obscure Stealth or reaction information.
21. Unknown enemies and reservations remain hidden.
22. Every legal optional Reaction belonging to a player-controlled unit creates the correct decision prompt.
23. Declining an ordinary Reaction does not spend it.
24. Holding Overwatch or Brace preserves the reservation and ammunition.
25. The same reserved Reaction does not repeatedly prompt against the same target during one continuous movement action.
26. Multiple eligible player Reactions are offered in deterministic order and revalidated between choices.
27. AI obeys the same Reaction and perception rules as the player but uses deterministic policy without prompts.
28. Mandatory or explicitly automatic reactions bypass player prompts only when their definitions require it.
29. Ordinary movement without reactions remains as responsive as Stage 4.4e3b2.
30. Immediate non-blocking hit feedback remains intact.
31. No permanent threatened-space overlay clutters the tactical board.

## Final intended feel

```text
Hover
→ immediate and cheap

First click
→ clear movement plan
→ Stealth and reaction danger shown consistently

Second click
→ decisive movement

Reaction trigger
→ spatially correct interruption
→ player-controlled reactor receives a genuine Use/Decline or Fire/Hold choice
→ AI-controlled reactor decides through policy
→ clear icon, attack and roll information

Resolution
→ selected Reaction resolves
→ declined or held Reaction resumes immediately
→ immediate hit confirmation when damage occurs
→ movement continues or stops for an understandable reason
```

This version locks the reaction warning language as:

```text
Stealth
hood icon + chance to remain hidden

Attack of Opportunity
crossed melee-weapons icon + chance to be hit

Overwatch
bow icon + chance to be hit

Brace
spear icon + chance to be hit
```

The player-decision language is locked as:

```text
Attack of Opportunity
Use Reaction / Decline

Overwatch
Fire / Hold Fire

Brace
Use Brace / Hold Brace
```

Only player-controlled optional Reactions prompt. AI decisions and explicitly automatic effects use the same Reaction pipeline without opening the player interface.
