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

## Follow-up: isolated messaging login

Source: dedicated-login changes based on `7b93af41`, in the same commit as this
section. The user requested keeping the existing shared ADC for another project.
The console now selects its own per-user credential file, with a dedicated
`messages:login --account <email>` command, explicit account display, and no
fallback to shared ADC. The Functions CLI and inbox transaction are unchanged.

Checks from the repository root:

- `node --test tools/messaging/test/auth.test.mjs tools/messaging/test/server.test.mjs`:
  eight passed. Includes child-process identity isolation, preservation of shared
  credential bytes, missing/corrupt dedicated credentials, safe recovery messages,
  immutable previews and same-delivery retries.
- `node tools/messaging/test/browser_smoke.mjs`: passed against the in-memory
  sender, including account display and all previous recovery/layout cases.
  Preview screenshot inspected; no live writes or external browser requests.
- Login with an invalid email and launcher with an invalid port both reject
  with exit 1 before contacting Google.
- `git diff --check`: passed. No new package or backend source changes.
- Dedicated gcloud login launched using `node tools/messaging/login.mjs --account
  lothringen.rpg@gmail.com`; browser consent completed successfully. The helper
  confirmed that the dedicated file belongs to the requested account.
- Live read-only verification after sign-in used `configureMessagingCredentials`,
  a named Firebase Admin app for `rpg-runner-d7add`, and `getAll` for the target
  player profile and original delivery's message/reward documents. Access and
  profile existence were confirmed; the original delivery was still absent.
  SHA-256 comparison confirms the shared ADC and gcloud active-configuration
  selector remain byte-for-byte unchanged. No message was sent by the agent.
- `node tools/messaging/start.mjs` passed dedicated credential validation but
  found port 8766 occupied by the existing console. No process was stopped or
  replaced; the user reported that it was working.

Context7 was unavailable. Authentication behavior was checked against the
official [gcloud login reference](https://docs.cloud.google.com/sdk/gcloud/reference/auth/application-default/login),
[configuration documentation](https://docs.cloud.google.com/sdk/docs/configurations)
and [ADC search order](https://docs.cloud.google.com/docs/authentication/application-default-credentials).
