import 'board_key.dart';
import 'codecs/json_value_reader.dart';
import 'replay_digest.dart';

const int kReplayBlobVersion1 = 1;
const int kCommandEncodingVersion1 = 1;

final class ReplayCommandFrameV1 {
  const ReplayCommandFrameV1({
    required this.tick,
    this.moveAxis,
    this.aimDirX,
    this.aimDirY,
    this.pressedMask = 0,
    this.abilitySlotHeldChangedMask = 0,
    this.abilitySlotHeldValueMask = 0,
  }) : assert(tick > 0, 'tick must be > 0'),
       assert(
         (aimDirX == null && aimDirY == null) ||
             (aimDirX != null && aimDirY != null),
         'aimDirX and aimDirY must be both set or both unset.',
       ),
       assert(
         (abilitySlotHeldValueMask & ~abilitySlotHeldChangedMask) == 0,
         'abilitySlotHeldValueMask cannot set bits outside abilitySlotHeldChangedMask.',
       );

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
    return ReplayCommandFrameV1(
      tick: readRequiredInt(json, 't'),
      moveAxis: readOptionalDouble(json, 'mx'),
      aimDirX: readOptionalDouble(json, 'ax'),
      aimDirY: readOptionalDouble(json, 'ay'),
      pressedMask: readOptionalInt(json, 'pm') ?? 0,
      abilitySlotHeldChangedMask: readOptionalInt(json, 'hm') ?? 0,
      abilitySlotHeldValueMask: readOptionalInt(json, 'hv') ?? 0,
    );
  }
}

final class ReplayBlobV1 {
  ReplayBlobV1({
    required this.runSessionId,
    required this.tickHz,
    required this.seed,
    required this.levelId,
    required this.playerCharacterId,
    required this.loadoutSnapshot,
    required this.totalTicks,
    required this.commandStream,
    required this.canonicalSha256,
    this.boardId,
    this.boardKey,
    this.commandEncodingVersion = kCommandEncodingVersion1,
    this.replayVersion = kReplayBlobVersion1,
    this.clientSummary,
  }) : assert(replayVersion == kReplayBlobVersion1, 'Unsupported replayVersion'),
       assert(tickHz > 0, 'tickHz must be > 0'),
       assert(totalTicks >= 0, 'totalTicks must be >= 0') {
    if ((boardId == null) != (boardKey == null)) {
      throw ArgumentError('boardId and boardKey must both be set or both be null.');
    }
    if (!ReplayDigest.isValidSha256Hex(canonicalSha256)) {
      throw ArgumentError.value(
        canonicalSha256,
        'canonicalSha256',
        'must be a lower-case 64-char SHA-256 hex string.',
      );
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
      'boardId':? boardId,
      'boardKey':? boardKey?.toJson(),
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
      'clientSummary':? clientSummary,
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
      commandStream: List<ReplayCommandFrameV1>.unmodifiable(commandStream),
      canonicalSha256: digest,
      clientSummary: clientSummary,
    );
  }

  factory ReplayBlobV1.fromJson(Object? raw, {bool verifyDigest = true}) {
    final json = asObjectMap(raw, fieldName: 'replayBlob');
    final blob = ReplayBlobV1(
      replayVersion: readRequiredInt(json, 'replayVersion'),
      runSessionId: readRequiredString(json, 'runSessionId'),
      boardId: readOptionalString(json, 'boardId'),
      boardKey: json['boardKey'] == null ? null : BoardKey.fromJson(json['boardKey']),
      tickHz: readRequiredInt(json, 'tickHz'),
      seed: readRequiredInt(json, 'seed'),
      levelId: readRequiredString(json, 'levelId'),
      playerCharacterId: readRequiredString(json, 'playerCharacterId'),
      loadoutSnapshot: readRequiredObject(json, 'loadoutSnapshot'),
      commandEncodingVersion: readRequiredInt(json, 'commandEncodingVersion'),
      totalTicks: readRequiredInt(json, 'totalTicks'),
      commandStream: readRequiredList(json, 'commandStream')
          .map(ReplayCommandFrameV1.fromJson)
          .toList(growable: false),
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
      'loadoutSnapshot': loadoutSnapshot,
      'commandEncodingVersion': commandEncodingVersion,
      'totalTicks': totalTicks,
      'commandStream': commandStream
          .map((frame) => frame.toJson())
          .toList(growable: false),
      if (clientSummary != null) 'clientSummary': clientSummary,
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
}
