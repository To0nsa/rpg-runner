# 00 — Vision

## One-liner
A **mobile 2D mid-core RPG runner** where you build a character loadout, then execute **tight, deterministic runs** with **skill-based combat**, chasing **leaderboards and ghost runs**.

## North Star
Make every run feel like: **"My build matters + my execution matters."**
Not an idle runner. Not a pure arcade runner. A combat-first runner with real mastery depth.

## Target platforms
- **Mobile first** (Android early, iOS-ready architecture)
- Designed for **short-to-medium sessions** with fast restarts and strong replay value

## Target players
- Mid-core mobile players who like **progression + mastery**
- Players who enjoy: action timing, spacing, aim/commit decisions, build crafting
- **RPG fans** who want **light narrative context** and **fair progression**
- Built to support a **global audience**

## Core fantasy
You're a combat runner. You don't "auto-fight". You **commit** to actions with timing and positioning, and you win by:
- picking the right kit,
- reading enemies/terrain,
- executing clean inputs.

## Core gameplay loop

### Run types (per level)
Every level supports two run types:

1) **Practice (Random Seed)**
- Seed: random
- Purpose: variety, learning, farming, experimentation
- **No leaderboard submission**
- Only scoreboard: local personal bests (device only)

2) **Competitive (Fixed Seed)**
- Seed: fixed for a **time window** (seasonal window)
- Purpose: fair comparison + mastery chase
- **Leaderboard submission enabled**
- **Ghost replays enabled (only against Top 10)**

**Weekly Challenge (Featured Competitive)**
- A highlighted competitive run on a curated level/ruleset for the week.
- Same competitive constraints: fixed seed + leaderboard + Top 10 ghosts.
- Surfaced prominently in UI, but does **not** replace the player's normal selected level by default.

### Meta loop
1. Progress through runs to earn rewards (**in-game currency**).
2. Spend rewards in the meta to unlock weapons, abilities, and Codex entries.
3. Build loadouts per character (gear + melee / ranged / spell / mobility ability slots).
4. Pick a level + run type:
   - Practice (random) for variety/farming
   - Competitive (fixed) to chase rank/ghosts
   - Weekly Challenge for the featured competition
5. Race against **top ghost runs** from **competitive leaderboards**.

### Run loop (in-run)
1. Run through a scrolling level (obstacles + enemy encounters)
2. Make continuous micro-decisions:
   - avoid hazards (jump/mobility),
   - commit attacks (melee/ranged/spell),
   - commit defensive moves (parry/block),
   - manage cooldowns/resources,
   - maintain momentum/positioning
3. Outcome: score + currency + (if competitive) rank

## Unique selling points
- **Deterministic, tick-based gameplay** (reliable, fair, replayable)
- **Loadout-driven combat** (your kit changes how you play)
- **Skill + build** combine (execution matters, not just stats)
- **Build philosophy**: multiple **viable, equivalent-power** playstyles; the "best" loadout depends on the **level's hazards and enemy composition**, not a universal meta build.
- **Two run types per level**:
  - Practice (random seed, no leaderboard)
  - Competitive (fixed seed, leaderboard + ghosts)
- **Weekly Challenge spotlight** (featured competitive track)
- Leaderboards are **score-first**, with **time as a tie-breaker**.
- **In-game Codex (Library)**: quick entries for enemies/levels/characters with light flavor + practical tips.

## Pillars
1. **Clarity before complexity**
   - Player always understands what will happen when committing an action.
2. **Determinism + fairness**
   - Same inputs → same results; no "random feels-bad" in competitive contexts.
3. **Low-branching, responsive controls**
   - Minimal ambiguity. No accidental casts. No hidden state traps.
4. **Readable combat**
   - Strong silhouettes, clean telegraphs, consistent hit feedback.
5. **Mobile-session friendly**
   - Runs are short, rewarding, and restartable without friction.

## Player controls (current intent)
- Designed for **two-thumb mobile play**
  - **Left thumb:** virtual joystick for movement
  - **Right thumb:** action buttons (mobility / melee / ranged-or-spell / bonus) + jump
