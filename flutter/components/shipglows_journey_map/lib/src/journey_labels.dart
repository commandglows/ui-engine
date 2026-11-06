import 'package:flutter/widgets.dart';

import 'journey_model.dart';

/// Every user-facing and spoken string of the map, so apps can localise it
/// without the package depending on an i18n framework.
///
/// Templates use `{title}`, `{count}`, `{index}` and `{total}` placeholders.
@immutable
class JourneyMapLabels {
  /// Creates a label set; the defaults are English.
  const JourneyMapLabels({
    this.done = 'done',
    this.current = 'current',
    this.upcoming = 'upcoming',
    this.neutral = '',
    this.empty = 'Nothing here yet.',
    this.emptyChapter = 'Nothing in this chapter yet.',
    this.loading = 'Loading',
    this.error = 'Could not load the map.',
    this.retry = 'Try again',
    this.untitled = 'Untitled',
    this.chapter = '{title}, {count} stops',
    this.position = '{index} of {total}',
  });

  /// English labels.
  static const JourneyMapLabels en = JourneyMapLabels();

  /// French labels.
  static const JourneyMapLabels fr = JourneyMapLabels(
    done: 'terminé',
    current: 'en cours',
    upcoming: 'à venir',
    empty: 'Rien ici pour le moment.',
    emptyChapter: 'Rien dans ce chapitre pour le moment.',
    loading: 'Chargement',
    error: 'La carte n’a pas pu être chargée.',
    retry: 'Réessayer',
    untitled: 'Sans titre',
    chapter: '{title}, {count} repères',
    position: '{index} sur {total}',
  );

  /// Labels for [locale]'s language, English when it is not supported.
  static JourneyMapLabels forLocale(Locale locale) =>
      locale.languageCode == 'fr' ? fr : en;

  /// Spoken name of [JourneyNodeState.done].
  final String done;

  /// Spoken name of [JourneyNodeState.current].
  final String current;

  /// Spoken name of [JourneyNodeState.upcoming].
  final String upcoming;

  /// Spoken name of [JourneyNodeState.neutral]; empty adds nothing.
  final String neutral;

  /// Shown when there are no chapters.
  final String empty;

  /// Shown under a chapter header that has no nodes.
  final String emptyChapter;

  /// Spoken while loading.
  final String loading;

  /// Shown when loading failed.
  final String error;

  /// Retry button text.
  final String retry;

  /// Fallback for an empty node or chapter title.
  final String untitled;

  /// Spoken chapter header: `{title}`, `{count}`.
  final String chapter;

  /// Spoken position of a node in its chapter: `{index}`, `{total}`.
  final String position;

  /// Spoken name of [state]; may be empty.
  String stateName(JourneyNodeState state) => switch (state) {
    JourneyNodeState.done => done,
    JourneyNodeState.current => current,
    JourneyNodeState.upcoming => upcoming,
    JourneyNodeState.neutral => neutral,
  };

  /// Copy with some strings replaced.
  JourneyMapLabels copyWith({
    String? done,
    String? current,
    String? upcoming,
    String? neutral,
    String? empty,
    String? emptyChapter,
    String? loading,
    String? error,
    String? retry,
    String? untitled,
    String? chapter,
    String? position,
  }) => JourneyMapLabels(
    done: done ?? this.done,
    current: current ?? this.current,
    upcoming: upcoming ?? this.upcoming,
    neutral: neutral ?? this.neutral,
    empty: empty ?? this.empty,
    emptyChapter: emptyChapter ?? this.emptyChapter,
    loading: loading ?? this.loading,
    error: error ?? this.error,
    retry: retry ?? this.retry,
    untitled: untitled ?? this.untitled,
    chapter: chapter ?? this.chapter,
    position: position ?? this.position,
  );

  /// Fills `{name}` placeholders of [template].
  static String fill(String template, Map<String, Object> values) {
    var out = template;
    values.forEach((key, value) => out = out.replaceAll('{$key}', '$value'));
    return out;
  }
}
