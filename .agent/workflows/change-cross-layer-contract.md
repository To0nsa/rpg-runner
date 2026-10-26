---
description: Change shared payloads or persistence across client, Functions and replay validation
---

# Change a cross-layer contract

Use for run/replay/board payloads, callable APIs, ownership/persistence,
settlement or projection changes. Read each affected owner's instructions from
the [routing index](../README.md). Local UI-only changes do not require every layer.

## Trace the contract

1. Find the actual producer, decoder, value object, storage representation and
   consumers. Check TypeScript validators, Dart constructors/codecs, client
   adapters, worker repositories and existing fixtures; do not assume one shared
   Dart type defines the TypeScript contract.
2. Specify absent/null/default behavior, numeric bounds, versioning, canonical
   serialization/digest effects, and compatibility with retained data. Identify
   retry, deletion, revision and idempotency behavior when persistence changes.
3. Choose a compatible additive change or an explicit migration/coordinated
   compatibility release. Record required deployment ordering without deploying.
   Old plans or an implementation request alone do not authorize cloud mutations.

## Change the owning layers

- `packages/run_protocol` owns shared wire values and codecs, not gameplay or
  Firestore persistence. Validate direct construction as well as JSON decoding.
- `functions/src` owns authenticated callables, ownership mutations and settlement;
  preserve auth/UID checks, revisions, payload hashing and retry idempotency.
- `services/replay_validator` owns replay acceptance and projection. Keep leases
  token-fenced, replay evidence generation-pinned, and canonical wallet writes
  in Functions settlement.
- `lib/ui/state` owns client adapters and local orchestration; update the consuming
  UI flow and errors when the payload changes. Widgets do not become persistence owners.
- Change Core only for gameplay authority, and apply the
  [simulation](change-core-simulation-contract.md) or
  [output](change-core-output-contract.md) workflow when relevant.

Finish the migration across affected layers in one coherent change. Update
fixtures and implemented TDD/GDD contracts; keep outstanding rollout work in one plan.

## Prove the boundary

Use focused checks in each affected layer with the working directories in
[validation routing](../README.md#validation). Exercise an actual producer-to-
consumer payload and malformed input, not only isolated JSON round trips. Test
retry/revision/deletion cases where the changed invariant depends on them.

When runtime constructor validation changes, extend/run the protocol AOT probe
required by [protocol instructions](../../packages/run_protocol/AGENTS.md).
When tick/replay fields change, include a non-default tick-rate case. When
canonical payloads change, verify digest stability or the intentional version
transition. Build Functions after TypeScript edits. Distinguish local/emulator
evidence from live rollout checks in the handoff.
