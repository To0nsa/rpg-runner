import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/ui_routes.dart';
import '../../bootstrap/loader_content.dart';
import '../../components/loader_shell.dart';
import '../../run/run_start_preparation.dart';
import '../../state/app/app_state.dart';

class RunStartBootstrapPage extends StatefulWidget {
  const RunStartBootstrapPage({required this.args, super.key});

  final RunStartBootstrapArgs args;

  @override
  State<RunStartBootstrapPage> createState() => _RunStartBootstrapPageState();
}

class _RunStartBootstrapPageState extends State<RunStartBootstrapPage> {
  late final RunStartPreparation _preparation;
  String? _navigationError;

  @override
  void initState() {
    super.initState();
    _preparation = RunStartPreparation(
      appState: context.read<AppState>(),
      request: widget.args,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepareAndNavigate();
    });
  }

  Future<void> _prepareAndNavigate() async {
    if (_preparation.inFlight) return;
    setState(() => _navigationError = null);
    final descriptor = await _preparation.prepare();
    if (!mounted || descriptor == null) return;
    try {
      await Navigator.of(context)
          .pushReplacementNamed(UiRoutes.run, arguments: descriptor);
    } catch (error) {
      if (mounted) {
        setState(
          () => _navigationError = RunStartPreparation.messageFor(error),
        );
      }
    }
  }

  @override
  void dispose() {
    _preparation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _preparation,
    builder: (context, _) => LoaderShell(
      scrollable: _preparation.error != null || _navigationError != null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoaderContent(
            loadingMessage: 'Preparing run...',
            errorMessage: _navigationError ?? _preparation.errorMessage,
            onContinue: _preparation.inFlight ? null : _prepareAndNavigate,
            continueLabel: _preparation.inFlight ? 'Retrying...' : 'Retry',
          ),
          if (Navigator.of(context).canPop())
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Exit'),
            ),
        ],
      ),
    ),
  );
}
