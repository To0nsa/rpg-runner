import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tool_ui/tool_ui.dart';

import 'src/admin_controller.dart';
import 'src/admin_draft.dart';
import 'src/admin_page.dart';
import 'src/admin_service.dart';
import 'src/repository_assets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: 'Lothringen Admin',
      debugShowCheckedModeBanner: false,
      theme: createToolTheme(),
      home: const _Bootstrap(),
    ),
  );
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  AdminController? _controller;
  LocalAdminService? _service;
  RandomAccessFile? _lock;
  String? _repository, _error;
  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      const fixture = bool.fromEnvironment('ADMIN_FIXTURE');
      final repository = _findRepository();
      final appData = Platform.environment['APPDATA'];
      if (appData == null) {
        throw StateError(
          'APPDATA is unavailable. Start Admin in your Windows user session.',
        );
      }
      final directory = Directory(
        '$appData/Lothringen/admin${fixture ? '-fixture' : ''}',
      );
      await directory.create(recursive: true);
      final lock = await File('${directory.path}/session.lock')
          .open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.exclusive);
      } catch (_) {
        await lock.close();
        throw StateError('Admin is already open. Use its existing window.');
      }
      _lock = lock;
      final service = await LocalAdminService.start(
        repository,
        fixture: fixture,
      );
      _service = service;
      final controller = AdminController(
        service: service,
        store: FileAdminDraftStore(File('${directory.path}/draft.json')),
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        await _close();
        return;
      }
      setState(() {
        _repository = repository;
        _controller = controller;
      });
    } catch (failure) {
      await _close();
      if (mounted) setState(() => _error = 'Could not start Admin.\n$failure');
    }
  }

  Future<void> _close() async {
    final service = _service;
    _service = null;
    final lock = _lock;
    _lock = null;
    try {
      await service?.close();
    } finally {
      await lock?.close();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    unawaited(_close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller case final controller?) {
      return DefaultAssetBundle(
        bundle: RepositoryAssets(_repository!),
        child: AdminPage(controller: controller),
      );
    }
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lothringen Admin',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 20),
                      SelectableText(_error!),
                      const SizedBox(height: 20),
                      const SelectableText(
                        'From the repository: corepack pnpm admin:login\nThen start: corepack pnpm admin',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _start,
                        child: const Text('Retry startup'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Source, service and artwork must come from the same checkout.
String _findRepository() {
  final explicit = Platform.environment['RUNNER_REPO_ROOT'];
  final starts = explicit == null
      ? [Directory.current, File(Platform.resolvedExecutable).parent]
      : [Directory(explicit)];
  for (var directory in starts) {
    while (true) {
      if (File('${directory.path}/tools/admin/service/native.mjs')
              .existsSync() &&
          File('${directory.path}/tools/release/environments.json')
              .existsSync() &&
          File('${directory.path}/pubspec.yaml').existsSync()) {
        return directory.absolute.path;
      }
      if (explicit != null || directory.parent.path == directory.path) break;
      directory = directory.parent;
    }
  }
  throw StateError(
    'Start Admin from the rpg_runner checkout, or set RUNNER_REPO_ROOT to that checkout.',
  );
}
