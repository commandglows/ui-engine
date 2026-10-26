import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';
import 'package:shipglows_icons/shipglows_icons.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'notification_controller.dart';
import 'notification_item.dart';
import 'strings.dart';

/// Asks before « Delete all »; true goes ahead.
typedef NotificationConfirm =
    Future<bool> Function(
      BuildContext context, {
      required String title,
      required String message,
      required String confirmLabel,
    });

/// Hears every failed action, for the app's log. Mark all read and the
/// deletions also show an error message; the read mark of an opened
/// notification, done in the background, goes to [FlutterError.reportError]
/// when there is no handler.
typedef NotificationErrorHandler =
    void Function(
      Object error,
      StackTrace stackTrace,
      NotificationOperation operation,
    );

/// The leading of a notification: the app's own (a thumbnail), or
/// [fallback], the type's icon in a tinted circle.
typedef NotificationLeadingBuilder =
    Widget Function(BuildContext context, NotificationItem item, Widget fallback);

/// The body of a notification screen or panel: the latest notifications,
/// unread first in weight and tint, how long ago, open and delete, the
/// unread summary, the empty and error states. The app keeps its scaffold
/// and puts [NotificationCenterActions] in its app bar, or sets
/// [showToolbar] for a panel without one.
class NotificationCenterView extends StatefulWidget {
  const NotificationCenterView({
    super.key,
    required this.controller,
    this.onOpen,
    this.leadingBuilder,
    this.strings,
    this.confirm,
    this.onError,
    this.formatDate,
    this.now,
    this.showSummary = true,
    this.showToolbar = false,
    this.showFilters = true,
    this.emptyIcon,
    this.padding = EdgeInsets.zero,
  });

  final NotificationCenterController controller;

  /// Opens what the notification is about; it is marked read first. Null:
  /// a tap only marks it read.
  final void Function(NotificationItem item)? onOpen;

  final NotificationLeadingBuilder? leadingBuilder;

  /// Defaults to [NotificationStrings.of] the context.
  final NotificationStrings? strings;

  /// The app's confirmation dialog; a plain [AlertDialog] by default.
  final NotificationConfirm? confirm;

  final NotificationErrorHandler? onError;

  /// Date of a notification older than four weeks; the medium Material date
  /// by default.
  final String Function(BuildContext context, DateTime date)? formatDate;

  /// The clock of « 3 min ago », for tests.
  final DateTime Function()? now;

  /// « 3 unread » / « All caught up » over the list, announced on change.
  final bool showSummary;

  /// The summary and the actions in a row over the list.
  final bool showToolbar;

  /// « Unread only » and, with several sources, one chip per source.
  final bool showFilters;

  /// Icon of the empty state; the bell by default.
  final IconData? emptyIcon;

  /// Around the list.
  final EdgeInsetsGeometry padding;

