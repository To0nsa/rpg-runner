# Android beta release with dev, staging and production

Status: executing, October 26, 2026. This is the
active checklist for reusing the existing project for development, creating
isolated staging and production backends, and releasing an Android beta through
Google Play. Team expansion and internal release-candidate testing make staging
part of this workstream now, including before the first production beta.
Prefer the smallest implementation that provides reliable isolation and routine
releases. A second Firebase registration in the same project is not environment
isolation.

The agent will perform repository work, CLI operations and console configuration
through the user's connected Chrome session where no suitable CLI/API exists.
The October 26 execution request authorizes project/configuration/signing/CI
setup, use of the existing billing account, deployments, maintenance/pause/resume,
and internal/closed Play publication. Public rollout remains excluded. Complete
reviewable preparation and retain all non-waived acceptance gates.

## Execution checkpoint - October 27, 2026

- Starting source: `f0aa66d8`; the only initial worktree edits are this plan and
  its links in `docs/README.md` and `docs/building/README.md`. Preserve them as
  part of this workstream. No staged or unrelated source changes were present.
- CLI access verified for the existing Lothringen operator and GitHub account.
  Chrome extension inventory is empty, but Windows Computer Use now controls the
  signed-in Chrome window. Play Console inventory is recorded below.
- Live inventory corrects the planning baseline: the existing project's worker
  is `replay-validator-00058-94k`, with both replay queues RUNNING. The latest
  documented deployment is gameplay `2026.10.21` on October 25. Historical
  records remain attached to `rpg-runner-d7add`.
- User explicitly waives level pathfinding, enemy traversal, navigation quality
  and related content-test failures for this release only. Record exact failures;
  keep build/assets/auth/isolation/replay-integrity/deployment gates strict.
  No failure has yet been waived or relabeled as passing.
- Environment registry, explicit mutation selection, project resource checks,
  project-derived Functions identities and dev-only Hosting are implemented.
  The Functions build and all 257 emulator tests pass. Isolation helper tests
  pass on PowerShell 5.1/7; the six-case mocked routing matrix also passes
  (87 dev checks, 82 staging and 82 prod on each PowerShell version).
- Fresh inventory at `2026-10-26T20:36:13.893Z` found one player, 469 accepted
  validations and 469 settled grants, zero pending/quarantined settlement.
  Preserve the recorded historical orphan/ghost findings; they are not new
  environment state or permission for an unrelated cleanup.
- Routing milestone committed as `c1d11dbd07803e2545683221fac15f76a917b69a`.
  Empty-target bootstrap is implemented and validated on PowerShell 5.1 and 7.
- Created `lothringen-long-run-staging` (943085064373) and
  `lothringen-long-run-prod` (696550437718), linked both to the existing Firebase
  Payment billing account, and renamed the existing project's display name to
  `Lothringen Long Run - Dev`. Firebase and Auth are initialized on both new
  projects, with isolated Firestore, replay/build buckets, registry, service
  accounts and paused task queues. Monthly alert budgets are EUR25 staging and
  EUR50 prod; these are notifications, not spending caps. No new game backend
  or Android artifact is deployed.
- Play account is Personal. Existing Long Run app ID 4975420968170292531 has an
  inactive internal track, empty draft and no bundles in its library. Internal
  testing is available. Public access requires 12 testers for 14 continuous days;
  Console currently reports zero opted-in testers. Closed-track setup is pending.
- Owner reconsidered the overhead and explicitly reconfirmed all three
  environments for independent candidate testing during execution.
- Store audience confirmed by owner: Finland, ages 16+, public support and
  account-deletion contact `lothringen.rpg@gmail.com`; initial internal tester is
  the existing owner account. This audience choice does not replace IARC ratings.
- Provisioning is repeatable through `release.ps1 -Action Provision`; 30 mocked
  checks pass on PowerShell 5.1 and 7. Live existence-only Auth/Firestore checks
  confirm both new environments are empty. Worker URLs use the documented
  project-number format; actual service readback awaits deployment.
- Android flavor/resource generation passes for dev debug/release and staging/
  prod release. Nineteen focused environment/startup tests and targeted analysis
  pass. Signing, Play Games linkage and device acceptance remain pending.
- Play rejects `com.example.rpg_runner.staging` as already in use. It confirms
  `com.lothringen.longrun.staging` is available; created its separate Long Run
  Staging listing, app ID `4975698862921375548`. Update the new Firebase/native
  registration before uploading. Preserve the existing working dev identity.
- The previously staged auth/account-deletion work is now commit `f5075eed`.
  Preserve it as intended source and revalidate integration before freezing.
