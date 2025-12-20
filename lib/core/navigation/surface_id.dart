const int surfaceKindTop = 0;
const int surfaceIdUnknown = -1;

/// Packs a surface identity into a stable, comparable 64-bit key.
///
/// Ordering is lexicographic by (chunkIndex, localSolidIndex, surfaceKind).
int packSurfaceId({
  required int chunkIndex,
  required int localSolidIndex,
  int surfaceKind = surfaceKindTop,
}) {
  if (localSolidIndex < 0) {
    throw ArgumentError.value(
      localSolidIndex,
      'localSolidIndex',
      'must be >= 0',
    );
  }
  final chunk = (chunkIndex ^ 0x80000000) & 0xFFFFFFFF;
  final local = ((localSolidIndex << 2) | (surfaceKind & 0x3)) & 0xFFFFFFFF;
  return (chunk << 32) | local;
}

int unpackChunkIndex(int surfaceId) {
  final chunk = (surfaceId >> 32) & 0xFFFFFFFF;
  return (chunk ^ 0x80000000);
}

int unpackLocalSolidIndex(int surfaceId) {
  final local = surfaceId & 0xFFFFFFFF;
  return local >> 2;
}

int unpackSurfaceKind(int surfaceId) {
  return surfaceId & 0x3;
}
