# Authored sources

These are source assets, not generated runtime output. Read the
[content workflow](../../.agent/workflows/change-core-authored-content.md),
[Core package rules](../../packages/runner_core/AGENTS.md) and relevant
[editor domain rules](../../.agent/references/editor-authoring.md).

Preserve stable IDs, ordinals, canonical ordering and explicit schema versions.
Current level source is v3, chunks v2, Prefabs v3 and terrain materials v3.
Verify constants in the owning codecs when changing schemas; normal loaders
must not migrate implicitly. Keep inclusion/deprecation separate from identity.

Regenerate affected outputs with the root generator and check freshness before
using runtime tests as source evidence. Geometry, spawns and assembly may change
replay outcomes and require traversal plus compatibility checks. Visual-only
data must not acquire collision/gameplay authority. Use canonical atlas/parallax
locations from root instructions; do not move art into per-level duplicate trees.
