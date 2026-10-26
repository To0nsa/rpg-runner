# Android beta execution evidence

Status: in progress, October 26, 2026. No new environment deployed yet.
The active checklist is [android_beta_release.md](../building/android_beta_release.md).

## Initial state

Source inspected: `f0aa66d8`, repository root `C:\dev\rpg_runner`.
Initial edits: the untracked release plan and its two documentation-index links.
No staged edits or unrelated source modifications.

Read-only live CLI checks used the existing authenticated operator credential
cache (outside Git). `gcloud auth list`, project list, billing account list and
the existing project's billing association succeeded. The open **Firebase
Payment** account is the existing project's billing account. Other projects and
the closed billing account are outside this workstream.

`gcloud run services list`, `tasks queues list`, `scheduler jobs list` and
`firestore databases list` against `rpg-runner-d7add` / `europe-west1` show:

- worker ready revision `replay-validator-00058-94k`;
- issuer ready revision `runsessioncreate-00071-wx8`;
- validation/projection queues both RUNNING, each capped at five concurrent
  dispatches and five dispatches/second;
- nine enabled scheduled maintenance jobs;
- default native Firestore database in `eur3`, pessimistic concurrency, PITR
  disabled and one-hour version retention. This is inventory, not recovery proof.

`gh auth status` verifies repository access. Browser inventory via the Chrome
control integration returned no connected browsers; setup instructions supplied
to the owner. No Play account/listing/signing facts are verified yet.

## Authorization and waiver

The October 26 execution request authorizes all necessary plan-scoped projects,
billing linkage, IAM, secrets, signing, CI, deployment, maintenance and beta
publication. It excludes general public distribution and unrelated deletion.
Only the owner's existing development game data may be discarded if necessary.

Traversal/navigation/content-quality failures are non-blocking for this initial
release, with exact failure evidence required. No tests have yet failed in this
execution; no waiver has been consumed. Replay integrity/determinism, missing
assets, authentication, isolation, builds and deployments remain blocking.

## Environment-routing milestone

Implemented registry and explicit mutation selection, Firebase aliases and
separate configs, environment resource validation, project-specific configuration
requirement, project-derived Functions runtime/private-invoker identities, and
dev-only Hosting. Staging/prod IDs remain proposed until actual creation succeeds.
Release input hashing includes Android and environment definitions. Git file
enumeration disables pathname quoting so accented asset paths remain usable.

Validation from the repository root on the uncommitted milestone:

- `corepack pnpm --dir functions build` and `build:test`: pass.
- `node --test functions/lib_test/test/deployment_identity.test.js`: 5 pass.
- `corepack pnpm --dir functions test`: 257 pass, zero failures/skips. The first
  sandboxed invocation could not read Firebase CLI configuration; the rerun with
  existing credential/emulator-cache access passed. Transient log:
  `.tmp/beta-checks/functions-tests.log` (credential diagnostics redacted).
- `test_release_environments.ps1`: 29 checks pass on PowerShell 5.1 and 7.
- `test_release.ps1`: 32 checks pass on PowerShell 5.1 and 7.
- `test_release_cache.ps1`: 48 mocked checks pass on PowerShell 5.1 and 7.
- `test_release_integration.ps1 -TestEnvironment <dev|staging|prod>`: all six
  runs pass on PowerShell 5.1 and 7 (87 dev checks and 82 each staging/prod).
  Logs: `.tmp/beta-checks/integration-<powershell|pwsh>-<environment>.log`.
  These exercise actual entry-point sequencing against mocked commands,
  including project selection and no staging/prod Hosting publication.
- `node tools/agents/check.mjs` and `git diff --check`: pass.

Live `release.ps1 -Action Inspect -Environment dev -CacheDirectory
.tmp/beta-inventory-cache` succeeded. Inventory observed at
`2026-10-26T20:36:13.893Z`, stored under
`.tmp/releases/rpg-runner-d7add/eec4b43c0a3591ee0c55667da341cc4b3d895e7f981345b37070b3f5ae9af35c/`.
It reports one player, 469 accepted runs, 469 settled grants, no pending or
quarantined settlement. Historical findings include 18 grants without sessions
and one ghost with invalid source lineage; no reset/repair was performed.

The main Windows checkout's CRLF bytes differ from the earlier LF release
baseline, so its default Plan rejected simulation input hashes. Git comparison
against `a4f99b89` shows no new simulation implementation/content changes, only
instruction files in that input area. This inspection uses an isolated scratch
cache; the actual release must use the canonical LF frozen checkout and verified
baseline. No gameplay-version bump or weakening of the simulation fence was made
to hide line-ending differences.

## Remaining acceptance

Environment creation, Android identities, signing, freeze/build/deployment hashes,
real Play auth/attestation, device acceptance, recovery rehearsal, capacity and
store review/publication are pending. Do not infer completion from authorization.
