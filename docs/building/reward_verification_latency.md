# Reward verification latency

Status: `2026.10.11.1` deployed October 11, 2026; the exact final-image benchmark
and coordinated cutover passed. The owner accepted the two independently
reproduced terrain failures for this release; they remain unresolved. Target-device
measurements, representative route coverage and controlled end-to-end latency
remain open. See [production evidence](../verification/game-compat-2026.10.11.1-production.md).

Implemented contracts: [prepared navigation](../tdd/prepared_navigation.md) and
[reward completion](../tdd/reward_settlement_operations.md). The evidence below
records the original investigation; it is not a production performance claim.

## October 30 diagnostic instrumentation and dev rollout

The owner authorized code changes and the necessary dev deployment on October 30.
The worktree was clean at `dced382b` before this change. The reconnected phone now
has verified dev APK version code 3. The first backend image build was cancelled
to implement the owner's requested reuse of existing navigation artifacts.
See the [dev rollout evidence](../verification/reward-diagnostics-dev-2026-10-30.md).

Acceptance criteria: correlate each run across local replay save, durable spool,
grant/upload/finalize, task enqueue, validation lease/download/decode/simulation,
committed handoff/settlement, status polling, canonical refresh and account-value
paint (including XP catch-up). Use monotonic durations within a process, explicit
start/completion/failure and bounded diagnostic memory. Preserve gameplay,
authentication, revisions, retries, deletion fencing and once-only grants. Never
log credentials, player identity, signed URLs or replay contents.

- [x] Instrument client, Functions and worker; document timing semantics.
- [x] Verify failure isolation, hidden-route/animation observations and existing
  submission/settlement behavior; freeze diagnostic source `1d4799e7`.
- [x] Complete source-bound release preparation from the frozen checkout.
- [x] Automatically seed worker navigation from verified existing artifacts;
  document the requirement for every agent and validate release tooling.
- [x] Build and benchmark the final worker image.
- [x] Build and verify the instrumented dev APK.
- [x] Perform the guarded dev cutover and verify service/queue/board state.
- [x] Install after phone reconnection and verify package/hash and hub startup.
- [ ] Capture correlated live runs after the dev backend cutover; phone
  reconnection is required before starting the prepared capture.

