# Stage 4.2.5.1 — Stealth Search and Initiative HUD Revision

> **Range revision:** Stage 4.2.5.3 supersedes the sight, focused-cone and close-awareness distances recorded here.


## Purpose

This revision keeps Stage 4.2.5's binary Unaware/Aware model while correcting the player-facing information and extending the first aware-AI response after visual contact is broken.

## Locked revisions

### Avoid-detection percentage

Every movement preview percentage now means:

> Chance that the selected character completes the route without being detected.

The preview no longer displays the inverse chance. Unknown observers continue to display `?` rather than leaking hidden information.

### Clear stealth roll marker

The risky destination marker now combines:

- a compact d20 outline;
- the same robber-mask symbol used on hidden player tokens;
- the percentage chance to avoid detection.

A crossed mask with `0%` means the route enters perception while the character is not in Stealth.

### Close awareness

The 10-foot all-around area is no longer automatic detection. It uses the normal Stealth check with a +4 bonus to the observer's effective Detection DC. This makes close movement dangerous without deleting character skill from the result.

### Initiative order

While initiative combat is active, the existing controls-instruction label at the top right becomes a compact initiative order. It shows up to five entries in normal presentation, marks the active entry and exposes the full order through the tooltip.

### Re-entering Stealth

A character previously detected may use `Enter Stealth` again when outside all current enemy perception and when its Quick Action is available. The squad remains Aware, but loses the character's exact live position and retains only its Last Seen Position.

### Last Seen search

When an aware guard has no currently revealed hostile:

1. it moves toward the nearest Last Seen Position held by its squad;
2. perception is refreshed after movement;
3. if no hostile is reacquired at the inspected point, that memory is cleared;
4. on later activations, the guard returns toward its assigned prior task.

Search and return are action-plan kinds, not new awareness states.

## Non-goals

This revision does not implement suspicion, hearing, noise propagation, multi-point search patterns, coordinated guard roles, timers for abandoning combat or automatic de-escalation to side-based turns.
