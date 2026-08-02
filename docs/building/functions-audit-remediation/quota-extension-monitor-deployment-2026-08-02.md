# Quota Extension Monitor Deployment — August 2, 2026

## Outcome

The quota extension for canonical ownership reads, profile reads and writes,
account-deletion requests, and run-status polling is deployed to production in
`monitor` mode only. It is **not** yet production-enforced.

The rollout deliberately stops before enforcement because the current
production canary creates an anonymous Firebase Auth user while every player
callable now requires a linked Google Play Games identity. That account was
correctly rejected before a quota decision or gameplay write. A complete
authenticated canary is still required before promoting these routes.

## Deployed scope

Deployment project: `rpg-runner-d7add`  
Region: `europe-west1`  
Deployment mode: `ABUSE_CONTROL_MODE=monitor`

| Function | Active revision |
| --- | --- |
| `loadoutOwnershipLoadCanonicalState` | `loadoutownershiploadcanonicalstate-00011-hez` |
| `playerProfileLoad` | `playerprofileload-00011-xav` |
| `playerProfileUpdate` | `playerprofileupdate-00011-lom` |
| `accountDelete` | `accountdelete-00016-way` |
| `runSessionCreate` | `runsessioncreate-00013-zaw` |
| `runSessionCreateUploadGrant` | `runsessioncreateuploadgrant-00013-cem` |
| `runSessionLoadStatus` | `runsessionloadstatus-00011-kuw` |

All seven Functions reported `ACTIVE` with all traffic on their latest
revision and `ABUSE_CONTROL_MODE=monitor` after deployment.

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

## Promotion gate

Do not change these seven Functions to `ABUSE_CONTROL_MODE=enforce` until a
dedicated, disposable Firebase account linked to Google Play Games has run the
complete canary. The test session must also be freshly authenticated (within
five minutes) to exercise the account-deletion path.

The current Node canary must be extended to accept that dedicated linked
identity without treating it as an anonymous signup, with an explicit
destructive-deletion opt-in. The successful monitor canary must then show all
eleven quota routes accepted with `wouldReject: false`, including the five new
routes; only after recording that evidence may the same seven Functions be
redeployed with `ABUSE_CONTROL_MODE=enforce` and re-verified.
