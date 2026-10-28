import 'package:flutter/foundation.dart';
import 'package:game_presentation/catalog_gift.dart';
import 'package:game_presentation/catalog_item.dart';

import 'admin_draft.dart';
import 'admin_service.dart';

/// Owns the compose/preview/send state machine and guards stale environment responses.
class AdminController extends ChangeNotifier {
  AdminController({required this.service, required this.store});
  final AdminService service;
  final AdminDraftStore store;
  AdminDraft draft = AdminDraft.fresh();
  Map<String, String> environments = {};
  List<GameCatalogItem> catalog = const [];
  List<String> characters = const [];
  String operatorAccount = '', catalogMessage = '';
  String? error, storageError;
  Map<String, dynamic>? preview;
  bool busy = false, catalogLoading = false, offlineTest = false, ready = false;
  int _catalogGeneration = 0, _editGeneration = 0;
  bool _disposed = false;
  String? get projectId => environments[draft.environment];
  bool get canEdit => ready && !busy && !draft.attempted;
  void reportError(String message) {
    error = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _run(() async {
    final config = await service.call('/api/environments');
    final rows = config['environments'];
    if (rows is! List ||
        rows.length != 3 ||
        config['operatorAccount'] is! String) {
      throw const FormatException('Invalid Admin configuration.');
    }
    final mapping = <String, String>{};
    for (final row in rows) {
      if (row is! Map ||
          !['dev', 'staging', 'prod'].contains(row['name']) ||
          row['projectId'] is! String) {
        throw const FormatException('Invalid environment.');
      }
      mapping[row['name'] as String] = row['projectId'] as String;
    }
    if (mapping.length != 3 || mapping.values.toSet().length != 3) {
      throw const FormatException('Environments must be separate.');
    }
    environments = Map.unmodifiable(mapping);
    operatorAccount = config['operatorAccount'];
    offlineTest = config['offlineTest'] == true;
    ready = true;
    draft = await store.load() ?? AdminDraft.fresh();
    if (draft.receipt != null) {
      _validateReceipt(draft.receipt!, delivered: true);
    }
    await loadCatalog();
  });

  void edit(AdminDraft next) {
    if (!canEdit || next.sourceId != draft.sourceId) return;
    draft = next;
    preview = null;
    error = null;
    _notify();
    final generation = ++_editGeneration;
    store
        .save(next)
        .then(
          (_) {
            if (generation == _editGeneration) {
              storageError = null;
              _notify();
            }
          },
          onError: (Object _) {
            if (generation == _editGeneration) {
              storageError = 'Draft could not be saved. Check local storage before sending.';
              _notify();
            }
          },
        );
  }

  Future<void> selectEnvironment(String name) async {
    if (!canEdit || !environments.containsKey(name)) return;
    edit(draft.copyWith(environment: name, attachments: []));
    await loadCatalog();
  }

  Future<void> loadCatalog() async {
    final generation = ++_catalogGeneration;
    final environment = draft.environment;
    catalog = const [];
    characters = const [];
    catalogMessage = '';
    if (!environments.containsKey(environment)) {
      catalogLoading = false;
      _notify();
      return;
    }
    catalogLoading = true;
    _notify();
    try {
      final result = await service.call('/api/catalog', {
        'environment': environment,
      });
      if (_disposed || generation != _catalogGeneration) return;
      if (result['environment'] != environment ||
          result['projectId'] != environments[environment] ||
          result['enabled'] is! bool) {
        throw const FormatException('Catalog destination mismatch.');
      }
      if (result['enabled'] == true) {
        catalog = List.unmodifiable(
          (result['entries'] as List).map(
            (row) =>
                GameCatalogItem.fromJson(Map<String, dynamic>.from(row as Map)),
          ),
        );
        characters = List.unmodifiable(
          (result['characters'] as List).cast<String>(),
        );
        if (catalog.map((e) => e.key).toSet().length != catalog.length ||
            characters.isEmpty) {
          throw const FormatException('Invalid gift catalog.');
        }
      } else {
        catalogMessage =
            result['message'] as String? ??
            'Item and skill gifts are unavailable in this environment.';
      }
    } catch (failure) {
      if (generation == _catalogGeneration) {
        catalog = const [];
        characters = const [];
        catalogMessage = 'Catalog unavailable. ${_errorText(failure)}';
      }
    } finally {
      if (generation == _catalogGeneration) {
        catalogLoading = false;
        _notify();
      }
    }
  }

  void toggleGift(GameCatalogItem item, String characterId) {
    if (!canEdit || !catalog.any((entry) => entry.key == item.key)) return;
    if (item.kind != 'gear' && !characters.contains(characterId)) return;
    final gift = CatalogGift(
      item: item,
      characterId: item.kind == 'gear' ? null : characterId,
    );
    final list = draft.attachments.toList();
    if (list.any((entry) => entry.key == gift.key)) {
      list.removeWhere((entry) => entry.key == gift.key);
    } else {
      if (list.length >= 8) {
        error = 'Use at most eight item or skill gifts.';
        _notify();
        return;
      }
      list.add(gift);
    }
    edit(draft.copyWith(attachments: list));
  }

  Future<void> createPreview() => _run(() async {
    if (!ready || projectId == null || draft.receipt != null) return;
    preview = null;
    await store.save(draft);
    storageError = null;
    final response = await service.call('/api/preview', {
      'environment': draft.environment,
      'message': draft.message,
    });
    _validateReceipt(response);
    if (response['previewId'] is! String) {
      throw const FormatException('Missing preview identity.');
    }
    preview = response;
  });

  Future<void> send() => _run(() async {
    final reviewed = preview;
    if (!ready || reviewed == null || draft.receipt != null) return;
    draft = draft.copyWith(attempted: true);
    _notify();
    // Persistence must succeed before any delivery can start.
    await store.save(draft);
    storageError = null;
    final response = await service.call('/api/send', {
      'previewId': reviewed['previewId'],
    });
    _validateReceipt(response, delivered: true);
    if (response['messageId'] != reviewed['messageId'] ||
        response['previewId'] != reviewed['previewId']) {
      throw const FormatException('Delivery receipt differs from the preview.');
    }
    draft = draft.copyWith(receipt: response);
    await store.save(draft);
  });

  Future<void> newMessage() => _run(() async {
    final next = AdminDraft.fresh(draft.environment);
    await store.save(next);
    _editGeneration++;
    draft = next;
    preview = null;
    storageError = null;
  });

  Future<void> restore(Map<String, dynamic> raw) => _run(() async {
    final restored = AdminDraft.fromJson(raw);
    await store.save(restored);
    _editGeneration++;
    draft = restored;
    preview = null;
    storageError = null;
    await loadCatalog();
  });

  void _validateReceipt(Map<String, dynamic> value, {bool delivered = false}) {
    if (value['environment'] != draft.environment ||
        value['projectId'] != projectId ||
        value['uid'] != draft.uid.trim() ||
        value['sourceId'] != draft.sourceId.trim() ||
        value['title'] != draft.title.trim() ||
        value['body'] != draft.body.trim() ||
        value['goldAmount'] != draft.goldAmount ||
        value['messageId'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(value['messageId']) ||
        !_sameJson(
          value['attachments'] ?? [],
          draft.message['attachments'] ?? [],
        ) ||
        (delivered &&
            (value['status'] != 'delivered' ||
                value['confirmedAt'] is! String))) {
      throw const FormatException('Invalid delivery destination or contents.');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
    } catch (failure) {
      error = _errorText(failure);
    } finally {
      busy = false;
      _notify();
    }
  }

  static String _errorText(Object failure) => failure is AdminServiceException
      ? failure.message
      : failure is FormatException
      ? failure.message
      : 'Operation could not be confirmed. Keep this draft and retry the same delivery.';
  @override
  void dispose() {
    _disposed = true;
    _catalogGeneration++;
    super.dispose();
  }
}

bool _sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _sameJson(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _sameJson(a[i], b[i]));
  }
  return a == b;
}
