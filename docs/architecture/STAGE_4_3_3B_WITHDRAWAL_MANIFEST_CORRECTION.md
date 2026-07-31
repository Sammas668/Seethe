# Stage 4.3.3b — Withdrawal Manifest Correction

## Locked rules

A legal Victory or Withdrawal takes every ordinary item whose authoritative
physical location is a permitted extraction-zone ground or tactical-container
tile.

A living hostile is eligible for physical enemy-body extraction only when the
linked tactical character is **Unconscious** or **Restrained**. A conscious,
unrestrained hostile is never swept into withdrawal by the location of a stale
or awaiting-placement body item.

Dead hostile bodies remain physical body items and may be recovered when the
player deliberately brings them into the zone. An unconscious hostile may be
recovered as a body, but only a living character with authoritative
`restrained && captive` state becomes a campaign Captive.

## Boundary

`TacticalExtractionManifestQuery` is the sole authority for this decision.
Mission-result construction and campaign commit consume the normalized manifest
and do not infer extraction from proximity independently.
