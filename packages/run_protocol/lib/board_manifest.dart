import 'board_key.dart';
import 'codecs/json_value_reader.dart';

enum BoardStatus {
  scheduled,
  active,
  closed,
  disabled;

  static BoardStatus parse(Object? raw) {
    if (raw is! String) {
      throw FormatException('status must be a string.');
    }
    return switch (raw) {
      'scheduled' => BoardStatus.scheduled,
      'active' => BoardStatus.active,
      'closed' => BoardStatus.closed,
      'disabled' => BoardStatus.disabled,
      _ => throw FormatException(
        'status must be one of: scheduled|active|closed|disabled.',
      ),
    };
  }
}

final class BoardManifest {
  BoardManifest({
    required this.boardId,
    required this.boardKey,
    required this.gameCompatVersion,
    required this.ghostVersion,
    required this.tickHz,
    required this.seed,
    required this.opensAtMs,
    required this.closesAtMs,
    required this.status,
    this.minClientBuild,
  }) {
    _requireNonEmpty(boardId, 'boardId');
    _requireNonEmpty(gameCompatVersion, 'gameCompatVersion');
    _requireNonEmpty(ghostVersion, 'ghostVersion');
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be positive');
    }
    if (closesAtMs <= opensAtMs) {
      throw ArgumentError.value(
        closesAtMs,
        'closesAtMs',
        'must be greater than opensAtMs',
      );
    }
    if (minClientBuild != null && minClientBuild!.isEmpty) {
      throw ArgumentError.value(
        minClientBuild,
        'minClientBuild',
        'must be non-empty when set',
      );
    }
  }

  final String boardId;
  final BoardKey boardKey;
  final String gameCompatVersion;
  final String ghostVersion;
  final int tickHz;
  final int seed;
  final int opensAtMs;
  final int closesAtMs;
  final String? minClientBuild;
  final BoardStatus status;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'boardId': boardId,
      'boardKey': boardKey.toJson(),
      'gameCompatVersion': gameCompatVersion,
      'ghostVersion': ghostVersion,
      'tickHz': tickHz,
      'seed': seed,
      'opensAtMs': opensAtMs,
      'closesAtMs': closesAtMs,
      if (minClientBuild != null) 'minClientBuild': minClientBuild,
      'status': status.name,
    };
  }

  factory BoardManifest.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'boardManifest');
    return BoardManifest(
      boardId: readRequiredString(json, 'boardId'),
      boardKey: BoardKey.fromJson(json['boardKey']),
      gameCompatVersion: readRequiredString(json, 'gameCompatVersion'),
      ghostVersion: readRequiredString(json, 'ghostVersion'),
      tickHz: readRequiredInt(json, 'tickHz'),
      seed: readRequiredInt(json, 'seed'),
      opensAtMs: readRequiredInt(json, 'opensAtMs'),
      closesAtMs: readRequiredInt(json, 'closesAtMs'),
      minClientBuild: readOptionalString(json, 'minClientBuild'),
      status: BoardStatus.parse(json['status']),
    );
  }

  static void _requireNonEmpty(String value, String name) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, name, 'must be non-empty');
    }
  }
}
