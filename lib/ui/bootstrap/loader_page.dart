import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/ui_routes.dart';
import '../components/loader_shell.dart';
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
  Timer? _minimumTimer;
  Completer<void>? _minimumDuration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startBootstrap(enforceMinimumDuration: true));
    });
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    final minimum = _minimumDuration;
    if (minimum != null && !minimum.isCompleted) minimum.complete();
    super.dispose();
  }

  Future<void> _startMinimumDuration() {
    final minimum = Completer<void>();
    _minimumDuration = minimum;
    _minimumTimer = Timer(const Duration(seconds: 2), minimum.complete);
    return minimum.future;
  }

  Future<void> _startBootstrap({required bool enforceMinimumDuration}) async {
    if (!mounted || _bootstrapInFlight) return;
    _bootstrapInFlight = true;
    setState(() => _result = null);
    final services = context.read<AppServices>();
    // Ensure the loading screen is visible for at least 2 seconds on cold start.
    // On resume, don't enforce an artificial minimum duration.
    final minWait = !enforceMinimumDuration || widget.args.isResume
        ? Future<void>.value()
        : _startMinimumDuration();
    try {
      final result = await widget.bootstrapper.run(
        services,
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

    final appState = context.read<AppServices>().appState;
    final completed = appState.profile.namePromptCompleted;

    if (!widget.args.isResume && !completed) {
      navigator.pushReplacementNamed(UiRoutes.setupProfileName);
      return;
    }

    navigator.pushReplacementNamed(UiRoutes.hub);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _result != null && !_result!.ok;

    return PopScope(
      // A resume refresh is a gate; only successful completion may dismiss it.
      canPop: !widget.args.isResume,
      child: LoaderShell(
        scrollable: hasError,
        child: hasError
            ? LoaderContent(
                errorTitle: _result!.errorTitle,
                errorMessage: _result!.errorMessage,
                continueLabel: _result!.retryLabel,
                onContinue: _bootstrapInFlight
                    ? null
                    : () => unawaited(
                        _startBootstrap(enforceMinimumDuration: false),
                      ),
              )
            : const LoaderContent(),
      ),
    );
  }
}
