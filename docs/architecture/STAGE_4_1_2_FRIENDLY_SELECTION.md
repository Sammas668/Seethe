# Stage 4.1.2 — Friendly selection during weapon targeting

A selected weapon no longer turns every occupied tile into an attempted attack.

## Behaviour

- Hovering a hostile unit still shows the attack cursor and hit-chance preview.
- Hovering a friendly or neutral unit shows a pointing-hand cursor.
- No hit percentage, damage popup, invalid-target warning, or hostile outline is
  shown for a friendly unit.
- Left-clicking a friendly unit selects it normally.
- Left-clicking a non-player neutral unit opens the existing inspection
  selection behaviour.
- Only a hostile unit is sent to the attack preview and execution pipeline.
- Right-clicking a hostile still cycles attack mode.

This is a presentation-routing fix. Team relationships and attack legality remain
owned by the application facade.
