import '../state/profile/user_profile_remote_api.dart';

String displayNameSaveErrorText(Object error) {
  if (error is UserProfileRemoteException) {
    final mapped = _mapRemoteException(error);
    if (mapped != null) {
      return mapped;
    }
  }

  final raw = '$error'.toLowerCase();
  if (raw.contains('already-exists') || raw.contains('already exists')) {
    return 'That name is already taken.';
  }
  return 'Could not save name. Please try again.';
}

String? _mapRemoteException(UserProfileRemoteException error) {
  if (error.isDuplicateDisplayName) {
    return 'That name is already taken.';
  }
  if (error.isUnauthorized) {
    return 'Session expired. Please restart the game and try again.';
  }
  if (error.isUnavailable) {
    return 'Could not reach the server. Check your connection and try again.';
  }
  if (error.isUnsupported) {
    return 'Name service is unavailable. Please try again later.';
  }
  if (error.isInvalidArgument) {
    final message = error.message?.trim();
    final normalized = message?.toLowerCase() ?? '';
    if (normalized.contains('at least')) {
      return _renameDisplayNameField(message);
    }
    if (normalized.contains('at most')) {
      return _renameDisplayNameField(message);
    }
    if (normalized.contains('unsupported characters')) {
      return 'Only letters, numbers, spaces, "_" and "-" are allowed.';
    }
    if (normalized.contains('reserved')) {
      return 'That name is reserved.';
    }
    if (normalized.contains('not allowed')) {
      return 'That name is not allowed.';
    }
    if (message != null && message.isNotEmpty) {
      return _renameDisplayNameField(message);
    }
  }

  final message = error.message?.trim();
  if (message != null && message.isNotEmpty) {
    return message;
  }
  return null;
}

String _renameDisplayNameField(String? message) {
  if (message == null || message.isEmpty) {
    return 'Could not save name. Please try again.';
  }
  return message.replaceFirst('displayName', 'Name');
}
