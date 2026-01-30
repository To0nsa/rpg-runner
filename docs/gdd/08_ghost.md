# Ghost Runs (Race Mode)

This document defines **Ghost Race**: how the game replays a Top-10 run as a **full “shadow world”** in the same level while the player plays live.

**Design intent (your vision):**
- The player and the ghost run in the **same level**.
- The ghost run is rendered **black & white**.
- The ghost includes **everything** from that run: enemies, animations, VFX, etc. (all black & white).

---

## 1. Goals (non‑negotiable)

1. **Fair + deterministic**
   - Ghost playback must be deterministic: same seed + same rulesetVersion + same inputs ⇒ same ghost run.
2. **Visual clarity**
   - Ghost is always visually distinct: **grayscale + optional reduced alpha**.
3. **“Full world replay”**
   - Ghost includes **enemies + projectiles + VFX** from that run, not just a player trail.
4. **No gameplay interaction**
   - Ghost must never affect the live run (no collisions, no damage, no pickups).
5. **Hard gate compatibility**
   - If `client.gameCompatVersion != ghost.gameCompatVersion`, Ghost Race is **disabled** (same policy as Competitive/Weekly).
6. **Mobile performance**
   - Must remain playable on phone hardware (CPU/GPU bounded).

---

## 2. User experience spec

### 2.1 Entry points
- Leaderboards (Competitive/Weekly): select a Top‑10 entry → **Race Ghost**.
- Weekly quick flow may deep-link to Weekly leaderboards first to select ghost.

### 2.2 What the player sees
- Live run renders normally.
- Ghost world renders:
  - grayscale (black & white) for *all* ghost entities and their VFX,
  - optional alpha (e.g. 60–80%) so it never hides hazards,
  - optional “rank badge” above ghost player only (e.g. `#1`).
- Ghost world uses the **same camera** framing as the live run (shared camera position), but it is a separate simulation.

### 2.3 What the player can do
- Player plays normally.
- Ghost is not targetable and does not affect outcomes.
- HUD: show “Ghost distance delta” (behind/ahead) as a small unobtrusive number.

---

## 3. Core design decision: how to represent “full world” ghosts

There are two viable strategies:

### Deterministic dual simulation
- Store **only player inputs** (plus minimal metadata).
- During Ghost Race, run a second **ghost simulation** in lockstep:
  - same seed
  - same ruleset/score versions
  - same deterministic tick rate
  - feed recorded inputs into the ghost sim
- Render the ghost sim’s world in grayscale.

**Pros**
- Storage is small (input stream).
- Ghost includes everything (enemies/VFX) automatically.
- Versioning is clear (compat gate + schema).

**Cons**
- CPU cost: basically **2× simulation** (live + ghost).

---

## 4. Data model

### 4.1 Ghost identity & compatibility
Ghosts are stored and fetched by:
- `boardKey`
- `rank` or `entryId`
- `ghostVersion`

Hard gate compatibility fields:
- `gameCompatVersion` (must match client)
- `rulesetVersion`
- `scoreVersion`
- `tickHz` (must match, or the replay is invalid)

### 4.2 Ghost payload schema (v1)
```txt
GhostReplayV1 {
  ghostVersion: 1
  boardKey
  entryId
  playerDisplayName?   // optional; never used for logic
  gameCompatVersion
  rulesetVersion
  scoreVersion
  tickHz
  seed
  inputStream          // compressed events (see §4.3)
  checksum             // hash over canonical bytes (anti-tamper / integrity)
}
```

### 4.3 Input stream encoding (event-based)
Record only what the sim needs:

- **Move axis changes** (float quantized):
  - `MoveAxisEvent { tick, axisQ }` where `axisQ ∈ [-256..256]` (or [-127..127]).
- **Button intents**:
  - `PressEvent { tick, slot }`
  - `ReleaseEvent { tick, slot }` (for aim+commit)
- **Aim direction updates** (quantized vector):
  - `AimEvent { tick, slot, dxQ, dyQ }` where dx/dy in [-256..256].

Compression:
- delta-encode ticks (`dt = tick - prevTick`), varint.
- RLE repeated move axis.
- omit AimEvent spam by:
  - only emitting when quantized value changes
  - optional max rate (e.g. ≤ 15 Hz) if determinism allows.

> Rule: quantization and emission policy must match live input router behavior, otherwise deterministic replay breaks.

---

## 5. Runtime architecture (Ghost Race)

### 5.1 Two worlds, one camera
- **LiveWorld**: normal authoritative run.
- **GhostWorld**: separate ECS/simulation instance:
  - same levelId
  - same seed
  - same deterministic tick loop
  - no persistence and no submission

The camera:
- driven by LiveWorld only
- used to render both worlds in the same viewport (GhostWorld is just another render layer).