- Foundation milestone committed as `2e272c40`. Staging now uses the genuine
  Firebase registration for `com.lothringen.longrun.staging`; its separate Play
  Games project is linked to `lothringen-long-run-staging`. OAuth consent and
  credentials remain pending after browser control lost URL verification.
- Separate staging/prod upload keys are backed up in each project's Secret
  Manager. Readback and repeated setup preserve the same certificates. Google
  Play distribution signing remains pending; upload keys are not that identity.
- Signing milestone committed as `f3d1c471`. Android artifact inspection is
  implemented and passes on a real dev APK (API 36, all 3,750 navigation graphs,
  expected Firebase/Play IDs, three ABIs and 16 KB alignment). This is an
  uncommitted-source probe, not the frozen release candidate. The initial native
  build failed because `--no-pub` retained a test-only plugin registrant;
  enabling Flutter's normal release regeneration resolved it.
- Managed PITR and daily seven-day backup schedules are configured/read back in
  staging/prod. First scheduled backup completion is not yet verified. An isolated
  synthetic dev database restore completed in 11m09s and passed duplicate-reward
  and deletion-barrier checks. Both rehearsal databases were cleaned up and live
  inventory shows only the untouched default dev database. Full-service recovery
  and the first scheduled backup remain separate, unverified checks.
- Crashlytics dependency/handlers pass 21 focused startup/diagnostic tests and
  targeted analysis. Native AAB integration hit Gradle native-memory exhaustion;
  retry with bounded memory/workers passed, as did full AAB inspection. No live diagnostic event or
  readable release report is verified yet.
- Structured maintenance/update responses and the client release gate pass 25
  focused tests, 35 startup/recovery tests and all 259 Functions emulator tests.
  These are local checks, not Play/device acceptance or a deployed change.
- Operation locks and source-bound maintenance ownership pass 13 focused checks
  and 97/92/92 dev/staging/prod entry-point checks on PowerShell 5.1/7. Monitoring
  setup is partial and final reconciliation is running. The new channels omit
  verification status, which the documented API treats as usable; an unnecessary
  verification request was withdrawn. Approval review
  rejected cross-project verification copying; it was not executed. The owner
  was also asked for the legal operator name/country needed for public privacy
  information. OAuth/Chrome resumption remains pending.
- Android/runtime milestone committed as `aac4d7f6`. Required final tooling
  matrix passes (50 syntax, 50 cache, 29 isolation, 11 artifact, nine recovery,
  13 lock checks on both shells); eight focused monitoring checks also pass.
- Next: finish OAuth/Play identity, canonical Android build evidence, diagnostics,
  recovery and remaining release
  acceptance. Final source is not frozen and no app upload occurred.
- Durable evidence: [Android beta execution](../verification/android-beta-2026-10-26.md).

## Outcome and environment decisions

The owner confirmed on October 25 that they are the game's only current user.
Their existing account and gameplay data may be reused for development or
discarded as needed for this setup. Preserving or migrating that data is not a
requirement. Reusing it in place avoids unnecessary work; no reset is required
just to change the project's role. This exception does not extend to future
beta-player data or authorize unrelated credential/resource deletion.

Use three complete environments from one codebase and deployment workflow:

| Environment | Firebase / Google Cloud project ID | Display name | Initial data |
| --- | --- | --- | --- |
| Development | Existing `rpg-runner-d7add` | `Lothringen Long Run - Dev` | Reuse the owner's existing account; add synthetic fixtures as needed |
| Staging | `lothringen-long-run-staging` | `Lothringen Long Run - Staging` | Synthetic fixtures and internal tester accounts |
| Production | `lothringen-long-run-prod` | `Lothringen Long Run - Prod` | Start fresh; no account, progression or replay import |

Both staging/production project IDs were created unchanged on October 26.
Their backend services and application configuration are still being provisioned.
Project display names can change; project IDs are permanent. Keep the existing
development ID to avoid resource recreation. These infrastructure labels use
the game's Lothringen identity; they do not rename the public game title.
Development changes frequently. Staging holds a selected, frozen candidate for
internal acceptance while development continues. Production serves external
closed-beta players and the eventual public release; beta is a distribution
stage, not another backend environment.

| Build / distribution | Android package | Backend | Purpose |
| --- | --- | --- | --- |
| Development debug | `com.example.rpg_runner.dev` | Existing project, now development | Everyday work and device debugging |
| Development release/profile | Same development package | Development project | Local release-mode debugging; a dev Play listing is optional |
| Staging release, separate app's Play internal track | `com.lothringen.longrun.staging` | New staging project | Team acceptance, real Play authentication/attestation and release rehearsals |
| Production release, Play internal track | `com.example.rpg_runner` | New production project | Final production-artifact smoke checks before promotion |
| Production release, closed beta and later public release | Same production package | Production project | Player testing and eventual public release |

