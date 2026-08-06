# Stage 4.2.5.4a — Symmetrical Preview-and-Confirm Controls

## Boundary

This stage changes only tactical input and presentation. Domain movement, detection, perception, initiative and AI rules remain authoritative and unchanged.

## Controller ownership

`TacticalScreen` owns the mutually exclusive `BoardIntentMode`:

```gdscript
enum BoardIntentMode {
	NONE,
	MOVE_PREVIEW,
	FACING_PREVIEW,
}
```

The controller stores the planned movement destination, planned facing, movement path and detection preview. `TacticalBoardView` renders those values and emits pointer events; it does not decide or commit actions.

## Input contract

| Current mode | Left-click | Right-click |
|---|---|---|
| None | Start movement preview | Start facing preview |
| Movement preview | Confirm same destination or replace with another | Cancel movement preview |
| Facing preview | Cancel facing preview | Confirm same direction or redirect |

Attack/ability targeting and modal windows retain priority and consume their own cancellation inputs before board intents are considered.

## Movement planning

Hover never performs pathfinding. The first left-click performs the preview query and stores the result. The second click on the same destination sends the existing movement command, which revalidates through the application layer before committing.

The board displays:
- cumulative per-square capacity colours;
- per-square Stealth avoidance percentages from the existing detection preview;
- destination highlight and final-facing arrow.

## Facing planning

The first right-click performs only the non-mutating facing preview query. The selected `TacticalUnitView` animates toward that direction immediately, while the board redraws the focused perception cone with the same override.

The second right-click in the same quantised direction invokes the existing `FacingHandler`. Only that command spends 5 feet and mutates tactical state.

Cancelling calls `TacticalUnitView.cancel_facing_preview()`, which returns to committed facing without spending capacity.

## Visual rotation

The unit node itself is not rotated. `TacticalUnitView` interpolates a visual facing angle and redraws only the directional front marker and facing tick. Hidden, awareness, selection, health and initiative badges therefore remain upright.

A new preview redirects the active tween through the shortest angular arc. Input is never locked while the short tween runs.

## State changes

Any unrelated tactical state change clears an unconfirmed board intent. Facing commits are guarded so their own state-change signal does not cancel the visual preview before it becomes authoritative.

## Non-goals

- No movement-rule changes.
- No Stealth-rule changes.
- No perception-range changes.
- No initiative changes.
- No AI changes.
- No active Search or noise system.
