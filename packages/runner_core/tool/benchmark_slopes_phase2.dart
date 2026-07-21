import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:runner_core/collision/static_world_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_capsule_controller.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:runner_core/collision/terrain/upright_capsule.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart' hide Isolate;
import 'package:vm_service/vm_service_io.dart';

/// Reproducible Phase 2 controller and complete-player-slice benchmark.
///
/// Run from `packages/runner_core`:
///
/// ```text
/// dart run tool/benchmark_slopes_phase2.dart --strict
/// ```
Future<void> main(List<String> args) async {
  final config = _BenchmarkConfig.fromArgs(args);
  final cases = <String, _ControllerCase>{
    'supportedIdle': _supportedIdleCase(),
    'ordinarySlopeTraversal': _ordinarySlopeCase(),
    'maximumSpeedMultiContact': _multiContactCase(),
    'stepUp': _stepCase(),
    'supportSnap': _snapCase(),
    'oneWayLanding': _oneWayCase(),
    'overlapRecovery': _recoveryCase(),
  };

  final controllerMeasurements = <String, _ControllerMeasurement>{
    for (final entry in cases.entries)
      entry.key: _measureController(
        entry.value,
        warmup: config.warmup,
        iterations: config.iterations,
      ),
  };
  final flatHarnessGeometry = _harnessGeometry(sloped: false);
  final slopeHarnessGeometry = _harnessGeometry(sloped: true);
  final flatHarnessFirst = _measureHarness(
    geometry: flatHarnessGeometry,
    warmup: config.warmup,
    iterations: config.harnessIterations,
  );
  final slopeHarnessFirst = _measureHarness(
    geometry: slopeHarnessGeometry,
    warmup: config.warmup,
    iterations: config.harnessIterations,
  );
  final slopeHarnessSecond = _measureHarness(
    geometry: slopeHarnessGeometry,
    warmup: config.warmup,
    iterations: config.harnessIterations,
  );
  final flatHarnessSecond = _measureHarness(
    geometry: flatHarnessGeometry,
    warmup: config.warmup,
    iterations: config.harnessIterations,
  );
  final flatHarness = _mergeHarness(flatHarnessFirst, flatHarnessSecond);
  final slopeHarness = _mergeHarness(slopeHarnessFirst, slopeHarnessSecond);
  final allocationProfile = config.profileAllocations
      ? await _measureControllerAllocations(
          iterations: config.allocationIterations,
        )
      : null;

  final allControllerTimings = _Stats(
    controllerMeasurements.values.expand(
      (measurement) => measurement.timing.values,
    ),
  );
  final allCandidates = _Stats(
    controllerMeasurements.values.expand(
      (measurement) => measurement.candidates.values,
    ),
  );
  final totalResizeDelta = controllerMeasurements.values.fold<int>(
    0,
    (sum, measurement) => sum + measurement.bufferResizeDelta,
  );
  final harnessOverheadPercent = flatHarness.timing.totalTicks == 0
      ? 0.0
      : (slopeHarness.timing.totalTicks - flatHarness.timing.totalTicks) /
            flatHarness.timing.totalTicks *
            100;
  final gates = <String, bool>{
    'representative_edge_count': cases.values.every(
      (benchmarkCase) => benchmarkCase.geometry.edges.length == 1280,
    ),
    'controller_p95_us': allControllerTimings.p95 <= 75,
    'controller_p99_us': allControllerTimings.p99 <= 150,
    'candidate_p95': allCandidates.p95 <= 24,
    'candidate_p99': allCandidates.p99 <= 64,
    'full_harness_p99_us': slopeHarness.timing.p99 <= 2000,
    'full_harness_hard_p99_us': slopeHarness.timing.p99 < 4000,
    'matched_flat_overhead': harnessOverheadPercent <= 25,
    'steady_state_buffer_growth': totalResizeDelta == 0,
    'bounded_controller_iterations': controllerMeasurements.values.every(
      (measurement) =>
          measurement.contactIterations.max <= terrainMaxBlockingContacts &&
          measurement.recoveryIterations.max <= terrainMaxRecoveryIterations,
    ),
    if (allocationProfile != null)
      'zero_steady_state_controller_allocations':
          allocationProfile.hotLoopAllocatedInstances == 0,
  };
  final passed = gates.values.every((value) => value);
  final revision = _gitOutput(<String>['rev-parse', '--short', 'HEAD']);
  final dirty = _gitOutput(<String>['status', '--porcelain']).isNotEmpty;

  final report = <String, Object?>{
    'benchmark': 'slopes-phase2-controller-v1',
    'revision': revision,
    'dirty': dirty,
    'os': Platform.operatingSystem,
    'osVersion': Platform.operatingSystemVersion,
    'dartVersion': Platform.version,
    'fixture': 'representative-1280-edges',
    'warmup': config.warmup,
    'controllerIterations': config.iterations,
    'harnessIterations': config.harnessIterations,
    'controller': <String, Object?>{
      for (final entry in controllerMeasurements.entries)
        entry.key: entry.value.toJson(),
    },
    'controllerCombinedUs': allControllerTimings.toJson(),
    'controllerCombinedCandidates': allCandidates.toJson(),
    'fullHarnessFlat': flatHarness.toJson(),
    'fullHarnessSlope': slopeHarness.toJson(),
    'fullHarnessSlopeOverFlatPercent': harnessOverheadPercent,
    'steadyStateBufferResizeDelta': totalResizeDelta,
    'allocationEvidence':
        allocationProfile?.toJson() ??
        <String, Object?>{
          'measured': false,
          'bufferEvidence':
              'All controller/query/result storage is caller- or '
              'controller-owned; warmed query-buffer resize delta is zero.',
          'profileCommand':
              'dart --observe=0 run tool/benchmark_slopes_phase2.dart '
              '--allocation-profile',
        },
    'gates': gates,
    'passed': passed,
  };
  const encoder = JsonEncoder.withIndent('  ');
  final json = encoder.convert(report);
  stdout.writeln(json);

  final outputPath = config.jsonOutPath;
  if (outputPath != null) {
    final output = File(outputPath);
    output.parent.createSync(recursive: true);
    output.writeAsStringSync('$json\n');
  }
  if (config.strict && !passed) exitCode = 1;
}

