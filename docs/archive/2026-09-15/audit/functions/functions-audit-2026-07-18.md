# Firebase Functions Audit — 2026-07-18

## Executive decision

**Release recommendation: BLOCK**

The audited Functions tree has strong authentication, transaction, replay-upload,
and settlement foundations, and all 110 discovered emulator tests pass. It is
not release-ready because two client trust-boundary defects allow authenticated
clients to change server-authoritative economy/loadout state and to choose the
backend clock used for run tickets and managed boards. The production dependency
tree also reports 31 known advisories, including two critical advisories.

| Severity | Count | Release effect |
| --- | ---: | --- |
| Critical | 2 | Must be fixed before deployment |
| High | 4 | Must be fixed or explicitly risk-accepted before deployment |
| Medium | 4 | Schedule immediately after the release blockers |
| Low | 2 | Correct as part of backend hardening |

## Audit target and scope

This audit covers the current working tree on branch `master`, based on commit
`d924895`. The working tree already contained uncommitted Functions settlement
changes when the audit began; those changes are included in the findings. No
application or backend source files were changed by this audit.

The reviewed surface includes:

- all 39 TypeScript files under `functions/src/`;
- all 11 TypeScript test files under `functions/test/`;
- Functions build, test, package, and TypeScript configuration;
- `functions/src/index.ts` deployment exports;
- `firebase.json`, `firestore.rules`, and the resolved production dependency
  graph in `pnpm-lock.yaml`;
- relevant Flutter, replay-validator, and design-document references where they
  define or consume a Functions contract.

The audit considered authentication and authorization, client trust boundaries,
Firestore consistency, idempotency, replay and reward lifecycle correctness,
account erasure, resource abuse, error behavior, observability, dependency
security, tests, and documentation alignment.

The following require a separate live-project audit and were not verified:

- deployed IAM bindings and invoker policies;
- App Check enforcement configured outside source;
- Cloud Tasks queue retry/rate settings and Cloud Scheduler state;
- Firestore indexes, TTL policies, quotas, and production data shape;
- Storage bucket IAM, lifecycle rules, CORS, and signed-URL behavior;
- deployed environment variables, secrets, alert policies, and dashboards;
- production load, latency, cost, and failure-recovery behavior.

## Deployment surface inventory

All 21 exports in `functions/src/index.ts` were included.

| Surface | Exports | Count |
| --- | --- | ---: |
| Ownership | `loadoutOwnershipLoadCanonicalState`, `loadoutOwnershipExecuteCommand` | 2 |
| Player profile | `playerProfileLoad`, `playerProfileUpdate` | 2 |
| Account | `accountDelete` | 1 |
| Boards and run submission | `runBoardsLoadActive`, `runSessionCreate`, `runSessionCreateUploadGrant`, `runSessionFinalizeUpload`, `runSessionLoadStatus` | 5 |
| Leaderboards | `leaderboardLoadBoard`, `leaderboardLoadMyRank`, `leaderboardLoadActiveBoardData` | 3 |
| Ghosts | `ghostLoadManifest` | 1 |
| Firestore triggers | `runSettlementOnHandoff`, `runProjectionOnAccepted` | 2 |
| IAM-protected HTTP | `runSettlementImmediate` | 1 |
| Scheduled jobs | `runSubmissionCleanup`, `runSettlementRepair`, `runLegacyRewardGrantMigration`, `leaderboardBoardMaintenance` | 4 |

## Findings

| ID | Severity | Finding |
| --- | --- | --- |
| F-01 | Critical | Authenticated clients can grant currency and entitlements and equip unowned content |
| F-02 | Critical | Public requests control the authoritative run and board clock |
| F-03 | High | Production dependencies contain 31 known advisories |
| F-04 | High | Non-retryable settlement records can starve the repair queue |
| F-05 | High | Account deletion can leave or recreate user data during execution |
| F-06 | High | High-value callables lack application-level abuse controls and amplify idempotency storage |
| F-07 | Medium | Expiry state written inside a failing transaction is rolled back |
| F-08 | Medium | Failed validation dispatch can leave an indefinitely provisional reward grant |
| F-09 | Medium | Display-name cooldown time is client-authoritative |
| F-10 | Medium | Concurrent first profile load and update can orphan a name reservation |
| F-11 | Low | The test and runtime harness has drifted from the deployed surface |
| F-12 | Low | Some default dependencies are constructed before authentication |

