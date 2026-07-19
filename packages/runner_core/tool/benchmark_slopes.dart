import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:runner_core/collision/terrain/capsule_segment_kernel.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_query_buffer.dart';
import 'package:runner_core/collision/terrain/upright_capsule.dart';

void main(List<String> args) {
  final config = _BenchmarkConfig.fromArgs(args);
  final slopeInputs = _buildInputs(config.edgeCount, sloped: true);
  final flatInputs = _buildInputs(config.edgeCount, sloped: false);
  const compiler = TerrainCompiler();
  final slopeGeometry = compiler.compile(slopeInputs, geometryVersion: 1);
  final flatGeometry = compiler.compile(flatInputs, geometryVersion: 1);

  final compilerStats = _measure(
    runs: config.runs,
    warmup: 1,
    operation: () {
      compiler.compile(
        _buildInputs(config.edgeCount, sloped: true),
        geometryVersion: 1,
      );
      return 0;
    },
  );
  final rebuildStats = _measure(
    runs: config.rebuilds,
    warmup: math.min(3, config.rebuilds),
    operation: () {
      final index = TerrainEdgeIndex(edges: slopeGeometry.edges);
      return index.insertedReferences;
    },
  );

  final slopeIndex = TerrainEdgeIndex(edges: slopeGeometry.edges);
  final flatIndex = TerrainEdgeIndex(edges: flatGeometry.edges);
  final slopeQuery = _measureQueries(
    slopeIndex,
    iterations: config.iterations,
    warmup: config.warmup,
  );
  final flatQuery = _measureQueries(
    flatIndex,
    iterations: config.iterations,
    warmup: config.warmup,
  );
  final sweepStats = _measureSweeps(
    slopeGeometry,
    iterations: config.iterations,
    warmup: config.warmup,
  );

  final queryOverheadPercent = _measureMatchedQueryOverhead(
    slopeIndex,
    flatIndex,
    iterations: config.iterations,
    warmup: config.warmup,
  );
  final representative = config.edgeCount == 1280;
  final rebuildBudgetUs = representative ? 15000 : 50000;
  final gates = <String, bool>{
    'edge_count_exact': slopeGeometry.edges.length == config.edgeCount,
    'rebuild_p99': rebuildStats.p99 <= rebuildBudgetUs,
    'candidate_p95': slopeQuery.candidates.p95 <= 24,
    'candidate_p99': slopeQuery.candidates.p99 <= 64,
    'steady_state_buffer_growth': slopeQuery.bufferResizeDelta == 0,
    'matched_flat_overhead': queryOverheadPercent <= 25,
  };
  final passed = gates.values.every((value) => value);
  final revision = _gitOutput(<String>['rev-parse', '--short', 'HEAD']);
  final dirty = _gitOutput(<String>['status', '--porcelain']).isNotEmpty;
  final signature = slopeGeometry.edgeSignature(
    indexMembershipRecords: slopeIndex.canonicalMembershipRecords(),
  );

  final report = <String, Object?>{
    'benchmark': 'slopes-phase1-v1',
    'fixture': config.fixture,
    'revision': revision,
    'dirty': dirty,
    'os': Platform.operatingSystem,
    'osVersion': Platform.operatingSystemVersion,
    'dartVersion': Platform.version,
    'signature': signature,
    'warmup': config.warmup,
    'runs': config.runs,
    'iterations': config.iterations,
    'rebuilds': config.rebuilds,
    'edgeCount': slopeGeometry.edges.length,
    'compilerUs': compilerStats.toJson(),
    'indexRebuildUs': rebuildStats.toJson(),
    'slopeQueryUs': slopeQuery.timing.toJson(),
    'flatQueryUs': flatQuery.timing.toJson(),
    'sweepUs': sweepStats.toJson(),
    'candidateCount': slopeQuery.candidates.toJson(),
    'insertedReferences': slopeIndex.insertedReferences,
    'occupiedCells': slopeIndex.occupiedCellCount,
    'steadyStateBufferResizeDelta': slopeQuery.bufferResizeDelta,
    'matchedFlatOverheadPercent': queryOverheadPercent,
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
    required this.fixture,
    required this.edgeCount,
    required this.runs,
    required this.warmup,
    required this.iterations,
    required this.rebuilds,
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

    final fixture = value('fixture', 'representative');
    if (fixture != 'representative' && fixture != 'hard-stream') {
      throw ArgumentError.value(
        fixture,
        'fixture',
        'Expected representative or hard-stream.',
      );
    }
    return _BenchmarkConfig(
      fixture: fixture,
      edgeCount: fixture == 'representative' ? 1280 : 5120,
      runs: int.parse(value('runs', '8')),
      warmup: int.parse(value('warmup', '200')),
      iterations: int.parse(value('iterations', value('ticks', '8000'))),
      rebuilds: int.parse(value('rebuilds', '100')),
      strict: args.contains('--strict'),
      jsonOutPath: args
          .where((argument) => argument.startsWith('--json-out='))
          .map((argument) => argument.substring('--json-out='.length))
          .firstOrNull,
    );
  }

  final String fixture;
  final int edgeCount;
  final int runs;
  final int warmup;
  final int iterations;
  final int rebuilds;
  final bool strict;
  final String? jsonOutPath;
}

