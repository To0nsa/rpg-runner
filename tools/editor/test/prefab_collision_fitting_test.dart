import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/prefabs/collision_fitting/prefab_collision_fitting.dart';

void main() {
  group('PrefabCollisionFitter', () {
    test('rejects malformed and oversized masks before fitting', () {
      expect(
        () => PrefabAlphaMask(width: 0, height: 1, alpha: Uint8List(0)),
        throwsArgumentError,
      );
      expect(
        () => PrefabAlphaMask(width: 2, height: 2, alpha: Uint8List(3)),
        throwsArgumentError,
      );
      expect(
        () => PrefabAlphaMask(
          width: PrefabAlphaMask.maximumPixelCount + 1,
          height: 1,
          alpha: Uint8List(0),
        ),
        throwsArgumentError,
      );
    });

    test('mask and result byte views cannot be mutated by callers', () {
      final mask = _mask(<String>['#']);
      expect(() => mask.alpha[0] = 0, throwsUnsupportedError);

      final result = PrefabCollisionFitter.generate(
        mask: mask,
        method: PrefabCollisionCreationMethod.fitVisibleBounds,
      );
      expect(() => result.acceptedPixels[0] = 0, throwsUnsupportedError);
    });

    test('handles one pixel, rows, columns, and full masks exactly', () {
      for (final rows in <List<String>>[
        <String>['#'],
        <String>['###'],
        <String>['#', '#', '#'],
        <String>['##', '##'],
      ]) {
        final result = PrefabCollisionFitter.generate(
          mask: _mask(rows),
          method: PrefabCollisionCreationMethod.traceVisibleOutline,
        );

        expect(result.accepted, isTrue);
        expect(result.evidence.coveredVisiblePixels, rows.join().length);
        expect(result.evidence.omittedVisiblePixels, 0);
        expect(result.evidence.coveredTransparentPixels, 0);
      }
    });

    test('reports each invalid setting without generating geometry', () {
      for (final entry in <(PrefabCollisionFitSettings, String)>[
        (
          const PrefabCollisionFitSettings(alphaCutoff: 0),
          'prefab_fit_alpha_cutoff_invalid',
        ),
        (
          const PrefabCollisionFitSettings(minimumIslandArea: 0),
          'prefab_fit_minimum_island_invalid',
        ),
        (
          const PrefabCollisionFitSettings(maximumVerticesPerShape: 3),
          'prefab_fit_maximum_vertices_invalid',
        ),
      ]) {
        final result = PrefabCollisionFitter.generate(
          mask: _mask(<String>['#']),
          method: PrefabCollisionCreationMethod.traceVisibleOutline,
          settings: entry.$1,
        );
        expect(result.accepted, isFalse);
        expect(result.shapes, isEmpty);
        expect(result.diagnostics.single.code, entry.$2);
      }
    });

    test('fits tight bounds and reports transparent cells added', () {
      final result = PrefabCollisionFitter.generate(
        mask: _mask(<String>['.....', '.##..', '.#.#.', '.....']),
        method: PrefabCollisionCreationMethod.fitVisibleBounds,
      );

      expect(result.accepted, isTrue);
      expect(result.shapes, hasLength(1));
      expect(result.shapes.single.vertices, const <PrefabCollisionFitPoint>[
        PrefabCollisionFitPoint(1, 1),
        PrefabCollisionFitPoint(4, 1),
        PrefabCollisionFitPoint(4, 3),
        PrefabCollisionFitPoint(1, 3),
      ]);
      expect(result.evidence.acceptedVisiblePixels, 4);
      expect(result.evidence.coveredVisiblePixels, 4);
      expect(result.evidence.coveredTransparentPixels, 2);
      expect(
        result.diagnostics.map((diagnostic) => diagnostic.code),
        contains('prefab_fit_bounds_spans_gaps'),
      );
    });

    test('uses stable four-connected component order', () {
      final result = PrefabCollisionFitter.generate(
        mask: _mask(<String>['...#.', '.#.#.', '.##..']),
        method: PrefabCollisionCreationMethod.traceVisibleOutline,
      );

      expect(result.accepted, isTrue);
      expect(result.shapes, hasLength(2));
      expect(result.shapes[0].componentIndex, 0);
      expect(
        result.shapes[0].vertices.first,
        const PrefabCollisionFitPoint(3, 0),
      );
      expect(result.shapes[1].componentIndex, 1);
      expect(result.shapes[1].vertices.length, greaterThan(4));
      expect(result.evidence.coveredVisiblePixels, 5);
      expect(result.evidence.coveredTransparentPixels, 0);
    });

    test('traces concave occupancy exactly and splits diagonal contact', () {
      final concave = PrefabCollisionFitter.generate(
        mask: _mask(<String>['##.', '.##']),
        method: PrefabCollisionCreationMethod.traceVisibleOutline,
      );
      final diagonal = PrefabCollisionFitter.generate(
        mask: _mask(<String>['#.', '.#']),
        method: PrefabCollisionCreationMethod.traceVisibleOutline,
      );

      expect(concave.accepted, isTrue);
      expect(concave.shapes, hasLength(1));
      expect(concave.shapes.single.vertices.length, greaterThan(4));
      expect(concave.evidence.coveredVisiblePixels, 4);
      expect(concave.evidence.omittedVisiblePixels, 0);
      expect(concave.evidence.coveredTransparentPixels, 0);
      expect(diagonal.shapes, hasLength(2));
    });

    test('preserves a transparent hole with exact rectangle partitions', () {
      final result = PrefabCollisionFitter.generate(
        mask: _mask(<String>['###', '#.#', '###']),
        method: PrefabCollisionCreationMethod.traceVisibleOutline,
      );

      expect(result.accepted, isTrue);
      expect(result.shapes.length, greaterThan(1));
      expect(result.evidence.coveredVisiblePixels, 8);
      expect(result.evidence.coveredTransparentPixels, 0);
      expect(result.evidence.omittedVisiblePixels, 0);
    });

    test('filters islands only when the author requests it', () {
      final result = PrefabCollisionFitter.generate(
        mask: _mask(<String>['##.#']),
        method: PrefabCollisionCreationMethod.traceVisibleOutline,
        settings: const PrefabCollisionFitSettings(minimumIslandArea: 2),
      );

      expect(result.accepted, isTrue);
      expect(result.shapes, hasLength(1));
      expect(result.evidence.thresholdVisiblePixels, 3);
      expect(result.evidence.filteredIslandCount, 1);
      expect(result.evidence.filteredVisiblePixels, 1);
      expect(result.evidence.acceptedVisiblePixels, 2);
    });

    test('detects stepped platform support and closes it downward', () {
      final result = PrefabCollisionFitter.generate(
        mask: _mask(<String>['..##', '####', '####']),
        method: PrefabCollisionCreationMethod.detectPlatformSurface,
      );

      expect(result.accepted, isTrue);
      final vertices = result.shapes.single.vertices;
      expect(vertices, contains(const PrefabCollisionFitPoint(0, 1)));
      expect(vertices, contains(const PrefabCollisionFitPoint(2, 1)));
      expect(vertices, contains(const PrefabCollisionFitPoint(2, 0)));
      expect(vertices, contains(const PrefabCollisionFitPoint(4, 0)));
      expect(result.evidence.sourceColumns, 4);
      expect(result.evidence.supportedColumns, 4);
      expect(result.evidence.omittedColumns, 0);
      expect(result.evidence.maximumDeviationPx, 0);
      for (var index = 0; index < vertices.length; index += 1) {
        final start = vertices[index];
        final end = vertices[(index + 1) % vertices.length];
        if (end.x > start.x) {
          expect(end.y, lessThanOrEqualTo(1));
        }
      }
    });

    test('platform detection preserves split support runs', () {
      final result = PrefabCollisionFitter.generate(
        mask: _mask(<String>['##.##', '##.##']),
        method: PrefabCollisionCreationMethod.detectPlatformSurface,
      );

      expect(result.accepted, isTrue);
      expect(result.shapes, hasLength(2));
      expect(result.evidence.sourceColumns, 4);
      expect(result.evidence.supportedColumns, 4);
      expect(result.evidence.omittedColumns, 0);
    });

    test('rejects an empty retained mask', () {
      final result = PrefabCollisionFitter.generate(
        mask: _mask(<String>['...']),
        method: PrefabCollisionCreationMethod.fitVisibleBounds,
      );

      expect(result.accepted, isFalse);
      expect(result.diagnostics.single.code, 'prefab_fit_no_visible_pixels');
    });

    test('alpha cutoff is inclusive and deterministic', () {
      final result = PrefabCollisionFitter.generate(
        mask: PrefabAlphaMask(
          width: 3,
          height: 1,
          alpha: Uint8List.fromList(<int>[0, 127, 128]),
        ),
        method: PrefabCollisionCreationMethod.fitVisibleBounds,
        settings: const PrefabCollisionFitSettings(alphaCutoff: 128),
      );

      expect(result.evidence.thresholdVisiblePixels, 1);
      expect(result.shapes.single.vertices, const <PrefabCollisionFitPoint>[
        PrefabCollisionFitPoint(2, 0),
        PrefabCollisionFitPoint(3, 0),
        PrefabCollisionFitPoint(3, 1),
        PrefabCollisionFitPoint(2, 1),
      ]);
    });

    test(
      'budgeted outline reduction is deterministic and preserves extents',
      () {
        final mask = _mask(<String>[
          '#.......',
          '###.....',
          '#####...',
          '#######.',
          '########',
        ]);
        String signature(PrefabCollisionFitResult result) => result.shapes
            .map(
              (shape) => shape.vertices
                  .map((point) => '${point.x},${point.y}')
                  .join(';'),
            )
            .join('|');
        final exact = PrefabCollisionFitter.generate(
          mask: mask,
          method: PrefabCollisionCreationMethod.traceVisibleOutline,
          settings: const PrefabCollisionFitSettings(
            maximumVerticesPerShape: 64,
          ),
        );
        final simplifiedA = PrefabCollisionFitter.generate(
          mask: mask,
          method: PrefabCollisionCreationMethod.traceVisibleOutline,
          settings: const PrefabCollisionFitSettings(
            maximumVerticesPerShape: 6,
          ),
        );
        final simplifiedB = PrefabCollisionFitter.generate(
          mask: mask,
          method: PrefabCollisionCreationMethod.traceVisibleOutline,
          settings: const PrefabCollisionFitSettings(
            maximumVerticesPerShape: 6,
          ),
        );

        expect(simplifiedA.accepted, isTrue);
        expect(signature(simplifiedA), signature(simplifiedB));
        final exactVertices = exact.shapes.single.vertices;
        final simplifiedVertices = simplifiedA.shapes.single.vertices;
        expect(simplifiedVertices.length, lessThan(exactVertices.length));
        expect(simplifiedVertices.length, lessThanOrEqualTo(6));
        expect(simplifiedVertices.every(exactVertices.contains), isTrue);
        expect(_extents(simplifiedVertices), _extents(exactVertices));
        expect(simplifiedA.evidence.maximumDeviationPx, greaterThan(0));
      },
    );

    test('default budget compacts a noisy 32 pixel silhouette', () {
      final rows = <String>[
        for (var y = 0; y < 32; y += 1)
          y.isEven
              ? '${List<String>.filled(31, '#').join()}.'
              : '.${List<String>.filled(31, '#').join()}',
      ];
      final exact = PrefabCollisionFitter.generate(
        mask: _mask(rows),
        method: PrefabCollisionCreationMethod.traceVisibleOutline,
        settings: const PrefabCollisionFitSettings(maximumVerticesPerShape: 64),
      );
      final reduced = PrefabCollisionFitter.generate(
        mask: _mask(rows),
        method: PrefabCollisionCreationMethod.traceVisibleOutline,
      );

      expect(exact.shapes.single.vertices, hasLength(64));
      expect(exact.accepted, isTrue);
      expect(reduced.accepted, isTrue);
      expect(
        reduced.shapes.single.vertices.length,
        lessThanOrEqualTo(
          PrefabCollisionFitSettings.defaultMaximumVerticesPerShape,
        ),
      );
      expect(
        _extents(reduced.shapes.single.vertices),
        _extents(exact.shapes.single.vertices),
      );
      expect(reduced.evidence.maximumDeviationPx, greaterThan(0));
    });

    test('platform surface reduction pins endpoints within its budget', () {
      final result = PrefabCollisionFitter.generate(
        mask: _mask(<String>[
          List<String>.generate(32, (index) => index.isEven ? '#' : '.').join(),
          List<String>.filled(32, '#').join(),
          List<String>.filled(32, '#').join(),
        ]),
        method: PrefabCollisionCreationMethod.detectPlatformSurface,
      );

      expect(result.accepted, isTrue);
      expect(result.shapes.single.vertices.length, lessThanOrEqualTo(24));
      expect(result.evidence.sourceColumns, 32);
      expect(result.evidence.supportedColumns, 32);
      expect(result.evidence.maximumDeviationPx, lessThanOrEqualTo(1));
      expect(
        result.shapes.single.vertices,
        containsAll(const <PrefabCollisionFitPoint>[
          PrefabCollisionFitPoint(0, 0),
          PrefabCollisionFitPoint(32, 1),
        ]),
      );
    });

    test('default budget produces a compact grass platform outline', () {
      final result = PrefabCollisionFitter.generate(
        mask: _mask(const <String>[
          '....########################....',
          '..############################..',
          '.##############################.',
          '################################',
          '################################',
          '################################',
          '################################',
          '################################',
          '################################',
          '###############################.',
          '.##############################.',
          '.##############################.',
          '.##############################.',
          '.##############################.',
          '..#############################.',
          '.#############################..',
          '#############################...',
          '##############################..',
          '##############################..',
          '.#############################..',
          '.##############################.',
          '.##############################.',
          '###############################.',
          '###############################.',
          '###############################.',
          '###############################.',
          '###############################.',
          '.##############################.',
          '..############################..',
          '.....####################.###...',
          '......#########.########........',
          '.......######.....#####.........',
        ]),
        method: PrefabCollisionCreationMethod.traceVisibleOutline,
      );

      expect(result.accepted, isTrue);
      expect(result.shapes, hasLength(1));
      expect(
        result.shapes.single.vertices.length,
        lessThanOrEqualTo(
          PrefabCollisionFitSettings.defaultMaximumVerticesPerShape,
        ),
      );
      expect(result.evidence.maximumDeviationPx, lessThanOrEqualTo(2));
      expect(result.evidence.omittedVisiblePixels, lessThanOrEqualTo(10));
      expect(_extents(result.shapes.single.vertices), (
        minX: 0,
        minY: 0,
        maxX: 32,
        maxY: 32,
      ));
    });

    test('hard capacity failures never report an accepted partial fit', () {
      final row = List<String>.generate(
        65,
        (index) => index == 64 ? '#' : '#.',
      ).join();
      final result = PrefabCollisionFitter.generate(
        mask: _mask(<String>[row]),
        method: PrefabCollisionCreationMethod.traceVisibleOutline,
      );

      expect(result.shapes, hasLength(65));
      expect(result.accepted, isFalse);
      expect(
        result.diagnostics.map((diagnostic) => diagnostic.code),
        contains('prefab_fit_shape_capacity_exceeded'),
      );
    });

    test('edited candidate evidence is recomputed from accepted pixels', () {
      final mask = _mask(<String>['##.#']);
      final generated = PrefabCollisionFitter.generate(
        mask: mask,
        method: PrefabCollisionCreationMethod.traceVisibleOutline,
      );
      final evidence = PrefabCollisionFitter.evaluateEvidence(
        mask: mask,
        acceptedPixels: generated.acceptedPixels,
        shapes: <PrefabCollisionFitShape>[generated.shapes.first],
        method: PrefabCollisionCreationMethod.traceVisibleOutline,
        baseline: generated.evidence,
      );

      expect(evidence.coveredVisiblePixels, 2);
      expect(evidence.omittedVisiblePixels, 1);
      expect(evidence.coveredTransparentPixels, 0);
    });
  });
}

({int minX, int minY, int maxX, int maxY}) _extents(
  List<PrefabCollisionFitPoint> points,
) => (
  minX: points
      .map((point) => point.x)
      .reduce((left, right) => left < right ? left : right),
  minY: points
      .map((point) => point.y)
      .reduce((left, right) => left < right ? left : right),
  maxX: points
      .map((point) => point.x)
      .reduce((left, right) => left > right ? left : right),
  maxY: points
      .map((point) => point.y)
      .reduce((left, right) => left > right ? left : right),
);

PrefabAlphaMask _mask(List<String> rows) {
  final width = rows.first.length;
  final alpha = Uint8List(width * rows.length);
  for (var y = 0; y < rows.length; y += 1) {
    expect(rows[y].length, width);
    for (var x = 0; x < width; x += 1) {
      alpha[y * width + x] = rows[y][x] == '#' ? 255 : 0;
    }
  }
  return PrefabAlphaMask(width: width, height: rows.length, alpha: alpha);
}
