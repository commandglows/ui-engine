import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_icons/shipglows_icons.dart';

import 'daily_reminder_plan.dart';
import 'snooze_options.dart';

/// Texts of [SnoozeOptionsEditor] and [SnoozeButton]: [en], [fr] or the app's
/// own.
@immutable
class SnoozeStrings {
  const SnoozeStrings({
    this.title = 'Snooze options',
    this.help = 'Choices in every snooze menu, listed soonest first. Weekdays '
        'mean the next one after today.',
    this.after = 'In',
    this.at = 'at',
    this.minute = 'minute',
    this.minutes = 'minutes',
    this.hour = 'hour',
    this.hours = 'hours',
    this.day = 'day',
    this.days = 'days',
    this.today = 'Today',
    this.tomorrow = 'Tomorrow',
    this.thisMorning = 'This morning',
    this.thisAfternoon = 'This afternoon',
    this.thisEvening = 'This evening',
    this.nextWeek = 'Next week',
    this.weekdays = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ],
    this.shortWeekdays = const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ],
    this.passed = 'Already past today',
    this.menuNow = 'Menu now: {choices}',
    this.addOption = 'Add option',
    this.removeOption = 'Remove {option}',
    this.decrease = 'Less',
    this.increase = 'More',
    this.changeTime = 'Change {time}',
    this.snooze = 'Snooze',
  });

  static const en = SnoozeStrings();

  static const fr = SnoozeStrings(
    title: 'Options de report',
    help: 'Les choix de chaque menu de report, du plus proche au plus '
        'lointain. Un jour de la semaine désigne le prochain après '
        'aujourd’hui.',
    after: 'Dans',
    at: 'à',
    minute: 'minute',
    minutes: 'minutes',
    hour: 'heure',
    hours: 'heures',
    day: 'jour',
    days: 'jours',
    today: 'Aujourd’hui',
    tomorrow: 'Demain',
    thisMorning: 'Ce matin',
    thisAfternoon: 'Cet après-midi',
    thisEvening: 'Ce soir',
    nextWeek: 'La semaine prochaine',
    weekdays: [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ],
    shortWeekdays: ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'],
    passed: 'Déjà passé aujourd’hui',
    menuNow: 'Menu actuel : {choices}',
    addOption: 'Ajouter une option',
    removeOption: 'Retirer {option}',
    decrease: 'Moins',
    increase: 'Plus',
    changeTime: 'Changer {time}',
    snooze: 'Reporter',
  );

  final String title;
  final String help;

  /// The first word of a delay: « In 3 hours ».
  final String after;

  /// Between a day and its time: « Monday at 09:00 ».
  final String at;
  final String minute;
  final String minutes;
  final String hour;
  final String hours;
  final String day;
  final String days;
  final String today;
  final String tomorrow;
  final String thisMorning;
  final String thisAfternoon;
  final String thisEvening;
  final String nextWeek;

  /// Monday first, seven of each.
  final List<String> weekdays;
  final List<String> shortWeekdays;

  /// In place of the moment of an option that has passed.
  final String passed;

  /// `{choices}` stands for the labels the menu shows now.
  final String menuNow;
  final String addOption;

  /// Tooltips; `{option}` and `{time}` stand for the label and the time.
  final String removeOption;
  final String decrease;
  final String increase;
  final String changeTime;

  /// The tooltip of [SnoozeButton].
  final String snooze;

  /// The unit as it reads after [amount]: « hour », « hours ».
  String unit(SnoozeUnit unit, int amount) => switch (unit) {
    SnoozeUnit.minutes => amount == 1 ? minute : minutes,
    SnoozeUnit.hours => amount == 1 ? hour : hours,
    SnoozeUnit.days => amount == 1 ? day : days,
  };

  /// The name of a day, as in the day selector.
  String dayName(SnoozeDay day) => switch (day) {
    SnoozeDay.today => today,
    SnoozeDay.tomorrow => tomorrow,
    _ => weekdays[day.weekday! - 1],
  };

  /// What a person reads in the menu: « In 1 hour », « This evening »,
  /// « Tomorrow », « Next week » for Monday, otherwise the weekday.
  String label(SnoozeOption option) => switch (option) {
    SnoozeAfter(:final amount, unit: final u) =>
      '$after $amount ${unit(u, amount)}',
    SnoozeAt(day: SnoozeDay.today, :final time) =>
      time.hour < 12
          ? thisMorning
          : time.hour < 17
          ? thisAfternoon
          : thisEvening,
    SnoozeAt(day: SnoozeDay.monday) => nextWeek,
    SnoozeAt(:final day) => dayName(day),
  };
}

