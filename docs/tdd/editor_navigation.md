# Editor navigation

The home shell owns one browser-style history across Entities, Prefab Creator,
Chunk Creator, Level Creator, Parallax, and Terrain Materials. Back/Forward are
separate from content Undo/Redo. The toolbar exposes both navigation actions;
Alt+Left and Alt+Right use the same guarded path when a dialog, editable text
field, or Play session does not own input.

## Visits and remembered locations

`EditorNavigationHistory` retains up to 100 visits and a last location per tool.
A visit contains the route ID, an immutable `EditorPageLocation`, and any Level
handoff context. Selecting a tool normally resumes its last location. Explicit
source links choose their exact target instead. Selecting the already active
tool is a no-op; selecting owners or tabs inside a tool updates the current view
without adding history entries. Leaving captures that view for this visit.

Each visit is independent: Chunk A → Prefab → Chunk B → Back → Back returns to
Chunk A. Back/Forward move the cursor without adding visits. New navigation after
Back removes the forward branch while preserving the last locations of other
tools. The Level return banner uses the earlier matching Level visit when it is
available, retaining Forward through the content-editing journey.

Navigation state lasts for the current shell/session; replacing the session
controller clears both history and remembered locations, including on workspace
replacement. Existing Level Creator disk-backed view preferences still provide
its first-visit defaults. A navigation location takes precedence over those
defaults. No new workspace files, preferences, or authored fields are written.

## One transition path

`EditorHomePage._navigate` handles the route selector, history, source links,
Build report destinations, and Level returns:

1. Admit one request while the shell is available. Save, refresh recovery,
   transaction recovery, Build, Play, and dependency repair keep their existing
   locks. Navigation requests remain serialized until the destination mounts.
2. Resolve local input and accepted edits through the existing Save all,
   Discard all, or Cancel decision. Save must permit departure; rejected input,
   failed writes, and failed post-write refresh retain the originating page.
3. Capture the origin after Save, so accepted identity edits are remembered.
4. Load fresh repository data through the destination plugin using
   `EditorSessionController.loadWorkspaceForPlugin`. Explicit source links
   preflight their exact saved target. The location may restore a domain's
   active-level selection through plugin commands before session installation.
5. Only after successful loading, commit history, select the route, and mount a
   new page with its typed location. Same-tool source links also remount a view.

Cancel and load failure leave the cursor, origin document, pending edits, and
forward branch unchanged. Discard permits replacement only once the target
loads successfully. There is no retained source-document cache: returning to a
Chunk after saving Prefab collision reloads its dependencies. Navigation also
establishes the normal fresh content Undo/Redo baseline for the loaded domain.

Dependency repair remains a bounded exception to page replacement: its origin
stays mounted with its raw inputs while a separate controller edits a dependency.
Ordinary navigation is unavailable during repair, and the repair visit is not
added to history. Its explicit return actions still reconcile authored intent
against fresh sources. See [Level recovery](editor_level_workspace.md).

## Page-owned restoration

Every route implements `EditorPageNavigationState`; wrapper pages delegate to
their workspace. `home_routes.dart` passes the location to its matching typed
page constructor. These snapshots retain view data only:

| Tool | Remembered context |
| --- | --- |
| Entities | Entry, text/type/dirty filters, zoom, animation/frame |
| Prefab Creator | Owner, workflow, collision selection/tool, pan/zoom, atlas source and prefab/tile slice selections, module and painting-tile selection |
| Chunk Creator | Level and Chunk, scene tab, placed prefab/marker/water selections, terrain selection/tool, pan/zoom, grid/edge/visual-preview toggles |
| Level Creator | Level, tab, Chunk/section selection, group filter, preview seed, search fields, settings visibility |
| Parallax | Active Level/theme and layer |
| Terrain Materials | Material key |

Pages reconcile stable IDs against current sources. Missing remembered owners
use the page's normal empty/default selection; removed child selections are
cleared. Polygon selections use the interaction layer's shape/index validation
before reaching its strict reducer. Explicit source-link targets and explicit
Level returns still fail when their required saved owner is missing.

Raw form input, unsaved geometry, drag operations, source bytes, scene/image
caches, and content undo stacks are excluded. The departure guard resolves edits;
a location must never become another content persistence authority.

## Verification

`editor_navigation_history_test.dart` covers independent visits, forward-branch
truncation, bounded history, and reset. `owning_prefab_navigation_test.dart`
covers all three Chunk-to-Prefab destinations, Back/Forward, and normal switching.
`editor_tool_locations_test.dart` covers the remaining four tools using disposable
current-schema sources. Shell tests cover Cancel, Discard, failed Save, failed
loads, configuration errors, and controller/workspace replacement. Existing
Level journeys, Build, Save/recovery, and Play checks remain part of the editor
test suite.
