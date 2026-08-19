# AGENTS.md - Runner Content Pipeline Package

This pure-Dart package owns repository-independent decoding, validation,
compilation, and runtime materialization for authored chunks. It is shared by
the repository generator and the standalone editor so both consumers produce
the same Core-facing data from the same current-schema source strings.

Keep filesystem traversal, fixed repository paths, process exit behavior,
generated-file drift orchestration, Flutter, Flame, and editor state outside
this package. Public operations accept explicit source identities and source
text, return typed products and canonical issues, and do not mutate caller or
repository state.

The package may depend on `runner_core`; `runner_core` must never depend on this
package. Preserve deterministic ordering, exact signatures, strict Prefab-v3
and Chunk-v2 validation, and generated-byte parity when changing the pipeline.
Do not add legacy schema fallback paths.

Validate changes with:

```powershell
dart analyze packages/runner_content_pipeline
Push-Location packages/runner_content_pipeline
dart test
Pop-Location
```
