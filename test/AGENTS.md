# Root test suites

Read the instructions for the implementation under test as well as the root
rules. Tests outside a source subtree do not waive that source's invariants.

- `test/core/`: Flutter-hosted Core integration; portable simulation tests belong
  in `packages/runner_core/test/` and use `dart test` from that package.
- `test/game/`, `test/ui/`: renderer/controller and app/widget/state behavior.
- `test/tool/`: root generator, asset and artifact contracts.
- `test/playtest/`, `test/integration_test/`: authored host and cross-layer coverage.
- `test/support/`, `test/test_support/`, `test/fixtures/`: reuse applicable helpers
  and fixtures; do not fork production logic to manufacture a passing result.

Run focused `flutter test <target>` from the repository root. Device/profile
benchmarks under `test/integration_test/`, root `integration_test/` and
`test_driver/` may need `flutter drive` and a real target; inspect their existing
README/driver first. Never label a unit pass as device or performance evidence.

Test observable behavior and failure boundaries. Use deterministic seeds and
explicit clocks; keep regressions for discovered failures. Update generated
fixtures through their owning generator. Geometry/navigation changes use the
[traversal workflow](../.agent/workflows/test-level-traversal.md).
