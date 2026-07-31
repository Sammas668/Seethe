# Stage 4.2.1 — Legacy test constructor hotfix

`CharacterResolutionService` intentionally uses a parameterless constructor and
explicit `configure(catalogue)` dependency injection. Several old Stage 3.12 test
copies still called `CharacterResolutionService.new(catalogue)`, which Godot 4.7
rejects during parsing.

This hotfix updates the legacy test fixtures to the current construction pattern.
No production combat, AI, phase, UI, or persistence behaviour is changed.