class _BenchmarkConfig {
  const _BenchmarkConfig({
    required this.warmup,
    required this.iterations,
    required this.harnessIterations,
    required this.profileAllocations,
    required this.allocationIterations,
    required this.strict,
    required this.jsonOutPath,
  });

  factory _BenchmarkConfig.fromArgs(List<String> args) {
    String value(String name, String fallback) {
      final prefix = '--$name=';
      return args
              .where((argument) => argument.startsWith(prefix))
              .map((argument) => argument.substring(prefix.length))
              .firstOrNull ??
          fallback;
    }

    return _BenchmarkConfig(
      warmup: int.parse(value('warmup', '500')),
      iterations: int.parse(value('iterations', '5000')),
      harnessIterations: int.parse(value('harness-iterations', '5000')),
      profileAllocations: args.contains('--allocation-profile'),
      allocationIterations: int.parse(value('allocation-iterations', '10000')),
      strict: args.contains('--strict'),
      jsonOutPath: args
          .where((argument) => argument.startsWith('--json-out='))
          .map((argument) => argument.substring('--json-out='.length))
          .firstOrNull,
    );
  }

  final int warmup;
  final int iterations;
  final int harnessIterations;
  final bool profileAllocations;
  final int allocationIterations;
  final bool strict;
  final String? jsonOutPath;
}

class _AllocationMeasurement {
  const _AllocationMeasurement({
    required this.iterationsPerTrial,
    required this.trialPairs,
    required this.baselineAllocatedInstances,
    required this.solveAllocatedInstances,
    required this.profilerPositiveDeltaInstances,
    required this.hotLoopAllocatedInstances,
    required this.positiveClassDeltas,
    required this.hotLoopClassDeltas,
    required this.doubleAllocationCallsites,
  });

  final int iterationsPerTrial;
  final int trialPairs;
  final int baselineAllocatedInstances;
  final int solveAllocatedInstances;
  final int profilerPositiveDeltaInstances;
  final int hotLoopAllocatedInstances;
  final Map<String, int> positiveClassDeltas;
  final Map<String, int> hotLoopClassDeltas;
  final Map<String, int> doubleAllocationCallsites;