The [initial phone evidence](../verification/reward-latency-phone-2026-10-30.md)
records two accepted runs before instrumentation. Local validation: Functions
build and all 282 emulator tests passed; validator analysis, 301 service tests,
97 final worker tests and executable compilation passed. Focused client state,
diagnostic and hub tests passed initially; a later import-formatting edit changed
the XP separator's encoding, which the repeated hub tests caught. The separator
was restored and all 11 affected widget/diagnostic checks passed.
Final client analysis is clean. A follow-up clears pending presentation traces
when AppState is disposed, with a regression test; all 12 submission-state tests
passed. The initial `5a7d66ca` preparation was stopped after its backend and worker
components passed and were cached. No cloud mutation had started. The final
`1d4799e7` candidate reused those unchanged components. All 1,363 client tests
passed; client, test and driver analysis was clean. The release web build and
built-artifact smoke check passed. Preparation completed at 17:33 UTC.
The frozen LF checkout's scope resolution confirms unchanged
simulation inputs and tuple `2026.10.21 / rules-v2 / score-v4 / ghost-v1`, with
Coordinated scope for the changed client/Functions/worker. Source digest is
`46cd44f99fba6f46b80a0cc3f6378bd9f395c77ccdb9a6d3eaa4b2add2dd1b47`.
The prepared checkout is `.tmp/release-checkouts/1d4799e7866ab3f1ca7cb2dd8be13a8929dbe47b/`;
its source-bound evidence is `.tmp/releases/rpg-runner-d7add/<source-digest>/`.
Cloud Build `293d71e1-ee58-4d24-a2cf-b405514277db` started at 17:34 UTC and was
confirmed cancelled at 18:00 UTC after the owner identified redundant navigation
generation. The generator already validates/reuses exact-key pieces, but the
Docker recipe had supplied an empty directory. The correction seeds the current
producer from the selected environment's previous verified immutable image,
retaining source/key/digest checks and the final-image benchmark. The isolated
implementation is committed as `b58ac324`; the same validated patch is committed
on the shared branch as `427e811a`. Root/scoped agent guidance now defaults to
verified reuse of all artifacts and test evidence, not only navigation.
The new frozen backend candidate is `b58ac324dda44c86aa844fe6636f08486de8cae6`,
excluding concurrent achievement changes; source digest
`14388b2491269fe4e76795c068d252256da87c1ead3be0fd4211bd20504f9b3e`.
Its preparation completed at 18:30 UTC, reusing nine component records. The
changed worker component passed analysis, 301 tests and executable compilation
in 89 seconds. Replacement Cloud Build `f1413136-2e1b-4359-8619-dc3800608b22`
started at 18:31 UTC with the verified previous dev navigation pack.
Its producer verified/reused all 93,910 graphs and built zero, in 129.215 seconds.
The image build succeeded at 18:40 UTC; all eight strict final-image benchmark
gates passed (one CPU, 512 MiB, 36,000 ticks per level). The immutable digest is
`sha256:45d6d0a00fe563464c9ca9ab89748bad7befad18ee8f53d073013a8fbf23908e`.
Release helper, integration, cache/image and environment isolation checks passed
under PowerShell 5.1 and 7.6.9, and agent guidance/link checks passed. These are
mocked release checks, not deployment evidence. A live read-only lookup verified
the previous dev image's build/benchmark provenance for the navigation seed.
The diagnostic candidate's dev Android build completed and passed verification at
17:49 UTC with version code 3. Installation and on-device artifact-hash checks
passed; the hub retained 3,149 gold and level 2, 32/124 XP.
The new candidate's `android-reuse.json` proves matching Android inputs,
Flutter/Java toolchain, environment/package and artifact hash, retaining the
original signing/native-inspection provenance. The existing APK is reused.
The main working-copy Plan's earlier simulation mismatch was line-ending drift
against the LF baseline; no compatibility bump or gate override was needed.

Live read-only inventory at 17:37 UTC found nine accepted/settled runs, no pending
settlement, and three issued tickets with no uploaded replay, validation or
reward grant. The ordinary coordinated-cutover drain gate rejects issued tickets.
The 18:32 UTC read-only review found five issued tickets, including two created
since that inventory. All five lack uploaded replay/lease/validation/grant
evidence; their expected replay objects returned 404. This cannot rule out
unsubmitted local play. Their IDs and update timestamps are retained in
`.tmp/reward-issued-review.json`.
After artifacts passed, the owner explicitly approved cancelling exactly those
five tickets and completing the dev deployment. Issuance was paused; a fresh
review verified the exact set. The guarded transaction cancelled all five at
18:52:47 UTC. Verification confirmed every other session, grant, validated run
and both account profiles unchanged, including a repeated check after backend
deployment. Functions, worker and Hosting were deployed by 19:03 UTC; issuance
resumed at 19:08:32 UTC. Final live checks confirmed all 32 Functions active,
the exact-image worker revision `replay-validator-00062-hml` Ready at 100% traffic,
both queues RUNNING, all three current boards valid, all nine settled grants
retained and 3,149 canonical gold. The issuer's healthy serving revision has no
pause override; the verified baseline and normal lock cleanup are recorded.
The phone was reauthorized during deployment but disconnected again before
capture; no instrumented end-to-end run or latency improvement is claimed yet.

## Recommendation

Use trusted, prepared navigation artifacts with a rotating Practice seed pool,
and make pending reward completion an app-owned background operation. Preserve
the existing ranked seeds and prepare their artifacts before each board opens.
Build navigation graphs on demand on the server when prepared data is missing.

The expensive part is navigation graph construction, not decoding authored
terrain or writing gold. Restricting seeds without preparing and loading graph
data would leave the current work unchanged. Conversely, a shared artifact
format can accelerate matching terrain with any seed; a curated pool makes
preparation coverage and route QA manageable.

