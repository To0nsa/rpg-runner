# Game compatibility `2026.09.2` production verification

Date: 2026-09-20 (Europe/Helsinki)

## Release scope

- Release source head: `f0dc9f76` (`Upgrade Flutter dependencies and Android build stack`)
- Deterministic collision compatibility: `c177cdb1`
- Difficulty-paced camera compatibility: `ee69d480`
- Editor obstacle-to-decoration conversion: `36dd12fe`
- Initial-world run UI readiness gate: `4dfb3bb1`
- Forest woodcamp authored and generated content: `bea6982e`
- Flutter dependency and Android build-stack upgrade: `f0dc9f76`
- Flutter client default compatibility: `2026.09.2`
- Firebase Functions current compatibility: `2026.09.2`
- Replay validator accepted compatibility: `2026.09.2`

The release changes deterministic terrain contact and difficulty-paced camera
outcomes. Client, Functions authority, board manifests, generated content, and
the replay worker were therefore deployed as one compatibility cutover.

## Validation completed before deployment

- Root `dart analyze`: clean.
- Root non-integration Flutter suite: 848 tests passed.
- `packages/runner_core`: 439 tests passed.
- Replay validator: analysis clean and 134 tests passed.
- Firebase Functions: TypeScript build passed and 208 emulator tests passed.
- Editor analysis: clean. The full run completed 816 passing tests and two
  skips; its three suite-context failures passed in focused reruns after the
  stale authored-content baseline was corrected.
- Authored-content generator dry run: 35 chunks, three levels, three parallax
  themes, and three terrain materials validated with no generated drift.
- Android debug APK built successfully with Gradle 9.3.1 and Android Gradle
  Plugin 9.1.0.
- Replay validator server and protocol-rejection probe compiled and passed in
  AOT mode.
- Local strict 36,000-tick replay benchmark passed for Forest, Field, and New
  Level.
- Exact-image Cloud Run execution
  `replay-validator-phase7-benchmark-scvkt` passed at one CPU and 512 MiB.
  Forest completed in 0.952319 seconds (630.04x real time), Field in 0.549712
  seconds (1091.48x), and New Level in 0.497971 seconds (1204.89x); all three
  deterministic-outcome gates passed.

## Compatibility cutover

Both replay queues were empty and were paused before changing production
compatibility. The only non-terminal sessions were the two `2026.09.1`
Practice warmup-prefetch tickets already recorded by the prior deployment.
They had no reward grants or uploaded work. They were conditionally changed to
the terminal `cancelled` state with Firestore update-time preconditions and an
explicit `2026.09.2` cutover message. Their records were preserved. A second
inventory confirmed zero active sessions before Functions or validator traffic
changed.

## Production deployment

### Firebase Functions and Firestore

- Firestore rules and indexes deployed successfully.
- All 26 Gen 2 Functions deployed successfully; zero deployments errored or
  aborted.
- `runSessionCreate` state: `ACTIVE`.
- `runSessionCreate` revision: `runsessioncreate-00018-bey`.
- Function update time: `2026-09-19T22:00:38.837247874Z`.
- The validator-only settlement endpoint and both Eventarc target services are
  private and retain only their intended service-account invokers.

### Replay validator

- Cloud Build: `b0098d64-75fa-484a-8087-da2ffc725038`.
- Immutable image digest:
  `sha256:816c22f6b26d6656280e801165eb0bb8db71ee0e77deae8bf76b5c2301f31c69`.
- Cloud Run revision: `replay-validator-00039-xdg`.
- Readiness: Ready; `/live` and `/ready` both returned HTTP 200 through an
  authenticated operator probe.
- Traffic: 100%.
- The `production` image tag points to the same immutable digest.
- Checked-in Cloud Run, queue-routing, IAM, and retention policies were applied
  successfully.

### Queues and boards

- `replay-validation`: `RUNNING`, empty, routed to `/tasks/validate` on the
  deployed validator.
- `replay-projection`: `RUNNING`, empty, routed to `/tasks/project` on the
  deployed validator.
- Board maintenance provisioned all six expected current/next
  `2026.09.2`/`rules-v2` manifests: Field and Forest competitive boards for
  September/October plus Field weekly boards for weeks 38/39.

### Web client

- Firebase Hosting version: `c996b098ff84bd04`.
- Live release: `1789855459598000`.
- Hosting URL: `https://rpg-runner-d7add.web.app`.
- Live `main.dart.js` SHA-256:
  `09BA9D22F17D5E5B74C07A3B5A0FD61DF74E34019AD9BDD2419A130A5EC83D93`.
- The fetched live bundle byte-matched the local release build and contains
  `2026.09.2`.

## Final production inventory

Observed at `2026-09-19T22:06:48.332Z`:

- 61 retained run sessions: 42 validated, 17 expired, and two cancelled; zero
  active sessions remain.
- All 42 validated runs were accepted; none were rejected.
- All 42 reward grants were `validated_settled`; there were no stale pending or
  quarantined settlements.
- All six expected `2026.09.2` current/next board manifests exist.
- Profile, display-name, ownership, board, run, deletion, projection-source,
  and identity checks reported no current invariant violations.
- Both replay queues were `RUNNING` and empty after resumption.
- Cloud Run logged zero severity-Error entries between cutover and the final
  verification.

## Distribution boundary

The production backend, replay worker, and Firebase Hosting client were
deployed and verified. The Android debug APK built successfully with SHA-256
`8F5EB55ABDD57352B3539860B4E0FAE2F58F3065591A780905B76D450550F6D5`,
but device `8ce90820` was disconnected during deployment, so it could not be
installed as a connected-device canary. No Google Play track upload was
performed; this repository has no configured Play release workflow.