  Map<String, Object?> toJson() => <String, Object?>{
    'measured': true,
    'method':
        'VM getAllocationProfile on an isolated warmed 1280-edge '
        'controller worker, subtracting an identical no-op message trial',
    'iterationsPerTrial': iterationsPerTrial,
    'trialPairs': trialPairs,
    'baselineAllocatedInstances': baselineAllocatedInstances,
    'solveAllocatedInstances': solveAllocatedInstances,
    'profilerPositiveDeltaInstances': profilerPositiveDeltaInstances,
    'hotLoopAllocatedInstances': hotLoopAllocatedInstances,
    'allocationsPerSolve':
        hotLoopAllocatedInstances / (iterationsPerTrial * trialPairs),
    'positiveClassDeltas': positiveClassDeltas,
    'hotLoopClassDeltas': hotLoopClassDeltas,
    'doubleAllocationCallsites': doubleAllocationCallsites,
  };
}

Future<_AllocationMeasurement> _measureControllerAllocations({
  required int iterations,
}) async {
  final serviceInfo = await developer.Service.getInfo();
  final serverUri = serviceInfo.serverUri;
  if (serverUri == null) {
    throw StateError(
      'Allocation profiling requires `dart --observe=0 run ... '
      '--allocation-profile`.',
    );
  }

  final ready = ReceivePort();
  final worker = await Isolate.spawn<SendPort>(
    _allocationWorker,
    ready.sendPort,
    debugName: 'slopes-phase2-allocation-worker',
  );
  final workerPort = await ready.first as SendPort;
  final isolateId = developer.Service.getIsolateId(worker);
  if (isolateId == null) {
    worker.kill(priority: Isolate.immediate);
    throw StateError('Could not resolve the allocation worker isolate ID.');
  }

  final websocketUri = convertToWebSocketUrl(serviceProtocolUrl: serverUri);
  final service = await vmServiceConnectUri(websocketUri.toString());
  try {
    await _allocationTrial(
      service: service,
      isolateId: isolateId,
      workerPort: workerPort,
      iterations: math.min(iterations, 2000),
      solve: true,
    );
    final baselineFirst = await _allocationTrial(
      service: service,
      isolateId: isolateId,
      workerPort: workerPort,
      iterations: iterations,
      solve: false,
    );
    final solveFirst = await _allocationTrial(
      service: service,
      isolateId: isolateId,
      workerPort: workerPort,
      iterations: iterations,
      solve: true,
    );
    final solveSecond = await _allocationTrial(
      service: service,
      isolateId: isolateId,
      workerPort: workerPort,
      iterations: iterations,
      solve: true,
    );
    final baselineSecond = await _allocationTrial(
      service: service,
      isolateId: isolateId,
      workerPort: workerPort,
      iterations: iterations,
      solve: false,
    );
    final baseline = _sumAllocationCounts(baselineFirst, baselineSecond);
    final solve = _sumAllocationCounts(solveFirst, solveSecond);
    // Allocation tracing can deoptimize the selected class. Capture the
    // warmed steady-state profile first, then gather callsites as separate
    // diagnostic evidence.
    final doubleAllocationCallsites = await _traceDoubleAllocations(
      service: service,
      isolateId: isolateId,
      workerPort: workerPort,
    );
    final classNames = <String>{...baseline.keys, ...solve.keys}.toList()
      ..sort();
    final positiveDeltas = <String, int>{};
    for (final className in classNames) {
      final delta = (solve[className] ?? 0) - (baseline[className] ?? 0);
      if (delta > 0) positiveDeltas[className] = delta;
    }
    final hotLoopDeltas = <String, int>{
      for (final entry in positiveDeltas.entries)
        if (_isTrackedHotLoopClass(entry.key)) entry.key: entry.value,
    };
    return _AllocationMeasurement(
      iterationsPerTrial: iterations,
      trialPairs: 2,
      baselineAllocatedInstances: baseline.values.fold(0, (a, b) => a + b),
      solveAllocatedInstances: solve.values.fold(0, (a, b) => a + b),
      profilerPositiveDeltaInstances: positiveDeltas.values.fold(
        0,
        (a, b) => a + b,
      ),
      hotLoopAllocatedInstances: hotLoopDeltas.values.fold(0, (a, b) => a + b),
      positiveClassDeltas: positiveDeltas,
      hotLoopClassDeltas: hotLoopDeltas,
      doubleAllocationCallsites: doubleAllocationCallsites,
    );
  } finally {
    worker.kill(priority: Isolate.immediate);
    ready.close();
    await service.dispose();
  }
}

bool _isTrackedHotLoopClass(String className) =>
    className == '_Double' ||
    className == '_Record' ||
    className == '_SupportTransition' ||
    className.startsWith('Terrain') ||
    className.startsWith('Capsule') ||
    className == 'UprightCapsule';

