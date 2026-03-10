import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

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
    LoadoutOwnershipApi? fallbackApi,
    MetaService? metaService,
  }) : _source = source ?? PluginFirebaseLoadoutOwnershipSource(),
       _fallbackApi = fallbackApi,
       _metaService = metaService ?? const MetaService();

  final FirebaseLoadoutOwnershipSource _source;
  final LoadoutOwnershipApi? _fallbackApi;
  final MetaService _metaService;

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String profileId,
    required String userId,
    required String sessionId,
  }) async {
    final fallbackCanonical = _fallbackCanonical(profileId);
    try {
      final response = await _source.loadCanonicalState(
        profileId: profileId,
        userId: userId,
        sessionId: sessionId,
      );
      return _decodeCanonicalState(
        response,
        fallbackCanonical: fallbackCanonical,
      );
    } catch (error) {
      debugPrint('Firebase ownership canonical load failed: $error');
      final fallbackApi = _fallbackApi;
      if (fallbackApi != null) {
        return fallbackApi.loadCanonicalState(
          profileId: profileId,
          userId: userId,
          sessionId: sessionId,
        );
      }
      return fallbackCanonical;
    }
  }

  @override
  Future<OwnershipCommandResult> setSelection(SetSelectionCommand command) {
    return _executeCommand(
      command,
      fallbackInvoke: (api) => api.setSelection(command),
    );
  }

  @override
  Future<OwnershipCommandResult> resetOwnership(ResetOwnershipCommand command) {
    return _executeCommand(
      command,
      fallbackInvoke: (api) => api.resetOwnership(command),
    );
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) {
    return _executeCommand(
      command,
      fallbackInvoke: (api) => api.equipGear(command),
    );
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) {
    return _executeCommand(
      command,
      fallbackInvoke: (api) => api.setLoadout(command),
    );
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(SetAbilitySlotCommand command) {
    return _executeCommand(
      command,
      fallbackInvoke: (api) => api.setAbilitySlot(command),
    );
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) {
    return _executeCommand(
      command,
      fallbackInvoke: (api) => api.setProjectileSpell(command),
    );
  }

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) {
    return _executeCommand(
      command,
      fallbackInvoke: (api) => api.learnProjectileSpell(command),
    );
  }

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) {
    return _executeCommand(
      command,
      fallbackInvoke: (api) => api.learnSpellAbility(command),
    );
  }

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) {
    return _executeCommand(
      command,
      fallbackInvoke: (api) => api.unlockGear(command),
    );
  }

  Future<OwnershipCommandResult> _executeCommand(
    OwnershipCommand command, {
    required Future<OwnershipCommandResult> Function(LoadoutOwnershipApi api)
    fallbackInvoke,
  }) async {
    final fallbackCanonical = _fallbackCanonical(command.profileId);
    try {
      final response = await _source.executeCommand(command: command);
      return _decodeCommandResult(
        response,
        fallbackCanonical: fallbackCanonical,
      );
    } catch (error) {
      debugPrint(
        'Firebase ownership command failed: ${command.type} '
        'profile=${command.profileId} error=$error',
      );
      final fallbackApi = _fallbackApi;
      if (fallbackApi != null) {
        return fallbackInvoke(fallbackApi);
      }
      return OwnershipCommandResult(
        canonicalState: fallbackCanonical,
        newRevision: fallbackCanonical.revision,
        replayedFromIdempotency: false,
        rejectedReason: _mapRejectedReason(error),
      );
    }
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

  OwnershipRejectedReason _mapRejectedReason(Object error) {
    if (error is FirebaseFunctionsException) {
      return switch (error.code) {
        'unauthenticated' => OwnershipRejectedReason.unauthorized,
        'permission-denied' => OwnershipRejectedReason.forbidden,
        'invalid-argument' => OwnershipRejectedReason.invalidCommand,
        'aborted' => OwnershipRejectedReason.staleRevision,
        'already-exists' => OwnershipRejectedReason.idempotencyKeyReuseMismatch,
        _ => OwnershipRejectedReason.forbidden,
      };
    }
    return OwnershipRejectedReason.forbidden;
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
