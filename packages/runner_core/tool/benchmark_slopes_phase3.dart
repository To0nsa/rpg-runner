import 'dart:convert';
import 'dart:io';

import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/navigation/terrain_surface_graph_builder.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';

import 'src/slopes_phase3_benchmark_fixture.dart';

/// Reproducible Phase 3 enemy/navigation terrain benchmark.
///
/// Acceptance numbers must be captured from a compiled executable:
///
/// ```text
/// dart compile exe tool/benchmark_slopes_phase3.dart -o .tmp/slopes-phase3.exe
/// .tmp/slopes-phase3.exe --strict --json-out=.tmp/slopes-phase3.json
/// ```
void main(List<String> args) {
  final config = _BenchmarkConfig.fromArgs(args);
  final representativeSlope = SlopesPhase3BenchmarkFixture.build(
    edgeCount: slopesPhase3RepresentativeEdgeCount,
    sloped: true,
  );
  final representativeFlat = SlopesPhase3BenchmarkFixture.build(
    edgeCount: slopesPhase3RepresentativeEdgeCount,
    sloped: false,
  );
  final hardGeometry = buildSlopesPhase3BenchmarkGeometry(
    edgeCount: slopesPhase3HardStreamEdgeCount,
    sloped: true,
    geometryVersion: 61,
  );
  final replacementGeometry = buildSlopesPhase3BenchmarkGeometry(
    edgeCount: slopesPhase3RepresentativeEdgeCount,
    sloped: true,
    geometryVersion: representativeSlope.geometry.version + 1,
  );

  final grojibProfile = representativeSlope.profiles.singleWhere(
    (profile) => profile.profileKey == EnemyId.grojib.name,
  );
  final hashashProfile = representativeSlope.profiles.singleWhere(
    (profile) => profile.profileKey == EnemyId.hashash.name,
  );
  final extractionAndIndex = _measureOperation(
    runs: config.rebuildRuns,
    warmup: config.rebuildWarmup,
    operation: () => buildSlopesPhase3SurfaceStack(
      representativeSlope.geometry,
    ).surfaceSet.surfaces.length,
  );
  final grojibGraphBuilder = TerrainSurfaceGraphBuilder(
    placementQuery: representativeSlope.stack.placementQuery,
  );
  final grojibGraph = _measureOperation(
    runs: config.rebuildRuns,
    warmup: config.rebuildWarmup,
    operation: () => grojibGraphBuilder.build(grojibProfile).edges.length,
  );
  final hashashGraphBuilder = TerrainSurfaceGraphBuilder(
    placementQuery: representativeSlope.stack.placementQuery,
  );
  final hashashGraph = _measureOperation(
    runs: config.rebuildRuns,
    warmup: config.rebuildWarmup,
    operation: () => hashashGraphBuilder.build(hashashProfile).edges.length,
  );
  final bothGraphBuilder = TerrainSurfaceGraphBuilder(
    placementQuery: representativeSlope.stack.placementQuery,
  );
  final bothGraphs = _measureOperation(
    runs: config.rebuildRuns,
    warmup: config.rebuildWarmup,
    operation: () {
      return bothGraphBuilder.build(grojibProfile).edges.length +
          bothGraphBuilder.build(hashashProfile).edges.length;
    },
  );
  final combinedBundle = _measureOperation(
    runs: config.rebuildRuns,
    warmup: config.rebuildWarmup,
    operation: () => TerrainRuntimeBundle.build(
      geometry: representativeSlope.geometry,
      groundEnemyProfiles: representativeSlope.profiles,
    ).graphPublication.graphs.length,
  );
  final replacement = _measureWithSetup<TerrainMultiBodyWorldMotionAuthority>(
    runs: config.replacementRuns,
    warmup: 1,
    setup: () => TerrainMultiBodyWorldMotionAuthority(
      geometry: representativeSlope.geometry,
      playerProfile: buildSlopesPhase3PlayerProfile(),
      groundEnemyGraphProfiles: representativeSlope.profiles,
    ),
    operation: (authority) {
      authority.queueTerrainGeometryReplacement(replacementGeometry);
      return authority.terrainGeometryVersion;
    },
  );

  final hardStack = buildSlopesPhase3SurfaceStack(hardGeometry);
  final hardIndexBuild = _measureOperation(
    runs: config.hardRuns,
    warmup: 1,
    operation: () =>
        TerrainEdgeIndex(edges: hardGeometry.edges).insertedReferences,
  );
  final hardQueries = _measureQueries(
    hardStack.edgeIndex,
    iterations: config.queryIterations,
    warmup: config.hotWarmup,
  );

  final groundControllerCases = <SlopesPhase3ControllerCase>[
    SlopesPhase3ControllerCase.supported(
      fixture: representativeSlope,
      enemyId: EnemyId.grojib,
    ),
    SlopesPhase3ControllerCase.supported(
      fixture: representativeSlope,
      enemyId: EnemyId.hashash,
    ),
  ];
  final flyingControllerCases = <SlopesPhase3ControllerCase>[
    SlopesPhase3ControllerCase.flyingBlocked(fixture: representativeSlope),
  ];
  final groundController = _measureControllers(
    groundControllerCases,
    iterations: config.hotIterations,
    warmup: config.hotWarmup,
  );
  final flyingController = _measureControllers(
    flyingControllerCases,
    iterations: config.hotIterations,
    warmup: config.hotWarmup,
  );

  final navigation = SlopesPhase3NavigationHarness.build(representativeSlope)
    ..warm();
  final predictorResizeStart = navigation.predictor.queryBufferResizeCount;
  final navigatorSteady = _measureHot(
    iterations: config.hotIterations,
    warmup: config.hotWarmup,
    operation: navigation.runSteadyState,
  );
  final navigatorRepath = _measureHot(
    iterations: config.navigationRepathIterations,
    warmup: config.rebuildWarmup,
    operation: navigation.runRepath,
  );
  final trajectory = _measureHot(
    iterations: config.trajectoryIterations,
    warmup: config.hotWarmup,
    operation: navigation.runTrajectory,
  );
  final predictorResizeDelta =
      navigation.predictor.queryBufferResizeCount - predictorResizeStart;

  final flyingHarness = SlopesPhase3MixedEnemyHarness.build(
    representativeSlope.geometry,
  )..runTick();
  final flyingClearance = _measureHot(
    iterations: config.hotIterations,
    warmup: config.hotWarmup,
    operation: flyingHarness.runFlyingClearanceProbe,
  );

  final mixedPair = _measureBalancedMixedEnemyTicks(
    flatGeometry: representativeFlat.geometry,
    slopeGeometry: representativeSlope.geometry,
    runs: config.mixedRuns,
    warmupTicks: config.mixedWarmupTicks,
    measuredTicks: config.mixedTicks,
  );
  final slopeMixed = mixedPair.slope;
  final flatMixed = mixedPair.flat;
  final mixedOverheadPercent = flatMixed.timing.mean == 0
      ? 0.0
      : (slopeMixed.timing.mean - flatMixed.timing.mean) /
            flatMixed.timing.mean *
            100;

  final allCandidates = _Stats(<int>[
    ...groundController.candidates.values,
    ...flyingController.candidates.values,
    ...slopeMixed.candidates.values,
    ...hardQueries.candidates.values,
  ]);
  final controllerBufferResizeDelta =
      groundController.bufferResizeDelta + flyingController.bufferResizeDelta;
  final allDynamicSolveTimings = _Stats(<int>[
    ...groundController.timing.values,
    ...flyingController.timing.values,
  ]);
  final graphDestinationsValid =
      <TerrainSurfaceGraph>[
        representativeSlope.bundle.grojibGraph,
        representativeSlope.bundle.hashashGraph,
      ].every(
        (graph) => graph.edges.every(
          (edge) => edge.to >= 0 && edge.to < graph.surfaces.length,
        ),
      );
  final boundedLoops =
      groundController.contactIterations.max <= terrainMaxBlockingContacts &&
      groundController.recoveryIterations.max <= terrainMaxRecoveryIterations &&
      flyingController.contactIterations.max <= terrainMaxBlockingContacts &&
      flyingController.recoveryIterations.max <= terrainMaxRecoveryIterations &&
      slopeMixed.maxContactIterations <= terrainMaxBlockingContacts &&
      slopeMixed.maxRecoveryIterations <= terrainMaxRecoveryIterations &&
      navigation.lastExpandedNodeCount < slopesPhase3PathfinderExpansionLimit &&
      navigation.predictor.lastTicksSimulated <=
          navigation.graph.buildProfile.jumpTemplate.profile.maxAirTicks;
  final noTruncation =
      representativeSlope.geometry.edges.length ==
          slopesPhase3RepresentativeEdgeCount &&
      hardGeometry.edges.length == slopesPhase3HardStreamEdgeCount &&
      hardQueries.bufferResizeDelta == 0 &&
      graphDestinationsValid &&
      navigation.pathCapacity > 0 &&
      navigation.prediction.hasLanding;
  final gates = <String, bool>{
    'representative_edge_count':
        representativeSlope.geometry.edges.length ==
        slopesPhase3RepresentativeEdgeCount,
    'hard_stream_edge_count':
        hardGeometry.edges.length == slopesPhase3HardStreamEdgeCount,
    'enemy_candidate_p95': allCandidates.p95 <= 24,
    'enemy_candidate_p99': allCandidates.p99 <= 64,
    'dynamic_actor_solve_p95_us': allDynamicSolveTimings.p95 <= 75,
    'dynamic_actor_solve_p99_us': allDynamicSolveTimings.p99 <= 150,
    'grojib_graph_p95_us': grojibGraph.p95 <= 5000,
    'grojib_graph_p99_us': grojibGraph.p99 <= 10000,
    'hashash_graph_p95_us': hashashGraph.p95 <= 5000,
    'hashash_graph_p99_us': hashashGraph.p99 <= 10000,
    'both_graphs_p95_us': bothGraphs.p95 <= 20000,
    'both_graphs_p99_us': bothGraphs.p99 <= 35000,
    'combined_bundle_p95_us': combinedBundle.p95 <= 35000,
    'combined_bundle_p99_us': combinedBundle.p99 <= 50000,
    'hard_index_rebuild_p99_us': hardIndexBuild.p99 <= 50000,
    'whole_core_slope_tick_p99_us': slopeMixed.timing.p99 <= 2000,
    'whole_core_slope_tick_hard_p99_us': slopeMixed.timing.p99 < 4000,
    'matched_flat_overhead': mixedOverheadPercent <= 25,
    'steady_state_controller_query_allocations':
        controllerBufferResizeDelta == 0,
    'steady_state_query_buffer_growth':
        hardQueries.bufferResizeDelta == 0 && predictorResizeDelta == 0,
    'bounded_loops': boundedLoops,
    'no_candidate_path_edge_truncation': noTruncation,
    'mixed_enemy_dynamic_body_count': slopeMixed.lastIntegratedBodyCount == 20,
  };
  final passed = gates.values.every((value) => value);
  final slopeIndex = representativeSlope.bundle.edgeIndex;
  final report = <String, Object?>{
    'benchmark': 'slopes-phase3-enemy-navigation-v1',
    'revision': _gitOutput(<String>['rev-parse', '--short', 'HEAD']),
    'dirty': _gitOutput(<String>['status', '--porcelain']).isNotEmpty,
    'os': Platform.operatingSystem,
    'osVersion': Platform.operatingSystemVersion,
    'dartVersion': Platform.version,
    'runtimeMode': const bool.fromEnvironment('dart.vm.product')
        ? 'compiled-product'
        : 'jit-development',
    'fixture': <String, Object>{
      'name': 'phase3-representative-5-chunk-1280-edge-v1',
      'signature': representativeSlope.geometry.edgeSignature(
        indexMembershipRecords: slopeIndex.canonicalMembershipRecords(),
      ),
      'surfaceSignature': representativeSlope.bundle.surfaceSignature(),
      'graphSignature': representativeSlope.bundle.graphSignature(),
      'chunks': slopesPhase3ChunkCount,
      'edges': representativeSlope.geometry.edges.length,
      'surfaceNodes': representativeSlope.nodeCount,
      'graphEdges': representativeSlope.graphEdgeCount,
      'actors': const <String, int>{
        'player': 1,
        'grojib': 8,
        'hashash': 8,
        'unocoDemon': 4,
        'derf': 4,
      },
    },
    'config': config.toJson(),
    'surfaceExtractionAndIndexBuildUs': extractionAndIndex.toJson(),
    'grojibGraphBuildUs': grojibGraph.toJson(),
    'hashashGraphBuildUs': hashashGraph.toJson(),
    'bothGroundEnemyGraphsBuildUs': bothGraphs.toJson(),
    'combinedTerrainBundleBuildUs': combinedBundle.toJson(),
    'controlledBundleReplacementBuildUs': replacement.toJson(),
    'hardStream': <String, Object>{
      'edges': hardGeometry.edges.length,
      'surfaceNodes': hardStack.surfaceSet.surfaces.length,
      'indexBuildUs': hardIndexBuild.toJson(),
      'queryUs': hardQueries.timing.toJson(),
      'candidates': hardQueries.candidates.toJson(),
      'bufferResizeDelta': hardQueries.bufferResizeDelta,
    },
    'supportedGroundEnemySolves': groundController.toJson(),
    'unocoBlockedFlightSolve': flyingController.toJson(),
    'navigatorSteadyStateUs': navigatorSteady.toJson(),
    'navigatorRepathUs': navigatorRepath.toJson(),
    'trajectoryPredictionUs': trajectory.toJson(),
    'trajectoryDiagnostics': <String, Object>{
      'ticksSimulated': navigation.predictor.lastTicksSimulated,
      'candidates': navigation.predictor.lastCandidateCount,
      'cellsVisited': navigation.predictor.lastQueryCellsVisited,
      'bufferResizeDelta': predictorResizeDelta,
    },
    'unocoBlockedFlightAndClearanceSteeringUs': flyingClearance.toJson(),
    'unocoClearanceCandidateId': flyingHarness.clearanceProbeCandidateId,
    'mixedEnemyFlatTick': flatMixed.toJson(),
    'mixedEnemySlopeTick': slopeMixed.toJson(),
    'mixedEnemySlopeOverFlatPercent': mixedOverheadPercent,
    'combinedEnemyCandidates': allCandidates.toJson(),
    'allocationEvidence': <String, Object>{
      'controllerQueryBufferResizeDelta': controllerBufferResizeDelta,
      'trajectoryQueryBufferResizeDelta': predictorResizeDelta,
      'hardQueryBufferResizeDelta': hardQueries.bufferResizeDelta,
      'controllerVmProfile':
          'The exact TerrainCapsuleController hot loop is inherited from the '
          'accepted Phase 2 VM allocation profile; rerun with '
          '`dart --observe=0 run tool/benchmark_slopes_phase2.dart '
          '--allocation-profile --strict`.',
    },
    'boundedLoopDiagnostics': <String, Object>{
      'controllerContactLimit': terrainMaxBlockingContacts,
      'controllerContactObserved': <int>[
        groundController.contactIterations.max,
        flyingController.contactIterations.max,
      ].reduce((left, right) => left > right ? left : right),
      'controllerRecoveryLimit': terrainMaxRecoveryIterations,
      'controllerRecoveryObserved': <int>[
        groundController.recoveryIterations.max,
        flyingController.recoveryIterations.max,
      ].reduce((left, right) => left > right ? left : right),
      'pathfinderExpansionLimit': slopesPhase3PathfinderExpansionLimit,
      'pathfinderExpandedObserved': navigation.lastExpandedNodeCount,
      'predictorTickLimit':
          navigation.graph.buildProfile.jumpTemplate.profile.maxAirTicks,
      'predictorTicksObserved': navigation.predictor.lastTicksSimulated,
      'flyingSteeringCandidateLimit': 4,
    },
    'rebuildCounts': <String, int>{
      'representativeSamplesPerOperation': config.rebuildRuns,
      'hardSamples': config.hardRuns,
      'controlledReplacementSamples': config.replacementRuns,
    },
    'gates': gates,
    'passed': passed,
  };
  const encoder = JsonEncoder.withIndent('  ');
  final json = encoder.convert(report);
  stdout.writeln(json);
  if (config.jsonOutPath case final outputPath?) {
    final output = File(outputPath);
    output.parent.createSync(recursive: true);
    output.writeAsStringSync('$json\n');
  }
  if (config.strict && !passed) exitCode = 1;
}

