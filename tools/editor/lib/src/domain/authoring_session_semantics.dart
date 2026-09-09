import 'authoring_types.dart';

/// Domain-owned distinction between content edits and session presentation.
///
/// Presentation commands must not change persisted values, revisions, or source
/// baselines. History restores content while retaining a still-valid selection.
abstract interface class AuthoringSessionSemantics {
  bool isPresentationCommand(AuthoringCommand command);

  AuthoringDocument retainPresentation({
    required AuthoringDocument current,
    required AuthoringDocument restored,
  });
}

/// Reconciles an ordinary undo target with the current persisted source baseline.
///
/// Implementations copy semantic content only, preserving current fingerprints,
/// dependency snapshots, and identity lifecycle fences. Revisions follow normal
/// domain edit policy. Returning null establishes a history boundary; returning
/// [current] unchanged means the historical step has no remaining content effect.
abstract interface class AuthoringHistoryReconciliation {
  AuthoringDocument? restoreContent({
    required AuthoringDocument current,
    required AuthoringDocument historical,
  });
}