List<TerrainPolygonInput> _buildInputs(int edgeCount, {required bool sloped}) {
  if (edgeCount % 4 != 0) {
    throw ArgumentError.value(
      edgeCount,
      'edgeCount',
      'Must be divisible by 4.',
    );
  }
  final shapeCount = edgeCount ~/ 4;
  final chunkCount = edgeCount == 1280 ? 5 : 5;
  return <TerrainPolygonInput>[
    for (var i = 0; i < shapeCount; i += 1)
      _benchmarkShape(i, chunkCount: chunkCount, sloped: sloped),
  ];
}

TerrainPolygonInput _benchmarkShape(
  int index, {
  required int chunkCount,
  required bool sloped,
}) {
  final chunkIndex = index % chunkCount;
  final row = index ~/ chunkCount;
  final x = row * 40.0;
  final y = chunkIndex * 128.0;
  final rise = sloped && index.isOdd ? -8.0 : 0.0;
  return TerrainPolygonInput.fromWorld(
    sourcePath: 'benchmark/chunk_$chunkIndex/shape_$index',
    identity: TerrainSourceIdentity(
      chunkIndex: chunkIndex,
      chunkKey: 'benchmark_$chunkIndex',
      shapeId: 'shape_${index.toString().padLeft(4, '0')}',
    ),
    vertices: <(double, double)>[
      (x, y),
      (x + 32, y + rise),
      (x + 32, y + rise + 16),
      (x, y + 16),
    ],
    surfaceKind: 'benchmark',
  );
}

_Stats _measure({
  required int runs,
  required int warmup,
  required int Function() operation,
}) {
  var sink = 0;
  for (var i = 0; i < warmup; i += 1) {
    sink ^= operation();
  }
  final samples = List<int>.filled(runs, 0);
  final stopwatch = Stopwatch();
  for (var i = 0; i < runs; i += 1) {
    stopwatch
      ..reset()
      ..start();
    sink ^= operation();
    stopwatch.stop();
    samples[i] = stopwatch.elapsedMicroseconds;
  }
  if (sink == -1) stderr.writeln('unreachable');
  return _Stats(samples);
}

_QueryMeasurement _measureQueries(
  TerrainEdgeIndex index, {
  required int iterations,
  required int warmup,
}) {
  final buffer = index.createQueryBuffer();
  final stopwatch = Stopwatch();
  var sink = 0;
  final queries = <TerrainAabb>[
    for (final edge in index.edges)
      edge.bounds.expanded(
        2 * terrainPhysicsTicksPerWorldUnit + terrainCollisionSkinTicks,
      ),
  ];

  for (var i = 0; i < warmup; i += 1) {
    sink ^= index.query(queries[i % queries.length], buffer);
  }
  final initialResizeCount = buffer.resizeCount;
  final timings = List<int>.filled(iterations, 0);
  final candidates = List<int>.filled(iterations, 0);
  for (var i = 0; i < iterations; i += 1) {
    stopwatch
      ..reset()
      ..start();
    sink ^= index.query(queries[i % queries.length], buffer);
    stopwatch.stop();
    timings[i] = stopwatch.elapsedMicroseconds;
    candidates[i] = buffer.candidateCount;
  }
  if (sink == -1) stderr.writeln('unreachable');
  return _QueryMeasurement(
    timing: _Stats(timings),
    candidates: _Stats(candidates),
    bufferResizeDelta: buffer.resizeCount - initialResizeCount,
  );
}