### F-01 — Authenticated clients can grant currency and entitlements and equip unowned content

**Severity: Critical**

#### Evidence

- The public `loadoutOwnershipExecuteCommand` callable authenticates the user
  and checks that the command UID matches, but then accepts every command type
  recognized by the parser (`functions/src/index.ts:113-127`).
- The public command contract contains `learnProjectileSpell`,
  `learnSpellAbility`, `unlockGear`, and `awardRunGold`
  (`functions/src/ownership/contracts.ts:1-16`).
- Command-specific validation exists only for `purchaseStoreOffer` and
  `refreshStore`; the grant and unlock commands have no server-origin check
  (`functions/src/ownership/validators.ts:32-81`).
- `awardRunGold` accepts a caller-selected non-negative run ID and up to 10,000
  gold per command, then writes that value into canonical spendable gold. The
  replay guard remembers only the latest 512 IDs
  (`functions/src/ownership/apply_command.ts:291-330`).
- Learn and unlock handlers directly add the supplied IDs to canonical
  entitlement and inventory lists
  (`functions/src/ownership/apply_command.ts:206-288`).
- `setSelection` accepts an arbitrary object. `setLoadout`, `equipGear`,
  `setAbilitySlot`, and `setProjectileSpell` do not prove that the supplied
  content is owned or learned
  (`functions/src/ownership/apply_command.ts:76-203`).
- Run-session creation treats that selection as authoritative and copies its
  selected character and loadout directly into the signed run ticket
  (`functions/src/runs/store.ts:52-79`, `functions/src/runs/store.ts:260-285`).
- Passing tests currently codify both currency granting and equipping
  `bastionCodex` without an inventory-ownership assertion
  (`functions/test/ownership/ownership_callable.test.ts:181-209`,
  `functions/test/ownership/ownership_callable.test.ts:584-613`).

#### Impact

Any authenticated client, including a modified game client, can repeatedly use
unique run IDs to mint gold, learn abilities, unlock equipment, or inject
unowned content into the canonical loadout. This bypasses progression and store
rules. Because run tickets consume the canonical selection, it can also alter
ranked-run inputs while still producing a replay that correctly matches its
ticket.

Authentication is functioning here; the defect is authorization. A user is
authorized to mutate their document but is incorrectly authorized to choose
server-owned rewards and entitlements.

#### Required remediation

1. Define an explicit public command allowlist and remove reward, learn, and
   unlock operations from the client-callable contract.
2. Issue rewards only from the validated settlement transaction, and issue
   entitlements only from server-verified purchase/progression flows.
3. Validate every equipped character, item, spell, and ability against the
   server catalog and the user's canonical ownership before accepting selection
   or loadout changes.
4. Reject arbitrary whole-selection replacement unless every field is
   normalized and authorized server-side.
5. Add negative emulator tests proving that an authenticated caller cannot mint
   gold, grant content, or equip unowned content.
6. Review existing production canonical documents for impossible grant IDs,
   ownership, balances, and loadouts before accepting ranked results.

### F-02 — Public requests control the authoritative run and board clock

**Severity: Critical**

#### Evidence

- Run-session, upload-grant, and finalize validators accept an optional
  client-supplied `nowMs` and validate only that it is an integer
  (`functions/src/runs/validators.ts:13-32`,
  `functions/src/runs/validators.ts:46-130`).
- Active-board and leaderboard validators also accept client `nowMs`
  (`functions/src/boards/validators.ts:13-61`,
  `functions/src/leaderboards/validators.ts:24-82`).
- Run creation uses that value for ticket issuance and expiry and for ranked
  board resolution/provisioning (`functions/src/runs/store.ts:42-76`,
  `functions/src/runs/store.ts:102-188`).
- Managed-board provisioning resolves current and future windows relative to
  the supplied value (`functions/src/boards/provisioning.ts:107-181`,
  `functions/src/boards/provisioning.ts:189-202`).
- Upload leases and finalize expiry decisions use the supplied value
  (`functions/src/runs/submission_store.ts:157-216`,
  `functions/src/runs/submission_store.ts:267-331`).
