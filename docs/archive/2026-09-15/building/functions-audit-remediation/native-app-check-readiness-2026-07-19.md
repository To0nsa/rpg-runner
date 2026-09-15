# Native App Check Readiness — July 19, 2026

## Decision

Native App Check is **not ready for production enforcement**. Functions remain
in `APP_CHECK_ROLLOUT_MODE=monitor`; no enforcement deployment was attempted.

The web path remains the only measured production attestation path. Android is
the repository's early native target, but its production identity, signing,
distribution, and device measurement prerequisites are incomplete. Apple
platforms have provider resources but no configured team identity or reachable
release host/device. Windows has no production provider in the current client
contract.

This record supplements the
[web rollout evidence](app-check-client-rollout-2026-07-19.md). It does not
alter the immutable July 18 audit.

## Repository release scope

The implemented project contains Android, iOS, macOS, web, and Windows runner
configuration. The game design document describes the product as mobile-first,
with "Android early" and an "iOS-ready architecture." That is evidence for
prioritizing Android; it is not sufficient by itself to declare every other
build target excluded from release.

The enforcement gate therefore remains:

| Platform | Current disposition | Evidence still required |
| --- | --- | --- |
| Web | In scope and measured | Longer organic observation only; the controlled end-to-end attestation already passed |
| Android | Early native target; not ready | Final package/signing identity, Play-distributed build, registered Play signing SHA-256, and physical-device attestation |
| iOS | Architecture-ready; release scope undecided | Explicit release exclusion, or Apple team/configuration plus release-device attestation |
| macOS | Build target exists; release scope undecided | Explicit release exclusion, or Apple team/configuration plus release-device attestation |
| Windows | Build target exists; no production provider | Explicit exclusion from Firebase-backed release or separately reviewed endpoints |
| Linux/Fuchsia | Unsupported by the client contract | Explicit exclusion if either becomes a release target |

An exclusion is a product/release decision, not something inferred from the
presence or absence of a platform folder. No new exclusion was declared during
this technical preflight.

## Client implementation

The standalone client activates App Check after Firebase initialization and
before `UiApp` starts:

- Android release: Play Integrity;
- iOS/macOS release: App Attest with DeviceCheck fallback;
- web release: reCAPTCHA Enterprise when its site key is injected;
- Windows release: activation is skipped because only an explicitly registered
  debug token is supported;
- Linux/Fuchsia: activation is skipped as unsupported.

Current FlutterFire documentation continues to expose those Android, Apple,
web, and debug-provider choices. A debug-provider or emulator result is useful
for integration testing but is not a legitimate release-attestation sample.

`tool/app_check_native_smoke.dart` now provides a reusable privacy-safe native
probe. It:

1. initializes the production Firebase options;
2. activates the platform provider through the same client bootstrap as the
   game;
3. forces a fresh App Check token;
4. calls the auth-gated `playerProfileLoad` endpoint without Firebase Auth;
5. prints one JSON result containing token length and error codes, never the
   token;
6. exits.

A passing sample requires both a non-empty token and the expected
`unauthenticated` callable result. The server log must independently show
`tokenStatus=verified` and the expected Firebase app ID.

## Cloud registration inventory

Read-only production inspection at `2026-07-19T19:24:46Z` found:

### Android

- Firebase app:
  `1:964001571974:android:d48582bc9cde8cf2d81d07`;
- package: `com.example.rpg_runner`;
- app state: active;
- Play Integrity API: enabled;
- App Check Play Integrity resource: present;
- token TTL: 3,600 seconds;
- registered SHA-1 fingerprints: one;
- registered SHA-256 fingerprints: zero.

The package still uses an example namespace. `android/app/build.gradle.kts`
also assigns the debug signing configuration to the release build. The release
APK produced during preflight was signed by `CN=Android Debug`, with SHA-256
certificate digest
`b1bab9e14cf0651e3c9b787cae1e1e53e27c7df86d53c5e7909444ebd01f9c68`.
That fingerprint is not registered as a Firebase SHA-256 fingerprint and is
not a production Play App Signing identity.

