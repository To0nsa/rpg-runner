import '../chunks/chunk_v2_file_codec.dart';
import '../prefabs/store/prefab_v3_file_codec.dart';
import 'polygon_authoring_target_models.dart';

/// Migration-facing facade over normal strict polygon-source codecs.
///
/// Legacy parsing remains migration-owned. Current prefab-v3 and chunk-v2
/// structure must have only one authority, so this facade delegates without
/// adding compatibility defaults, normalization, or filesystem behavior.
abstract final class PolygonAuthoringTargetCodec {
  static PrefabV3TargetDocument decodePrefabV3(
    String raw, {
    String sourcePath = 'prefab_defs.json',
  }) => PrefabV3FileCodec.decode(raw, sourcePath: sourcePath);

  static String encodePrefabV3(PrefabV3TargetDocument document) =>
      PrefabV3FileCodec.encode(document);

  static ChunkV2TargetDocument decodeChunkV2(
    String raw, {
    String sourcePath = 'chunk.json',
  }) => ChunkV2FileCodec.decode(raw, sourcePath: sourcePath);

  static String encodeChunkV2(ChunkV2TargetDocument document) =>
      ChunkV2FileCodec.encode(document);
}
