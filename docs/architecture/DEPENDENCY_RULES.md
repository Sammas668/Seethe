# Dependency Rules

```text
domain         → core
application    → domain + core
presentation   → application + read-only domain state
infrastructure → interfaces and content loading required inward
bootstrap      → all layers for composition only
```

## Forbidden dependencies

`domain/` must never import from:

- application;
- presentation;
- infrastructure;
- bootstrap.

`application/` must never depend on concrete screens, tactical actor Nodes or
scene-tree paths.

## Presentation read policy

Presentation may read domain state to render the current prototype. It must
never mutate domain state directly.

Every gameplay change must go through an application handler or session-owned
service. UI-only state such as hover, selection, tray visibility and tab choice
may remain inside presentation.

Tactical scenes must never hold a live reference to persistent campaign state.
A tactical session receives a tactical snapshot and returns an explicit result.

## Composition

`bootstrap/` creates or receives:

- content catalogue;
- save services when implemented;
- state stores;
- application handlers;
- tactical sessions;
- screen dependencies.

It is the only layer allowed to wire concrete infrastructure into
application-facing sessions.
