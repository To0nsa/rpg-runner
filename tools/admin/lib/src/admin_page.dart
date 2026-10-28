import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_presentation/catalog_gift.dart';
import 'package:tool_ui/tool_ui.dart';

import 'admin_controller.dart';

/// Operator workspace. Domain state and all privileged requests live in the controller.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.controller});
  final AdminController controller;
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _uid = TextEditingController(), _title = TextEditingController();
  final _body = TextEditingController(), _gold = TextEditingController();
  final _search = TextEditingController();
  final _panels = ToolThreePanelController();
  String _category = 'All', _character = '';
  AdminController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    _search.addListener(_searchChanged);
    _changed();
  }

  void _searchChanged() => setState(() {});
  void _changed() {
    for (final pair in [
      (_uid, c.draft.uid),
      (_title, c.draft.title),
      (_body, c.draft.body),
      (_gold, c.draft.goldAmount == 0 ? '' : '${c.draft.goldAmount}'),
    ]) {
      if (pair.$1.text != pair.$2) {
        pair.$1.value = TextEditingValue(
          text: pair.$2,
          selection: TextSelection.collapsed(offset: pair.$2.length),
        );
      }
    }
    if (!c.characters.contains(_character)) {
      _character = c.characters.firstOrNull ?? '';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    for (final controller in [_uid, _title, _body, _gold, _search]) {
      controller.dispose();
    }
    _panels.dispose();
    super.dispose();
  }

  Future<bool> _replaceDraft() async {
    if (!c.draft.attempted || c.draft.receipt != null) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keep the uncertain delivery?'),
            content: const Text(
              'A send was attempted. Export this draft before replacing it so you can retry the same delivery without granting twice.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep draft'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace draft'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _export() async {
    try {
      final location = await getSaveLocation(
        suggestedName: 'admin-delivery-${c.draft.sourceId}.json',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON draft', extensions: ['json']),
        ],
      );
      if (location == null) return;
      await XFile.fromData(
        Uint8List.fromList(
          utf8.encode(
            const JsonEncoder.withIndent('  ').convert(c.draft.toJson()),
          ),
        ),
        mimeType: 'application/json',
        name: 'draft.json',
      ).saveTo(location.path);
    } catch (_) {
      c.reportError('Could not export the draft. Check the chosen location.');
    }
  }

  Future<void> _import() async {
    if (!await _replaceDraft()) return;
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON draft', extensions: ['json']),
        ],
      );
      if (file == null) return;
      if (await file.length() > 64 * 1024) throw const FormatException();
      await c.restore(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      c.reportError(
        'Could not import this draft. Choose a valid Admin or messaging draft.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Lothringen Admin'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Text(c.offlineTest ? 'OFFLINE FIXTURE' : c.operatorAccount),
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Messages & gifts',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('environment-${c.draft.environment}'),
                  initialValue: c.environments.containsKey(c.draft.environment)
                      ? c.draft.environment
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Environment',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in c.environments.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          {
                            'dev': 'Development',
                            'staging': 'Staging',
                            'prod': 'Production',
                          }[entry.key]!,
                        ),
                      ),
                  ],
                  onChanged: c.canEdit
                      ? (value) {
                          if (value != null) c.selectEnvironment(value);
                        }
                      : null,
                ),
              ),
              if (c.projectId != null)
                Chip(
                  avatar: Icon(
                    c.draft.environment == 'prod'
                        ? Icons.public
                        : Icons.dns_outlined,
                  ),
                  label: Text(
                    '${c.draft.environment.toUpperCase()} · ${c.projectId}',
                  ),
                  backgroundColor: c.draft.environment == 'prod'
                      ? Theme.of(context).colorScheme.errorContainer
                      : null,
                ),
              if (c.offlineTest)
                const Text('Test deliveries stay on this machine.'),
            ],
          ),
          if (!c.ready && !c.busy)
            TextButton(
              onPressed: c.initialize,
              child: const Text('Retry connection'),
            ),
          if (c.busy || c.catalogLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (c.error != null || c.storageError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(
                c.error ?? c.storageError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: ToolThreePanelLayout(
              controller: _panels,
              firstLabel: 'Compose',
              secondLabel: 'Gifts',
              thirdLabel: 'Review',
              firstFlex: 3,
              secondFlex: 4,
              thirdFlex: 3,
              initialNarrowIndex: 0,
              first: _compose(),
              second: _catalog(),
              third: _review(),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _compose() => ToolPanelCard(
    title: 'Compose',
    bodyMode: ToolPanelBodyMode.scrollable,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.draft.attempted)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'This delivery is locked. Retry it with the same contents, or start a new message.',
            ),
          ),
        TextField(
          key: const Key('player-uid'),
          controller: _uid,
          enabled: c.canEdit,
          maxLength: 128,
          decoration: const InputDecoration(
            labelText: 'Player UID',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => c.edit(c.draft.copyWith(uid: value)),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('message-title'),
          controller: _title,
          enabled: c.canEdit,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Message title',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => c.edit(c.draft.copyWith(title: value)),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('message-body'),
          controller: _body,
          enabled: c.canEdit,
          maxLength: 2000,
          minLines: 5,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'Message body',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => c.edit(c.draft.copyWith(body: value)),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('gold'),
          controller: _gold,
          enabled: c.canEdit,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
          ],
          decoration: const InputDecoration(
            labelText: 'Gold',
            helperText: 'Optional · claimed in the player inbox',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) =>
              c.edit(c.draft.copyWith(goldAmount: int.tryParse(value) ?? 0)),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('preview'),
          icon: const Icon(Icons.preview_outlined),
          label: const Text('Preview message'),
          onPressed:
              c.ready &&
                  !c.busy &&
                  c.projectId != null &&
                  c.draft.receipt == null
              ? () async {
                  await c.createPreview();
                  if (c.preview != null) _panels.revealPanel(2);
                }
              : null,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: !c.ready || c.busy
                  ? null
                  : () async {
                      if (await _replaceDraft()) await c.newMessage();
                    },
              child: const Text('New message'),
            ),
            TextButton(
              onPressed: !c.ready || c.busy ? null : _import,
              child: const Text('Import draft'),
            ),
            TextButton(
              onPressed: c.busy ? null : _export,
              child: const Text('Export draft'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Delivery ID', style: Theme.of(context).textTheme.labelMedium),
        SelectableText(
          c.draft.sourceId,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Your draft is saved on this computer. Keep its delivery ID when retrying.',
        ),
      ],
    ),
  );

  Widget _catalog() {
    final query = _search.text.trim().toLowerCase();
    final items = c.catalog
        .where(
          (item) =>
              (_category == 'All' ||
                  (_category == 'Items'
                      ? item.kind == 'gear'
                      : item.kind != 'gear')) &&
              '${item.displayName} ${item.itemId} ${item.slot}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return ToolPanelCard(
      title: 'Items & skills',
      bodyMode: ToolPanelBodyMode.scrollable,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.catalogMessage.isNotEmpty || c.projectId == null) ...[
            Text(
              c.projectId == null
                  ? 'Choose an environment to load its gift catalog.'
                  : c.catalogMessage,
            ),
            TextButton.icon(
              onPressed: c.catalogLoading || c.projectId == null
                  ? null
                  : c.loadCatalog,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload catalog'),
            ),
          ],
          if (c.catalog.isNotEmpty) ...[
            ToolVisualCatalogLayout(
              searchController: _search,
              searchKey: const Key('catalog-search'),
              searchLabel: 'Search items and skills',
              searchHint: 'Name or ID',
              clearSearchKey: const Key('clear-search'),
              clearSearchTooltip: 'Clear search',
              countKey: const Key('catalog-count'),
              countLabel:
                  '${items.length} available · ${c.draft.attachments.length}/8 selected',
              gridKey: const Key('gift-catalog'),
              emptyKey: const Key('empty-catalog'),
              emptyMessage: 'No matching gifts.',
              gridHeight: 390,
              itemCount: items.length,
              onSearchSubmitted: () {},
              filters: [
                for (final name in ['All', 'Items', 'Skills'])
                  ChoiceChip(
                    label: Text(name),
                    selected: _category == name,
                    onSelected: (_) => setState(() => _category = name),
                  ),
                if (c.characters.isNotEmpty)
                  DropdownButton<String>(
                    value: _character,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final character in c.characters)
                        DropdownMenuItem(
                          value: character,
                          child: Text('Skills for $character'),
                        ),
                    ],
                    onChanged: c.canEdit
                        ? (value) => setState(() => _character = value!)
                        : null,
                  ),
              ],
              itemBuilder: (context, index) {
                final item = items[index];
                final gift = CatalogGift(
                  item: item,
                  characterId: item.kind == 'gear' ? null : _character,
                );
                return ToolVisualCatalogCard(
                  key: ValueKey(gift.key),
                  semanticsLabel: 'Gift ${gift.label}',
                  tooltipMessage:
                      '${item.displayName}\n${item.itemId} · ${item.slot}',
                  selected: c.draft.attachments.any(
                    (value) => value.key == gift.key,
                  ),
                  enabled: c.canEdit,
                  preview: Center(child: item.icon(size: 48)),
                  title: item.displayName,
                  subtitle: item.kind == 'gear'
                      ? 'Account · ${item.slot}'
                      : '$_character · ${item.slot}',
                  onTap: () => c.toggleGift(item, _character),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          if (c.draft.attachments.isNotEmpty) ...[
            Text(
              'Selected gifts',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final gift in c.draft.attachments)
              _giftRow(gift, removable: c.canEdit),
            const SizedBox(height: 8),
            const Text(
              'Gifts unlock ownership. Already-owned items and skills grant no duplicate or compensation.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _giftRow(CatalogGift gift, {bool removable = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        gift.item.icon(size: 32),
        const SizedBox(width: 10),
        Expanded(child: Text(gift.label)),
        if (removable)
          IconButton(
            tooltip: 'Remove ${gift.item.displayName}',
            icon: const Icon(Icons.close),
            onPressed: () => c.edit(
              c.draft.copyWith(
                attachments: c.draft.attachments
                    .where((g) => g.key != gift.key)
                    .toList(),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _review() => ToolPanelCard(
    title: 'Review & send',
    bodyMode: ToolPanelBodyMode.scrollable,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.preview == null && c.draft.receipt == null)
          const Text(
            'Preview the message to review its exact destination and gifts.',
          ),
        if (c.preview != null || c.draft.receipt != null) ...[
          Text(
            '${c.draft.environment.toUpperCase()} · ${c.projectId}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 16),
          const Text('Player UID'),
          SelectableText(c.draft.uid.trim()),
          const SizedBox(height: 16),
          Text(
            c.draft.title.trim(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SelectableText(c.draft.body.trim()),
          const Divider(height: 32),
          if (c.draft.goldAmount > 0)
            Text(
              '${c.draft.goldAmount} gold to claim',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          for (final gift in c.draft.attachments) _giftRow(gift),
          const SizedBox(height: 20),
          if (c.draft.receipt == null) ...[
            Text(
              c.draft.environment == 'prod'
                  ? 'This sends to a real player in PRODUCTION.'
                  : 'Sending checks that this player exists in the selected environment.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('send'),
              icon: const Icon(Icons.send_outlined),
              onPressed: c.busy ? null : c.send,
              label: Text(
                c.draft.attempted
                    ? 'Retry same delivery'
                    : 'Send to ${c.draft.environment.toUpperCase()}',
              ),
            ),
          ] else ...[
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent),
                SizedBox(width: 8),
                Text('Delivery confirmed'),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Message ID'),
            SelectableText(c.draft.receipt!['messageId'] as String),
            const SizedBox(height: 8),
            Text(c.draft.receipt!['confirmedAt'] as String),
            const SizedBox(height: 12),
            const Text('The player claims gifts from their inbox.'),
          ],
        ],
      ],
    ),
  );
}
