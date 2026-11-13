# Campaign combat introduction

Completed locally on November 14, 2026. See the
[verification record](../../../verification/campaign-combat-tutorial-2026-11-14.md).

Requested: introduce Projectile at the enemy after Dash, lock further shots after
the first real launch, introduce Sword at melee reach, and unlock Projectile after
the introductory strike executes. Keep movement and existing actions available.

The checkout already contains the tutorial framework and unrelated work. Preserve
it; task baseline is in ignored `build/combat_tutorial_baseline/`.

- [x] Extend authored sequence, strict marker validation and shared editor form.
- [x] Add read-only Core combat opportunity and real execution feedback; preserve
  damage, resource costs, cooldowns, AI and replay commands.
- [x] Integrate ordered lesson state, cross-device lock, spotlight and practice hint.
- [x] Validate real Reporting for Duty encounter, interrupted/rejected actions,
  early enemy death, restart, alternate builds, authoring and localization.
- [x] Update implemented docs, generate content, review task diff, rebuild Windows
  editor when closed, and archive this checklist with evidence.

Acceptance: a fresh action resumes and performs each attack; only a real projectile
launch locks further shots, only a real sword execution completes practice. No
instruction can pause on an unavailable action. A missing/dead target releases the
lock and reveals attacks without freezing the attempt. Core owns combat geometry;
presentation owns guidance. Tests must distinguish snapshots from real traversal.

Review refinements:
- Wait for the real enemy to stop inside blade reach; moving-target homing can
  otherwise miss when AI stops during the sword windup. The continuous regression
  requires a landed hit and unchanged player health.
- Require the entire enemy spotlight inside the visible device crop, not just the
  Core camera canvas. Share geometry with editor preview and attach its resolver
  through the gameplay surface lifecycle.
- Keep one combat creation action in the sequence panel; reuse the existing
  terrain-resolved actor preview and its image-cache ownership.
