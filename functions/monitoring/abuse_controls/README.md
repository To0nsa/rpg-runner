# Callable abuse and resource monitoring

This bundle owns operational alerts for callable App Check and quota controls,
plus the resource/cost pressure they bound. It creates four privacy-safe
log-based metrics and twelve policies.

## Coverage

- more than 20 missing/invalid App Check verification summaries in 15 minutes;
- any enforced quota rejection or invalid abuse-control configuration;
- any active-session/upload-grant saturation or bounded-scan saturation;
- any non-validator backend 5xx or transaction-contention error;
- a full 200-document quota-retention cleanup page;
- more than 64 replay-finalize attempts in 15 minutes, with exact bytes kept
  on each structured decision;
- more than 500 accepted signed-URL attempts in 15 minutes;
- more than 1,000 replay-bucket API operations in 15 minutes;
- more than 1,000 Cloud Tasks attempts in 15 minutes;
- more than 5,000 callable verification summaries in 15 minutes.

The volume thresholds are pre-launch safety bounds based on controlled traffic,
protocol maxima, and the fact that the game is not live. They are deliberately
well above canary traffic. Revisit them after at least seven days of organic
route, latency, and cost observations; never raise them solely to silence an
incident.

Existing source-controlled replay-validator policies remain authoritative for
validation/projection queue backlog, retry activity, validator 5xx, resource
rejections, probe failures, and memory pressure. This bundle adds task-attempt
volume rather than duplicating those latency/recovery policies.

The request, replay-byte, signer, Storage, and task policies are resource/cost
proxies. They do not replace a Cloud Billing budget owned at the billing
account level.

## Apply

Use the already verified production notification-channel resource:

```powershell
.\functions\monitoring\abuse_controls\apply_alerts.ps1 `
  -ProjectId rpg-runner-d7add `
  -NotificationChannel projects/rpg-runner-d7add/notificationChannels/CHANNEL_ID
```

The command idempotently creates or updates metrics and policies by exact name,
and refuses a disabled or unverified notification channel.

## Interpretation

App Check remains a global callable gate. This monitoring bundle does not make
native release attestation valid and does not authorize enforcement. Keep
`APP_CHECK_ROLLOUT_MODE=monitor` until each in-scope release platform supplies
representative verified tokens or is explicitly excluded from the Firebase
release.

Quota logs contain only a truncated SHA-256 UID hash. App Check observations
contain the Firebase app ID but no UID. Logs-based metrics define no extracted
high-cardinality labels.

When a policy fires, correlate the route/service with App Check status, quota
decision, 5xx/contention, queue backlog/retry, Storage method/response code, and
task response-code series. Preserve Auth, UID matching, atomic transactions,
bounded scans, and enforcement while repairing the dependency or abusive
traffic source.
