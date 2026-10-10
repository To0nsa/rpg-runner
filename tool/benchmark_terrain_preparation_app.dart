import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:runner_core/levels/level_id.dart';

import 'benchmark_terrain_preparation.dart';

/// Flutter production terrain workload, excluding actors and world rendering.
/// Build native with --profile or web with --release; configure via dart-defines.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _BenchmarkPage()));
}

class _BenchmarkPage extends StatefulWidget {
  const _BenchmarkPage();
  @override
  State<_BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<_BenchmarkPage> {
  static final _seed =
      int.tryParse(Uri.base.queryParameters['seed'] ?? '') ??
      const int.fromEnvironment(
        'TERRAIN_BENCHMARK_SEED',
        defaultValue: 857469563,
      );
  static final _seconds =
      int.tryParse(Uri.base.queryParameters['seconds'] ?? '') ??
      const int.fromEnvironment('TERRAIN_BENCHMARK_SECONDS', defaultValue: 300);
  String _status =
      'Preparing Forest, seed $_seed. Recording $_seconds seconds at real-time speed.';
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final result = await benchmarkTerrainPreparation(
        realTime: true,
        levelIds: const [LevelId.forest],
        seed: _seed,
        seconds: _seconds,
        onMeasurementStart: (level) =>
            debugPrint('TERRAIN_BENCHMARK_ACTIVE ${level.name}'),
      );
      final levels = result['levels']! as List<Map<String, Object?>>;
      final summary = levels.single['summary']! as Map<String, Object?>;
      // Export only after the timed run; logging during construction would
      // distort scheduling and could itself create frame stalls.
      debugPrint('TERRAIN_BENCHMARK_SUMMARY ${jsonEncode(summary)}');
      for (final row in levels.single['rows']! as List<Map<String, Object?>>) {
        debugPrint('TERRAIN_BENCHMARK_ROW ${jsonEncode(row)}');
      }
      if (!mounted) return;
      setState(() {
        _status = const JsonEncoder.withIndent('  ').convert(summary);
        _complete = true;
      });
    } catch (error, stack) {
      debugPrint('TERRAIN_BENCHMARK_ERROR $error');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      setState(() {
        _status = 'Benchmark failed: $error';
        _complete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Terrain preparation benchmark')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_complete) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            SelectableText(_status),
          ],
        ),
      ),
    ),
  );
}
