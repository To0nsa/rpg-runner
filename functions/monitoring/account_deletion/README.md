# Account-deletion production monitoring

This bundle owns the production alerts for the resumable account-deletion
workflow:

- any stage transition to `retryable`;
- incomplete work at least twelve hours old;
- saturation of the bounded expired-completion cleanup page;
- unexpected errors from the scheduled repair service.

Repair runs once per minute, selecting at most ten accounts and processing up to
32 checkpointed stage steps per account in round-robin order. The invocation
has a shared 40-second elapsed-time budget and stops each account on retryable
failure, lease contention, a no-progress step or the signed-upload quiet wait.
An individual RPC can finish after the soft time budget; a step is never
interrupted between its effects and durable checkpoint.

Twelve hours is an operator safety budget, not a completion SLA. Attempts count
successful steps as well as failures and no longer trigger the age policy. Its
legacy display name remains stable so applying this bundle updates the existing
policy instead of creating a duplicate. Each heartbeat reports selected-page
oldest age/stage, retryable backlog, attempts, processed requests and
`processedStepCount`. These are bounded-page signals, not collection-wide counts.
Expired completions are selected oldest-first, with ten deletes per invocation
and `expiredCompletionPageSaturated` lookahead. Thirty days is the expiry
deadline; backlog, scheduler jitter, or outages can delay physical removal.
Malformed completion evidence emits an error caught by the runtime-error policy.
Log-match policies do not detect missing heartbeats; operations must separately
check scheduler execution and heartbeat freshness.
The heartbeat contains no account identifier. Retryable-failure logs use a truncated
SHA-256 UID hash for correlation and never emit the raw UID.

For a release adding an index, deploy `firestore:indexes` separately and wait
until every required index is `READY` before deploying the dependent Functions.
Firebase CLI completion does not mean index backfill has finished. A combined
deployment in September produced two repair errors during backfill; repair was
briefly paused, then resumed successfully once the index became ready.

Apply the bundle with the already verified production notification-channel
resource:

```powershell
.\functions\monitoring\account_deletion\apply_alerts.ps1 `
  -ProjectId rpg-runner-d7add `
  -NotificationChannel projects/rpg-runner-d7add/notificationChannels/CHANNEL_ID
```

The command is idempotent by exact policy display name and refuses a disabled
or unverified notification channel. After deployment, test delivery with a
temporary exact-ID synthetic log policy; never create a real deletion request
or corrupt a deletion record solely to test notification delivery.

When an alert fires:

1. inspect the `accountdeletionrepair` revision and scheduler execution;
2. correlate retryable failures by `uidHash`, stage, and attempt count;
3. confirm the scheduler remains enabled and one-minute invocations continue;
4. allow the idempotent worker to retry, or repair the failed dependency;
5. never skip stages or manually delete a subset of account data.