These package names are the current baseline, pending the explicit identity
decision in Phase 1. Play tracks distribute versions of a package; they do not
select or isolate Firebase environments. Staging needs a separate Android package
and Play app listing. The production app's internal track still uses production
services and does not replace staging. Reuse an existing dev listing if useful;
creating a third Play listing is not required for normal development.

Use explicit Android `dev`, `staging` and `prod` product flavors, independently of
debug, profile and release build modes. Give dev/staging clear launcher labels
and separate package storage. This replaces the current debug-only package
suffix arrangement. Development release/profile must remain in development;
production debug must not become an accidental route to live data. Existing
web/Apple/Windows configuration targets the old project and therefore remains
development configuration until explicitly configured for production. Keep local
development on dev; account for this boundary without expanding Android delivery
into an Apple/Windows release or automatically publishing a production website.

Each backend owns its Auth users, Firestore, Functions, Storage, Cloud Run worker,
queues, scheduler jobs, boards, service accounts, IAM and operational evidence.
The owner's existing data stays in the existing project unless cleanup is needed;
future production-player data must not be copied into dev or staging. Signing in
with the same Google account in another environment creates independent state.
There is no account or progression migration workstream.

Alternatives considered: keeping one project leaves data and deployments shared;
keeping the old project as production would require more development-identity
relocation and retain its prototype project ID. Reusing it for dev and creating
staging/production fresh fits the owner's preference. Two environments were
initially considered; the owner's planned team expansion and independent
internal acceptance now justify staging. Local emulators complement the shared
dev project for isolated developer work; per-developer cloud projects are not
required by this plan.

## Scope and release policy

- Support one active gameplay compatibility version per environment. Staging
  can run the next version while production remains on its accepted version.
  Require an app update for incompatible releases and accept planned maintenance
  during cutover. Compatible
  UI fixes do not automatically require retiring older clients.
- Implement an update-required screen with a Google Play link before beta.
  Reuse server compatibility enforcement. Play's immediate in-app update flow is
  optional polish; it still requires user acceptance. Do not add multi-version
  validators or a custom update service for this beta.
- Stop new issuance and finish outstanding work before incompatible backend
  cutover. Do not interrupt a run to update. Current tickets last 24 hours, so
  maintenance duration depends on real drain/expiry evidence. Do not require a
  replacement build until it is available to the affected Play cohort. New
  clients arriving before cutover need a maintenance response too.
- Bootstrap staging/production without importing old sessions or requiring a
  drain of another project. Once production players exist, preserve their
  tickets, rewards and progression through the normal release workflow.
- Extend existing deployment scripts and CI, reuse backend alerts, use managed
  backups and standard client crash reporting. Keep one bounded beta-capacity
  check; defer a general load-testing platform and infrastructure rewrite.
- Prefer additive stored-data changes with defaults and stable identifiers.
  Mandatory app updates do not migrate saved player data. Add a focused data
  migration only when an actual schema change needs one.
- Promote a frozen commit through dev -> staging acceptance -> production.
  Hold staging stable during acceptance; fixes create a new candidate with
  affected checks repeated. Use the same application code, dependency locks,
  gameplay/content and build recipe without long-lived environment code forks.
- Match staging's auth, App Check, rules, indexes, queues and service topology to
  production. Document environment-specific identity, secret and scaling values.
  Smaller staging capacity can control cost, but record that limit when using
  its results as production load evidence. Separate telemetry and budgets.
- Staging and production AABs differ in package/configuration/signing identity.
  Build prod from the exact accepted source; verify its packaged configuration
  and run production smoke checks. Reuse backend artifact bytes only when inputs
  are genuinely environment-independent. Promote the same prod AAB across its
  own Play tracks, not a staging AAB into the production listing.

## Verified repository baseline and open facts

Read-only repository inspection on October 25 established:

- `.firebaserc` and `firebase.json` target `rpg-runner-d7add`.
- Both Android JSON configurations use that project. Debug selects the `.dev`
  registration; profile/release select the release registration.
- `android/app/build.gradle.kts` signs release with the workstation debug key.
  `pubspec.yaml` currently declares `1.0.0+1`; actual uploaded version codes are
  unknown until Play Console is inspected.
- `tools/release/release.ps1` rejects a project different from the configured
  default/Hosting site. Passing another `ProjectId` is not supported isolation.
- `functions/src/index.ts` hard-codes existing-project run-control and validator
  service-account addresses. Worker configuration already accepts project parameters,
  but the whole deployment chain still needs inspection.