These facts block a legitimate Play Integrity release measurement even if a
local emulator starts successfully.

### Apple

- Firebase app:
  `1:964001571974:ios:84c6faf57baaa0f4d81d07`;
- bundle ID: `com.example.rpgRunner`;
- app state: active;
- App Attest and DeviceCheck configuration resources: present;
- token TTL for each: 3,600 seconds;
- Firebase Apple team ID: absent;
- App Store ID: absent.

The bundle ID is also an example identity. No macOS build host, Apple release
device, signing team, or distribution artifact is available in this
environment.

### Web and Windows

The production web app remains configured with reCAPTCHA Enterprise and has
one previously recorded verified production-origin observation.

The Windows Firebase registration is a web-app configuration consumed by the
desktop Flutter plugins. It does not create a Windows production attestation
provider. The source intentionally skips release activation on Windows.

## Local build and device evidence

Environment:

- Flutter `3.41.7`, Dart `3.11.5`;
- Windows 11 host;
- reachable devices: Windows desktop, Chrome, and Edge;
- no connected Android or Apple physical device;
- one Android 36 Pixel 7 Google Play emulator is configured.

Validation:

- `dart analyze tool/app_check_native_smoke.dart`: passed;
- ordinary Android release artifact: produced before the native smoke was
  added, 103,387,947 bytes, signed with the debug certificate above;
- artifact SHA-256:
  `5c4492c8b5f558d878d36d988dcf34f58ac11c47879b5439a2a1c1049c0e887e`;
- native-smoke release build: blocked while copying assets because the system
  drive had no free space;
- emulator start: blocked by the Android emulator's disk-space preflight.

The generated repository `build/` directory was cleaned after its path was
verified to be inside the workspace, recovering about 640 MiB. Concurrent
Flutter test processes retained part of that generated directory, so no
unrelated process was stopped and no broader cache or user-data deletion was
attempted.

Even without the disk-space blocker, a sideloaded debug-key release on an
emulator would not satisfy the production Play-distribution and signing gate.
It would therefore be recorded only as diagnostic evidence.

## Production observations

For the current structured-log revision, the 30-day query returned six
`callable_app_check` observations:

- six `missing_or_invalid`;
- zero `verified`;
- all in `monitor` mode;
- no app ID attached to the missing/invalid observations.

Those are controlled production canaries, not organic native traffic. The
earlier server-verified web observation is recorded in the web rollout
evidence and predates the current structured-log revision.

## Exact path to the Android release measurement

1. Select the final Android application ID instead of `com.example.*`.
2. Configure a non-debug release signing path without committing a keystore or
   passwords.
3. Create/link the Google Play application to project
   `rpg-runner-d7add`, enable Play App Signing, and obtain its SHA-256
   certificate.
4. Register that SHA-256 on the matching Firebase Android app and regenerate
   Firebase client configuration if the application ID changes.
5. Build a production-signed internal-test App Bundle. For the dedicated
   probe, use:

   ```text
   flutter build appbundle --release \
     --target tool/app_check_native_smoke.dart \
     --build-number <unused-internal-test-version>
   ```

6. Install that exact version from Google Play on a Play-certified physical
   Android device.
7. Capture the `APP_CHECK_NATIVE_SMOKE` result without capturing the token.
8. Confirm a matching server `callable_app_check` log with
   `tokenStatus=verified` and Android app ID
   `1:964001571974:android:d48582bc9cde8cf2d81d07`.
9. Repeat enough normal release calls to establish a platform-specific success
   rate rather than relying on one synthetic sample.
10. Record explicit release exclusions or complete equivalent Apple
    measurements before changing the global Functions switch to `enforce`.

## Enforcement outcome

The readiness gate failed safely. Auth, UID authorization, enforced quotas,
payload bounds, and monitoring remain active. `monitor` continues to be the
documented rollback and current production value.

Global enforcement must not be enabled until:

- Android has a Play-installed, production-signed, physical-device verified
  sample and an acceptable observation window;
- every other Firebase-backed release platform is either measured or
  explicitly excluded;
- the resulting release matrix is recorded in this remediation plan.
