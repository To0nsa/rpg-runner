# Dev item and skill gift activation — October 29, 2026

The owner explicitly requested activation in dev after the Admin catalog showed
the disabled rollout message. Activation completed at **21:43:14 UTC** in
`rpg-runner-d7add`. Staging and production were not changed.

## Verified source and client

- Deployed source: `285ef4f491f9eef6c2ea605a7ee7d709f534a69e`.
- Source digest: `60ed92d85cc12ae202b96448f5fdcb4e7c95cd9eefb91e369506581d51b74055`.
- Canonical dev Deploy completed at 21:33:21 UTC and ResumeIssuance at 21:38:36 UTC.
- Fresh Cloud Functions reads verified all six inbox handlers ACTIVE and their
  update times exactly matching the completed release's `functions.json`.
- Dev app `com.example.rpg_runner.dev`, version `1.0.0-dev`, build 2 was installed
  at 21:39:30 UTC. The installed APK hash matched the prepared artifact:
  `db378bc84ea5a6fc94ae13e56af36899826027c44ad9908eb1c9cb8f4b822f33`.
  This session also read the installed package version before USB disconnected.
  The recent exact installation evidence was reused; no further device input
  was needed. The [dev release record](dev-app-2026-10-29.md) records its inbox
  startup checks.
- Current Admin/backend gift sources matched the frozen release. Both compiled
  catalogs had the same hash.

## Configuration mutation and readback

The configuration did not exist before activation. The operation created only
`inbox_configuration/gifts` with:

```json
{
  "schemaVersion": 1,
  "enabled": true,
  "catalogHash": "9310db4c01d6ff89956a506383aea0d9b6a2da8367e4033cda5252d7af771d36"
}
```

The operation used the dedicated Lothringen Admin credentials and an explicit
dev target. It reused the canonical release mutation-lock helpers, verified that
no cutover was active, rechecked deployed handlers and the prior configuration,
and used create-if-absent semantics. Readback confirmed the expected record.
The acquired lock was released by its exact generation; independent verification
confirmed both lock and cutover objects absent.

At 21:44:01 UTC, the real local Admin service's authenticated `POST /api/catalog`
returned HTTP 200, `enabled: true`, the dev project and the expected catalog hash.
All **63 entries** matched the compiled catalog: **34 gear items, 21 abilities
and 8 projectile spells**. The open Admin app can load them with **Reload catalog**.

Commands ran from `C:\dev\rpg_runner`, using Node 24.16.0:

- `.tmp/admin-dev-gifts-20261029.mjs inspect dev`: live read-only preflight passed.
- `pwsh -NoProfile -File .tmp/activate-admin-dev-gifts-20261029.ps1 -Environment dev`:
  guarded configuration creation and readback passed.
- `.tmp/admin-dev-gifts-20261029.mjs verify dev`: independent live readback and
  the actual Admin service endpoint passed.

The scripts and JSON snapshots remain in ignored `.tmp/admin-dev-gifts-*` and
`.tmp/activate-admin-dev-gifts-*` paths. They are evidence for this operation,
not reusable release authorization. Initial attempts stopped before cloud
mutation because network sandbox access was unavailable, USB had disconnected,
and a PowerShell date conversion needed correction. The successful operation
used approved network access and the verified recent installation record.

## Scope and limits

This is an owner-authorized **controlled dev activation**, not staging/prod
rollout acceptance. Gift recipients must use the compatible dev build 2 or a
later compatible build. Global minimum inbox-client version enforcement is not
implemented, so older-client exclusion was not established. The stricter
staging/prod rollout prerequisites remain outstanding.

No player message, grant or ownership mutation was performed to test activation.
No live item/skill send-and-claim was claimed as verified. Existing source-matching
emulator and client tests are recorded in the [implementation evidence](admin-tools-2026-10-29.md).
Disabling new issuance must retain schema-2 readers for existing messages, as
specified in [Admin architecture](../tdd/admin_tools.md#gifts-and-release-activation).
