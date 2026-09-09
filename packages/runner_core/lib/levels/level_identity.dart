import 'level_id.dart';

/// Level provenance carried by simulation snapshots without granting run access.
sealed class LevelIdentity {
  const LevelIdentity();

  /// Stable authored name; equal names do not erase registered/tooling provenance.
  String get value;

  /// Resolves a production identity, rejecting an authored tooling scenario.
  LevelId requireRegisteredId() => switch (this) {
    RegisteredLevelIdentity(:final id) => id,
    AuthoredLevelIdentity() => throw StateError(
      'Authored level "$value" is available only through playtest construction.',
    ),
  };
}

/// Protocol-stable game identity admitted by normal run construction.
final class RegisteredLevelIdentity extends LevelIdentity {
  const RegisteredLevelIdentity(this.id);

  final LevelId id;

  @override
  String get value => id.name;

  @override
  bool operator ==(Object other) =>
      other is RegisteredLevelIdentity && other.id == id;

  @override
  int get hashCode => Object.hash(RegisteredLevelIdentity, id);

  @override
  String toString() => 'registered:$value';
}

/// Current authoring identity, including levels absent from generated enums.
final class AuthoredLevelIdentity extends LevelIdentity {
  factory AuthoredLevelIdentity(String value) {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value)) {
      throw ArgumentError.value(value, 'value', 'Expected a stable level ID.');
    }
    return AuthoredLevelIdentity._(value);
  }

  const AuthoredLevelIdentity._(this.value);

  @override
  final String value;

  @override
  bool operator ==(Object other) =>
      other is AuthoredLevelIdentity && other.value == value;

  @override
  int get hashCode => Object.hash(AuthoredLevelIdentity, value);

  @override
  String toString() => 'authored:$value';
}
