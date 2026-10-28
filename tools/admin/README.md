# Lothringen Admin

Flutter Windows app for targeted system messages, gold and existing item/skill
unlocks. It shares the editor's theme, tokens, panels and catalog cards, and the
game's names and artwork. The first workspace is **Messages & gifts**.

## Start

Use the repository's Flutter/Node versions, Visual Studio Windows desktop tools,
and pnpm dependencies. From the repository root:

```powershell
corepack pnpm install --frozen-lockfile
corepack pnpm admin:login --account lothringen.rpg@gmail.com
corepack pnpm admin
```

The launcher builds Functions, resolves the root Pub workspace, then runs the
Windows app. `corepack pnpm admin:build` builds its executable under
`tools/admin/build/windows/x64/runner/Release/`. This is a repository-backed
internal tool: keep that checkout, Node, service and artwork available. It is not
a portable installer. Launch from the checkout or set `RUNNER_REPO_ROOT` to it.
The editor keeps its separate app and authoring responsibilities.

The dedicated login remains at `%APPDATA%/Lothringen/messaging/gcloud`; the old
folder name is intentionally retained so existing logins keep working. It never
replaces shared ADC or the PikkuRetki login. Credentials stay in the Node child
service; Flutter receives only a short-lived loopback session token over a pipe.
The selected dev/staging/prod project comes from
[the environment registry](../release/environments.json), never the active gcloud
project. Login grants no IAM permissions; the operator needs access separately.

## Send and recover

1. Select an environment and verify its displayed project.
2. Enter one player's UID, title and body, and optional whole gold amount.
3. In an enabled environment, choose up to eight existing items/skills. Gear is
   account-wide. Skills/spells require the displayed character target.
4. Preview, check destination/contents, then send. The player claims all gifts
   together from their inbox. Ownership unlocks do not equip gear or skills.

New installations have no default environment. Production has a prominent label
and explicit send button. Catalog loading reads the selected project's rollout
gate; preview itself is offline. Send checks profile existence, account erasure
and the gate atomically. A disabled catalog does not prevent gold-only mail.

A send attempt locks the draft. On uncertainty, **Retry same delivery**; after
restart, preview that same draft again. Never start a new delivery just to retry.
The backend prevents duplicate grants even after message deletion. Confirmation
means delivered or previously delivered identically, not read/claimed.

The current draft is flushed before sending and stored at
`%APPDATA%/Lothringen/admin/draft.json`. A Windows file lock permits one Admin
instance per user. **Export draft** / **Import draft** preserve its environment,
attachments and delivery ID. Imported confirmations are ignored until verified
by sending again. Drafts contain player UIDs and message text: keep exports out
of source control. New message replaces the current local draft; export it first
if it may still need retrying. There is no delivery-history dashboard or broadcast.

The old browser remains available through `corepack pnpm messages`; its source
moved to `tools/admin/service`. Its storage stays in the same browser/port. Export
an old browser draft and import it into Admin to continue it. Browser imports
reject item/skill attachments so they cannot silently discard gifts. The
`messages:login`, `messages:test` and `messages:test:browser` aliases remain.

## Verification and rollout

`corepack pnpm admin:fixture` uses an in-memory service with a separate
`admin-fixture` draft directory and no credentials/cloud access. `retry-player`
simulates a lost response after delivery; `missing-player` simulates no profile.
Fixture claims are not a replacement for backend emulator tests.

```powershell
corepack pnpm admin:test:service
node tools/admin/service/catalog.mjs --check-fixture
# From tools/admin:
flutter test
flutter build windows --no-pub
```

The generated test catalog comes from the compiled backend allowlist. After an
intentional catalog change, build Functions and run
`node tools/admin/service/catalog.mjs --write-fixture`, then review the diff and
run the Dart catalog test. Do not hand-edit `test/fixtures/catalog.json`.

Item/skill issuance fails closed until each environment has compatible backend
and game-client rollout evidence. See [Admin architecture and activation](../../docs/tdd/admin_tools.md)
and [inbox contracts](../../docs/tdd/system_inbox.md). No launcher enables gifts
or deploys services. Gold/messages retain their existing schema and behavior.
