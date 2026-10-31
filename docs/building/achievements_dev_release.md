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