double _measureMatchedQueryOverhead(
  TerrainEdgeIndex slope,
  TerrainEdgeIndex flat, {
  required int iterations,
  required int warmup,
}) {
  final slopeBuffer = slope.createQueryBuffer();
  final flatBuffer = flat.createQueryBuffer();
  final slopeQueries = <TerrainAabb>[
    for (final edge in slope.edges)
      edge.bounds.expanded(
        2 * terrainPhysicsTicksPerWorldUnit + terrainCollisionSkinTicks,
      ),
  ];
  final flatQueries = <TerrainAabb>[
    for (final edge in flat.edges)
      edge.bounds.expanded(
        2 * terrainPhysicsTicksPerWorldUnit + terrainCollisionSkinTicks,
      ),
  ];

  var sink = 0;
  for (var i = 0; i < warmup * 4; i += 1) {
    sink ^= slope.query(slopeQueries[i % slopeQueries.length], slopeBuffer);
    sink ^= flat.query(flatQueries[i % flatQueries.length], flatBuffer);
  }

  int run(
    TerrainEdgeIndex index,
    TerrainQueryBuffer buffer,
    List<TerrainAabb> queries,
  ) {
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i += 1) {
      sink ^= index.query(queries[i % queries.length], buffer);
    }
    stopwatch.stop();
    return stopwatch.elapsedTicks;
  }

  var slopeTicks = 0;
  var flatTicks = 0;
  slopeTicks += run(slope, slopeBuffer, slopeQueries);
  flatTicks += run(flat, flatBuffer, flatQueries);
  flatTicks += run(flat, flatBuffer, flatQueries);
  slopeTicks += run(slope, slopeBuffer, slopeQueries);
  slopeTicks += run(slope, slopeBuffer, slopeQueries);
  flatTicks += run(flat, flatBuffer, flatQueries);
  flatTicks += run(flat, flatBuffer, flatQueries);
  slopeTicks += run(slope, slopeBuffer, slopeQueries);

  if (sink == -1) stderr.writeln('unreachable');
  return flatTicks == 0 ? 0 : (slopeTicks - flatTicks) / flatTicks * 100;
}

_Stats _measureSweeps(
  TerrainGeometry geometry, {
  required int iterations,
  required int warmup,
}) {
  final edge = geometry.edges.firstWhere(
    (candidate) => candidate.outwardNormal.yTicks < 0,
  );
  final midpointX = (edge.start.xTicks + edge.end.xTicks) ~/ 2;
  final highestY = math.min(edge.start.yTicks, edge.end.yTicks);
  final capsule = UprightCapsule(
    center: TerrainPoint(
      midpointX,
      highestY - 40 * terrainPhysicsTicksPerWorldUnit,
    ),
    radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
    verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
  );
  final kernel = CapsuleSegmentKernel();
  final hit = CapsuleSweepHit();
  final stopwatch = Stopwatch();
  for (var i = 0; i < warmup; i += 1) {
    kernel.sweep(
      capsule: capsule,
      displacementXTicks: 0,
      displacementYTicks: 80 * terrainPhysicsTicksPerWorldUnit,
      edge: edge,
      out: hit,
    );
  }
  final samples = List<int>.filled(iterations, 0);
  var hits = 0;
  for (var i = 0; i < iterations; i += 1) {
    stopwatch
      ..reset()
      ..start();
    kernel.sweep(
      capsule: capsule,
      displacementXTicks: 0,
      displacementYTicks: 80 * terrainPhysicsTicksPerWorldUnit,
      edge: edge,
      out: hit,
    );
    stopwatch.stop();
    samples[i] = stopwatch.elapsedMicroseconds;
    if (hit.hit) hits += 1;
  }
  if (hits != iterations) {
    throw StateError(
      'Benchmark sweep fixture missed ${iterations - hits} times.',
    );
  }
  return _Stats(samples);
}

class _QueryMeasurement {
  const _QueryMeasurement({
    required this.timing,
    required this.candidates,
    required this.bufferResizeDelta,
  });

  final _Stats timing;
  final _Stats candidates;
  final int bufferResizeDelta;
}

class _Stats {
  _Stats(Iterable<int> values) : values = List<int>.of(values)..sort();

  final List<int> values;

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

  int _percentile(double percentile) {
    final index = ((values.length - 1) * percentile).round();
    return values[index];
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
