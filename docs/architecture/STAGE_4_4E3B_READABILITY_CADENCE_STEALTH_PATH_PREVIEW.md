# Stage 4.4e3b — Readability Cadence and Stealth Path Preview Restoration

## Purpose

Stage 4.4e3b restores the per-tile Stealth information that was disconnected by the earlier hover-performance hotfix and adds short presentation pauses only when a meaningful event needs to be understood.

It preserves the Stage 4.4e3a input contract:

- empty-tile hover is highlight-only;
- first left-click builds and locks a route;
- cursor motion cannot replace that route;
- a second click on the same destination confirms movement;
- a different click replaces the preview;
- right-click or Escape cancels.

It does not restore continuous hover pathfinding, hypothetical automatic-Peek markers, all-team visibility rebuilding or blanket post-movement timers.

## Click-owned Stealth preview

`TacticalScreen._destination_preview_for()` now attaches one bounded `MovementDetectionPreview` to a deliberately clicked destination:

```gdscript
result.detection_preview = _facade.preview_movement_detection(
	unit.unit_id,
	result.path_result
)
```

The call is reached only by first-click destination creation or genuine locked-preview revalidation. `_on_board_tile_hovered()` contains no movement, detection, destination-cover or automatic-Peek query.

The existing board presentation remains authoritative:

- every risky path square receives the Stealth hood and its avoidance percentage;
- an unknown observer is shown as `?`;
- certain detection outside Stealth is shown as `0%` with the slashed hood;
- movement-capacity colours remain visible beneath the badge;
- the HUD reports the route-wide number of risky tiles and the lowest known avoidance chance.

Actual movement revalidates pathing and detection. The preview never supplies an authoritative roll result.

## Presentation cadence policy

Ordinary movement receives no fixed wait. Every wait is selected from one central event enum and one central timing table:

| Event | Default |
|---|---:|
| Activation ownership changes | 0.15 s |
| AI movement followed by an attack reaction | 0.18 s |
| Player phase hands to Enemy/World processing | 0.25 s |
| Previously unseen enemy becomes visible | 0.35 s |
| First squad alert begins initiative | 0.40 s |
| Movement interruption without a higher-priority reveal/alert | 0.25 s |

A combined event chain chooses one highest-priority cadence event. Alert supersedes reveal, interruption, AI attack and activation handoff. Reveal supersedes lower events. This prevents several small waits from stacking around one action.

The AI movement-to-attack cadence is presentation-only. The authoritative AI activation remains atomic, but deferred damage reactions are held until the final movement position has been visible for the configured interval. The combat state is not recalculated during the wait.

## Active-unit handoff pulse

`TacticalUnitView.play_active_handoff_pulse()` expands and softens the initiative ring for a short non-blocking pulse. It does not alter selection, initiative, visibility, camera position, input ownership or tactical state.

## Performance boundaries

During empty-tile hover:

- movement preview queries: 0;
- detection-preview queries: 0;
- automatic-Peek preview queries: 0;
- full HUD refreshes: 0 unless attack-hover context changes.

During first destination click:

- movement preview queries: 1;
- detection-preview queries: 1;
- movement commits: 0.

Cursor movement after the click performs no additional route or detection query. A different destination click creates one replacement pair. The second click on the locked destination performs one authoritative movement commit.

## Invalidation

A locked route may be rebuilt or cleared by tactical state changes such as selection, active ownership, remaining capacity, geometry, observer knowledge or targeting mode. Mouse motion alone is never an invalidation reason.

## Validation

Static validation:

```text
python tests/static/validate_stage_4_4e3b.py
```

Runtime validation:

```text
godot --headless --path . --script res://tests/tactical/run_stage_4_4e3b_tests.gd
```

The runtime fixture verifies click-owned Stealth previews, zero hover queries, locked preview persistence, one replacement query, central cadence values, event-priority deduplication and the non-blocking active-unit pulse.