final class _BenchmarkConfig {
  const _BenchmarkConfig({
    required this.rebuildRuns,
    required this.rebuildWarmup,
    required this.hardRuns,
    required this.replacementRuns,
    required this.hotWarmup,
    required this.hotIterations,
    required this.queryIterations,
    required this.navigationRepathIterations,
    required this.trajectoryIterations,
    required this.mixedRuns,
    required this.mixedWarmupTicks,
    required this.mixedTicks,
    required this.strict,
    required this.jsonOutPath,
  });

  factory _BenchmarkConfig.fromArgs(List<String> args) {
    int value(String name, int fallback) {
      final prefix = '--$name=';
      final raw = args
          .where((argument) => argument.startsWith(prefix))
          .map((argument) => argument.substring(prefix.length))
          .firstOrNull;
      return raw == null ? fallback : int.parse(raw);
    }

    String? stringValue(String name) {
      final prefix = '--$name=';
      return args
          .where((argument) => argument.startsWith(prefix))
          .map((argument) => argument.substring(prefix.length))
          .firstOrNull;
    }

    return _BenchmarkConfig(
      rebuildRuns: value('rebuild-runs', 100),
      rebuildWarmup: value('rebuild-warmup', 2),
      hardRuns: value('hard-runs', 100),
      replacementRuns: value('replacement-runs', 100),
      hotWarmup: value('warmup', 500),
      hotIterations: value('iterations', 5000),
      queryIterations: value('query-iterations', 10000),
      navigationRepathIterations: value('repath-iterations', 1000),
      trajectoryIterations: value('trajectory-iterations', 1000),
      mixedRuns: value('mixed-runs', 4),
      mixedWarmupTicks: value('mixed-warmup', 300),
      mixedTicks: value('mixed-ticks', 1000),
      strict: args.contains('--strict'),
      jsonOutPath: stringValue('json-out'),
    );
  }

