# Dependency Rules

```text
domain        → core
application   → domain + core
presentation  → application + read-only view models
infrastructure→ interfaces required by application/domain
bootstrap     → all layers for composition only
```

## Forbidden imports

`domain/` must never import from:

- application
- presentation
- infrastructure
- bootstrap

`application/` must never import concrete screens or tactical actor Nodes.

`presentation/` must never mutate campaign state directly.

Tactical scenes must never hold a live reference to the campaign state store.

## Composition

`bootstrap/` creates:

- content catalogue;
- save service;
- campaign state store;
- application handlers;
- screen/session dependencies;
- tactical sessions.

It is the only layer allowed to wire concrete infrastructure into application-facing interfaces.
