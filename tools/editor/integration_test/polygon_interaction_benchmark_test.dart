import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/chunk_creator_page.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/staging/chunk_polygon_scene_surface.dart';
import 'package:runner_editor/src/chunks/chunk_v2_staging_models.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';

import 'support/polygon_interaction_benchmark_fixture.dart';

const int _warmupFrames = 120;
const int _sampleFrames = 600;
const Duration _frameInterval = Duration(microseconds: 16667);
const int _p95BudgetMicros = 8000;
const int _p99BudgetMicros = 16667;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profiles representative polygon vertex drag', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 1080);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final fixture = PolygonInteractionBenchmarkFixture.build();
    final session = await fixture.openSession(
      workspacePath: Directory.current.path,
    );
    addTearDown(session.dispose);
    final documentBefore = session.controller.document!;
    final chunkListBefore = (documentBefore as ChunkV2StagingDocument).chunks;
    final mainChunkBefore = chunkListBefore.firstWhere(
      (chunk) =>
          chunk.chunkKey == PolygonInteractionBenchmarkFixture.mainChunkKey,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: ChunkCreatorPage(controller: session.controller)),
      ),
    );
    await tester.pumpAndSettle();

    final surfaceInputFinder = find.byKey(
      const ValueKey<String>('chunk_polygon_scene_surface'),
    );
    final surfaceWidgetFinder = find.byType(ChunkPolygonSceneSurface);
    expect(surfaceInputFinder, findsOneWidget);
    expect(surfaceWidgetFinder, findsOneWidget);
    var surface = tester.widget<ChunkPolygonSceneSurface>(surfaceWidgetFinder);
    final controller = surface.controller;
    controller
      ..select(
        TerrainPolygonSelection.vertex(
          PolygonInteractionBenchmarkFixture.selectedShapeId,
          0,
        ),
      )
      ..setTool(TerrainPolygonTool.moveVertex);
    await tester.pump();
    surface = tester.widget<ChunkPolygonSceneSurface>(surfaceWidgetFinder);

    final selectedShape = controller.state.shapes.firstWhere(
      (shape) =>
          shape.shapeId == PolygonInteractionBenchmarkFixture.selectedShapeId,
    );
    final localStart = surface.transform.sourceVertexToCanvas(
      selectedShape.vertices.first,
    );
    final globalStart = tester.getTopLeft(surfaceInputFinder) + localStart;
    final halfPixelDelta = Offset(
      surface.transform.canvasPixelsPerHalfPixel,
      0,
    );
    final gesture = await tester.startGesture(globalStart, pointer: 1);
    await tester.pump();
    expect(controller.hasActiveOperation, isTrue);

    for (var index = 0; index < _warmupFrames; index += 1) {
      await gesture.moveTo(
        globalStart + (index.isEven ? halfPixelDelta : Offset.zero),
      );
      await tester.pump(_frameInterval);
    }

    final updateSamplesMicros = <int>[];
    var notifications = 0;
    var missedInputCount = 0;
    var currentMissedInputBurst = 0;
    var maximumMissedInputBurst = 0;
    void countNotification() => notifications += 1;
    controller.addListener(countNotification);
    try {
      await binding.watchPerformance(() async {
        for (var index = 0; index < _sampleFrames; index += 1) {
          final notificationsBefore = notifications;
          final stopwatch = Stopwatch()..start();
          await gesture.moveTo(
            globalStart + (index.isEven ? halfPixelDelta : Offset.zero),
          );
          stopwatch.stop();
          updateSamplesMicros.add(stopwatch.elapsedMicroseconds);
          if (notifications == notificationsBefore) {
            missedInputCount += 1;
            currentMissedInputBurst += 1;
            if (currentMissedInputBurst > maximumMissedInputBurst) {
              maximumMissedInputBurst = currentMissedInputBurst;
            }
          } else {
            currentMissedInputBurst = 0;
          }
          await tester.pump(_frameInterval);
        }
      }, reportKey: 'frameTiming');
    } finally {
      controller.removeListener(countNotification);
    }
    await gesture.cancel();
    await tester.pump();

    final documentAfter = session.controller.document!;
    final chunkListAfter = (documentAfter as ChunkV2StagingDocument).chunks;
    final mainChunkAfter = chunkListAfter.firstWhere(
      (chunk) =>
          chunk.chunkKey == PolygonInteractionBenchmarkFixture.mainChunkKey,
    );
    final interactionStats = _summarizeMicros(updateSamplesMicros);
    final fullGeometryVisible =
        controller.sceneProjection.shapes.length ==
            PolygonInteractionBenchmarkFixture.directShapeCount &&
        fixture.mainExpansion.geometry.edges.length ==
            PolygonInteractionBenchmarkFixture.compiledEdgeCount &&
        fixture.mainExpansion.expandedPrefabShapes.length ==
            PolygonInteractionBenchmarkFixture.placedPrefabCount;
    final gates = <String, bool>{
      'interactionUpdateP95': interactionStats['p95']! <= _p95BudgetMicros,
      'interactionUpdateP99': interactionStats['p99']! <= _p99BudgetMicros,
      'noMissedInputBurst':
          missedInputCount == 0 && maximumMissedInputBurst == 0,
      'noRepositoryReloadOrGeneratorRun': session.plugin.loadCount == 1,
      'noWorkspaceSourceReplacement':
          identical(documentBefore, documentAfter) &&
          identical(chunkListBefore, chunkListAfter) &&
          identical(mainChunkBefore, mainChunkAfter),
      'noInteractionDiagnosticTruncation': fullGeometryVisible,
    };
    final allGatesPass = gates.values.every((passed) => passed);
    final frameTiming = binding.reportData?['frameTiming'];
    binding.reportData = <String, dynamic>{
      'reportVersion': 1,
      'benchmark': 'polygon-interaction-v1',
      'mode': kProfileMode
          ? 'profile'
          : kReleaseMode
          ? 'release'
          : 'debug',
      'acceptanceEvaluated': kProfileMode,
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'runtime': Platform.version,
      'fixture': <String, dynamic>{
        'id': PolygonInteractionBenchmarkFixture.fixtureId,
        'chunkWidthPx': fixture.mainChunk.width,
        'chunkHeightPx': fixture.mainChunk.height,
        'directShapeCount': fixture.mainChunk.collisionShapes.length,
        'selectedShapeVertexCount': selectedShape.vertices.length,
        'placedPrefabCount': fixture.mainChunk.prefabs.length,
        'expandedPrefabShapeCount':
            fixture.mainExpansion.expandedPrefabShapes.length,
        'compiledEdgeCount': fixture.mainExpansion.geometry.edges.length,
        'reachableSeamCount': fixture.seamAnalysis.seams.length,
        'groundPreviewEnabled': true,
        'expandedCollisionOverlayEnabled': true,
        'compiledEdgeOverlayEnabled': true,
        'signatures': <String, String>{
          'authoringPolygons': fixture.authoringPolygonSignature,
          'source': fixture.sourceSignature,
          'edges': fixture.edgeSignature,
          'reachableSeams': fixture.seamSignature,
        },
      },
      'warmupFrames': _warmupFrames,
      'sampleFrames': _sampleFrames,
      'interactionUpdateMicros': interactionStats,
      'frameTiming': frameTiming,
      'missedInputCount': missedInputCount,
      'maximumMissedInputBurst': maximumMissedInputBurst,
      'affectedShapeCount': 1,
      'affectedEdgeCount': selectedShape.vertices.length,
      'repositoryLoadCount': session.plugin.loadCount,
      'generatorRunCount': 0,
      'allocationEvidence': <String, dynamic>{
        'heapAllocationCount': null,
        'sourceDocumentReplacementCount':
            identical(documentBefore, documentAfter) ? 0 : 1,
        'sourceChunkListReplacementCount':
            identical(chunkListBefore, chunkListAfter) ? 0 : 1,
        'sourceChunkReplacementCount':
            identical(mainChunkBefore, mainChunkAfter) ? 0 : 1,
      },
      'gates': gates,
      'passed': kProfileMode && allGatesPass,
    };

    expect(updateSamplesMicros, hasLength(_sampleFrames));
    if (kProfileMode) {
      expect(gates.values, everyElement(isTrue));
    }
  });
}

Map<String, num> _summarizeMicros(List<int> samples) {
  if (samples.isEmpty) {
    throw ArgumentError.value(samples, 'samples', 'Must not be empty.');
  }
  final sorted = List<int>.of(samples)..sort();
  return <String, num>{
    'samples': sorted.length,
    'mean': sorted.reduce((left, right) => left + right) / sorted.length,
    'p50': _nearestRank(sorted, 0.50),
    'p95': _nearestRank(sorted, 0.95),
    'p99': _nearestRank(sorted, 0.99),
    'max': sorted.last,
  };
}

int _nearestRank(List<int> sorted, double percentile) {
  final index = (sorted.length * percentile).ceil() - 1;
  return sorted[index.clamp(0, sorted.length - 1)];
}
