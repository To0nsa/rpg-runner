import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/navigation/types/surface_id.dart';

void main() {
  test(
    'surface ID chunk index round-trips for negative and positive values',
    () {
      for (final chunkIndex in <int>[-2, -1, 0, 1]) {
        final id = packSurfaceId(chunkIndex: chunkIndex, localSolidIndex: 123);
        expect(unpackChunkIndex(id), chunkIndex);
      }
    },
  );
}
