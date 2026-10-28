# System inbox

## Authority and persistence

Functions owns system mail and claims. Flutter uses `InboxApi` through AppState;
direct Firestore client access is denied. Core, run tickets, replay contracts
and the validator are unchanged. Player chat is not implemented.

| Collection | Responsibility |
| --- | --- |
| `system_messages/{id}` | Versioned message, recipient, source, immutable text/rewards, creation time, independent read/claim times |
| `inbox_rewards/{id}` | Snapshotted attachment, recipient, claim receipt and applied ownership revision |
| `inbox_summaries/{uid}` | Monotonic revision, whole-inbox unread and unclaimed counts |
| `inbox_receipts/{id}` | Removed-message identity, immutable content hash, original creation time, deletion time and gift claim result; no title/body |

IDs hash recipient plus source identity. Level gifts use `level:<level>`;
operator messages use `operator:<sourceId>`. Retrying identical delivery is a
no-op; different contents under the same identity are rejected. Rewards are a
typed list. Schema 1 remains empty or one positive JavaScript-safe gold amount.
Schema 2 adds up to eight catalog unlocks: `gear` with `slot`/`itemId`, or
`ability`/`projectileSpell` with `slot`/`itemId`/explicit `characterId`. Unknown
fields, IDs, slots, characters and duplicate identities fail closed. Catalog
attachments are sorted by stable identity before persistence/content hashing;
legacy gold-only hashing is unchanged. Unsupported types fail closed. Issued rewards never change with later tuning.

Unclaimed gifts and unread information have no expiry. Claimed gifts become
eligible for removal 30 days after successful claim; information becomes eligible
30 days after its first read. Reading a gift does not start expiry, and retries
never extend the retention deadline. `expiresAtMs` is a server-owned query field;
missing legacy values remain valid and are repaired from read/claim timestamps.

Players can delete information or claimed gifts immediately. The delete transaction
fences account erasure, validates recipient and claim records, removes message and
attachment, adjusts unread count, increments summary revision, and creates a compact
receipt. Any unclaimed gift is rejected even if a caller bypasses the UI. Repeating
deletion of an owned receipt succeeds without another counter change; unknown or
other-player IDs fail. Claimed gold and ownership remain with the player.

Delivery checks both active messages and removal receipts. The retained hash covers
recipient, source ID, title, body and rewards. Identical retry is a no-op after
removal; changed content under the same source identity is rejected. The receipt
retains gold amount, schema-2 reward identities, claim time and applied ownership revision for the account's
lifetime. Claiming a removed message fails without crediting gold. Account erasure
explicitly removes all four inbox collections in resumable stages.

`inboxRetentionCleanup` runs hourly in UTC, processing at most 200 indexed due
messages plus 200 documents in a rotating compatibility sweep. Every deletion
rechecks actual read/claim eligibility in a transaction, protecting gifts even
when a stale expiry index says they are due. The sweep repairs legacy/mismatched
deadlines and removes eligible legacy content; it wraps after a full pass. Its
`maintenance_state/inbox_retention_v1` checkpoint advances with a revision compare
and set, so overlapping runs cannot overwrite newer progress. Account-erasure
barriers are skipped; other document failures are logged and revisited on later
passes. Counts, backlog saturation and checkpoint advancement are logged.
The 30-day point is an eligibility deadline; physical removal follows cleanup
cadence/backlog. Firestore TTL is not enabled, since deletion must update related
records atomically. Existing single-field indexing supports the expiry query.

## Level milestone transaction

`settleAcceptedRunSession` compares XP-derived levels before and after applying
validated progress. Each crossed milestone creates a pending 25-gold gift,
configured in `inbox/level_rewards.ts`. Multiple levels each receive a gift;
level 30 remains the cap. Previously reached levels and previously settled runs
are never backfilled. Loading an account/inbox does not create gifts.

Inbox reads precede grant reconciliation's transaction writes. Messages,
attachments, summary, XP, ordinary run gold and terminal run state commit
together. Canonical ownership and terminal sessions fence duplicate settlement.
Inbox gold remains unspendable until claimed; ordinary run gold still settles
automatically. Developer Practice issues neither reward.

## Callable contract

All routes use the existing Play Games identity gate, App Check rollout,
bounded payload checks, UID equality, deletion fencing and quota observation.
Unknown request fields, including sender/reward fields, are rejected.