Future<Map<String, int>> _traceDoubleAllocations({
  required VmService service,
  required String isolateId,
  required SendPort workerPort,
}) async {
  final classes = await service.getClassList(isolateId);
  ClassRef? doubleClass;
  for (final candidate in classes.classes ?? const <ClassRef>[]) {
    if (candidate.name == '_Double') {
      doubleClass = candidate;
      break;
    }
  }
  final classId = doubleClass?.id;
  if (classId == null) return const <String, int>{};

  await service.setTraceClassAllocation(isolateId, classId, true);
  await service.clearCpuSamples(isolateId);
  final completed = ReceivePort();
  workerPort.send(<Object>[true, 200, completed.sendPort]);
  await completed.first;
  completed.close();
  final traces = await service.getAllocationTraces(isolateId, classId: classId);
  await service.setTraceClassAllocation(isolateId, classId, false);

  final functions = traces.functions ?? const <ProfileFunction>[];
  final callsites = <String, int>{};
  for (final sample in traces.samples ?? const <CpuSample>[]) {
    var label = '<unknown>';
    for (final functionIndex in sample.stack ?? const <int>[]) {
      if (functionIndex < 0 || functionIndex >= functions.length) continue;
      final function = functions[functionIndex];
      final url = function.resolvedUrl ?? '';
      if (!url.contains('runner_core')) continue;
      final reference = function.function;
      final name = reference is FuncRef ? reference.name : null;
      label = '${name ?? '<anonymous>'} @ $url';
      break;
    }
    callsites.update(label, (count) => count + 1, ifAbsent: () => 1);
  }
  return Map<String, int>.fromEntries(
    callsites.entries.toList()..sort((left, right) {
      final countOrder = right.value.compareTo(left.value);
      return countOrder != 0 ? countOrder : left.key.compareTo(right.key);
    }),
  );
}

Map<String, int> _sumAllocationCounts(
  Map<String, int> first,
  Map<String, int> second,
) {
  final result = <String, int>{...first};
  for (final entry in second.entries) {
    result.update(
      entry.key,
      (value) => value + entry.value,
      ifAbsent: () => entry.value,
    );
  }
  return result;
}

Future<Map<String, int>> _allocationTrial({
  required VmService service,
  required String isolateId,
  required SendPort workerPort,
  required int iterations,
  required bool solve,
}) async {
  await service.getAllocationProfile(isolateId, reset: true, gc: true);
  final completed = ReceivePort();
  workerPort.send(<Object>[solve, iterations, completed.sendPort]);
  await completed.first;
  completed.close();
  final profile = await service.getAllocationProfile(isolateId);
  final counts = <String, int>{};
  for (final member in profile.members ?? const <ClassHeapStats>[]) {
    final className = member.classRef?.name;
    final count = member.instancesAccumulated ?? 0;
    if (className != null && count > 0) {
      counts.update(
        className,
        (existing) => existing + count,
        ifAbsent: () => count,
      );
    }
  }
  return counts;
}

void _allocationWorker(SendPort readyPort) {
  final benchmarkCase = _ordinarySlopeCase();
  for (var index = 0; index < 50000; index += 1) {
    benchmarkCase.run();
  }
  final requests = ReceivePort();
  readyPort.send(requests.sendPort);
  requests.listen((Object? rawMessage) {
    final message = rawMessage! as List<Object>;
    final solve = message[0] as bool;
    final iterations = message[1] as int;
    final replyPort = message[2] as SendPort;
    var sink = 0;
    for (var index = 0; index < iterations; index += 1) {
      if (solve) benchmarkCase.run();
      sink ^= index;
    }
    replyPort.send(
      sink ^
          benchmarkCase.result.finalCenterXTicks ^
          benchmarkCase.result.finalCenterYTicks,
    );
  });
}

class _ControllerCase {
  _ControllerCase({
    required this.geometry,
    required this.controller,
    required this.capsule,
    required this.request,
    required this.beganGrounded,
    this.priorSupportEdgeId,
    this.priorSupportGeometryVersion = -1,
  });

  final TerrainGeometry geometry;
  final TerrainCapsuleController controller;
  final UprightCapsule capsule;
  final TerrainMotionRequest request;
  final bool beganGrounded;
  final TerrainEdgeId? priorSupportEdgeId;
  final int priorSupportGeometryVersion;
  final TerrainCapsuleMotionResult result = TerrainCapsuleMotionResult();