  final int rebuildRuns;
  final int rebuildWarmup;
  final int hardRuns;
  final int replacementRuns;
  final int hotWarmup;
  final int hotIterations;
  final int queryIterations;
  final int navigationRepathIterations;
  final int trajectoryIterations;
  final int mixedRuns;
  final int mixedWarmupTicks;
  final int mixedTicks;
  final bool strict;
  final String? jsonOutPath;

  Map<String, Object> toJson() => <String, Object>{
    'rebuildRuns': rebuildRuns,
    'rebuildWarmup': rebuildWarmup,
    'hardRuns': hardRuns,
    'replacementRuns': replacementRuns,
    'hotWarmup': hotWarmup,
    'hotIterations': hotIterations,
    'queryIterations': queryIterations,
    'navigationRepathIterations': navigationRepathIterations,
    'trajectoryIterations': trajectoryIterations,
    'mixedRuns': mixedRuns,
    'mixedWarmupTicks': mixedWarmupTicks,
    'mixedTicks': mixedTicks,
    'strict': strict,
  };
}

_Stats _measureOperation({
  required int runs,
  required int warmup,
  required int Function() operation,
}) {
  var sink = 0;
  for (var index = 0; index < warmup; index += 1) {
    sink ^= operation();
  }
  final timings = List<int>.filled(runs, 0);
  final stopwatch = Stopwatch();
  for (var index = 0; index < runs; index += 1) {
    stopwatch
      ..reset()
      ..start();
    sink ^= operation();
    stopwatch.stop();
    timings[index] = stopwatch.elapsedMicroseconds;
  }
  if (sink == -1) stderr.writeln('unreachable');
  return _Stats(timings);
}

