import 'package:flutter/widgets.dart';

/// Texts of the notification center. The app picks the language: [en],
/// [fr], or its own values (`copyWith`), once for the app with
/// [NotificationStringsScope]. `{n}` stands for a number.
@immutable
class NotificationStrings {
  const NotificationStrings({
    this.title = 'Notifications',
    this.markAllRead = 'Mark all as read',
    this.deleteAll = 'Delete all',
    this.deleteAllTitle = 'Delete all notifications?',
    this.deleteAllMessage = 'They will be removed from this list for good.',
    this.deleteAllConfirm = 'Delete all',
    this.cancel = 'Cancel',
    this.delete = 'Delete',
    this.more = 'More actions',
    this.unread = 'Unread',
    this.oneUnread = '1 unread',
    this.manyUnread = '{n} unread',
    this.allRead = 'All caught up',
    this.badgeLabel = '{n} unread notifications',
    this.empty = 'No notifications yet',
    this.filteredEmpty = 'No notifications match these filters',
    this.unreadOnly = 'Unread only',
    this.allSources = 'All',
    this.countTemplate = '{n} new',
    this.emptyDescription,
    this.loadFailed = 'Could not load the notifications',
    this.markReadFailed = 'Could not mark as read',
    this.deleteFailed = 'Could not delete',
    this.loadingMore = 'Loading older notifications',
    this.justNow = 'just now',
    this.minutesAgo = '{n} min ago',
    this.hoursAgo = '{n} h ago',
    this.daysAgo = '{n} d ago',
    this.weeksAgo = '{n} wk ago',
  });

  final String title;
  final String markAllRead;
  final String deleteAll;

  /// Confirmation dialog of « Delete all ».
  final String deleteAllTitle;
  final String deleteAllMessage;
  final String deleteAllConfirm;
  final String cancel;

  /// Tooltip of a notification's delete button.
  final String delete;

  /// Tooltip of the global actions menu.
  final String more;

  /// Read before an unread notification by a screen reader.
  final String unread;

  /// Summary over the list.
  final String oneUnread;
  final String manyUnread;
  final String allRead;

  /// Read for a [NotificationBadge] with a count.
  final String badgeLabel;

  final String empty;

  /// Under [empty]: what will show up here (« New videos from your
  /// subscriptions »).
  final String? emptyDescription;

  /// When the filters leave nothing.
  final String filteredEmpty;

  /// Filter chips.
  final String unreadOnly;
  final String allSources;

  /// Read for [NotificationItem.count].
  final String countTemplate;

  final String loadFailed;
  final String markReadFailed;
  final String deleteFailed;

  /// Read for the loader at the end of the list.
  final String loadingMore;

  /// Relative time of a notification; older than four weeks, the date.
  final String justNow;
  final String minutesAgo;
  final String hoursAgo;
  final String daysAgo;
  final String weeksAgo;

  static const en = NotificationStrings();

  static const fr = NotificationStrings(
    markAllRead: 'Tout marquer comme lu',
    deleteAll: 'Tout supprimer',
    deleteAllTitle: 'Supprimer toutes les notifications ?',
    deleteAllMessage: 'Elles seront retirées de cette liste pour de bon.',
    deleteAllConfirm: 'Tout supprimer',
    cancel: 'Annuler',
    delete: 'Supprimer',
    more: 'Plus d’actions',
    unread: 'Non lue',
    oneUnread: '1 non lue',
    manyUnread: '{n} non lues',
    allRead: 'Tout est lu',
    badgeLabel: '{n} notifications non lues',
    empty: 'Aucune notification pour l’instant',
    filteredEmpty: 'Aucune notification pour ces filtres',
    unreadOnly: 'Non lues seulement',
    allSources: 'Toutes',
    countTemplate: '{n} nouveautés',
    loadFailed: 'Impossible de charger les notifications',
    markReadFailed: 'Impossible de marquer comme lu',
    deleteFailed: 'Impossible de supprimer',
    loadingMore: 'Chargement des notifications plus anciennes',
    justNow: 'à l’instant',
    minutesAgo: 'il y a {n} min',
    hoursAgo: 'il y a {n} h',
    daysAgo: 'il y a {n} j',
    weeksAgo: 'il y a {n} sem.',
  );

