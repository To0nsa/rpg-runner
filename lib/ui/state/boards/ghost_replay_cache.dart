import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:run_protocol/replay_blob.dart';

import 'ghost_api.dart';
import '../run/run_start_remote_exception.dart';

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
      final responseBytes = await response
          .expand((List<int> chunk) => chunk)
          .toList();
      if (response.statusCode != HttpStatus.ok) {
        final responseSnippet = _responseSnippet(responseBytes);
        final suffix = responseSnippet == null ? '' : ' ($responseSnippet)';
        throw RunStartRemoteException(
          code: 'ghost-download-failed',
          message:
              'Ghost download failed with status ${response.statusCode}$suffix.',
        );
      }
      return responseBytes;
    } finally {
      client.close(force: true);
    }
  }

  String? _responseSnippet(List<int> bytes) {
    if (bytes.isEmpty) {
      return null;
    }
    try {
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      if (text.isEmpty) {
        return null;
      }
      final singleLine = text.replaceAll(RegExp(r'\s+'), ' ');
      if (singleLine.length <= 160) {
        return singleLine;
      }
      return '${singleLine.substring(0, 160)}...';
    } catch (_) {
      return null;
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
    final replayBlob = await _decodeReplay(
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
      final replayBlob = await _decodeReplay(bytes: bytes, manifest: manifest);
      return GhostReplayBootstrap(
        manifest: manifest,
        replayBlob: replayBlob,
        cachedFile: cacheFile,
        cachedAtMs: _clockMs(),
      );
    } catch (_) {
      try {
        await cacheFile.delete();
      } catch (_) {
        // A later verified write may still replace this unusable cache entry.
      }
      return null;
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
  // Bound filenames independently of server IDs and Storage generation lengths.
  final keyDigest = sha256.convert(
    utf8.encode(
      jsonEncode([
        manifest.boardId,
        manifest.entryId,
        manifest.runSessionId,
        manifest.promotedReplayStorageGeneration,
        manifest.replayDigest,
        manifest.updatedAtMs,
      ]),
    ),
  );
  return '${prefix}_$keyDigest.replay.json';
}

String _cacheFilePrefix(String boardId, String entryId) {
  // Pruning must distinguish full entry identities, even on long shared boards.
  final entryDigest = sha256.convert(
    utf8.encode(jsonEncode([boardId, entryId])),
  );
  return 'ghost_$entryDigest';
}

Directory _defaultGhostCacheDirectory() {
  return Directory(
    '${Directory.systemTemp.path}'
    '${Platform.pathSeparator}rpg_runner'
    '${Platform.pathSeparator}ghost_cache',
  );
}

int _defaultClockMs() => DateTime.now().millisecondsSinceEpoch;

// Only immutable payload data crosses the worker boundary; never capture the
// cache instance, downloader, filesystem handles, or signed download URL.
typedef _ReplayDecodeRequest = ({
  List<int> bytes,
  String replayDigest,
  String runSessionId,
  String boardId,
});

Future<ReplayBlobV1> _decodeReplay({
  required List<int> bytes,
  required GhostManifest manifest,
}) => compute(_decodeAndValidateReplay, (
  bytes: bytes,
  replayDigest: manifest.replayDigest,
  runSessionId: manifest.runSessionId,
  boardId: manifest.boardId,
), debugLabel: 'ghost-replay-decode');

ReplayBlobV1 _decodeAndValidateReplay(_ReplayDecodeRequest request) {
  final jsonBytes = _maybeDecompressGzip(request.bytes);
  final decoded = jsonDecode(utf8.decode(jsonBytes));
  final replayBlob = ReplayBlobV1.fromJson(decoded, verifyDigest: true);
  if (replayBlob.canonicalSha256 != request.replayDigest) {
    throw const RunStartRemoteException(
      code: 'failed-precondition',
      message: 'Ghost replay digest does not match manifest.',
    );
  }
  if (replayBlob.runSessionId != request.runSessionId) {
    throw const RunStartRemoteException(
      code: 'failed-precondition',
      message: 'Ghost replay runSessionId does not match manifest.',
    );
  }
  if (replayBlob.boardId != request.boardId) {
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
