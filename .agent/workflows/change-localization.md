---
description: "Add or change player text, translations or language behavior without changing gameplay identities."
---

# Change localization

1. Read the [localization contract](../../docs/tdd/localization.md), owning
   instructions from the [routing index](../README.md), the
   [authoring recipes](../../docs/localization.md) and
   [glossary](../../docs/localization-glossary.md). Check the
   [planning index](../../docs/building/README.md) for active work. Technical
   literals and historical fallbacks do not permit new hardcoded player text.
2. Identify the owner: app UI resources for app-only messages, shared
   `game_presentation` for reusable catalog presentation, backend inbox contract
   for persisted/operator messages. Compose
   [cross-layer changes](change-cross-layer-contract.md) for wire/persistence work
   and [shared tool changes](change-shared-tools.md) for game/Admin consumers.
3. Author English source text first, with semantic keys, translator context,
   placeholder types/units and examples where ambiguity matters. Supply French
   using **tu**. Preserve canonical names and accents. Keep full sentence grammar
   in messages; do not concatenate translated fragments, derive display names
   from IDs, or replace words in an already formatted sentence.
4. Pass gameplay numbers as parameters and locale-bound resources to presenters.
   Localize presentation formatting, never wire serialization, hashing, gameplay
   calculations or user-authored names. Locale changes must preserve live runs.
5. Run `dart run tool/localization.dart generate` at the root. Resolve
   dependencies only at the root workspace. Inspect ARBs and generated diffs
   together; do not edit generated Dart or copy app text into shared dependencies.
6. Run focused language/state/presenter/widget tests for the actual affected
   surface. Include compact layout, longer text and accessibility labels where
   relevant. Run `dart run tool/localization.dart check` for source/translation
   keys, placeholder parity, generated freshness and hardcoded-text detection.
   Exemptions must be exact technical literals with a reason, not file ignores.
   A successful generator alone does not prove French coverage or readability.
7. Update the implemented contract and contributor documentation when ownership,
   fallback, persistence or authoring changes. Record local versus device/live
   evidence separately. Run `node tools/agents/check.mjs` after guidance edits.

## Coordinating larger migrations

Use the [coordination workflow](coordinate-work.md) and one checklist. The
coordinator owns resource/API contracts, shared generated outputs, integration
and evidence. If the session separately authorizes collaborators, partition by
surface/owner, serialize shared ARB and generator writes, and require handoffs
with keys, files, placeholder decisions, checks and untranslated residuals.
This workflow does not start agents, select models or authorize delegation.

| Work packet | Inputs and owned output | Integration proof |
| --- | --- | --- |
| Resources and terminology | Source keys, full sentences, glossary, placeholder contract | Locale parity, generated check; source/translation review |
| App surfaces | Assigned widgets/presenters, shared resource API | Compact layout, enlarged text, semantics, live locale rebuild |
| Shared catalog | Catalog IDs and Core values, shared ARBs and adapters | All supported IDs/languages; game and Admin consumers |
| Inbox | Versioned envelope and immutable retry contract | Producer-to-client fixture, legacy hash, claim/delete retries, operator receipt match |
| Integration | Shared generation, docs, source gate and final diff | Targeted suites, visual evidence and explicit device/live limits |

Assign one writer per shared resource bundle at a time. A handoff includes keys,
placeholder types/units, canonical names, edited files, exact commands/results,
screens reviewed and any English fallback still visible. Reconcile actual diffs
before integrating; do not use a collaborator's summary as validation evidence.

Before finishing, inspect indirect text sources: enums/catalog fallbacks,
loading/failure states, tooltips/semantics, dynamic descriptions, rich-text
highlights, saved default labels and server messages. Preserve immutable legacy
inbox bytes and hashes; never translate persisted deliveries in place.
