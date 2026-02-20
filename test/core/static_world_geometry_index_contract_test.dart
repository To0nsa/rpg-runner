import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/collision/static_world_geometry_index.dart';

void main() {
  test('accepts sorted and disjoint provided ground segments', () {
    const geometry = StaticWorldGeometry(
      groundSegments: <StaticGroundSegment>[
        StaticGroundSegment(minX: 0, maxX: 100, topY: 200),
        StaticGroundSegment(minX: 120, maxX: 220, topY: 200),
      ],
    );

    final index = StaticWorldGeometryIndex.from(geometry);
    expect(index.groundSegments, hasLength(2));
  });

  test('throws for unsorted provided ground segments', () {
    const geometry = StaticWorldGeometry(
      groundSegments: <StaticGroundSegment>[
        StaticGroundSegment(minX: 200, maxX: 300, topY: 200),
        StaticGroundSegment(minX: 0, maxX: 100, topY: 200),
      ],
    );

    expect(() => StaticWorldGeometryIndex.from(geometry), throwsStateError);
  });

  test('throws for overlapping provided ground segments', () {
    const geometry = StaticWorldGeometry(
      groundSegments: <StaticGroundSegment>[
        StaticGroundSegment(minX: 0, maxX: 120, topY: 200),
        StaticGroundSegment(minX: 100, maxX: 200, topY: 200),
      ],
    );

    expect(() => StaticWorldGeometryIndex.from(geometry), throwsStateError);
  });
}