- Targeting models:
  - **Instant** (quick tap uses facing direction / default)
  - **Aim + confirm** (hold to aim, release to commit)
- Key rule: **aim is a commitment**, but **survival is priority** (mobility ability cancels aim)

## Game feel goals
- Combat is **snappy**: short windups, visible recovery, meaningful hitstun
- Movement is **smooth but grounded**: clean jump arcs, predictable landings
- Enemies feel **alive**: slight reaction delay, not perfect tracking
- Feedback is **juicy but readable**: hit flash, knockback, clear VFX without clutter

## Content scope (ready for playtesting)
A playable slice that proves the loop:
- **2 characters** with distinct identity
- Per character:
  - at least **4 abilities per main action slot** (to validate loadout choices)
- **6 enemies** with different behaviors (melee, ranged, jumper, tank, etc.)
- **2 levels/biomes** (different obstacle + encounter patterns)
- **Run types**
  - Practice (random seed, no leaderboard)
  - Competitive (fixed seed) with **online leaderboards + ghost replays (Top 10)**
  - Weekly Challenge (featured competitive) with **weekly leaderboard + Top 10 ghosts**

## Art direction
- **Side-view 2D HD** (high-res sprites), readable on mobile at multiple DPI scales
- Style: **mature, almost dark fantasy** grim mood, restrained color palette, high contrast/value clarity, minimal "cartoony" exaggeration
- Strong silhouettes and clear telegraphs at runner speed (readability > detail)
- Animation priority: clear anticipation → impact → recovery
- VFX: minimal but sharp (avoid screen noise; favor readable impacts and debuffs)

## Technical intent (constraints that shape design)
- **Flutter + Flame**
- Deterministic simulation (tick-based)
- Low-branching gameplay code
- Data-driven catalogs for:
  - characters, weapons, abilities, enemies, levels
- Competitive + ghosts require:
  - deterministic input-record + replay
  - seed + ruleset versioning for compatibility

## Monetization principles (placeholder)
- Don't undermine mastery with pay-to-win.
- Keep the "fair competitive loop" intact.
- Supporter Pack
- QoL packs (presets/slots/inventory)
- Rewarded ads
- Cosmetic packs
- Additional content (expansion packs)

## Success metrics (early)
- A run is fun even when you lose.
- Players can explain in 1 sentence why they died.
- Retention proxy: players voluntarily retry to beat their ghost / leaderboard.
- Clear "build curiosity": players want to try different loadouts.

## Non-goals (for now)
- No in-run loadout changes
- No complex meta economy
- No giant open-world or story campaign
- No heavy PvP (leaderboard/ghosts only)

## Future features (not committed)
Potential additions once the core loop is proven:
- More characters and purchasable **expansion packs** (levels/biomes + enemies + characters)
- Replay viewer for top runs (without racing)
- Advanced progression (passives / ultimates / deeper build synergies)
- Seasonal events with unique rewards
- Future modes: expand beyond the core runner into **Challenge/Platformer**, **Survivor/Horde**
- Accessibility and control options (left-handed layout, button scaling, joystick tuning)

## Key risks
- **Controls ambiguity / misinputs on mobile**
  - thumb occlusion, fat-finger errors, joystick drift, action button proximity, and aim/commit rules that feel inconsistent
- **High-speed readability**
  - telegraphs, hit VFX, damage numbers, and parallax noise fighting for attention at runner speed
- **Loadout system complexity creep**
  - too many slots/ability variants without strict constraints → balance hell + UI bloat + "optimal build only" meta
- **Determinism integrity**
  - any non-deterministic timing, floating-point drift, or frame-rate coupling breaks fairness and makes ghosts unreliable
- **Ghosts / leaderboards cost + cheating surface**
  - storage/bandwidth, replay validation, and basic anti-tamper needs (at least input-hash + versioning)
- **Content scaling**
  - adding enemies/abilities multiplies animation + VFX + balance work; without a tight content pipeline you'll stall

## Design stance
This game wins by being **tight, fair, and replayable**.  
If a feature makes the game messier, less readable, or less deterministic, it's not worth it.
