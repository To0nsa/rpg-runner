# Forest boss arena

Branch: `feature/forest-boss-arena`; isolated worktree:
`C:/dev/rpg_runner/.tmp/forest-boss-arena`.

User approval: implement the agreed first-boss arena and stop the player only
after the complete arena is framed, show the entrance, then enable combat.
Existing Forest authoring edits in the main worktree remain untouched.

- [x] Dedicated branch and isolated source baseline.
- [x] Stable Bringer identity, source sheet, deterministic attacks and entrance.
- [x] Core lifecycle, bounds, retention, outside-actor isolation and exit release.
- [x] Authored arena and deterministic single-candidate Forest assembly slot.
- [x] Shared decoding/placement and editor metadata Save/Play path.
- [x] Snapshot-driven HUD and boundary presentation.
- [x] Fixed defeat score and excluded arena time on client and worker.
- [x] Matching prepared compatibility `2026.10.8` / `score-v4`.
- [x] TDD, GDD and focused implementation regressions.
- [x] Final analyzers, generated freshness, Core/pipeline/editor/client/worker checks.
- [x] Seeded traversal matrix and compiled worker benchmark.
- [x] Render review, final diff review and branch commits.

Implementation delivered in `1c350b0e6`. Final Core validation passes 929 tests;
the client Core suite passes 495, shared pipeline 91, worker/boss replay 90,
editor 8, Flame 11, render review 3 and backend emulator 7. Both characters
defeat the boss through real Core combat and resume scrolling. Generation and
asset manifests are fresh; local compiled benchmark gates pass with a documented
Forest-bot limitation. See `docs/verification/forest_boss_arena.md` for evidence.
No production deployment is authorized by this implementation request.
