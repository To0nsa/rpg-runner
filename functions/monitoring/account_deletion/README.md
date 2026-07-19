# Account-deletion production monitoring

This bundle owns the production alerts for the resumable account-deletion
workflow:

- any stage transition to `retryable`;
- incomplete work older than six hours or at 400 attempts;
- unexpected errors from the scheduled repair service.

The six-hour threshold deliberately exceeds the expected duration of the
multi-board, repeated-reconciliation workflow. Each
`accountDeletionRepair` heartbeat includes the bounded page size, oldest age
and stage, retryable count, maximum attempt count, and page-saturation signal.
It contains no account identifier. Retryable-failure logs use a truncated
SHA-256 UID hash for correlation and never emit the raw UID.

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
