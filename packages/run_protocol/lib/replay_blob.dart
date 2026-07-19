import 'board_key.dart';
import 'codecs/json_value_copy.dart';
import 'codecs/json_value_reader.dart';
import 'replay_digest.dart';

const int kReplayBlobVersion1 = 1;
const int kCommandEncodingVersion1 = 1;

final class ReplayCommandFrameV1 {
  ReplayCommandFrameV1({
    required this.tick,
    this.moveAxis,
    this.aimDirX,
    this.aimDirY,
    this.pressedMask = 0,
    this.abilitySlotHeldChangedMask = 0,
    this.abilitySlotHeldValueMask = 0,
  }) {
    if (tick <= 0) {
      throw ArgumentError.value(tick, 'tick', 'must be positive');
    }
    if ((aimDirX == null) != (aimDirY == null)) {
      throw ArgumentError(
        'aimDirX and aimDirY must be both set or both unset.',
      );
    }
    _validateAxis(moveAxis, 'moveAxis');
    _validateAxis(aimDirX, 'aimDirX');
    _validateAxis(aimDirY, 'aimDirY');
    if (pressedMask < 0 || (pressedMask & ~knownPressedMask) != 0) {
      throw ArgumentError.value(
        pressedMask,
        'pressedMask',
        'contains unsupported command bits',
      );
    }
    if (abilitySlotHeldChangedMask < 0 ||
        (abilitySlotHeldChangedMask & ~knownAbilitySlotMask) != 0) {
      throw ArgumentError.value(
        abilitySlotHeldChangedMask,
        'abilitySlotHeldChangedMask',
        'contains unsupported ability-slot bits',
      );
    }
    if (abilitySlotHeldValueMask < 0 ||
        (abilitySlotHeldValueMask & ~knownAbilitySlotMask) != 0 ||
        (abilitySlotHeldValueMask & ~abilitySlotHeldChangedMask) != 0) {
      throw ArgumentError.value(
        abilitySlotHeldValueMask,
        'abilitySlotHeldValueMask',
        'must be a subset of abilitySlotHeldChangedMask',
      );
    }
  }

  final int tick;
  final double? moveAxis;
  final double? aimDirX;
  final double? aimDirY;
  final int pressedMask;
  final int abilitySlotHeldChangedMask;
  final int abilitySlotHeldValueMask;

  static const int pressedJumpBit = 1 << 0;
  static const int pressedDashBit = 1 << 1;
  static const int pressedStrikeBit = 1 << 2;
  static const int pressedProjectileBit = 1 << 3;
  static const int pressedSecondaryBit = 1 << 4;
  static const int pressedSpellBit = 1 << 5;
  static const int knownPressedMask =
      pressedJumpBit |
      pressedDashBit |
      pressedStrikeBit |
      pressedProjectileBit |
      pressedSecondaryBit |
      pressedSpellBit;
  static const int knownAbilitySlotMask = (1 << 6) - 1;

  bool get jumpPressed => (pressedMask & pressedJumpBit) != 0;
  bool get dashPressed => (pressedMask & pressedDashBit) != 0;
  bool get strikePressed => (pressedMask & pressedStrikeBit) != 0;
  bool get projectilePressed => (pressedMask & pressedProjectileBit) != 0;
  bool get secondaryPressed => (pressedMask & pressedSecondaryBit) != 0;
  bool get spellPressed => (pressedMask & pressedSpellBit) != 0;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      't': tick,
      if (moveAxis != null) 'mx': moveAxis,
      if (aimDirX != null && aimDirY != null) ...<String, Object?>{
        'ax': aimDirX,
        'ay': aimDirY,
      },
      if (pressedMask != 0) 'pm': pressedMask,
      if (abilitySlotHeldChangedMask != 0) 'hm': abilitySlotHeldChangedMask,
      if (abilitySlotHeldValueMask != 0) 'hv': abilitySlotHeldValueMask,
    };
  }

  factory ReplayCommandFrameV1.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'commandStream.frame');
    final tick = readRequiredInt(json, 't');
    final moveAxis = readOptionalDouble(json, 'mx');
    final aimDirX = readOptionalDouble(json, 'ax');
    final aimDirY = readOptionalDouble(json, 'ay');
    final pressedMask = readOptionalInt(json, 'pm') ?? 0;
    final abilitySlotHeldChangedMask = readOptionalInt(json, 'hm') ?? 0;
    final abilitySlotHeldValueMask = readOptionalInt(json, 'hv') ?? 0;
    if (tick <= 0) {
      throw const FormatException('commandStream.frame.t must be positive.');
    }
    if ((aimDirX == null) != (aimDirY == null)) {
      throw const FormatException(
        'commandStream.frame aim axes must both be set or both be absent.',
      );
    }
    if (moveAxis != null && (moveAxis < -1 || moveAxis > 1)) {
      throw const FormatException(
        'commandStream.frame.mx must be within [-1, 1].',
      );
    }
    if (aimDirX != null && (aimDirX < -1 || aimDirX > 1)) {
      throw const FormatException(
        'commandStream.frame.ax must be within [-1, 1].',
      );
    }
    if (aimDirY != null && (aimDirY < -1 || aimDirY > 1)) {
      throw const FormatException(
        'commandStream.frame.ay must be within [-1, 1].',
      );
    }
    if (pressedMask < 0 || (pressedMask & ~knownPressedMask) != 0) {
      throw const FormatException(
        'commandStream.frame.pm contains unsupported command bits.',
      );
    }
    if (abilitySlotHeldChangedMask < 0 ||
        (abilitySlotHeldChangedMask & ~knownAbilitySlotMask) != 0) {
      throw const FormatException(
        'commandStream.frame.hm contains unsupported ability-slot bits.',
      );
    }
    if (abilitySlotHeldValueMask < 0 ||
        (abilitySlotHeldValueMask & ~knownAbilitySlotMask) != 0 ||
        (abilitySlotHeldValueMask & ~abilitySlotHeldChangedMask) != 0) {
      throw const FormatException(
        'commandStream.frame.hv must be a subset of hm.',
      );
    }
    return ReplayCommandFrameV1(
      tick: tick,
      moveAxis: moveAxis,
      aimDirX: aimDirX,
      aimDirY: aimDirY,
      pressedMask: pressedMask,
      abilitySlotHeldChangedMask: abilitySlotHeldChangedMask,
      abilitySlotHeldValueMask: abilitySlotHeldValueMask,
    );
  }

  static void _validateAxis(double? value, String name) {
    if (value == null) return;
    if (!value.isFinite || value < -1 || value > 1) {
      throw ArgumentError.value(
        value,
        name,
        'must be finite and within [-1, 1]',
      );
    }
  }
}

