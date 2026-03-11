import 'package:cloud_functions/cloud_functions.dart';

import '../../core/meta/meta_service.dart';
import 'loadout_ownership_api.dart';
import 'selection_state.dart';

/// Firebase-backed [LoadoutOwnershipApi] adapter for server-authoritative
/// ownership and loadout commands.
///
/// This adapter keeps the same command envelope and canonical response contract
/// used by the local ownership adapter, so `AppState` remains transport-agnostic.
class FirebaseLoadoutOwnershipApi implements LoadoutOwnershipApi {
  FirebaseLoadoutOwnershipApi({
    FirebaseLoadoutOwnershipSource? source,
    MetaService? metaService,
  }) : _source = source ?? PluginFirebaseLoadoutOwnershipSource(),
       _metaService = metaService ?? const MetaService();

  final FirebaseLoadoutOwnershipSource _source;
  final MetaService _metaService;

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String profileId,
    required String userId,
    required String sessionId,
  }) async {
    final fallbackCanonical = _fallbackCanonical(profileId);
    final response = await _source.loadCanonicalState(
      profileId: profileId,
      userId: userId,
      sessionId: sessionId,
    );
    return _decodeCanonicalState(
      response,
      fallbackCanonical: fallbackCanonical,
    );
  }

  @override
  Future<OwnershipCommandResult> setSelection(SetSelectionCommand command) {
    return _executeCommand(command);
  }

  @override
  Future<OwnershipCommandResult> resetOwnership(ResetOwnershipCommand command) {
    return _executeCommand(command);
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) {
    return _executeCommand(command);
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) {
    return _executeCommand(command);
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(SetAbilitySlotCommand command) {
    return _executeCommand(command);
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) {
    return _executeCommand(command);
  }

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) {
    return _executeCommand(command);
  }

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) {
    return _executeCommand(command);
  }

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) {
    return _executeCommand(command);
  }

  Future<OwnershipCommandResult> _executeCommand(
    OwnershipCommand command,
  ) async {
    final fallbackCanonical = _fallbackCanonical(command.profileId);
    final response = await _source.executeCommand(command: command);
    return _decodeCommandResult(response, fallbackCanonical: fallbackCanonical);
  }

  OwnershipCanonicalState _fallbackCanonical(String profileId) {
    return OwnershipCanonicalState(
      profileId: profileId,
      revision: 0,
      selection: SelectionState.defaults,
      meta: _metaService.createNew(),
    );
  }

  OwnershipCanonicalState _decodeCanonicalState(
    Map<String, dynamic> response, {
    required OwnershipCanonicalState fallbackCanonical,
  }) {
    final wrapped = response['canonicalState'];
    if (wrapped is Map<String, dynamic>) {
      return OwnershipCanonicalState.fromJson(
        wrapped,
        fallback: fallbackCanonical,
      );
    }
    if (wrapped is Map) {
      return OwnershipCanonicalState.fromJson(
        Map<String, dynamic>.from(wrapped),
        fallback: fallbackCanonical,
      );
    }
    return OwnershipCanonicalState.fromJson(
      response,
      fallback: fallbackCanonical,
    );
  }

  OwnershipCommandResult _decodeCommandResult(
    Map<String, dynamic> response, {
    required OwnershipCanonicalState fallbackCanonical,
  }) {
    final wrapped = response['result'];
    if (wrapped is Map<String, dynamic>) {
      return OwnershipCommandResult.fromJson(
        wrapped,
        fallbackCanonicalState: fallbackCanonical,
      );
    }
    if (wrapped is Map) {
      return OwnershipCommandResult.fromJson(
        Map<String, dynamic>.from(wrapped),
        fallbackCanonicalState: fallbackCanonical,
      );
    }
    return OwnershipCommandResult.fromJson(
      response,
      fallbackCanonicalState: fallbackCanonical,
    );
  }
}

/// Transport abstraction for Firebase ownership callable invocations.
abstract class FirebaseLoadoutOwnershipSource {
  Future<Map<String, dynamic>> loadCanonicalState({
    required String profileId,
    required String userId,
    required String sessionId,
  });

  Future<Map<String, dynamic>> executeCommand({
    required OwnershipCommand command,
  });
}

/// Production callable source backed by `package:cloud_functions`.
class PluginFirebaseLoadoutOwnershipSource
    implements FirebaseLoadoutOwnershipSource {
  PluginFirebaseLoadoutOwnershipSource({
    FirebaseFunctions? functions,
    this.loadCanonicalCallableName = 'loadoutOwnershipLoadCanonicalState',
    this.executeCommandCallableName = 'loadoutOwnershipExecuteCommand',
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final String loadCanonicalCallableName;
  final String executeCommandCallableName;

  @override
  Future<Map<String, dynamic>> loadCanonicalState({
    required String profileId,
    required String userId,
    required String sessionId,
  }) async {
    final callable = _functions.httpsCallable(loadCanonicalCallableName);
    final result = await callable.call(<String, Object?>{
      'profileId': profileId,
      'userId': userId,
      'sessionId': sessionId,
    });
    return _decodeMap(result.data);
  }

  @override
  Future<Map<String, dynamic>> executeCommand({
    required OwnershipCommand command,
  }) async {
    final callable = _functions.httpsCallable(executeCommandCallableName);
    final result = await callable.call(<String, Object?>{
      'command': command.toJson(),
    });
    return _decodeMap(result.data);
  }

  Map<String, dynamic> _decodeMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw FormatException(
      'Firebase ownership callable returned non-map payload: '
      '${raw.runtimeType}',
    );
  }
}
