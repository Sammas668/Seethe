# Stage 4.3.2 — Body Items, Medical Interaction and Restraint

## Status

Implemented vertical-slice foundation.

## Architectural decision

An incapacitated or dead character is not deleted and is not replaced by a
second character record. The character remains authoritative for identity, HP,
life state, conditions, faction and carried equipment. One linked
`TacticalItemInstanceState` becomes authoritative for the character's physical
location while the character is Dying, unconscious, dead, restrained or
awaiting legal placement after recovery.

This preserves the ordinary inventory invariant:

```text
one physical item instance -> one authoritative item location
```

The body item is therefore real inventory state rather than a presentation-only
entry or a bespoke carry attachment.

## Standing occupancy and body occupancy

Exactly 0 HP remains Disabled and continues to occupy standing space.

Dying, Stable Unconscious, nonlethally Unconscious and Dead characters release
standing occupancy immediately after the life-state change commits. Their body
item may share a tile with a standing unit and ordinary ground items. A ground
or dragged body makes the tile difficult terrain without blocking a legal
standing destination.

`TacticalState` derives two indexes:

- `unit_id_by_cell` for blocking standing occupants;
- `body_unit_ids_by_cell` for linked bodies that remain physically on the map.

## Body item contract

A linked body item:

- has `instance_kind = BODY`;
- has an immutable link to one tactical unit ID;
- is named from that character, such as `Rellan's Body`;
- has a real multi-cell inventory footprint;
- derives effective weight from body weight plus all equipment still owned by
  the linked character;
- never stacks;
- cannot enter the Belt;
- can enter the Backpack or a Hand through the ordinary transfer handler.

A Medium one-tile creature uses a 4x3 Backpack footprint.
Large bodies deliberately exceed the current ordinary Backpack width.

## Inventory location semantics

```text
TACTICAL_GROUND
    Body lies on the map and appears in Items in Reach.

UNIT_INVENTORY / BACKPACK
    Body is carried, consumes real Backpack cells and contributes its complete
    derived weight. Its ground token is hidden.

UNIT_EQUIPMENT / HAND + transport_mode = dragging
    Body occupies the real Hand slot but remains on the ground. Its token
    follows the dragger and movement uses dragging penalties.

BODY_ATTACHMENT / RESTRAINT
    The attached item is the actual rope used to restrain the linked character.
```

There is no parallel `CarriedBodyState`, abstract captive slot or special body
transport panel.

## Body context menu

Right-clicking an accessible body exposes exactly:

1. Loot Equipment
2. Administer First Aid
3. Finish Off
4. Untie

Unavailable commands remain visible and disabled with a reason. Carry, Drag,
Restrain and potion use do not appear in this menu because their single input
route is direct drag and drop.

## Direct item interaction

Dragging a medical item onto a Dying body performs a Half-Action Medicine
check. The roll uses the acting character's Medicine modifier and only the
bonus authored on the dragged item. A valid attempt consumes the authored
number of uses whether it succeeds or fails.

Dragging a healing potion onto a living body consumes the potion and applies
its authored healing without a Medicine roll. HP and life state are recalculated
from the target's real current HP.

Dragging rope onto a helpless living body spends a Half Action, moves that same
rope item to a restraint attachment location and applies Restrained and Captive.
It does not stabilise a Dying character.

## Loot Equipment and Search

Loot Equipment opens the linked character's actual equipment as an external
inventory source. Individual transfers use the existing inventory transfer
handler.

Search is available inside that loot view and is a Full Action. It moves every
removable equipment item still owned by the linked character to the body item's
current ground tile in one atomic transaction. Search preserves item IDs and
excludes the body item, anatomy, destroyed items and the attached restraint.

## Untie

Untie is the only release mechanism in this stage. It requires an adjacent allied
actor, a usable free Hand and a Half Action. It removes only Restrained and
Captive, then places the exact attached rope item on the body tile. The same
handler serves player and enemy factions. Basic enemy AI considers Untie only
for an already adjacent allied captive.

## Recovery and placement

If healing makes a body conscious on a free legal ground tile, the body item is
removed and ordinary standing occupancy resumes immediately.

If the body is packed, dragged beneath an occupied standing tile or otherwise
cannot reclaim legal standing space, the unit enters `awaiting_body_placement`.
The body item remains authoritative and the unit cannot act until the same item
is placed on a legal free ground tile.

## Transaction boundary

Every affected command follows:

```text
validate
-> stage action cost
-> stage item movement/consumption
-> stage HP, life-state or restraint change
-> commit
-> synchronise body representation
-> validate inventory and occupancy invariants
-> write log
-> emit presentation refresh
```

`TacticalChangeSet` snapshots body representation before mutation so a failed
post-mutation validation restores the same body item, item location, linked unit
and standing/body indexes.

## Presentation boundary

The fallen character's existing token remains the body artwork while the item is
grounded or dragged. Life-state badges and the secondary rope badge update from
committed character state. A packed body has no ground token. The existing
0.8-second damage reaction remains fire-and-forget and cannot delay body creation,
occupancy release, badges, input, initiative or AI.

## Deferred work

Cutting or attacking restraints, escape checks, keys, advanced rescue AI,
team-carrying large bodies, resurrection, corpse harvesting and strategic captive
processing remain outside Stage 4.3.2.
