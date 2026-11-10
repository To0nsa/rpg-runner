import '../l10n/app_localization.dart';
import '../state/profile/user_profile_remote_api.dart';
import 'display_name_policy.dart';

/// Known wire failures map to local recovery text; server diagnostics remain private.
String displayNameSaveErrorText(Object error, AppLocalizations l10n) {
  if (error is UserProfileRemoteException) {
    if (error.isDuplicateDisplayName) return l10n.nameTaken;
    if (error.isUnauthorized) {
      return l10n.uiSessionExpiredPleaseRestartTheGameAndTryAgain;
    }
    if (error.isUnavailable) return l10n.nameServerUnavailable;
    if (error.isUnsupported) return l10n.nameServiceUnavailable;
    if (error.isInvalidArgument) {
      // Legacy responses have no structured validation reason. Classify known
      // diagnostics, but never show their text or interpolate server values.
      final message = error.message?.toLowerCase() ?? '';
      if (message.contains('at least')) {
        return l10n.nameTooShort(min: DisplayNamePolicy.minLen);
      }
      if (message.contains('at most')) {
        return l10n.nameTooLong(max: DisplayNamePolicy.maxLen);
      }
      if (message.contains('unsupported characters')) {
        return l10n.nameCharacters;
      }
      if (message.contains('reserved')) return l10n.nameReserved;
      if (message.contains('not allowed')) return l10n.nameDisallowed;
      return l10n.nameInvalid;
    }
  }
  return l10n.nameSaveFailed;
}
