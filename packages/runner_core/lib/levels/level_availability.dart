import 'level_id.dart';

/// A registered identity whose gameplay content is absent from this build.
///
/// Callers must surface availability or configuration failure. Substituting a
/// different identity would invalidate run-ticket, replay, and ghost contracts.
final class LevelUnavailableException implements Exception {
  const LevelUnavailableException(this.levelId);

  final LevelId levelId;

  @override
  String toString() =>
      'LevelUnavailableException: Level "${levelId.name}" is not included in this build.';
}