_Stats _measureWithSetup<T>({
  required int runs,
  required int warmup,
  required T Function() setup,
  required int Function(T value) operation,
}) {
  var sink = 0;
  for (var index = 0; index < warmup; index += 1) {
    sink ^= operation(setup());
  }
  final timings = List<int>.filled(runs, 0);
  final stopwatch = Stopwatch();
  for (var index = 0; index < runs; index += 1) {
    final value = setup();
    stopwatch
      ..reset()
      ..start();
    sink ^= operation(value);
    stopwatch.stop();
    timings[index] = stopwatch.elapsedMicroseconds;
  }
  if (sink == -1) stderr.writeln('unreachable');
  return _Stats(timings);
}

_Stats _measureHot({
  required int iterations,
  required int warmup,
  required void Function() operation,
}) {
  for (var index = 0; index < warmup; index += 1) {
    operation();
  }
  final timings = List<int>.filled(iterations, 0);
  final stopwatch = Stopwatch();
  for (var index = 0; index < iterations; index += 1) {
    stopwatch
      ..reset()
      ..start();
    operation();
    stopwatch.stop();
    timings[index] = stopwatch.elapsedMicroseconds;
  }
  return _Stats(timings);
}

_ControllerMeasurement _measureControllers(
  List<SlopesPhase3ControllerCase> cases, {
  required int iterations,
  required int warmup,
}) {
  for (var index = 0; index < warmup; index += 1) {
    for (final benchmarkCase in cases) {
      benchmarkCase.run();
    }
  }
  final resizeAtStart = <int>[
    for (final benchmarkCase in cases)
      benchmarkCase.controller.queryBufferResizeCount,
  ];
  final sampleCount = iterations * cases.length;
  final timings = List<int>.filled(sampleCount, 0);
  final candidates = List<int>.filled(sampleCount, 0);
  final contacts = List<int>.filled(sampleCount, 0);
  final contactIterations = List<int>.filled(sampleCount, 0);
  final recoveryIterations = List<int>.filled(sampleCount, 0);
  final stopwatch = Stopwatch();
  var sample = 0;
  for (var index = 0; index < iterations; index += 1) {
    for (final benchmarkCase in cases) {
      stopwatch
        ..reset()
        ..start();
      benchmarkCase.run();
      stopwatch.stop();
      timings[sample] = stopwatch.elapsedMicroseconds;
      candidates[sample] = benchmarkCase.result.candidateCount;
      contacts[sample] = benchmarkCase.result.contactCount;
      contactIterations[sample] = benchmarkCase.result.contactIterations;
      recoveryIterations[sample] = benchmarkCase.result.recoveryIterations;
      sample += 1;
    }
  }
  var resizeDelta = 0;
  for (var index = 0; index < cases.length; index += 1) {
    resizeDelta +=
        cases[index].controller.queryBufferResizeCount - resizeAtStart[index];
  }
  return _ControllerMeasurement(
    timing: _Stats(timings),
    candidates: _Stats(candidates),
    contacts: _Stats(contacts),
    contactIterations: _Stats(contactIterations),
    recoveryIterations: _Stats(recoveryIterations),
    bufferResizeDelta: resizeDelta,
  );
}

