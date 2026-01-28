# TODO — Autoscroll Camera Review & Hardening

---

## P0 — Correctness / Gameplay Feel

### [ ] Unify the player reference point used by camera *and* gameplay rules

**Problem (real in your code):**

* Camera pull uses **transform.posX** (`playerPosX`)
* Death rule uses **collider right edge** 
  So tuning thresholds will feel “off” depending on collider offset/size.

**Task**

* Pick ONE canonical driver for “player pushing camera”, recommended:

  * **Runner default:** `playerRightX` (collider front) — matches your death rule and visual intuition.
* Change `AutoscrollCamera.updateTick` signature to reflect semantics:

  * `playerX` → `playerRightX` (or `playerCenterX`, but then change death/culling rules too).
* Update the call site to pass collider-derived value (same math used in `_checkFellBehindCamera`).

**Acceptance**

* Camera pull begins exactly when **the same point** used for death checks crosses the threshold line.
* No hidden offset caused by `colliderAabb.offsetX/halfX`.

---

## P0 — “Autoscroll” sanity check (tuning intent)

### [ ] Confirm whether camera should have baseline autoscroll speed in V0

Right now the camera supports baseline scroll (`targetSpeedX`, `accelX`) inside `updateTick`. 
But your actual tuning values determine whether it truly autoscrolls.

**Task**

* Verify current `CameraTuningDerived.targetSpeedX` behavior and ensure the tuning actually sets a non-zero baseline if intended.
* If autoscroll is intended: set a baseline such as `targetSpeedX = maxSpeedX * speedLagMulX` with a sensible `speedLagMulX` (runner typical: `< 1.0` so player can catch up).

**Acceptance**

* With no input, camera still moves if “autoscroll runner” is the goal.
* If “follow-only” is intended, rename the module accordingly (don’t call it autoscroll).

---

## P1 — Maintainability / API clarity

### [ ] Rename parameters to reflect semantics (no more “playerX” ambiguity)

**Task**

* Rename `playerX` → `playerRightX` (or `playerCenterX`, whichever you pick). 
* Add doc comment: what coordinate space, what point, and why.

**Acceptance**

* Call sites self-document the semantics (no guessing).

### [ ] Document threshold math explicitly

Camera math today:

* `threshold = left() + followThresholdRatio * viewWidth` 

**Task**

* Add doc comment showing this exact formula.
* Add tuning guidance range (runner typical values).

---

## P1 — Performance / Allocation hygiene (only if profiling says it’s hot)

### [ ] Remove per-tick `CameraState.copyWith()` allocation

Currently every tick ends with `_state = _state.copyWith(...)`. 

**Options**

* **Option A (cleanest hot-loop):** make `_state` mutable (fields not `final`).
* **Option B (best API separation):** keep `CameraState` as an immutable snapshot, but store `centerX/targetX/speedX` as primitive fields in `AutoscrollCamera` and only materialize `CameraState` for snapshot export/debug.

**Acceptance**

* No per-tick CameraState allocations (confirm with DevTools allocations).

---

## P2 — Consistency with gameplay systems (culling + death)

### [ ] Standardize camera edge usage across systems

Right now:

* Death uses `_camera.left()` 
* Collectible/restoration use `_camera.left()` 

**Task**

* Ensure every “behind camera” rule uses the same edge definition + same player point definition (right edge, center, etc).
* Decide whether margins should be consistent across:

  * player death
  * enemy culling
  * pickups/items culling

**Acceptance**

* What you see on screen matches despawns and run-end rules exactly.

---

## P2 — Determinism / Stability tests (small but valuable)

### [ ] Add unit tests for camera invariants

**Test cases**

* `centerX` monotonic non-decreasing (camera never moves backward). 
* `targetX` monotonic non-decreasing. 
* `speedX` eases toward `targetSpeedX` under `accelX`. 
* Player pull only happens when `player*X > threshold`. 

**Acceptance**

* Tests guard future refactors and tuning changes.

---

## Notes — behavior worth keeping

* The monotonic clamp is correct for strict runner feel. 
* Two-stage smoothing (target and center) is a good approach for “player can push camera forward” behavior. 
