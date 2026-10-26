# Root tooling

These scripts coordinate repository I/O, generation, asset manifests and local
probes. Run them from the repository root after root workspace resolution.

- Shared authored decoding/compilation belongs in `runner_content_pipeline`;
  material schema/math belongs in `terrain_materials`; gameplay belongs in Core.
  Read those packages' instructions when changing their contracts.
- Preserve deterministic ordering, canonical bytes, captured-source drift
  checks and atomic artifact replacement. Keep check/dry-run modes read-only;
  failure must return a nonzero exit code without partial publication.
- `generate_chunk_runtime_data.dart` owns the runtime source outputs. Update
  sources and regenerate; never hand-patch its output. Inspect the whole generated diff.
- Keep migrations explicit and test-backed. Normal loading never upgrades source
  silently. Avoid adding a second build/export authority alongside the editor.
- Probes/benchmarks must declare their inputs and limits. Live cloud or device
  checks are separate from offline tooling tests and need the task's authorization.

Use targeted analysis and the relevant root `test/tool/` tests. For generation
changes run `dart run tool/generate_chunk_runtime_data.dart --dry-run`; for asset
manifest changes run `dart run tool/sync_assets.dart --check`. Check affected
editor/pipeline consumers when a shared output contract changes.
