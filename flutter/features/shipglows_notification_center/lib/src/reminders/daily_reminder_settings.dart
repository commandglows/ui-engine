import 'package:flutter/material.dart';

import 'daily_reminder_plan.dart';
import 'daily_reminders.dart';

/// Texts of [DailyReminderSettings]: [en], [fr] or the app's own.
@immutable
class ReminderStrings {
  const ReminderStrings({
    this.enable = 'Daily reminders',
    this.enableHelp = 'A notification at the times you choose, even when '
        'the app is closed.',
    this.limit = 'Up to 3 a day. No streak: a missed reminder is simply '
        'gone.',
    this.addTime = 'Add a time',
    this.changeTime = 'Change {time}',
    this.removeTime = 'Remove {time}',
    this.permissionDenied = 'Notifications are blocked for this app. Allow '
        'them in the system settings, then try again.',
    this.failed = 'The reminders could not be planned.',
    this.unsupported = 'Reminders are not available on this device.',
  });

  static const en = ReminderStrings();

  static const fr = ReminderStrings(
    enable: 'Rappels quotidiens',
    enableHelp: 'Une notification aux heures choisies, même app fermée.',
    limit: 'Jusqu’à 3 par jour. Pas de série : un rappel manqué est '
        'simplement passé.',
    addTime: 'Ajouter une heure',
    changeTime: 'Changer {time}',
    removeTime: 'Retirer {time}',
    permissionDenied: 'Les notifications sont bloquées pour cette app. '
        'Autorise-les dans les réglages du système, puis réessaie.',
    failed: 'Les rappels n’ont pas pu être programmés.',
    unsupported: 'Les rappels ne sont pas disponibles sur cet appareil.',
  );

  final String enable;
  final String enableHelp;

  /// Under the times.
  final String limit;
  final String addTime;

  /// Tooltips and labels; `{time}` stands for the time.
  final String changeTime;
  final String removeTime;

  final String permissionDenied;
  final String failed;
  final String unsupported;
}

/// The settings of [DailyReminders]: a switch, then the times as chips
/// (tap to change, × to remove) and « Add a time » while there is room.
class DailyReminderSettings extends StatelessWidget {
  const DailyReminderSettings({
    super.key,
    required this.reminders,
    this.strings = ReminderStrings.en,
  });

  final DailyReminders reminders;
  final ReminderStrings strings;

  Future<ReminderTime?> _pick(BuildContext context, ReminderTime initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    return picked == null ? null : ReminderTime(picked.hour, picked.minute);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: reminders,
    builder: (context, _) {
      final theme = Theme.of(context);
      if (!reminders.isSupported) {
        return Text(strings.unsupported, style: theme.textTheme.bodyMedium);
      }
      final plan = reminders.plan;
      final localizations = MaterialLocalizations.of(context);
      String label(ReminderTime time) => localizations.formatTimeOfDay(
        TimeOfDay(hour: time.hour, minute: time.minute),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
      final problem = reminders.permissionDenied
          ? strings.permissionDenied
          : reminders.error != null
          ? strings.failed
          : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            key: const ValueKey('daily-reminders-enabled'),
            contentPadding: EdgeInsets.zero,
            title: Text(strings.enable),
            subtitle: Text(strings.enableHelp),
            value: plan.enabled,
            onChanged: (on) => reminders.update(plan.copyWith(enabled: on)),
          ),
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      problem,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (plan.enabled) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final time in plan.times)
                  InputChip(
                    key: ValueKey('daily-reminder-${time.id}'),
                    avatar: const Icon(Icons.notifications_outlined),
                    label: Text(label(time)),
                    tooltip: strings.changeTime.replaceAll(
                      '{time}',
                      label(time),
                    ),
                    onPressed: () async {
                      final next = await _pick(context, time);
                      if (next != null) {
                        await reminders.update(plan.replacing(time, next));
                      }
                    },
                    onDeleted: plan.times.length > 1
                        ? () => reminders.update(plan.withoutTime(time))
                        : null,
                    deleteButtonTooltipMessage: strings.removeTime.replaceAll(
                      '{time}',
                      label(time),
                    ),
                  ),
                if (plan.canAddTime)
                  TextButton.icon(
                    key: const ValueKey('daily-reminder-add'),
                    onPressed: () async {
                      final next = await _pick(
                        context,
                        ReminderTime((plan.times.last.hour + 4) % 24, 0),
                      );
                      if (next != null) {
                        await reminders.update(plan.withTime(next));
                      }
                    },
                    icon: const Icon(Icons.add_alarm),
                    label: Text(strings.addTime),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(strings.limit, style: theme.textTheme.bodySmall),
          ],
        ],
      );
    },
  );
}
