import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/app_button.dart';
import '../../components/app_icon_button.dart';
import '../../components/gold_display.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app/app_state.dart';
import '../../state/inbox/inbox_models.dart';
import '../../theme/ui_tokens.dart';

/// Landscape system inbox using the same shell, panels and controls as other menus.
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  String? _selectedId;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    // Provider notifications happen after this route's first build completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<AppState>().loadInbox());
    });
  }

  Future<void> _open(InboxMessage message) async {
    setState(() {
      _selectedId = message.id;
      _actionError = null;
    });
    if (!message.isUnread) return;
    try {
      await context.read<AppState>().markInboxMessageRead(message.id);
    } catch (_) {
      if (mounted && _selectedId == message.id) {
        setState(
          () => _actionError =
              'Unable to mark this message as read. Please try again.',
        );
      }
    }
  }

  Future<void> _claim(InboxMessage message) async {
    setState(() => _actionError = null);
    try {
      await context.read<AppState>().claimInboxReward(message.id);
    } catch (_) {
      if (mounted && _selectedId == message.id) {
        setState(
          () => _actionError = 'Unable to confirm the claim. Please try again. Your gift can only be claimed once.',
        );
      }
    }
  }

  Future<void> _delete(InboxMessage message) async {
    setState(() => _actionError = null);
    try {
      await context.read<AppState>().deleteInboxMessage(message.id);
      if (mounted && _selectedId == message.id) {
        setState(() {
          _selectedId = null;
          _actionError = null;
        });
      }
    } catch (_) {
      if (mounted && _selectedId == message.id) {
        setState(
          () => _actionError = 'Unable to confirm deletion. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ui = context.ui;
    final selected = app.inboxMessages
        .where((message) => message.id == _selectedId)
        .firstOrNull;
    return MenuScaffold(
      title: 'Messages',
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ui.space.md,
            0,
            ui.space.md,
            ui.space.sm,
          ),
          child: !app.inboxAvailable
              ? Center(
                  child: Text(
                    'Messages are unavailable in this profile.',
                    style: ui.text.body,
                  ),
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Game messages', style: ui.text.headline),
                        ),
                        GoldDisplay(gold: app.progression.gold),
                        SizedBox(width: ui.space.sm),
                        AppIconButton(
                          icon: Icons.refresh,
                          tooltip: 'Refresh messages',
                          onPressed: app.inboxLoading
                              ? null
                              : () => app.loadInbox(),
                        ),
                      ],
                    ),
                    if (app.inboxLoadError != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: ui.space.xs),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                app.inboxLoadError!,
                                style: ui.text.body,
                              ),
                            ),
                            AppButton(
                              label: 'Retry',
                              size: AppButtonSize.sm,
                              onPressed: app.inboxLoading
                                  ? null
                                  : () => app.loadInbox(),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: app.inboxMessages.isEmpty
                          ? Center(
                              child: app.inboxLoading
                                  ? const CircularProgressIndicator()
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          app.inboxHasMore
                                              ? 'More messages are available.'
                                              : app.inboxLoadError == null
                                              ? 'No messages yet.'
                                              : 'Your messages will appear here.',
                                          style: ui.text.body,
                                        ),
                                        if (app.inboxHasMore)
                                          AppButton(
                                            label: 'Load more',
                                            onPressed: () =>
                                                app.loadInbox(more: true),
                                          ),
                                      ],
                                    ),
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount:
                                        app.inboxMessages.length +
                                        (app.inboxHasMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index == app.inboxMessages.length) {
                                        return AppButton(
                                          label: app.inboxLoading
                                              ? 'Loading…'
                                              : 'Load more',
                                          onPressed: app.inboxLoading
                                              ? null
                                              : () => app.loadInbox(more: true),
                                        );
                                      }
                                      final message = app.inboxMessages[index];
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom: ui.space.xs,
                                        ),
                                        child: _MessageTile(
                                          message: message,
                                          selected: message.id == _selectedId,
                                          onPressed: () => _open(message),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: ui.space.sm),
                                Expanded(
                                  flex: 3,
                                  child: _MessagePanel(
                                    child: selected == null
                                        ? Center(
                                            child: Text(
                                              'Select a message to read it.',
                                              style: ui.text.body,
                                            ),
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        selected.title,
                                                        style: ui.text.headline,
                                                      ),
                                                      SizedBox(
                                                        height: ui.space.xxs,
                                                      ),
                                                      Text(
                                                        'Game · ${_messageDate(selected.createdAtMs)}',
                                                        style: ui
                                                            .text
                                                            .cardSubtitle,
                                                      ),
                                                      SizedBox(
                                                        height: ui.space.md,
                                                      ),
                                                      Text(
                                                        selected.body,
                                                        style: ui.text.body,
                                                      ),
                                                      SizedBox(
                                                        height: ui.space.sm,
                                                      ),
                                                      Text(
                                                        selected.canClaim
                                                            ? 'Claim your gold before deleting this message. Unclaimed gold does not expire.'
                                                            : selected.hasReward
                                                            ? 'Automatically removed 30 days after claiming.'
                                                            : 'Automatically removed 30 days after reading.',
                                                        style: ui
                                                            .text
                                                            .cardSubtitle,
                                                      ),
                                                      if (_actionError !=
                                                          null) ...[
                                                        SizedBox(
                                                          height: ui.space.sm,
                                                        ),
                                                        Text(
                                                          _actionError!,
                                                          style: ui.text.body,
                                                        ),
                                                        if (selected.isUnread)
                                                          AppButton(
                                                            label:
                                                                'Retry reading',
                                                            size: AppButtonSize
                                                                .sm,
                                                            onPressed:
                                                                app.inboxMessageBusy(
                                                                  selected.id,
                                                                )
                                                                ? null
                                                                : () => _open(
                                                                    selected,
                                                                  ),
                                                          ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: ui.space.sm),
                                              Wrap(
                                                spacing: ui.space.sm,
                                                runSpacing: ui.space.xs,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  if (selected.hasReward)
                                                    GoldDisplay(
                                                      gold: selected.goldAmount,
                                                      variant:
                                                          GoldDisplayVariant
                                                              .body,
                                                    ),
                                                  if (selected.hasReward)
                                                    AppButton(
                                                      label: selected.canClaim
                                                          ? app.inboxMessageBusy(
                                                                  selected.id,
                                                                )
                                                                ? 'Please wait…'
                                                                : 'Claim'
                                                          : 'Claimed',
                                                      size: AppButtonSize.sm,
                                                      onPressed:
                                                          selected.canClaim &&
                                                              !app.inboxMessageBusy(
                                                                selected.id,
                                                              )
                                                          ? () =>
                                                                _claim(selected)
                                                          : null,
                                                    ),
                                                  AppButton(
                                                    label: 'Delete message',
                                                    size: AppButtonSize.sm,
                                                    variant: AppButtonVariant
                                                        .secondary,
                                                    onPressed:
                                                        selected.canClaim ||
                                                            app.inboxMessageBusy(
                                                              selected.id,
                                                            )
                                                        ? null
                                                        : () =>
                                                              _delete(selected),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.selected,
    required this.onPressed,
  });
  final InboxMessage message;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final state = [
      if (message.isUnread) 'Unread',
      if (message.canClaim) 'Gift available',
      if (message.hasReward && !message.canClaim) 'Claimed',
    ].join(' · ');
    return Semantics(
      selected: selected,
      child: Material(
        color: ui.colors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ui.radii.sm),
          side: BorderSide(
            color: selected ? ui.colors.outlineStrong : ui.colors.outline,
            width: selected ? ui.sizes.borderWidth : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.all(ui.space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.title,
                  style: ui.text.body.copyWith(
                    fontWeight: message.isUnread
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ui.space.xxs),
                Text(
                  _messageDate(message.createdAtMs),
                  style: ui.text.cardSubtitle,
                ),
                if (message.hasReward)
                  Text('${message.goldAmount} gold', style: ui.text.body),
                if (state.isNotEmpty)
                  Text(
                    state,
                    style: ui.text.cardSubtitle.copyWith(
                      color: ui.colors.accentStrong,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      padding: EdgeInsets.all(ui.space.md),
      decoration: BoxDecoration(
        color: ui.colors.cardBackground,
        borderRadius: BorderRadius.circular(ui.radii.sm),
        border: Border.all(color: ui.colors.outline),
      ),
      child: child,
    );
  }
}

String _messageDate(int milliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
