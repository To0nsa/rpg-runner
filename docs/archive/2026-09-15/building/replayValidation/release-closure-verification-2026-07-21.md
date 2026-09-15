# Replay Validator Release Closure Verification

Date: July 21, 2026
Project: `rpg-runner-d7add`
Region: `europe-west1`
Status: Complete; production updated and temporary data/resources removed

## Purpose

This record closes the verification gates that remained open after the July 19
successor audit and pre-release rollout. It is mutable implementation evidence
under `docs/building/`; the dated audits under `docs/audit/` remain immutable.

The repository owner confirmed that no staging project exists and the game has
not been released. The existing production project was therefore used as the
controlled pre-release environment. All player-shaped records used disposable
anonymous accounts, and all temporary infrastructure and scoped records were
removed after verification.

## Source and image

- Fix commit:
  `0861f98baa25affc5356accbcfb383ff9c2b7649`
- Published containing commit:
  `9eea5cfd6b3a5b7ce2e90b928215446ae90c1b85`
- Local and registry manifest digest:
  `sha256:92adcfe4bfc57647b0be5c11105aee9f466f555e786b51084f0a00fd5351fa22`
- Cloud Run platform image digest:
  `sha256:2b93650cda8c0b5058b9ca000e43e3185748ab9235b3d2c951114b8827a3c7c1`
- Runtime user: `65532:65532`
- Trivy `0.67.2` High/Critical result: zero findings
- Local unconfigured-container smoke: `/live` returned `ok`; `/ready` failed
  closed with HTTP 503.

The image was built from a detached clean checkout at the fix commit. The
unrelated in-progress Core workspace was not present in the build context.

## Resource-boundary correction

The first live expanded-replay check exposed excessive allocation in
`collectReplayBytes`. A growable `List<int>` retained unnecessary capacity and
the 512 MiB container restarted after processing a payload just above the
32 MiB expanded limit.

Commit `0861f98b` replaced the growable list with `BytesBuilder(copy: false)`,
tracked the observed byte count separately, and returned the compact
`Uint8List`. The corrected image then completed all five cases on a 512 MiB,
1 CPU, concurrency-1 Cloud Run revision:

| Case | HTTP | Terminal reason |
|---|---:|---|
| Declared compressed size above 8 MiB | 200 | `replay_compressed_size_limit_exceeded` |
| Gzip output above 32 MiB | 200 | `replay_expanded_size_limit_exceeded` |
| JSON depth above 64 | 200 | `replay_json_nesting_limit_exceeded` |
| Command frames above 250,000 | 200 | `replay_frame_limit_exceeded` |
| Duration above 6 hours | 200 | `replay_duration_limit_exceeded` |

Every case ended `rejected` with its reward grant `revoked_final`. The corrected
revision logged no memory-limit event or error entry. Cloud Monitoring returned
11 memory-usage samples with a peak one-minute mean of 15.25 MiB during the
verification window.

A separate revision with a 1 ms simulation allowance returned the stable
`simulation_time_limit_exceeded` terminal result, after which the normal
120,000 ms setting was restored.

## Internal-error grace lifecycle

A private temporary service used the release image and a temporary service
identity with the same Firestore role as production but no replay-object read
role. The grace window was reduced to 5 seconds and automatic revocation was
paused for the first phase.

- Attempts 1 through 7 returned HTTP 503, remained `pending_validation`, and
  did not set the grace timestamp.
- Attempt 8 returned HTTP 503, persisted the first-error timestamp, and left
  the provisional reward unchanged.
- The service was restarted with automatic revocation enabled.
- Attempt 9, after the grace deadline, returned HTTP 200, preserved the exact
  original timestamp, ended the session as `internal_error`, and changed the
  grant to `revoked_final`.
- No validated-run evidence was written.

The temporary service, project role binding, and service identity were deleted.
Post-removal checks found neither the service nor the role binding.

## Compatibility matrix

The release image completed nine deployed cases:

| Case | Result |
|---|---|
| Current supported contract | accepted, settled, HTTP 202 |
| Retired game compatibility | `game_compat_version_unsupported` |
| Ticket identity mismatch | `ticket_identity_mismatch` |
| Loadout digest mismatch | `loadout_digest_mismatch` |
| Retired ruleset | `board_compat_version_unsupported` |
| Retired score version | `board_compat_version_unsupported` |
| Retired ghost version | `board_compat_version_unsupported` |
| Board binding mismatch | `board_id_mismatch` |
| Ticket outside board window | `ticket_board_window_mismatch` |

