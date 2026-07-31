# Stage 4.3.1c — Immediate Life-State Presentation and Initiative AI Handoff

## Purpose

Guarantee that token body-state presentation follows authoritative HP state without
waiting for the affected unit's initiative turn, and make the presentation-owned
AI initiative coroutine robust when state callbacks change the active participant.

## Life-state presentation contract

`TacticalUnitState` remains authoritative. `TacticalScreen` keeps only a compact
presentation signature containing life-state ID, Dying successes, and Dying
failures. It synchronises changed token views during `state_changed` and once per
rendered frame as a defensive fallback.

A transition into Dying, unconsciousness, or death immediately:

- replaces the awareness eye or stealth badge;
- clears stale contextual attack targeting against that unit;
- leaves Dying pips empty until a Dying check changes the track.

## Initiative handoff contract

The enemy planner may finalise/log an activation, but `InitiativeTurnHandler` owns
initiative advancement. The presentation coroutine:

- captures the acting unit ID;
- rechecks ownership after each presentation delay;
- advances only if that same unit is still active;
- ignores stale second end-turn requests after normalisation;
- resumes on the following frame when another AI unit becomes active.

This prevents asynchronous state refreshes from leaving the UI on an enemy actor
whose activation has already ended.
