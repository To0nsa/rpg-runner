# Account Deletion Workflow

## Status

Implemented and deployed on July 19, 2026. Two synthetic workflows completed
the final reconciliation and Auth-deletion path; the controlled evidence is in
the
[Functions production verification record](../building/functions-audit-remediation/production-verification-2026-07-19.md).
Privacy/legal confirmation of the 30-day completion-record retention remains
pending.

## Purpose

Account deletion is a tombstone-first, asynchronous erasure workflow. The
authenticated callable accepts the request and returns after establishing
durable ownership of the deletion; the player does not remain signed in while
Firestore and Storage cleanup continues.

The implementation lives in:

- `functions/src/account/delete.ts`
- `functions/src/account/deletion_guard.ts`
- `functions/src/index.ts`
- `lib/ui/state/profile/account_deletion_api.dart`
- `lib/ui/state/profile/firebase_account_deletion_api.dart`

## State and checkpoint contract

`account_deletion_requests/{uid}` is both the write barrier and the durable
workflow checkpoint. Its states are:

- `requested`: tombstone committed and no worker page has started.
- `in_progress`: a worker owns or most recently completed a page.
- `retryable`: the last page failed; the stage and counters remain resumable.
- `complete`: the final zero-change reconciliation passed and Firebase Auth was
  deleted.

The record stores the current stage, pass number, final-pass flag, per-pass
deletion count, nested-board cursor, bounded lease token/expiry, attempt count,
last error class/message, aggregate deletion counters, and completion expiry.
The UID is the request ID, so repeated calls converge on one workflow.

Workers acquire a five-minute transactional lease. A crash after deleting data
but before checkpointing is safe: the same bounded page is retried and missing
documents/objects are accepted.

## Authority and concurrency boundary

The callable transaction creates the tombstone before attempting any Auth or
data operation. Once the document exists:

- every user-facing profile, ownership, board, run, leaderboard, and ghost
  callable rejects the UID;
- profile and ownership lazy creation reads the tombstone inside the same
  transaction that would create data;
- ownership command, run-session creation, upload-grant, finalize, and
  post-enqueue run-session transactions read the same tombstone before writing;
- Firestore rules deny direct client access to the tombstone and all
  authoritative user collections.

Firebase Auth is disabled and refresh tokens are revoked in the first worker
stage. Already-issued ID tokens remain possible until expiry, which is why the
Firestore tombstone remains the immediate server-side barrier.

## Bounded erasure inventory

The worker processes at most one bounded page per invocation across this
explicit inventory:

- `player_profiles`
- `display_name_index`
- `ownership_profiles`
- `ownership_profiles/*/idempotency`
- `abuse_quota`
- `run_sessions`
- `validated_runs`
- `reward_grants`
- `ghost_runs`
- `leaderboard_ghost_runs`
- `weekly_ghost_runs`
- `leaderboard_boards/*/ghost_manifests`
- `leaderboard_boards/*/player_bests`
- affected `leaderboard_boards/*/views/top10`
- `replay-submissions/pending/{uid}/**`
- `replay-submissions/validated/{runSessionId}.bin.gz`
- referenced `ghosts/**` artifacts

New UID-owned schemas, projections, or Storage prefixes must extend this
inventory and its emulator test before shipping.

Top-level UID queries repeat from the beginning until empty; they do not advance
past deleted documents. Nested ownership and board collections use durable
parent cursors and bounded child pages. A later full pass revisits all stages,
so records inserted by previously queued server work are detected.

## Signed-upload and final reconciliation rule

An upload URL issued before deletion can remain valid for 15 minutes. The
worker therefore:

1. runs ordinary erasure passes until a complete pass deletes nothing;
2. waits until the signed-upload lease window from `requestedAtMs` has expired;
3. starts a fresh final pass from the profile stage;
4. repeats that final pass if it deletes anything;
5. deletes Firebase Auth only after a final pass deletes nothing.

This prevents a late upload from appearing after Storage was swept but before
completion.

## Client contract

The callable response status is one of `requested`, `in_progress`,
`retryable`, or `deleted`. All four mean the server owns the deletion request.
Flutter clears local state and signs out for any of them. A retryable backend
page is recovered by the scheduled worker and does not require the deleted
account to remain authenticated.

## Scheduling, retention, and operations

`accountDeletionRepair` runs every minute. Each request records attempts, stage,
last retryable error, age inputs, and aggregate deletion counters for operator
inspection. Missing Auth users and already-missing data/artifacts are normal
idempotent outcomes.

The implemented engineering default retains a minimal completed tombstone for
30 days, after which the scheduled worker removes it. This exceeds token and
signed-URL lifetimes and supports retry/incident diagnosis. The 30-day policy
must be confirmed by the project owner's privacy/legal review before
public launch and audit closure; changing it requires updating this document
and the EU-compliance checklist.

## Validation

Emulator tests cover:

- tombstone-before-disable ordering;
- transaction-protected lazy creation;
- multi-page ownership/idempotency/quota/run/reward/ghost cleanup;
- concurrent worker serialization;
- a deliberately reinserted late record and pending upload;
- retryable Storage failure and resume;
- repeated delete requests;
- already-missing Auth users;
- final Auth deletion only after reconciliation.

Production verification additionally confirmed:

- the one-minute repair scheduler and IAM path;
- three-pass final reconciliation after the 15-minute signed-upload quiet
  period;
- deletion of the synthetic Auth users, Firestore documents, pending replay
  objects, and ghost artifact;
- restoration of gameplay/projection counts to the pre-canary baseline;
- completion in 18.1 to 18.9 minutes with no retryable terminal state.
