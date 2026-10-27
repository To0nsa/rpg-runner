# System inbox and reusable attention marker

Status: completed locally, 2026-10-21; not deployed. This is the agreed first
Messages feature; player chat remains a future workstream. Current contracts:
[technical design](../../../tdd/system_inbox.md) and
[player experience](../../../gdd/messages.md).

## Agreed behavior

- Match the existing landscape menu shell, typography, colors, panels, buttons,
  spacing and navigation. Keep the interaction simple.
- Support game information messages and manually claimed gold attachments.
- Each newly reached account level awards **25 gold**, centrally configured
  on the backend. Create one gift for every crossed level during accepted-run
  settlement, including multi-level gains.
- Do not award previously reached levels, generate gifts on inbox load, or
  backfill historical settlements. Existing run gold remains automatic.
- Level gifts have no expiry. Read and claimed state are independent.
- The Messages icon has an attention dot while any message is unread or any
  gift remains unclaimed. Opening the inbox does not mark every message read.
- Implement the dot as a shared, theme-driven UI component with semantic
  inputs. Library and Store may reuse it later; their discovery policies are
  outside this change.
- Later level-specific rewards must not mutate already issued gifts. Support
  only gold claims initially and reject unsupported reward types safely.
- Future player messaging will be live conversations with their own state,
  participants, authorization and abuse controls, sharing the Messages entry.
  Do not expose an empty Players tab now.

## Implementation approach

Use the existing Functions callable, Firestore transaction and AppState client
patterns. Keep system messages separate from run-specific reward grants and
canonical ownership; the claim transaction alone credits inbox gold. Persist
level gift creation with the XP/terminal-settlement write so a crash cannot
leave an earned level without a gift. Stable milestone identifiers and stored
claim outcomes prevent duplicate delivery or payment.

Messages are individually stored and paginated. Attention must cover the full
inbox, not just the currently loaded page. Authentication, deletion fencing,
payload validation and quota monitoring follow existing callable conventions.
No arbitrary client sender, reward amount or ownership patch is accepted.
Claim results preserve canonical revisions and integrate with queued ownership
changes. Late responses must not repopulate a deleted or replaced account.

Provide a privileged, repeatable operator entry point for targeted information
messages and gold gifts, with preview and stable delivery identity. Large
broadcast campaigns, player chat, item grants and push notifications remain
separate workstreams. Do not send messages to real accounts during development.

## Milestones and acceptance

- [x] M1: backend message contract, targeted issuing, paginated reads, mark-read
  and atomic gold claim; new-level issuing in settlement; account deletion and
  authorization coverage. Tests cover duplicate/concurrent claims, retries,
  overflow, multiple levels, no historical awards and deletion fencing.
- [x] M2: typed client API and account-scoped AppState orchestration; refresh
  attention at bootstrap/resume and after settlement; refresh canonical gold
  after claims without losing queued selections. Cover failures, stale
  responses and account reset with focused state tests.
- [x] M3: shared attention component and menu icon integration; familiar inbox
  list/detail, read state, reward claim, loading/empty/error/retry states.
  Verify landscape layout, accessibility and dot lifecycle with widget tests.
- [x] M4: technical/game-design documentation, relevant backend build/emulator
  tests and targeted Flutter analysis/tests; review all changes and record
  evidence. Commit only validated, coherent task changes.

## Existing integration points

- [Run settlement](../../../../functions/src/runs/reward_settlement.ts)
- [Player progression](../../../../functions/src/ownership/player_progress.ts)
- [Canonical ownership](../../../../functions/src/ownership/canonical_store.ts)
- [App state](../../../../lib/ui/state/app/app_state.dart)
- [Menu icon column](../../../../lib/ui/components/menu_icon_column.dart)
- [Hub icons](../../../../lib/ui/pages/hub/components/hub_menu_icon_column.dart)
- [Current progression design](../../../gdd/player_progression.md)

## Validation and handoff

- Production and test TypeScript builds passed. The final check invoked the
  installed compiler directly against `functions/tsconfig.json` and
  `functions/tsconfig.test.json` after restoring locked dependencies; the
  sandboxed pnpm wrapper was trying to reinstall its modules before execution.
- Firestore emulator: **55 passed**, zero failures/skips across
  `inbox/inbox.test`, `runs/run_projection.test` and
  `runs/settlement_repair.test`. Includes concurrent claims, permanent receipts,
  stale revisions, overflow, cross-account denial, multi-level gains, no
  backfill and atomic rejection of malformed/overflowing inbox counters.
- Account deletion and direct-client Firestore rules: **15 passed**, zero
  failures/skips, with all three new collections seeded into deletion fixtures.
- An earlier **81-test** focused backend run also covered existing abuse
  controls; overlapping inbox/settlement targets were rerun after final changes.
- Flutter: **61 passed** across the three new inbox targets plus hub,
  submission, deletion and ownership-sync regressions. Temporary aggregate
  entry points avoided shared test-cache collisions during concurrent work.
- Targeted Dart analysis: **no issues**. Widget checks cover 844x390 and
  640x360 landscapes, text scale 1.5, errors/retry, attention semantics and
  claim visibility. A 960x450 capture was visually reviewed against the
  existing forest menu, fonts, panels and buttons.
- The targeted delivery CLI produced an offline preview with stable identity
  and 25 gold. No real-account delivery or live deployment was performed.
- Relevant technical/game-design docs and domain guidance are updated.
  Unrelated worktree changes are excluded from the feature commits.

Deployment remains a separate authorized release through the repository
workflow, including callables, rules and the inbox pagination index before
client exposure. Player chat, item gifts, broadcasts and Library/Store discovery
policies remain future work, outside this completed implementation.
