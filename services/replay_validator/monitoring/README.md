# Replay validator monitoring

This directory defines production monitoring for replay validation,
leaderboard/ghost projection, and their durable recovery paths. Metrics do not
extract run-session, user, board, lease-token, or other high-cardinality
labels.

Apply or reconcile the configuration from the repository root:

```powershell
.\services\replay_validator\monitoring\apply_alerts.ps1 `
  -ProjectId rpg-runner-d7add `
  -NotificationEmail lothringen.rpg@gmail.com
```

The script creates or updates nine log-based metrics, eleven alert policies,
and the `RPG Runner - Projection cost and recovery` dashboard:

- validation retry or lease-conflict activity;
- projection or ghost-reconciliation retry activity;
- terminal validator internal errors;
- bursts of replay resource-limit rejection;
- Cloud Run request 5xx responses;
- failed startup or liveness probes;
- sustained container memory pressure;
- sustained validation or projection queue backlog;
- scheduled validation-repair or projection-reconciliation failures;
- retained projection-board count at the 80-board release threshold.

The dashboard covers changed/unchanged/ghost-only outcomes, projection
duration, boards selected per invocation, completed cursor-cycle duration,
retained-board count, daily Firestore reads/writes, and the structured
reconciliation page logs.

The policies reuse an enabled email channel for the supplied address or create
one when absent. Cloud Run and Cloud Tasks policies use native metrics. The
log-based policies use either the structured `replay_validator.dispatch` event
written by the service or the structured `runProjectionReconciliation` event
written by the scheduled Function.

The checked-in queue policy retains `1.0` Cloud Tasks operation logging for
`replay-validation` and samples `replay-projection` operation logs at `0.1`.
That sampling may apply to successful and failed queue operations. Failure
coverage therefore comes from independent sources:

- projection retry alerts consume unsampled validator application logs;
- reconciliation-failure alerts consume scheduled Function error logs;
- queue backlog alerts consume native Cloud Tasks depth metrics;
- Cloud Run 5xx alerts consume native request metrics.

None of these policies depends on successful Cloud Tasks operation logs.

## Operational interpretation

Validation and projection retries are warnings because durable retry and
repair are expected to recover them. A terminal internal error, unhealthy
probe, or failed repair/reconciliation job is critical because the durable
recovery boundary itself failed or a run exhausted its recovery window.

Queue backlog thresholds deliberately exceed the pre-release retry and
reconciliation cadence:

- validation depth greater than zero for 30 minutes;
- projection depth greater than zero for 30 minutes.

Before public release, remeasure validation recovery and restore the production
repair cadence and alert threshold.

The projection repair sweep runs hourly and selects at most four boards by
default. Its `runProjectionReconciliation` structured log includes cadence,
effective batch size, queried/selected/enqueued counts, page completion, next
cursor, retained-board count, completed-cycle duration, and whether the cursor
compare-and-set committed. Fifty-four retained boards should complete in 14
successful invocations. The checked-in alert fires at the 80-board operator
review threshold; before exceeding 96, approve archival, a measured larger
bounded page, or a due/dirty index so the 24-hour repair SLO does not silently
drift.

After applying the policies, verify their enabled state, notification channel,
metric filters, and a healthy `/live` and `/ready` production smoke. Do not
generate a false production incident merely to test email delivery.
