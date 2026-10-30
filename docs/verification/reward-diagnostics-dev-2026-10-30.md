# Reward timing diagnostics — dev rollout, October 30, 2026

Scope is dev only: `rpg-runner-d7add`, `europe-west1`, Android package
`com.example.rpg_runner.dev`. The owner authorized implementation and the
necessary deployment, then explicitly reconfirmed dev-only scope. Staging and
production are excluded.

## Candidate and validation

Diagnostic APK source: `1d4799e7866ab3f1ca7cb2dd8be13a8929dbe47b`; source digest
`46cd44f99fba6f46b80a0cc3f6378bd9f395c77ccdb9a6d3eaa4b2add2dd1b47`.
The subsequent Hall of Honour changes are outside this candidate.
The gameplay tuple remains `2026.10.21 / rules-v2 / score-v4 / ghost-v1`.

Canonical Prepare completed at 17:33 UTC. Source-bound evidence resides in
`.tmp/release-checkouts/<source-commit>/.tmp/releases/rpg-runner-d7add/<source-digest>/`.
All 1,363 client tests and client/test/driver analysis passed, along with the
release web build and built-artifact browser smoke. Functions build and all 282
emulator tests passed; validator analysis, 301 service tests, final 97 worker
tests and executable compilation passed. Unchanged components reused verified
cache evidence. These checks do not establish live phone latency.

The navigation reuse follow-up is frozen at
`b58ac324dda44c86aa844fe6636f08486de8cae6`, source digest
`14388b2491269fe4e76795c068d252256da87c1ead3be0fd4211bd20504f9b3e`.
The identical patch is committed on the shared branch as `427e811a`; the frozen
candidate excludes concurrent achievement work. Its Prepare completed at 18:30
UTC, reusing nine unchanged component records. The changed worker component
passed analysis, 301 service tests and executable compilation in 89 seconds.

From `.tmp/worktrees/reward-navigation-reuse`, both PowerShell 5.1.26100.9818 and
7.6.9 passed `tools/release/test_release.ps1` (61 checks),
`test_release_integration.ps1` (103 dev checks), `test_release_cache.ps1`
(56 checks), `test_release_image.ps1` (22 checks), and
`test_release_environments.ps1` (29 checks). The integration script also passed
98 checks for each mocked staging/prod environment. All use fixtures; they made
no cloud changes. `node tools/agents/check.mjs`, diff checks and changed-doc
relative links passed. Guidance also fits the root byte limit with CRLF endings.

## Android installation

Canonical BuildAndroid completed at 17:49 UTC for dev version code 3,
`1.0.0-dev`, using Flutter 3.47.1's recorded revision and Dart 3.13.1.
The artifact inspection verified dev Firebase/Play Games resources, signing,
three ABIs, 16-KiB alignment for ELF64 libraries and 3,750 navigation graphs.

APK: `android/dev/3/app-dev-release.apk` inside the evidence directory above.
SHA-256: `368c6a01540f1c7d05c2110463053af664b07fd2ffde92216b0727ae66ca2610`.
Size: 184,143,278 bytes. Certificate SHA-256:
`001f8fe8d465d47b2aa1264fd8a00ac2221875aeef17ce1bfad5d1bf6d91f061`.

Installed with `adb install -r` on the reconnected OnePlus CPH2465, preserving
app data. Android reported version code 3; on-device `sha256sum` matched the
artifact. The app opened to the hub with 3,149 gold and level 2, 32/124 XP,
matching the [pre-instrumentation baseline](reward-latency-phone-2026-10-30.md).
The game-only screenshot is
`.tmp/reward-latency-instrumented-20261030/installed-hub.png`.
This startup check is not an instrumented reward-completion run.
At 18:39 UTC, `adb devices` reported no connected device; the next live capture
requires reconnection.

The follow-up candidate's `android-reuse.json` retains the original APK source
and proves matching Android component inputs
(`d5a86d5b0957a26f30f43a5647e89d5e54beefd8146fdee956ec0945dd019ee6`),
Flutter/Java toolchain, dev package/environment and APK digest. The original
signing/native-inspection evidence remains applicable. No repeat APK build is
needed for the release-only changes.

## Backend and outstanding evidence

Cloud Build `293d71e1-ee58-4d24-a2cf-b405514277db` started at 17:34 UTC and was
confirmed `CANCELLED` at 18:00 UTC. The owner requested reuse of unchanged
navigation graphs; the Docker recipe had provided the incremental producer an
empty directory. The follow-up implements automatic seeding from the previous
verified dev image. A live read-only selector check verified dev Cloud Build
`933b4257-cfd1-4052-bb21-15615f062a85` and immutable image
`sha256:9c81113febe223d1e399d12bdaa8253131e71a1df901611852d47b00b42edd80`.
Replacement Cloud Build `f1413136-2e1b-4359-8619-dc3800608b22` started at 18:31
UTC with that verified navigation seed. Producer logs confirm 93,910 graphs
reused and zero built across 38 routes (128 chunks), in 129.215 seconds.
The build completed successfully at 18:40 UTC with immutable image digest
`sha256:45d6d0a00fe563464c9ca9ab89748bad7befad18ee8f53d073013a8fbf23908e`.
The exact final-image benchmark (`--cpus=1 --memory=512m`, 36,000 ticks per level,
strict mode) passed all eight gates: Forest 2.148317 seconds, Field 1.992179
seconds, deterministic outcomes and sustained forward progress. This is a
generated-terrain fixture without combat objectives, not live reward latency.
Canonical `ImageStatus -Environment dev` verified SUCCESS, benchmark evidence
and the immutable image identity, and recorded `imageVerified: true` in the
frozen candidate's release manifest.
No backend cutover has occurred. Issuance remains enabled.

Read-only Inspect at 17:37 UTC found nine accepted/settled runs, three issued
tickets, no pending/quarantined settlement, and no identity/evidence mismatch.
The latest read-only ticket review at 18:32 UTC found five issued tickets: the
same three plus two created at 17:38 and 17:51 UTC. All five have no uploaded
replay, upload/validation lease, accepted run or reward grant; the expected replay
objects returned 404. Their exact IDs and document timestamps are retained in
`.tmp/reward-issued-review.json`. This does not establish whether an offline run
exists on a device. Cancelling these tickets prevents later submission and requires
separate owner authorization under the release workflow. Approval was requested
after final-image verification and is pending; none has been given.
The guarded cancellation helper has only been syntax-checked, not executed.
Canonical Inspect at 18:36 UTC confirmed 21 sessions (five issued, nine validated,
six cancelled, one expired), nine settled grants, 3,149 canonical gold and no
pending/quarantined settlement or run identity/evidence mismatch.

After the guarded dev cutover, capture a new live run before claiming that all
stage events correlate correctly. A finite app-scoped logcat helper is prepared
under `.tmp/reward-latency-instrumented-20261030/`. A bounded client-only capture
started at 17:54 UTC while the previous backend was live, then stopped without
a run-end timing event after the owner redirected work to graph reuse. It avoided
continuous screenshots and recorded process changes; missing events and
cross-process clock differences must remain explicit. See the
[timing contract](../tdd/reward_settlement_operations.md#per-run-timing-diagnostics)
and [active checklist](../building/reward_verification_latency.md).
