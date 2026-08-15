import '../domain/authoring_types.dart';
import 'entity_change_policy.dart';
import 'entity_domain_models.dart';

/// Typed payload for the only mutable entity operation in the current editor.
///
/// Collider values are always supplied as one complete group. Optional source-
/// backed values are present only when the caller intends to replace them.
final class EntityUpdate {
  const EntityUpdate({
    required this.entryId,
    required this.halfX,
    required this.halfY,
    required this.offsetX,
    required this.offsetY,
    this.renderScale,
    this.anchorXPx,
    this.anchorYPx,
    this.castOriginOffset,
  });

  static const String commandKind = 'update_entry';
  static const String _payloadKey = 'update';

  final String entryId;
  final double halfX;
  final double halfY;
  final double offsetX;
  final double offsetY;
  final double? renderScale;
  final double? anchorXPx;
  final double? anchorYPx;
  final double? castOriginOffset;

  AuthoringCommand toCommand() => AuthoringCommand(
    kind: commandKind,
    payload: <String, Object?>{_payloadKey: this},
  );

  /// Decodes a known entity-update command or fails fast on programmer error.
  ///
  /// Unknown command kinds return null so the plugin can preserve its normal
  /// no-op behavior for commands owned by another domain/version.
  static EntityUpdate? decode(AuthoringCommand command) {
    if (command.kind != commandKind) return null;
    if (command.payload.length != 1 ||
        command.payload[_payloadKey] is! EntityUpdate) {
      throw ArgumentError.value(
        command.payload,
        'command.payload',
        'Entity update commands require one typed EntityUpdate payload.',
      );
    }
    return command.payload[_payloadKey]! as EntityUpdate;
  }

  /// Validates values and source writability against the selected entry.
  void validateFor(EntityEntry entry) {
    if (entryId.trim().isEmpty || entry.id != entryId) {
      throw ArgumentError.value(
        entryId,
        'entryId',
        'Entity update target does not match the selected entry.',
      );
    }
    final values = <String, double>{
      'halfX': halfX,
      'halfY': halfY,
      'offsetX': offsetX,
      'offsetY': offsetY,
    };
    if (renderScale != null) values['renderScale'] = renderScale!;
    if (anchorXPx != null) values['anchorXPx'] = anchorXPx!;
    if (anchorYPx != null) values['anchorYPx'] = anchorYPx!;
    if (castOriginOffset != null) {
      values['castOriginOffset'] = castOriginOffset!;
    }
    for (final value in values.entries) {
      if (!value.value.isFinite) {
        throw ArgumentError.value(
          value.value,
          value.key,
          'Entity update values must be finite.',
        );
      }
    }

    final anchorPairIsComplete =
        (anchorXPx == null && anchorYPx == null) ||
        (anchorXPx != null && anchorYPx != null);
    if (!anchorPairIsComplete) {
      throw ArgumentError(
        'Entity update anchorXPx and anchorYPx must be supplied together.',
      );
    }

    final bindings = entry.colliderBindings;
    if (bindings.offsetX == null &&
        !EntityNumericPolicy.equal(offsetX, entry.offsetX)) {
      throw ArgumentError('Entity ${entry.id} has no writable offsetX source.');
    }
    if (bindings.offsetY == null &&
        !EntityNumericPolicy.equal(offsetY, entry.offsetY)) {
      throw ArgumentError('Entity ${entry.id} has no writable offsetY source.');
    }

    final reference = entry.referenceVisual;
    if (renderScale != null && reference?.renderScaleBinding == null) {
      throw ArgumentError(
        'Entity ${entry.id} has no writable renderScale source.',
      );
    }
    if (anchorXPx != null && reference?.hasWritableAnchorPoint != true) {
      throw ArgumentError(
        'Entity ${entry.id} has no writable anchorPoint source.',
      );
    }
    if (castOriginOffset != null && entry.castOriginOffsetBinding == null) {
      throw ArgumentError(
        'Entity ${entry.id} has no writable castOriginOffset source.',
      );
    }
  }
}
