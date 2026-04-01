import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/track/chunk_builder.dart';
import 'package:runner_core/track/chunk_pattern.dart';

void main() {
  test('buildSolids enforces grid snap in all build modes', () {
    const pattern = ChunkPattern(
      name: 'unsnapped-platform',
      platforms: <PlatformRel>[
        PlatformRel(
          x: 10.5,
          width: 32.0,
          aboveGroundTop: 32.0,
          thickness: 16.0,
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
          contains('Platform not snapped to grid'),
        ),
      ),
    );
  });

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
