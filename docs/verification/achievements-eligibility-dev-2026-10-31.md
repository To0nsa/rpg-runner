# Achievement eligibility dev release, October 31, 2026

Status: canonical preparation and worker-image verification passed.
Cutover awaits a decision on two additional unfinished tickets. No cancellation
or deployment has been performed.
The owner authorized dev deployment ("ok deploy") and then explicitly approved
cancelling only the three reviewed unfinished tickets below and deploying.

## Candidate and scope

- Dev project `rpg-runner-d7add`, region `europe-west1`.
- Frozen candidate `8750344dbf992957c9346be70fadfb504282fcd9` in
  `.tmp/release-checkouts/8750344dbf992957c9346be70fadfb504282fcd9/`.
- Source digest `456dae902d5834d3d3d8d9ef011308544ddcd0b18339e7373d5e259fb3159a41`.
- Replaces `08afcc49f5a0feba2fd7fc2e96661c34eb86735c` (digest
  `03cce26103ff6eb2b9828998fd350c77d74c5c09abe9113a4b1de2c8f57b626e`)
  before any cloud mutation, adding only two validated test-file corrections.
- Coordinated scope; unchanged
  `2026.10.21 / rules-v2 / score-v4 / ghost-v1` tuple.
- First Steps requires a natural end and 100 metres OR 30 seconds. Other
  achievements retain all verified distance, survival time and kills, including
  short runs and manual quits. Existing progress and receipts are preserved.
- The client also includes the already committed reward-display and menu changes
  since the preceding `25978623` deployment. Simulation, protocol and worker
  source are unchanged.

The canonical LF checkout passes Plan. The initial main-worktree Plan rejected
CRLF source-byte differences; no compatibility version or source was changed to
bypass that check.

## Preparation

Canonical Prepare runs in the frozen checkout. Source-bound logs and state are
under its `.tmp/releases/rpg-runner-d7add/<source-digest>/` directory.
Commands from that checkout were
`tools/release/release.ps1 -Environment dev -Action Prepare`,
`tools/release/release.ps1 -Environment dev -Action Inspect` and
`tools/release/release.ps1 -Environment dev -Action BuildImage`.
The unchanged-artifact smoke retry used
`node tools/release/web_smoke.mjs build/web`.

- Fresh production dependency audit: no known vulnerabilities.
- Functions emulator suite: 340 passed. Production build and four inventory
  tests passed.
- Client `lib`, `test` and `test_driver` analysis: no issues. The first full
  client run exposed two Town layout failures caused by a test double missing
  `displayedGold`, and an auth test still expecting the old cross-account stale
  revision rejection. Production behavior resets ownership revision on account
  change, allowing the new account's first write. Test fixes preserve the Town
  layout checks and verify independent revisions/loadouts for both accounts;
  explicit stale-revision recovery remains covered separately. The replacement
  candidate reran the complete client gate.
- The first client suite finished with 1,423 passed, one skipped and exactly
  those three failures. Focused corrections in `.tmp/achievements-test-fixes`
  passed 28 tests across `codex_library_test.dart`,
  `app_state_firebase_auth_integration_test.dart` and
  `app_state_ownership_conflict_test.dart`; analysis of both edited test files
  reported no issues. No production implementation changes were needed.
- Replacement candidate `8750344d`: all three analysis targets passed; the full
  client suite passed 1,426 tests, with one skipped and zero errors (987.9 seconds
  in the Flutter JSON report). Both Town layouts and the account-switch
  regression passed within this full run.
- The web producer verified/reused all 3,750 navigation graphs, building zero.
  The release web compiler succeeded (575.7 seconds). The first Chrome smoke
  attempt failed with a `Runtime.evaluate` CDP timeout before the hub check;
  retrying the unchanged script against the same built artifact passed hub,
  Practice-only Options, readiness, live timer, exit and game-over checks, with
  no browser exceptions or backend requests. No timeout or assertion was
  changed. Canonical Prepare then reran the client-build component while reusing
  all successful test evidence.
- The final canonical client-build run passed the unmodified Chrome smoke gate
  as well. It reused all 3,750 navigation graphs, retained the compiled
  `main.dart.js` output, and completed the incremental web build in 260.8 seconds.
  Canonical Prepare completed at 19:56:31 UTC; all required component checks
  passed.
- Prepared Functions tree SHA-256:
  `10dc4c6ebbb48c4753b944ad9e272e03ba7e6f72a6dd63259a1116f0a69f04b4`.
