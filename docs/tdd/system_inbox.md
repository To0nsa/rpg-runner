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

IDs hash recipient plus source identity. Level gifts use `level:<level>`;
operator messages use `operator:<sourceId>`. Retrying identical delivery is a
no-op; different contents under the same identity are rejected. Rewards are a
typed list, currently empty or one positive, JavaScript-safe gold amount.
Unsupported types fail closed. Issued rewards never change with later tuning.

Messages and receipts have no expiry or user-delete operation in this version.
Account deletion explicitly removes all three collections in resumable stages.
Future archival must retain delivery/claim deduplication evidence.

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

Pages contain at most 20 messages, newest first, then descending document ID
for timestamp ties. Cursors contain `createdAtMs` and `messageId`; one lookahead
record determines whether another page exists. Summary counts include unloaded
pages. Reads are transactionally fenced against account deletion.

Reading decrements unread count once; claiming does not mark mail read.
Claiming verifies message/attachment consistency, safe-integer gold addition
and ownership revision. Gold, next canonical revision, claim receipts and
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

`MessagesPage` reuses `MenuScaffold`, shared tokens, `AppButton`, icon buttons
and `GoldDisplay`. Landscape list and message text scroll independently; gift
controls remain visible below the text. Selecting a message marks it read;
opening the list does not. Failures use player-facing retry text.

`AttentionMarker` is a shared presentation-only component. Its caller supplies
visibility, accessible meaning and child. Shared tokens control its worn-gold
dot; the overlay preserves layout and hit targets. `MenuIconAction` exposes
attention inputs. Messages supplies unread OR unclaimed state. Library/Store
can reuse it when their separate discovery policies are implemented.

## Operator delivery

The privileged CLI accepts a JSON file containing `uid`, `sourceId`, `title`,
`body` and optional `goldAmount`. Preview is offline:

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

Future live chat needs separate conversations, participant authorization,
delivery/read state, blocking, reporting and abuse controls. Item gifts require
an implemented ownership handler and compatible reward schema first.

Deploy callables and the inbox index before exposing the client using the
repository release workflow. Implementation/local tests do not establish live
deployment. Focused tests cover delivery/claim retries, multiple milestones,
no backfill, pagination, deletion, direct-client denial, client races and UI
layout/accessibility.
