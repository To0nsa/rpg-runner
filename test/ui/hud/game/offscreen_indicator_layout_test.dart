import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/spatial/offscreen_indicators.dart';
import 'package:rpg_runner/game/spatial/world_view_transform.dart';
import 'package:rpg_runner/ui/hud/game/offscreen_indicator_layout.dart';
import 'package:rpg_runner/ui/viewport/viewport_metrics.dart';

const camera = WorldViewTransform(
  cameraCenterX: 300,
  cameraCenterY: 135,
  viewWidth: 600,
  viewHeight: 270,
);

void main() {
  test(
    'contain uses the fitted view, cover uses only the visible world crop',
    () {
      for (final mode in ViewportScaleMode.values) {
        final metrics = computeViewportMetrics(
          const BoxConstraints.tightFor(width: 800, height: 600),
          1,
          600,
          270,
          mode,
        );
        final viewport = IndicatorViewport(
          metrics: metrics,
          camera: camera,
          hostSize: const Size(800, 600),
        );
        if (mode == ViewportScaleMode.pixelPerfectContain) {
          expect(viewport.visible, const Rect.fromLTWH(100, 165, 600, 270));
          expect(viewport.visibleWorld, const Rect.fromLTWH(0, 0, 600, 270));
        } else {
          expect(viewport.visible, const Rect.fromLTWH(0, 0, 800, 600));
          expect(viewport.visibleWorld.left, closeTo(166.6667, .001));
          expect(viewport.visibleWorld.top, 35);
          final frame = OffscreenIndicatorFrame(
            runId: 1,
            camera: camera,
            targets: [
              const OffscreenIndicatorTarget(
                id: 1,
                isPlayer: true,
                body: Rect.fromLTWH(100, 100, 20, 20),
              ),
            ],
          );
          expect(
            OffscreenIndicatorProjector().project(frame, viewport.visibleWorld),
            hasLength(1),
          );
        }
        expect(
          viewport.toScreen(viewport.visibleWorld.topLeft),
          viewport.visible.topLeft,
        );
      }
    },
  );

  test(
    'non-centred fitting and DPI use the same logical coordinates as the game',
    () {
      final metrics = computeViewportMetrics(
        const BoxConstraints.tightFor(width: 844, height: 390),
        3,
        600,
        270,
        ViewportScaleMode.pixelPerfectContain,
        alignment: Alignment.bottomRight,
      );
      final viewport = IndicatorViewport(
        metrics: metrics,
        camera: camera,
        hostSize: const Size(844, 390),
      );
      expect(viewport.visible.right, 844);
      expect(viewport.visible.bottom, 390);
      expect(
        viewport.toScreen(const Offset(300, 135)),
        viewport.visible.center,
      );
    },
  );

  test(
    'group nearest enemies while keeping player separate and avoiding HUD',
    () {
      final viewport = IndicatorViewport(
        metrics: const ViewportMetrics(
          viewW: 600,
          viewH: 270,
          offsetX: 0,
          offsetY: 0,
        ),
        camera: camera,
        hostSize: const Size(600, 270),
      );
      final exclusions = [
        const Rect.fromLTWH(0, 0, 600, 70),
        const Rect.fromLTWH(0, 220, 170, 50),
      ];
      final indicators = [
        indicator(2, const Offset(0, 200), 3),
        indicator(3, const Offset(0, 202), 1),
        indicator(1, const Offset(0, 200), 2, player: true),
      ];
      List<OffscreenMarker> layout(List<OffscreenIndicator> input) =>
          layoutOffscreenIndicators(
            indicators: input,
            viewport: viewport,
            safeBounds: const Rect.fromLTRB(20, 10, 590, 260),
            exclusions: exclusions,
            measure: (text) => Size(text.length * 6 + 30, 22),
          );
      final markers = layout(indicators);
      expect(markers, hasLength(2));
      expect(markers.first.indicator.isPlayer, isTrue);
      expect(markers.first.count, 1);
      expect(markers.last.count, 2);
      expect(markers.last.label, '×2 · 1 m');
      expect(markers.first.bounds.overlaps(markers.last.bounds), isFalse);
      for (final marker in markers) {
        expect(marker.bounds.left, greaterThanOrEqualTo(24));
        expect(exclusions.any((rect) => rect.overlaps(marker.bounds)), isFalse);
      }
      expect(
        layout(indicators.reversed.toList()).map((e) => (e.bounds, e.label)),
        markers.map((e) => (e.bounds, e.label)),
      );
    },
  );

  test('top and corner markers clear panels without duplicating corners', () {
    final viewport = IndicatorViewport(
      metrics: const ViewportMetrics(
        viewW: 600,
        viewH: 270,
        offsetX: 0,
        offsetY: 0,
      ),
      camera: camera,
      hostSize: const Size(600, 270),
    );
    final markers = layoutOffscreenIndicators(
      indicators: [
        indicator(
          1,
          const Offset(300, 0),
          .5,
          edge: OffscreenIndicatorEdge.top,
        ),
        indicator(2, Offset.zero, 3, edge: OffscreenIndicatorEdge.topLeft),
      ],
      viewport: viewport,
      safeBounds: const Rect.fromLTWH(0, 0, 600, 270),
      exclusions: [
        const Rect.fromLTWH(0, 0, 600, 75),
        const Rect.fromLTWH(190, 80, 220, 50),
      ],
      measure: (_) => const Size(64, 22),
    );
    expect(markers, hasLength(2));
    expect(markers.first.label, '<1 m');
    expect(markers.first.bounds.center.dx, 300);
    expect(markers.first.bounds.top, greaterThanOrEqualTo(134));
    expect(markers.last.bounds.left, 4);
    expect(markers.last.bounds.top, 79);
  });
}

OffscreenIndicator indicator(
  int id,
  Offset anchor,
  double distance, {
  bool player = false,
  OffscreenIndicatorEdge edge = OffscreenIndicatorEdge.left,
}) => OffscreenIndicator(
  id: id,
  isPlayer: player,
  edge: edge,
  anchor: anchor,
  distanceMeters: distance,
);