- Replay validation compares replay/ticket/board bindings but does not
  independently enforce the ticket's wall-clock issuance or expiry in
  `services/replay_validator/lib/src/validator_worker.dart`.
- Tests successfully create boards and tickets at caller-selected March 2026
  timestamps (`functions/test/runs/run_session_callable.test.ts:78-99`,
  `functions/test/runs/run_session_callable.test.ts:451-556`).

#### Impact

A modified authenticated client can mint a ticket in a historical or future
competitive window, create managed board documents for caller-selected periods,
and choose a ticket expiry window unrelated to server time. It can also submit a
past value to pass the pre-finalize expiry check until scheduled cleanup changes
the state. The documented 24-hour ticket authority and board-window fairness
therefore do not hold at the security boundary.

#### Required remediation

1. Remove `nowMs` from all public wire contracts.
2. Inject a clock only into internal domain helpers and tests; public handlers
   must use server time.
3. In replay validation, independently reject tickets that are expired, issued
   implausibly in the future, or outside the bound board window.
4. Apply an explicit maximum clock-skew policy where external timestamps must be
   compared.
5. Add boundary tests that invoke the public handlers with forged timestamps and
   prove those values cannot influence persisted state.
6. Audit existing boards and accepted runs for issuance times outside the
   expected board window.

### F-03 — Production dependencies contain 31 known advisories

**Severity: High**

`corepack pnpm --dir functions audit --prod` failed with:

- 2 critical advisories;
- 15 high advisories;
- 13 moderate advisories;
- 1 low advisory.

Representative critical paths reported by the package manager include:

- `@google-cloud/tasks` → `google-gax` → `protobufjs`, including
  `GHSA-xq3m-2v4x-88gg`;
- `firebase-admin` → Firebase Realtime Database compatibility packages →
  `faye-websocket`/`websocket-driver`, including `GHSA-xv26-6w52-cph6`.

Representative high paths include vulnerable `fast-xml-parser`,
`path-to-regexp`, `node-forge`, and `protobufjs` versions. The direct dependency
ranges in `functions/package.json` start at `@google-cloud/tasks` 5.5.0,
`firebase-admin` 12.7.0, and `firebase-functions` 6.0.1.

The scanner's severity does not by itself prove that every vulnerable path is
reachable from this application. It does establish that the deployed production
artifact contains known vulnerable versions and requires triage before release.

#### Required remediation

1. Upgrade the three direct Google/Firebase dependencies to currently supported
   compatible releases and regenerate the lockfile.
2. Rerun the production audit and record any unavoidable advisory with a
   reachability analysis, compensating controls, owner, and expiry date.
3. Rerun the Node 20 build, all emulator tests, signed-URL smoke tests, Cloud
   Tasks dispatch tests, and a canary deployment after the upgrade.
4. Add a production dependency audit gate to CI.

### F-04 — Non-retryable settlement records can starve the repair queue

**Severity: High**

#### Evidence

- `runSettlementRepair` queries `settlement_pending` sessions with only a
  bounded `limit`; it has no ordering, cursor, retryability field, or quarantine
  filter (`functions/src/index.ts:359-369`).
- The settlement helper converts persisted-data contradictions into the
  non-throwing `invariant_violation` outcome
  (`functions/src/runs/reward_settlement.ts:191-206`).
- The repair job counts that result but leaves the session in
  `settlement_pending` (`functions/src/index.ts:373-417`).
- The Firestore trigger similarly completes successfully after a returned
  invariant result, acknowledging that event.
- Current operational documentation correctly says invariant violations are
  operator incidents rather than retryable payouts
  (`docs/tdd/reward_settlement_operations.md:23-24`), but the query does not
  separate them from retryable work.

#### Impact

An invariant-violating record can be selected on every five-minute scan. A
batch-sized group of such records can prevent the query from reaching later
valid sessions, leaving legitimate gold settlement pending indefinitely. The
query has no progress guarantee even below that threshold.

#### Required remediation

1. Atomically move contradictions to a quarantined/terminal incident state or
   mark them non-retryable without changing gold.
2. Query only retryable records and page with an explicit stable order and
   cursor.
3. Monitor pending count, oldest retryable age, quarantine count, and page
   progress.
4. Add a test with more than one repair page, including poisoned records before
   valid records, and prove all valid records settle.

### F-05 — Account deletion can leave or recreate user data during execution