  @override
  State<NotificationCenterView> createState() => _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<NotificationCenterView> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // « 3 min ago » moves on while the center stays open.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _open(NotificationItem item) {
    if (!item.read) {
      unawaited(
        widget.controller.markRead(item.id).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          final onError = widget.onError;
          if (onError != null) {
            onError(error, stackTrace, NotificationOperation.markRead);
          } else {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'shipglows_notification_center',
                context: ErrorDescription('marking a notification read'),
              ),
            );
          }
        }),
      );
    }
    widget.onOpen?.call(item);
  }

  Future<void> _delete(
    NotificationItem item,
    NotificationStrings texts,
  ) async {
    final feedback = FeedbackMessenger.of(context);
    try {
      await widget.controller.delete(item.id);
    } catch (error, stackTrace) {
      _report(
        feedback,
        texts,
        error,
        stackTrace,
        NotificationOperation.delete,
        widget.onError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = widget.strings ?? NotificationStrings.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _build(context, texts),
    );
  }

  Widget _build(BuildContext context, NotificationStrings texts) {
    final theme = ShipglowsTheme.of(context);
    final controller = widget.controller;
    final items = controller.items;
    final error = controller.error;

    if (controller.isLoading) {
      return Center(
        child: CircularProgressIndicator(semanticsLabel: texts.title),
      );
    }
    final hasAny = controller.allItems.isNotEmpty;
    if (error != null && !hasAny) {
      return FeedbackErrorState(
        message: texts.loadFailed,
        onRetry: () => unawaited(controller.retry()),
        details: () => '$error\n${controller.stackTrace ?? ''}'.trim(),
      );
    }
    if (!hasAny) {
      return _EmptyState(texts: texts, icon: widget.emptyIcon);
    }

    final now = (widget.now ?? DateTime.now)();
    final summary = Semantics(
      liveRegion: true,
      child: Text(
        texts.unreadSummary(controller.unreadCount),
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: theme.textMuted),
      ),
    );
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showToolbar)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: theme.spaceMd,
                end: theme.spaceSm,
                top: theme.spaceXs,
                bottom: theme.spaceXs,
              ),
              child: Row(
                children: [
                  Expanded(child: widget.showSummary ? summary : const SizedBox()),
                  NotificationCenterActions(
                    controller: controller,
                    strings: texts,
                    confirm: widget.confirm,
                    onError: widget.onError,
                  ),
                ],
              ),
            )
          else if (widget.showSummary)
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spaceMd,
                theme.spaceMd,
                theme.spaceMd,
                theme.spaceSm,
              ),
              child: summary,
            ),
          if (error != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spaceMd,
                vertical: theme.spaceSm,
              ),
              child: FeedbackInline(
                kind: FeedbackKind.error,
                dense: true,
                message: texts.loadFailed,
                trailing: TextButton(
                  onPressed: () => unawaited(controller.retry()),
                  child: Text(FeedbackStrings.of(context).retry),
                ),
              ),
            ),
          if (widget.showFilters)
            _FilterBar(controller: controller, texts: texts),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(theme.spaceXl),
                      child: Text(
                        texts.filteredEmpty,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: theme.textMuted),
                      ),
                    ),
                  )
                : ListView.builder(
              itemCount: items.length + (controller.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return _LoadMore(
                    controller: controller,
                    label: texts.loadingMore,
                    onError: widget.onError,
                  );
                }
                final item = items[index];
                return NotificationTile(
                  key: ValueKey(item.id),
                  item: item,
                  now: now,
                  strings: texts,
                  leadingBuilder: widget.leadingBuilder,
                  formatDate: widget.formatDate,
                  onTap: () => _open(item),
                  onDelete: controller.canDelete
                      ? () => unawaited(_delete(item, texts))
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void _report(
  FeedbackMessenger feedback,
  NotificationStrings texts,
  Object error,
  StackTrace stackTrace,
  NotificationOperation operation,
  NotificationErrorHandler? onError,
) {
  onError?.call(error, stackTrace, operation);
  final message = switch (operation) {
    NotificationOperation.markRead ||
    NotificationOperation.markAllRead => texts.markReadFailed,
    NotificationOperation.delete ||
    NotificationOperation.deleteAll => texts.deleteFailed,
    NotificationOperation.loadMore => texts.loadFailed,
  };
  feedback.showError(message, details: () => '$error\n$stackTrace');
}

/// The end of a list with older pages: asks for the next one once built,
/// that is once scrolled near.
class _LoadMore extends StatefulWidget {
  const _LoadMore({
    required this.controller,
    required this.label,
    this.onError,
  });

  final NotificationCenterController controller;
  final String label;
  final NotificationErrorHandler? onError;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        widget.controller.loadMore().catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          final onError = widget.onError;
          if (onError != null) {
            onError(error, stackTrace, NotificationOperation.loadMore);
          } else {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'shipglows_notification_center',
                context: ErrorDescription('loading older notifications'),
              ),
            );
          }
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(theme.spaceMd),
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: widget.label,
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller, required this.texts});

  final NotificationCenterController controller;
  final NotificationStrings texts;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final sources = controller.sources;
    final selected = controller.source;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spaceMd,
        0,
        theme.spaceMd,
        theme.spaceSm,
      ),
      child: Wrap(
        spacing: theme.spaceSm,
        runSpacing: theme.spaceXs,
        children: [
          FilterChip(
            label: Text(texts.unreadOnly),
            selected: controller.unreadOnly,
            onSelected: (value) => controller.unreadOnly = value,
          ),
          if (sources.length > 1) ...[
            ChoiceChip(
              label: Text(texts.allSources),
              selected: selected == null,
              onSelected: (_) => controller.source = null,
            ),
            for (final source in sources)
              ChoiceChip(
                label: Text(source),
                selected: selected == source,
                onSelected: (value) => controller.source = value ? source : null,
              ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.texts, this.icon});

  final NotificationStrings texts;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final description = texts.emptyDescription;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.all(theme.spaceXl),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    icon ??
                        ShipglowsIcons.of(context, 'notifications') ??
                        ShipglowsIcons.notifications,
                    size: 40,
                    color: theme.icon,
                  ),
                ),
                SizedBox(height: theme.spaceMd),
                Text(
                  texts.empty,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(color: theme.text),
                ),
                if (description != null) ...[
                  SizedBox(height: theme.spaceXs),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: theme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One notification: its leading, the title (bold when unread) over the
/// body and how long ago, an unread dot, a delete button. A screen reader
/// hears « Unread. Title. Body. 3 min ago » as one button; the delete
/// button is its own, 44 px.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onDelete,
    this.now,
    this.strings,
    this.leadingBuilder,
    this.formatDate,
  });

  final NotificationItem item;
  final VoidCallback? onTap;

  /// Null hides the delete button.
  final VoidCallback? onDelete;

  /// Defaults to [DateTime.now].
  final DateTime? now;

  /// Defaults to [NotificationStrings.of] the context.
  final NotificationStrings? strings;
  final NotificationLeadingBuilder? leadingBuilder;
  final String Function(BuildContext context, DateTime date)? formatDate;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final texts = strings ?? NotificationStrings.of(context);
    final unread = !item.read;
    final body = item.body;
    final time =
        texts.timeAgo(item.createdAt, now ?? DateTime.now()) ??
        (formatDate?.call(context, item.createdAt) ??
            MaterialLocalizations.of(context).formatMediumDate(item.createdAt));
    final tone = item.kind?.colorOf(theme) ?? theme.accent;

    final fallback = _IconLeading(
      icon:
          item.icon ??
          ShipglowsIcons.of(context, 'notifications') ??
          ShipglowsIcons.notifications,
      tone: tone,
    );
    final leading = leadingBuilder?.call(context, item, fallback) ?? fallback;

    final source = item.source;
    final count = item.count;
    final label = [
      if (unread) texts.unread,
      ?source,
      item.title,
      ?body,
      if (count != null) texts.countLabel(count),
      time,
    ].join('. ');

    final content = Semantics(
      container: true,
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: theme.spaceMd,
              end: onDelete == null ? theme.spaceMd : theme.spaceXs,
              top: theme.spaceSm,
              bottom: theme.spaceSm,
            ),
            child: Row(
              children: [
                leading,
                SizedBox(width: theme.spaceMd),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (source != null)
                        Text(
                          source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: theme.textMuted,
                          ),
                        ),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: theme.text,
                          fontWeight: unread
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      if (body != null) ...[
                        SizedBox(height: theme.spaceXs / 2),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: theme.textMuted,
                          ),
                        ),
                      ],
                      SizedBox(height: theme.spaceXs / 2),
                      Text(
                        time,
                        style: textTheme.labelSmall?.copyWith(
                          color: theme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (count != null) ...[
                  SizedBox(width: theme.spaceSm),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        theme.accent.withValues(alpha: 0.14),
                        theme.surfaceRaised,
                      ),
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spaceSm,
                        vertical: theme.spaceXs / 2,
                      ),
                      child: Text(
                        '$count',
                        style: textTheme.labelMedium?.copyWith(
                          color: theme.text,
                        ),
                      ),
                    ),
                  ),
                ],
                if (unread) ...[
                  SizedBox(width: theme.spaceSm),
                  // Unread is also said by the weight and, to a screen
                  // reader, by the label: the dot is never alone.
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Material(
      color: unread
          ? Color.alphaBlend(theme.accent.withValues(alpha: 0.08), theme.surface)
          : Colors.transparent,
      child: Row(
        children: [
          Expanded(child: content),
          if (onDelete case final onDelete?)
            Padding(
              padding: EdgeInsetsDirectional.only(end: theme.spaceXs),
              child: IconButton(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: texts.delete,
                color: theme.icon,
                onPressed: onDelete,
                icon: Icon(
                  ShipglowsIcons.of(context, 'delete') ?? ShipglowsIcons.delete,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IconLeading extends StatelessWidget {
  const _IconLeading({required this.icon, required this.tone});

  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            tone.withValues(alpha: 0.14),
            theme.surfaceRaised,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: tone, size: 20),
      ),
    );
  }
}

enum _GlobalAction { deleteAll }

/// « Mark all as read » and, when the store can, « Delete all » (confirmed)
/// in a menu: for the app bar over a [NotificationCenterView]. Disabled
/// while there is nothing to do or the action runs.
class NotificationCenterActions extends StatelessWidget {
  const NotificationCenterActions({
    super.key,
    required this.controller,
    this.strings,
    this.confirm,
    this.onError,
  });

  final NotificationCenterController controller;

  /// Defaults to [NotificationStrings.of] the context.
  final NotificationStrings? strings;
  final NotificationConfirm? confirm;
  final NotificationErrorHandler? onError;

  Future<void> _markAllRead(
    BuildContext context,
    NotificationStrings texts,
  ) async {
    final feedback = FeedbackMessenger.of(context);
    try {
      await controller.markAllRead();
    } catch (error, stackTrace) {
      _report(
        feedback,
        texts,
        error,
        stackTrace,
        NotificationOperation.markAllRead,
        onError,
      );
    }
  }

  Future<void> _deleteAll(BuildContext context, NotificationStrings texts) async {
    final feedback = FeedbackMessenger.of(context);
    final ok = await _confirm(context, texts);
    if (!ok) return;
    try {
      await controller.deleteAll();
    } catch (error, stackTrace) {
      _report(
        feedback,
        texts,
        error,
        stackTrace,
        NotificationOperation.deleteAll,
        onError,
      );
    }
  }

  Future<bool> _confirm(BuildContext context, NotificationStrings texts) {
    final confirm = this.confirm;
    if (confirm != null) {
      return confirm(
        context,
        title: texts.deleteAllTitle,
        message: texts.deleteAllMessage,
        confirmLabel: texts.deleteAllConfirm,
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = ShipglowsTheme.of(context);
        return AlertDialog(
          title: Text(texts.deleteAllTitle),
          content: Text(texts.deleteAllMessage),
          actions: [
            // Explicit color: the dialog captures the themes around the
            // actions, an app bar's light text button theme included.
            TextButton(
              style: TextButton.styleFrom(foregroundColor: theme.accent),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(texts.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.danger,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(texts.deleteAllConfirm),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final texts = strings ?? NotificationStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasItems = controller.items.isNotEmpty;
        final canMarkAll =
            controller.shownUnreadCount > 0 && !controller.markingAllRead;
        final canDeleteAll =
            controller.canDeleteAll && hasItems && !controller.deletingAll;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: canMarkAll
                  ? () => unawaited(_markAllRead(context, texts))
                  : null,
              icon: Icon(
                ShipglowsIcons.of(context, 'check') ?? ShipglowsIcons.check,
                size: 18,
              ),
              label: Text(texts.markAllRead),
            ),
            if (controller.canDeleteAll)
              PopupMenuButton<_GlobalAction>(
                tooltip: texts.more,
                icon: Icon(
                  ShipglowsIcons.of(context, 'more') ?? ShipglowsIcons.more,
                ),
                // After the menu closes, so the dialog is not closed with it.
                onSelected: (_) => unawaited(_deleteAll(context, texts)),
                itemBuilder: (menuContext) => [
                  PopupMenuItem<_GlobalAction>(
                    value: _GlobalAction.deleteAll,
                    enabled: canDeleteAll,
                    child: Row(
                      children: [
                        Icon(
                          ShipglowsIcons.of(menuContext, 'clear') ??
                              ShipglowsIcons.clear,
                          size: 18,
                        ),
                        SizedBox(width: ShipglowsTheme.of(menuContext).spaceSm),
                        Text(texts.deleteAll),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