String _time(BuildContext context, ReminderTime time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: time.hour, minute: time.minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// The moment of [at] next to its label: the time, after the short weekday
/// when it is not today and the label does not already say the day.
String _moment(
  BuildContext context,
  SnoozeStrings strings,
  SnoozeOption option,
  DateTime at,
  DateTime now,
) {
  final time = _time(context, ReminderTime(at.hour, at.minute));
  final local = now.toLocal();
  final sameDay =
      at.year == local.year && at.month == local.month && at.day == local.day;
  final tomorrow = option is SnoozeAt && option.day == SnoozeDay.tomorrow;
  if (sameDay || tomorrow) return time;
  return '${strings.shortWeekdays[at.weekday - 1]} $time';
}

/// The settings of the snooze menus: one row per option (a delay, or a day and
/// a time) with the moment it means now, the menu as it reads now and « Add
/// option ». Holds no value: the app keeps [value] and saves what [onChanged]
/// gives, through `toJson` / `fromJson`.
class SnoozeOptionsEditor extends StatefulWidget {
  const SnoozeOptionsEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.strings = SnoozeStrings.en,
    this.now = DateTime.now,
  });

  final SnoozeOptions value;
  final ValueChanged<SnoozeOptions> onChanged;
  final SnoozeStrings strings;
  final DateTime Function() now;

  @override
  State<SnoozeOptionsEditor> createState() => _SnoozeOptionsEditorState();
}

class _SnoozeOptionsEditorState extends State<SnoozeOptionsEditor> {
  /// Below this width the moment goes under the row's controls.
  static const _narrow = 520.0;

  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Keeps « 16:33 » and the menu line true while the settings stay open.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = widget.strings;
    final value = widget.value;
    final now = widget.now();
    final moments = [for (final o in value.options) o.nextAt(now)];
    // Soonest first, what has passed last; the index keeps a row's identity
    // when an edit moves it.
    final order = [for (var i = 0; i < moments.length; i++) i]
      ..sort((a, b) {
        final at = moments[a];
        final other = moments[b];
        if (at == null || other == null) {
          if (at == null && other == null) return a - b;
          return at == null ? 1 : -1;
        }
        final compared = at.compareTo(other);
        return compared != 0 ? compared : a - b;
      });
    final choices = value.menu(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            strings.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(strings.help, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        for (final index in order)
          Padding(
            key: ValueKey('snooze-option-$index'),
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionRow(
              option: value.options[index],
              at: moments[index],
              now: now,
              strings: strings,
              narrowBelow: _narrow,
              onChanged: (next) =>
                  widget.onChanged(value.replacingAt(index, next)),
              onRemove: value.canRemove
                  ? () => widget.onChanged(value.removingAt(index))
                  : null,
            ),
          ),
        Semantics(
          liveRegion: true,
          child: Text(
            strings.menuNow.replaceAll(
              '{choices}',
              choices.map((c) => strings.label(c.option)).join(' · '),
            ),
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (value.canAdd)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('snooze-option-add'),
              onPressed: () => widget.onChanged(
                value.adding(const SnoozeAfter(30, SnoozeUnit.minutes)),
              ),
              icon: Icon(
                ShipglowsIcons.of(context, 'add') ?? ShipglowsIcons.add,
                size: 18,
              ),
              label: Text(strings.addOption),
            ),
          ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.at,
    required this.now,
    required this.strings,
    required this.narrowBelow,
    required this.onChanged,
    required this.onRemove,
  });

  /// The value of the day selector that stands for a delay.
  static const _afterKey = 'after';

  final SnoozeOption option;
  final DateTime? at;
  final DateTime now;
  final SnoozeStrings strings;
  final double narrowBelow;
  final ValueChanged<SnoozeOption> onChanged;
  final VoidCallback? onRemove;

  void _changeKind(String key) {
    if (key == _afterKey) {
      if (option is! SnoozeAfter) {
        onChanged(const SnoozeAfter(1, SnoozeUnit.hours));
      }
      return;
    }
    final day = SnoozeDay.values.byName(key);
    onChanged(
      SnoozeAt(
        day,
        switch (option) {
          SnoozeAt(:final time) => time,
          _ when day == SnoozeDay.today => const ReminderTime(18, 0),
          _ => const ReminderTime(9, 0),
        },
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, SnoozeAt option) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: option.time.hour,
        minute: option.time.minute,
      ),
    );
    if (picked != null) {
      onChanged(SnoozeAt(option.day, ReminderTime(picked.hour, picked.minute)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final option = this.option;
    final at = this.at;
    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Select<String>(
          value: switch (option) {
            SnoozeAfter() => _afterKey,
            SnoozeAt(:final day) => day.name,
          },
          label: strings.label(option),
          items: {
            _afterKey: strings.after,
            for (final day in SnoozeDay.values)
              day.name: strings.dayName(day),
          },
          onChanged: _changeKind,
        ),
        ...switch (option) {
          SnoozeAfter(:final amount, :final unit) => [
            _Stepper(
              amount: amount,
              label: strings.label(option),
              strings: strings,
              onChanged: (next) => onChanged(SnoozeAfter(next, unit)),
            ),
            _Select<SnoozeUnit>(
              value: unit,
              label: strings.label(option),
              items: {
                for (final u in SnoozeUnit.values) u: strings.unit(u, amount),
              },
              onChanged: (next) => onChanged(SnoozeAfter(amount, next)),
            ),
          ],
          SnoozeAt(:final time) => [
            Text(strings.at, style: theme.textTheme.bodySmall),
            Tooltip(
              message: strings.changeTime.replaceAll(
                '{time}',
                _time(context, time),
              ),
              child: OutlinedButton.icon(
                onPressed: () => _pickTime(context, option),
                icon: const Icon(Icons.schedule, size: 18),
                iconAlignment: IconAlignment.end,
                label: Text(_time(context, time)),
              ),
            ),
          ],
        },
      ],
    );
    final moment = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: strings.label(option),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const TextSpan(text: '  '),
          TextSpan(
            text: at == null
                ? strings.passed
                : _moment(context, strings, option, at, now),
          ),
        ],
      ),
      style: theme.textTheme.bodySmall,
    );
    final remove = IconButton(
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      tooltip: strings.removeOption.replaceAll(
        '{option}',
        strings.label(option),
      ),
      onPressed: onRemove,
      icon: Icon(
        ShipglowsIcons.of(context, 'close') ?? ShipglowsIcons.close,
        size: 18,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < narrowBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: controls),
                  remove,
                ],
              ),
              Padding(padding: const EdgeInsets.only(top: 4), child: moment),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: controls),
            const SizedBox(width: 12),
            moment,
            const SizedBox(width: 4),
            remove,
          ],
        );
      },
    );
  }
}

