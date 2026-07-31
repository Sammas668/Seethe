# Stage 4.3.1d — Diagonal Melee Contact and Alert Deduplication

## Purpose

Make close combat respect visually touching diagonal squares while preventing an
already-aware squad from repeatedly producing the same alert interruption.

## Melee contact authority

`TacticalMeleeReachRules` is the shared authority for melee contact. For ordinary
5-foot reach:

- orthogonally adjacent footprints are in contact;
- diagonally adjacent footprints are in contact;
- a diagonal is invalid when both intervening orthogonal terrain tiles are
  blocked;
- one blocked side does not by itself prevent the attack.

Attack previews, committed attacks and the enemy planner consume the same rule.
Movement, ordinary sight, perception and ranged distance continue to use
`TacticalGridDistance` and are not changed by this exception.

## Alert deduplication

Detection now distinguishes three practical outcomes:

- **new squad alert:** movement stops and the contact transition begins;
- **hidden-unit revelation to an aware squad:** the failed Stealth tile still
  stops movement, but the squad does not become Aware again;
- **visible-unit reacquisition by an aware squad:** revelation and Last Seen
  Position update without stopping movement or replaying the alert flash.

An already-aware squad can still re-enter or join initiative when a new combat
contact requires it. Deduplication removes repeated alert presentation and
mid-route interruption; it does not suppress legitimate combat membership.
