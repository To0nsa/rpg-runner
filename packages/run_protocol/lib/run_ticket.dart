import 'board_key.dart';
import 'codecs/json_value_copy.dart';
import 'codecs/json_value_reader.dart';
import 'run_mode.dart';

final class RunTicket {
  RunTicket({
    required this.runSessionId,
    required this.uid,
    required this.mode,
    required this.seed,
    required this.tickHz,
    required this.gameCompatVersion,
    required this.levelId,
    required this.playerCharacterId,
    required Map<String, Object?> loadoutSnapshot,
    required this.loadoutDigest,
    required this.issuedAtMs,
    required this.expiresAtMs,
    required this.singleUseNonce,
    this.boardId,
    this.boardKey,
    this.rulesetVersion,
    this.scoreVersion,
    this.ghostVersion,
    this.boardOpensAtMs,
    this.boardClosesAtMs,
  }) : loadoutSnapshot = immutableJsonObject(
         loadoutSnapshot,
         fieldName: 'loadoutSnapshot',
       ) {
    _requireNonEmpty(runSessionId, 'runSessionId');
    _requireNonEmpty(uid, 'uid');
    _requireNonEmpty(gameCompatVersion, 'gameCompatVersion');
    _requireNonEmpty(levelId, 'levelId');
    _requireNonEmpty(playerCharacterId, 'playerCharacterId');
    _requireNonEmpty(singleUseNonce, 'singleUseNonce');
    _requireNonEmpty(loadoutDigest, 'loadoutDigest');
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be positive');
    }
    if (expiresAtMs <= issuedAtMs) {
      throw ArgumentError.value(
        expiresAtMs,
        'expiresAtMs',
        'must be greater than issuedAtMs',
      );
    }
    if (mode.requiresBoard) {
      if (boardId == null ||
          boardKey == null ||
          rulesetVersion == null ||
          scoreVersion == null ||
          ghostVersion == null) {
        throw ArgumentError(
          'Competitive/Weekly tickets require board and version fields.',
        );
      }
      if ((boardOpensAtMs == null) != (boardClosesAtMs == null)) {
        throw ArgumentError(
          'Competitive/Weekly ticket board window must be complete when set.',
        );
      }
      if (boardClosesAtMs != null && boardClosesAtMs! <= boardOpensAtMs!) {
        throw ArgumentError(
          'Competitive/Weekly ticket board window must be increasing.',
        );
      }
      _requireNonEmpty(boardId!, 'boardId');
      _requireNonEmpty(rulesetVersion!, 'rulesetVersion');
      _requireNonEmpty(scoreVersion!, 'scoreVersion');
      _requireNonEmpty(ghostVersion!, 'ghostVersion');
      if (boardKey!.mode != mode || boardKey!.levelId != levelId) {
        throw ArgumentError(
          'Competitive/Weekly tickets must bind boardKey to their mode and levelId.',
        );
      }
      if (boardKey!.rulesetVersion != rulesetVersion ||
          boardKey!.scoreVersion != scoreVersion) {
        throw ArgumentError(
          'Competitive/Weekly ticket versions must match boardKey versions.',
        );
      }
    } else {
      if (boardId != null ||
          boardKey != null ||
          rulesetVersion != null ||
          scoreVersion != null ||
          ghostVersion != null ||
          boardOpensAtMs != null ||
          boardClosesAtMs != null) {
        throw ArgumentError(
          'Practice tickets must omit board, window, and board-version fields.',
        );
      }
    }
  }

  final String runSessionId;
  final String uid;
  final RunMode mode;
  final String? boardId;
  final BoardKey? boardKey;
  final int seed;
  final int tickHz;
  final String gameCompatVersion;
  final String? rulesetVersion;
  final String? scoreVersion;
  final String? ghostVersion;

  /// Immutable half-open board window captured at ranked ticket issuance.
  ///
  /// Both values are Unix epoch milliseconds. They are optional only when
  /// decoding legacy ranked tickets; new backend writers emit the pair.
  final int? boardOpensAtMs;
  final int? boardClosesAtMs;
  final String levelId;
  final String playerCharacterId;
  final Map<String, Object?> loadoutSnapshot;
  final String loadoutDigest;
  final int issuedAtMs;
  final int expiresAtMs;
  final String singleUseNonce;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'runSessionId': runSessionId,
      'uid': uid,
      'mode': mode.name,
      if (boardId != null) 'boardId': boardId,
      if (boardKey != null) 'boardKey': boardKey!.toJson(),
      'seed': seed,
      'tickHz': tickHz,
      'gameCompatVersion': gameCompatVersion,
      if (rulesetVersion != null) 'rulesetVersion': rulesetVersion,
      if (scoreVersion != null) 'scoreVersion': scoreVersion,
      if (ghostVersion != null) 'ghostVersion': ghostVersion,
      if (boardOpensAtMs != null) 'boardOpensAtMs': boardOpensAtMs,
      if (boardClosesAtMs != null) 'boardClosesAtMs': boardClosesAtMs,
      'levelId': levelId,
      'playerCharacterId': playerCharacterId,
      'loadoutSnapshot': mutableJsonObjectCopy(
        loadoutSnapshot,
        fieldName: 'loadoutSnapshot',
      ),
      'loadoutDigest': loadoutDigest,
      'issuedAtMs': issuedAtMs,
      'expiresAtMs': expiresAtMs,
      'singleUseNonce': singleUseNonce,
    };
  }

  factory RunTicket.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'runTicket');
    return RunTicket(
      runSessionId: readRequiredString(json, 'runSessionId'),
      uid: readRequiredString(json, 'uid'),
      mode: RunMode.parse(json['mode'], fieldName: 'mode'),
      boardId: readOptionalString(json, 'boardId'),
      boardKey: json['boardKey'] == null
          ? null
          : BoardKey.fromJson(json['boardKey']),
      seed: readRequiredInt(json, 'seed'),
      tickHz: readRequiredInt(json, 'tickHz'),
      gameCompatVersion: readRequiredString(json, 'gameCompatVersion'),
      rulesetVersion: readOptionalString(json, 'rulesetVersion'),
      scoreVersion: readOptionalString(json, 'scoreVersion'),
      ghostVersion: readOptionalString(json, 'ghostVersion'),
      boardOpensAtMs: readOptionalInt(json, 'boardOpensAtMs'),
      boardClosesAtMs: readOptionalInt(json, 'boardClosesAtMs'),
      levelId: readRequiredString(json, 'levelId'),
      playerCharacterId: readRequiredString(json, 'playerCharacterId'),
      loadoutSnapshot: readRequiredObject(json, 'loadoutSnapshot'),
      loadoutDigest: readRequiredString(json, 'loadoutDigest'),
      issuedAtMs: readRequiredInt(json, 'issuedAtMs'),
      expiresAtMs: readRequiredInt(json, 'expiresAtMs'),
      singleUseNonce: readRequiredString(json, 'singleUseNonce'),
    );
  }

  static void _requireNonEmpty(String value, String name) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, name, 'must be non-empty');
    }
  }
}