  /// The [NotificationStringsScope] above [context]; without one, [fr]
  /// when the app locale is French, [en] otherwise.
  static NotificationStrings of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NotificationStringsScope>()
          ?.strings ??
      (Localizations.maybeLocaleOf(context)?.languageCode == 'fr' ? fr : en);

  /// [unreadCount] as the summary over the list.
  String unreadSummary(int unreadCount) => switch (unreadCount) {
    0 => allRead,
    1 => oneUnread,
    _ => _count(manyUnread, unreadCount),
  };

  String badge(int count) => _count(badgeLabel, count);

  String countLabel(int count) => _count(countTemplate, count);

  /// How long ago [time] was, or null when older than four weeks (the date
  /// is shown instead).
  String? timeAgo(DateTime time, DateTime now) {
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return justNow;
    if (diff.inMinutes < 60) return _count(minutesAgo, diff.inMinutes);
    if (diff.inHours < 24) return _count(hoursAgo, diff.inHours);
    if (diff.inDays < 7) return _count(daysAgo, diff.inDays);
    if (diff.inDays < 28) return _count(weeksAgo, diff.inDays ~/ 7);
    return null;
  }

  static String _count(String template, int n) =>
      template.replaceAll('{n}', '$n');

  NotificationStrings copyWith({
    String? title,
    String? markAllRead,
    String? deleteAll,
    String? deleteAllTitle,
    String? deleteAllMessage,
    String? deleteAllConfirm,
    String? cancel,
    String? delete,
    String? more,
    String? unread,
    String? oneUnread,
    String? manyUnread,
    String? allRead,
    String? badgeLabel,
    String? empty,
    String? emptyDescription,
    String? filteredEmpty,
    String? unreadOnly,
    String? allSources,
    String? countTemplate,
    String? loadFailed,
    String? markReadFailed,
    String? deleteFailed,
    String? loadingMore,
    String? justNow,
    String? minutesAgo,
    String? hoursAgo,
    String? daysAgo,
    String? weeksAgo,
  }) => NotificationStrings(
    title: title ?? this.title,
    markAllRead: markAllRead ?? this.markAllRead,
    deleteAll: deleteAll ?? this.deleteAll,
    deleteAllTitle: deleteAllTitle ?? this.deleteAllTitle,
    deleteAllMessage: deleteAllMessage ?? this.deleteAllMessage,
    deleteAllConfirm: deleteAllConfirm ?? this.deleteAllConfirm,
    cancel: cancel ?? this.cancel,
    delete: delete ?? this.delete,
    more: more ?? this.more,
    unread: unread ?? this.unread,
    oneUnread: oneUnread ?? this.oneUnread,
    manyUnread: manyUnread ?? this.manyUnread,
    allRead: allRead ?? this.allRead,
    badgeLabel: badgeLabel ?? this.badgeLabel,
    empty: empty ?? this.empty,
    emptyDescription: emptyDescription ?? this.emptyDescription,
    filteredEmpty: filteredEmpty ?? this.filteredEmpty,
    unreadOnly: unreadOnly ?? this.unreadOnly,
    allSources: allSources ?? this.allSources,
    countTemplate: countTemplate ?? this.countTemplate,
    loadFailed: loadFailed ?? this.loadFailed,
    markReadFailed: markReadFailed ?? this.markReadFailed,
    deleteFailed: deleteFailed ?? this.deleteFailed,
    loadingMore: loadingMore ?? this.loadingMore,
    justNow: justNow ?? this.justNow,
    minutesAgo: minutesAgo ?? this.minutesAgo,
    hoursAgo: hoursAgo ?? this.hoursAgo,
    daysAgo: daysAgo ?? this.daysAgo,
    weeksAgo: weeksAgo ?? this.weeksAgo,
  );
}

/// The app's own [NotificationStrings] for every center below it.
class NotificationStringsScope extends InheritedWidget {
  const NotificationStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final NotificationStrings strings;

  @override
  bool updateShouldNotify(NotificationStringsScope oldWidget) =>
      strings != oldWidget.strings;
}
