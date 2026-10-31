# Immediate run gold and XP display, October 31, 2026

Implemented the owner's decision after the APK 5 measurements: display run gold
and XP immediately without pending labels, while purchases and level gifts still
require confirmed settlement. This is local implementation evidence, not a new
phone measurement or deployment.

## Source and scope

Started from clean `81272eecf87acd8a2ffcef555de46700f1f6a512`. The tested
client/test patch is committed with this record. The 24 changed Dart files have
normalized source manifest SHA-256
`b7b818575e0f0e37d65b59f254eda80187844bd99089f366fefee5ee0e655e2b`.
The manifest is a sorted JSON map of relative path to SHA-256 of UTF-8 contents
with LF newlines, serialized without spaces. Local logs, manifest and rendered
PNGs are in ignored `.tmp/reward-display-20261031/`.

- Reused the local submission journal, Core score breakdown, canonical applied
  grant IDs, completion receipts, AppDialog, theme and XP animation.
- Wallet/XP presentation includes eligible journaled rewards. Canonical account
  state remains separate; confirmed funds remain usable while another run waits.
- Canonical refreshes, retries, restart and receipt ordering cannot apply a
  local reward twice. Retained-history anchors suppress ambiguous old previews.
- Purchases and paid refreshes needing unconfirmed funds explain the wait.
  Settlement updates the open modal without automatically buying anything.
- Rejected rewards correct the display; transient failures keep recovery intact.
- No Core, protocol, server, authored terrain or navigation input changed. No
  navigation regeneration, Android build, cloud mutation or reserved idle compute.

Contracts: [reward presentation](../tdd/reward_settlement_operations.md#immediate-local-reward-presentation),
[XP](../tdd/player_progression.md), [active workstream](../building/reward_verification_latency.md).

## Local validation

All commands ran from `C:\dev\rpg_runner` with Flutter 3.47.1 / Dart 3.13.1.
Backend interactions in these tests are fakes or checked-in producer fixtures;
they are not live service evidence.

| Check | Result and source |
| --- | --- |
| Native `dart.exe analyze` over the 24 changed Dart files | No issues; `analysis-final.log` |
| `flutter test --no-pub test/ui/state/app_state_run_submission_test.dart` | 26 passed; `state-final.log`. Includes rejection, concurrent rewards, stale canonical responses, failed canonical recovery, paid/unpaid/pruned/retained-anchor restart and account replacement. |
| `flutter test --no-pub test/ui/state/app_state_ownership_conflict_test.dart test/ui/state/app_state_ownership_commands_test.dart test/ui/state/app_state_hybrid_sync_test.dart test/ui/state/app_state_account_deletion_test.dart test/ui/state/app_state_inbox_test.dart test/ui/state/app_state_achievements_test.dart test/ui/bootstrap/ui_app_startup_test.dart test/ui/pages/messages/messages_page_test.dart test/ui/pages/meta/achievements_page_test.dart` | 74 passed; `account-consumers.log` |
| `flutter test --no-pub --update-goldens .tmp/reward-display-20261031/modal_preview_test.dart test/ui/pages/hub/play_hub_page_test.dart test/ui/pages/meta/town_page_test.dart` | 21 passed, including two temporary visual checks; `modal-and-hub-final.log`. Local XP crosses a level once and stays unchanged on settlement; confirmed spending, deferred purchase/refresh and no automatic purchase covered. |
| Submission persistence, receipt decoding, coordinator, progression, Game Over, profile and paint diagnostics | Selected files passed across the batches below; earlier failed expectations and an invalid path are explicitly recorded. |
| `node tools/agents/check.mjs` | Passed; 36 guidance files |
| `git diff --check`; changed relative Markdown link checks | Passed |

Additional batch commands and outcomes:

```powershell
flutter test --no-pub test/ui/state/app_state_run_submission_test.dart test/ui/state/run_submission_spool_store_test.dart test/ui/state/run_submission_response_test.dart test/ui/pages/meta/town_page_test.dart test/ui/game_over_score_feed_test.dart
flutter test --no-pub test/ui/state/run_submission_response_test.dart test/ui/game_over_score_feed_test.dart
flutter test --no-pub test/ui/game_over_score_feed_test.dart test/ui/state/run_submission_coordinator_test.dart test/ui/state/player_progress_test.dart test/ui/state/app_state_ownership_test.dart test/ui/pages/hub/play_hub_page_test.dart test/ui/pages/profile/profile_page_test.dart test/ui/components/reward_diagnostics_test.dart
```

The first batch passed 70 tests and failed five: four old verification-label/
wallet expectations and one incorrect assumption that a legacy TypeScript
receipt fixture includes XP. The corrected two-file batch passed 31 tests with
one remaining stale wallet assertion. After correcting that assertion, all 72
tests in the third batch passed; that command still exited nonzero because the
listed `app_state_ownership_test.dart` does not exist. The real ownership command
and conflict files passed in the separate 74-test batch above. Logs are
`targeted-tests.log`, `corrected-expectations.log` and `consumer-tests.log`.

The first added hub animation test also needed a frame to mount its pushed route
before popping it. The corrected route test passes in the final 21-test batch;
no production animation logic was changed.

## Visual review and remaining acceptance

Rendered the actual modal and store with the app theme and bundled fonts at
800×360 landscape and 360×640 portrait. Inspected checking and ready PNGs. The
first render clipped “Back to store”; using the existing small button size fixed
it, and both final layouts were inspected without overflow or clipping. The
temporary harness and images remain ignored local evidence.

No Android installation or live verification of this UI change has been done.
APK 5 and the existing dev backend remain the latest measured deployment. Device
acceptance should confirm immediate results, the wait/ready modal, ordinary
confirmed spending and offline/restart recovery. Existing pipeline phone
recovery and controlled latency work remains open in the active plan.
