/// Surface ID Packing Utilities.
///
/// Surfaces are identified by a 64-bit integer that encodes:
/// - **Chunk Index** (32 bits, high): Which level chunk the surface belongs to.
/// - **Local Solid Index** (30 bits): Index of the solid tile within the chunk.
/// - **Surface Kind** (2 bits, low): Top/Side/etc. (Currently only Top is used).
///
/// This encoding allows:
/// - Stable, deterministic IDs across save/load.
/// - Efficient Map/Set lookups.
/// - Lexicographic ordering by chunk then local index.
library;

/// The "Top" surface kind (entities stand on top of the solid).
const int surfaceKindTop = 0;

const int _signed32Min = -0x80000000;
const int _signed32Max = 0x7FFFFFFF;
const int _maxPackedLocalSolidIndex = 0x3FFFFFFF;

/// Sentinel value for "no surface" / invalid.
const int surfaceIdUnknown = -1;

/// Packs a surface identity into a stable, comparable 64-bit key.
///
/// **Bit Layout**:
/// ```
/// [63..32] chunkIndex (XOR'd with 0x80000000 to handle signed comparison)
/// [31..2]  localSolidIndex
/// [1..0]   surfaceKind
/// ```
int packSurfaceId({
  required int chunkIndex,
  required int localSolidIndex,
  int surfaceKind = surfaceKindTop,
}) {
  if (chunkIndex < _signed32Min || chunkIndex > _signed32Max) {
    throw ArgumentError.value(
      chunkIndex,
      'chunkIndex',
      'must fit in signed 32-bit range',
    );
  }
  if (localSolidIndex < 0) {
    throw ArgumentError.value(
      localSolidIndex,
      'localSolidIndex',
      'must be >= 0',
    );
  }
  if (localSolidIndex > _maxPackedLocalSolidIndex) {
    throw ArgumentError.value(
      localSolidIndex,
      'localSolidIndex',
      'must be <= $_maxPackedLocalSolidIndex (30-bit)',
    );
  }
  if (surfaceKind < 0 || surfaceKind > 0x3) {
    throw ArgumentError.value(surfaceKind, 'surfaceKind', 'must fit in 2 bits');
  }
  // XOR with sign bit to make signed chunkIndex sort correctly as unsigned.
  final chunk = ((chunkIndex & 0xFFFFFFFF) ^ 0x80000000) & 0xFFFFFFFF;
  // Pack localSolidIndex and surfaceKind into lower 32 bits.
  final local = ((localSolidIndex << 2) | (surfaceKind & 0x3)) & 0xFFFFFFFF;
  return (chunk << 32) | local;
}

/// Extracts the chunk index from a packed [surfaceId].
int unpackChunkIndex(int surfaceId) {
  final chunk = (surfaceId >> 32) & 0xFFFFFFFF;
  final signed = (chunk ^ 0x80000000) & 0xFFFFFFFF;
  return (signed & 0x80000000) != 0 ? signed - 0x100000000 : signed;
}

/// Extracts the local solid index from a packed [surfaceId].
int unpackLocalSolidIndex(int surfaceId) {
  final local = surfaceId & 0xFFFFFFFF;
  return local >> 2;
}

/// Extracts the surface kind (Top/Side) from a packed [surfaceId].
int unpackSurfaceKind(int surfaceId) {
  return surfaceId & 0x3;
}