- The latest documented deployment to the existing project is October 18,
  gameplay `2026.10.17`. Source/configuration includes later work. Neither HEAD
  nor local configuration proves what is serving. Preserve historical release
  records under their original project identity; they are not evidence for the
  new production project. Earlier documents call the existing project live/prod.
- [Android build identities](../tdd/android_build_variants.md) records successful
  dev authentication against the shared backend, but also an existing release
  Play Integrity rejection. Opening the hub is not proof of valid attestation.
- The initial planning pass recorded no connected browsers or tabs. Firebase,
  Cloud and Play Console state has not been verified during this plan revision.

Account type, verification status, existing Play listings/uploads, app-signing
enrollment, active credentials, project permissions, billing and existing service
health must be discovered rather than assumed.

## Execution and evidence rules

Prefer supported CLI/API operations for repeatability. Use the user's Chrome
session for Firebase/Google Cloud/Play Console tasks missing suitable CLI support.
Record the selected project/package before each mutation and verify the resulting
state afterward. Do not rely on the browser's previously selected project.

The agent owns implementation, tests, builds, resource configuration, draft store
materials and status tracking. The user supplies business decisions, authentic
policy facts, tester identities and access where missing, and performs required
credential, payment or identity-verification handoffs. Browser confirmation rules
apply at the actual consequential action; ordinary inspections and authorized
reversible preparation do not need repeated permission requests.

Before spending on cloud builds/provisioning, linking billing, changing sensitive
access, modifying live services or submitting/publishing a release, establish
the specific authorization required by the repository and browser policies.
Accepting binding terms or deleting unrecoverable data has its own action-time
requirements. The owner's sole-account data exception above permits necessary
dev cleanup; do not turn it into a blanket reset or carry it over to future
production users. Preserve auth and settlement invariants. Do not send tester
invitations/messages without explicit authorization.

Keep keys, keystore passwords, tokens, OAuth secrets and login exports out of Git,
logs and screenshots shared as evidence. Store only resource identifiers, public
certificate fingerprints, redacted configuration summaries and artifact hashes.
Use existing credential stores and protected secret storage; avoid downloaded
service-account keys when existing user/workload credentials suffice.

Maintain this checklist as the single progress record. For each phase, record
commit, environment, checks, evidence location and remaining limits. Save durable
redacted verification under `docs/verification/`; local operational output belongs
under `.tmp/`. Distinguish repository inspection, mocked checks and live results.

## Phase 1 - inventory and decisions

Execution: agent via read-only CLI and connected Chrome; user for missing decisions.

- [x] Restore/verify Chrome browser-control access to the intended signed-in
  profile, then inspect Firebase, Google Cloud and Play Console without changes.
- [ ] Inventory existing resources, serving versions, active sessions, pending rewards,
  boards, buckets, queues, scheduler, IAM, billing, alerts and retention policies.
  Record what can be reused as dev and a redacted configuration baseline; do not
  build an account-data migration or duplicate the existing dev infrastructure.
- [ ] Inspect developer account type/date, verification and distribution access;
  existing app listings, package names, version codes and signing state;
  Play Games configuration, testers and linked Cloud/OAuth projects.
- [ ] Decide the permanent production Android package/listing before upload.
  The new Cloud project name does not choose the Android package. Inspect Play
  constraints and prefer the simplest supported identity setup. Existing owner
  installations may be replaced without preserving gameplay data; update native,
  Firebase and Play Games configuration consistently if the package changes.
  Reserve a distinct staging package derived from that decision and identify the
  separate staging Play listing/internal tester access.
- [ ] Verify availability of `lothringen-long-run-staging` and
  `lothringen-long-run-prod`; select database/bucket locations, billing account,
  operational contact, internal team and beta audience/countries, and test-data
  and production retention policies. Record all three environment identities.
  Consult brand references before changing public names or authoring store copy.
- [ ] Inventory existing Play Games and OAuth credentials. Prefer leaving the
  working dev identity in the old project and configuring staging/prod separately.
  Package/certificate pairs can conflict across projects; resolve listing and
  credential constraints before creating duplicates or relinking a game. No
  custom cross-project authentication bridge is in scope.
- [ ] Record team access: developers can work in dev; designated maintainers
  deploy candidates to staging; production deployment/signing stays restricted.
  Document how candidates are selected and accepted without requiring another
  deployment system or giving internal testers production cloud permissions.

Exit: environment/resource matrix and identity decisions recorded; existing state
known; outstanding user inputs named. Do not block independent local work on
optional store-copy choices.

## Phase 2 - make deployments environment-aware

Execution: agent, repository and CLI. Prepare locally before cloud changes.

- [x] Read the closest AGENTS files, then add one explicit validated environment
  definition for project, region, Firebase configuration/Hosting target, bucket,
  worker, queues, identities and required secrets. Map dev to the existing project
  and staging/prod to their new projects. Keep one deployment workflow and shared
  provisioning recipe; environment definitions supply resource differences.
