# Account-Deletion Retention Privacy Review — July 19, 2026

## Scope and limitation

This is an engineering privacy review of application-owned account-deletion
state in `rpg-runner-d7add`. It assesses data minimization, purpose limitation,
access, expiry, implementation behavior, and required public disclosure. It is
not legal advice and does not select a lawful basis for the project owner.

The review is grounded in:

- GDPR Article 5 data minimization, storage limitation, security, and
  accountability;
- the European Commission's guidance to retain personal data for the shortest
  period justified by its purpose and to establish deletion or review limits;
- Google Play's rule that associated account data must be deleted while
  narrowly retained security, fraud-prevention, or regulatory data must be
  disclosed.

## Data classification

`account_deletion_requests/{uid}` remains personal data while it exists. The
Firebase UID is pseudonymous, not anonymous, and the document key keeps the
record linkable to a specific deleted account.

The active workflow must temporarily retain operational state so erasure can
resume safely. Before this review, that same state remained after completion,
including stage, pass, attempt count, per-category deletion counters, and
Firestore bookkeeping timestamps.

Those workflow details were useful while deletion was active but were not
necessary after Firebase Auth deletion and final reconciliation. Retaining them
for the full completion window failed the project's stated "minimal completed
tombstone" standard.

## Adopted completion record

On terminal completion, the document is now replaced with exactly four fields:

| Field | Purpose |
| --- | --- |
| `state = "complete"` | Proves the terminal outcome and keeps the deletion guard fail-closed. |
| `requestedAtMs` | Establishes when the request entered server custody. |
| `completedAtMs` | Establishes erasure duration and completion. |
| `expiresAtMs` | Enforces the maximum retention deadline. |

The UID remains only as the Firestore document ID. The completed record contains
no profile, display name, provider identity, gameplay data, ownership,
progression, run ID, leaderboard result, ghost, IP address, error message,
per-category deletion count, or workflow diagnostic.

The record may be used only to:

- prevent the same UID from recreating application data during the bounded
  post-deletion period;
- demonstrate and investigate deletion completion;
- investigate security or erasure-integrity incidents.

It must not be used for gameplay, analytics, advertising, engagement,
profiling, or generalized fraud scoring.

## Retention decision

The adopted maximum remains 30 days from completion.

The engineering rationale is:

- the security purpose is specific and separate from normal game processing;
- 30 days provides one bounded support/security incident window;
- the record is reduced to the minimum fields needed to prove request,
  completion, and expiry;
- direct client access is denied;
- deletion is automatic and continuously checked;
- no gameplay or identity-provider data remains in the record.

This is a maximum, not a minimum. A shorter period may be adopted without a
schema change if operational evidence shows that the security/support purpose
can be met sooner. Any extension requires a new documented purpose, necessity
assessment, public-disclosure update, and project-owner approval. Indefinite
retention is prohibited.

This engineering assessment finds the 30-day maximum proportionate only with
the minimization and controls in this record. It does not replace jurisdiction-
specific legal advice. Before public launch, the project owner must select and
document the applicable lawful basis and publish the retention disclosure.

## Expiry and access controls

`accountDeletionRepair` runs every minute. Before processing active requests,
it queries `expiresAtMs <= now`, deletes only records whose state is
`complete`, and handles at most 10 expired records per invocation. The
production inventory reports:

- completed records missing expiry;
- expired completion evidence still present;
- compact versus non-minimal completion counts.

Firestore native TTL is not configured for this collection. Current Firestore
TTL policies require a timestamp field, while this workflow's source-controlled
contract uses integer epoch milliseconds. Native TTL is also typically
eventual within 24 hours, whereas the scheduled cleanup targets one-minute
evaluation. A scheduler outage can therefore extend retention until a
successful repair invocation; scheduler health and
`expiredCompletionEvidenceCount` must remain operational checks.

Firestore Security Rules deny direct clients access to the collection. Only
the server runtime and authorized operators can process it. Operational output
must use one-way UID hashes rather than raw UIDs.

## Validation and production evidence

The implementation changed:

- `functions/src/account/delete.ts`;
- `functions/test/account/account_delete_callable.test.ts`;
- `functions/tool/production_inventory.mjs`.

Validation passed:

- Functions TypeScript build;
- focused account-deletion emulator suite: 7/7;
- complete Functions emulator suite: 170/170.

Production deployment:

- Functions source/configuration hash:
  `a968167e5da186d99a87a2f77a640485787c7222`;
- `accountDelete`: `accountdelete-00008-bet`;
- `accountDeletionRepair`: `accountdeletionrepair-00002-yet`;
- both active in `europe-west1` on Node.js 24.

Two already-completed synthetic tombstones, UID hashes
`0011f144ad2bebf3` and `6cfb71addad9a428`, were compacted from 16 fields to
four without changing their original request, completion, or expiry times.

The post-migration inventory at `2026-07-19T16:21:55Z` reported:

- two completed records;
- two compacted completions;
- zero non-minimal completions;
- zero completed records missing expiry;
- zero expired completion records;
- three active synthetic deletion workflows, which remained unmodified.

## Required public disclosure

The public privacy policy and external account-deletion resource do not yet
exist. They remain launch blockers even though the backend retention design is
reviewed.

A suitable plain-language starting point is:

> When you delete your account, we delete the account and associated game data.
> We keep a minimal record of the account identifier and the request,
> completion, and expiry times for up to 30 days to prevent data recreation and
> investigate deletion or security problems. The record contains no game
> progress and is deleted automatically.

The final notice must also address provider-controlled logs, backups, support
records, applicable rights, the chosen lawful basis, and a privacy contact.

## Review outcome

Engineering privacy review: **accepted with launch conditions**.

The implementation now satisfies the repository's minimal completed-tombstone
design and bounded-retention requirement. Public disclosure, lawful-basis
documentation, the external deletion resource, and any desired legal-counsel
review remain product-launch work; they are not reasons to retain additional
application data.