final class _ControllerMeasurement {
  const _ControllerMeasurement({
    required this.timing,
    required this.candidates,
    required this.contacts,
    required this.contactIterations,
    required this.recoveryIterations,
    required this.bufferResizeDelta,
  });

  final _Stats timing;
  final _Stats candidates;
  final _Stats contacts;
  final _Stats contactIterations;
  final _Stats recoveryIterations;
  final int bufferResizeDelta;

  Map<String, Object> toJson() => <String, Object>{
    'timingUs': timing.toJson(),
    'candidates': candidates.toJson(),
    'contacts': contacts.toJson(),
    'contactIterations': contactIterations.toJson(),
    'recoveryIterations': recoveryIterations.toJson(),
    'bufferResizeDelta': bufferResizeDelta,
  };
}

_QueryMeasurement _measureQueries(
  TerrainEdgeIndex index, {
  required int iterations,
  required int warmup,
}) {
  final buffer = index.createQueryBuffer();
  final queries = <TerrainAabb>[
    for (final edge in index.edges)
      edge.bounds.expanded(
        2 * terrainPhysicsTicksPerWorldUnit + terrainCollisionSkinTicks,
      ),
  ];
  for (var sample = 0; sample < warmup; sample += 1) {
    index.query(queries[sample % queries.length], buffer);
  }
  final resizeAtStart = buffer.resizeCount;
  final timings = List<int>.filled(iterations, 0);
  final candidates = List<int>.filled(iterations, 0);
  final stopwatch = Stopwatch();
  for (var sample = 0; sample < iterations; sample += 1) {
    stopwatch
      ..reset()
      ..start();
    index.query(queries[sample % queries.length], buffer);
    stopwatch.stop();
    timings[sample] = stopwatch.elapsedMicroseconds;
    candidates[sample] = buffer.candidateCount;
  }
  return _QueryMeasurement(
    timing: _Stats(timings),
    candidates: _Stats(candidates),
    bufferResizeDelta: buffer.resizeCount - resizeAtStart,
  );
}

