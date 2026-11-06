import 'package:flutter/foundation.dart';

/// Texts of [TrashView]. The app picks the language: use [en], [fr], or its
/// own values. `{date}`, `{days}` and `{count}` are filled in.
@immutable
class TrashStrings {
  const TrashStrings({
    required this.searchHint,
    required this.allFilter,
    required this.empty,
    required this.noMatch,
    required this.restore,
    required this.deletePermanently,
    required this.deleted,
    required this.deletedWithDays,
    required this.lastDay,
    required this.purging,
    required this.deleteTitle,
    required this.deleteMessage,
    required this.emptyTrash,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.cancel,
  });

  final String searchHint;
  final String allFilter;
  final String empty;
  final String noMatch;
  final String restore;

  final String deletePermanently;

  /// Subtitle without a purge date: `{date}`.
  final String deleted;

  /// Subtitle with a purge date: `{date}`, `{days}`.
  final String deletedWithDays;

  /// Subtitle on the last day before purge: `{date}`.
  final String lastDay;
  final String purging;
  final String deleteTitle;
  final String deleteMessage;
  final String emptyTrash;
  final String emptyTitle;

  /// Confirmation to empty the trash: `{count}`.
  final String emptyMessage;
  final String cancel;

  static const en = TrashStrings(
    searchHint: 'Search the trash',
    allFilter: 'All',
    empty: 'Trash is empty',
    noMatch: 'Nothing in the trash matches these filters',
    restore: 'Restore',
    deletePermanently: 'Delete permanently',
    deleted: 'Deleted {date}',
    deletedWithDays: 'Deleted {date} · {days} days remaining',
    lastDay: 'Deleted {date} · deleted for good today',
    purging: 'Permanent deletion in progress; restore is unavailable.',
    deleteTitle: 'Delete permanently?',
    deleteMessage: 'This cannot be undone.',
    emptyTrash: 'Empty trash',
    emptyTitle: 'Empty the trash?',
    emptyMessage:
        '{count} items will be deleted for good. This cannot be undone.',
    cancel: 'Cancel',
  );

  static const fr = TrashStrings(
    searchHint: 'Rechercher dans la corbeille',
    allFilter: 'Tout',
    empty: 'La corbeille est vide',
    noMatch: 'Rien dans la corbeille ne correspond à ces filtres',
    restore: 'Restaurer',
    deletePermanently: 'Supprimer définitivement',
    deleted: 'Supprimé le {date}',
    deletedWithDays: 'Supprimé le {date} · encore {days} jours',
    lastDay: 'Supprimé le {date} · effacé définitivement aujourd’hui',
    purging:
        'Suppression définitive en cours ; la restauration est indisponible.',
    deleteTitle: 'Supprimer définitivement ?',
    deleteMessage: 'Cette action est irréversible.',
    emptyTrash: 'Vider la corbeille',
    emptyTitle: 'Vider la corbeille ?',
    emptyMessage:
        '{count} éléments seront supprimés définitivement. Cette action est '
        'irréversible.',
    cancel: 'Annuler',
  );

  TrashStrings copyWith({
    String? searchHint,
    String? allFilter,
    String? empty,
    String? noMatch,
    String? restore,
    String? deletePermanently,
    String? deleted,
    String? deletedWithDays,
    String? lastDay,
    String? purging,
    String? deleteTitle,
    String? deleteMessage,
    String? emptyTrash,
    String? emptyTitle,
    String? emptyMessage,
    String? cancel,
  }) => TrashStrings(
    searchHint: searchHint ?? this.searchHint,
    allFilter: allFilter ?? this.allFilter,
    empty: empty ?? this.empty,
    noMatch: noMatch ?? this.noMatch,
    restore: restore ?? this.restore,
    deletePermanently: deletePermanently ?? this.deletePermanently,
    deleted: deleted ?? this.deleted,
    deletedWithDays: deletedWithDays ?? this.deletedWithDays,
    lastDay: lastDay ?? this.lastDay,
    purging: purging ?? this.purging,
    deleteTitle: deleteTitle ?? this.deleteTitle,
    deleteMessage: deleteMessage ?? this.deleteMessage,
    emptyTrash: emptyTrash ?? this.emptyTrash,
    emptyTitle: emptyTitle ?? this.emptyTitle,
    emptyMessage: emptyMessage ?? this.emptyMessage,
    cancel: cancel ?? this.cancel,
  );
}
