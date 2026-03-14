import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:run_protocol/replay_blob.dart';

import 'ghost_api.dart';
import 'run_start_remote_exception.dart';

final class GhostReplayBootstrap {
  const GhostReplayBootstrap({
    required this.manifest,
    required this.replayBlob,
    required this.cachedFile,
    required this.cachedAtMs,
  });

  final GhostManifest manifest;
  final ReplayBlobV1 replayBlob;
  final File cachedFile;
  final int cachedAtMs;
}

abstract class GhostReplayCache {
  Future<GhostReplayBootstrap> loadReplay({required GhostManifest manifest});
}

abstract class GhostReplayDownloader {
  Future<List<int>> downloadBytes({required Uri url});
}

class HttpGhostReplayDownloader implements GhostReplayDownloader {
  const HttpGhostReplayDownloader();

  @override
  Future<List<int>> downloadBytes({required Uri url}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw RunStartRemoteException(
          code: 'ghost-download-failed',
          message: 'Ghost download failed with status ${response.statusCode}.',
        );
      }
      return response.expand((List<int> chunk) => chunk).toList();
    } finally {
      client.close(force: true);
    }
  }
}

class FileGhostReplayCache implements GhostReplayCache {
  FileGhostReplayCache({
    Directory? cacheDirectory,
    GhostReplayDownloader? downloader,
    int Function()? clockMs,
  }) : _cacheDirectory = cacheDirectory ?? _defaultGhostCacheDirectory(),
       _downloader = downloader ?? const HttpGhostReplayDownloader(),
       _clockMs = clockMs ?? _defaultClockMs;

  final Directory _cacheDirectory;
  final GhostReplayDownloader _downloader;
  final int Function() _clockMs;

  @override
  Future<GhostReplayBootstrap> loadReplay({
    required GhostManifest manifest,
  }) async {
    await _cacheDirectory.create(recursive: true);
    final cacheFile = File(
      '${_cacheDirectory.path}${Platform.pathSeparator}${_cacheFileName(manifest)}',
    );
    final cached = await _tryLoadCached(cacheFile, manifest);
    if (cached != null) {
      return cached;
    }

    final nowMs = _clockMs();
    if (manifest.downloadUrlExpiresAtMs <= nowMs) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message: 'Ghost download URL expired before fetch.',
      );
    }
    final uri = Uri.tryParse(manifest.downloadUrl);
    if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
      throw const RunStartRemoteException(
        code: 'invalid-argument',
        message: 'Ghost manifest downloadUrl is invalid.',
      );
    }

    final downloadedBytes = await _downloader.downloadBytes(url: uri);
    final replayBlob = _decodeAndValidateReplay(
      bytes: downloadedBytes,
      manifest: manifest,
    );
    await cacheFile.writeAsBytes(downloadedBytes, flush: true);
    await _pruneSupersededEntryCaches(
      manifest: manifest,
      keepFileName: cacheFile.uri.pathSegments.last,
    );
    return GhostReplayBootstrap(
      manifest: manifest,
      replayBlob: replayBlob,
      cachedFile: cacheFile,
      cachedAtMs: nowMs,
    );
  }

  Future<GhostReplayBootstrap?> _tryLoadCached(
    File cacheFile,
    GhostManifest manifest,
  ) async {
    if (!await cacheFile.exists()) {
      return null;
    }
    try {
      final bytes = await cacheFile.readAsBytes();
      final replayBlob = _decodeAndValidateReplay(
        bytes: bytes,
        manifest: manifest,
      );
      return GhostReplayBootstrap(
        manifest: manifest,
        replayBlob: replayBlob,
        cachedFile: cacheFile,
        cachedAtMs: _clockMs(),
      );
    } catch (_) {
      await cacheFile.delete();
      return null;
    }
  }

  ReplayBlobV1 _decodeAndValidateReplay({
    required List<int> bytes,
    required GhostManifest manifest,
  }) {
    final jsonBytes = _maybeDecompressGzip(bytes);
    final decoded = jsonDecode(utf8.decode(jsonBytes));
    final replayBlob = ReplayBlobV1.fromJson(decoded, verifyDigest: true);
    if (replayBlob.runSessionId != manifest.runSessionId) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message: 'Ghost replay runSessionId does not match manifest.',
      );
    }
    if (replayBlob.boardId != manifest.boardId) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message: 'Ghost replay boardId does not match manifest.',
      );
    }
    return replayBlob;
  }

  List<int> _maybeDecompressGzip(List<int> bytes) {
    final looksGzip = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    if (!looksGzip) {
      return bytes;
    }
    try {
      return gzip.decode(bytes);
    } catch (error) {
      throw RunStartRemoteException(
        code: 'invalid-response',
        message: 'Ghost replay gzip decode failed: $error',
      );
    }
  }

  Future<void> _pruneSupersededEntryCaches({
    required GhostManifest manifest,
    required String keepFileName,
  }) async {
    final prefix = _cacheFilePrefix(manifest.boardId, manifest.entryId);
    await for (final entity in _cacheDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final name = entity.uri.pathSegments.last;
      if (name == keepFileName) {
        continue;
      }
      if (!name.startsWith(prefix)) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {
        // Best-effort pruning.
      }
    }
  }
}

String _cacheFileName(GhostManifest manifest) {
  final prefix = _cacheFilePrefix(manifest.boardId, manifest.entryId);
  final keyRaw =
      '${manifest.boardId}|${manifest.entryId}|${manifest.runSessionId}|'
      '${manifest.updatedAtMs}';
  final encodedKey = base64Url.encode(utf8.encode(keyRaw)).replaceAll('=', '');
  return '${prefix}_$encodedKey.replay.json';
}

String _cacheFilePrefix(String boardId, String entryId) {
  final raw = '${boardId}_$entryId'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final maxLen = math.min(raw.length, 48);
  return 'ghost_${raw.substring(0, maxLen)}';
}

Directory _defaultGhostCacheDirectory() {
  return Directory(
    '${Directory.systemTemp.path}'
    '${Platform.pathSeparator}rpg_runner'
    '${Platform.pathSeparator}ghost_cache',
  );
}

int _defaultClockMs() => DateTime.now().millisecondsSinceEpoch;
