# Inbox retention and player deletion

Requested: keep unclaimed gold and unread informational messages indefinitely;
remove claimed gifts 30 days after claim and informational messages 30 days after
first read. Allow immediate player deletion unless gold remains unclaimed.

## Acceptance and scope

- Backend enforces recipient identity, account deletion fences, unclaimed-gift
  protection, idempotent deletion, exact counters and no duplicate delivery/payments.
- Removed messages retain compact account-scoped receipts without title/body;
  account erasure includes those receipts. Existing messages remain compatible.
- Bounded hourly expiry cleanup and resumable legacy expiry repair use transactions
  and preserve progress across overlapping invocations. No Firestore TTL deletion.
- Inbox exposes Delete, protected-gift explanation, retention wording, busy/error
  recovery, and fences stale list responses after deletion/account replacement.
- Focused emulator, adapter/controller/widget tests; update TDD/GDD and rollout notes.

Unrelated edits preserved: `docs/building/android_beta_release.md` and
`docs/verification/android-beta-2026-10-26.md`. Implementation is authorized;
deployment and live deletion are not authorized by this request.

## Work

- [x] Backend receipts, deletion, retention/legacy repair, erasure and callable.
- [x] Flutter API/state/inbox controls and race handling.
- [x] Focused regression checks, documentation, task diff review and local commit.

Context7 is unavailable in this session. Use official Firebase/Flutter documentation
for library-specific usage; existing repository patterns remain authoritative.

## Validation evidence

Tested source: retention and deletion changes based on `d5b51ad9`, committed with
this record. All commands ran from `C:\dev\rpg_runner`. Tests used local emulators
or fakes, without deployment or live player mutations.

- `corepack pnpm --dir functions build` and
  `corepack pnpm --dir functions build:test`: passed on final backend source.
- `corepack pnpm --dir functions exec firebase emulators:exec --config
  ../firebase.test.json --project demo-rpg-runner-functions-tests --only firestore
  "node --test lib_test/test/inbox/inbox.test.js lib_test/test/inbox/operator.test.js
  lib_test/test/inbox/retention.test.js lib_test/test/account/account_delete_callable.test.js
  lib_test/test/rules/firestore_rules.test.js lib_test/test/runs/run_projection.test.js"`:
  79 passed. Covers delivery/claim/deletion races, retry receipts, exact retention
  boundaries, legacy repair/cursor overlap, erasure, direct-client denial and
  level-gift settlement. This run preceded the final expiry overflow guard;
  focused final-source retention verification is recorded below.
- `corepack pnpm --dir functions exec firebase emulators:exec --config
  ../firebase.test.json --project demo-rpg-runner-functions-tests --only firestore
  "node --test lib_test/test/inbox/retention.test.js"`: all eight passed on final
  backend source, including transaction rollback when an expiry would overflow.
- With `INBOX_CAPTURE=1`, `flutter test --no-pub
  test/ui/state/app_state_inbox_test.dart test/ui/state/firebase_inbox_api_test.dart
  test/ui/pages/messages/messages_page_test.dart`: all 24 passed. Includes lost
  responses, stale pages, account replacement, strict receipts, protected gifts,
  deletion retry and pagination after deleting the loaded page. Layout cases
  cover 844x390 and 640x360, with long content at 1.5 text scale. The 960x450
  screenshot was visually reviewed; output is ignored at `.tmp/inbox/inbox.png`.
- Direct SDK `dart.exe format` on the nine changed Dart files: passed.
- `dart.exe analyze lib/ui/state/inbox
  lib/ui/state/app/controllers/inbox_controller.dart lib/ui/state/app/app_state.dart
  lib/ui/pages/messages test/ui/state/app_state_inbox_test.dart
  test/ui/state/firebase_inbox_api_test.dart test/ui/pages/messages/messages_page_test.dart
  test/ui/test_support/inbox_fixture.dart`: passed with no issues. Used
  `C:/Users/Toonsa/flutter/bin/cache/dart-sdk/bin/dart.exe`.
- `git diff --check` and changed documentation's local file links: passed.

An initial test compilation caught a fixture edit, which was corrected before
the successful checks. Initial sandboxed Dart formatting could not write its
user-level telemetry state; SDK checks were rerun with the necessary filesystem
access. Final Firebase commands unset the inherited `DEBUG` variable to avoid
unrelated CLI debug output.

Documentation lookup used the official
[scheduled Functions](https://firebase.google.com/docs/functions/schedule-functions),
[Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
and [Flutter IconButton](https://api.flutter.dev/flutter/material/IconButton-class.html)
references because Context7 was unavailable.

## Release handoff

Implementation is complete locally; deployment remains outside this request.
Follow [the inbox deployment ordering](../../../tdd/system_inbox.md#extension-and-release-boundaries)
before enabling Delete in a released app. Rebuild/restart privileged message
senders before cleanup begins. Existing eligible mail can be removed during the
first cleanup passes; unread information and unclaimed gold remain protected.