| Callable | Fields beyond `userId` | Result |
| --- | --- | --- |
| `inboxLoadSummary` | None | `summary` |
| `inboxList` | Optional `cursor` | `messages`, `summary`, `nextCursor` |
| `inboxMarkRead` | `messageId` | `message`, `summary` |
| `inboxClaimReward` | `messageId`, `commandId`, `expectedRevision` | `message`, `summary`, ownership `result` |
| `inboxDeleteMessage` | `messageId` | Matching `messageId`, `deleted: true`, current `summary` |

Pages contain at most 20 messages, newest first, then descending document ID
for timestamp ties. Cursors contain `createdAtMs` and `messageId`; one lookahead
record determines whether another page exists. Summary counts include unloaded
pages. Reads are transactionally fenced against account deletion.

Reading decrements unread count once; claiming does not mark mail read.
Claiming verifies message/attachment consistency, safe-integer gold addition
and ownership revision. Existing catalog grants reuse the store's ownership
primitive, with fixed character targets, no automatic equip and no compensation
for an already-owned unlock. Store offers are normalized after ownership changes.
Gold, unlocks, next canonical revision, claim receipts and
summary update atomically. Command IDs use the existing compact ownership
idempotency records/retention; hashes bind recipient, message and expected
revision. Stale revisions and changed payloads under a reused ID stay rejected.
The durable reward receipt prevents recrediting with a fresh command ID, even
after command-idempotency expiry. Retries return current canonical ownership.

`inbox_read`/`inbox_write` initially observe one-minute/day request counts without
unmeasured enforcement limits; see [callable controls](callable_abuse_controls.md).

## Client and UI

The production service factory injects `FirebaseInboxApi`. Decoding rejects
unknown claim outcomes, mismatched identities and missing receipts. AppState
owns account-scoped messages, summary, pagination and per-message busy state.

Attention refreshes after bootstrap/resume, final run settlement and once per
minute while foregrounded. Failure retains known attention without blocking
startup; opening the inbox provides explicit refresh/retry. Data is in memory,
with no new disk cache or push notification service. Developer Practice has no
inbox access.

Claims flush pending ownership edits, apply only non-regressing canonical
revisions and reapply queued selection projections. A stale-revision response
can retry once with a fresh command ID. Transport uncertainty remains retryable;
the server receipt prevents double credit. Summary revision checks and
monotonic message-state merging prevent old pages undoing reads or claims.
Account replacement, accepted deletion and disposal fence late responses.
The adapter requires an explicit matching deletion receipt before removing local
state. Per-message busy state prevents overlapping read/claim/delete actions.
Account-scoped removed IDs filter older in-flight page responses, preventing
deleted mail from reappearing. Loading more remains available after deleting all
currently loaded messages. Failed or lost delete responses preserve retry; deletion
does not apply speculative counter or wallet changes.

`MessagesPage` reuses `MenuScaffold`, shared tokens, `AppButton`, icon buttons
and `GoldDisplay`. Landscape list and message text scroll independently; gift
controls remain visible below the text. Selecting a message marks it read;
opening the list does not. Failures use player-facing retry text.
Item/skill rows reuse `game_presentation` icons and names.
Delete is disabled while any gift is unclaimed, with a visible claim-first explanation.
Eligible messages expose immediate deletion; the body explains the 30-day policy.

`AttentionMarker` is a shared presentation-only component. Its caller supplies
visibility, accessible meaning and child. Shared tokens control its worn-gold
dot; the overlay preserves layout and hit targets. `MenuIconAction` exposes
attention inputs. Messages supplies unread OR unclaimed state. Library/Store
can reuse it when their separate discovery policies are implemented.

## Operator delivery

The [Flutter Admin app](../../tools/admin/README.md) runs from
`tools/admin/` with `corepack pnpm admin`; its gold-only browser compatibility
console remains available as `corepack pnpm messages`. The launcher builds current
Functions source. Both console and CLI use `inbox/operator.ts` for input
validation and explicit-project delivery through `issueSystemMessage`.
No player-callable issuance route is added.