final class ReplayBlobV1 {
  ReplayBlobV1({
    required this.runSessionId,
    required this.tickHz,
    required this.seed,
    required this.levelId,
    required this.playerCharacterId,
    required Map<String, Object?> loadoutSnapshot,
    required this.totalTicks,
    required List<ReplayCommandFrameV1> commandStream,
    required this.canonicalSha256,
    this.boardId,
    this.boardKey,
    this.commandEncodingVersion = kCommandEncodingVersion1,
    this.replayVersion = kReplayBlobVersion1,
    Map<String, Object?>? clientSummary,
  }) : loadoutSnapshot = immutableJsonObject(
         loadoutSnapshot,
         fieldName: 'loadoutSnapshot',
       ),
       clientSummary = clientSummary == null
           ? null
           : immutableJsonObject(clientSummary, fieldName: 'clientSummary'),
       commandStream = List<ReplayCommandFrameV1>.unmodifiable(commandStream) {
    if (replayVersion != kReplayBlobVersion1) {
      throw ArgumentError.value(
        replayVersion,
        'replayVersion',
        'is unsupported',
      );
    }
    if (commandEncodingVersion != kCommandEncodingVersion1) {
      throw ArgumentError.value(
        commandEncodingVersion,
        'commandEncodingVersion',
        'is unsupported',
      );
    }
    _requireNonEmpty(runSessionId, 'runSessionId');
    _requireNonEmpty(levelId, 'levelId');
    _requireNonEmpty(playerCharacterId, 'playerCharacterId');
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be positive');
    }
    if (totalTicks < 0) {
      throw ArgumentError.value(
        totalTicks,
        'totalTicks',
        'must be non-negative',
      );
    }
    if ((boardId == null) != (boardKey == null)) {
      throw ArgumentError(
        'boardId and boardKey must both be set or both be null.',
      );
    }
    if (!ReplayDigest.isValidSha256Hex(canonicalSha256)) {
      throw ArgumentError.value(
        canonicalSha256,
        'canonicalSha256',
        'must be a lower-case 64-char SHA-256 hex string.',
      );
    }
    if (boardId != null) {
      _requireNonEmpty(boardId!, 'boardId');
    }
    var previousTick = 0;
    for (final frame in commandStream) {
      if (frame.tick <= previousTick || frame.tick > totalTicks) {
        throw ArgumentError(
          'commandStream ticks must be strictly increasing and within totalTicks.',
        );
      }
      previousTick = frame.tick;
    }
  }

  final int replayVersion;
  final String runSessionId;
  final String? boardId;
  final BoardKey? boardKey;
  final int tickHz;
  final int seed;
  final String levelId;
  final String playerCharacterId;
  final Map<String, Object?> loadoutSnapshot;
  final int commandEncodingVersion;
  final int totalTicks;
  final List<ReplayCommandFrameV1> commandStream;
  final String canonicalSha256;
  final Map<String, Object?>? clientSummary;

  factory ReplayBlobV1.withComputedDigest({
    required String runSessionId,
    required int tickHz,
    required int seed,
    required String levelId,
    required String playerCharacterId,
    required Map<String, Object?> loadoutSnapshot,
    required int totalTicks,
    required List<ReplayCommandFrameV1> commandStream,
    String? boardId,
    BoardKey? boardKey,
    int commandEncodingVersion = kCommandEncodingVersion1,
    int replayVersion = kReplayBlobVersion1,
    Map<String, Object?>? clientSummary,
  }) {
    final payload = <String, Object?>{
      'replayVersion': replayVersion,
      'runSessionId': runSessionId,
      'boardId': ?boardId,
      'boardKey': ?boardKey?.toJson(),
      'tickHz': tickHz,
      'seed': seed,
      'levelId': levelId,
      'playerCharacterId': playerCharacterId,
      'loadoutSnapshot': loadoutSnapshot,
      'commandEncodingVersion': commandEncodingVersion,
      'totalTicks': totalTicks,
      'commandStream': commandStream
          .map((frame) => frame.toJson())
          .toList(growable: false),
      'clientSummary': ?clientSummary,
    };
    final digest = ReplayDigest.canonicalSha256ForMap(payload);
    return ReplayBlobV1(
      replayVersion: replayVersion,
      runSessionId: runSessionId,
      boardId: boardId,
      boardKey: boardKey,
      tickHz: tickHz,
      seed: seed,
      levelId: levelId,
      playerCharacterId: playerCharacterId,
      loadoutSnapshot: loadoutSnapshot,
      commandEncodingVersion: commandEncodingVersion,
      totalTicks: totalTicks,
      commandStream: commandStream,
      canonicalSha256: digest,
      clientSummary: clientSummary,
    );
  }

  factory ReplayBlobV1.fromJson(Object? raw, {bool verifyDigest = true}) {
    final json = asObjectMap(raw, fieldName: 'replayBlob');
    final replayVersion = readRequiredInt(json, 'replayVersion');
    final commandEncodingVersion = readRequiredInt(
      json,
      'commandEncodingVersion',
    );
    final tickHz = readRequiredInt(json, 'tickHz');
    final totalTicks = readRequiredInt(json, 'totalTicks');
    if (replayVersion != kReplayBlobVersion1) {
      throw FormatException('Unsupported replayVersion $replayVersion.');
    }
    if (commandEncodingVersion != kCommandEncodingVersion1) {
      throw FormatException(
        'Unsupported commandEncodingVersion $commandEncodingVersion.',
      );
    }
    if (tickHz <= 0) {
      throw const FormatException('tickHz must be positive.');
    }
    if (totalTicks < 0) {
      throw const FormatException('totalTicks must be non-negative.');
    }
    final commandStream = readRequiredList(
      json,
      'commandStream',
    ).map(ReplayCommandFrameV1.fromJson).toList(growable: false);
    var previousTick = 0;
    for (final frame in commandStream) {
      if (frame.tick <= previousTick) {
        throw const FormatException(
          'commandStream ticks must be strictly increasing.',
        );
      }
      if (frame.tick > totalTicks) {
        throw const FormatException(
          'commandStream frame tick exceeds totalTicks.',
        );
      }
      previousTick = frame.tick;
    }
    final blob = ReplayBlobV1(
      replayVersion: replayVersion,
      runSessionId: readRequiredString(json, 'runSessionId'),
      boardId: readOptionalString(json, 'boardId'),
      boardKey: json['boardKey'] == null
          ? null
          : BoardKey.fromJson(json['boardKey']),
      tickHz: tickHz,
      seed: readRequiredInt(json, 'seed'),
      levelId: readRequiredString(json, 'levelId'),
      playerCharacterId: readRequiredString(json, 'playerCharacterId'),
      loadoutSnapshot: readRequiredObject(json, 'loadoutSnapshot'),
      commandEncodingVersion: commandEncodingVersion,
      totalTicks: totalTicks,
      commandStream: commandStream,
      canonicalSha256: readRequiredString(json, 'canonicalSha256'),
      clientSummary: readOptionalObject(json, 'clientSummary'),
    );
    if (verifyDigest && !blob.hasValidDigest) {
      throw FormatException('canonicalSha256 does not match replay payload.');
    }
    return blob;
  }

  Map<String, Object?> toCanonicalPayloadJson() {
    return <String, Object?>{
      'replayVersion': replayVersion,
      'runSessionId': runSessionId,
      if (boardId != null) 'boardId': boardId,
      if (boardKey != null) 'boardKey': boardKey!.toJson(),
      'tickHz': tickHz,
      'seed': seed,
      'levelId': levelId,
      'playerCharacterId': playerCharacterId,
      'loadoutSnapshot': mutableJsonObjectCopy(
        loadoutSnapshot,
        fieldName: 'loadoutSnapshot',
      ),
      'commandEncodingVersion': commandEncodingVersion,
      'totalTicks': totalTicks,
      'commandStream': commandStream
          .map((frame) => frame.toJson())
          .toList(growable: false),
      if (clientSummary != null)
        'clientSummary': mutableJsonObjectCopy(
          clientSummary!,
          fieldName: 'clientSummary',
        ),
    };
  }

  bool get hasValidDigest {
    final expected = ReplayDigest.canonicalSha256ForMap(
      toCanonicalPayloadJson(),
    );
    return expected == canonicalSha256;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      ...toCanonicalPayloadJson(),
      'canonicalSha256': canonicalSha256,
    };
  }

  static void _requireNonEmpty(String value, String name) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, name, 'must be non-empty');
    }
  }
}
