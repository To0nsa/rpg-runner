import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/ui_routes.dart';
import '../components/menu_layout.dart';
import '../components/menu_scaffold.dart';
import '../state/app_state.dart';
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
  bool _bootstrapInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startBootstrap(enforceMinimumDuration: true));
    });
  }

  Future<void> _startBootstrap({required bool enforceMinimumDuration}) async {
    if (_bootstrapInFlight) return;
    _bootstrapInFlight = true;
    if (mounted) {
      setState(() {
        _result = null;
      });
    }
    final appState = context.read<AppState>();
    // Ensure the loading screen is visible for at least 2 seconds on cold start.
    // On resume, don't enforce an artificial minimum duration.
    final minWait = !enforceMinimumDuration || widget.args.isResume
        ? Future<void>.value()
        : Future<void>.delayed(const Duration(seconds: 2));
    try {
      final result = await widget.bootstrapper.run(
        appState,
        force: widget.args.isResume,
      );
      await minWait;
      if (!mounted) return;
      setState(() {
        _result = result;
      });
      if (result.ok) {
        _complete();
      }
    } finally {
      _bootstrapInFlight = false;
    }
  }

  void _complete() {
    final navigator = Navigator.of(context);
    if (widget.args.isResume && navigator.canPop()) {
      navigator.pop();
      return;
    }

    final appState = context.read<AppState>();
    final completed = appState.profile.namePromptCompleted;

    if (!widget.args.isResume && !completed) {
      navigator.pushReplacementNamed(UiRoutes.setupProfileName);
      return;
    }

    navigator.pushReplacementNamed(UiRoutes.hub);
  }

  Future<void> _retryBootstrap() async {
    await _startBootstrap(enforceMinimumDuration: false);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _result != null && !_result!.ok;

    return MenuScaffold(
      showAppBar: false,
      useBodySafeArea: false,
      background: Image.asset(
        'assets/images/backgrounds/loader_bg.png',
        fit: BoxFit.fitWidth,
        alignment: Alignment.bottomCenter,
      ),
      child: MenuLayout(
        alignment: Alignment.center,
        scrollable: hasError,
        maxWidth: double.infinity,
        horizontalPadding: 0,
        child: hasError
            ? LoaderContent(
                errorMessage: '${_result!.error}',
                continueLabel: 'Retry Play Games sign-in',
                onContinue: _bootstrapInFlight
                    ? null
                    : () => unawaited(_retryBootstrap()),
              )
            : const LoaderContent(),
      ),
    );
  }
}
