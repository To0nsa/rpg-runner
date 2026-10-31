# Reward pipeline dev rollout, October 31, 2026

Status: deployed to dev; issuance resumed and live configuration verified.
The user authorized dev deployment, followed by phone installation and
measurement. The verified dev APK is ready; phone installation and measurement
have not started.

## Candidate and scope

- Dev project `rpg-runner-d7add`, region `europe-west1`; no staging/prod action.
- Candidate `259786236b61a867c9edccbe1d74679c20c2459a`, isolated LF checkout at
  `.tmp/release-checkouts/259786236b61a867c9edccbe1d74679c20c2459a/`.
- Source digest `64a27017431e8f8456c236e6ef2eba8f30f719c283cd27a36639470275137c8f`.
- Coordinated scope; unchanged simulation inputs and tuple
  `2026.10.21 / rules-v2 / score-v4 / ghost-v1`.
- Pipeline implementation is described in the
  [implementation evidence](reward-pipeline-rework-2026-10-31.md) and
  [workstream checklist](../building/reward_verification_latency.md).

The first candidate `2d8ddb9d` stopped during the fresh production audit before
cloud mutation. New moderate glob/minimatch advisories required the narrow
runtime override committed in `25978623`. Both pnpm and isolated production npm
audits passed, Functions compiled, and Node 24 synchronous/asynchronous rimraf
glob probes passed under both installed dependency layouts. The isolated npm
installation is outside the pnpm workspace; its location and logs are retained
in `.tmp/pipeline-deploy-20261031/`. See the override rationale in the
[deployment contract](../tdd/deployment_workflow.md).

## Preparation evidence

Canonical commands run from the frozen checkout:
`tools/release/release.ps1 -Environment dev -Action Prepare` and `-Action Inspect`.
Source-bound output is under that checkout's
`.tmp/releases/rpg-runner-d7add/64a27017431e8f8456c236e6ef2eba8f30f719c283cd27a36639470275137c8f/`.

- Fresh production dependency audit: passed.
- Backend emulator suite: 312 passed; production build/inventory tests passed.
- Worker analysis, 304 tests and compiled AOT protocol probe: passed.
- Client analysis and full native suite: 1,412 passed, one skipped. The skipped
  case is the existing fresh-install Developer Practice launch-flag widget test;
  it does not establish target-phone acceptance.
- Release web build and browser smoke: passed, including local run start/game
  over without browser exceptions or backend requests.
- Core: 2,290 tests; protocol: 133; content pipeline: 99; terrain materials: 25;
  all passed with clean analysis. Navigation/generated-content freshness passed.
- Final source/artifact verification completed at 15:25:41 UTC; `prepared=true`.

