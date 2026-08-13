import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/atlas/atlas_grid.dart';
import 'package:runner_editor/src/atlas/atlas_grid_settings_cache.dart';
import 'package:runner_editor/src/atlas/atlas_pixel_rect.dart';

void main() {
  group('AtlasPixelRect parsing', () {
    test('accepts an arbitrary in-bounds integer rectangle', () {
      final result = parseAtlasPixelRect(
        rawX: '3',
        rawY: '5',
        rawWidth: '17',
        rawHeight: '19',
        imageWidth: 64,
        imageHeight: 64,
      );

      expect(
        result.rect,
        const AtlasPixelRect(x: 3, y: 5, width: 17, height: 19),
      );
      expect(result.error, isNull);
    });

    test('rejects partial, negative, zero, and out-of-bounds values', () {
      AtlasPixelRectParseResult parse(
        String x,
        String y,
        String width,
        String height,
      ) => parseAtlasPixelRect(
        rawX: x,
        rawY: y,
        rawWidth: width,
        rawHeight: height,
        imageWidth: 64,
        imageHeight: 64,
      );

      expect(parse('0', '', '32', '32').error, isNotNull);
      expect(parse('-1', '0', '32', '32').error, isNotNull);
      expect(parse('0', '0', '0', '32').error, isNotNull);
      expect(parse('48', '0', '32', '32').error, isNotNull);
    });
  });

  group('AtlasGridGeometry', () {
    test('defaults to complete 32x32 cells and ignores a partial tail', () {
      const settings = AtlasGridSettings();

      expect(
        AtlasGridGeometry.completeColumnCount(
          settings: settings,
          imageWidth: 70,
        ),
        2,
      );
      expect(
        AtlasGridGeometry.completeRowCount(settings: settings, imageHeight: 63),
        1,
      );
      expect(
        AtlasGridGeometry.hitTest(
          settings: settings,
          imageWidth: 70,
          imageHeight: 63,
          x: 65,
          y: 12,
        ),
        isNull,
      );
    });

    test('uses half-open cells and excludes gutters and image boundaries', () {
      const settings = AtlasGridSettings(
        cellWidth: 10,
        cellHeight: 8,
        originX: 2,
        originY: 3,
        gutterX: 2,
        gutterY: 1,
      );

      AtlasGridCell? hit(double x, double y) => AtlasGridGeometry.hitTest(
        settings: settings,
        imageWidth: 30,
        imageHeight: 24,
        x: x,
        y: y,
      );

      expect(hit(2, 3), const AtlasGridCell(column: 0, row: 0));
      expect(hit(11.999, 10.999), const AtlasGridCell(column: 0, row: 0));
      expect(hit(12, 4), isNull);
      expect(hit(14, 3), const AtlasGridCell(column: 1, row: 0));
      expect(hit(3, 11), isNull);
      expect(hit(30, 4), isNull);
      expect(hit(4, 24), isNull);
    });

    test('normalizes reverse ranges and includes intermediate gutters', () {
      const settings = AtlasGridSettings(
        cellWidth: 8,
        cellHeight: 6,
        originX: 1,
        originY: 2,
        gutterX: 2,
        gutterY: 3,
      );

      final rect = AtlasGridGeometry.rectForRange(
        settings: settings,
        first: const AtlasGridCell(column: 2, row: 3),
        second: const AtlasGridCell(column: 0, row: 1),
      );

      expect(rect, const AtlasPixelRect(x: 1, y: 11, width: 28, height: 24));
    });

    test('drag retains the last complete cell while crossing a gutter', () {
      const settings = AtlasGridSettings(
        cellWidth: 10,
        cellHeight: 10,
        gutterX: 2,
      );
      final drag = AtlasGridDragController();

      expect(
        drag.begin(
          settings: settings,
          imageWidth: 40,
          imageHeight: 20,
          x: 3,
          y: 3,
        ),
        const AtlasPixelRect(x: 0, y: 0, width: 10, height: 10),
      );
      expect(
        drag.update(
          settings: settings,
          imageWidth: 40,
          imageHeight: 20,
          x: 10.5,
          y: 3,
        ),
        const AtlasPixelRect(x: 0, y: 0, width: 10, height: 10),
      );
      expect(
        drag.update(
          settings: settings,
          imageWidth: 40,
          imageHeight: 20,
          x: 13,
          y: 3,
        ),
        const AtlasPixelRect(x: 0, y: 0, width: 22, height: 10),
      );
    });

    test('valid oversized grids contain no complete cells', () {
      const settings = AtlasGridSettings(cellWidth: 128, cellHeight: 128);
      expect(
        AtlasGridGeometry.completeColumnCount(
          settings: settings,
          imageWidth: 64,
        ),
        0,
      );
      expect(
        AtlasGridGeometry.completeRowCount(settings: settings, imageHeight: 64),
        0,
      );
    });
  });

  test('grid settings cache is path normalized and workspace scoped', () {
    final cache = AtlasGridSettingsCache();
    const custom = AtlasGridSettings(cellWidth: 16, cellHeight: 24);

    cache.ensureWorkspace(r'C:\repo');
    cache.setSettings(r'assets\images\level\atlas.png', custom);
    expect(cache.settingsFor('assets/images/level/atlas.png'), custom);

    cache.ensureWorkspace(r'C:\another_repo');
    expect(
      cache.settingsFor('assets/images/level/atlas.png'),
      const AtlasGridSettings(),
    );
  });
}
