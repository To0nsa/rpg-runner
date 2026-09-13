import '../../../domain/authoring_types.dart';

/// A route's immutable view location, never a retained content document or draft.
///
/// The shell captures this after resolving pending input and restores it against
/// freshly loaded sources. Pages validate local selections on mount; domains
/// whose selection lives in the session restore it through plugin commands.
abstract class EditorPageLocation {
  const EditorPageLocation();

  /// Reapplies only supported selection commands to a fresh document.
  /// Missing owners fall back to the destination's normal selection rules.
  AuthoringDocument restoreDocumentSelection(
    AuthoringDomainPlugin plugin,
    AuthoringDocument document,
  ) => document;
}

/// Implemented by every shell route, including wrappers around workspaces.
abstract interface class EditorPageNavigationState {
  EditorPageLocation? get navigationLocation;
}