/// A selector drawn as an outlined field, sized to its longest item.
class _Select<T> extends StatelessWidget {
  const _Select({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final T value;

  /// The option this selector belongs to, for screen readers.
  final String label;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: _Outlined(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          items: [
            for (final MapEntry(:key, value: text) in items.entries)
              DropdownMenuItem(value: key, child: Text(text)),
          ],
          onChanged: (next) {
            if (next != null && next != value) onChanged(next);
          },
        ),
      ),
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.amount,
    required this.label,
    required this.strings,
    required this.onChanged,
  });

  final int amount;
  final String label;
  final SnoozeStrings strings;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    IconButton step(String tooltip, IconData icon, int? next) => IconButton(
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: next == null ? null : () => onChanged(next),
      icon: Icon(icon, size: 18),
    );
    return _Outlined(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          step(
            strings.decrease,
            ShipglowsIcons.of(context, 'remove') ?? ShipglowsIcons.remove,
            amount > SnoozeAfter.minAmount ? amount - 1 : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28),
            child: Semantics(
              label: label,
              liveRegion: true,
              excludeSemantics: true,
              child: Text('$amount', textAlign: TextAlign.center),
            ),
          ),
          step(
            strings.increase,
            ShipglowsIcons.of(context, 'add') ?? ShipglowsIcons.add,
            amount < SnoozeAfter.maxAmount ? amount + 1 : null,
          ),
        ],
      ),
    );
  }
}

class _Outlined extends StatelessWidget {
  const _Outlined({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

/// A snooze button: opens the [options] that still make sense now, soonest
/// first, and gives the chosen moment to [onSelected]. The app plans what comes
/// back at that moment.
class SnoozeButton extends StatelessWidget {
  const SnoozeButton({
    super.key,
    required this.options,
    required this.onSelected,
    this.strings = SnoozeStrings.en,
    this.now = DateTime.now,
  });

  final SnoozeOptions options;
  final ValueChanged<DateTime> onSelected;
  final SnoozeStrings strings;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => PopupMenuButton<DateTime>(
    tooltip: strings.snooze,
    icon: const Icon(Icons.snooze),
    onSelected: onSelected,
    // Computed at each opening: the moments follow the clock.
    itemBuilder: (context) {
      final at = now();
      return [
        for (final choice in options.menu(at))
          PopupMenuItem(
            value: choice.at,
            child: Row(
              children: [
                Expanded(child: Text(strings.label(choice.option))),
                const SizedBox(width: 24),
                Text(
                  _moment(context, strings, choice.option, choice.at, at),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ];
    },
  );
}