Source defaults are 16 Practice seeds per level, 128 worker chunks and an
eight-chunk client prefix at 60 Hz. These are preparation horizons, not run-length
caps or exhaustive coverage guarantees. Missing selections use the deterministic
builder. Ranked seed authority is unchanged; explicit current/next windows are
prepared for the release tuple. Pool/horizon expansion requires coverage and
size measurements.

## Evidence

The performance probes use the deployed `90d1becc` source and one accepted
Forest replay: seed 1776486020, 60 Hz, 20,867 ticks, 79 terrain publications.
Current HEAD and concurrent local gameplay/content edits were excluded. This
is Windows AOT diagnostic evidence, not a phone or Cloud Run performance claim.

| Experiment | Simulation time | Graph work |
| --- | ---: | --- |
| Original construction, with candidate retention for later reuse | 25.404 s | 79 newly built candidates |
| Repeat with every candidate already in memory | 0.826 s / 0.866 s | 79 hits, zero builds |
| Original construction, instrumented graph usage | 25.926 s | 790 graphs built, 107 requested |
| Experimental on-demand graph construction | 7.157 s | 107 graphs built and requested |

Construction outside the simulation loop took 0.030–0.158 seconds across these
experiments; decoding the replay took 0.054–0.080 seconds. Earlier repeated
original-source runs measured 27.8–33.4 seconds. Timing varies with desktop load.

The graph-usage probe attributes 25.087 seconds to graph construction, of which
6.585 seconds belongs to graphs that the simulation requested. Approximately
18.5 seconds built unused profile views. All ten profiles are currently built
for every terrain publication, including absent enemies and NPCs. The rest of
candidate construction is small in this sample: about 0.065 seconds across all
79 candidates, excluding the graph work.

Cold and cached passes matched final tick, death reason, distance, geometry
version, gold (75), rescue points (2,500), rescued NPCs (10), and kill counts.
The on-demand probe matched final tick, death reason, distance and geometry
version. These diagnostics do not establish full state equivalence, safe cache
invalidation, cross-platform parity or production readiness.

The reuse probe retained all candidates from the same exact replay/configuration
inside one process. It did not test a persistent artifact codec, network access,
eviction, another character, a different input sequence or another seed. Its
diagnostic key is deliberately insufficient for a production cache.

The 790 graph views contain 270,470 edges. Their canonical diagnostic text was
86.7 MB, compressing to 5.4 MB as one stream. This is neither a production binary
format nor the size of a complete terrain pack. Collision/render data is omitted;
independently compressed pieces can differ. Process RSS varied substantially
during serialization and is not an isolated cache-memory measurement.

Five accepted Practice submissions after the October 11 release reached the
durable handoff in 9.892, 26.013, 26.052, 18.744 and 46.599 seconds. Successful
gold settlement logs followed the handoff logs by 0.46–0.87 seconds. The last
four task traces dispatched approximately 10–15 ms after scheduling, without
retries. Four correlated instance starts took about five seconds to reach the
startup probe's success log; one request also waited about 17 seconds before
its instance-start log. These are samples, not representative percentiles.

For the latest sample, the wallet settled roughly 4.4 seconds before the next
status request. The client switches from one-second to five-second polling
after ten seconds. Upload and callable cold starts remain additional costs;
one observed finalize callable request lasted 5.1 seconds. Subsecond simulation
does not imply subsecond game-over-to-wallet latency.

Local probes, extracted source and raw timing JSON are under
`.tmp/reward-verification-2026-10-11/`. The baseline binaries were compiled
before the later lazy-construction experiment changed that temporary source.
Reproduction must restore the stated source/experiment variant before compiling.
Raw replay data stays outside tracked documentation.

## Seed pools and coverage

At the diagnostic baseline, Practice issuance used a fresh random seed;
competitive and weekly tickets took their seed from the immutable board manifest.
Both client and
worker use Core's terrain candidate builder. The game's preparer has a bounded,
run-owned cache; it is not a server cache or persistent content artifact.

