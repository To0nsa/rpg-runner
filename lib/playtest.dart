/// Tooling-only API for deterministic authored-chunk playtests.
///
/// This barrel is intentionally separate from `runner.dart`: editor hosts can
/// run an immutable scenario without importing product app/backend behavior.
library;

export 'package:runner_core/playtest/chunk_playtest_scenario.dart'
    show
        ChunkPlaytestScenario,
        ChunkPlaytestScenarioException,
        ChunkPlaytestScenarioPath;
export 'playtest/runner_chunk_playtest_host.dart';
export 'playtest/runner_workspace_asset_bundle.dart';