The console requires dev/staging/prod selection and reads the project mapping
from `tools/release/environments.json`. It never derives the target from ADC or
the active gcloud project. Each send initializes a named Admin app for that
explicit project and deletes it afterwards. The console uses a dedicated user
ADC file outside the repository, under `%APPDATA%/Lothringen/messaging/gcloud`
on Windows or `~/.config/Lothringen/messaging/gcloud` elsewhere.
`corepack pnpm admin:login --account <email>` runs gcloud ADC login with a
child-only `CLOUDSDK_CONFIG`, clearing inherited cloud account overrides and
disabling a fixed quota project. The launcher selects this credential file in
its own `GOOGLE_APPLICATION_CREDENTIALS` before importing Firebase. Missing or
incomplete credentials stop startup; it never falls back to shared ADC.
The saved account email is shown in the launcher and console; credential material
is never exposed to Flutter or browser code. Shared ADC and active gcloud configuration
are unchanged. The standalone Functions CLI still uses its caller's ADC.
Firestore permission-denied and unauthenticated failures return tool-specific
login recovery guidance. Provider details remain private, and the existing
draft/source identity is retained for retry. Login does not grant IAM access.

The HTTP service binds to `127.0.0.1` and validates exact Host, same-origin
requests, a random per-process bearer token and bounded JSON bodies. It serves
only fixed local assets with a restrictive CSP, no caching and no CORS access.
The native child supplies its token to Flutter over a private pipe. For the
browser, the printed URL supplies the token through its fragment; the browser moves it
to session storage and removes the fragment. The real launcher rejects a
Firestore emulator override. A separate in-memory fixture supports UI checks.

Preview is offline and stores an immutable normalized request in server memory,
bound to the selected project, UID and delivery identity. Send accepts only its
preview ID; altered fields or unknown previews are rejected. Preview entries
expire after 30 minutes; in-flight delivery is allowed to finish. The process keeps
at most 128 entries; expired idle entries are reclaimed at preview creation.
Concurrent sends share a promise, successful receipts are cached for the preview
lifetime, and failures allow retry with the same request.
Backend delivery identities remain authoritative across process restarts.

Any composer edit invalidates the visible preview. A send attempt locks the draft;
new deliveries require New message and a new source identity. Browser local
storage and JSON draft download/restore preserve environment and delivery ID
for recovery. Imported drafts must be previewed. Success shows a confirmation
with project, recipient and message ID, covering both new and identical prior
delivery. Local confirmations are not read/claim receipts or operator audit logs.
Player availability and deletion are checked atomically at send, not at preview.

Admin supports single-recipient text, optional gold and existing item/skill
unlocks. The compatibility browser remains gold-only. Native draft persistence,
shared packages and the per-environment schema-2 activation gate are defined in
[Admin architecture](admin_tools.md). No launcher publishes the capability gate.

The privileged CLI accepts a JSON file containing `uid`, `sourceId`, `title`,
`body`, optional `goldAmount` and optional typed `attachments`. Preview is offline:

```powershell
corepack pnpm --dir functions build
node functions/lib/inbox/send_message_cli.js --file message.json
```

Sending requires operator Firestore credentials, an explicit project and send
flag. The target profile must exist and have no deletion tombstone:

```powershell
node functions/lib/inbox/send_message_cli.js --file message.json --project PROJECT_ID --send
```

Reuse the source ID for retries. Persisted source, contents, creation time and
claim receipt provide delivery evidence. There is no player-callable issuance
route or broadcast campaign service.

## Extension and release boundaries

Deploy the new callable, scheduler, receipt-aware issuers, account erasure and
rules before releasing the client Delete action. Restart/rebuild local operator
consoles and CLI senders before cleanup starts: older privileged issuers do not
check removal receipts. Use the coordinated release workflow to keep settlement
issuers consistent through cutover. No separate live backfill is required; the
bounded compatibility sweep derives deadlines from retained timestamps. Existing
eligible mail can be removed on the first sweep after deployment. Monitor failed
documents and saturated expiry batches; a large legacy inbox may require several
hourly passes. Local verification does not authorize or establish deployment.

Future live chat needs separate conversations, participant authorization,
delivery/read state, blocking, reporting and abuse controls. Item/skill gifts
require the explicit [compatible-environment activation](admin_tools.md#gifts-and-release-activation).

Focused tests cover delivery/claim retries, multiple milestones,
no backfill, pagination, deletion, direct-client denial, client races and UI
layout/accessibility.