**Severity: High**

#### Evidence

- The callable performs a long synchronous sequence across profile, ownership,
  runs, validated runs, rewards, ghosts, leaderboards, cached views, and Storage
  (`functions/src/account/delete.ts:115-210`).
- Firebase Auth is deleted only after all data and artifact steps complete
  (`functions/src/account/delete.ts:211-222`).
- No deletion tombstone is checked by the other callables.
- Profile and ownership loading can lazily create documents while the account
  remains authenticated.
- Board-wide work uses `listDocuments` and repeated serial recursive deletions,
  increasing the execution window (`functions/src/account/delete.ts:311-472`).

#### Impact

Another active client request can recreate or write data after a collection has
already been swept but before Auth deletion. The account-delete call can then
report success while orphaned data remains. A timeout or downstream permission
failure can leave partially erased data while the account is still usable. The
implementation is idempotent in several individual steps, but it does not
provide a concurrency-safe erasure state machine.

#### Required remediation

1. Create a server-owned deletion tombstone/state before erasure begins and make
   every user callable reject writes and lazy creation for that UID.
2. Revoke or disable the account early, accounting for already-issued token
   lifetime.
3. Dispatch an idempotent background erasure workflow with bounded pagination,
   retries, and a completion record rather than doing all work in one callable.
4. Repeat collection queries until empty and perform a final reconciliation
   sweep before marking deletion complete.
5. Add concurrent-write, timeout-resume, large-account, and repeated-delete
   tests.

### F-06 — High-value callables lack application-level abuse controls and amplify idempotency storage

**Severity: High**

#### Evidence

- No source handler enables App Check enforcement or consumes App Check tokens.
- No per-UID rate, storage, command, ticket, or upload quota is implemented in
  the audited Functions paths.
- Every unique ownership command, including rejected commands, creates an
  idempotency document (`functions/src/ownership/command_executor.ts:42-129`).
- Each idempotency document stores the full `OwnershipCommandResult`, including
  the full canonical state, rather than a compact outcome
  (`functions/src/ownership/canonical_store.ts:109-117`).
- No TTL or scheduled cleanup exists for ownership idempotency documents.
- Run-session creation has no client request ID and no application-level cap on
  the number of session/upload records an authenticated UID can create.

#### Impact

An authenticated or automated client can cause sustained Firestore, Functions,
Storage, signed-URL, and Cloud Tasks cost. The ownership ledger magnifies that
cost by duplicating an increasingly large canonical payload for every unique
command. App Check is not a rate limiter, but its absence also removes one
useful barrier against non-app clients.

#### Required remediation

1. Enforce App Check on callable endpoints where client support is available,
   while retaining UID authorization.
2. Add atomic per-UID quotas/rate controls for commands, active run sessions,
   upload grants, finalized bytes, and expensive read paths.
3. Make run-session creation idempotent with a bounded client request ID.
4. Store compact idempotency results and configure an explicit retention/TTL
   policy that preserves the required retry window.
5. Bound command IDs and nested JSON payload size/depth before Firestore work.
6. Add cost and rejection metrics with operational alerts.

### F-07 — Expiry state written inside a failing transaction is rolled back

**Severity: Medium**

`throwIfExpiredBeforeFinalize` writes `state: "expired"` with `tx.set` and then
throws `HttpsError` from the Firestore transaction callback
(`functions/src/runs/submission_store.ts:563-588`). A thrown transaction callback
does not commit its writes. Both upload-grant and finalize paths call this helper
inside their transactions (`functions/src/runs/submission_store.ts:157-170`,
`functions/src/runs/submission_store.ts:267-278`).

The caller receives an expired error, but the stored session remains in its old
state until another process changes it. Repeated requests therefore observe and
repeat an inconsistent transition.

Return an expiry sentinel from a successful transaction and throw to the client
after the commit, or perform the terminal transition in a separate successful
transaction. Add tests that assert the persisted state, timestamp, and message,
not only the returned error.

### F-08 — Failed validation dispatch can leave an indefinitely provisional reward grant

**Severity: Medium**

Finalize creates a `provisional_created` reward grant in the same transaction
that moves the session to `uploaded`
(`functions/src/runs/submission_store.ts:304-334`). Cloud Tasks enqueue happens
after that commit. If enqueue fails, the callable throws while the session and
grant remain persisted (`functions/src/runs/submission_store.ts:349-356`).

