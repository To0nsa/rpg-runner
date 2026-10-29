# Shared tools and Admin

## Ownership

| Owner | Contract |
| --- | --- |
| `packages/tool_ui` | Flutter tool theme, spacing/radius tokens, panel/section/list/workspace cards, visual catalog controls/cards and persistent responsive three-panel layout |
| `packages/game_presentation` | Game icon renderers, atlas coordinates, names, Core-backed catalog presentation and typed gift display values |
| `tools/editor` | Existing authoring routes, sessions, undo/history, validation and explicit repository writes |
| `tools/admin` | Operator compose/catalog/review workflow, durable drafts and local-service lifecycle |
| `functions/src/inbox` and `ownership` | Validated gift issuance, retention, atomic claim and canonical ownership |

Shared primitives have neutral `Tool*` names and one implementation. Editor
consumers import `package:tool_ui/tool_ui.dart`; authoring controllers, dialogs
and draft semantics remain editor-owned. Game consumers import
`package:game_presentation/...`; neither shared package imports `rpg_runner`,
Firebase, editor routes or Admin state. Core remains pure Dart. New abstractions
should follow an actual second consumer rather than pre-emptive modularization.

Admin is a member of the root Pub workspace, using its one lockfile. Editor
remains independently resolved and points to the same shared packages. Art stays
in canonical `assets/images`: the game bundles it; Admin's contained, read-only
`RepositoryAssets` supplies it through `DefaultAssetBundle`. Fonts/manifests use
the Flutter app bundle. Resolved paths cannot escape the art directory. There is
no copied icon tree or alternate name/ID registry in Admin. Image listeners
follow the consumer's asset bundle and release their image handles on replacement.

## Operator lifecycle

The Windows app starts a Node child from the same checkout. Its launch script
first compiles Functions. The service sets its dedicated ADC before importing
Firebase, rejects emulator overrides in real mode, and binds to an ephemeral
loopback port. A single JSON pipe handshake carries protocol version, origin and
random bearer token. Flutter accepts only a loopback origin, bounded responses
and its four known endpoints. Tokens are memory-only, never a game credential or
editor session. EOF on the parent's pipe closes the child; the app also closes
its own service on disposal. The parent never kills unrelated Node processes.

`GET /api/environments` supplies the registry and operator account.
`POST /api/catalog` takes only an environment and reads its gift capability gate.
`POST /api/preview` freezes a normalized message in local memory.
`POST /api/send` accepts only that preview ID. Host/origin/token checks and limits
apply equally to the browser and native app. Preview lifetime, pending-request
coalescing and backend idempotency are defined in [system inbox](system_inbox.md).

The controller fences late catalog responses by generation and clears gifts on
an editable environment switch. Edits invalidate review. A send first persists
`attempted: true`, then locks identity/destination/contents. Persistence failure
prevents network send. Response identity, destination and content must match the
draft before confirmation. A lost response remains retryable with the same ID.
The single draft file uses serialized flushed temporary writes followed by file
replacement; an exclusive per-user Windows file lock prevents competing app
instances. Draft exports preserve retries; imported success receipts are ignored.
The fixture has separate storage, an explicit offline banner and no cloud access.

## Gifts and release activation

The operator catalog is derived from the existing store definitions, including
gear, abilities and projectile spells. Dart resolves every returned entry against
Core definitions and shared presentation. Backend validation is authoritative.
Existing skills are granted to an explicit `eloise` or `eloiseWip` recipient;
selection changes before claim do not retarget them. Gear is account-wide.
There are no quantities, arbitrary items or client-supplied ownership patches.

Gold-only messages remain schema 1. Catalog attachments use schema 2 with up to
eight unlocks and optional gold. The claim transaction reuses
`grantCatalogOwnership` from store purchases. Already-owned unlocks are no-ops,
with no compensation; explicit gold is still credited once. Claims refresh store
offers against current ownership without equipping or charging. Atomicity,
revision, command retry and deletion guards apply to the whole attachment list.

Each environment requires a privileged `inbox_configuration/gifts` document:

```json
{ "schemaVersion": 1, "enabled": true, "catalogHash": "<current compiled catalog hash>" }
```

The hash binds reward schema 2, the allowlist and supported characters. Missing,
disabled or mismatched configuration hides the catalog and blocks new schema-2
issuance inside the transaction. Existing identical delivery retries and claims
remain valid when issuance is disabled. Direct clients cannot read/write the gate.
A local preview is not compatibility evidence and cannot enable gifts.

For an **authorized staging/prod release**, deploy the schema-2 readers/claim
handlers and receipt-aware issuers first; release the compatible game client and establish
that older clients cannot access schema-2 inboxes (required-update rollout plus
supported-client acceptance). Rebuild/restart privileged tools from that same
source. Generate the exact activation record offline with
`node tools/admin/service/catalog.mjs --activation-record`. Only then publish
that record to the explicitly selected project's document through the authorized
release operation, recording source, client version, project and live checks.
This implementation does not publish the record or authorize a deployment.

For controlled dev use, the owner may explicitly authorize activation after
matching backend deployment and compatible client installation are verified.
Use that compatible build for every gift recipient. Minimum inbox-client version
enforcement is not implemented, so this dev activation does not establish
older-client exclusion or satisfy staging/prod acceptance. The
[October 29 dev activation](../verification/admin-dev-gifts-2026-10-29.md) records
the exact source, installed build, configuration and live catalog readback.

Changing the catalog hash requires renewed rollout evidence. Do not retire IDs
or decoders while retained gifts may reference them. Disable new issuance before
rollback; do not roll back schema-2 readers while schema-2 messages remain.

## Verification

Backend emulator tests exercise real issue/claim/ownership/retention transactions
and client-denied configuration. Service tests cover identity isolation, immutable
previews, HTTP boundaries and uncertain retries. Admin tests run the real child
service in fixture mode, restart draft state, reject persistence/receipt failures,
fence late catalogs, render the backend catalog with canonical art and exercise
wide/narrow compose/review/send. Game tests cover schema decoding, gift-only UI,
claims, removal protection and existing inbox races. Shared extraction also runs
editor regression tests. Local fixtures and executable builds establish no live
project state; rollout remains separate.

See the [local verification record](../verification/admin-tools-2026-10-29.md),
including the editor failures reproduced before this change.
