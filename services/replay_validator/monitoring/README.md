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

The script creates or updates four log-based metrics and ten alert policies:

- validation retry or lease-conflict activity;
- projection or ghost-reconciliation retry activity;
- terminal validator internal errors;
- bursts of replay resource-limit rejection;
- Cloud Run request 5xx responses;
- failed startup or liveness probes;
- sustained container memory pressure;
- sustained validation or projection queue backlog;
- scheduled validation-repair or projection-reconciliation failures.

The policies reuse an enabled email channel for the supplied address or create
one when absent. Cloud Run and Cloud Tasks policies use native metrics. The
other policies use only the structured `replay_validator.dispatch` event
written by the service.

## Operational interpretation

Validation and projection retries are warnings because durable retry and
repair are expected to recover them. A terminal internal error, unhealthy
probe, or failed repair/reconciliation job is critical because the durable
recovery boundary itself failed or a run exhausted its recovery window.

Queue backlog thresholds deliberately exceed the normal retry and
reconciliation cadence:

- validation depth greater than zero for 15 minutes;
- projection depth greater than zero for 30 minutes.

After applying the policies, verify their enabled state, notification channel,
metric filters, and a healthy `/live` and `/ready` production smoke. Do not
generate a false production incident merely to test email delivery.
