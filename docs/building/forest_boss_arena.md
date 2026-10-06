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
- [ ] Render review, final diff review and branch commits.

Completed targeted evidence: strict source tests pass; entrance/confinement at
30/60/90 Hz passes for both characters; both characters defeat the boss through
real Core combat and resume scrolling. Final checks are still in progress.
No production deployment is authorized by this implementation request.