- [x] Extend the existing release entry point and provisioning helpers to select
  an environment. Preserve offline default `Plan`; require explicit environment
  selection for mutations and reject contradictory project/resource identities.
- [x] Remove hard-coded project service-account addresses from Functions source.
  Derive/validate identity against the selected deployment project. Audit task
  dispatch, settlement URLs, token audiences, scheduled work and monitoring for
  cross-project defaults; make missing environment values fail clearly.
- [x] Separate manifests, baselines, checkpoints, config files and cache keys by
  environment/project. Share source-only evidence/artifacts only when inputs
  genuinely match. Historical old-project production evidence belongs to that
  project; it cannot establish a baseline for the new production project.
- [x] Add a first-deployment bootstrap path for empty staging/production, without
  requiring resources or paused/drained sessions in another project. Retain
  readiness checks and coordinated cutover rules for established environments.
  Bootstrap must verify the target is empty rather than trust an environment name.
- [ ] Reuse provisioning helpers with safe retries and configuration readback;
  document console-only steps. Keep dev/staging runtime and deployment automation
  unable to mutate other environments, with separate production deployment access.
  The owner's existing operator identity can administer all projects. Serialize
  mutations per environment so two teammates cannot cut over it concurrently.
  Do not replace the existing tooling with a new infrastructure framework.
- [x] Add meaningful mocked tests for all three environments: an operation must
  not target another project's buckets, service accounts, queues, Hosting or
  release checkpoints. Mismatched configuration blocks before mutation; preserve
  scoped-release protections and environment-specific cache/evidence validation.
- [ ] Update deployment TDD/workflow/AGENTS documentation alongside delivered
  changes. Validate release helpers under PowerShell 5.1 and 7 and run focused
  Functions checks for affected configuration behavior.

Exit: plans for all three environments resolve correctly; isolation and existing
cutover tests pass. No direct package-deploy workaround becomes a parallel path.

## Phase 3 - reuse development and provision staging/production

Execution: agent via CLI; Chrome for billing/console-only setup; user where required.

- [x] Label the existing project as development and reuse its account, data and
  services. Keep credentials needed for dev sign-in. Only clean up obsolete
  owner fixtures when necessary; no data preservation or import task is required.
- [ ] Create the new staging and production Firebase/Cloud projects with their
  chosen IDs/display names, associate approved billing and enable required APIs.
  Configure separate budgets/alerts and conservative scaling; budget alerts are
  notifications, not a guaranteed spending cap.
- [ ] Apply the same provisioning recipe for Firestore/Storage, Auth configuration,
  indexes/rules, Artifact Registry/build resources, least-privilege service
  accounts, both task queues and scheduler jobs. Image-dependent worker deployment
  goes through canonical bootstrap: staging first, production after acceptance.
- [ ] Create separate environment configuration/secrets. Keep worker invocation,
  bucket access, token audiences and settlement dispatch inside each project;
  do not grant dev/staging identities access to production resources.
- [ ] Apply existing retention/cleanup and monitoring policies to each selected
  environment. Verify indexes, private invokers and routing; worker health,
  supported compatibility tuple and required boards must pass after bootstrap.
- [ ] Update dev through the environment-aware workflow and bootstrap staging
  from a frozen candidate. Seed representative synthetic fixtures without copying
  the owner's dev account or production data. Record image/deployment identities.
  Prepare production configuration for Phase 8 bootstrap from the accepted
  candidate; production starts fresh, with explicit smoke-test accounts as needed.

Exit: dev/staging backend stacks operate independently and production foundations
are ready for candidate deployment; configuration readback proves isolation.

## Phase 4 - isolate Android configuration and Play Games identity

Execution: agent, repository/CLI plus Firebase and Play Console in Chrome.

- [ ] Implement `dev`/`staging`/`prod` flavors with clear package/label identities
  across build modes. Install all three side by side.
  Download genuine environment-specific Google Services files; select the
  intended Firebase app, Storage bucket, Functions region and native resources
  consistently. The dev installation stays on its current backend. Use a clean
  production installation for the owner when the former release package changes
  backend; do not build local-state migration code just to preserve owner data.
  Verify Auth, outbox, replay spool and ghost cache state cannot cross environments.
- [ ] Retain the working dev registration/certificates in the existing Firebase
  project. Register staging/production packages and proper signing certificates
  in their own projects; resolve OAuth conflicts through the Phase 1 identity plan.
