---
description: Change level, chunk, prefab, marker, or theme data consumed by runner_core
---

# Change Core Authored Content Workflow

Use this workflow for authored level/chunk/prefab/marker/theme data and the
generated runtime contracts consumed by Core. Use `add-new-level.md` for the
full playable-level creation path.

Read first:

- `packages/runner_core/AGENTS.md`
- `docs/tdd/runner_core_simulation_contract.md`
- `tools/editor/AGENTS.md` when editor behavior changes

## Source of truth

- `assets/authoring/level/level_defs.json`
- `assets/authoring/level/chunks/**`
- `assets/authoring/level/prefab_defs.json`
- `assets/authoring/level/parallax_defs.json`
- `tool/generate_chunk_runtime_data.dart`

Generated Core, Game, and UI outputs are not hand-edited.

## Required checks before editing

1. Classify the change: gameplay geometry/spawn/marker, visual-only prefab or
   parallax, or level selection/assembly metadata.
2. Identify generated outputs and all runtime consumers.
3. Decide whether the change affects deterministic replay outcomes. Geometry,
   gaps, spawns, markers, and chunk selection normally do.

## Implementation rules

- Preserve stable authored IDs, chunk keys, enum ordering, and canonical JSON.
- Keep collision/gameplay authority in authored Core content; parallax remains
  visual-only.
- Regenerate every affected output in one change and inspect the generated
  diff. Never patch generated files to compensate for source data.
- Update Core/Game/UI/editor/docs tests according to the content actually
  authored; do not preserve stale expectations for removed content.

## Validation

```powershell
dart run tool/generate_chunk_runtime_data.dart --dry-run
flutter test test/tool/level_definition_generation_test.dart
flutter test test/tool/generate_chunk_runtime_data_test.dart
flutter test test/core
```

Run affected Game/UI/editor tests and replay validation coverage when the
content changes streamed gameplay or run outcomes.
