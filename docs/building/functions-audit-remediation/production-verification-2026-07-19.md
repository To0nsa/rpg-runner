# Functions Audit Remediation Production Verification — July 19, 2026

## Scope and authorization

The repository owner authorized direct production verification in
`rpg-runner-d7add` because no staging project exists and the game is not live.
This record supplements the
[production deployment record](production-deployment-2026-07-19.md). It does
not modify or replace the immutable
[July 18 audit](../../audit/functions/functions-audit-2026-07-18.md).

Verification used:

- a read-only, aggregate Firestore inventory;
- an anonymous Firebase Auth canary exercising authenticated callables;
- one valid ranked replay and one deliberately invalid ranked replay;
- the production account-deletion workflow for synthetic canary users;
- manual invocations of existing scheduled maintenance jobs;
- read-only Cloud Logging, Scheduler, Monitoring, Auth, and Storage checks.

Exact synthetic UIDs and run-session IDs are intentionally omitted. Short
one-way hashes are retained only where they distinguish the two deletion
workflows. No production user data was copied into this document.

## Verification tooling

The following repository tools make the checks repeatable:

```powershell
node functions/tool/production_inventory.mjs --project rpg-runner-d7add
$env:FIREBASE_WEB_API_KEY = '<Firebase web API key from the authorized environment>'
node functions/tool/production_canary.mjs `
  --project rpg-runner-d7add `
  --region europe-west1
```

`production_inventory.mjs` is read-only and emits PII-free aggregates.
`production_canary.mjs` creates a disposable anonymous account, stores no Auth
token, verifies the flow, and requests account deletion in a `finally` path.
Its ignored local recovery-state file contains exact synthetic identifiers so
an interrupted canary can still be erased.

The immutable audit SHA-256 remained
`F6D7FED2061F7B307BAF5C848F925CFF51F50D135DB81CAAE28FCFAB40DD601B`
after verification.

## Read-only production inventory

The final inventory was captured at `2026-07-19T12:30:42Z`, after canary
deletion and idempotency migration.

### Profiles and ownership

- One player profile, one display-name claim, and one ownership profile exist.
- Profile UID, claim, normalized-name metadata, and rename timestamps have zero
  mismatches.
- The live consistency repair scanned one profile and one claim and made zero
  repairs.
- Canonical ownership has a valid revision, valid gold, and no unauthorized
  selected/equipped content.
- Canonical gold is 305. Sixteen settled grants total 455 gold. The lower
  wallet value is compatible with server-authorized spending; there is no
  positive unexplained surplus.
- No ownership document contains legacy `awardedRunIds`; there are no repeated,
  malformed, or synthetic legacy reward identifiers to repair.

Adjudication: no F-01 production data repair is warranted. There is no positive
evidence of a public reward-command credit or unauthorized entitlement in the
remaining production data, and speculative wallet mutation would be less safe
than preserving the valid canonical state.

### Boards, tickets, runs, rewards, and projections

- All 31 boards are structurally valid and match their deterministic IDs,
  keys, and UTC windows.
- Three boards are active, three are upcoming, and all six expected
  current/next managed boards exist.
- The 25 run sessions comprise 8 expired, 1 issued, and 16 validated sessions.
  The issued session is still within its valid 24-hour lifetime; no expirable
  session is past expiry.
- Ticket identity, duration, future-time, loadout authorization, and terminal
  evidence checks have zero mismatches.
- Two validated legacy tickets issued between `2026-07-19T11:02:53Z` and
  `11:03:31Z` lack the newly embedded `boardOpensAtMs` and `boardClosesAtMs`
  fields. Both predate the remediation deployment, and both issuance times fall
  inside their matching canonical board records.
- All 16 validated-run documents are accepted and have matching settled reward
  grants. There are no stale settlement-pending grants, quarantined
  settlements, orphan grants, or identity mismatches.
- The one player-best projection, two ghost manifests, and 31 board views all
  reference valid accepted source data.

Adjudication: the two pre-cutover tickets are preserved as accepted legacy
evidence. Backfilling fields into signed/accepted ticket history would rewrite
evidence without improving authority. There are zero impossible window
issuances or unauthorized loadouts to invalidate.

## Authenticated canary results

The complete canary used synthetic UID hash `6cfb71addad9a428`.

Negative boundary checks passed:

- a client-supplied profile authority timestamp was rejected with
  `INVALID_ARGUMENT`;
- a callable UID mismatch was rejected;
- public `awardRunGold` was rejected with `PERMISSION_DENIED`;
- a client-supplied `nowMs` was rejected;
- repeating the same run-create request ID returned the same session.

The valid competitive-field replay completed the full path:

- signed upload scope and approximately 15-minute expiry were valid;
- deterministic validation accepted the replay;
- the reward settled exactly once;
- the leaderboard projected the accepted run;
- an active ghost manifest was published;
- the signed ghost download returned 505 bytes.

The deliberately seed-mismatched replay completed the terminal rejection path:

- validation rejected it with `seed_mismatch`;
- its provisional reward was revoked;
- it did not affect the leaderboard or publish a ghost.

The valid replay's first validator transaction encountered a Firestore update
precondition conflict and returned 500. Cloud Tasks retried after approximately
30 seconds and the flow converged correctly. Structured telemetry records:

