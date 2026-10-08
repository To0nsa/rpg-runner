# Boss combat corrections — October 8, 2026

## Reviewed source

Frozen implementation commit: `10f85b4c007a97cbfba9e22a6734452968cc2b45`.
Gameplay milestone: `61e74baba14a8a434644663330037199a4187d62`.
Deployed gameplay compatibility: `2026.10.10`; replay/command format 1,
`rules-v2`, `score-v4`, and `ghost-v1` are unchanged.

- Voidcaller uses fixed source-cell pivots and native diagonal strips. Portal,
  middle and surface pieces share their bright/pink phase. Nearest-neighbor
  drawing without edge antialiasing removes seams at 1.5x scale. Collision follows
  the corrected diagonal axis.
- Goddess moves to a checked upper corner, holds there while six hands sweep the
  floor at half-second intervals, then attempts a checked return. Each hand has
  its own warning animation and one-hit damage ledger. Her lifecycle store
  cancels pending hands on interrupted/replaced/dead casts and clears on ID reuse.
- Authored source-frame windows allow four Goddess claw swipes, two Shoggoth
  sweeps/spin passes and three Voidcaller beam pulses to hit again. Each window
  deduplicates targets across its poses; normal post-hit invulnerability remains.

## Focused verification

- Core/render analysis: no issues.
- Boss suite: 179 passing checks, including both characters clearing all four
  authored Forest arenas continuously.
- Barrage: flat Field and real Forest rooms at 30/60/90 Hz; six distinct ordered
  marks, stable upper-corner position throughout the sequence and safe return.
- Swing/pulse regression: repeated collision on one pose cannot repeat damage;
  later authored windows can, and revisiting an old frame cannot reopen it.
- Lifecycle: cancelled, same-ID replaced and dead barrages at all three rates;
  destroyed entities do not retain barrage state after ID recycling.
- Real-PNG render test: all active beam frames have an opaque continuous axis
  through every strip/endcap join at native and 1.5x scale. Rendered preview
  inspected after the correction. The final test supplies the effect component's
  own paint and verifies that drawing does not mutate it; the sprite copies tint
  and opacity while disabling edge antialiasing.
- Generated beam metadata is fresh. Authored runtime dry run validates all
  83 chunks, three levels, three parallax themes and three terrain materials.

The arena lifetime test now stops gameplay assertions when player death begins,
because Core freezes gameplay timers during the terminal death animation. The
blocked ordinary-teleport regression measures that action specifically, allowing
the new intentional corner move earlier in the fight.

## Production release

The gameplay milestone passed 1,128 client, 1,152 Core, 212 Functions, 203 worker
and 98 content-pipeline tests, analysis, the compiled protocol-rejection probe,
generated freshness and the production web build. Matching protocol (44) and
terrain (25) evidence was reused. The production dependency audit was clean.
The rendering follow-up changes only client inputs. Its client analysis, all
1,128 tests and the final web build passed again; unchanged components reused
that successful evidence. Core includes the 36-case traversal matrix: complete
finite Forest routes of 114/105/116 chunks for seeds 7/42/2026, plus 32 chunks
of Field and New Level for each seed. The looping Forest continuation and device
performance are excluded; boss combat has its separate integration coverage.

Cloud Build `e8390a4d-bb82-43c8-afdd-8567d3e544f8` succeeded, including the strict
36,000-tick benchmark in the final image at one CPU and 512 MiB. Immutable image:
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:883a635418aaca19803d547411cb6c460a2e9df29787ab108c303c97316f31aa`.
It was built from `61e74bab`; the final renderer-only commit has exactly the same
worker input hash, `d2616af880e0612a376ea920884df47ec92530eec520bc2a3ddad78154ead0e0`.
Canonical image-cache reuse verifies that hash and rechecks Cloud Build success.
The benchmark is a runtime throughput gate, not a full campaign or device
performance claim; authored boss gameplay is covered by the separate tests.

The coordinated release completed through `tools/release/release.ps1`.
Final source digest: `574e089ce00434dddadc16f1b0b6c62bcbe0d4fe5088f2f1285abf25bc5a88a9`.
Worker revision `replay-validator-00051-mx4` is healthy and serves 100% of traffic.
Issuer revision `runsessioncreate-00050-dlg` is healthy and serves 100%; direct
serving-revision inspection confirms that the temporary pause gate is absent.

Live [Hosting](https://rpg-runner-d7add.web.app) `main.dart.js` SHA-256:
`f3271b924c535398b23ddf267c7f328889115c3951c92f9dabf5f0287d1c3a50`.
Downloaded production bytes exactly match the final frozen build.

| Stage | October 8 UTC |
| --- | --- |
| Final preparation complete | 06:43:26 |
| Issuance paused | 06:45:24 |
| Authorized cancellations committed | 06:46:31 |
| Backend verified | 06:51:50 |
| Worker deployed | 06:53:44 |
| Hosting deployed | 06:54:14 |
| Issuance restored | 06:59:10 |
| Final inventory | 07:00:32 |
| Serving issuer verified | 07:00:55 |

Two unsubmitted `2026.10.9` tickets remained after issuance paused. Under the
owner's explicit authorization, a Firestore transaction rechecked their exact
candidate set, state/version, update times and absence of upload, validation and
reward evidence before marking only those tickets cancelled. Candidate-set
SHA-256: `3249374c2856f1ebc3bc9aec82f87c5b01ae9b6a0cb3d16562e33319a47f9a19`.
No profiles, validated runs or reward grants were changed.

The final live inventory contains zero active sessions, all six expected boards,
199 accepted validated runs and 199 settled rewards, with no pending/quarantined
settlement. Both validation and projection queues are `RUNNING`. The canonical
workflow saved the verified production baseline. No controlled post-cutover
accepted replay was produced during this verification window.

Evidence is in the final frozen checkout's
`.tmp/releases/rpg-runner-d7add/574e089ce00434dddadc16f1b0b6c62bcbe0d4fe5088f2f1285abf25bc5a88a9/`,
including preparation/cache provenance, Cloud Build results, live snapshots,
downloaded web artifact, cancellation receipts and issuer verification.

## Remaining verification

The preceding release could not complete signed-in browser gameplay because of
its existing `_Namespace` service-bootstrap failure. Infrastructure verification
does not establish gameplay, replay settlement or leaderboard/ghost smoke.
The October 8 browser retry was blocked by the Playwright profile already being
in use; the computer-use fallback reported no browser available. No user browser
was closed. The new web artifact has not been smoke-tested through a signed-in
gameplay session, and no native package was installed.
