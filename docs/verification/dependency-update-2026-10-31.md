# Flutter dependency update — October 31, 2026

Scope: root Pub workspace dependency maintenance and diagnosis of the Android
Kotlin Gradle Plugin warning. Flutter 3.47.1 / Dart 3.13.1, AGP 9.1.0 and Gradle
9.3.1 remain the supported toolchain. No cloud release or device installation.
The editor and replay validator retain their independent lockfiles.

## Updated source

- Firebase Core 5.1.0, Auth 7.0.1, App Check 0.5.1, Functions 7.0.1,
  Firestore 7.1.0 and Crashlytics 6.0.1.
- Battery 7.1.2, crypto 3.0.8, image 4.12.0, SharedPreferences 2.5.6,
  Cupertino icons 2.0.0 and Lucide icons 4.0.1, plus resolvable transitive updates.
- Migrated ability icons from `LucideIcons.<name>400` to
  `LucideIcons400.<name>` and the dedicated weight library, preserving weight
  400. The first build with updated packages exposed these removed v3 members.
- Generated Windows/Linux plugin lists include JNI, introduced through
  SharedPreferences Android's new native implementation.
- iOS project/framework minimum 15.0 and macOS project minimum 11.0 match
  Firebase's published Apple plugin requirements. Apple builds are unrun on this
  Windows workstation.
- Android minimum stays API 24. App Check already uses the provider object API
  required by 0.5.x; no authentication or attestation policy changes were needed.
- The standalone terrain signature test accepts Dart CLI build-hook progress
  on stderr while preserving successful-exit, exact JSON, fixture signature and
  cross-process equality checks. The new JNI hooks exposed the previous
  assumption that successful `dart run` leaves stderr empty.

The working tree also contains another workstream's achievement release evidence.
Concurrent updates to `codex_library_test.dart` and
`app_state_firebase_auth_integration_test.dart` were committed separately in
`8750344d` while validation ran. Those edits are preserved and are not part of
this dependency change.

## Kotlin warning diagnosis

The installed Flutter SDK's
`packages/flutter_tools/gradle/src/main/kotlin/FlutterPluginUtils.kt` uses regex
source inspection in `getSubprojectPluginState`, called by
`detectApplyingKotlinGradlePlugin`. This matches the conditional legacy plugin
application in the published FlutterFire Android scripts, even though AGP 9
with `android.builtInKotlin=true` leaves that branch inactive.

Removing the settings-level Kotlin declaration exposed AGP's default Kotlin
2.2.10. `flutter build apk --debug --flavor dev` then failed Flutter's minimum
2.2.20 check. Restored the existing 2.4.0 `apply false` compiler pin and added
its rationale. No validation bypass, warning suppression, or SDK/Pub-cache
patch is used. The generic Flutter Fix footer mentioned the new DSL, but the
actual failure was the compiler version check; `android.newDsl=false` was
already set.

An init-script probe at `gradle.projectsEvaluated` inspected every configured
Android module using `plugins.hasPlugin('org.jetbrains.kotlin.android')` and
`plugins.hasPlugin('kotlin-android')`, and asserted both were absent while
`android.builtInKotlin` was `true`. All 12 modules passed: app, battery, Firestore,
Functions, App Check, Auth, Core, Crashlytics, integration_test, JNI,
SharedPreferences Android and URL Launcher Android. Flutter printed its warning
in the same successful invocation, confirming the mismatch with actual state.
The scratch probe was scoped to the app root after its first invocation also
visited Flutter's included tooling build, which has no Android modules.

The local init script used for the probe was:

