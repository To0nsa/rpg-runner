import 'package:googleapis/firestore/v1.dart' as firestore;

import 'firestore_value_codec.dart';
import 'google_api_helpers.dart';

abstract class BoardRepository {
  Future<Map<String, Object?>?> loadBoard({required String boardId});
}

class NoopBoardRepository implements BoardRepository {
  @override
  Future<Map<String, Object?>?> loadBoard({required String boardId}) async {
    return null;
  }
}

class FirestoreBoardRepository implements BoardRepository {
  FirestoreBoardRepository({
    required this.projectId,
    required this.apiProvider,
  });

  final String projectId;
  final GoogleCloudApiProvider apiProvider;

  String get _databaseRoot => 'projects/$projectId/databases/(default)';
  String _boardDocPath(String boardId) =>
      '$_databaseRoot/documents/leaderboard_boards/$boardId';

  @override
  Future<Map<String, Object?>?> loadBoard({required String boardId}) async {
    final firestoreApi = await apiProvider.firestoreApi();
    return _loadDocument(
      firestoreApi: firestoreApi,
      path: _boardDocPath(boardId),
    );
  }

  Future<Map<String, Object?>?> _loadDocument({
    required firestore.FirestoreApi firestoreApi,
    required String path,
  }) async {
    firestore.Document document;
    try {
      document = await firestoreApi.projects.databases.documents.get(path);
    } catch (error) {
      if (isApiNotFound(error)) {
        return null;
      }
      rethrow;
    }
    return decodeFirestoreFields(document.fields);
  }
}