- settlement transaction: `settled`;
- duplicate Eventarc/immediate delivery: `already_settled`;
- projection: completed in 526 ms;
- durable finalize-to-settlement-handoff: 31,088 ms.

This is evidence that retry and exactly-once settlement work in production. It
also legitimately exceeded the 15-second payout-latency warning threshold, so
the retry conflict remains an observation item rather than being hidden as a
successful low-latency canary.

Follow-up remediation classified the actual structured
`FAILED_PRECONDITION` response, added production-shaped lease and atomic
handoff fixtures, and made stale handoffs emit `lease_conflict` retry telemetry.
Validator analysis and all 73 tests passed. Image digest
`sha256:b75a241d53eb8ff5936c815867f3497e539f6d9a178c63c293d10a130e48c70c`
was deployed as `replay-validator-00022-sb6` with 100% traffic. Authenticated
`/ready` and `/live` both returned 200; the retired reserved-suffix routes
returned 404. No error entry was observed on the new revision. A deliberately
raced production handoff was not manufactured, so the successor audit's
contention-drill gate remains open.

## Controlled account-deletion results

Two synthetic deletion workflows completed. The first, hash
`0011f144ad2bebf3`, came from an early canary harness failure before gameplay
mutation; the second was the complete canary above.

- Both reached `complete`, stage `delete_auth`, pass 3, with `finalPass: true`.
- Completion times were 18.1 to 18.9 minutes, including the designed 15-minute
  reconciliation quiet period.
- Neither workflow became retryable or retained expired/missing-expiry
  completion evidence.
- Firebase Auth lookup returned zero synthetic users.
- Exact checks confirmed both pending replay objects and the published canary
  ghost object were deleted.
- Profile, ownership, run, reward, validated-run, player-best, ghost-manifest,
  and view counts returned to their pre-canary values.

The retained completion tombstones have the configured expiry. Privacy/legal
approval of that retention policy remains an owner task; this verification
does not substitute for that review.

## Scheduled maintenance and index correction

Routine production maintenance was exercised and inspected:

- `runSubmissionCleanup` returned 200, scanned 19 candidate sessions, expired
  none, found no retention-eligible Firestore records, scanned 10 pending
  replay objects, and deleted none.
- `playerProfileConsistencyRepair` returned 200, scanned one profile and one
  index claim, and found no repair or conflict.
- account-deletion repair converged both synthetic accounts without a retryable
  state.
- all enabled scheduler jobs report successful latest attempts; the completed
  legacy reward migration remains intentionally paused.

The first manual `ownershipIdempotencyRetentionCleanup` invocation exposed a
missing Firestore collection-group index for `idempotency.expiresAtMs`. The
source-controlled correction was added to `firestore.indexes.json` and deployed
to production. After the index reached `READY`, the job returned 200 and:

- scanned six legacy idempotency records;
- compacted all six to bounded outcomes;
- assigned all six retention expiries;
- marked the one-pass migration complete.

The final inventory reports six compact outcomes, zero full-result snapshots,
zero missing expiries, and zero already-expired records. All eight composite
indexes and the new field override report `READY`.

## Monitoring evidence

Production now has three reward-settlement logs-based metrics and four enabled
alert policies:

- settlement invariant violation;
- reward pending over 15 minutes;
- immediate settlement fallback above 5%;
- payout latency p99 above 15 seconds.

All four policies target one enabled email notification channel. The Monitoring
API does not report its verification status, so the recipient must confirm the
Google verification email before alert delivery can be relied upon.

During the verification window:

- 43 App Check decisions were logged in `monitor` mode;
- all 43 had missing/invalid tokens, as expected for the direct canary;
- zero legitimate platform attestations were observed;
- 11 quota decisions were logged in `monitor` mode and accepted;
- zero would have been rejected because production quota limits remain unset;
- no `ERROR` log entries were observed after the retention index became ready.

This proves fail-open monitoring is active, not that enforcement is ready.

## Findings supported by this evidence

- F-01: production rejection, settlement, ownership inventory, and no-repair
  adjudication verified.
- F-02: client-time rejection and historical ticket/window adjudication
  verified.
- F-03: deployed runtime, signed URLs, task retry, trigger, and schedules
  verified.
- F-05: one complete controlled canary plus one interrupted-canary cleanup
  verified.
- F-07/F-08: terminal invalid replay, reward revocation, exactly-once
  settlement, and projection suppression verified.
- F-10: live profile/index inventory and repair job verified.
- F-11/F-12: Node 24 deployment, rules, auth-first failures, and lazy dependency
  behavior verified.
- F-06 remains in progress: monitoring and bounded retention are live, but
  legitimate App Check evidence, measured quotas, and enforcement are not.

## Remaining work that was intentionally not forced in production

- ship an App Check-capable Flutter release and measure legitimate attestation
  success by platform;
- collect normal-client quota distributions, choose reviewed burst/sustained
  limits, and test enforcement rollback;
- confirm the alert channel verification email;
- complete privacy/legal review of deletion completion evidence and retention;
- observe settlement latency and verify the corrected precondition-conflict
  classification under natural contention or a future isolated drill;
- exercise deliberately injected quarantine, dispatch outage, upload expiry,
  and every deletion-stage failure in an emulator or future isolated test
  project, rather than manufacturing destructive production incidents;
- complete release provenance and final finding-by-finding closure review
  before archiving the remediation plan.
