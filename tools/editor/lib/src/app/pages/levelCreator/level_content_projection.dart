import '../../../chunks/chunk_domain_models.dart';
import '../../../chunks/chunk_domain_plugin.dart';
import '../../../chunks/chunk_v2_file_data.dart';
import '../../../chunks/chunk_v2_models.dart';
import '../../../workspace/editor_workspace.dart';

/// Read-only authored dependencies reused by the Level catalog and Play capture.
/// The isolated plugin load never replaces the editor's active Level session;
/// changes still navigate to their owning Chunk or Parallax domain.
class LevelContentProjection {
  const LevelContentProjection({required this.document});

  final ChunkV2Document document;

  List<ChunkV2FileData> chunksFor(String levelId, {String? groupId}) => document
      .chunks
      .where(
        (chunk) =>
            chunk.levelId == levelId &&
            (groupId == null || chunk.assemblyGroupId == groupId),
      )
      .toList(growable: false);

  int activeCount(String levelId, {String? groupId}) => chunksFor(
    levelId,
    groupId: groupId,
  ).where((chunk) => chunk.status == chunkStatusActive).length;
}

typedef LevelContentProjectionLoader = Future<LevelContentProjection> Function(
  String workspaceRoot,
);

/// Loads current authoring schemas using existing domain readers. Runtime
/// preparation subsequently performs canonical compilation and admission.
Future<LevelContentProjection> loadLevelContentProjection(
  String workspaceRoot,
) async => LevelContentProjection(
  document: await ChunkDomainPlugin().loadV2FromRepo(
    EditorWorkspace(rootPath: workspaceRoot),
    allowEmpty: true,
  ),
);
