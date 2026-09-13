# Swimmable water implementation checklist

Status: in progress. Strategy: [swimmable water](swimmable_water_strategy.md).

## 1. Authored and streamed water

- [ ] Add typed rectangular water data and strict shared source codec.
- [ ] Preserve water through compilation, signatures, generated artifacts, runtime
  admission, captured Play, streaming, preparation and version rebinding.
- [ ] Prove water creates no collision/support edges and invalid source fails.

## 2. Deterministic swimming

- [ ] Add registered ECS immersion state and player swimming rules.
- [ ] Integrate pre-motion classification, strokes, drag/gravity and post-motion
  snapshot state with existing actions, control locks and solid collision.
- [ ] Test hysteresis, entry/exit, strokes, banks/floor, lifecycle, dry behavior,
  repeatability and replay execution.

## 3. Animated presentation

- [ ] Extend terrain surface material source, validation and generator with frames.
- [ ] Add the canonical atlas-backed water material.
- [ ] Render cached world-aligned animated water with underwater foreground tint.
- [ ] Verify tick-rate timing, pause, actor readability and asset disposal.

## 4. Authoring and example

- [ ] Preserve water through editor load, drafts, save, duplication and Build.
- [ ] Add water rectangle creation/edit/delete and material selection using current
  scene and transaction patterns.
- [ ] Preview water and animation in editor and authored Play.
- [ ] Supply a usable example with solid banks/floor and suitable kill plane.
- [ ] Test editor authoring round trips and playtest/runtime parity.

## 5. Delivery

- [ ] Complete technical and gameplay documentation and relevant working rules.
- [ ] Run Core, pipeline, terrain material, relevant app/editor and validator checks.
- [ ] Run generators and verify generated drift; inspect all diffs.
- [ ] Commit independently validated milestones without unrelated user changes.
- [ ] Archive completed strategy/checklist and report validation and limitations.
