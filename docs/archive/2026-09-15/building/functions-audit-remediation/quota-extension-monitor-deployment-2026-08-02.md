# Quota Extension Monitor Deployment — August 2, 2026

## Outcome

The quota extension for canonical ownership reads, profile reads and writes,
account-deletion requests, and run-status polling was first deployed to
production in `monitor` mode, then promoted to `enforce` on August 2, 2026 by
explicit owner direction. It is deployment-verified, but it is **not yet
end-to-end-canary-verified**.

The normal rollout gate would stop before enforcement because the current
production canary creates an anonymous Firebase Auth user while every player
callable now requires a linked Google Play Games identity. That account was
correctly rejected before a quota decision or gameplay write. The owner
explicitly accepted promotion before a complete authenticated canary; the
missing canary remains a recorded verification obligation.

## Deployed scope

Deployment project: `rpg-runner-d7add`  
Region: `europe-west1`  
Deployment mode: `ABUSE_CONTROL_MODE=enforce`

| Function | Active revision |
| --- | --- |
| `loadoutOwnershipLoadCanonicalState` | `loadoutownershiploadcanonicalstate-00012-max` |
| `playerProfileLoad` | `playerprofileload-00012-puq` |
| `playerProfileUpdate` | `playerprofileupdate-00012-feh` |
| `accountDelete` | `accountdelete-00017-zuw` |
| `runSessionCreate` | `runsessioncreate-00014-mob` |
| `runSessionCreateUploadGrant` | `runsessioncreateuploadgrant-00014-miv` |
| `runSessionLoadStatus` | `runsessionloadstatus-00012-toy` |

All seven Functions reported `ACTIVE` with all traffic on their latest
revision and `ABUSE_CONTROL_MODE=enforce` after promotion. No error-severity
log entry was observed for those revisions in the immediate post-promotion
window beginning at `2026-08-02T18:50:00Z`.

The rollout includes the signed replay POST contract: upload grants bind the
content type and a `content-length-range` condition, and clients submit the
policy fields before the replay file part.

## Canary result and cleanup

`functions/tool/production_canary.mjs` authenticated an anonymous disposable
account, then `playerProfileLoad` returned the expected production denial:
`PERMISSION_DENIED: A linked Google Play Games identity is required.`

This is an authorization-policy outcome, not a monitor-mode quota rejection.
The linked-identity guard runs before `profile_read` quota consumption, so the
failed account made no quota decision and did not create game data. Its in-band
`accountDelete` request was also correctly denied by the same policy. The
disposable Auth account was subsequently deleted through the privileged
Identity Platform account API, and an admin lookup confirmed zero remaining
users for its recorded synthetic UID hash.

## Outstanding canary verification

The owner explicitly promoted these seven Functions despite this incomplete
gate. A dedicated, disposable Firebase account linked to Google Play Games
must still run the complete canary. The test session must also be freshly
authenticated (within five minutes) to exercise the account-deletion path.

The current Node canary must be extended to accept that dedicated linked
identity without treating it as an anonymous signup, with an explicit
destructive-deletion opt-in. The subsequent canary must show all eleven quota
routes accepted, including the five new routes. Any unexpected rejection,
configuration error, or elevated error log warrants the documented rollback:
set `ABUSE_CONTROL_MODE=monitor` and redeploy these same seven Functions.
