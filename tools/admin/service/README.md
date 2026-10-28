# Admin local service and browser compatibility console

Owned by [Lothringen Admin](../README.md). This directory replaces
`tools/messaging`; the `messages*` package-script aliases and existing dedicated
credential path remain compatible.

`native.mjs` is the Flutter parent/child pipe entry point, `server.mjs` owns the
bounded authenticated loopback API, and `start.mjs` launches the legacy browser
console. `auth.mjs` isolates the operator account. All real sends use
`functions/src/inbox/operator.ts` and the existing Firestore transaction.

From the repository root, `corepack pnpm messages` opens the gold-only browser
workflow on port 8766; `corepack pnpm messages --port 8768` selects another port.
Keep its terminal open. Draft storage is browser/port-specific. The native Admin
app imports browser draft exports; the browser rejects item/skill drafts.
See the parent guide for credentials, recovery, testing and release boundaries.