  void run() {
    controller.move(
      capsule: capsule,
      request: request,
      beganGrounded: beganGrounded,
      priorSupportEdgeId: priorSupportEdgeId,
      priorSupportGeometryVersion: priorSupportGeometryVersion,
      lastValidCapsuleCenterXTicks: capsule.center.xTicks,
      lastValidCapsuleCenterYTicks: capsule.center.yTicks,
      out: result,
    );
  }
}

_ControllerMeasurement _measureController(
  _ControllerCase benchmarkCase, {
  required int warmup,
  required int iterations,
}) {
  for (var index = 0; index < warmup; index += 1) {
    benchmarkCase.run();
  }
  final resizeAtStart = benchmarkCase.controller.queryBufferResizeCount;
  final timings = List<int>.filled(iterations, 0);
  final candidates = List<int>.filled(iterations, 0);
  final contacts = List<int>.filled(iterations, 0);
  final recoveryIterations = List<int>.filled(iterations, 0);
  final contactIterations = List<int>.filled(iterations, 0);
  var stepCount = 0;
  var snapCount = 0;
  final diagnostics = <String, int>{};
  final stopwatch = Stopwatch();
  for (var index = 0; index < iterations; index += 1) {
    stopwatch
      ..reset()
      ..start();
    benchmarkCase.run();
    stopwatch.stop();
    final result = benchmarkCase.result;
    timings[index] = stopwatch.elapsedMicroseconds;
    candidates[index] = result.candidateCount;
    contacts[index] = result.contactCount;
    recoveryIterations[index] = result.recoveryIterations;
    contactIterations[index] = result.contactIterations;
    if (result.usedStep) stepCount += 1;
    if (result.usedSnap) snapCount += 1;
    diagnostics.update(
      result.diagnostic.name,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }
  return _ControllerMeasurement(
    timing: _Stats(timings),
    candidates: _Stats(candidates),
    contacts: _Stats(contacts),
    recoveryIterations: _Stats(recoveryIterations),
    contactIterations: _Stats(contactIterations),
    stepCount: stepCount,
    snapCount: snapCount,
    bufferResizeDelta:
        benchmarkCase.controller.queryBufferResizeCount - resizeAtStart,
    diagnostics: diagnostics,
    geometrySignature: _geometrySignature(benchmarkCase.geometry),
  );
}

class _ControllerMeasurement {
  const _ControllerMeasurement({
    required this.timing,
    required this.candidates,
    required this.contacts,
    required this.recoveryIterations,
    required this.contactIterations,
    required this.stepCount,
    required this.snapCount,
    required this.bufferResizeDelta,
    required this.diagnostics,
    required this.geometrySignature,
  });

  final _Stats timing;
  final _Stats candidates;
  final _Stats contacts;
  final _Stats recoveryIterations;
  final _Stats contactIterations;
  final int stepCount;
  final int snapCount;
  final int bufferResizeDelta;
  final Map<String, int> diagnostics;
  final String geometrySignature;

  Map<String, Object?> toJson() => <String, Object?>{
    'geometrySignature': geometrySignature,
    'timingUs': timing.toJson(),
    'candidates': candidates.toJson(),
    'contacts': contacts.toJson(),
    'contactIterations': contactIterations.toJson(),
    'recoveryIterations': recoveryIterations.toJson(),
    'stepCount': stepCount,
    'snapCount': snapCount,
    'bufferResizeDelta': bufferResizeDelta,
    'diagnostics': diagnostics,
  };
}

class _HarnessMeasurement {
  const _HarnessMeasurement({
    required this.timing,
    required this.geometrySignature,
    required this.finalTick,
    required this.finalDistance,
  });

  final _Stats timing;
  final String geometrySignature;
  final int finalTick;
  final double finalDistance;

  Map<String, Object?> toJson() => <String, Object?>{
    'geometrySignature': geometrySignature,
    'timingUs': timing.toJson(),
    'finalTick': finalTick,
    'finalDistance': finalDistance,
  };
}

_HarnessMeasurement _mergeHarness(
  _HarnessMeasurement first,
  _HarnessMeasurement second,
) {
  if (first.geometrySignature != second.geometrySignature) {
    throw StateError('Cannot merge different harness fixtures.');
  }
  return _HarnessMeasurement(
    timing: _Stats(<int>[...first.timing.values, ...second.timing.values]),
    geometrySignature: first.geometrySignature,
    finalTick: second.finalTick,
    finalDistance: second.finalDistance,
  );
}

_HarnessMeasurement _measureHarness({
  required TerrainGeometry geometry,
  required int warmup,
  required int iterations,
}) {
  final core = GameCore.terrainMotionHarness(
    seed: 2202,
    runId: 2,
    levelDefinition: _benchmarkLevel(),
    playerCharacter: eloiseCharacter,
    terrainGeometry: geometry,
  );
  final commandFrames = <List<Command>>[
    for (var tick = 1; tick <= warmup + iterations; tick += 1)
      <Command>[MoveAxisCommand(tick: tick, axis: 1)],
  ];
  for (var index = 0; index < warmup; index += 1) {
    core.applyCommands(commandFrames[index]);
    core.stepOneTick();
  }
  final timings = List<int>.filled(iterations, 0);
  final stopwatch = Stopwatch();
  for (var index = 0; index < iterations; index += 1) {
    stopwatch
      ..reset()
      ..start();
    core.applyCommands(commandFrames[warmup + index]);
    core.stepOneTick();
    stopwatch.stop();
    timings[index] = stopwatch.elapsedMicroseconds;
    if (core.gameOver) {
      throw StateError('Benchmark harness ended at tick ${core.tick}.');
    }
  }
  return _HarnessMeasurement(
    timing: _Stats(timings),
    geometrySignature: _geometrySignature(geometry),
    finalTick: core.tick,
    finalDistance: core.distance,
  );
}

_ControllerCase _supportedIdleCase() {
  final geometry = _representativeGeometry(<TerrainPolygonInput>[
    _polygon('floor', const [
      (-1000, 1000),
      (2000, 1000),
      (2000, 1200),
      (-1000, 1200),
    ]),
  ]);
  final support = _upwardEdge(geometry);
  return _supportedCase(
    geometry,
    support,
    TerrainMotionRequest(
      displacementXTicks: 0,
      displacementYTicks: 0,
      gravityYTicks: 256,
      mode: TerrainMotionMode.groundedHorizontal,
    ),
  );
}

_ControllerCase _ordinarySlopeCase() {
  final geometry = _representativeGeometry(<TerrainPolygonInput>[
    _polygon('slope', const [
      (-1000, 1500),
      (2000, 0),
      (2000, 1800),
      (-1000, 1800),
    ]),
  ]);
  final support = _upwardEdge(geometry);
  return _supportedCase(
    geometry,
    support,
    TerrainMotionRequest(
      displacementXTicks: 4 * terrainPhysicsTicksPerWorldUnit,
      displacementYTicks: 0,
      gravityYTicks: 256,
      mode: TerrainMotionMode.groundedHorizontal,
    ),
  );
}

_ControllerCase _multiContactCase() {
  final geometry = _representativeGeometry(<TerrainPolygonInput>[
    _polygon('floor-wall', const [
      (0, 1000),
      (500, 1000),
      (500, 700),
      (540, 700),
      (540, 1200),
      (0, 1200),
    ]),
  ]);
  final support = _upwardEdge(geometry);
  return _supportedCase(
    geometry,
    support,
    TerrainMotionRequest(
      displacementXTicks: 80 * terrainPhysicsTicksPerWorldUnit,
      displacementYTicks: 30 * terrainPhysicsTicksPerWorldUnit,
      mode: TerrainMotionMode.worldSpace,
    ),
    centerXWorld: 450,
  );
}

_ControllerCase _stepCase() {
  final geometry = _representativeGeometry(<TerrainPolygonInput>[
    _polygon('lower', const [(0, 1004), (100, 1004), (100, 1200), (0, 1200)]),
    _polygon('upper', const [
      (100, 1000),
      (400, 1000),
      (400, 1200),
      (100, 1200),
    ]),
  ]);
  final support = geometry.edges.firstWhere(
    (edge) =>
        edge.outwardNormal.yTicks < -900 &&
        edge.start.yTicks == 1004 * terrainPhysicsTicksPerWorldUnit,
  );
  return _supportedCase(
    geometry,
    support,
    TerrainMotionRequest(
      displacementXTicks: 30 * terrainPhysicsTicksPerWorldUnit,
      displacementYTicks: 0,
      gravityYTicks: 256,
      mode: TerrainMotionMode.groundedHorizontal,
    ),
    centerXWorld: 80,
  );
}

_ControllerCase _snapCase() {
  final geometry = _representativeGeometry(<TerrainPolygonInput>[
    _polygon('floor', const [(0, 1000), (500, 1000), (500, 1200), (0, 1200)]),
  ]);
  final support = _upwardEdge(geometry);
  final capsule = _supportedCapsule(support, centerXWorld: 250);
  return _case(
    geometry: geometry,
    capsule: UprightCapsule(
      center: capsule.center.translated(
        0,
        -3 * terrainPhysicsTicksPerWorldUnit,
      ),
      radiusTicks: capsule.radiusTicks,
      verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
    ),
    request: TerrainMotionRequest(
      displacementXTicks: 0,
      displacementYTicks: 0,
      gravityYTicks: 256,
      mode: TerrainMotionMode.groundedHorizontal,
    ),
    beganGrounded: true,
    priorSupport: support,
  );
}

_ControllerCase _oneWayCase() {
  final geometry = _representativeGeometry(<TerrainPolygonInput>[
    _polygon('one-way', const [
      (0, 1000),
      (500, 1000),
      (500, 1002),
      (0, 1002),
    ], collisionMode: TerrainCollisionMode.oneWay),
  ]);
  return _case(
    geometry: geometry,
    capsule: UprightCapsule(
      center: TerrainPoint.fromWorld(250, 900),
      radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
      verticalHalfSegmentTicks: 0,
    ),
    request: TerrainMotionRequest(
      displacementXTicks: 0,
      displacementYTicks: 150 * terrainPhysicsTicksPerWorldUnit,
      mode: TerrainMotionMode.worldSpace,
    ),
    beganGrounded: false,
  );
}

_ControllerCase _recoveryCase() {
  final geometry = _representativeGeometry(<TerrainPolygonInput>[
    _polygon('floor', const [(0, 1000), (500, 1000), (500, 1200), (0, 1200)]),
  ]);
  return _case(
    geometry: geometry,
    capsule: UprightCapsule(
      center: TerrainPoint.fromWorld(250, 991),
      radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
      verticalHalfSegmentTicks: 0,
    ),
    request: TerrainMotionRequest(
      displacementXTicks: 0,
      displacementYTicks: 0,
      mode: TerrainMotionMode.worldSpace,
    ),
    beganGrounded: false,
  );
}

_ControllerCase _supportedCase(
  TerrainGeometry geometry,
  TerrainEdge support,
  TerrainMotionRequest request, {
  double centerXWorld = 300,
}) => _case(
  geometry: geometry,
  capsule: _supportedCapsule(support, centerXWorld: centerXWorld),
  request: request,
  beganGrounded: true,
  priorSupport: support,
);

_ControllerCase _case({
  required TerrainGeometry geometry,
  required UprightCapsule capsule,
  required TerrainMotionRequest request,
  required bool beganGrounded,
  TerrainEdge? priorSupport,
}) {
  final controller = TerrainCapsuleController(
    geometry: geometry,
    index: TerrainEdgeIndex(edges: geometry.edges),
    profile: _profile(),
  );
  return _ControllerCase(
    geometry: geometry,
    controller: controller,
    capsule: capsule,
    request: request,
    beganGrounded: beganGrounded,
    priorSupportEdgeId: priorSupport?.id,
    priorSupportGeometryVersion: priorSupport == null ? -1 : geometry.version,
  );
}

TerrainTraversalProfile _profile() => createEloiseTerrainTraversalProfile(
  enabled: true,
  isKinematic: false,
  useGravity: true,
  gravityScale: 1,
  collideCeilings: true,
  collideLeftWalls: true,
  collideRightWalls: true,
);

TerrainGeometry _representativeGeometry(List<TerrainPolygonInput> functional) {
  const compiler = TerrainCompiler();
  final functionalGeometry = compiler.compile(functional, geometryVersion: 1);
  final remaining = 1280 - functionalGeometry.edges.length;
  if (remaining < 0) {
    throw StateError('Functional fixture exceeds the representative edge set.');
  }
  final fillerSides = _partitionIntoTrianglesAndQuads(remaining);
  final inputs = <TerrainPolygonInput>[...functional];
  for (var index = 0; index < fillerSides.length; index += 1) {
    final x = 500000.0 + index * 64;
    final y = 20000.0 + (index % 8) * 128;
    inputs.add(
      fillerSides[index] == 3
          ? _polygon('filler_$index', [(x, y), (x + 24, y), (x + 12, y + 16)])
          : _polygon('filler_$index', [
              (x, y),
              (x + 24, y),
              (x + 24, y + 16),
              (x, y + 16),
            ]),
    );
  }
  final geometry = compiler.compile(inputs, geometryVersion: 1);
  if (geometry.edges.length != 1280) {
    throw StateError(
      'Representative fixture compiled ${geometry.edges.length} edges.',
    );
  }
  return geometry;
}

List<int> _partitionIntoTrianglesAndQuads(int total) {
  for (var triangles = 0; triangles <= total ~/ 3; triangles += 1) {
    final remainder = total - triangles * 3;
    if (remainder % 4 == 0) {
      return <int>[
        ...List<int>.filled(triangles, 3),
        ...List<int>.filled(remainder ~/ 4, 4),
      ];
    }
  }
  throw StateError('Cannot partition $total remaining edges.');
}

TerrainGeometry _harnessGeometry({required bool sloped}) {
  final top = sloped
      ? const <(double, double)>[(-100000, 51000), (100000, -49000)]
      : const <(double, double)>[(-100000, 1000), (100000, 1000)];
  return _representativeGeometry(<TerrainPolygonInput>[
    _polygon('harness-surface', [
      top[0],
      top[1],
      (100000, 80000),
      (-100000, 80000),
    ]),
  ]);
}

LevelDefinition _benchmarkLevel() => LevelDefinition(
  id: LevelId.field,
  chunkPatternSource: const ChunkPatternListSource(easyPatterns: []),
  staticWorldGeometry: const StaticWorldGeometry(
    groundPlane: StaticGroundPlane(topY: 6000),
  ),
  tuning: const CoreTuning(
    camera: CameraTuning(speedLagMulX: 0, followThresholdRatio: 1),
    track: TrackTuning(enabled: false, playerStartX: 300),
  ),
  killPlaneY: 100000,
);

TerrainPolygonInput _polygon(
  String shapeId,
  List<(double, double)> vertices, {
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'benchmark/phase2/$shapeId',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'phase2',
    shapeId: shapeId,
  ),
  vertices: vertices,
  collisionMode: collisionMode,
);

TerrainEdge _upwardEdge(TerrainGeometry geometry) => geometry.edges.firstWhere(
  (edge) =>
      edge.id.shapeId.startsWith('filler_') == false &&
      edge.outwardNormal.yTicks < -500,
);

UprightCapsule _supportedCapsule(
  TerrainEdge edge, {
  required double centerXWorld,
}) {
  final centerX = physicsCoordinateToTicks(centerXWorld);
  const radius = 10 * terrainPhysicsTicksPerWorldUnit;
  final normalX = edge.dyTicks;
  final normalY = -edge.dxTicks;
  final edgeLength = _integerSqrt(
    edge.dxTicks * edge.dxTicks + edge.dyTicks * edge.dyTicks,
  );
  final extent = (radius + terrainCollisionSkinTicks) * edgeLength;
  final lineConstant =
      normalX * edge.start.xTicks + normalY * edge.start.yTicks + extent;
  final centerY = _roundedDivide(lineConstant - normalX * centerX, normalY);
  return UprightCapsule(
    center: TerrainPoint(centerX, centerY),
    radiusTicks: radius,
    verticalHalfSegmentTicks: 0,
  );
}

String _geometrySignature(TerrainGeometry geometry) {
  final index = TerrainEdgeIndex(edges: geometry.edges);
  return geometry.edgeSignature(
    indexMembershipRecords: index.canonicalMembershipRecords(),
  );
}

class _Stats {
  _Stats(Iterable<int> samples)
    : values = List<int>.of(samples)..sort(),
      totalTicks = samples.fold<int>(0, (sum, value) => sum + value);

  final List<int> values;
  final int totalTicks;

  double get mean =>
      values.fold<double>(0, (sum, value) => sum + value) / values.length;
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

int _roundedDivide(int numerator, int denominator) {
  final negative = (numerator < 0) != (denominator < 0);
  final quotient =
      (numerator.abs() + denominator.abs() ~/ 2) ~/ denominator.abs();
  return negative ? -quotient : quotient;
}

int _integerSqrt(int value) {
  if (value < 2) return value;
  var estimate = 1 << ((value.bitLength + 1) >> 1);
  while (true) {
    final next = (estimate + value ~/ estimate) >> 1;
    if (next >= estimate) return estimate;
    estimate = next;
  }
}

String _gitOutput(List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    workingDirectory: Directory.current.path,
  );
  return result.exitCode == 0 ? (result.stdout as String).trim() : 'unknown';
}