- [ ] Establish staging/production Play Games and Firebase Auth linkage using the
  supported topology chosen in Phase 1. Prefer retaining the existing dev game
  configuration and configuring each new environment separately where Console
  permits it. Staging must test the real authentication path without a bypass.
  Document each game's linked Cloud project and server OAuth client. Do not
  assume the old server client authenticates against the new Firebase project.
- [ ] Configure flavor-specific game-services ID/server client resources. Verify
  the full chain: package + installed signing certificate -> Play Games -> server
  authorization code -> intended Firebase Auth project -> protected callable.
  The update-required link must open that flavor's Play listing, not switch a
  staging tester into the production app.
- [ ] Configure development debug App Check tokens only in development; require
  real Play Integrity for staging/prod Play-delivered release builds. Match
  production enforcement in staging before acceptance. Confirm diagnostics
  without logging credentials.
- [ ] Verify packaged IDs/resources and targeted startup/auth tests; install dev,
  staging and prod side by side. Prove the same Google account has independent
  state in each and non-production actions cannot change production progression.
- [ ] Update Android identities/authentication TDD and build instructions. Mark
  non-Android configurations that still target the old project as development;
  verify local defaults cannot silently reach prod. Generated files stay generated.

Exit: dev retains working sign-in to the existing project; staging and production
builds have distinct registrations and authenticate to their respective projects
with fresh, independent progression.

## Phase 5 - production signing and reproducible Android artifacts

Execution: agent for configuration/builds; user for protected credential handling.

- [ ] Configure protected upload signing and Play App Signing for the live app.
  Remove debug-key fallback from release builds; missing signing inputs must
  fail clearly. Back up the upload key securely with a documented recovery owner.
- [ ] Configure staging release signing and its own Play app/internal track for
  team acceptance. Resolve listing/Play Games eligibility before relying on this
  path. Dev keeps local release-mode testing; its own Play listing is optional
  because required store-delivered integration coverage now belongs to staging.
- [ ] Register the appropriate installed-app signing certificates with each
  environment's Firebase, Play Games and App Check setup. Distinguish Google's
  distribution signing certificate from the local upload certificate.
- [ ] Add a repeatable Android preparation/build path tied to frozen source,
  environment, compatibility tuple, toolchain, navigation assets and version
  code. Extend existing CI/release components to include Android sources, native
  configuration and toolchain inputs; current client-build evidence is web-only.
  Keep signing credentials protected and promote the same verified production
  AAB across Play tracks. Staging/prod bundles have different identities; record
  the accepted commit and environment-specific build inputs for both.
- [ ] Check current Play SDK requirements and inspect the actual bundle's target
  API, supported ABIs, native-library/page alignment, manifest, permissions,
  package, signing, size and asset inclusion. Upgrade/fix dependencies as needed.
- [ ] Allocate increasing version codes from actual Play history; generate signed
  AABs plus hashes and symbols needed to diagnose release crashes. No dev flags,
  debug tokens or secret material may enter the live bundle.

Exit: reproducible signed staging/prod AABs and a working dev build, with verified
identities; production no longer depends on the workstation debug signing key.

## Phase 6 - release candidate and pre-beta readiness

Execution: agent via automated checks and staging deployment; internal team via
Play-delivered device QA and candidate acceptance.

- [ ] Run relevant client/Core/protocol/Functions/worker checks and generated
  content freshness. Follow the traversal workflow for included level/navigation
  changes; record levels, seeds, enemies, horizons and exclusions.
- [ ] Prepare navigation graphs and run the strict benchmark on the final worker
  image. Reuse valid preparation evidence and retain required coverage; do not
  repeat this work for unrelated UI changes.
- [ ] Freeze the candidate commit and deploy its complete stack to staging.
  Hold it stable for the test session while dev work continues. Record who
  accepts the candidate; a fix selects a new commit and repeats affected checks.
- [ ] Install the staging release through its separate Play internal track. Verify
  real Play Integrity and Play Games sign-in, including a fresh tester account.
- [ ] Exercise issuance, replay upload/acceptance, exactly-once rewards, wallet
  catch-up, leaderboard and ghost retrieval, account deletion and pending-run
  recovery after disconnect, app restart and background/foreground transitions.
- [ ] Verify wrong-environment identities/tokens fail, unauthorized access remains
  blocked, and dev/staging tests leave production accounts/resources unchanged.
- [ ] Implement and test the single-version release policy before the first beta
  client ships. Distinguish maintenance from an obsolete client; present an
  update-required screen with a Play Store button and reuse backend enforcement.
  Gate incompatible online operations/new runs, preserve outstanding submission
  recovery and keep account-deletion/support access available. A canceled or
  failed update must not bypass compatibility checks. Immediate in-app updating
  is optional, not a release prerequisite.
