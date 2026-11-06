import 'package:flutter/foundation.dart';
import 'package:shipglows_date_sections/shipglows_date_sections.dart';

/// Every text of the dialog. Use [fr] or [en], or build your own.
@immutable
class BulkDeleteStrings {
  /// Creates the texts of one language.
  const BulkDeleteStrings({
    required this.title,
    required this.what,
    required this.when,
    required this.lastWeek,
    required this.includeOneProtected,
    required this.includeManyProtected,
    required this.warning,
    required this.cancel,
    required this.nothing,
    required this.deleteOne,
    required this.deleteMany,
    required this.dates,
  });

  /// French.
  static const fr = BulkDeleteStrings(
    title: 'Supprimer des éléments',
    what: 'Quoi',
    when: 'Depuis quand',
    lastWeek: 'Dernière semaine',
    includeOneProtected: 'Inclure l’élément épinglé',
    includeManyProtected: 'Inclure les {n} éléments épinglés',
    warning: 'Tu ne pourras pas les récupérer depuis l’app.',
    cancel: 'Annuler',
    nothing: 'Rien à supprimer',
    deleteOne: 'Supprimer 1 élément',
    deleteMany: 'Supprimer {n} éléments',
    dates: DateStrings.fr,
  );

  /// English.
  static const en = BulkDeleteStrings(
    title: 'Delete items',
    what: 'What',
    when: 'Since when',
    lastWeek: 'Last week',
    includeOneProtected: 'Include the pinned item',
    includeManyProtected: 'Include the {n} pinned items',
    warning: 'You won’t be able to get them back from the app.',
    cancel: 'Cancel',
    nothing: 'Nothing to delete',
    deleteOne: 'Delete 1 item',
    deleteMany: 'Delete {n} items',
    dates: DateStrings.en,
  );

  /// Dialog title.
  final String title;

  /// Heading of the types.
  final String what;

  /// Heading of the periods.
  final String when;

  /// The seven-day choice of the default periods.
  final String lastWeek;

  /// Switch for one pinned item.
  final String includeOneProtected;

  /// Switch for several pinned items, with `{n}`.
  final String includeManyProtected;

  /// Line above the buttons.
  final String warning;

  /// Button that closes without deleting.
  final String cancel;

  /// Disabled confirm button when the choices match nothing.
  final String nothing;

  /// Confirm button for one item.
  final String deleteOne;

  /// Confirm button for several items, with `{n}`.
  final String deleteMany;

  /// Texts of the period chips.
  final DateStrings dates;
}
