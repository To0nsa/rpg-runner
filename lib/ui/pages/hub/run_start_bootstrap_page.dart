import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/ui_routes.dart';
import '../../assets/ui_asset_lifecycle.dart';
import '../../bootstrap/loader_content.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app_state.dart';
import '../../state/run_start_remote_exception.dart';

class RunStartBootstrapPage extends StatefulWidget {
  const RunStartBootstrapPage({
    required this.args,
    super.key,
  });

  final RunStartBootstrapArgs args;

  @override
  State<RunStartBootstrapPage> createState() => _RunStartBootstrapPageState();
}

class _RunStartBootstrapPageState extends State<RunStartBootstrapPage> {
  bool _inFlight = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prepareAndNavigate();
    });
  }

  Future<void> _prepareAndNavigate() async {
    if (_inFlight) return;
    setState(() {
      _inFlight = true;
      _errorMessage = null;
    });

    try {
      final appState = context.read<AppState>();
      final lifecycle = context.read<UiAssetLifecycle>();
      final descriptor = await appState.prepareRunStartDescriptor(
        expectedMode: widget.args.expectedMode,
        expectedLevelId: widget.args.expectedLevelId,
        ghostEntryId: widget.args.ghostEntryId,
      );
      if (!mounted) return;
      await lifecycle.warmRunStartAssets(
        levelId: descriptor.levelId,
        characterId: descriptor.playerCharacterId,
        context: context,
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      await navigator.pushReplacementNamed(
        UiRoutes.run,
        arguments: descriptor,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFor(error);
      });
    } finally {
      if (mounted) {
        setState(() => _inFlight = false);
      }
    }
  }

  String _messageFor(Object error) {
    if (error is RunStartRemoteException && error.isPreconditionFailed) {
      return 'Run start requirements changed. Return to hub and try again.';
    }
    return 'Unable to start run right now. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;
    final hasError = errorMessage != null;
    return MenuScaffold(
      showAppBar: false,
      child: MenuLayout(
        alignment: Alignment.center,
        scrollable: hasError,
        child: LoaderContent(
          loadingMessage: 'Preparing run...',
          errorMessage: errorMessage,
          onContinue: _inFlight ? null : () => _prepareAndNavigate(),
          continueLabel: _inFlight ? 'Retrying...' : 'Retry',
        ),
      ),
    );
  }
}