Forward-camera enumeration using the deployed selector, seeds 1–32, 600-unit
viewport and a 128-chunk prefix produced:

| Level / pool | Exact windows, including positions and indices | Ordered chunk windows, ignoring position |
| --- | ---: | ---: |
| Forest / 16 seeds | 2,375 | 2,048 |
| Forest / 32 seeds | 4,583 | 3,816 |
| Field / 16 seeds | 2,907 | 120 |
| Field / 32 seeds | 4,313 | 167 |

Each tested seed had a distinct first-12-chunk route within its level. This
does not measure perceived variety or validate traversal difficulty. The
enumeration does not simulate combat, encounters or boss retention. It is a
planning inventory, not a proof of complete reachable terrain-state coverage.

Runtime publication depends on the exact active selection. Spawn/cull ordering
has boundary cases, ticks can skip projected states, and the API permits
encounter/boss retention. The measured replay and ordinary forward projection
used at most five chunks per selection. Encounter expiry currently aligns with
the default trailing margin, and boss arenas stop the camera; do not infer an
unbounded state explosion from retention alone. Prove the supported bounds and
cover actual retained and released states before issuing prepared-only routes.

Forest repeats its final section with fresh seeded choices; other assemblies
can repeat their full composition. A finite seed list therefore does not mean
a finite set of all future world-positioned artifacts. A 128-chunk pack cannot
be described as covering an endless run. Preserve an explicit fallback for
uncovered continuation while tracking misses. If a hard guarantee that every
terrain state is prepared becomes a product requirement, evaluate fixed tail
loops per course or a finite course finish as separate gameplay changes.
Neither change is necessary for the initial background-reward experience.

## Original architecture recommendation

1. Keep authored geometry and deterministic route selection authoritative in
   Core. Build cheap world geometry, surfaces and lookup structures normally.
   Separate immutable navigation graph materialization from that cheap work.
   The worker can request a missing profile on demand. Interactive gameplay
   must still have every graph it needs ready before stepping; never transfer
   a cold graph build onto the Flutter frame path.
2. Generate navigation graph artifacts from trusted release content and exact
   profile/tuning inputs. Preserve the existing graph algorithms and canonical
   output. A new codec should store compact node/edge data, not the diagnostic
   text used for the size experiment.
3. Identify each artifact by content/compiler/graph-format versions, exact
   ordered chunk identities and placements, surface signature, tick rate, and
   all movement/collision/support/profile inputs that affect construction.
   A seed or chunk filename alone is insufficient. Bind the published manifest
   to the ticket's release/route identity and a trusted digest. The server must
   not admit player-supplied graph bytes merely because their own hash matches.
4. Publish immutable, bounded artifact pieces. Preload the initial pieces during
   existing hub/ticket warmup, then fetch ahead into a bounded memory/disk cache.
   Load only the selected course's needed pieces on the phone. The worker shares
   trusted pieces across runs and can use a small hot set plus durable storage.
   Persisted artifacts must survive instance replacement; an in-process map is
   only an acceleration layer. Cache static graph data, never actor/run state.
5. Introduce the Practice pool only after the codec and loader demonstrate their
   value. Issue only routes whose required initial artifacts are published and
   validated. Prepare current/next ranked boards before opening them. Retain old
   artifacts for still-valid tickets and ghost compatibility, then garbage
   collect by the supported-version policy. Update both sides of any ticket
   manifest binding in `run_protocol`, Functions, client and worker together.
6. Use exact world-positioned artifacts first. Reusing local graph templates
   across translated/repeated chunk windows could greatly reduce storage,
   especially for Field. This needs explicit coordinate and source-ID remapping
   and parity proof for node ordering, tie-breaks, contacts and trajectories.
   Do not implement it by dropping positions or instance indices from the key.

## Player experience and operational latency

