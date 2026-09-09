import 'authoring_types.dart';

/// Explicit resolution of one field edited both on disk and in this session.
enum AuthoringConflictChoice { saved, intended }

final class AuthoringIntentConflict {
  const AuthoringIntentConflict({
    required this.path,
    required this.savedValue,
    required this.intendedValue,
    this.canUseIntended = true,
  });

  final String path;
  final Object? savedValue;
  final Object? intendedValue;
  final bool canUseIntended;
}

/// A domain's semantic edits against freshly loaded sources, never a byte patch.
final class AuthoringReapplyPlan {
  const AuthoringReapplyPlan({
    required this.commands,
    required this.conflicts,
    required this.unresolvedPaths,
  });

  final List<AuthoringCommand> commands;
  final List<AuthoringIntentConflict> conflicts;
  final Set<String> unresolvedPaths;
}

/// Bounded source-drift and dependency-repair capability owned by the domain.
abstract interface class AuthoringIntentReconciliation {
  AuthoringReapplyPlan planReapply({
    required AuthoringDocument current,
    required AuthoringDocument original,
    required Map<String, AuthoringConflictChoice> resolutions,
  });
}

/// Three-way merge of semantic values. Lists remain atomic so competing changes
/// to ordering or membership require an explicit choice rather than guessing.
final class AuthoringIntentMerger {
  AuthoringIntentMerger(this.resolutions);

  final Map<String, AuthoringConflictChoice> resolutions;
  final List<AuthoringIntentConflict> conflicts = [];
  final Set<String> unresolvedPaths = {};

  Object? merge(
    String path,
    Object? baseline,
    Object? saved,
    Object? intended,
  ) {
    if (_valuesEqual(baseline, intended)) return saved;
    if (_valuesEqual(saved, intended) || _valuesEqual(saved, baseline)) {
      return intended;
    }
    if (baseline is Map<String, Object?> &&
        saved is Map<String, Object?> &&
        intended is Map<String, Object?>) {
      return <String, Object?>{
        for (final key in {...baseline.keys, ...saved.keys, ...intended.keys})
          key: merge('$path/$key', baseline[key], saved[key], intended[key]),
      };
    }
    return conflict(path, saved, intended);
  }

  Object? conflict(
    String path,
    Object? saved,
    Object? intended, {
    bool canUseIntended = true,
  }) {
    conflicts.add(
      AuthoringIntentConflict(
        path: path,
        savedValue: saved,
        intendedValue: intended,
        canUseIntended: canUseIntended,
      ),
    );
    final choice = resolutions[path];
    if (choice == null ||
        (choice == AuthoringConflictChoice.intended && !canUseIntended)) {
      unresolvedPaths.add(path);
    }
    return choice == AuthoringConflictChoice.intended && canUseIntended
        ? intended
        : saved;
  }
}

// Values here are the domains' JSON-compatible semantic trees.
bool _valuesEqual(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every(
          (key) => b.containsKey(key) && _valuesEqual(a[key], b[key]),
        );
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        Iterable<int>.generate(a.length)
            .every((index) => _valuesEqual(a[index], b[index]));
  }
  return a == b;
}
