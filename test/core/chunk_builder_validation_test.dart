import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/track/chunk_builder.dart';
import 'package:runner_core/track/chunk_pattern.dart';

void main() {
  test('buildSolids enforces grid snap in all build modes', () {
    const pattern = ChunkPattern(
      name: 'unsnapped-solid',
      solids: <SolidRel>[
        SolidRel(
          x: 10.5,
          aboveGroundTop: 32.0,
          width: 32.0,
          height: 16.0,
          sides: SolidRel.sideTop,
          oneWayTop: true,
        ),
      ],
    );

    expect(
      () => buildSolids(
        pattern,
        chunkStartX: 0.0,
        chunkIndex: 0,
        groundTopY: 220.0,
        chunkWidth: 600.0,
        gridSnap: 16.0,
      ),
          throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('Solid not snapped to grid'),
        ),
      ),
    );
  });

  test('buildSolids preserves authored solid order', () {
    const pattern = ChunkPattern(
      name: 'ordered-solids',
      solids: <SolidRel>[
        SolidRel(
          x: 16.0,
          aboveGroundTop: 48.0,
          width: 32.0,
          height: 16.0,
          sides: SolidRel.sideTop,
          oneWayTop: true,
        ),
        SolidRel(
          x: 80.0,
          aboveGroundTop: 32.0,
          width: 16.0,
          height: 32.0,
          sides: SolidRel.sideAll,
        ),
        SolidRel(
          x: 128.0,
          aboveGroundTop: 64.0,
          width: 24.0,
          height: 8.0,
          sides: SolidRel.sideTop,
          oneWayTop: true,
        ),
        SolidRel(
          x: 176.0,
          aboveGroundTop: 40.0,
          width: 16.0,
          height: 40.0,
          sides: SolidRel.sideLeft | SolidRel.sideRight,
        ),
      ],
    );

    final builtSolids = buildSolids(
      pattern,
      chunkStartX: 100.0,
      chunkIndex: 2,
      groundTopY: 220.0,
      chunkWidth: 320.0,
      gridSnap: 8.0,
    );

    expect(builtSolids, hasLength(4));

    expect(builtSolids[0].minX, 116.0);
    expect(builtSolids[0].minY, 172.0);
    expect(builtSolids[0].maxX, 148.0);
    expect(builtSolids[0].maxY, 188.0);
    expect(builtSolids[0].sides, SolidRel.sideTop);
    expect(builtSolids[0].oneWayTop, isTrue);
    expect(builtSolids[0].localSolidIndex, 0);

    expect(builtSolids[1].minX, 180.0);
    expect(builtSolids[1].minY, 188.0);
    expect(builtSolids[1].maxX, 196.0);
    expect(builtSolids[1].maxY, 220.0);
    expect(builtSolids[1].sides, SolidRel.sideAll);
    expect(builtSolids[1].oneWayTop, isFalse);
    expect(builtSolids[1].localSolidIndex, 1);

    expect(builtSolids[2].minX, 228.0);
    expect(builtSolids[2].minY, 156.0);
    expect(builtSolids[2].maxX, 252.0);
    expect(builtSolids[2].maxY, 164.0);
    expect(builtSolids[2].sides, SolidRel.sideTop);
    expect(builtSolids[2].oneWayTop, isTrue);
    expect(builtSolids[2].localSolidIndex, 2);

    expect(builtSolids[3].minX, 276.0);
    expect(builtSolids[3].minY, 180.0);
    expect(builtSolids[3].maxX, 292.0);
    expect(builtSolids[3].maxY, 220.0);
    expect(builtSolids[3].sides, SolidRel.sideLeft | SolidRel.sideRight);
    expect(builtSolids[3].oneWayTop, isFalse);
    expect(builtSolids[3].localSolidIndex, 3);
  });

  test(
    'buildSolids rejects generic solid side masks outside supported bits',
    () {
      const pattern = ChunkPattern(
        name: 'invalid-solid-mask',
        solids: <SolidRel>[
          SolidRel(
            x: 32.0,
            aboveGroundTop: 32.0,
            width: 16.0,
            height: 16.0,
            sides: 1 << 5,
          ),
        ],
      );

      expect(
        () => buildSolids(
          pattern,
          chunkStartX: 0.0,
          chunkIndex: 1,
          groundTopY: 220.0,
          chunkWidth: 320.0,
          gridSnap: 8.0,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('Solid has invalid side mask'),
          ),
        ),
      );
    },
  );

  test('buildGroundSegments rejects overlapping gaps with chunk context', () {
    const pattern = ChunkPattern(
      name: 'overlap-gaps',
      chunkKey: 'chunk-alpha',
      groundGaps: <GapRel>[
        GapRel(x: 96.0, width: 80.0, gapId: 'gap-a'),
        GapRel(x: 160.0, width: 40.0, gapId: 'gap-b'),
      ],
    );

    expect(
      () => buildGroundSegments(
        pattern,
        chunkStartX: 0.0,
        chunkIndex: 3,
        groundTopY: 220.0,
        chunkWidth: 600.0,
        gridSnap: 8.0,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          allOf(<Matcher>[
            contains('Ground gap overlaps previous gap'),
            contains('chunkKey=chunk-alpha'),
            contains('chunkIndex=3'),
          ]),
        ),
      ),
    );
  });
}