All eight invalid cases returned HTTP 200, ended `rejected`, and finalized the
grant as `revoked_final`.

## Atomic handoff matrix

The real Firestore adapter matrix completed 23 scenarios:

- eight accepted-handoff scenarios;
- eight rejected-handoff scenarios;
- seven internal-error scenarios;
- successful commits, session conflicts, reward conflicts, validated-document
  conflicts where applicable, pre-commit connection loss, post-commit response
  loss, stale lease tokens, and expired leases;
- zero residual matrix fixtures.

This supplies direct production-adapter evidence for atomicity, idempotency,
and stale-writer rejection without changing non-fixture records.

## Board-wide projection load

An isolated competitive board contained 250 players and 273 accepted validated
runs, including 24 competing results for one player. The exercise sent 321
out-of-order and duplicate deliveries at concurrency 25, followed by eight
concurrent board reconciliations, a stale delivery, and a final reconciliation.

Observed result:

- 321 deliveries completed;
- 371 bounded retry responses occurred under contention and converged;
- exactly 250 player-best documents remained;
- the selected best for the repeated player never regressed;
- the materialized top 10 exactly matched canonical player-best ordering;
- all eight reconciliation calls returned HTTP 200;
- no generation-less ghost manifest was published.

The helper's first preparation used an empty Firestore map in fixture metadata;
that preparation was deleted with zero residue and replaced with a non-empty
fixture marker before the successful run. The successful board and all 525
scoped documents were then deleted. The clean verifier reported
`residualCount: 0`.

## Production update

Before deployment, the validation queue was empty. Three older reconciliation
tasks for the current monthly board were retrying on revision
`replay-validator-00024-rzt`. The same board reconciled with HTTP 200 through
the verified temporary revision.

The release digest was deployed directly because the game is unreleased:

- production revision: `replay-validator-00025-wfv`;
- traffic: 100%;
- 1 CPU, 512 MiB, 240-second request timeout, concurrency 1, maximum scale 10;
- startup `/ready` and liveness `/live` both healthy;
- private invocation retained;
- all three prior reconciliation tasks completed immediately;
- validation and projection queues both returned to zero tasks.

The two temporary Cloud Run services were deleted. A final service inventory
found zero service names with the `rv-audit-` prefix.

## Synthetic-account cleanup

Two disposable accounts were tracked only by one-way hashes:

- `6ba37a21b05b1702`
- `a71d88ce511614dd`

Cleanup used the deployed account-deletion worker, including its leases,
bounded pages, repeated board scans, 15-minute quiet period, final pass, and
Auth deletion. The worker was invoked directly to advance the same production
workflow without bypassing a stage.

Both requests reached `complete`. Exact verification at
`2026-07-21T21:03Z` found zero matching profiles, ownership records,
idempotency records, quota documents, sessions, grants, validated runs,
player-best rows, ghost manifests, views, pending replay objects, or validated
replay objects. Both credential fields were scrubbed before retained evidence
was inspected.

The read-only production inventory at `2026-07-21T21:03:40Z` reported:

- one non-synthetic profile and ownership record, untouched;
- 27 run sessions: 9 expired and 18 validated;
- 18 settled reward grants and 18 accepted validated runs;
- zero terminal/evidence, identity, grant, stale-settlement, or projection
  source inconsistencies;
- 11 retained deletion completion records, all `complete` and compact;
- zero active or retryable deletion request.

## Validation summary

- Replay validator: analysis clean, 75/75 tests passed in both the working and
  detached clean checkout, and AOT server compilation passed.
- Shared protocol: analysis and all tests passed.
- Deterministic Core at the clean release commit: analysis and all 39 tests
  passed.
- Functions: locked install, build, and all tests passed.
- Root Flutter package: `flutter analyze lib test` passed; the broad test run
  reached 480 passing tests before one generated-file comparison failed only
  because the Windows checkout used CRLF while the generator returns LF.
- GitHub Actions on published commit `9eea5cfd`: Functions run 5 succeeded and
  Replay Validator run 4 succeeded.

The Windows-only generated-file comparison is outside the validator change and
does not alter the Linux replay-validator workflow result.

## Immutable evidence check

The prior audit blobs were rechecked after all implementation and production
work:

- July 18 audit:
  `4b075d4b1b571d3c947d79f9b0bbb22c519aca20`
- July 19 successor audit:
  `f966a89f8b60c3b7c60dcfa1482d8e5ddbf6534b`

Neither prior audit was edited.
