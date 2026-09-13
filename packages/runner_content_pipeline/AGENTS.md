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

Optional Chunk-v2 water rectangles compile into separate Core volume records.
Preserve water signatures and bindings without adding solid edges or navigation
support. Missing water arrays mean dry chunks; explicit null is invalid.

Repository generation validates all source schemas, identities and individual
geometry even for excluded levels. The separate runtime batch contains only
active chunks of included levels and must pass scheduler/seam readiness. Keep
`isRuntimeEligibleChunkStatus` shared by generation, authored Play and editor
capacity admission; deprecation cannot contribute to a runtime pool. The root
generator owns Level schema migration, stable enum availability and the policy
requiring included playable content before publication.

Validate changes with:

```powershell
dart analyze packages/runner_content_pipeline
Push-Location packages/runner_content_pipeline
dart test
Pop-Location
```
