import 'package:_discoveryapis_commons/_discoveryapis_commons.dart'
    as commons;
import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:googleapis_auth/auth_io.dart' as auth;

class GoogleCloudApiProvider {
  GoogleCloudApiProvider({
    List<String>? scopes,
  }) : _scopes =
           scopes ??
           const <String>['https://www.googleapis.com/auth/cloud-platform'];

  final List<String> _scopes;
  Future<auth.AutoRefreshingAuthClient>? _authClientFuture;

  Future<firestore.FirestoreApi> firestoreApi() async {
    return firestore.FirestoreApi(await _authClient());
  }

  Future<storage.StorageApi> storageApi() async {
    return storage.StorageApi(await _authClient());
  }

  Future<auth.AutoRefreshingAuthClient> _authClient() {
    return _authClientFuture ??= auth.clientViaApplicationDefaultCredentials(
      scopes: _scopes,
    );
  }
}

bool isApiNotFound(Object error) {
  return error is commons.DetailedApiRequestError && error.status == 404;
}

bool isApiConflict(Object error) {
  if (error is! commons.DetailedApiRequestError) {
    return false;
  }
  return error.status == 409 || error.status == 412;
}

bool isApiAlreadyExists(Object error) {
  return error is commons.DetailedApiRequestError && error.status == 409;
}
