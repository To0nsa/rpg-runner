import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/ui_routes.dart';
import '../components/menu_layout.dart';
import '../components/menu_scaffold.dart';
import '../state/app_state.dart';
import 'app_bootstrapper.dart';

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
    final result = await widget.bootstrapper.run(
      appState,
      force: widget.args.isResume,
    );
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'rpg-runner',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            if (!hasError) ...[
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'Loading...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
            if (hasError) ...[
              const Text(
                'Bootstrap failed',
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '${_result!.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _continueWithDefaults,
                child: const Text('Continue with defaults'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
