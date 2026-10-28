import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Narrow local transport. Firebase credentials stay in the child Node service.
abstract interface class AdminService {
  Future<Map<String, dynamic>> call(String path, [Map<String, Object?>? body]);
  Future<void> close();
}

class AdminServiceException implements Exception {
  AdminServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Owns one loopback service and its pipe lifetime; only this instance is stopped.
class LocalAdminService implements AdminService {
  LocalAdminService._(this._process, this._origin, this._token, this._logs);
  final Process _process;
  final Uri _origin;
  final String _token;
  final List<StreamSubscription<dynamic>> _logs;
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  bool _closed = false;

  static Future<LocalAdminService> start(
    String repository, {
    bool fixture = false,
  }) async {
    final process = await Process.start(
      'node',
      ['$repository/tools/admin/service/native.mjs', if (fixture) '--fixture'],
      workingDirectory: repository,
      environment: {'DEBUG': ''},
    );
    final ready = Completer<Map<String, dynamic>>();
    final errors = StringBuffer();
    final subscriptions = <StreamSubscription<dynamic>>[
      process.stderr.transform(utf8.decoder).listen((text) {
        if (errors.length < 4000) errors.write(text);
      }),
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (ready.isCompleted) return;
            try {
              final data = jsonDecode(line);
              if (data is Map<String, dynamic> && data['protocol'] == 1) {
                ready.complete(data);
              }
            } on FormatException {
              /* Provider logs do not form the handshake. */
            }
          }),
    ];
    unawaited(
      process.exitCode.then((_) {
        if (!ready.isCompleted) {
          ready.completeError(
            AdminServiceException(
              errors.isEmpty
                  ? 'Admin service stopped before startup.'
                  : errors.toString().trim(),
            ),
          );
        }
      }),
    );
    try {
      final data = await ready.future.timeout(const Duration(seconds: 30));
      final origin = Uri.parse(data['origin'] as String);
      final token = data['token'];
      if (origin.scheme != 'http' ||
          origin.host != '127.0.0.1' ||
          !origin.hasPort ||
          origin.path.isNotEmpty ||
          origin.userInfo.isNotEmpty ||
          origin.hasQuery ||
          origin.hasFragment ||
          token is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
        throw const FormatException('Invalid local service handshake.');
      }
      return LocalAdminService._(process, origin, token, subscriptions);
    } catch (_) {
      await process.stdin.close();
      process.kill();
      for (final sub in subscriptions) {
        await sub.cancel();
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> call(
    String path, [
    Map<String, Object?>? body,
  ]) async {
    if (_closed) throw AdminServiceException('Admin service is closed.');
    if (!{
      '/api/environments',
      '/api/catalog',
      '/api/preview',
      '/api/send',
    }.contains(path)) {
      throw ArgumentError('Unknown Admin endpoint.');
    }
    final request = await _http.openUrl(
      body == null ? 'GET' : 'POST',
      _origin.resolve(path),
    );
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (body != null) request.write(jsonEncode(body));
    try {
      final response = await request.close().timeout(
        const Duration(seconds: 90),
      );
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes.addAll(chunk);
        if (bytes.length > 256 * 1024) {
          throw const FormatException('Admin response is too large.');
        }
      }
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid Admin response.');
      }
      if (response.statusCode != 200) {
        throw AdminServiceException(
          value['error'] as String? ?? 'Admin request failed.',
        );
      }
      return value;
    } catch (_) {
      request.abort();
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _http.close(force: true);
    await _process.stdin.close();
    try {
      await _process.exitCode.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      _process.kill();
    }
    for (final sub in _logs) {
      await sub.cancel();
    }
  }
}