final class _QueryMeasurement {
  const _QueryMeasurement({
    required this.timing,
    required this.candidates,
    required this.bufferResizeDelta,
  });

  final _Stats timing;
  final _Stats candidates;
  final int bufferResizeDelta;
}

_MixedPair _measureBalancedMixedEnemyTicks({
  required TerrainGeometry flatGeometry,
  required TerrainGeometry slopeGeometry,
  required int runs,
  required int warmupTicks,
  required int measuredTicks,
}) {
  if (runs < 3) {
    throw ArgumentError.value(
      runs,
      'runs',
      'Acceptance comparison requires at least three balanced runs.',
    );
  }
  final flatParts = <_MixedMeasurement>[];
  final slopeParts = <_MixedMeasurement>[];
  void flat() => flatParts.add(
    _measureMixedEnemyTicks(
      geometry: flatGeometry,
      runs: 1,
      warmupTicks: warmupTicks,
      measuredTicks: measuredTicks,
    ),
  );
  void slope() => slopeParts.add(
    _measureMixedEnemyTicks(
      geometry: slopeGeometry,
      runs: 1,
      warmupTicks: warmupTicks,
      measuredTicks: measuredTicks,
    ),
  );
  for (var run = 0; run < runs; run += 1) {
    if (run.isEven) {
      flat();
      slope();
    } else {
      slope();
      flat();
    }
  }
  return _MixedPair(
    flat: _mergeMixedMeasurements(flatParts),
    slope: _mergeMixedMeasurements(slopeParts),
  );
}

