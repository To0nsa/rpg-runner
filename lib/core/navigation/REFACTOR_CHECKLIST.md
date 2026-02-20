# Navigation Refactor Checklist

Date: 2026-02-20  
Scope: `lib/core/navigation/**` and direct runtime integrations that consume navigation outputs.

## Outcomes
- [x] NPC movement is fluid: no takeoff jitter, no repeated failed jumps, no ledge oscillation.
- [x] Navigation stays deterministic across identical seeds and inputs.
- [x] Core hot paths remain allocation-light and analyzer-clean.

## Phase 0: Baseline and Guardrails
- [x] Re-run and freeze current navigation test baseline.
- [x] Add a short note in PR/commit about expected behavior changes before starting migration.
- [x] Define test scenes for: narrow ledges, low ceilings, wall-blocked jumps, long surfaces, high-speed drop approach.

Acceptance criteria:
- [x] Existing navigation tests pass before refactor.
- [x] Refactor branch has explicit before/after expectations for changed behaviors.

## Phase 1: Contracts and Data Integrity
Target files: `surface_extractor.dart`, `types/surface_id.dart`, geometry ingest path.

- [x] Replace fixed `groundPieceStride` ID math with collision-safe encoding for `(localSegmentIndex, pieceIndex)`.
- [x] Add surface-ID uniqueness assert/check during extraction.
- [x] Enforce `groundSegments` contract at ingest: sorted, disjoint, and valid ranges.
- [x] Add/extend tests for ID uniqueness under heavy ground splitting.
- [x] Add signed round-trip tests for negative chunk indices in surface ID pack/unpack.

Acceptance criteria:
- [x] No ID collisions in stress tests.
- [x] Invalid authored/base `groundSegments` fail fast with clear error.
- [x] `surface_id` tests pass for `chunkIndex` in `-2, -1, 0, 1`.

## Phase 2: Standability Semantics Migration
Target files: `surface_navigator.dart`, `utils/trajectory_predictor.dart`.

- [x] Replace partial-overlap checks with standable-range checks (`xMin + halfWidth`, `xMax - halfWidth`).
- [x] Apply the same standability rule in both surface locator and landing predictor.
- [x] Remove temporary relaxed landing behavior once replacement is validated.
- [x] Add tests covering narrow surfaces and ledge-adjacent ownership stability.

Acceptance criteria:
- [x] Surface ownership does not flap near edges on stable inputs.
- [x] Trajectory prediction and navigator agree on standable surfaces.

## Phase 3: Drop Takeoff Robustness
Target files: `surface_navigator.dart`.

- [x] Add directional “at or past takeoff” logic for drop edges (matching jump robustness).
- [x] Keep commit direction active while approaching drop takeoff.
- [x] Add high-speed overshoot tests for both left and right drops.

Acceptance criteria:
- [x] No back-and-forth oscillation near drop ledges at high speed.
- [x] Drop execution remains deterministic and does not regress current commit behavior.

## Phase 4: Jump Edge Obstruction Validation
Target files: `surface_graph_builder.dart`, `utils/jump_template.dart` (or new helper).

- [x] Validate jump arc clearance against static blockers before emitting jump edges.
- [x] Reject edges blocked by ceilings/walls before landing.
- [x] Keep deterministic edge ordering after adding obstruction checks.
- [x] Add tests for blocked jumps (ceiling and side-wall cases).

Acceptance criteria:
- [x] Graph does not include physically impossible jump edges.
- [x] Enemies stop attempting jump edges that always fail at runtime collision.

## Phase 5: Position-Aware Pathfinding
Target files: `surface_pathfinder.dart` (+ tests).

- [x] Replace center-X approximation on intermediate surfaces with position-aware state/costing.
- [x] Ensure transition cost uses predecessor arrival position (or equivalent state anchor).
- [x] Preserve deterministic tie-break ordering for equal-cost alternatives.
- [x] Add tests for route choice where arrival X changes optimal next edge.

Acceptance criteria:
- [x] Paths no longer include avoidable backtracking caused by center-X approximation.
- [x] Deterministic path output is stable across repeated runs.

## Phase 6: Trajectory Predictor Quality and Performance
Target files: `utils/trajectory_predictor.dart`.

- [x] Add horizontal sweep (`prevX -> x`) when querying landing candidates.
- [x] Reuse candidate buffers to remove per-call allocations in hot path.
- [x] Add tests for high `velX` over thin platforms.

Acceptance criteria:
- [x] Predictor catches landings that were previously skipped at high horizontal speed.
- [x] No per-call list allocation in predictor hot path.

## Phase 7: Integration, Tuning, and Rollout
Target files: `enemy_navigation_system.dart`, `ground_enemy_locomotion_system.dart`, tuning docs/files as needed.

- [x] Re-tune `repathCooldownTicks`, `takeoffEps`, and related thresholds after behavior changes.
- [x] Validate interaction with jump snap velocity and commit direction in locomotion.
- [x] Run full nav-related tests plus targeted gameplay sanity checks.
- [x] Update `REVIEW.md` with completion status and residual risks.

Acceptance criteria:
- [x] NPC chase behavior is smoother in practical scenarios (jump chase, ledge chase, multi-platform pursuit).
- [x] No analyzer issues in touched files.
- [x] No deterministic regressions observed in repeated test runs.

## Definition of Done
- [x] All phase acceptance criteria are met.
- [x] Navigation-related tests pass.
- [x] `dart analyze lib/core/navigation` passes.
- [x] Updated documentation reflects final contracts and behavior.
