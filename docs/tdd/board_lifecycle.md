# Board lifecycle

The current pre-release policy keeps the serving gameplay tuple's current
competitive windows for each configured competitive level and current weekly
window for the featured level. Default provisioning creates three boards, not
six: next windows are created on demand when they open. Explicit
`includeNextWindows` remains available for fixtures and operator preparation.
Gameplay compatibility remains part of board identity and deterministic seeds;
this change does not merge scores across incompatible simulations.

`leaderboardBoardMaintenance` ensures current boards, then calls
`boards/retention.ts`. Retention walks ten board parents per hourly invocation
with a durable cursor, compare-and-set cursor updates and one lookahead. It
requires exactly one supported gameplay version matching the provisioning
configuration; a cutover pause or draining-version set blocks retirement.

Current tuple/window boards and boards referenced by nonterminal run sessions
are protected. Active sessions are read using the single-field state index,
including top-level and ticket board bindings. More than 1,000 active sessions
blocks pruning rather than trusting a truncated inventory. Malformed unmanaged
parents are preserved for operator repair.

Other managed boards are marked `status: disabled` with `retiredAtMs`. Normal
cleanup waits 24 hours from retirement (the maximum ticket lifetime), rechecks
active sessions, and drains at most 100 documents from one nested collection per
board per invocation. The explicit inventory is `ghost_manifests`,
`player_bests`, and `views`. Once empty, at most 100 objects under the exact
`ghosts/<boardId>/` prefix are deleted with observed generation preconditions.
The parent is deleted only after child/object inventories are empty. Failures
and unknown child collections leave a discoverable parent for retry; canonical
run records, replay archives, wallet grants and ownership are not deleted.

Projection and ghost-manifest transactions read the board parent as well as
account-deletion barriers. Missing/disabled/retired parents raise
`BoardRetiredException`; optional projection tasks acknowledge this without
retries or wallet changes. Concurrent retirement invalidates an in-flight
projection transaction. A ghost copied before a fenced manifest write is
compensated using the copied generation, preserving any replacement object.
Previously retired future windows are reactivated when current provisioning
needs them; intentionally disabled boards without `retiredAtMs` stay disabled.

The operator command is read-only by default:

```powershell
node functions/tool/prune_boards.mjs --environment dev --game-compat 2026.10.21
```

`--apply` performs bounded resumable cleanup. `--immediate` bypasses the 24-hour
grace only for an explicitly authorized pre-release dev purge; active-session
protection still applies. It is rejected for staging/prod. The command resolves
the project/bucket from the environment registry and uses the existing gcloud
operator credentials in memory. Verify its explicit gameplay tuple against the
serving issuer before applying. Delayed projection tasks must be drained or the
board-fenced worker deployed before final removal. This tool does not authorize
deployment, run cancellation or an account reset.

Keep board maintenance paused across the coordinated Functions/worker cutover,
and resume it only after the board-fenced worker is serving. The current-only
policy must be reviewed before offering historical leaderboards
to real players. Local and live verification are tracked in the
[workstream checklist](../building/board_lifecycle_cleanup.md).
