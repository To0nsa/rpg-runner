# Player message console

Local developer tool for one player UID, a system message and optional claimable
gold. It uses the existing inbox delivery transaction and the projects in
[`../release/environments.json`](../release/environments.json). No new packages,
cloud service or player callable are required.

## Start

From the repository root, with Node 24 and the existing pnpm dependencies:

```powershell
corepack pnpm install --frozen-lockfile
corepack pnpm messages:login --account your-authorized-email@example.com
corepack pnpm messages
```

The launcher builds current Functions source before starting. Open its printed
`http://127.0.0.1:8766/#...` URL in a browser. Keep the terminal open; Ctrl+C stops
the server. To use a different port, run `corepack pnpm messages --port 8768`.
The console binds only to loopback. The URL's random session token authorizes
local requests; use the new printed URL after restarting the server.

The one-time login requires the Google Cloud CLI and a browser sign-in with an
account authorized for the game projects. For this workstation, use
`corepack pnpm messages:login --account lothringen.rpg@gmail.com`.
The launcher and browser show the saved messaging account.

The login helper gives only its child gcloud process a dedicated
[`CLOUDSDK_CONFIG`](https://docs.cloud.google.com/sdk/docs/configurations)
directory: `%APPDATA%/Lothringen/messaging/gcloud` on Windows, or
`~/.config/Lothringen/messaging/gcloud` elsewhere. The console selects that
directory's `application_default_credentials.json` through a process-only
[`GOOGLE_APPLICATION_CREDENTIALS`](https://docs.cloud.google.com/docs/authentication/application-default-credentials)
override. Shared ADC, active gcloud configuration, parent-shell variables and
other applications' logins are unchanged. Credentials stay outside the repository
and browser; the console refuses to start if its dedicated login is missing or
incomplete, with no fallback to another account. Do not commit credential files.

Preview makes no Firebase calls. Sending uses the dedicated account's Firestore
access to the selected project. The login does not grant IAM access or deploy
the player inbox. The helper disables a fixed quota project so resource usage
belongs to the selected project rather than another local application's project.

If sending reports **Firestore denied access**, check that the displayed account
has access to the selected environment. For an expired or different login, rerun
`corepack pnpm messages:login --account <authorized-email>`, restart the console,
open its new printed URL and preview/retry the existing draft. This replaces only
the messaging login. Keep the same browser and port to restore the saved draft.

## Send a message

1. Select **Development**, **Staging** or **Production**. The mapped project is
   shown in the composer and preview; there is no default environment.
2. Enter the player's UID from that environment, a title (up to 120 characters)
   and body (up to 2,000 characters). Enter a nonnegative whole gold amount; zero
   sends information only. The server requires a JavaScript-safe integer.
3. Select **Preview message**. Check the exact destination, UID, text and gold.
   Preview validates locally; it does not check the player or credentials.
4. Select **Send message**, or **Send to production**. Sending checks that the
   player profile exists and account deletion has not been requested. Gold is
   attached to the inbox message, becoming spendable only when claimed in game.

Editing any field invalidates the displayed preview. After a send attempt the
draft is locked, preserving the exact recipient/content for retries. Start a
**New message** to compose another delivery. The tool does not search players,
send broadcasts, grant items/skills, or display a cross-player delivery history.

## Recovery

The browser saves the draft, environment, delivery ID and successful confirmation
in local storage. Session authorization stays in session storage. Use a trusted
developer browser profile; clearing site data removes these local records.
Changing the port/browser changes the storage location. **Download draft** and
**Restore draft from file** preserve a delivery across browsers or machines.
Downloaded drafts include the recipient UID and message contents; keep them out
of source control. New messages replace the current saved draft.

After a timeout or other uncertain result, keep the draft and select **Retry
same delivery**. After a restart or expired preview, preview the same draft
again. Identical deliveries are idempotent, including after the gold was claimed.
A reused delivery ID with changed contents is rejected. Changing the environment
creates a separate destination; the same UID need not refer to a player there.
Imported drafts retain their environment and still require preview before send.

The confirmation records environment, project, UID, deterministic message ID and
confirmation time. It means delivery succeeded or an identical delivery already
existed; it does not imply the player read the message or claimed its gold.
While a message is active, the backend retains its immutable contents, source
identity and claim record.
After player deletion or automatic 30-day cleanup, a compact receipt retains
source identity, a content hash and claim result; the message text is removed.
An identical delivery retry still succeeds without recreating the message.
Unclaimed gifts never expire. Claimed gifts become eligible for cleanup 30 days
after claim; information messages 30 days after first read.
This first version does not add a durable operator-identity audit log.

## Validation

From the repository root:

```powershell
corepack pnpm messages:test
corepack pnpm messages:test:browser
corepack pnpm --dir functions build:test
corepack pnpm --dir functions exec firebase emulators:exec --config ../firebase.test.json --project demo-rpg-runner-functions-tests --only firestore "node --test lib_test/test/inbox/inbox.test.js lib_test/test/inbox/operator.test.js"
```

For browser checks, after building Functions, run
`node tools/messaging/test/ui_fixture.mjs` and open its printed URL (port 8767).
This separate fixture uses in-memory delivery only. UID `retry-player` simulates
a lost response after saving; `missing-player` simulates a missing account.
The real launcher refuses `FIRESTORE_EMULATOR_HOST` to avoid falsely labelling
emulator delivery as dev/staging/prod.

The automated browser check requires Chrome (or `CHROME_EXECUTABLE`), creates
an isolated headless profile and uses the in-memory adapter. Screenshots are
written under ignored `build/messaging-smoke/`; the temporary profile is removed.

See the [inbox contract](../../docs/tdd/system_inbox.md) for delivery, claim,
deletion and compatibility invariants.
