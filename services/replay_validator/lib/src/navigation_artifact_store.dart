import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/navigation/terrain_graph_artifact.dart';
import 'package:runner_core/navigation/terrain_graph_artifact_manifest.dart';
import 'package:runner_core/navigation/terrain_graph_materializer.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';

/// Reads only release-built artifacts in the worker image. A bounded byte LRU
/// accelerates repeated reads; no replay or player-controlled path enters it.
/// Missing/corrupt artifacts are performance misses, never acceptance changes.
final class NavigationArtifactStore {
  NavigationArtifactStore({
    required this.directory,
    this.maxCachedBytes = 32 * 1024 * 1024,
  }) {
    if (maxCachedBytes < 0) throw ArgumentError.value(maxCachedBytes);
    final manifestFile = File('$directory/manifest.json');
    if (manifestFile.existsSync()) {
      if (manifestFile.lengthSync() > 32 * 1024 * 1024) {
        throw const FormatException('Navigation manifest exceeds size limit.');
      }
      _manifest = TerrainGraphArtifactManifest.decode(
        manifestFile.readAsStringSync(),
      );
    }
  }

  final String directory;
  final int maxCachedBytes;
  TerrainGraphArtifactManifest? _manifest;
  final _cache = LinkedHashMap<String, Uint8List>();
  int _cachedBytes = 0;
  int hits = 0;
  int misses = 0;
  int invalid = 0;
  int get cachedBytes => _cachedBytes;
  TerrainGraphMaterializer get materializer =>
      TerrainGraphMaterializer.onDemand(lookup: lookup);

  TerrainSurfaceGraph? lookup(
    TerrainGeometry geometry,
    TerrainSurfaceSet surfaces,
    TerrainSurfaceGraphBuildProfile profile,
  ) {
    final manifest = _manifest;
    if (manifest == null) {
      misses++;
      return null;
    }
    final key = terrainGraphArtifactKey(
      geometry: geometry,
      surfaces: surfaces,
      profile: profile,
    );
    final entry = manifest.entries[key];
    if (entry == null) {
      misses++;
      return null;
    }
    try {
      var bytes = _cache.remove(key);
      if (bytes == null) {
        final file = File('$directory/$key.rng');
        if (!file.existsSync() || file.lengthSync() != entry.bytes) {
          invalid++;
          return null;
        }
        bytes = file.readAsBytesSync();
      } else {
        _cachedBytes -= bytes.length;
      }
      final graph = TerrainGraphArtifactCodec.decode(
        bytes: bytes,
        expectedSha256: entry.sha256,
        key: key,
        surfaces: surfaces,
        profile: profile,
      );
      if (bytes.length <= maxCachedBytes) {
        while (_cachedBytes + bytes.length > maxCachedBytes &&
            _cache.isNotEmpty) {
          _cachedBytes -= _cache.remove(_cache.keys.first)!.length;
        }
        _cache[key] = bytes;
        _cachedBytes += bytes.length;
      }
      hits++;
      return graph;
    } on FileSystemException {
      invalid++;
      return null;
    } on FormatException {
      invalid++;
      return null;
    } on ArgumentError {
      invalid++;
      return null;
    }
  }
}
