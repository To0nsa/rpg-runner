# Production release: gameplay 2026.10.11

Deployed October 11, 2026 through `tools/release/release.ps1` to
`rpg-runner-d7add` / `europe-west1`, including Firebase Functions, the replay
worker and [web Hosting](https://rpg-runner-d7add.web.app).
The owner authorized deployment and cancellation of runs if necessary.
No cancellations or data resets were needed.

## Frozen source and scope

Frozen commit: `90d1becc20baaa7a62c6d2f4a5ce55221249d458`.
Source digest: `c549c40aca99e43eb8bd229d474ce6385c7da638b4813d5b4fd5221666e9f25e`.
Compatibility is `2026.10.11`, with `rules-v2`, `score-v4`, `ghost-v1`, and
replay/command formats 1.

This publishes the latest combat, boss, Forest progression, terrain preparation
and run-startup changes from `eef1274a`. The release repair commit changes tests
and documentation only; production gameplay was not changed during preparation.
See [boss behavior](../tdd/ancient_god_bosses.md),
[level composition](../gdd/level_composition.md), and
[run startup](../tdd/run_startup.md) for implemented contracts.

The web artifact uses `flutter build web --release` with the checked-in
production App Check configuration. Although `drawActorHitboxes` remains true
in source, `canUseRenderDebug` is false in release mode. Live actor, trigger,
projectile and trap debug overlays are therefore disabled in this release.

## Preparation evidence

The canonical coordinated preparation passed:

- Client analysis, 1,184 tests and the release web build.
- Core analysis and 2,138 tests.
- Functions build and all 212 emulator tests; the fresh production dependency
  audit reported no known vulnerabilities.
- Validator analysis, 258 tests and the compiled AOT protocol-rejection probe.
- Content-pipeline analysis and 98 tests.
- Matching cached protocol (44 tests) and terrain-material (25 tests) evidence.
- Generated-content freshness: 83 chunks, three levels, three parallax themes
  and three terrain materials.

Stale regression fixtures were aligned with the current notifier provider,
Bringer platform, final Goddess assembly segment, seeded shrine placement and
three-boss Forest progression. Both characters clear the three actual authored
arenas continuously in the explicit 1,800-unit compressed combat fixture.
Full assembly selection is checked separately for seeds 7, 42 and 2026.
Reviewed golden changes reflect Bringer's current 1.2x capsule and the intended
post-hit invulnerability fix; existing semantic assertions remain in place.

The Core suite includes the 36-case enemy traversal matrix: complete finite
Forest assemblies for seeds 7/42/2026 and 32-chunk Field/New Level prefixes,
for all four mobile enemies. These pursuit checks exclude authored spawns,
combat, player/camera/rendering acceptance and the repeated Forest continuation.
The compressed combat fixture does not claim full-route player traversal.

The first full Core attempt passed every assertion but exited 255 while deleting
a missing test-runner temporary directory. Its failure log was retained. A
canonical Prepare retry with an isolated temporary directory passed all 2,138
tests and exited cleanly, reusing the already successful components.
No failed attempt was treated as reusable passing evidence.

## Immutable worker and live artifacts

Cloud Build `2ef2a7ca-d80d-4c65-8138-3b1ac3dbbc28` succeeded. Its exact final
image passed all nine strict 36,000-tick benchmark gates at one CPU / 512 MiB.
This is throughput/determinism evidence, not full campaign or device performance.

Worker image:
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:84980dfdd3605f6634dc21e523efd604194843a2542a3dd3fc600f803a2851b1`.
Ready worker revision `replay-validator-00052-z9f` serves 100% of traffic.

Live `main.dart.js` SHA-256:
`b0c86f56860288e884a4a647be489b116abbd46c73668fb80f05a9795fac40c0`.
Downloaded production bytes exactly match the frozen release build.

Ready issuer revision `runsessioncreate-00053-cpr` serves 100% of traffic.
Direct serving-revision inspection confirms that
`RUN_SUPPORTED_GAME_COMPAT_VERSIONS` is absent, so the temporary pause is removed.

| Stage | October 11 UTC |
| --- | --- |
| Preparation complete | 10:42:13 |
| Issuance paused | 10:49:57 |
| Paused drain inventory | 10:50:40 |
| Functions deployed | 10:55:00 |
| Worker configuration complete | 10:56:54 |
| Hosting deployed | 10:57:20 |
| All six boards verified | 10:58:13 |
| Issuance restored | 11:02:04 |
| Final inventory | 11:03:05 |
| Serving issuer verified | 11:03:50 |

The old issuer image had been removed by managed cleanup. PauseIssuance used
the documented prepared-issuer rebuild with its explicit `release-paused` gate,
restored local environment bytes, and verified the healthy serving revision.
The coordinated backend deployment excluded `runSessionCreate` until resume.

Final live inspection found all 26 Functions ACTIVE, both replay queues RUNNING,
zero missing current/next boards, zero active sessions and no pending or
quarantined settlement. All 199 accepted validated runs and 199 settled grants
were preserved. The 248 historical sessions remain 199 validated, 25 cancelled
and 24 expired. The canonical workflow saved the verified production baseline.

Evidence is in the frozen checkout's
`.tmp/releases/rpg-runner-d7add/c549c40aca99e43eb8bd229d474ce6385c7da638b4813d5b4fd5221666e9f25e/`,
including preparation provenance, failed-cleanup and successful retry logs,
Cloud Build output, before/paused/final inventories, downloaded live web bytes,
`issuer-live-verification.json` and `browser-smoke.md`.

## Remaining verification

Browser automation loaded the old and newly published web builds. Both stop at
the loader with “This platform does not support the services required by the
game.” The new-build retry produced no browser console errors, but did not
reach signed-in gameplay. This pre-existing startup limitation remains open.

Controlled linked Play Games issuance, replay acceptance, once-only settlement,
leaderboard, generation-pinned ghost playback and live retired-version rejection
remain unverified. No controlled post-cutover accepted replay was produced.
Local compatibility tests and live infrastructure checks do not complete those
smoke checks. No native package was built or installed by this release.
The [release checklist](../building/rescue_release_operations.md) remains active.