- [ ] Rehearse one incompatible update in staging: old/new clients, pause/drain,
  delayed store availability, restart and pending rewards. Do not assume a
  staged Play rollout can coexist with a single incompatible backend version.
  Record the maintenance window and the higher-version-code hotfix procedure;
  installed Android apps cannot be rolled back by restoring backend artifacts.
- [ ] Verify standard client error reporting and readable release stack traces,
  plus existing backend alerts for auth, validation and settlement. Record the
  owner, alert destination, actionable thresholds and conditions that stop rollout.
- [ ] Configure managed production database recovery with explicit acceptable
  data-loss/recovery-time targets and retention. Run a small synthetic-data
  restore rehearsal in dev and document reward/deletion consistency checks.
  Keep recovery-copy disclosures accurate; no custom backup system is needed.
- [ ] Declare the initial beta audience cap and run a bounded representative
  concurrent replay/settlement check in staging. Observe queue age, completion
  latency, memory and cost against stated limits. The isolated simulation
  benchmark alone is not cloud capacity evidence; record scaling differences
  from production and expand testing with audience.
- [ ] Check loading, controls, device performance/memory, crashes and ANRs on
  representative Android devices. Fix beta blockers; prior release waivers are
  historical evidence and do not automatically carry into beta acceptance.
- [ ] Record the accepted candidate and unresolved defects/limits. Commit
  independently validated milestones without including unrelated worktree edits.

Exit: an internally accepted frozen candidate with observed staging Play end-to-end
success, tested update/maintenance and recovery behavior, working diagnostics,
and an explicit disposition for every remaining beta blocker.

## Phase 7 - store listing, privacy and account readiness

Execution: agent prepares/configures; user validates factual business declarations.

- [ ] Inspect all mandatory tasks shown for the actual developer account and
  app. Complete identity/contact/device verification through user handoff where
  needed. Establish closed/open testing eligibility from the account's live state.
- [ ] Prepare truthful listing text, game icon, screenshots and required artwork
  from implemented gameplay. Consult Lothringen naming/brand references before
  creating public materials; do not advertise unimplemented systems.
- [ ] Use the existing [compliance checklist](../EU-compliance/checklist.md) to
  inventory actual SDK/data processing, retention and deletion behavior. Publish
  accessible privacy information and a working external account-deletion request
  route, with access inside the app as required. Verify the existing deletion
  implementation rather than declaring it complete from its presence in code.
- [ ] Complete Data safety, content rating, target audience, ads/monetization and
  app-access declarations from verified behavior. Provide a working reviewer
  access path compatible with mandatory Play Games authentication; do not add
  an auth bypass or invent review credentials.
- [ ] Configure release certificates, App Check/Play Integrity and Play Games
  tester/publication state for intended testers. Play app publication and Play
  Games publication are separate checks.

Exit: required console tasks complete, policy URLs work, disclosures match the
candidate, and reviewers/testers can access the game.

## Phase 8 - live internal release and closed beta

Execution: agent via canonical release CLI, Chrome and physical-device checks.

- [ ] Prepare live artifacts from the exact staging-accepted commit, dependency
  locks and gameplay/content. Revalidate environment inputs and the new
  production project's state. Reuse valid source evidence,
  not dev/staging cloud checkpoints. If the target is no longer empty after smoke
  testing, use normal cutover/drain gates rather than the empty-project bootstrap.
  Any code/content fix returns to staging; environment-specific bundle checks and
  production smoke still run because the staging AAB is a different application.
- [ ] Present the concrete production deployment and recovery set for release
  authorization. Use the canonical bootstrap or coordinated path as appropriate,
  preserving readiness, issuer, queue and compatibility fences. The old owner's
  disposable dev data is not permission to reset new production accounts.
  Keep production in maintenance until backend and Play availability match.
  Android delivery does not independently require or authorize a web publication;
  the old web deployment remains part of dev.
- [ ] Upload the signed live AAB as a draft, resolve Play validation findings,
  then publish to the main app's internal track once that action is authorized.
- [ ] Install from Play on a fresh tester account. Confirm live-project identity,
  valid attestation, sign-in and a complete accepted/rewarded run, leaderboard and
  ghost flow. The owner may use the same Google account with fresh production
  state. Replace the owner's former debug-signed release installation if needed;
  preserving its local state or progression is not required. Verify ordinary
  Play-signed updates preserve newly created production state.
- [ ] Prepare the closed-beta tester list, countries, feedback route, release
  notes and known limitations. Promote the same verified artifact where possible;
  rebuilds need new identity/checks. Obtain authorization for the actual rollout.
- [ ] Verify the tester opt-in and Play installation/update flow. Record the
  released version code, artifact hash, backend tuple, cohort and release time.

