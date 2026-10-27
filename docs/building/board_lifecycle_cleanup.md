# Board lifecycle and account deletion

Owner request, October 27, 2026: remove obsolete pre-release board data in dev,
keep the serving release's current windows, and prevent board growth from
making account erasure take hours. Unrelated Android signing, release guidance,
and privacy-policy edits in the working tree must be preserved.

Acceptance:

- [x] Scheduled erasure performs bounded, checkpointed batches with fair request
  selection, time/step limits, and no spinning on quiet periods or live leases.
- [x] Board provisioning defaults to current windows only.
- [x] Board maintenance retires obsolete partitions and removes their nested
  projections without touching active run sessions or canonical rewards.
- [x] Projection transactions cannot recreate retired/missing boards' children.
- [x] Emulator/worker regressions cover realistic board counts and retries.
- [x] Authorized dev cleanup keeps the three current `2026.10.21` boards;
  inventory, removals, remaining boards and deletion progress are verified live.
- [x] Deployment status and remaining release gates are explicit.
- [ ] Coordinated dev rollout, alert-policy update and board-maintenance resume.

The serving project is `rpg-runner-d7add` (dev). Initial read-only inventory:
184 boards across 22 gameplay versions; 107 past, 44 current, 33 future. One
account deletion was on final reconciliation with no retryable failures.
No application deployment is claimed by this checklist.

## Validation and live checkpoint

- Targeted Functions emulator checks: 27 passed, including 184-extra-board
  erasure, per-stage failure replay, lease serialization, retirement and grace.
- Worker: `dart analyze` passed; `dart test test` passed all 298 tests.
- Read-only dev preview: 181 removal candidates; exactly three current
  `2026.10.21` boards protected. Projection queue had zero pending tasks.
- Dev board-maintenance scheduler and projection queue were temporarily paused
  for authorized cleanup. The queue was restored; the legacy board provisioner
  remains paused until current-window provisioning is deployed. Current windows
  still provision on demand.
- Runtime changes and alert policy have not been deployed.

Live cleanup completed October 27, 2026 around 15:51 UTC: 181 board parents and
160 nested leaderboard documents deleted; zero ghost objects existed under the
removed board prefixes. Three current `2026.10.21` board parents remain, all
active. Projection queue restored to RUNNING. The legacy board provisioner is
still PAUSED until deployment of current-window provisioning. No run sessions,
canonical accepted runs, grants or ownership documents were targeted.

Final local verification from the repository root: `corepack pnpm --dir
functions build` and `build:test` passed; `corepack pnpm --dir functions test`
passed all 266 tests. Worker verification from `services/replay_validator`:
`dart analyze`, `dart test test` (298 tests), and `dart compile exe bin/server.dart
-o ../../.tmp/board_lifecycle_replay_validator.exe` all passed. Runtime source
was unchanged after these checks; later edits were tooling/documentation only.
The final transactional parent/child deletion guard additionally passed all 11
board provisioning/retention tests before live use.

Root-checkout release Plan reported a simulation digest mismatch with the live
baseline despite no simulation source differences from deployed `a4f99b89`.
Canonical clean LF checkout of `5b1f9092` resolved the mismatch: Plan passes
with Coordinated scope under the unchanged `2026.10.21` tuple. No gameplay
version bump or gate bypass was needed.

The original account deletion completed at `2026-10-27T15:54:06.030Z`. The
15:56 UTC repair heartbeat reports zero scanned/active/retryable work and one
minimal completed record. The cleanup mutation-lock inventory is empty.

Frozen source: `5b1f9092e76333c84e065cf3fa37699ce882b7b7` under
`.tmp/release-checkouts/5b1f9092e76333c84e065cf3fa37699ce882b7b7`.
Release input digest:
`a8fe60187d3039cf8eccbc4175b08a4ecf735a64c21b82209e82826848d04112`.
Local canonical Prepare is running. Cloud Build/image benchmarking, coordinated
cutover, alert-policy update and resuming board maintenance remain explicit
release steps; no application deployment is claimed.

First canonical Prepare: Functions (266 tests), worker (298 tests plus AOT
probe), and client analysis/tests passed. Flutter reported 1,348 passes and one
skip; the JSON reporter also includes successful loading/setup events. Prepare
then correctly refused to publish client evidence because the job fingerprint
differed from its parent. No tracked input bytes differed from the frozen index.

The reproducible cause was Windows PowerShell job encoding: the parent used
UTF-8, the job used code page 850, and Git's UTF-8 `assets/Theodonis.jpg` filename
(the actual tracked spelling contains an accented e) was omitted by the job's
path-existence filter. Parent client digest was
`c7f6ce8e1e818c42b96b0b8c15f3cd0b8e8c78c1dd1f0a8b0f116737bbe5bcf2`;
default-job digest was
`7494c6148089421d448f839f44f5646186bb4a60bc72ae057c19d103facd8858`.
Pinning `[Console]::OutputEncoding` to UTF-8 inside the job reproduced the parent
digest and included the asset. No source guard was disabled or failing evidence
cached. Prepare was rerun with:

```powershell
$PSDefaultParameterValues['Start-Job:InitializationScript'] = {
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}
.\tools\release\release.ps1 -Environment dev -Action Prepare
```

Eight unchanged component results are reused; client checks/build rerun under
the corrected execution environment. This Windows job-encoding requirement is
an operational limitation until the release helper explicitly pins native
output decoding. The prepared snapshot also includes the branch's earlier
Android/environment changes; review the full live-baseline diff before rollout.

The second Prepare also passed all client tests but failed the same source guard:
job initialization alone did not reliably pin decoding through SDK execution.
The permanent fix now scopes UTF-8 decoding around every `Invoke-ReleaseCommand`
call and restores the caller's encoding in `finally`. A real-Git regression
forces code page 850 in parent/job processes, verifies the accented asset is
included with identical digests, checks asset edits invalidate the digest, and
checks encoding restoration after successful and failed commands. It passes on
PowerShell 7 and Windows PowerShell 5 and is wired into the existing cache suite.
Required `test_release.ps1` and `test_release_integration.ps1` passed on both
shells. The final `test_release_cache.ps1` passes all 54 checks on each shell,
including the real-Git regression. No SDK/cloud commands are executed by those
mocked suites; the Unicode fixture uses only local Git and PowerShell.
The source-change guard remains intact; no failed preparation is marked ready.

Handoff: runtime fix is committed as `5b1f9092`; the native-command encoding fix
and this verification update form the next independently validated milestone.
Canonical Prepare must be rerun for the updated recipe, followed by web artifact
smoke, exact-image Cloud Build benchmark, coordinated dev deployment, monitoring
policy update and resuming the paused board-maintenance scheduler. No application
deployment, image upload/build or issuance cutover was performed. The current
branch also contains earlier Android/environment work, so approve the concrete
snapshot scope before that broader release. The live incident itself is resolved:
three current boards remain and the account deletion is complete.