_MixedMeasurement _mergeMixedMeasurements(List<_MixedMeasurement> parts) {
  return _MixedMeasurement(
    timing: _Stats(parts.expand((part) => part.timing.values)),
    candidates: _Stats(parts.expand((part) => part.candidates.values)),
    lastIntegratedBodyCount: parts.last.lastIntegratedBodyCount,
    maxContactIterations: parts
        .map((part) => part.maxContactIterations)
        .reduce((left, right) => left > right ? left : right),
    maxRecoveryIterations: parts
        .map((part) => part.maxRecoveryIterations)
        .reduce((left, right) => left > right ? left : right),
    clearanceSelections: parts.fold<int>(
      0,
      (sum, part) => sum + part.clearanceSelections,
    ),
  );
}

final class _MixedPair {
  const _MixedPair({required this.flat, required this.slope});

  final _MixedMeasurement flat;
  final _MixedMeasurement slope;
}

_MixedMeasurement _measureMixedEnemyTicks({
  required TerrainGeometry geometry,
  required int runs,
  required int warmupTicks,
  required int measuredTicks,
}) {
  final timings = List<int>.filled(runs * measuredTicks, 0);
  final candidates = List<int>.filled(runs * measuredTicks * 20, 0);
  var lastIntegratedBodyCount = 0;
  var maxContactIterations = 0;
  var maxRecoveryIterations = 0;
  var clearanceSelections = 0;
  var timingCursor = 0;
  var candidateCursor = 0;
  final stopwatch = Stopwatch();
  for (var run = 0; run < runs; run += 1) {
    final harness = SlopesPhase3MixedEnemyHarness.build(geometry);
    for (var tick = 0; tick < warmupTicks; tick += 1) {
      harness.runTick();
    }
    for (var tick = 0; tick < measuredTicks; tick += 1) {
      stopwatch
        ..reset()
        ..start();
      harness.runTick();
      stopwatch.stop();
      timings[timingCursor] = stopwatch.elapsedMicroseconds;
      timingCursor += 1;
      candidateCursor = harness.writeCandidateCounts(
        candidates,
        candidateCursor,
      );
      lastIntegratedBodyCount = harness.lastIntegratedBodyCount;
      if (harness.maxContactIterations > maxContactIterations) {
        maxContactIterations = harness.maxContactIterations;
      }
      if (harness.maxRecoveryIterations > maxRecoveryIterations) {
        maxRecoveryIterations = harness.maxRecoveryIterations;
      }
      clearanceSelections += harness.clearanceSelectionCount;
    }
  }
  if (timingCursor != timings.length || candidateCursor != candidates.length) {
    throw StateError('Mixed-enemy benchmark sample count drifted.');
  }
  return _MixedMeasurement(
    timing: _Stats(timings),
    candidates: _Stats(candidates),
    lastIntegratedBodyCount: lastIntegratedBodyCount,
    maxContactIterations: maxContactIterations,
    maxRecoveryIterations: maxRecoveryIterations,
    clearanceSelections: clearanceSelections,
  );
}

