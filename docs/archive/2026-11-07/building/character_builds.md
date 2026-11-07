# Character builds

Implement three independent saved builds for each character. Build 1 is available
at level 1, Build 2 at level 5, and Build 3 at level 12. Unlocks use confirmed
account progression. Developer Practice remains isolated from online authority.

- [x] Replace the single loadout/name selection with three named build slots and
  a selected slot per character; use a clean schema revision, without migration.
- [x] Bind queued equipment/ability edits to their original build. Validate slot
  bounds, names (12 grapheme clusters), ownership and level gates on the backend.
- [x] Resolve the selected build for run tickets, Training Field and menu gear.
- [x] Put character art/name at the left and three build buttons at the right of
  each chooser card; retain single-screen layout and unselected scrim.
- [x] Replace builder character switching with its build name and rename dialog.
- [x] Verify slot isolation, persistence, unlock thresholds, rejected bypasses,
  queued edits, rename failures and responsive layout with screenshots.
- [x] Update implemented contracts and local evidence, review and commit.

Local implementation only. No deployment, account reset or run cancellation.

Completed locally on 2026-11-07. See [verification](../../../verification/character-builds-2026-11-07.md)
for native/emulator results and the explicit unverified browser smoke (local
CanvasKit resources returned 404). No rollout or remote reset was performed.
