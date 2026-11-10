import 'package:intl/intl.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:game_presentation/catalog_gift.dart';

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
              context.l10n.uiUnableToMarkThisMessageAsReadPleaseTryAgain,
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
          () => _actionError = context
              .l10n
              .uiUnableToConfirmTheClaimPleaseTryAgainYourGiftCanOnlyBeClaimedOnce,
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
          () => _actionError =
              context.l10n.uiUnableToConfirmDeletionPleaseTryAgain,
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
      title: context.l10n.uiMessages,
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
                    context.l10n.uiMessagesAreUnavailableInThisProfile,
                    style: ui.text.body,
                  ),
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.uiGameMessages,
                            style: ui.text.headline,
                          ),
                        ),
                        GoldDisplay(gold: app.displayedGold),
                        SizedBox(width: ui.space.sm),
                        AppIconButton(
                          icon: Icons.refresh,
                          tooltip: context.l10n.uiRefreshMessages,
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
                                context.l10n.inboxLoadFailed,
                                style: ui.text.body,
                              ),
                            ),
                            AppButton(
                              label: context.l10n.uiRetry,
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
                                              ? context
                                                    .l10n
                                                    .uiMoreMessagesAreAvailable
                                              : app.inboxLoadError == null
                                              ? context.l10n.uiNoMessagesYet
                                              : context
                                                    .l10n
                                                    .uiYourMessagesWillAppearHere,
                                          style: ui.text.body,
                                        ),
                                        if (app.inboxHasMore)
                                          AppButton(
                                            label: context.l10n.uiLoadMore,
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
                                              ? context.l10n.uiLoadingLabel
                                              : context.l10n.uiLoadMore,
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
                                              context
                                                  .l10n
                                                  .uiSelectAMessageToReadIt,
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
                                                        selected
                                                            .textFor(
                                                              context
                                                                  .l10n
                                                                  .localeName,
                                                            )
                                                            .title,
                                                        style: ui.text.headline,
                                                      ),
                                                      SizedBox(
                                                        height: ui.space.xxs,
                                                      ),
                                                      Text(
                                                        context.l10n
                                                            .messageHeader(
                                                              date: _messageDate(
                                                                selected
                                                                    .createdAtMs,
                                                                context.l10n,
                                                              ),
                                                            ),
                                                        style: ui
                                                            .text
                                                            .cardSubtitle,
                                                      ),
                                                      SizedBox(
                                                        height: ui.space.md,
                                                      ),
                                                      Text(
                                                        selected
                                                            .textFor(
                                                              context
                                                                  .l10n
                                                                  .localeName,
                                                            )
                                                            .body,
                                                        style: ui.text.body,
                                                      ),
                                                      SizedBox(
                                                        height: ui.space.sm,
                                                      ),
                                                      Text(
                                                        selected.canClaim
                                                            ? selected
                                                                      .attachments
                                                                      .isEmpty
                                                                  ? context
                                                                        .l10n
                                                                        .uiClaimYourGoldBeforeDeletingThisMessageUnclaimedGoldDoesNotExpire
                                                                  : context
                                                                        .l10n
                                                                        .uiClaimYourGiftsBeforeDeletingThisMessageUnclaimedGiftsDoNotExpire
                                                            : selected.hasReward
                                                            ? context
                                                                  .l10n
                                                                  .uiAutomaticallyRemoved30DaysAfterClaiming
                                                            : context
                                                                  .l10n
                                                                  .uiAutomaticallyRemoved30DaysAfterReading,
                                                        style: ui
                                                            .text
                                                            .cardSubtitle,
                                                      ),
                                                      for (final gift
                                                          in selected
                                                              .attachments)
                                                        _GiftRow(gift: gift),
                                                      if (selected
                                                          .attachments
                                                          .isNotEmpty)
                                                        Text(
                                                          context
                                                              .l10n
                                                              .uiAlreadyOwnedGiftsGrantNoDuplicateUnlockOrCompensation,
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
                                                            label: context
                                                                .l10n
                                                                .uiRetryReading,
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
                                                  if (selected.goldAmount > 0)
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
                                                                ? context
                                                                      .l10n
                                                                      .uiPleaseWait
                                                                : context
                                                                      .l10n
                                                                      .uiClaim
                                                          : context
                                                                .l10n
                                                                .uiClaimed,
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
                                                    label: context
                                                        .l10n
                                                        .uiDeleteMessage,
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
      if (message.isUnread) context.l10n.uiUnread,
      if (message.canClaim) context.l10n.uiGiftAvailable,
      if (message.hasReward && !message.canClaim) context.l10n.uiClaimed,
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
                  message.textFor(context.l10n.localeName).title,
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
                  _messageDate(message.createdAtMs, context.l10n),
                  style: ui.text.cardSubtitle,
                ),
                if (message.goldAmount > 0)
                  Text(
                    context.l10n.goldAmount(gold: message.goldAmount),
                    style: ui.text.body,
                  ),
                if (message.attachments.isNotEmpty)
                  Text(
                    context.l10n.messageGiftCount(
                      count: message.attachments.length,
                    ),
                    style: ui.text.body,
                  ),
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

String _messageDate(int milliseconds, AppLocalizations l10n) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  return DateFormat.yMd(l10n.localeName).format(date);
}

/// Attachment artwork and names are shared with loadout screens and Admin.
class _GiftRow extends StatelessWidget {
  const _GiftRow({required this.gift});
  final CatalogGift gift;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.ui.space.xs),
    child: Row(
      children: [
        gift.item.icon(size: 32),
        SizedBox(width: context.ui.space.sm),
        Expanded(
          child: Text(
            gift.label(context.gameL10n),
            style: context.ui.text.body,
          ),
        ),
      ],
    ),
  );
}
