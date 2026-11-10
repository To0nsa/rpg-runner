import '../l10n/app_localization.dart';
import '../state/ownership/selection_state.dart';

/// Existing saves reserve each slot's canonical default token. Only that token
/// is localized; custom names and persisted bytes are never rewritten.
String buildDisplayName(String storedName, int index, AppLocalizations l10n) =>
    storedName == SelectionState.defaultBuildName(index)
    ? l10n.defaultBuildName(number: index + 1)
    : storedName;
