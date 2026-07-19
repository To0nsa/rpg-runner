# Reward settlement monitoring

This directory defines the production alerts in
`docs/tdd/reward_settlement_operations.md`. Metrics intentionally have no uid,
run-session-id, board, or other high-cardinality label.

Apply or reconcile the configuration with a principal that can manage Cloud
Logging metrics, Cloud Monitoring alert policies, and notification channels:

```powershell
.\functions\monitoring\reward_settlement\apply_alerts.ps1 `
  -ProjectId rpg-runner-d7add `
  -NotificationEmail lothringen.rpg@gmail.com
```

The script creates or updates three logs-based metrics, four alert policies,
and the `RPG Runner - Reward settlement` Cloud Monitoring dashboard:

- settlement invariant violation: immediate critical log-match alert;
- retryable reward pending more than 15 minutes: critical repair-scan log-match
  alert;
- immediate dispatch fallback ratio greater than 5% in 15 minutes: warning;
- p99 durable-finalize-to-settlement-handoff latency greater than 15 seconds in
  15 minutes: warning.

The dashboard keeps payout and optional leaderboard/ghost work separate. It
charts durable handoff latency, immediate delivery activity and fallback ratio,
and validator 5xx responses. Its log panels provide the run-session-level
settlement, repair/invariant, and projection-retry evidence needed to diagnose
an alert without adding high-cardinality metric labels.

## Planned replay drills

Do not pause queues or induce retry/lease contention under live alerting
without a time-bounded Monitoring snooze. Create it before the drill; it covers
only the payout-latency, validator-5xx, and validation-retry policies and never
disables their evaluation:

```powershell
.\functions\monitoring\reward_settlement\snooze_replay_drill.ps1 `
  -Reason "lease-recovery drill" `
  -DurationMinutes 15
```

The helper requires a reason, limits a snooze to 60 minutes, resolves the
managed policies by exact display name, and prints its start/end times. Use
`-WhatIf` to verify the target policies without creating a snooze. Allow the
snooze to expire naturally; do not disable or edit alert policies for a drill.

The stale-pending policy independently covers delivery after the durable
handoff. Google Cloud sends a verification email when a new email notification
channel is created; alerts cannot notify that address until its link is
confirmed.