Scheduled cleanup can later expire the uploaded session, but reward-grant cleanup
deletes only `validated_settled` and `revoked_final` grants
(`functions/src/runs/cleanup.ts:517-519`). Submission projection continues to
treat `provisional_created` as provisional
(`functions/src/runs/submission_store.ts:487-500`).

This can leave a permanent provisional grant and present provisional rewards for
a terminally expired submission. On terminal rejection/expiry, atomically
revoke/finalize the related provisional grant; suppress provisional projection
when the session lifecycle is incompatible; and add orphan-grant cleanup after a
documented grace period. Cover enqueue failure followed by cleanup in an
end-to-end emulator test.

### F-09 — Display-name cooldown time is client-authoritative

**Severity: Medium**

The shipped profile UI defines a 24-hour rename cooldown
(`lib/ui/pages/profile/profile_page.dart:34-58`). The backend accepts
`displayNameLastChangedAtMs` from the caller, verifies only that it is a
non-negative integer, and persists that exact value
(`functions/src/profile/validators.ts:48-83`,
`functions/src/profile/store.ts:54-110`).

A modified client can submit zero or an old timestamp and rename repeatedly, or
submit a future timestamp and lock the normal client. Enforce the cooldown
against the existing profile inside the same transaction that reserves the
name, set the change timestamp from server time, and return the server value.
Add tests for initial naming, early rename rejection, exact-boundary acceptance,
and concurrent rename attempts.

### F-10 — Concurrent first profile load and update can orphan a name reservation

**Severity: Medium**

`loadOrCreatePlayerProfile` performs a non-transactional read followed by an
unconditional full `set` when the document appears absent
(`functions/src/profile/store.ts:37-51`). Profile update uses a transaction to
claim the unique-name index and write the profile
(`functions/src/profile/store.ts:65-134`).

If first load reads “absent,” a concurrent update can then create the named
profile and index, after which the first load overwrites the profile with empty
defaults. The display-name index remains claimed while the profile no longer
contains the name.

Use atomic document creation and reload on `already-exists`, or perform
load/create in a transaction. Add a concurrency test that interleaves first load
and first update and asserts profile/index agreement.

### F-11 — The test and runtime harness has drifted from the deployed surface

**Severity: Low**

- `functions/package.json` explicitly enumerates 10 test files even though 11
  exist. `functions/test/runs/reward_grant_backfill.test.ts` is omitted.
- That omitted test says the backfill is retired and is intentionally empty,
  while `runLegacyRewardGrantMigration` is still an exported scheduled function
  (`functions/test/runs/reward_grant_backfill.test.ts:3-4`,
  `functions/src/index.ts:424-447`).
- The package targets Node 20, but this audit's build and emulator runs executed
  under Node 24.16.0.
- Firebase CLI emitted an unknown-property warning for the `flutter` key in
  `firebase.json` and project-ID warnings because tests use multiple suffixed
  project IDs under emulator `singleProjectMode`.

Use dynamic test discovery so new test files cannot be skipped, replace the
stale test with real migration inventory/apply/off coverage or remove the
deployed migration, run backend CI on Node 20, and clean or explicitly configure
the emulator warnings.

### F-12 — Some default dependencies are constructed before authentication

**Severity: Low**

The upload-grant, finalize, and ghost handlers create default Storage/Cloud Tasks
dependencies in default parameter expressions
(`functions/src/runs/callable_handlers.ts:84-113`,
`functions/src/ghosts/callable_handlers.ts:45-66`). JavaScript evaluates default
arguments before entering the function body, so environment checks and client
construction occur before the handler's authentication check. Missing
configuration can therefore return `failed-precondition` to an unauthenticated
request instead of `unauthenticated`, and unnecessary client construction is
performed for rejected calls.

Accept an optional dependency, authenticate and authorize first, and lazily
construct the production dependency afterward. Add an unauthenticated test that
does not inject test dependencies.

## Controls that are working well

- Callable handlers consistently require Firebase Auth and compare requested
  user IDs with the authenticated UID.
- Firestore rules are fail-closed: the explicitly named ownership/profile paths
  deny direct client access, and unmatched paths receive Firestore's default
  deny.
