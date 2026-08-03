# Cloud Artifact Retention

## Purpose

The application retains player-facing replay evidence only while it is named
by an authoritative Firestore record. Build and container history use explicit
time/count retention so release activity cannot grow Cloud Storage or Artifact
Registry indefinitely.

The checked-in configuration and apply script live in `tools/cloud/`. They are
the source of truth for the production project and must be applied after a new
project, bucket, or Artifact Registry repository is created. The validator
deployment script also establishes the prefix-scoped Storage access required by
the validator and the Functions control-plane identity.

## Cloud Build source archives

`cloudbuild-source-lifecycle.json` deletes only objects beneath `source/` in
the `${PROJECT_ID}_cloudbuild` bucket when they reach 30 days of age. These
archives are build inputs that have already been consumed; release source of
truth remains the Git revision. `apply_retention_policies.ps1` explicitly sets
the bucket's seven-day soft-delete setting as the recovery window for an
accidental lifecycle-policy change.

The rule intentionally does not match other prefixes, so Cloud Build logs or
future project-owned artifacts require an explicit policy change before they
can be expired.

## Replay-validator images

`replay-artifact-cleanup.json` applies only to packages beginning with
`replay-validator` in the `replay` Artifact Registry repository:

- `configure_cloud.ps1` accepts only an immutable image digest, confirms the
  accepted Cloud Run revision resolved to that digest, then tags it
  `production`; that version is retained indefinitely;
- the five most recent versions are retained as rollback candidates;
- every other version becomes eligible after 90 days.

Artifact Registry keeps any version matching a keep rule even when it also
matches the deletion rule. Deployments outside the script must tag the exact
accepted image digest before they are considered complete. `packageNamePrefixes`
matches package names beginning with `replay-validator`; reserve that prefix in
the repository or use a separate repository for similarly named packages. The Firebase-managed
`gcf-artifacts` repository is deliberately out of scope because Functions owns
its revision/image lifecycle.

Google applies Artifact Registry cleanup asynchronously, normally within a
day. Deleting a version does not necessarily reclaim shared container layers
until its daily garbage collection pass.

## Replay and ghost artifacts

`runSubmissionCleanup` runs hourly. It already expires stale uploads and
validated artifacts under their stricter run-session safeguards. It now also
scans the exact canonical path `ghosts/{boardId}/{entryId}/ghost.bin.gz` and
deletes an object only when all of the following hold:

1. it is at least 48 hours old;
2. its Firestore manifest document does not name that exact storage path;
3. its path matches the canonical ghost-object format.

An existing manifest protects the object regardless of whether it is active or
demoted, leaving the ghost publisher's seven-day demotion grace period
authoritative. Unexpected paths are never removed by this job. Each execution
scans and deletes at most 200 ghost objects, then persists its opaque Storage
page cursor in `maintenance/ghost_artifact_cleanup`; when operations lower the
delete cap below the scan cap, the scan request is reduced to the delete cap so
the cursor never advances past unprocessed objects. Storage deletion is
idempotent.

## Runtime Storage access

`configure_cloud.ps1` applies the operational IAM bindings required by the
implemented lifecycle:

- `sa-replay-validator` reads `replay-submissions/`, creates sealed
  `replay-submissions/validated/` artifacts, and manages `ghosts/` objects;
- `sa-run-control` lists the replay bucket for scheduled cleanup and account
  deletion, while object mutation is limited to `replay-submissions/` and
  `ghosts/`.

Cloud Storage evaluates object listing at the bucket rather than object-prefix
level, so the control-plane identity's read/list binding necessarily covers the
replay bucket. Its destructive binding remains prefix-scoped.

## Operations

Apply the policy as part of every replay-validator release; it is also safe to
run on its own:

```powershell
.\tools\cloud\apply_retention_policies.ps1 -ProjectId "rpg-runner-d7add"
```

For an Artifact Registry observation-only rollout, use
`-DryRunArtifactCleanup`, inspect the repository's cleanup-policy results, and
then rerun without the switch. The helper passes `--no-dry-run` for that second
call so it actively disables any prior dry-run setting. The production policy
is intended to run live after its first inventory review.

Do not bulk-delete replay-bucket objects by prefix. Use the scheduled cleanup
or an equivalent manifest-reference audit, because a ghost object's path alone
does not say whether a player can still load it.