- Prepared web tree SHA-256:
  `aa65542b6bd9eaf113ded8540fec32a6210fe4660ddfaf3123a44c78d1a4ff36`.
  `main.dart.js` SHA-256:
  `42ba194c249bcc8efd2b42dd8c038a7843ff8d74618d663175268ec5735facec`.
- Core, protocol, content, terrain, validator and generated-freshness evidence
  reused through matching component input/toolchain keys.
- Client navigation seeded from the preceding verified candidate: 3,750 graphs,
  manifest SHA-256
  `6f65c41f501cc9618ecefd8ae3349d037656aacb567935ab81268f8639a812bd`.
  Producer freshness/byte verification passed during client build.
- Canonical BuildImage reused Cloud Build
  `7df8cfb5-08bd-4988-8671-366e623f9955`, verified its live SUCCESS status and
  immutable worker digest
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:549581d0ca927054c1c9f39544876c80d127dd1bd8654fb4d769f2d1fe7051a1`.
  Worker inputs match the preceding release. No new image build was needed;
  the environment mutation lock was acquired and released normally.

The preflight phone check reported dev debug version code 1; historical APK 5
installation evidence does not establish this candidate's device acceptance.
No native artifact was installed or signed-in gameplay verified in this release.
Subsequent dependency/native-project commit `98a652f6` is outside the frozen
candidate. Test corrections were validated in an isolated checkout using the
candidate's dependencies before creating the replacement candidate.

## Unfinished-ticket review

Read-only inventory observed at 18:29:44 UTC found 29 sessions: 13 validated,
12 cancelled, one expired and three issued. All 13 accepted runs have settled
grants; there are no identity mismatches, pending/quarantined settlements,
active account deletions or missing current boards.

Read-only review at 18:32:11 UTC confirmed the following issued tickets have no
upload/validation lease, uploaded replay object, accepted validation or reward:

| Ticket | Issued October 31 (UTC) | Expires November 1 (UTC) |
| --- | --- | --- |
| `run_715d91f4f7a5ceca71bf4d2d4e672b145131b5e1` | 18:01:44 | 18:01:44 |
| `run_c1bb0f917bbf9e8bc42565fef391518734b21060` | 18:14:57 | 18:14:57 |
| `run_aaec56aef8c7eb4bb74ba15c554a1748386c4d83` | 18:27:50 | 18:27:50 |

Absence of uploaded data does not establish absence of an offline device run.
Cancellation approval was requested for these three tickets only, explaining
that any unsubmitted runs using them become invalid while existing account
gold, XP and achievements are preserved. The owner answered "Cancel these three
tickets and deploy". No cancellation has been performed yet.
The 18:59:02 UTC recheck found a fourth issued ticket,
`run_eea5191e43a5b2302daef5637aafbf438e5a41e5`, created at 18:42:51 UTC.
It also has no uploaded replay, validation or grant. Separate cancellation
authorization was requested; the original approval and helper still cover
only the initial three tickets.
Canonical Inspect at 19:37:42 UTC found 31 sessions: 13 validated, 12 cancelled,
one expired, four issued and one uploading. All 13 grants remain settled;
canonical gold is 3,199 and all three current boards are active. The 19:40:05 UTC
read-only follow-up identified the uploading session as
`run_55f75785ad2692d952654a5b2f5d5be06ef4efeb`, created at 19:04:01 UTC.
It has an upload lease but no replay object, validation or reward grant. The
owner was asked to approve both additions (20:42 and 21:04 Helsinki time),
replacing the earlier fourth-ticket-only question. Approval is pending; no
cancellation or cutover has been performed. `active-review.json` retains the
bounded read-only evidence. The cancellation helper still authorizes only the
original three IDs and will reject the expanded active set.
The final 19:58:20 UTC read-only check confirmed the same five IDs, states and
absence of uploaded replay objects, accepted validations and reward grants.
Issuance remains open. The prepared release state has `prepared: true` and
`imageVerified: true`, with pause/deployment/resume timestamps all null.
The same live inspection found all 35 Functions ACTIVE, worker revision
`replay-validator-00064-nxw` ready with 100% traffic, and all three task queues
RUNNING. These are the preceding deployment's identities, not proof that the
eligibility update has been deployed.
The bounded helper reuses the earlier guarded cancellation procedure, binds the
exact candidate/digest and ticket set, requires a healthy paused issuer and
source-bound cutover ownership, rechecks absent evidence, uses transaction and
update-time preconditions, and verifies protected-account/reward hashes.

Read-only evidence and the prepared helper are retained under
`.tmp/achievements-deploy-20261031/`. The active checklist is
[Hall of Honour dev release](../building/achievements_dev_release.md).