- Ownership command execution uses Firestore transactions, revision checks,
  stable payload hashing, and idempotency-key mismatch detection.
- Run upload paths are canonicalized and bound to UID/session; finalize verifies
  object existence, size, content type, generation, and caller metadata.
- Cloud Tasks use deterministic task IDs so duplicate enqueue attempts are
  treated idempotently.
- Board IDs and UTC month/ISO-week window contracts are validated.
- Reward settlement updates canonical gold, reward-grant lifecycle, and run
  state atomically and contains explicit overflow and invariant checks.
- Settlement, projection, and payout paths are separated, limiting projection
  failure from blocking wallet correctness.
- Leaderboard and ghost read handlers validate identity and board/entry inputs;
  ghost Storage paths are restricted to the `ghosts/` prefix.
- Account deletion enumerates a broad set of primary, projection, and artifact
  locations even though its orchestration needs concurrency hardening.
- TypeScript strict compilation succeeds, and the emulator suite contains
  meaningful transaction, duplicate-delivery, auth, replay, leaderboard, ghost,
  cleanup, and account-deletion coverage.

## Validation results

| Check | Result | Notes |
| --- | --- | --- |
| `corepack pnpm --dir functions build` | Pass | TypeScript production build succeeded; engine warning because local Node was 24.16.0 and package target is 20 |
| `corepack pnpm --dir functions test` | Pass | Configured Firestore emulator suite passed |
| All 11 compiled test files under the Firestore emulator | Pass | 110 passed, 0 failed |
| `git diff --check` for Functions/config scope | Pass | No whitespace errors; Git reported line-ending conversion warnings |
| `corepack pnpm --dir functions audit --prod` | Fail | 31 advisories: 2 critical, 15 high, 13 moderate, 1 low |

Emulator success does not validate production IAM, Eventarc delivery, Cloud
Scheduler, Cloud Tasks queue behavior, live Storage signing, or Node 20 runtime
compatibility.

## Important missing tests

The highest-value additions are:

1. authenticated callers cannot invoke server-only grant/unlock/learn commands;
2. arbitrary or unowned loadout content cannot enter a run ticket;
3. public timestamps cannot influence run, board, lease, or finalize time;
4. replay validation rejects expired and implausibly issued tickets;
5. repair progresses past more than one page of invariant-violating sessions;
6. account deletion rejects concurrent writes and resumes after partial failure;
7. expiry errors commit the terminal session state;
8. enqueue failure followed by cleanup revokes provisional rewards;
9. first profile load/update and concurrent rename races preserve index
   consistency;
10. callables authenticate before production dependencies are initialized;
11. quota, payload-bound, and App Check rejection paths;
12. Node 20 integration tests for Storage signing, task dispatch, HTTP IAM, and
    scheduled/event-driven handlers.

## Prioritized remediation plan

### P0 — Before any release

1. Close the ownership/economy command authorization gap in F-01 and inspect
   existing data for abuse.
2. Remove client-controlled time and add validator expiry enforcement from F-02;
   inspect existing boards and runs for impossible timestamps.
3. Upgrade and triage production dependencies from F-03.

### P1 — Before broad production traffic

1. Quarantine non-retryable settlement incidents and make repair pagination
   progress-safe.
2. Convert account deletion to a tombstoned, idempotent background state
   machine.
3. Add App Check plus application-level quotas, compact idempotency storage, and
   retention controls.

### P2 — Reliability hardening

1. Commit expiry transitions before returning errors.
2. Revoke and clean orphan provisional grants.
3. Make rename time server-authoritative and fix first-profile creation races.
4. Align test discovery, migration tests, emulator configuration, and the Node
   runtime.
5. Construct external dependencies only after authentication.

## Release closure criteria

The backend should not be approved for release until:

- both Critical findings have regression tests and are closed;
- dependency audit results contain no unreviewed critical/high production
  advisory;
- repair proves forward progress with poisoned and multi-page queues;
- account deletion prevents concurrent recreation and has resumable completion;
- rate/retention limits exist for ownership commands and run submissions;
- the full suite passes on Node 20;
- Storage, Cloud Tasks, IAM-protected HTTP, Eventarc, and scheduled jobs receive
  staging integration tests;
- production IAM, queue, bucket, TTL/index, environment, monitoring, and alert
  configuration receive a separate deployment audit.
