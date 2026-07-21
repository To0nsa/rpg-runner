---
description: Add a new playable level to the current generated level pipeline
---

# Add New Level Workflow

Use this workflow when adding a playable level to the current data-first
pipeline. Read `AGENTS.md`, `lib/AGENTS.md`,
`packages/runner_core/lib/AGENTS.md`, `lib/game/AGENTS.md`,
`lib/ui/AGENTS.md`, and `tools/editor/AGENTS.md` before editing.

## Current Source Of Truth

Do not hand-edit generated runtime files.

- source data: `assets/authoring/level/level_defs.json`
- chunk source data: `assets/authoring/level/chunks/*.json`
- parallax source data: `assets/authoring/level/parallax_defs.json`
- generator: `tool/generate_chunk_runtime_data.dart`
- generated core files:
  - `packages/runner_core/lib/levels/level_id.dart`
  - `packages/runner_core/lib/levels/level_registry.dart`
  - `packages/runner_core/lib/track/authored_chunk_patterns.dart`
- generated UI/render files:
  - `lib/ui/levels/generated_level_ui_metadata.dart`
  - `lib/game/themes/authored_parallax_themes.dart`

## Steps

1. Define the authored level data.

   Prefer the Level Creator in `tools/editor` when practical. If editing JSON
   directly, preserve canonical field order, stable `levelId`, stable
   `enumOrdinal`, deterministic chunk theme groups, camera/ground values, and
   explicit `status`.

2. Provide gameplay chunks and assembly inputs.

   Add or reuse chunk definitions under `assets/authoring/level/chunks/`.
   Keep authored chunk keys stable and validate that the level references only
   existing theme groups/chunks.

3. Provide render theme coverage.

   Add or reuse `visualThemeId` and parallax definitions in
   `assets/authoring/level/parallax_defs.json`. Gameplay collision remains in
   core/chunk data; parallax is visual-only.

4. Regenerate runtime data.

   ```bash
   dart run tool/generate_chunk_runtime_data.dart
   ```

   Use dry-run before finalizing when checking drift:

   ```bash
   dart run tool/generate_chunk_runtime_data.dart --dry-run
   ```

5. Wire UI only if generated metadata is not enough.

   Level selection should normally flow through generated level metadata and
   `LevelIdUi`. Avoid hard-coded one-off level lists in pages.

6. Verify determinism and runtime behavior.

   Run targeted generator/core/UI tests first, then broaden if contracts changed.

## Suggested Validation

```bash
dart run tool/generate_chunk_runtime_data.dart --dry-run
flutter test test/tool/level_definition_generation_test.dart
flutter test test/tool/generate_chunk_runtime_data_test.dart
dart analyze packages/runner_core lib/ui lib/game
flutter test test/core test/ui test/game
```

For editor changes, also run:

```bash
cd tools/editor
dart analyze
flutter test
```

## Manual Verification

- level appears only when `status` should make it selectable
- level loads through the normal hub/setup/run route
- generated `LevelId` ordering is intentional and stable
- chunks stream without missing references
- parallax/theme assets render without changing gameplay behavior
- replay validation assumptions still hold for the level seed/tick path
