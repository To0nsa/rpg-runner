# Game compatibility `2026.09.3` production verification

Date: 2026-09-20 (Europe/Helsinki)

## Release scope

- Source commit: `93961fef` (`Add ground-enemy swimming and version water gameplay`).
- Player swimming target speed is 80% of land speed.
- Grojib and Hashash gain water pursuit, buoyancy, strokes, and bank exits.
- Client, Functions compatibility authority, boards, and replay validator use
  `2026.09.3`; replay encoding and the ranked rules/score/ghost tuple are unchanged.
- All artifacts were built from an isolated archive of that commit. Uncommitted
  level, animation, debug, and editor changes were not deployed.

## Validation

- Implementation checks: clean analysis; 454 Core, 137 validator, 381 selected
  Flutter, and 208 backend emulator tests passed; Functions build passed.
- Isolated release checks: all 454 Core and 137 validator tests passed again,
  Functions compiled, the AOT protocol-rejection probe passed, and the Flutter
  web release built successfully.
- Cloud Build `4459944e-8332-41d9-b5d1-53ebc416e560` succeeded.
- Exact-image Cloud Run execution `replay-validator-phase7-benchmark-2bpv4`
  passed at one CPU and 512 MiB. The strict 36,000-tick benchmark passed all
  throughput and deterministic-outcome gates: Forest 0.788344 seconds, Field
  0.421860 seconds, New Level 0.416516 seconds. This benchmark uses the normal
  no-enemy stream; enemy-water replay parity is covered by the validator tests.

## Owner-authorized immediate cutover

The preflight inventory found one non-terminal `2026.09.2` Practice session in
`uploading`, with ticket expiry `2026-09-21T08:16:24.565Z`. It had no finalized
replay, validation lease, reward grant, or validated-run record. The owner
explicitly approved cancelling this unfinished upload and an immediate cutover
instead of the normal drain period. This was a release-specific exception;
the normal 24-hour compatibility-retirement interval was not claimed as passed.

New issuance was temporarily blocked by removing public invocation from
`runsessioncreate`; both replay queues were paused. At
`2026-09-20T14:48:18.684959Z`, the identified session was conditionally changed
to `cancelled` with its Firestore update-time precondition, terminal timestamp,
and an explicit cutover message. Its record was preserved; no reward or wallet
was changed and no artifact was deleted. A subsequent complete inventory found
zero active sessions before the validator switched.

## Deployed services

### Replay validator

- Immutable image digest:
  `sha256:0d05f27fc7ab8be897cf36f29a09cf8c90edc65cf8a720c7cfc13b1cdd7d9df5`.
- Cloud Run revision: `replay-validator-00040-lp7`, Ready, 100% traffic.
- Authenticated `/live` and `/ready` probes returned HTTP 200.
- The `production` registry tag resolves to the deployed digest.
- Checked-in Cloud Run, queue-routing, service-account IAM, and retention
  policies were applied successfully.

### Firebase Functions and boards

- All 26 Gen 2 Functions updated successfully, with zero deployment errors.
- `runSessionCreate`: `ACTIVE`, revision `runsessioncreate-00019-mad`, updated
  `2026-09-20T14:55:40.337359597Z`; no stale supported-version environment override.
- Both Eventarc targets retain only the intended `sa-run-control` invoker;
  immediate settlement retains only the `sa-replay-validator` invoker.
- Board maintenance provisioned all six expected current/next `2026.09.3`
  manifests: Field/Forest competitive September/October and Field weekly
  weeks 38/39. Existing boards and results were preserved.
- Firestore rules and indexes were unchanged by this release.

### Web client

- Hosting version: `06cb48c2dd21c2d6`, live release completed at approximately
  `2026-09-20T14:59:47Z`.
- URL: <https://rpg-runner-d7add.web.app>.
- Live `main.dart.js` SHA-256:
  `D667C09AB4BF6798EE23A8C3A2BE2FC0E52145AC56953521049B5ACE12B305C8`.
- The fetched live bundle byte-matched the isolated release build and contained
  `2026.09.3`.

## Final verification and distribution boundary

Public callable access for run creation was restored and both queues were
resumed by `2026-09-20T15:00:41.519Z`. Both were confirmed `RUNNING` and empty.
An unauthenticated run-creation probe returned HTTP 401, proving the route was
reachable while player authentication remained enforced.

The final inventory at `2026-09-20T14:58:38.362Z` contained 85 retained sessions
(65 validated, 17 expired, three cancelled), zero active sessions, and 65
`validated_settled` reward grants with no stale pending settlement. All six new
boards existed. The Cloud Run severity-Error query from `14:51:00Z` through the
check at `15:01:33Z` returned zero entries.

This release deployed the production backend, replay worker, and web client.
It did not distribute an Android/iOS binary or upload to an app-store track.
Existing native installations must be rebuilt with the matching compatibility.
