# Stage 4.0.5 — Damage Channels and Tactical Log Readability

## Damage channels

Damage type and damage channel are separate concepts. `blunt`, `slashing`, and
`piercing` describe the physical type. `lethal` and `nonlethal` describe which
runtime damage pool is changed.

- Lethal damage reduces `current_hp`.
- Nonlethal damage increases `nonlethal_damage`.
- Stage 4.0.5 deliberately does not add unconsciousness or defeat thresholds.
- The segmented health bar continues to show white nonlethal damage filling
  left-to-right and red lethal loss filling right-to-left.

## Tactical log

Expanded event summaries now use wrapping Labels and a separate detail toggle.
The panel is wider, and detail text wraps inside the available width rather than
continuing off-screen.
