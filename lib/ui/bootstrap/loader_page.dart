import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/ui_routes.dart';
import '../components/menu_layout.dart';
import '../components/menu_scaffold.dart';
import '../state/app_state.dart';
import '../state/profile_flag_keys.dart';
import 'app_bootstrapper.dart';
import 'loader_content.dart';

class LoaderPage extends StatefulWidget {
  const LoaderPage({
    super.key,
    required this.args,
    this.bootstrapper = const AppBootstrapper(),
  });

  final LoaderArgs args;
  final AppBootstrapper bootstrapper;

  @override
  State<LoaderPage> createState() => _LoaderPageState();
}

class _LoaderPageState extends State<LoaderPage> {
  BootstrapResult? _result;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBootstrap();
    });
  }

  Future<void> _startBootstrap() async {
    if (_starting) return;
    _starting = true;
    final appState = context.read<AppState>();
    // Ensure the loading screen is visible for at least 2 seconds on cold start.
    // On resume, don't enforce an artificial minimum duration.
    final minWait =
        widget.args.isResume
            ? Future<void>.value()
            : Future<void>.delayed(const Duration(seconds: 2));
    final bootstrap = widget.bootstrapper.run(
      appState,
      force: widget.args.isResume,
    );

    final result = await bootstrap;
    await minWait;
    if (!mounted) return;
    setState(() {
      _result = result;
    });
    if (result.ok) {
      _complete();
    }
  }

  void _complete() {
    final navigator = Navigator.of(context);
    if (widget.args.isResume && navigator.canPop()) {
      navigator.pop();
      return;
    }

    final appState = context.read<AppState>();
    final completed =
        appState.profile.flags[ProfileFlagKeys.namePromptCompleted] == true;

    if (!widget.args.isResume && !completed) {
      navigator.pushReplacementNamed(UiRoutes.setupProfileName);
      return;
    }

    navigator.pushReplacementNamed(UiRoutes.hub);
  }

  void _continueWithDefaults() {
    final appState = context.read<AppState>();
    appState.applyDefaults();
    _complete();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _result != null && !_result!.ok;

    return MenuScaffold(
      showAppBar: false,
      child: MenuLayout(
        alignment: Alignment.center,
        scrollable: false,
        child: hasError
            ? LoaderContent(
                errorMessage: '${_result!.error}',
                onContinue: _continueWithDefaults,
              )
            : const LoaderContent(),
      ),
    );
  }
}
