# Changes from Starter v1

## Structural changes

- Renamed `app/` to `bootstrap/`.
- Reduced the physical tree substantially.
- Moved the complete future tree into documentation.
- Added a valid main boot scene.
- Added `.gitignore` and `.editorconfig`.

## Ownership corrections

- Reservation is no longer listed as an item location.
- Notoriety is owned beneath `domain/strategic/notoriety/`.
- Archetype-specific facilities and Research have one canonical home under the archetype.
- Active timing belongs to the shared project framework.
- Captives reference persistent characters rather than duplicating identity.
- `ordinary_troops` terminology has been removed.

## Complexity corrections

- Screens no longer require controller and presenter files by default.
- Shared requirement/effect systems are promoted only when justified.
- Feature subfolders such as `commands/`, `handlers/`, `queries/`, `definitions/`, `state/` and `rules/` are added when file count or ownership makes them useful.

## Preserved principles

- one authoritative campaign state;
- atomic strategic commits;
- campaign/tactical snapshot boundary;
- semantic mission results;
- stable IDs;
- deterministic RNG;
- versioned saves and migrations;
- limited autoloads;
- tests focused on invariants and idempotency.
