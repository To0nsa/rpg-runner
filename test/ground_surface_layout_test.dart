import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/snapshots/ground_surface_snapshot.dart';
import 'package:rpg_runner/game/components/ground_surface_layout.dart';

void main() {
  test('clips finite and infinite surfaces to visible rect', () {
    const surfaces = <GroundSurfaceSnapshot>[
      GroundSurfaceSnapshot(
        minX: double.negativeInfinity,
        maxX: 120,
        topY: 255,
        chunkIndex: -1,
        localSegmentIndex: 0,
      ),
      GroundSurfaceSnapshot(
        minX: 140,
        maxX: double.infinity,
        topY: 255,
        chunkIndex: -1,
        localSegmentIndex: 1,
      ),
      GroundSurfaceSnapshot(
        minX: 300,
        maxX: 380,
        topY: 255,
        chunkIndex: 3,
        localSegmentIndex: 0,
      ),
    ];
    final visible = ui.Rect.fromLTRB(100, 0, 250, 300);

    final bands = GroundSurfaceLayout.buildVisibleBands(
      surfaces: surfaces,
      visibleWorldRect: visible,
      fillDepth: 16,
    );

    expect(bands, hasLength(2));
    expect(bands[0].minX, 100);
    expect(bands[0].maxX, 120);
    expect(bands[0].topY, 255);
    expect(bands[0].bottomY, 271);

    expect(bands[1].minX, 140);
    expect(bands[1].maxX, 250);
    expect(bands[1].topY, 255);
    expect(bands[1].bottomY, 271);
  });

  test('omits surfaces outside vertical visibility', () {
    const surfaces = <GroundSurfaceSnapshot>[
      GroundSurfaceSnapshot(
        minX: 0,
        maxX: 100,
        topY: 500,
        chunkIndex: 0,
        localSegmentIndex: 0,
      ),
      GroundSurfaceSnapshot(
        minX: 0,
        maxX: 100,
        topY: -30,
        chunkIndex: 0,
        localSegmentIndex: 1,
      ),
      GroundSurfaceSnapshot(
        minX: 0,
        maxX: 100,
        topY: 200,
        chunkIndex: 0,
        localSegmentIndex: 2,
      ),
    ];
    final visible = ui.Rect.fromLTRB(0, 0, 200, 260);

    final bands = GroundSurfaceLayout.buildVisibleBands(
      surfaces: surfaces,
      visibleWorldRect: visible,
      fillDepth: 20,
    );

    expect(bands, hasLength(1));
    expect(bands.single.minX, 0);
    expect(bands.single.maxX, 100);
    expect(bands.single.topY, 200);
    expect(bands.single.bottomY, 220);
  });

  test('returns empty when depth is non-positive', () {
    const surfaces = <GroundSurfaceSnapshot>[
      GroundSurfaceSnapshot(
        minX: 0,
        maxX: 100,
        topY: 200,
        chunkIndex: 0,
        localSegmentIndex: 0,
      ),
    ];
    final visible = ui.Rect.fromLTRB(0, 0, 200, 260);

    final bands = GroundSurfaceLayout.buildVisibleBands(
      surfaces: surfaces,
      visibleWorldRect: visible,
      fillDepth: 0,
    );

    expect(bands, isEmpty);
  });
}
