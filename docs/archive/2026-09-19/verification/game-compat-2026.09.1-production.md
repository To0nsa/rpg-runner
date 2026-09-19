# Game compatibility `2026.09.1` production verification

Date: 2026-09-19

## Release scope

- Gameplay compatibility commit: `2aaf7b1e` (`Add camera fall-behind grace distance`)
- Dependency security commit: `362fed44` (`Pin patched qs dependency`)
- Flutter client default compatibility: `2026.09.1`
- Firebase Functions current compatibility: `2026.09.1`
- Replay validator accepted compatibility: `2026.09.1`

The release changes the deterministic camera fall-behind terminal boundary by
adding the authored grace distance. Because that changes replay outcomes, the
client, Functions authority, board manifests, and replay worker were advanced
together.

## Validation completed before deployment

- Root `dart analyze`: clean.
- `packages/runner_core`: 422 tests passed.
- Focused root Flutter suite (`test/core` plus run-ticket prefetch tests): 376
  tests passed from an isolated checkout of `362fed44`.
- Replay validator: analysis clean and 130 tests passed.
- Firebase Functions: TypeScript build passed and 208 emulator tests passed.
- Firebase Functions production dependency audit: no known vulnerabilities
  after pinning `qs` `6.16.0`.
- Replay validator AOT build completed.
- Local strict 36,000-tick replay benchmark passed.
- Cloud benchmark job `replay-validator-phase7-benchmark-q6snr` passed at the
  production limit of 1 CPU and 512 MiB.

## Production deployment

### Firebase Functions and Firestore

- All 26 Functions deployed successfully with Firestore rules and indexes.
- `runSessionCreate` state: `ACTIVE`.
- `runSessionCreate` revision: `runsessioncreate-00017-hij`.
- Function update time: `2026-09-19T19:46:49.507308714Z`.

### Replay validator

- Cloud Build: `db85264b-4ed6-4803-a30f-7b70538462db`.
- Immutable image digest:
  `sha256:eee8ec85feb504915c8712980f77bfb780aa920fd56d33fce54f41ef5bb18145`.
- Cloud Run revision: `replay-validator-00038-66m`.
- Readiness: Ready.
- Traffic: 100%.
- The `production` image tag points to the same immutable digest.

### Queues and boards

- `replay-validation`: `RUNNING`, empty, routed to `/tasks/validate` on the
  deployed validator.
- `replay-projection`: `RUNNING`, empty, routed to `/tasks/project` on the
  deployed validator.
- Board maintenance provisioned all six expected current/next
  `2026.09.1`/`rules-v2` board manifests; none are missing.

### Web client

- Firebase Hosting version: `4a9df9bb1150d00c`.
- Live release: `1789849292477000`.
- Hosting URL: `https://rpg-runner-d7add.web.app`.
- The fetched live `main.dart.js` hash exactly matched the isolated release
  build and contains `2026.09.1`.

### Android device canary

- Device: Oppo CPH2465 (`8ce90820`).
- APK source: isolated checkout of `362fed44`; concurrent editor/content work
  was excluded.
- APK SHA-256:
  `B50B970D6CAC97EC2FE85FCDCDFFAC6B6F9C3C2D7AE5C5529D8EBE5E2333F299`.
- Install and Firebase initialization succeeded.
- A real Forest Practice run reached the run screen, played for 14 seconds,
  ended at 49 m with score 465, uploaded its replay, and entered reward
  verification.
- The device's App Check debug token was registered with the display name
  `Oppo CPH2465 - 2026.09.1 debug - 2026-09-19`. A clean restart then produced
  no App Check, compatibility, Flutter runtime, or fatal errors.

## Final production inventory

Observed at `2026-09-19T20:26:16.581Z`:

- Six `2026.09.1` sessions existed: four validated and two issued warmup
  prefetch tickets.
- All 37 validated runs were accepted; none were rejected.
- All 37 reward grants were `validated_settled`; there were no stale pending or
  quarantined settlements.
- Wallet gold was 309 after the canary flow.
- Profile, display-name, ownership, board, run, and deletion consistency checks
  reported no identity or invariant violations.

## Cutover and data-retention decision

The queues were paused during the deployment. Before cutover, all 50 legacy run
sessions were terminal and both queues were empty. A proposed destructive reset
was not executed because the Firestore records have no practical rollback.
Instead, the release used a non-destructive compatibility cutover:

- legacy `2026.03.0` and `2026.08.0` terminal history remains intact and inert;
- fresh `2026.09.1` boards were provisioned;
- no replay bucket objects or player progression were deleted;
- Auth identities, profiles, display-name claims, maintenance records, and
  account-deletion tombstones were preserved.

This avoids a migration while preserving player and compliance history. The two
issued `2026.09.1` warmup tickets are expected client-prefetch state and expire
normally if unused.

## Distribution boundary

The production backend, replay worker, Firebase Hosting client, and connected
Android debug device were deployed and verified. No Google Play track upload was
performed as part of this release.
