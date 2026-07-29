# Stage 4.0.4 — Movement bar and UnitBlock layout

Stage 4.0.4 is a presentation-only follow-up to the segmented health-bar pass.

## Changes

- The selected unit's remaining and maximum turn capacity are displayed inside
  the movement bar as `remaining / maximum ft`.
- Armour Class remains on its own compact line rather than duplicating movement.
- The bottom deck is taller and the UnitBlock reserves a minimum of 52 pixels for
  wrapped context text.
- The UnitBlock is slightly wider to reduce unnecessary wrapping.
- The collapsed and expanded Tactical Log positions move upward with the deck.

No tactical rules, action costs, movement calculations, damage rules, or
nonlethal mechanics are changed.
