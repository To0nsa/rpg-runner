import 'dart:convert';

import 'terrain_graph_artifact.dart';

/// Digests from a trusted release artifact directory, never a replay payload.
/// Keys are exact Core input fingerprints; filenames are derived from them.
final class TerrainGraphArtifactManifest {
  TerrainGraphArtifactManifest(Map<String, TerrainGraphArtifactEntry> entries)
    : entries = Map.unmodifiable(entries);

  final Map<String, TerrainGraphArtifactEntry> entries;

  factory TerrainGraphArtifactManifest.decode(String source) {
    if (source.length > 32 * 1024 * 1024) {
      throw const FormatException('Navigation manifest exceeds size limit.');
    }
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic> ||
        json['version'] != terrainGraphArtifactVersion ||
        json['entries'] is! Map) {
      throw const FormatException('Unsupported navigation manifest.');
    }
    final entries = <String, TerrainGraphArtifactEntry>{};
    for (final entry in (json['entries'] as Map).entries) {
      final value = entry.value;
      if (entry.key is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.key as String) ||
          value is! List ||
          value.length != 2 ||
          value[0] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(value[0] as String) ||
          value[1] is! int ||
          (value[1] as int) < 70 ||
          (value[1] as int) > TerrainGraphArtifactCodec.maxBytes) {
        throw const FormatException('Invalid navigation manifest entry.');
      }
      entries[entry.key as String] = TerrainGraphArtifactEntry(
        sha256: value[0] as String,
        bytes: value[1] as int,
      );
    }
    return TerrainGraphArtifactManifest(entries);
  }

  String encode() {
    final keys = entries.keys.toList()..sort();
    return jsonEncode({
      'version': terrainGraphArtifactVersion,
      'entries': {
        for (final key in keys)
          key: [entries[key]!.sha256, entries[key]!.bytes],
      },
    });
  }
}

final class TerrainGraphArtifactEntry {
  const TerrainGraphArtifactEntry({required this.sha256, required this.bytes});
  final String sha256;
  final int bytes;
}
