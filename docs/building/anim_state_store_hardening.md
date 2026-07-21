# AnimStateStore Hardening

Status: proposed work; not part of the documentation cleanup.

`AnimStateStore` is a structure-of-arrays store written by `AnimSystem` and
read by snapshot construction. It currently has a correctness footgun:
`add(entity)` resets an existing entity to idle frame zero because
`SparseSet.addEntity` returns the current dense index for an existing entity.

## Required outcome

- Repeated initialization must never silently reset live animation state.
- A deliberate reset must be explicit.
- Default array initialization must have one owner.
- Animation writes must preserve the existing allocation-light SoA layout.

## Implementation direction

1. Replace ambiguous `add` semantics with either:
   - `ensure(entity)`, which adds only when absent, plus an explicit
     `reset(entity)`; or
   - a strict `add(entity)` that rejects existing entities.
2. Keep default `idle` / frame-zero initialization only in `onDenseAdded`.
3. Decide whether `AnimSystem` should retain indexed writes or receive a small
   typed write API. Do not add wrappers to a hot path without a measured need.
4. Document that `animFrame` is a non-negative tick-relative render hint and
   that `AnimSystem` is its normal writer.

## Acceptance and validation

- Adding or ensuring an existing entity preserves its current animation/frame.
- Explicit reset restores `AnimKey.idle` and frame zero.
- Add/remove/swap-remove stay aligned across both SoA arrays.
- `dart analyze packages/runner_core`
- `flutter test test/core/anim_system_test.dart`
- Add focused store lifecycle coverage before changing the API.
