import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../firebase_environment.dart';
import '../bootstrap/loader_content.dart';
import '../state/run/run_start_remote_exception.dart';
import 'run_start_preparation.dart';

/// A rejected new-run request never becomes playable by opening or canceling
/// the store. Account navigation and app-owned submission recovery remain live.
class RunReleaseGate extends StatefulWidget {
  const RunReleaseGate({
    required this.error,
    this.onRetry,
    this.storeUri,
    this.openUrl = _openExternal,
    super.key,
  });

  final RunStartRemoteException error;
  final VoidCallback? onRetry;
  final Uri? storeUri;
  final Future<bool> Function(Uri) openUrl;

  @override
  State<RunReleaseGate> createState() => _RunReleaseGateState();
}

Future<bool> _openExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class _RunReleaseGateState extends State<RunReleaseGate> {
  bool _opening = false;
  String? _linkError;

  Uri? get _storeUri {
    if (widget.storeUri != null) return widget.storeUri;
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        appFlavor == null) {
      return null;
    }
    final environment = FirebaseEnvironment.fromAndroidFlavor(appFlavor);
    return environment == FirebaseEnvironment.dev
        ? null
        : environment.playStoreUri;
  }

  Future<void> _open(Uri uri) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _linkError = null;
    });
    var opened = false;
    try {
      opened = await widget.openUrl(uri);
    } catch (_) {
      // Platform/browser failures must not authorize another run.
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (!opened) {
        _linkError = context.l10n.supportLinkFailed(
          email: 'lothringen.rpg@gmail.com',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.error.isUpdateRequired;
    final store = update ? _storeUri : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LoaderContent(
          errorTitle: update
              ? context.l10n.updateRequiredTitle
              : context.l10n.maintenanceTitle,
          errorMessage: RunStartPreparation.messageFor(
            widget.error,
            context.l10n,
          ),
          continueLabel: update
              ? context.l10n.openGooglePlay
              : context.l10n.bootstrapRetry,
          onContinue: _opening
              ? null
              : update
              ? (store == null ? null : () => _open(store))
              : widget.onRetry,
        ),
        if (update && store == null) Text(context.l10n.installCurrentBuild),
        if (_linkError != null) Text(_linkError!, textAlign: TextAlign.center),
        TextButton(
          onPressed: _opening
              ? null
              : () => _open(
                  Uri(scheme: 'mailto', path: 'lothringen.rpg@gmail.com'),
                ),
          child: Text(context.l10n.contactSupport),
        ),
      ],
    );
  }
}