Game-over already permits Restart/Exit after durable replay journaling; it does
not require a verified reward. Keep that behavior. Score collection is a visual
flow, not payout authority. Show pending reward context clearly and allow the
player to move on. Once the server settles, refresh canonical ownership and
notify the player in the current screen without interrupting gameplay. Pending
gold remains unspendable, and retries must never produce another payout.

Move retry/completion ownership into the app's authenticated session lifetime.
At the diagnostic baseline, the periodic status timer was run-widget-owned and
stopped on dispose; initial app warmup performed a pending-submission pass. No continuous
app-owned completion watcher was found. Resume/later canonical refresh can
catch up, but leaving Game Over should not be the reason a wallet stays stale.

Begin with one centralized, quota-aware foreground scheduler using existing
callables. Do not create one one-second timer per historical run: `run_status`
allows 120 calls/minute and 5,000/day per user. Deduplicate requests, prioritize
recent completions, back off delayed submissions, suspend inactive polling,
resume from the durable spool, and fence sign-out/account-deletion late results.

A minimal owner-readable receipt stream is a later option if polling cost or
latency warrants it. Current Firestore rules do not expose these internal
documents. Do not simply attach a listener to `run_sessions`. A projection would
need scoped rules, a minimal payload, terminal consistency and deletion cleanup.
Firestore supports low-latency snapshot notifications, with reads billed for
document changes and some reconnects: [realtime query architecture](https://firebase.google.com/docs/firestore/real-time_queries_at_scale)
and [listener billing](https://firebase.google.com/docs/firestore/pricing).

Shorten the worker startup-probe interval while preserving its startup allowance
and a valid timeout/period relationship. Google's [probe contract](https://docs.cloud.google.com/run/docs/configuring/healthchecks)
permits a one-second period. Measure before attributing every cold-start second
to that interval. Keeping a worker warm may help after the CPU work is removed,
but is a cost decision and does not guarantee that an instance never restarts:
[minimum-instance behavior](https://docs.cloud.google.com/run/docs/configuring/min-instances).
Measure upload-grant/finalize/status/ownership Functions as well as the worker.

## Alternatives considered

| Approach | Decision |
| --- | --- |
| Trust terrain uploaded by the phone | Reject as authority; it would allow altered navigation/collision to support a false replay. Trusted manifests/artifacts are different. |
| Use a fixed seed list without a prepared artifact loader | Insufficient: the current worker still rebuilds the same graphs. |
| On-demand graphs only, keep unrestricted seeds | Good first milestone and fallback: this sample improved to 7.2 s, but remains materially slower than prepared reuse. |
| Warm server memory cache only | Useful hot layer; cold instances and first-seen routes still pay construction cost. |
| Prepared graphs plus curated routes | Recommended target for predictable common-case latency, content QA and controlled preparation cost. |
| Validate continuously while the player runs | Defer: requires incremental uploads, authenticated ordered segments, checkpoints, recovery, lease changes and offline handling. Much larger change than removing graph construction. |
| Incremental graph rebuilding across changing windows | Promising longer-term way to preserve unrestricted variety, but proving trajectory/neighbor invalidation is more complex than reusing complete trusted graphs. |
| More CPU or parallel graph workers | Secondary: more cores do not accelerate the existing serial loop by themselves; parallelization and memory/cost measurements are required. |

## Implementation and remaining rollout gates

- [x] Trace deployed delays; compare on-demand and exact prepared reuse.
- [x] App-owned foreground queue, global spacing/backoff, account fencing,
  durable terminal receipts and once-only canonical acknowledgement.
- [x] Eager live/on-demand replay boundary, trusted bounded codec/manifest,
  worker LRU and packaged client loader with deterministic fallback.
- [x] Curated Practice issuance with transactional no-repeat history and
  idempotency; explicit ranked seeds from the unchanged production algorithm.
- [x] Offline preparation, source fingerprint, Docker/web release integration,
  cache invalidation, matched `2026.10.11.1` tuple and startup-probe configuration.
- [x] Implemented TDD/GDD and embedding API documentation.
- [x] Exact final-image one-CPU/512-MiB gate; all nine checks passed in the
  production image build. This is a limited throughput fixture, not full-run combat.
- [ ] Target-phone measurements.
- [ ] Representative full-run coverage for every curated route, both characters,
  loadouts, bosses and retained/skipped selections. The finite artifact inventory
  is not proof that every selection is a hit; fallback remains mandatory.
- [ ] Resolve the two authored-terrain traversal failures. The owner accepted
  them only for the `2026.10.11.1` release; normal test gates remain unchanged.
- [x] Authorized coordinated cutover; Functions, worker, Hosting and all six
  boards verified, queues and issuance restored, all 204 settled runs preserved.
- [ ] Controlled live acceptance, once-only settlement, background wallet
  catch-up, leaderboard/ghost independence and cold/warm timings.

The provisional warm-service target remains p95 below three seconds from durable
finalization to visible verified reward for the declared prepared workload.
Game-over-to-reward also includes journaling, upload and cold callables. Neither
this target nor target-phone/container performance is established by local probes.

### Local implementation evidence

Focused checks passed: 32 client lifecycle/asset checks (including targeted
retries), 20 Core codec/determinism checks, 102 worker checks and 19 backend
issuance/compatibility checks. Release tooling passed 30 helper, 25 integration
and 45 cache/provenance checks under each of Windows PowerShell and PowerShell 7.
These release checks use mocks. Targeted analysis is clean.

The final client pack contains 2,980 graphs / 17,912,751 bytes. A complete
128-chunk inventory with the initial ranked-window seed set measured 60,600
graphs / 240,210,430 bytes in 35 minutes locally. Its source fingerprint and
ranked seeds preceded final formatting/compatibility cleanup; this is sizing
evidence, not the final deployable image. The final producer and fingerprint were
checked with the complete client pack and a 16-chunk worker pilot. The image
build must generate the final 128-chunk pack from its frozen source.

The actual Core/pilot smoke run for Field seed 1 at 60 Hz requested 40 graphs,
all hits with zero invalid pieces, for each character over 1,800 ticks. Eager and
prepared outcomes matched exactly. The Forest smoke input fell into a gap before
requesting graphs; it provides no Forest hit-coverage claim. The eight-chunk
client prefix can finish before the first requested AI graph on some routes;
its purpose is live eager startup preparation, not long-run server coverage.

The digest-verified historical Forest input was replayed against current authored
terrain, so it ends earlier (7,866 ticks, fellBehindCamera) than the historical
accepted run. Comparing all variants against the same current eager Core gives
identical termination, distance, collectibles, kills, rescues and terrain version:
15.18 s eager construction+simulation; 6.48 s on demand; 0.85 s prepared cold;
0.83 s prepared warm. The 44 requested pieces occupy 829,988 bytes. Decode of the
replay itself took 100 ms. This capture measures exact codec reuse, not coverage
of the release seed pool, and is not evidence of server acceptance.

The compiled 36,000-tick fixture passed for all three compiled levels. Its Forest
actor remained near the opening (geometry version 1); Field/new_level reached
version 190. It is a no-ambient-enemy throughput fixture, not full combat coverage.

Traversal: 105 checks passed; two failed with current authored terrain. Both were
reproduced at identical ticks/positions with the pre-change Core navigation code:
Forest Derf seed 2026 stalls at tick 9,400 in trainingcamp_hard_004 (76-chunk route),
and the four-chunk hard-ruin-to-grove Grojib seed 42 fixture falls at tick 390.
The authored edits were already present and were preserved. Matrix coverage is
Forest's finite assembly plus 32 Field/new_level chunks, seeds 7/42/2026 and the
four mobile enemies; arena bosses and full player/combat flows are separate.

Logs and local probes remain under `.tmp/navigation-*` and
`.tmp/reward-verification-2026-10-11/`; they contain historical local input and are
not release artifacts. These local measurements preceded the production rollout
linked above. No warm-instance billing change was performed.