### 5.2 Tick scheduling
For each `tick`:
1. Apply local inputs to LiveWorld.
2. Apply recorded inputs for current tick to GhostWorld.
3. Step LiveWorld (authoritative).
4. Step GhostWorld (replay).
5. Render: LiveWorld normal + GhostWorld grayscale.

Important:
- Both worlds must use the same `tickHz` and same deterministic time step.
- Never use wall-clock time or frame delta to drive sim outcomes.

### 5.3 Isolation rules (no gameplay interaction)
GhostWorld must not:
- collide with LiveWorld entities
- affect pickups, scoring, spawns, RNG, camera, or HUD logic

Implementation rule:
- GhostWorld writes **zero** into any shared stores. Treat it as read-only from the rest of the app.
- If you share asset caches, that’s fine (textures/audio).

---

## 6. Rendering: grayscale “shadow world”

### 6.1 Visual rule
Every ghost-world visual must be grayscale:
- sprites
- animations
- particles
- VFX
- hit flashes

### 6.2 Recommended render approach in Flame
**Best tradeoff:** render GhostWorld with a grayscale `Paint` at the root of its component tree.

**Root paint decorator**
- Put GhostWorld under a `Component` that applies:
  - `ColorFilter.matrix(grayscaleMatrix)`
  - optional `opacity` multiplier
- Everything drawn by that subtree inherits the paint.

### 6.3 Grayscale matrix (standard)
Use a luminance matrix (sRGB):
```txt
[ 0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0,      0,      0,      1, 0 ]
```

### 6.4 Layering + readability
- GhostWorld is rendered **behind** live player/VFX if possible.
- Reduce opacity slightly so it cannot hide hazards.
- Optional outline/highlight for the ghost player only (still grayscale).

---

## 7. Storage, caching, and fetching

### 7.1 Availability policy
- Only **Top 10 ghosts** per board are guaranteed.

### 7.2 Client caching
- Cache ghosts locally by `(boardKey, entryId, ghostVersion)`.
- Eviction:
  - LRU by byte size cap (mobile-friendly).
  - Always keep the last raced ghost cached.

### 7.3 Fetch flow
- On leaderboard screen: fetch Top 10 entries (light).
- When user selects a row: fetch that ghost payload (heavy).
- Auto-cache on fetch, clean up when leaving the app.

---

## 8. Validation and anti-tamper posture (minimum)

Ghosts increase cheating surface. Minimum sane checks:

- Server only accepts ghosts for runs that place in Top 10 (or stores ghost separately and promotes on rank).
- Store a `checksum` of canonical replay bytes.
- Store replay metadata (versions, seed, tickHz).
- Reject if:
  - compat mismatch
  - impossible values (axis out of range, tick decreasing)
  - schema mismatch

> Full anti-cheat (authoritative replay verification) can be deferred, but integrity checks should exist.

---

## 9. Performance constraints & mitigations

Running a full second simulation can be expensive.

Mitigations:
1. **Culling**
   - GhostWorld doesn’t need to simulate far-off entities if your sim supports spatial activation.
2. **No audio**
   - GhostWorld produces no audio/haptics.
3. **Reduced VFX budget**
   - Keep VFX deterministic but cheaper (same triggers, cheaper emitters) *only if it doesn’t change timing/state*.
   - Safer: keep VFX identical but render them with a lightweight renderer.

Acceptance performance target:
- Ghost Race should keep stable FPS on mid-range phones, with “worst-case” enemy density.

---

## 10. Acceptance checklist

Ghost Race is “done” when:

- Selecting a Top‑10 entry launches a run with a ghost overlay.
- Ghost world is fully grayscale (sprites + enemies + VFX).
- Ghost never affects live gameplay.
- Replay is deterministic and stable across devices for the same build.
- Hard gate disables Ghost Race on incompatible versions with a clear “Update required” message.
- Caching prevents repeated downloads of the same ghost.

---

## 11. Implementation notes

- Treat GhostWorld as a **second `GameCore`** instance with:
  - its own ECS stores
  - its own deterministic RNG seeded from the same seed
  - its own input router fed by replay events
- Make “ghost rendering” a first-class flag:
  - so entities/VFX can disable audio and use grayscale paint automatically.
- Ensure the same **content catalogs** are loaded for both worlds:
  - entity definitions, spawns, tuning.

---

## 12. Known risks

- **Determinism drift**: float math, time coupling, or non-deterministic collections can desync ghost.
- **CPU budget**: two full sims might be heavy; you may need spatial activation and careful ECS hot loops.
- **VFX determinism**: particle randomness must be seed-driven in GhostWorld too.

If any of those risks triggers, you’ll see ghost desync (ghost enemies not where expected). Treat desync as a blocker.
