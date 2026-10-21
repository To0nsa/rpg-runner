# Developer Practice

Developer mode is an explicit debug-build option for testing current local
gameplay on a connected device. It is not a public offline mode and does not
automatically activate after a connection failure.

Android debug builds install as **rpg_runner Dev**, separately from
release/profile. The first dev install starts with fresh preferences and still
requires normal sign-in before enabling Developer mode in Options. Existing
release preferences are not copied. See [Android build identities](android_build_variants.md)
for the package-specific sign-in setup.

## Profile ownership and startup

`createFirebaseAppServices` supplies `SharedPrefsDeveloperProfileStore` only
when `kDebugMode` is true. `AppServices` reads its enabled preference behind the
normal loader, before Firebase/App Check initialization or client construction.
A saved enabled preference creates `AppState.developer`; ordinary startup still
requires authenticated bootstrap. Release/profile builds do not read or expose
the developer setting. The local state factory rejects non-debug builds.

Options calls `AppServices.setDeveloperMode` outside gameplay. The service owner
bootstraps the candidate, persists the toggle, then replaces and disposes the
previous state. The provider subscribes to the replacement, and Options clears
the old menu stack. Failed initialization, authentication or preference writes
leave the current profile active. Concurrent switches are rejected. Lifecycle
refreshes are suppressed while a switch is in progress.

The local profile has no authentication or ownership API and no submission
coordinator. Its profile name is `Developer`, with onboarding completed and no
authenticated identity. It never signs out the Firebase user. Turning it off
initializes normal services and reloads the real account. Normal ownership
outbox entries and replay submissions are retained for normal account recovery;
they are not processed by the developer profile.

## Local selections and unlocks

The only developer persistence is:

- `developer_practice.enabled.v1`: active-mode preference.
- `developer_practice.selection.v1`: existing `SelectionState` serialization,
  containing level, character, build name and each character's loadout.

Writes are ordered; pending loadout saves finish before run start or profile
switch. A failed save can be retried by the next flush. Corrupt serialized
selections fall back to defaults. Reinstalling or clearing application data
resets these preferences; ordinary updates and restarts retain them.

Inventory and learned abilities are reconstructed from current catalogs on
bootstrap, rather than persisted as a second progression system. Character
namespaces, allowed slots, playable projectile IDs and normal slot masks remain
in force. Enemy abilities are excluded. Stale equipment/ability selections are
repaired using current character defaults. Core's `LoadoutValidator` checks the
selected loadout before each run. The normal starter-inventory normalization
policy is unchanged. No currency, reward ledger or progression is generated.

## Runs and presentation

The same hub, level selection and loadout screens are used. The hub identifies
the Developer profile and Practice-only mode. Town, account/profile and
leaderboard actions are disabled; Competitive is absent from level selection
and Weekly cannot start. State methods also reject non-Practice modes, ghost
requests and online operations, independently of disabled controls.

`RunStartPreparation` remains the shared entry point, including restart. The
developer controller builds an explicitly tagged `RunStartDescriptor` with a
unique local session ID, positive random seed, selected level/character/loadout
and the normal 60 Hz simulation rate. No ticket or compatibility deployment is
required. Normal remote ticket checks remain unchanged.

`RunnerRunSession` and `RunnerGameWidget` require debug mode, Practice and no
board/ghost for a developer descriptor. They use the existing Core, Flame,
controls, HUD and lifecycle behavior. World readiness is still required, but
developer runs do not open a recorder or append replay frames. Completion
keeps the normal score breakdown and restart/exit controls while omitting
reward verification, replay journaling/upload and local/online leaderboard
writes. Restart creates a fresh local descriptor through the same preflight.

## Verification

Focused tests cover catalog unlocks, saved selections, local starts/restarts,
online-action rejection, normal-profile restoration, saved startup without
online initialization, Options/provider switching, recorder-free world
readiness and game-over isolation. These do not establish device-specific
performance or replace authenticated backend/replay validation tests.
