# Message tooling — completed October 28, 2026

## Scope and acceptance

Build a local developer console in `tools/messaging/` for one player UID,
message title/body and optional claimable gold. Require explicit dev/staging/prod
selection from the existing release registry, an immutable preview before send,
and durable delivery identities for retries. Reuse backend issuance/claim logic.
Items, skills, broadcasts and cloud deployment are outside this workstream.

Existing unrelated edits to preserve: `android_beta_release.md` and
`../verification/android-beta-2026-10-26.md`.

## Milestones

- [x] Share operator validation/delivery between the existing CLI and local tool.
- [x] Implement environment routing, local HTTP boundary and browser composer.
- [x] Validate input, preview/send isolation, retries and backend issuance with
  focused tests; exercise the UI against a local fake delivery adapter.
- [x] Complete operator instructions, technical contract and final diff review.

No live messages or gold will be sent during implementation. Local tests and
emulator evidence do not establish deployed inbox availability.

## Delivered behavior

Local browser console, registry-derived environments, single UID, text and optional
gold; immutable preview, stable delivery identity, saved/exported/restored drafts,
retry recovery and delivery confirmation. CLI and console share operator parsing
and delivery. No wire-schema or player-experience change; GDD remains current.
See the [operator guide](../../../../tools/messaging/README.md) and
[technical contract](../../../tdd/system_inbox.md).

## Validation evidence

Tested source: message-tool and inbox-operator changes in the same commit as this
record, based on `bcb59300`. All commands ran from `C:\dev\rpg_runner`.

- `corepack pnpm messages:test`: Functions build and five local HTTP tests passed.
  After final preview-cache changes,
  `node --test tools/messaging/test/server.test.mjs`: five passed again.
- `corepack pnpm --dir functions build:test`: passed.
- `corepack pnpm --dir functions exec firebase emulators:exec --config
  ../firebase.test.json --project demo-rpg-runner-functions-tests --only firestore
  "node --test lib_test/test/inbox/inbox.test.js lib_test/test/inbox/operator.test.js"`:
  11 passed. Includes real emulator transaction/claim/deduplication, missing-player
  and deletion fences through the operator adapter. No live project writes.
- `node tools/messaging/test/browser_smoke.mjs`: passed with an isolated Chrome
  profile and in-memory sender. Covers environment selection, local preview,
  escaped text, edit invalidation, production review, uncertain delivery,
  reload/retry, export/import, local-storage failure, message-only preview,
  missing recipient and narrow-screen overflow. Screenshots visually reviewed;
  generated files remain in ignored `build/messaging-smoke/`.
- `node tools/messaging/start.mjs --port invalid`: expected rejection, exit 1.
- `git diff --check`: passed; changed documentation links checked locally.

The first emulator attempt was blocked reading the Firebase CLI's local config;
the rerun with required filesystem access passed. The browser connector profile
was busy and the in-app browser unavailable. The first headless check stalled
inside the sandbox; the identical check with required process access passed.
Subsequent browser regression checks also passed with that access.

Operator credentials, live inbox deployment and real-player end-to-end delivery
were not verified. No deployment or live message was requested or performed.
