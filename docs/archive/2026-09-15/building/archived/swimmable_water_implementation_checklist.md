# Swimmable water implementation checklist

Status: implemented in `c062ad40`. Strategy: [swimmable water](swimmable_water_strategy.md).

## 1. Authored and streamed water

- [x] Add typed rectangular water data and strict shared source codec.
- [x] Preserve water through compilation, signatures, generated artifacts, runtime
  admission, captured Play, streaming, preparation and version rebinding.
- [x] Prove water creates no collision/support edges and invalid source fails.

## 2. Deterministic swimming

- [x] Add registered ECS immersion state and player swimming rules.
- [x] Integrate pre-motion classification, strokes, drag/gravity and post-motion
  snapshot state with existing actions, control locks and solid collision.
- [x] Test hysteresis, entry/exit, strokes, banks/floor, lifecycle, dry behavior,
  repeatability and replay execution.

## 3. Animated presentation

- [x] Extend terrain surface material source, validation and generator with frames.
- [x] Add the canonical atlas-backed water material.
- [x] Render cached world-aligned animated water with underwater foreground tint.
- [x] Verify tick-rate timing, pause, actor readability and asset disposal.

## 4. Authoring and example

- [x] Preserve water through editor load, drafts, save, duplication and Build.
- [x] Add water rectangle creation/edit/delete and material selection using current
  scene and transaction patterns.
- [x] Preview water and animation in editor and authored Play.
- [x] Supply a usable example with solid banks/floor and suitable kill plane.
- [x] Test editor authoring round trips and playtest/runtime parity.

## 5. Delivery

- [x] Complete technical and gameplay documentation and relevant working rules.
- [x] Run Core, pipeline, terrain material, relevant app/editor and validator checks.
- [x] Run generators and verify generated drift; inspect all diffs.
- [x] Commit independently validated milestones without unrelated user changes.
- [x] Archive completed strategy/checklist and report validation and limitations.

## Verification notes

All water-specific acceptance checks passed. Broad checks also exposed existing
Core/content and Play fixture failures, reproduced against original code. The
[validation record](swimmable_water_validation.md) records these separately.
The root generator retains three pre-existing stale runtime files; the isolated
27-chunk build including the example passed generation and a clean dry-run.
