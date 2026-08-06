# Stage 4.2.5.2a — Character Test Static Helper Hotfix

## Problem

Godot 4.7.1 rejected `stage_3_12_character_system_tests.gd` because the static
methods `_test_marauder_baseline_resolution()` and
`_test_rage_recalculates_from_sources()` called `_resolution_service()`, which
was declared as an instance method.

## Resolution

`_resolution_service()` is now declared `static`, matching every caller and the
static `run_all()` test architecture.

## Scope

This is a parser-only test hotfix. It does not alter runtime character
resolution or any Stage 4.2.5.2 stealth behaviour.