```groovy
gradle.projectsEvaluated {
    if (gradle.rootProject.projectDir.canonicalPath !=
        new File('C:/dev/rpg_runner/android').canonicalPath) return
    def androidProjects = gradle.rootProject.subprojects.findAll {
        it.plugins.hasPlugin('com.android.application') ||
            it.plugins.hasPlugin('com.android.library')
    }
    assert !androidProjects.isEmpty()
    androidProjects.sort { it.path }.each { module ->
        def legacy = module.plugins.hasPlugin('org.jetbrains.kotlin.android') ||
            module.plugins.hasPlugin('kotlin-android')
        def enabled = module.providers.gradleProperty('android.builtInKotlin').get()
        println "KOTLIN_CHECK ${module.path} builtIn=${enabled} legacy=${legacy}"
        assert enabled == 'true' : "Built-in Kotlin disabled in ${module.path}"
        assert !legacy : "Legacy Kotlin Android plugin applied in ${module.path}"
    }
}
```

References: [Flutter migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers),
[AGP compiler dependency](https://developer.android.com/build/releases/agp-9-0-0-release-notes#runtime-dependency-on-kotlin-gradle-plugin),
[Firebase Core changelog](https://pub.dev/packages/firebase_core/changelog),
[App Check migration](https://pub.dev/packages/firebase_app_check/changelog),
[Lucide v4 migration](https://pub.dev/packages/lucide_icons_flutter),
[SharedPreferences Android changelog](https://pub.dev/packages/shared_preferences_android/changelog).
Context7 was unavailable in this session; official docs and downloaded package
sources were used instead.

## Local validation

All commands below use this working tree and updated root `pubspec.lock`.
The tested base is `8750344d` plus this change; lockfile SHA-256 is
`b3be9984b2991b9ae2b7963c2f87fcaf591bd179b4ba5a94136200517ab93a40`.

| Command | Directory | Result |
| --- | --- | --- |
| `flutter pub upgrade` | root | Pass; 46 dependencies changed |
| `flutter pub outdated --json` | root | Pass; all packages at their resolvable version |
| `dart pub workspace list` and member-lockfile inspection | root | Pass; all eight members use the root lockfile |
| `dart run packages/runner_core/tool/update_navigation_revision.dart --check` | root | Pass; fingerprint unchanged at `bd2274e0b71f13d538e131be959817d040eb11182da317b2db98903ed26a1e98` |
| `dart test test/replay_blob_test.dart --reporter expanded` | `packages/run_protocol` | Pass; 8 tests, including digest stability and rejection cases |
| `dart analyze lib packages test tools/admin` | root | Pass; no issues |
| `dart analyze lib/ui/controls/ability_slot_visual_spec.dart test/ui/controls/ability_slot_visual_spec_test.dart test/tool/polygon_terrain_signature_probe_test.dart` | root | Pass after the final test edit; no issues |
| `flutter test --no-pub --exclude-tags=integration --concurrency=2 --reporter expanded` | root | 1,425 passed, 1 skipped, 1 failed before the stderr assertion fix; 24m 14s |
| `flutter test --no-pub test/tool/polygon_terrain_signature_probe_test.dart test/ui/controls/ability_slot_visual_spec_test.dart --reporter expanded` | root | Pass; all 5 tests, including the corrected subprocess assertion |
| `gradlew.bat -I ../.tmp/dependency-update/verify-kotlin.init.gradle help --console=plain` | `android` | Pass; all 12 Android modules use built-in Kotlin without legacy KGP |
| `gradlew.bat :firebase_auth:clean :firebase_auth:compileDebugKotlin --console=plain` | `android` | Pass; clean native Auth compilation |
| `gradlew.bat :firebase_core:clean :firebase_auth:clean :firebase_app_check:clean :cloud_functions:clean :cloud_firestore:clean :firebase_crashlytics:clean --console=plain` | `android` | Pass; cleared the updated plugins' generated outputs |
| `flutter build apk --debug --flavor dev` after plugin cleanup | root | Pass; `app-dev-debug.apk`, all three Android ABIs; Gradle 463.1s |
| `flutter build apk --config-only --release --flavor dev --target-platform android-arm64` | root | Pass; refreshed normal app registration and release configuration |
| ARM64 Gradle release invocation below, preceded by `--dry-run` | `android` | Pass; AOT, R8, release lint and APK packaging; 12m 17s |

The ARM64 release check uses this Gradle invocation from `android`, following
a successful `--dry-run` of the same arguments:

```powershell
.\gradlew.bat :app:assembleDevRelease `
  -x :app:uploadCrashlyticsMappingFileDevRelease `
  -Ptarget-platform=android-arm64 -Ptarget=lib/main.dart `
  -Pdart-obfuscation=false -Ptrack-widget-creation=false -Ptree-shake-icons=true `
  -Pflutter.androidSdkRoot=C:/Users/Toonsa/AppData/Local/Android/sdk `
  -Pflutter.installedNdkVersions=28.2.13676358 `
  -Pflutter.sdkManagerPath=C:/Users/Toonsa/AppData/Local/Android/sdk/cmdline-tools/latest/bin/sdkmanager.bat `
  --console=plain
```

Only the Crashlytics mapping upload is excluded for this local verification;
the release compile, lint and shrinking tasks remain in the plan. This avoids
the plugin's [automatic mapping upload](https://firebase.google.com/docs/crashlytics/android/get-deobfuscated-reports)
without changing the project's release configuration. No APK was installed.

The resulting `build/app/outputs/flutter-apk/app-dev-release.apk` is
142,130,597 bytes, SHA-256
`a0d84180c57b6f4d89aa0d79604a5d22dafc88134842e212ea543dc19cadfdb8`.
Archive inspection confirms ARM64 Flutter engine and app libraries plus JNI
and datastore libraries. Dependency AARs also contribute JNI/datastore libraries
for ARMv7 and x86_64; this check does not establish a runnable release on those
architectures. The APK uses dev signing, not staging/prod signing.

The first native compilation after migration reported unresolved `PigeonParser`
references in Firebase Auth 7.0.1. Its downloaded source contained that class.
Rebuilding only the plugin's generated outputs with
`gradlew.bat :firebase_auth:clean :firebase_auth:compileDebugKotlin --console=plain`
cleared the error. The package and Kotlin compiler versions were unchanged;
no dependency source was patched or downgraded. This points to stale incremental
compilation state across the dependency update. The next app build reached Java
compilation but could not find `FirebaseAppCheckPlugin`, despite its presence in
the package source. Old legacy Kotlin output remained in the build directory,
while the built-in Kotlin debug output was absent. Cleared generated outputs
for all six updated Firebase modules before rebuilding the app.
The resulting debug APK is 327,707,657 bytes, SHA-256
`19f64ac3b941f24bc11bea697fc6dc52d6397f57f997b99e5781b48a9a38ed81`.

The full client suite's only failure was the standalone terrain signature probe's
empty-stderr assertion: the new native hooks write `Running build hooks...` to
stderr. The fix retains the successful exit, exact JSON, reviewed signatures
and cross-process equality requirements. The focused rerun is recorded separately;
the full suite is not represented as an all-green invocation.

The remaining nine newer packages are constrained by Flutter or dependencies:
`_fe_analyzer_shared`, `analyzer`, `cross_file`, `dbus`,
`material_color_utilities`, `package_config`, `test`, `test_api`, and `test_core`.
No dependency overrides were introduced. Existing navigation artifacts were
reused after the fingerprint check.

Full-tree `flutter analyze --no-pub` was cancelled in favor of the
affected-workspace command `dart analyze lib packages test tools/admin`.
Changed documentation links and anchors resolve, and `git diff --check` passes.
Builds retain upstream plugin deprecation warnings, the documented false-positive
KGP warning, and the existing `android.newDsl=false` compatibility warning.
These results do not establish compatibility with AGP/Gradle 10.

Live sign-in, App Check, callables, Firestore listeners, Crashlytics delivery and
device persistence remain unrun checks. Unit tests and local builds do not
establish those results. Signed staging/prod release acceptance is separate.
