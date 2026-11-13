import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localization.dart';
import '../../state/app/app_state.dart';

/// Optimistic edits retain their build address; retry flushes that saved edit
/// instead of applying it to whichever build is selected afterwards.
Future<void> saveBuildChange(
  BuildContext context,
  Future<void> Function() save,
) async {
  try {
    await save();
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.characterBuildSaveFailed),
        action: SnackBarAction(
          label: context.l10n.uiRetry,
          onPressed: () => saveBuildChange(
            context,
            context.read<AppState>().ensureOwnershipSyncedBeforeRunStart,
          ),
        ),
      ),
    );
  }
}
