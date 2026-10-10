import 'package:runner_core/ecs/spatial/grid_cell_map.dart';
import 'package:test/test.dart';

void main() {
  test(
    'signed and wide coordinates identify distinct cells on every target',
    () {
      const coordinates = [-0x100000000, -1, 0, 1, 0x100000000];
      final values = GridCellMap<(int, int)>();
      for (final x in coordinates) {
        for (final y in coordinates) {
          values.putIfAbsent(x, y, () => (x, y));
        }
      }
      expect(values.length, coordinates.length * coordinates.length);
      expect(values.get(2, 3), isNull);
      for (final x in coordinates) {
        for (final y in coordinates) {
          expect(values.get(x, y), (x, y));
        }
      }
      values.clear();
      expect(values.length, 0);
      expect(values.values, isEmpty);
      expect(values.get(1, 1), isNull);
      values.putIfAbsent(1, 1, () => (2, 3));
      expect(values.get(1, 1), (2, 3));
    },
  );
}
