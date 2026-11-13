/// Tooling-only APIs for captured authored Chunk, Level and Campaign playtests.
///
/// These explicit construction paths have no product app/backend integration.
/// All scenarios share runtime, HUD, controls and logical display geometry.
/// A standalone host uses a fixed logical preview; the Windows editor owns the
/// calibrated physical scale, prelaunch settings and monitor profile storage.
/// Product and Training keep separate lifecycle policies and actual displays.
library;

export 'package:runner_core/playtest/chunk_playtest_scenario.dart'
    show
        ChunkPlaytestScenario,
        ChunkPlaytestScenarioPath,
        PlaytestScenarioException;
export 'package:runner_core/playtest/level_playtest_scenario.dart'
    show LevelPlaytestScenario, LevelPlaytestChunkSample;
export 'package:runner_core/playtest/playtest_scenario.dart';
export 'package:runner_core/playtest/campaign_playtest_scenario.dart';

export 'playtest/runner_playtest_host.dart';
export 'playtest/runner_playtest_presentation.dart';
export 'playtest/runner_playtest_display.dart';
export 'playtest/runner_playtest_device_presets.dart';
export 'ui/controls/movement_control_mode.dart';
export 'ui/viewport/viewport_metrics.dart' show ViewportScaleMode;
export 'playtest/runner_playtest_appearance.dart';
export 'playtest/runner_workspace_asset_bundle.dart';