final class _MixedMeasurement {
  const _MixedMeasurement({
    required this.timing,
    required this.candidates,
    required this.lastIntegratedBodyCount,
    required this.maxContactIterations,
    required this.maxRecoveryIterations,
    required this.clearanceSelections,
  });

  final _Stats timing;
  final _Stats candidates;
  final int lastIntegratedBodyCount;
  final int maxContactIterations;
  final int maxRecoveryIterations;
  final int clearanceSelections;

  Map<String, Object> toJson() => <String, Object>{
    'timingUs': timing.toJson(),
    'candidatesPerDynamicEnemy': candidates.toJson(),
    'lastIntegratedBodyCount': lastIntegratedBodyCount,
    'maxContactIterations': maxContactIterations,
    'maxRecoveryIterations': maxRecoveryIterations,
    'clearanceSelections': clearanceSelections,
  };
}

final class _Stats {
  _Stats(Iterable<int> samples)
    : values = List<int>.of(samples)..sort(),
      total = samples.fold<int>(0, (sum, value) => sum + value) {
    if (values.isEmpty) throw ArgumentError('Stats require samples.');
  }

  final List<int> values;
  final int total;

  double get mean => total / values.length;
  int get p50 => _percentile(0.50);
  int get p95 => _percentile(0.95);
  int get p99 => _percentile(0.99);
  int get max => values.last;

  Map<String, Object> toJson() => <String, Object>{
    'samples': values.length,
    'mean': mean,
    'p50': p50,
    'p95': p95,
    'p99': p99,
    'max': max,
  };

  int _percentile(double percentile) =>
      values[((values.length - 1) * percentile).round()];
}

String _gitOutput(List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    workingDirectory: Directory.current.path,
  );
  return result.exitCode == 0 ? (result.stdout as String).trim() : 'unknown';
}
