# Production Alert Channel Confirmation — July 19, 2026

## Scope and result

The production email notification channel for `rpg-runner-d7add` was verified
and exercised end to end on July 19, 2026. The recipient confirmed receipt of
the synthetic incident email. The temporary alert policy was deleted after
confirmation.

This record intentionally omits the recipient address and verification code.
The channel resource name is retained because it is a non-secret deployment
identifier:

`projects/rpg-runner-d7add/notificationChannels/12624621645792006468`

## Channel verification

Before the test, the channel was enabled but unverified. A verification message
was requested through the Cloud Monitoring API and the repository owner
provided the one-time code out of band.

After verification:

- `enabled` was `true`;
- `verificationStatus` was `VERIFIED`;
- Cloud Monitoring's verification-proof endpoint returned a valid,
  time-bounded proof;
- no verification secret was written to the repository.

## Isolated delivery test

A temporary log-match policy was created with an exact synthetic test ID:

`notification-delivery-20260719-155802`

The policy resource was:

`projects/rpg-runner-d7add/alertPolicies/14691687732103635047`

Its condition matched only log entries with both:

- `jsonPayload.message="rpg_runner_notification_channel_test"`; and
- `jsonPayload.testId="notification-delivery-20260719-155802"`.

The first entry was written immediately after policy creation. A second
matching entry was written after the policy had propagated. Cloud Monitoring
opened incident:

`projects/rpg-runner-d7add/alerts/0.oafhbiwmkruo`

The incident opened at `2026-07-19T16:01:37Z`. The recipient confirmed an email
containing the exact policy name, condition name, project, test ID, and
temporary policy documentation.

This proves the complete path:

1. Cloud Logging accepted the scoped synthetic event.
2. The log-match notification rule selected it.
3. Cloud Monitoring opened the expected incident.
4. The verified production email channel delivered the notification.
5. The human recipient received the correct incident content.

## Cleanup and final state

The temporary policy was deleted at approximately
`2026-07-19T16:08:45Z`. A post-cleanup inventory confirmed:

- the temporary policy no longer exists;
- the production channel remains enabled and `VERIFIED`;
- 14 real enabled alert policies continue to reference the channel;
- no real alert condition, threshold, or notification routing was changed.

The synthetic incident was still open immediately before policy deletion. Its
history may remain visible according to Cloud Monitoring's incident-retention
behavior, but the deleted policy cannot match another log entry or emit another
test notification.

## Closure decision

Production email alert routing is confirmed operational. Future missing-alert
investigations must distinguish these separate stages:

- policy condition matched;
- incident opened;
- channel delivery attempted;
- recipient received the notification.

API-visible channel status or an opened incident alone is not sufficient proof
of recipient delivery; this controlled test includes all four stages.

## Follow-up monitoring inventory

After the later Functions safety-monitoring rollout, the same enabled and
verified channel is referenced by all 29 enabled production policies. Three
account-deletion and twelve callable/resource policies were added without
changing the channel. Exact resources and safe real-filter exercises are in
the
[Functions safety monitoring rollout](functions-safety-monitoring-rollout-2026-07-19.md).
