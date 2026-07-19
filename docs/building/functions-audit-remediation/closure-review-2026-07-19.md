# Functions Audit Remediation Closure Review — July 19, 2026

## Decision

The original July 18 audit remains immutable. Its `BLOCK` recommendation was
correct for the audited tree and is superseded by this dated review.

The two Critical findings and eight additional findings are closed. The
production backend may continue controlled pre-launch use and canarying.
Approval for public/live traffic remains **HOLD** because F-05 and F-06 still
have explicit launch gates.

The remediation plan remains active under `docs/building/`; it must not be
archived yet.

## Finding-by-finding disposition

| Finding | Final status | Closure basis or remaining gate |
| --- | --- | --- |
| F-01 | Closed | The public ownership allowlist excludes grants/unlocks, loadouts are transactionally authorized, negative tests pass, production rejects the removed authority paths, and live ownership/reward data was inventoried. |
| F-02 | Closed | Public time inputs were removed/rejected, the validator enforces ticket time/window invariants, boundary tests pass, and legacy production tickets were explicitly adjudicated. |
| F-03 | Closed | Direct dependencies and the lockfile were upgraded, the production audit reports no known vulnerability, Node 24 tests pass, and deployed Storage/Tasks/trigger/schedule paths were canaried. |
| F-04 | Closed | Retry disposition, quarantine, stable cursor paging, metrics, alerting, and the runbook are deployed. Poisoned-page, transient-failure, Eventarc/immediate/repair race, and multi-page drills converge without duplicate payment. |
| F-05 | Production verified | Tombstone-first guards, bounded resumable erasure, repeated reconciliation, 23-stage crash replay, production Auth/data/artifact erasure, four-field completion compaction, and deletion age/failure alerts are verified. Formal closure waits for public retention disclosure and lawful-basis documentation. |
| F-06 | In progress | Reviewed per-UID quotas are enforced, payload/replay/resource bounds and compact retention are live, web App Check attestation works, email delivery is verified, and rejection/storage/task/cost-pressure alerts are deployed. Native preflight is complete, but Android release identity/signing/Play-device measurement, other-platform exclusion decisions, and App Check enforcement remain. |
| F-07 | Closed | Expiry commits before the callable error, repeated and racing cleanup paths converge, and the client-absent expiry drills pass. |
| F-08 | Closed | Enqueue failure remains repairable, terminal cleanup atomically revokes provisional grants, projections suppress incompatible rewards, and valid/invalid production replay canaries converged. |
| F-09 | Closed | Rename time and cooldown are server-authoritative; exact-boundary and concurrent-rename tests pass; the authoritative profile functions are deployed. |
| F-10 | Closed | First creation is transactional, profile/index races and repair are tested, and production inventory/repair found zero inconsistency. |
| F-11 | Closed | Node 24 and dynamic compiled-test discovery are configured, migration behavior has real tests, Firestore deny tests cover server collections, and the complete 171-test Functions suite passes. |
| F-12 | Closed | Auth and UID checks precede dependency resolution; negative tests and production unauthenticated/mismatch canaries prove the ordering. |

Disposition count:

- 10 `Closed`;
- one `Production verified`;
- one `In progress`;
- zero open Critical findings;
- zero accepted-but-unbounded risks.

## Evidence chain

The principal implementation landed in commit
`815aaddebb077429ea52774d2bb86e3a76a217c4`. App Check, quota, and monitoring
rollout evidence landed in `90d643c`; replay-canary cleanup evidence landed in
`804c680`. This review and the final retention/fault-drill changes are carried
by the commit containing this document.

The exact non-secret deployment and verification evidence is split by concern:

- [production deployment](production-deployment-2026-07-19.md);
- [production verification](production-verification-2026-07-19.md);
- [App Check web rollout](app-check-client-rollout-2026-07-19.md);
- [native App Check readiness](native-app-check-readiness-2026-07-19.md);
- [quota enforcement](quota-selection-and-enforcement-2026-07-19.md);
- [alert delivery](alert-channel-confirmation-2026-07-19.md);
- [deletion retention review](deletion-retention-privacy-review-2026-07-19.md);
- [isolated destructive fault drills](isolated-destructive-fault-drills-2026-07-19.md);
- [Functions safety monitoring rollout](functions-safety-monitoring-rollout-2026-07-19.md).

The final deletion deployment reports:

- source/configuration hash
  `a0e9f8ecfd9afba9d89c8e1cfa7ce24a36f1c48b`;
- `accountDelete` revision `accountdelete-00013-sov`;
- `accountDeletionRepair` revision `accountdeletionrepair-00007-quf`;
- both functions `ACTIVE`;
- the one-minute scheduler `ENABLED`.

## Final validation

- `corepack pnpm --dir functions build`: passed.
- `corepack pnpm --dir functions test`: 172/172 passed.
- `corepack pnpm --dir functions audit --prod`: no known vulnerabilities.
- `dart analyze services/replay_validator`: no issues.
- `dart test services/replay_validator/test`: 75/75 passed.
- Focused replay-validator fault matrix: 48/48 passed.
- `git diff --check`: passed; only configured line-ending conversion warnings
  were emitted.
- Post-deployment logging query: no error-severity entry for the two deletion
  services after the final revision rollout.

## Production controls confirmed

- The App Check-capable web release obtained a server-verified reCAPTCHA
  Enterprise token from the production Hosting origin.
- All nine quota-bearing callables enforce the reviewed per-UID policy; the
  complete enforcement canary passed.
- The production email notification channel is enabled, verified, and delivered
  the exact synthetic incident to the recipient; the temporary policy was
  deleted.
- Completed deletion evidence is limited to `state`, `requestedAtMs`,
  `completedAtMs`, and `expiresAtMs` with a 30-day maximum.
- The final inventory reported nine compact completions and zero active,
  retryable, non-minimal, missing-expiry, or expired deletion records.
- The fault matrix was isolated from production; production received only
  normal canary traffic and ordinary repair-worker invocations.
- The deletion worker emits privacy-safe ordered backlog health; three deletion
  policies and twelve callable/resource policies are enabled on the verified
  channel.
- Four log metrics and native Cloud Run, Storage, and Tasks metrics cover App
  Check gaps, quota rejection, contention, retention saturation, signer/replay
  volume, and project resource/cost pressure.

## Gates before public launch

1. Publish the compact deletion-retention disclosure and external deletion
   resource, and record the selected lawful basis with appropriate owner/legal
   review.
2. Measure legitimate App Check release traffic for Android, iOS, macOS, and
   any other supported Firebase platform, or explicitly exclude each
   unsupported platform from the release. Native preflight found that Android
   still has an example package, debug release signing, no registered SHA-256,
   and no Play-installed physical-device sample; Apple has no configured team
   identity or reachable release environment.
3. Enable App Check enforcement only after those platform gates pass; retain
   the documented monitor-mode rollback.
4. Complete the broader release checks still listed in the active plan,
   including browser Storage CORS/lifecycle decisions, compatible native
   client provenance, and a longer latency/backlog/cost observation window.

Once F-05 and F-06 are `Closed` or have a dated, named, expiring risk
acceptance, rerun the closure inventory, change the public-launch decision, and
archive the remediation plan. Until then, this review authorizes continued
controlled pre-launch operation only.
