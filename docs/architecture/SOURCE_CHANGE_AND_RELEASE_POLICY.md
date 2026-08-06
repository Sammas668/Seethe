# Source Change and Release Policy

## Canonical source

The checked-out project tree is the only canonical source. A release ZIP is a distribution snapshot, not an editable layer that is later modified by generated patch scripts.

## Normal change workflow

1. Begin from a clean Git working tree.
2. Edit the real source, authored data, tests and documentation directly.
3. Run the relevant static and Godot behavioural suites.
4. Commit one coherent change with a descriptive message.
5. Create full and update-only release archives from that commit.

## Prohibited workflow

Do not add scripts whose purpose is to rewrite the project source into the next source version, including patterns such as:

- `apply_*_patch.py`
- `apply_*_update.py`
- one-off hotfix scripts that search and replace canonical GDScript

A genuine save migration, data importer, asset converter or authoring tool may remain when it is part of the shipped architecture and is safe to run repeatedly.

## Commit boundaries

Prefer commits that can be reviewed and reverted independently:

- authored-data correction;
- controller extraction;
- behavioural test addition;
- AI instrumentation extraction;
- release documentation and packaging.

## Release artefacts

A normal release may contain:

- a full project ZIP excluding `.git`, `.godot` and local caches;
- an update-only ZIP containing changed and deleted-path manifests;
- a Git bundle containing the portable source history baseline.

Update-only archives must identify deleted paths. Copying only replacement files is insufficient when a release intentionally removes obsolete scripts.
