# Off-screen actor indicators

The [HUD design](../gdd/03_ingame_hud.md#35-off-screen-player-and-enemy-indicators)
defines the left/top player and enemy markers. This feature is presentation
only: Core, input commands, replay protocols, backend and scoring are unchanged.

## Frame ownership and timing

`RunnerFlameGame.offscreenIndicators` is a run-owned value listenable, published
after the renderer samples the base camera each frame. `OffscreenIndicatorFrame`
interpolates current live player/enemy positions against the previous entity
map using the same alpha as actor rendering. New actors use their current pose.
The frame carries snapshot body extents and excludes `death`/`casterDeath` poses,
other entity kinds and the separate ghost feed. Game-over frames contain no
targets. This is a visual selection, not a new definition of combat eligibility.

The camera comes from the renderer's base center, including the arena camera
override, before shake. This intentionally stabilizes bearings during impact
and boss entrance feedback. The notifier is disposed with the Flame game;
preparation cancellation fences subsequent frame updates.

## Visibility and distance

`RunnerGameWidget` computes `ViewportMetrics` once for both `GameViewport` and
the HUD. `IndicatorViewport` intersects the fitted view with host bounds, then
maps that visible rectangle back through `WorldViewTransform`. Cover cropping,
contain letterboxing, non-centered alignment and DPI therefore use the actual
visible game region. HUD panels and safe-area insets do not change visibility
or distances; they constrain only the painted labels.

`OffscreenIndicatorProjector` owns a run-local set of previously shown entity
IDs. It requires a two-world-unit body clearance for a new left/top marker,
retains it while still outside, and removes it when the body touches the view.
IDs absent from a frame are pruned, and a new run resets history. A corner gets
one marker. Right-only/bottom-only departures are excluded.

Distance is the Euclidean separation between the body rectangle and the visible
world rectangle divided by `kWorldUnitsPerMeter`. It does not measure distance
from the player, from a displaced HUD label, or remaining fall-behind grace.

## HUD composition

`OffscreenIndicatorOverlay` paints through a `CustomPainter` driven directly by
the frame listenable, inside `IgnorePointer` and `RepaintBoundary`. It is mounted
only while the run UI is active. Replacing the frame source resets projector
history. The existing HUD theme supplies colors; labels respect text scaling.

The HUD provides tight layout keys for its top row and boss panel. Their bounds
are read after layout in the painter's local coordinate system, without build
side effects or a post-frame setState loop. Control exclusions reuse existing
control tuning and radial layout, including the floating joystick's possible
paint overflow and the fixed joystick footprint. Non-equipped action slots are
conservatively reserved as well.

Placement reserves the player first, then orders enemies by distance and stable
ID. Grouping uses original projected label bounds, before other markers displace
them, so reserving a player slot does not split an enemy cluster. Groups only
combine enemies on the same edge and keep their nearest distance. Labels avoid
panel/control bounds and each other; when no slot remains, enemies join an
existing same-edge group if its expanded label fits, otherwise they are omitted.
Extremely small hosts or large accessibility text may leave no readable slot.

## Validation

- `test/game/offscreen_indicators_test.dart`: body visibility, corners, metric
  distance, hysteresis, camera movement, run/despawn cleanup and interpolation.
- `test/ui/hud/game/offscreen_indicator_layout_test.dart`: cropping, letterbox,
  alignment/DPI, safe bounds, clustering and obstacle avoidance.
- `test/ui/hud/game/hud_layout_test.dart`: actual HUD composition at 480×320 and
  844×390, rendered review PNGs in `build/test/`, and pause/exit hit targets.
