# Pub Workspace And Dependency Resolution

## Purpose

The repository uses a Pub workspace for the root runtime and its shared
libraries. This gives those packages one dependency resolution, one analyzer
package configuration, and one committed root lockfile.

## Workspace Membership

The root `pubspec.yaml` is the workspace root. It includes:

- `rpg_runner` at the repository root
- every package under `packages/*`

Workspace members declare `resolution: workspace`. Their package manifests
retain path dependencies because those relationships remain explicit and can
still be inspected from each consumer.

Run workspace dependency commands from the repository root:

```powershell
flutter pub get
dart pub workspace list
flutter pub outdated
flutter pub upgrade
```

The root `pubspec.lock` is the only committed lockfile for workspace members.
Do not generate or commit member lockfiles under `packages/*`.

The shared libraries allow `test` 1.31.1 so Flutter 3.47.1 can select the test
runner compatible with its pinned `test_api` 0.7.12. Raise those constraints
only together with the repository Flutter baseline; overriding an SDK-pinned
test package is not supported.

## Independent Application Boundaries

`tools/editor` is intentionally not a workspace member. It directly consumes
the Analyzer package for guarded source edits, while the Flutter SDK pins the
test infrastructure used by the root workspace. At the repository's supported
Flutter 3.47.1 baseline, those constraints do not have one safe shared
resolution. The editor keeps its own committed `pubspec.lock`; do not override
Flutter's pinned test packages or downgrade Analyzer merely to force a shared
resolution.

Resolve and run the editor independently:

```powershell
Push-Location tools/editor
flutter pub get --enforce-lockfile
flutter analyze
flutter test
Pop-Location
```

`services/replay_validator` is intentionally not a workspace member. It is a
pure-Dart Cloud Run application built in a pinned Dart SDK container, while the
workspace contains Flutter SDK dependencies. Including it would force its
dependency resolution, CI, and container build to install Flutter despite the
service's pure-Dart boundary.

The validator therefore keeps its own committed `pubspec.lock`. Resolve and
verify it independently:

```powershell
Push-Location services/replay_validator
dart pub get --enforce-lockfile
dart analyze
dart test test
Pop-Location
```

Its path dependencies on `runner_core` and `run_protocol` continue to use the
checked-out repository sources. Changes to either shared package require both
workspace validation and validator validation.

## Validation

After changing workspace membership or dependency constraints:

1. Run `flutter pub get` at the repository root.
2. Confirm `dart pub workspace list` reports the root app and every package
   under `packages/*`.
3. Confirm no member-level `pubspec.lock` files remain.
4. Analyze and test each affected package from its normal directory.
5. Run the editor and replay validator's enforced standalone resolutions and
   checks when a shared dependency or its constraints changed.
