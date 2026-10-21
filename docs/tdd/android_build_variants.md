# Android build identities

Android debug builds have a separate application ID so installing a development
build does not replace an installed release build. Build types supply the
identity; no flavor argument or alternate Dart entrypoint is required.

| Build mode | Application ID | Launcher name | Firebase configuration |
| --- | --- | --- | --- |
| Debug | `com.example.rpg_runner.dev` | `rpg_runner Dev` | `android/app/src/debug/google-services.json` |
| Profile | `com.example.rpg_runner` | `rpg_runner` | `android/app/google-services.json` |
| Release | `com.example.rpg_runner` | `rpg_runner` | `android/app/google-services.json` |

Debug also appends `-dev` to the version name. Profile intentionally retains
release identity and attestation behavior; installing it can replace release.
This change is Android-only; Apple bundle identifiers are unchanged.

## Local installation and storage

From the repository root:

```bash
flutter run -d <device-id>
flutter build apk --debug
```

The APK is `build/app/outputs/flutter-apk/app-debug.apk`. Release commands
remain unchanged. Follow the existing prepared-navigation requirements before
building a mobile release.

Android isolates each package's private storage, including Firebase sessions,
control preferences, Developer Practice selections, ownership outbox and replay
spool. The first dev installation therefore starts fresh: sign in and enable
**Options > Settings > Developer mode** if local Practice is wanted. Ordinary
dev updates and hot restarts preserve that installation's data.

An older debug build installed as `com.example.rpg_runner` stays in that slot.
Install release over it to return that slot to release; do not uninstall or
clear its data merely to install the new dev package. Local settings are not
migrated between packages. Both builds currently use the local debug signing
configuration; production distribution signing remains a separate concern.

## Firebase configuration ownership

Both registrations belong to the existing `rpg-runner-d7add` project:

- Release/profile: `1:964001571974:android:d48582bc9cde8cf2d81d07`.
- Debug: `1:964001571974:android:1a4b98db937af313d81d07`.

The Google Services Gradle plugin selects the JSON for the build type, then
selects the client whose package matches the application ID. Keep these files
downloaded from Firebase; do not fabricate an app ID or change the package in a
release client entry to make a dev build compile.

`createFirebaseAppServices` initializes native Android Firebase without explicit
Dart options, letting the packaged native resources determine its registration.
Web (including Android browsers), Apple and Windows still use
`DefaultFirebaseOptions.currentPlatform`. The generated Dart file and
`firebase.json` default Android mapping continue to describe release.

Separate installations do not create separate backend environments. Both use
the same Functions, Auth, Firestore and Storage project. Signing into the same
Play Games account accesses the same remote progression; account operations
affect that shared account. Developer Practice retains its existing isolation:
local runs create no backend sessions, rewards or leaderboard writes.

Refresh the debug configuration with:

```bash
firebase apps:sdkconfig ANDROID 1:964001571974:android:1a4b98db937af313d81d07 --project rpg-runner-d7add --out android/app/src/debug/google-services.json
```

The downloaded JSON may include multiple registered clients; the plugin selects
the matching one. Refreshing the root release JSON does not refresh the debug
override. Keep `lib/firebase_options.dart` generated.

## Play Games and App Check setup

Firebase registration alone does not authorize a new Android package in Play
Games. Before the first online dev launch:

1. Register the workstation debug certificate's SHA-1 and SHA-256 on the dev
   Firebase Android app. These were registered for this workstation on
   2026-10-21. Other workstations may have different debug certificates.
2. In the existing game's Play Console **Play Games Services > Setup and
   management > Configuration**, add an Android credential for
   `com.example.rpg_runner.dev` and that certificate's SHA-1. Link it to the
   existing game and preserve the release credentials and server OAuth client.
   For this workstation the SHA-1 is
   `74:B0:81:6A:97:FE:84:86:35:C8:BD:30:F9:70:A9:18:E3:EB:6A:6E`.
3. Keep the phone's Google account on the Play Games tester list while the
   configuration is unpublished. Refresh the debug JSON after credential
   changes and rebuild.
4. Register the dev installation's App Check debug token on the **dev Firebase
   app**, not the release app. Obtain it from local device logs after launch;
   never check debug tokens into the repository. Release/profile continue to
   use Play Integrity. See [App Check diagnostics](callable_abuse_controls.md#app-check-diagnostics-and-troubleshooting).

The Firebase app and certificate registration are complete. Play Console
credential linking and the phone-specific App Check token registration still
require verification; they are not established by a successful APK build.
The downloaded dev configuration currently has the shared web OAuth client but
no Android OAuth client for the dev package. Normal startup remains fail-closed
until Play Games sign-in succeeds; this setup does not add an auth bypass.

## Validation

Verified locally on 2026-10-21: the debug APK builds and its packaged identity,
Firebase app ID, server OAuth client and signing certificate match the dev
registration. Targeted release/profile manifest and resource tasks pass using
cached arm64 dependencies, retaining the original identities. Dart analysis of
the service factory and all 28 focused startup/Developer Practice tests pass.
No full release/profile APK or connected-phone sign-in check was performed.

Build the debug APK and inspect its packaged manifest/resources: package
`com.example.rpg_runner.dev`, label `rpg_runner Dev`, dev `google_app_id` and the
existing Play Games server client ID. Also check the generated release/profile
manifests/resources retain their original package, label and Firebase app ID.
Run targeted Dart analysis and startup/Developer Practice tests for changes to
service initialization.

With a connected phone, verify both launcher entries exist, online dev sign-in
works after credential setup, Developer Practice persists across a dev update,
and release still opens with its existing data. APK/build checks do not replace
these device and online-service checks.

References: [Android build types](https://developer.android.com/build/build-variants),
[Google Services config selection](https://firebase.google.com/docs/android/google-services-plugin-and-file),
[Play Games credentials](https://developer.android.com/games/pgs/console/setup).
