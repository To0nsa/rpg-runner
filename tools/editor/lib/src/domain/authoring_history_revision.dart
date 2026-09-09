import 'dart:math' as math;

/// Reconciles an undo/redo value against the current source generation.
///
/// Returning to persisted content restores its current baseline revision so
/// unsaved edits can become clean. A different value advances from current
/// revisions; historical revision numbers are never inputs to this decision.
int reconcileAuthoringHistoryRevision({
  required int? currentRevision,
  required int? persistedRevision,
  required bool restoresPersistedContent,
  required bool preservesCurrentContent,
}) {
  if (persistedRevision != null && restoresPersistedContent) {
    return persistedRevision;
  }
  if (currentRevision != null && preservesCurrentContent) {
    return currentRevision;
  }
  return math.max(currentRevision ?? 0, persistedRevision ?? 0) + 1;
}