The current client pack was verified and seeded before preparation, matching
the manifest from verified dev APK 4 source `8a094efb`. The web-build producer
pass reused 3,750 graphs and built zero. Manifest SHA-256:
`6f65c41f501cc9618ecefd8ae3349d037656aacb567935ab81268f8639a812bd`.
The previous dev worker image's successful Cloud Build
`f1413136-2e1b-4359-8619-dc3800608b22` and exact-image benchmark were checked live;
its immutable digest is
`sha256:45d6d0a00fe563464c9ca9ab89748bad7befad18ee8f53d073013a8fbf23908e`.
BuildImage selected that verified navigation seed for Cloud Build
`7df8cfb5-08bd-4988-8671-366e623f9955`, started at 15:27:46 UTC and completed
successfully at 15:36:02 UTC. The worker producer reused all 93,910 graphs and
built zero. All eight exact-image benchmark gates passed (36,000 ticks per
level; Forest 2.111 seconds, Field 1.885 seconds). This limited generated-terrain
fixture does not measure phone latency or full combat. ImageStatus verified:
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:549581d0ca927054c1c9f39544876c80d127dd1bd8654fb4d769f2d1fe7051a1`.

BuildAndroid verified dev APK version 5 at 15:38:37 UTC. Its initial start was
safely rejected while BuildImage held the environment lock, and was retried only
after that lock was released. No lock was removed
manually and no staging/prod artifact was built.

- Artifact: source-bound `android/dev/5/app-dev-release.apk`, 185,404,456 bytes.
- SHA-256: `2b8398299f706db3ba1f976da458e8ee7d84e722bc8e75091914b05e661ee10a`.
- Package `com.example.rpg_runner.dev`, version `1.0.0-dev` / 5; dev Firebase and
  Play Games resource identities verified.
- Signing certificate SHA-256:
  `001f8fe8d465d47b2aa1264fd8a00ac2221875aeef17ce1bfad5d1bf6d91f061`.
- Packaged navigation: 3,750 graphs, matching the verified manifest above;
  Android producer reused all graphs and built zero.
- Three ABIs, nine native libraries, 16-KiB ELF64 page alignment verified.
- Build passed with existing Firebase-plugin Kotlin migration warnings;
  Crashlytics symbols were not uploaded for this dev artifact.

## Live inventory and cancellation boundary

Read-only inspection at 15:08 UTC found 32 ACTIVE Functions, the previous worker
revision `replay-validator-00063-thr` serving all traffic, and both replay queues
RUNNING. The session inventory contains 11 validated, 11 cancelled, one expired
and one issued run. All 11 grants are `validated_settled`; there are no missing
expected current boards, run-identity mismatches, pending settlement or active
account deletions.

Ticket `run_fcde7ddd37a589268c6fa72b107e76c1581691b1` was issued at
08:26:22.903 UTC on October 31 and expires at the same time on November 1. Its
review found no upload/validation lease, uploaded object, validated run or reward
grant. This does not prove that a device has no unsubmitted offline run.

The owner explicitly authorized cancelling this one ticket and finishing dev
deployment, acknowledging that any offline run using it becomes invalid while
existing gold and XP remain unchanged. The prepared helper is bounded to that
exact ID, requires a healthy paused issuer and matching source/cutover lock,
rechecks absent replay/reward evidence, and uses a Firestore transaction with
document update-time preconditions. It also compares hashes of all protected
session, grant, validation and account documents.

PauseIssuance completed at 15:41:19 UTC on healthy serving revision
`runsessioncreate-00087-4wn`. Both replay queues remained running while the fresh
review confirmed exactly the approved unsubmitted ticket. The bounded
transaction cancelled it at 15:43:40.771 UTC. Subsequent verification found all
sessions terminal, no unexpected ticket-field changes, and unchanged hashes for
every protected session, reward grant, validated run, ownership profile and
player profile. No gold or XP was changed. Review/result/verification JSON files
are retained in `.tmp/pipeline-deploy-20261031/`.

## Deployment and recovery

### Recovered first-deployment CLI failure

The first Deploy created all 35 ACTIVE Functions, but Firebase CLI 15.28.1
failed during the new task queue's enqueue-IAM step with
`Cannot read properties of undefined (reading 'filter')`. Live readback and the
installed CLI's `lib/gcp/cloudtasks.js:setEnqueuer` identified the cause: a newly
created queue returned `{etag: "ACAB"}` without `bindings`, and the CLI called
`existing.bindings.filter`. The handler already had the intended private Run
invoker; the queue existed with its expected retry/rate policy. This was not
evidence of missing operator privileges.

The release retained paused issuance, paused gameplay queues and its cutover
record. Under the normal environment mutation lock, the bounded recovery added
only `roles/cloudtasks.enqueuer` for
`sa-run-control@rpg-runner-d7add.iam.gserviceaccount.com` on `runPendingWork`.
This is the binding already required by Confirm-ReleaseBackend; no project-wide
grant or public invocation was added. Readback verified exactly that binding,
and canonical Deploy was retried with the unchanged prepared candidate. The
first local recovery attempt stopped before mutation because PowerShell strict
mode rejected the absent property; its property-existence guard was corrected
before the successful repair. Logs and before/applied/verified policy JSON are
retained in `.tmp/pipeline-deploy-20261031/`.

Canonical Deploy then succeeded with the existing artifacts. Functions/rules/
indexes completed at 15:59:25 UTC; the worker checkpoint at 16:03:53 UTC; Hosting
and Deploy completed at 16:04:27 UTC. Worker revision
`replay-validator-00064-nxw` serves 100% of traffic from the verified image.
Private IAM readback at 16:01:30 UTC verified immediate settlement, all three
event handlers, pending work and replay validation have only their intended
service-account invokers, plus queue-scoped enqueue and control-account
self-`actAs`. The subsequent worker update retained its private dispatch binding.

The post-update protected-data verification also passed. Fresh inventory at
16:05:04 UTC found 24 terminal sessions (11 validated, 12 cancelled, one expired),
11 accepted validated runs, 11 `validated_settled` grants, no identity/projection
source mismatches, no pending/quarantined settlement and no active deletion.
All three expected current boards were active; none were missing.

### Final live readback

ResumeIssuance completed at 16:08:50 UTC. The canonical baseline was verified at
16:09:03 UTC, the cutover record cleared and the mutation lock released. Final
readback completed at 16:10:10 UTC:

- All 35 Functions ACTIVE, including all three additive handlers. Settlement,
  projection and deletion Eventarc handlers retain retry enabled.
- Worker `replay-validator-00064-nxw` Ready, serving the exact verified image at
  100% traffic, with `SETTLEMENT_DELIVERY_MODE=eventarc`, automatic scaling and
  CPU throttling/request-based billing.
- All 36 Cloud Run services have effective zero service/revision minimums and
  no instance-based billing override; Functions have no reserved instances.
  Cloud APIs omit zero/default minimum fields. This verifies configuration,
  not a claim of zero storage, scheduled-work or usage charges.
- Issuer `runsessioncreate-00089-bcl` Ready at 100% traffic, with the temporary
  supported-version override absent.
- `replay-validation`, `replay-projection` and `runPendingWork` RUNNING.
  Pending work is limited to five concurrent/five per-second dispatches,
  1,000 attempts over at most one day, with 30–60-second backoff.
- Validation, settlement and deletion safety schedules ENABLED every 60 minutes.
- All 12 composite indexes READY; all three expected boards ready.
- Post-resume inventory at 16:09:41 UTC retained the same 24 terminal sessions,
  11 accepted runs and 11 settled grants, with zero identity mismatches, pending
  settlement, missing boards or active deletions.
- Live Hosting JavaScript matched SHA-256
  `2aa47286cb96b71da4f5a107c5c742701fc7fe06459e1c50ace321f2ec79b2c3`.
  Functions live identity:
  `b33562469e51e9a494643637aecc73937311708a4177471fa6bad55a8850bb0f`.

Commands were the canonical dev-only Prepare, Inspect, BuildImage, ImageStatus,
BuildAndroid (version 5), PauseIssuance, Deploy and ResumeIssuance from the frozen
checkout, plus the bounded approved cancellation and documented IAM recovery.
Read-only inventory and gcloud checks are saved in the source-bound release
directory and `.tmp/pipeline-deploy-20261031/`, including
`live-runtime-verified.json`, `live-access-verified.json` and
`post-resume-inventory.json`. The frozen source was not edited during cutover.

## Remaining phone checks

The verified dev release APK is ready for the later installation. Reused finite
capture/report helpers are prepared in `.tmp/reward-pipeline-phone-20261031/`;
capture is not running. Installation, linked Play Games/replay smoke and new
cold/warm phone timings remain separate live checks. The
[earlier phone measurement](reward-latency-phone-2026-10-31.md) is the pre-change
baseline and does not establish the new pipeline's latency.
