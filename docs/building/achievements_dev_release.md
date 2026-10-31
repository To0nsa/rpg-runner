# Hall of Honour dev release

Authorized on 2026-10-30: deploy the achievements changes to dev and reuse
verified unchanged artifacts and checks. No staging/prod deployment or player
data reset is included.

Frozen candidate: `8a094efb67a9f8e988940206c73b830765142248`; source digest
`d74764d48e162314e48072d2a91474eb54776ab29f427b14c4556d1e13c878ba`.
Environment: `dev`, project `rpg-runner-d7add`, region `europe-west1`.
Plan selects coordinated cutover at the unchanged
`2026.10.21 / rules-v2 / score-v4 / ghost-v1` tuple.

## Acceptance and progress

- [x] Freeze the clean candidate with the canonical LF Checkout action; Plan passes.
- [x] Prepare changed Functions/client components; reuse matching shared checks.
- [x] Reuse verified client navigation and the unchanged immutable worker image.
- [x] Build and inspect the updated dev Android artifact, version code 4.
- [x] Inspect live state, pause issuance and verify drained sessions.
- [x] Deploy Functions, worker/configuration and Hosting; verify readiness and resume.
- [x] Record fresh deployment identities and preserved player-state totals.
- [x] Verify installed APK 4 on the connected device and a natural accepted run
      (October 31: on-device hash matches; two runs settled exactly once).
- [ ] Verify achievement date, gold claim and duplicate-claim protection through
      the live menu.

All release commands run from
`.tmp/release-checkouts/8a094efb67a9f8e988940206c73b830765142248`.
Use `tools/release/release.ps1 -Environment dev` and preserve its source-bound
maintenance record throughout cutover. Existing evidence is
[local achievement verification](../verification/achievements-2026-10-30.md) and
[the preceding dev release](../verification/reward-diagnostics-dev-2026-10-30.md).
The phone was disconnected at both initial and final October 30 checks. The
[October 31 reward measurement](../verification/reward-latency-phone-2026-10-31.md)
verified the already-installed APK and natural runs; achievement-menu acceptance
remains open.

Cloud cutover completed and issuance resumed at 20:36:11 UTC. The final issuer
readback confirms a healthy revision serving 100% of traffic without a pause
override. The phone remained disconnected at 20:37 UTC. Android version 4
was ready for installation at release completion; keep this checklist open for
the remaining menu/claim acceptance. See the
[deployment evidence](../verification/achievements-dev-2026-10-30.md).

## October 31 eligibility update

This source change is outside the frozen October 30 candidate. First Steps now
requires a natural end and 100 metres OR 30 seconds. The other four achievements
retain verified metrics from short runs and manual quits. Existing progress and
receipts are preserved without historical backfill.

- [x] Update settlement, per-achievement UI descriptions and GDD/TDD contracts.
- [x] Validate the updated backend and client locally.
- [ ] Include the updated Functions/client source in a newly authorized dev
      release and verify short-run, manual-quit and First Steps boundary behavior.

The revised policy is not deployed; the preceding release evidence covers the
earlier policy only.

Local validation on October 31, against the eligibility implementation and tests
in this change, from the repository root:

- `corepack pnpm --dir functions build` and
  `corepack pnpm --dir functions build:test`: passed.
- `corepack pnpm --dir functions exec firebase emulators:exec --config ../firebase.test.json --project demo-rpg-runner-functions-tests --only firestore "node --test lib_test/test/ownership/achievements.test.js lib_test/test/runs/run_projection.test.js"`:
  85 tests passed against the local demo Firestore emulator, including boundary,
  short-run/manual-quit and concurrent settlement checks across all three modes.
- `dart analyze lib/ui/pages/achievements test/ui/pages/meta/achievements_page_test.dart`:
  no issues.
- `flutter test test/ui/pages/meta/achievements_page_test.dart`: 7 tests passed,
  including both eligibility descriptions and compact/enlarged-text layouts.

The initial sandbox Firebase launch failed on user-configuration access, and the
Flutter launch stalled; successful checks used approved local tooling access.
No live backend, deployment or device acceptance was performed for this policy.