Exit: invited beta players can install through Play and complete real runs
against a stable live backend. Dev/staging deployments cannot affect their
environment.

## Phase 9 - beta operations and subsequent releases

Execution: agent maintains workflow and evidence; user supplies feedback/rollout decisions.

- [ ] Use the diagnostics and alert thresholds verified before beta to monitor
  crashes/ANRs, auth/App Check failures, replay latency/backlogs, settlement,
  leaderboard/ghost health and cost. Keep the cohort within measured capacity.
- [ ] Document one repeatable sequence: implement/test in dev -> freeze candidate
  -> deploy to staging and complete internal acceptance -> prepare prod from that
  commit and complete Play review -> authorized maintenance/drain when incompatible
  -> production backend and matching Play release -> verified availability and
  smoke checks -> reopen. A production internal track shares the same backend
  as closed beta; do not test an incompatible backend on active beta players.
  Recheck compatibility for deterministic changes, including levels; compatible
  UI-only releases can follow the scoped path without retiring old clients.
- [ ] Keep one supported gameplay version per environment and enforce updates
  only after the replacement is available to every affected cohort there. Reuse
  the tested recovery procedure; revisit overlapping versions within an environment
  only if maintenance becomes unacceptable.
- [ ] If the developer account requires the closed-test qualification period,
  track real tester participation before applying for production/open access.
  Never claim elapsed time or participation that has not occurred.
- [ ] Update implemented TDD/GDD/AGENTS/setup docs with each delivered milestone.
  Archive this plan only after completion or explicit supersession, preserving
  unresolved findings and incoming links.

Exit: beta is supportable with isolated dev/staging, auditable candidate promotion
and a tested response to client/backend compatibility and operational failures.

## Reference requirements checked October 25, 2026

Recheck these against official documentation and the actual Console before each
submission; the account's eligibility and warnings are not known from this plan.

- [Firebase environments](https://firebase.google.com/docs/projects/dev-workflows/overview-environments)
  recommends a separate project for each environment.
- [Cloud project names and IDs](https://docs.cloud.google.com/resource-manager/docs/creating-managing-projects)
  distinguishes editable display names from globally unique, permanent project IDs.
- [Multiple-project configuration](https://firebase.google.com/docs/projects/multiprojects)
  describes selecting native configuration by build target.
- [Play signing](https://developer.android.com/studio/publish/app-signing) explains
  the upload/distribution key distinction.
- [Play Games setup](https://developer.android.com/games/pgs/console/setup) and
  [Cloud project settings](https://developer.android.com/games/pgs/console/cloud-platform)
  govern the credential/project topology; separate Firebase projects alone do
  not migrate Play Games credentials.
- [App Check / Play Integrity](https://firebase.google.com/docs/app-check/android/play-integrity-provider)
  requires the intended project linkage and signing-certificate registration.
- [Play testing tracks](https://support.google.com/googleplay/android-developer/answer/9845334)
  distinguish internal, closed and open distribution.
- [Immediate in-app updates](https://developer.android.com/guide/playcore/in-app-updates/kotlin-java#immediate)
  require user acceptance and can be canceled. Backend compatibility enforcement
  supplies the mandatory-update boundary; a Play Store link is the initial UI.
- [Firestore backup and restore](https://firebase.google.com/docs/firestore/backups)
  provides managed recovery; verify application consistency with synthetic data.
- [New personal-account testing](https://support.google.com/googleplay/android-developer/answer/14151465)
  currently requires qualifying accounts to have at least 12 closed testers
  continuously opted in for 14 days before applying for production access;
  production approval also unlocks open testing for these accounts.
- [Target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
  currently specify Android 16 / API 36 for new mobile apps and updates from
  August 31, 2026. Inspect actual build output rather than assuming Flutter's
  default satisfies it.
- [16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)
  describes native-library compatibility and changing enforcement dates. Verify
  Flutter/plugin binaries and Play bundle checks; an SDK version is not proof.
- [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
  cover in-app and external deletion request routes for apps creating accounts.

Repository execution references: [deployment workflow](../tdd/deployment_workflow.md),
[release checklist](rescue_release_operations.md),
[prepared navigation](../tdd/prepared_navigation.md),
[Android identities](../tdd/android_build_variants.md),
[authentication](../tdd/authentication_flow_and_authorization.md),
[abuse controls](../tdd/callable_abuse_controls.md) and
[level traversal workflow](../../.agent/workflows/test-level-traversal.md).

Next action: resume the execution checkpoint above. Foundation provisioning and
upload-key setup are complete; OAuth/Play configuration, remaining implementation,
candidate freeze, builds, deployments and acceptance remain open. No app bundle
has been uploaded or released. Do not repeat completed setup or treat local
validation as live acceptance.
