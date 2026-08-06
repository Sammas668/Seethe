# Stage 4.5e5 — Precise Attack Invalidation and Visibility Critical-Path Fix

## Problem

`attack_resolved` inherited broad invalidation defaults that marked occupancy and
visibility as changed. The visibility service treated those flags as a reason to
run `recalculate_all_teams(true)`. Because that work runs on the main thread, the
damage tween could be created but could not render until thousands of LOS traces
and fog work completed.

The board also refreshed the entire fog layer from the reason string alone, and
reaction attacks deferred during movement forced a full visibility rebuild even
when no sightline changed.

## Corrected contract

An ordinary hit or miss now publishes only `token_status_changed`. AttackHandler
escalates flags from the actual committed result:

- body transition: occupancy and inventory;
- alert transition: initiative where applicable;
- cover HP damage: environment visuals;
- cover integrity transition: combat geometry;
- opening or structure transition that changes sight blocking: visibility;
- generated salvage: inventory.

Occupancy and geometry no longer implicitly mean fog visibility changed. Systems
that genuinely alter sight set `visibility_changed` explicitly.

## Presentation

The tactical screen captures the precise attack flags while broad post-attack
reconciliation waits behind the first impact frame. The board uses those flags to
refresh static environment or fog only when required. `attack_resolved` is no
longer a reason-only fog redraw.

Reaction attacks committed during movement retain their flags. They request a
full visibility rebuild only when the actual result changes sight blocking.

## Performance contract

For an ordinary attack in established combat:

- visibility recalculations: 0;
- LOS traces caused by attack: 0;
- fog refresh caused by attack: 0;
- static environment rebuild: 0;
- token/HP presentation: updated;
- impact feedback: remains first-frame eligible.

A destroyed sight-blocking wall, door or similar opening still requests one
visibility refresh after impact presentation begins.
