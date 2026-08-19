# Windows Chunk Playtest Phase 6 Acceptance

Date: August 19, 2026

Decision: Accepted for Phase 6 closeout with native automated Windows evidence.

This record distinguishes native automation from human observation. No human
manual visual pass was performed or claimed. The native Windows-engine test,
focused widget/unit coverage, release build, and immutable-source hashes are
accepted together as the Phase 6 Windows evidence. A future operator may still
repeat the documented controls manually without reopening this implementation
plan unless that pass finds a defect.

## Environment

| Field | Value |
| --- | --- |
| OS | Windows 11 Famille 10.0, Build 26200 |
| CPU availability | 16 logical processors |
| Dart | 3.11.5 stable, `windows_x64` |
| Native acceptance revision | `c3d93f9b1bae6ba4506051ea018993b6e65a6cf6` |
| Working tree | Dirty: Phase 6 documentation plus the pre-existing user-owned terrain-material line-ending change |
| Profile executable | `tools/editor/build/windows/x64/runner/Profile/runner_editor.exe` |
| Release executable | `tools/editor/build/windows/x64/runner/Release/runner_editor.exe` |

The machine-readable driver report was written to
`.tmp/windows_chunk_playtest_phase6.json`. `.tmp` is intentionally untracked;
the stable evidence is summarized here.

## Native Windows-engine evidence

Command:

```powershell
cd tools/editor
flutter drive --profile `
  --driver=test_driver/chunk_playtest_windows_acceptance_driver.dart `
  --target=integration_test/chunk_playtest_windows_acceptance_test.dart `
  -d windows
```

Result: pass. The profile Windows executable built and the real
repository-backed Chunk Creator completed the test in the Windows engine.

| Acceptance item | Native automated result | Supporting focused evidence |
| --- | --- | --- |
| Real editor/host | Loaded `ChunkDomainPlugin`, mounted `ChunkCreatorPage`, prepared the selected canonical source, and reached Ready in 154,851 microseconds | Preparation tests cover accepted pending documents and deterministic failures |
| Keyboard rollover | Held `D`, added Right Arrow, released `D`, and continued moving 13 world units | Desktop adapter tests cover alternate-source reference counting, opposing keys, and repeat suppression |
| Mouse input | Dispatched primary and secondary mouse-button actions inside the fitted host | Adapter tests cover chords, release, cancel, exit, and re-entry |
| Resize and DPI | Continued running from 1280x800 at DPR 1.0 to 1920x1200 at DPR 1.5 | Aim-geometry tests cover logical-coordinate invariance, letterbox boundaries, and non-default alignment |
| Focus/deactivation | Forwarded `inactive`, observed paused input-neutral state, then required explicit `P` resume | Editor lifecycle tests repeat inactive, paused, hidden, and detached cycles; this is the Alt+Tab-equivalent route contract, not a literal OS key chord |
| Restart | `F6` created a fresh scenario at tick 0 | Host tests prove the new runtime ignores stale callbacks |
| Stop/Edit restoration | Escape removed the host and returned the identical editor state and document | Repeated-cycle test proves each host controller is disposed |
| Repository safety | SHA-256 hashes remained stable for the relevant authoring and generated files | Workspace-bundle and preparation tests contain additional no-write checks |
| Game over | Not delayed to terminal state in the native smoke | Real Core/Flame host widget test reaches game over, displays no-reward/replay state, and restarts deterministically |

No crash, framework exception, stale lifecycle callback, source write, replay,
or backend side effect was observed. The `flutter drive` command prints an
`integration_test plugin was not detected` warning after the test process has
already reported all tests passed; the driver still connected and persisted
the complete `reportData` payload above.

## Preparation profile

Command:

```powershell
cd tools/editor
flutter test test/chunk_playtest_performance_test.dart
```

The canonical repository fixture used 2 warmups, 12 measured capture/
synchronous-preparation samples, and 4 background-isolate samples.

| Operation | Minimum | Median | p95 / maximum |
| --- | ---: | ---: | ---: |
| Accepted-document capture | 2.962 ms | 5.021 ms | 6.934 ms |
| Synchronous preparation reference | 7.637 ms | 10.057 ms | 13.735 ms |
| Background preparation | 7.571 ms | 9.761 ms | 14.546 ms |

These are observational values from the environment above, not portable CI
thresholds. The production editor captures immutable data from the command
path and performs compilation in a background isolate; no measured work was
moved into widget `build`, and no refactor was warranted.

## Broader validation and accepted exception

- Scoped root analysis, 68 focused input/host tests, the full 802-test root
  suite, Core analysis and 381 Core tests, content-pipeline analysis and 41
  tests, editor analysis, focused editor tests, and generator dry-run passed.
- Two stale broad-suite assertions were aligned with already implemented
  fail-closed boundaries: malformed staged terrain is rejected when the Core
  catalog is constructed, and Core's tooling-only `ChunkPlaytestScenario` is
  an allowed staged-terrain consumer beside `GameCore`.
- The release Windows editor build passed.
- The full editor suite completed 526 tests and retained one verified
  working-tree exception in `terrain_materials_page_test.dart:87`. Git's
  clean-filter hash for the user-owned
  `assets/authoring/level/terrain_material_defs.json` equals `HEAD`, but its
  working-tree line endings are noncanonical for the editor codec. A no-op
  dialog save therefore reports a pending canonicalization. Phase 6 did not
  alter or stage that file.
- Import, backend/replay, source-write, public-export, whitespace, and package
  boundary searches found no Phase 6 violation.

## Manual evidence

No human/manual evidence is recorded. In particular, this document does not
claim a person visually evaluated animation quality, changed the operating
system's global display scale, or pressed physical Alt+Tab. Those aspects are
covered at their deterministic boundaries by the Windows engine run plus
logical DPR/resize and app-lifecycle tests. The control legend was checked
against the fixed binding table in code and `tools/editor/README.md`.

## Final acceptance

Phase 6 is accepted. The delivered Windows editor mode is deterministic,
backend-free, repository-read-only during Play, lifecycle-safe, and documented.
Keyboard/mouse composition in the production game remains a separate
follow-on; this acceptance does not enable or claim that product behavior.
