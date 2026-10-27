import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_scheduler.dart';

/// What the system needs to know about the app to show its reminders.
@immutable
class LocalReminderConfig {
  const LocalReminderConfig({
    required this.appName,
    required this.windowsAppUserModelId,
    required this.windowsGuid,
    required this.androidChannelId,
    required this.androidChannelName,
    this.androidChannelDescription,
    this.androidIcon = '@mipmap/ic_launcher',
    this.windowsIconPath,
    this.firstId = 0x52470000,
    this.maxReminders = 32,
    this.onOpen,
  });

  /// Shown on Windows toasts.
  final String appName;

  /// `Company.Product`, unique to the app; registered for the current user.
  final String windowsAppUserModelId;

  /// A GUID of the app's own, the toast activator.
  final String windowsGuid;

  /// The Android channel, listed in the system settings of the app.
  final String androidChannelId;
  final String androidChannelName;
  final String? androidChannelDescription;

  /// Drawable or mipmap resource of the small icon.
  final String androidIcon;

  /// Absolute path of a `.png` or `.ico` for the toasts.
  final String? windowsIconPath;

  /// Ids `firstId` to `firstId + maxReminders - 1` belong to the
  /// reminders; anything else the app shows is left alone.
  final int firstId;
  final int maxReminders;

  /// Called with the payload when a reminder is opened.
  final ValueChanged<String?>? onOpen;
}

/// [ReminderScheduler] over `flutter_local_notifications`, on Windows and
/// Android. Windows cannot repeat a notification, so the app plans each one
/// over the coming days and plans again at every launch.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler(this.config, {FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final LocalReminderConfig config;
  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _windows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  bool get isSupported => _android || _windows;

  /// Initialises once; a failed run is forgotten so the next call retries.
  Future<void> _initialize() => _ready ??= _start().catchError((Object e) {
    _ready = null;
    throw e;
  });

  Future<void> _start() async {
    await _plugin.initialize(
      settings: InitializationSettings(
        android: AndroidInitializationSettings(config.androidIcon),
        windows: WindowsInitializationSettings(
          appName: config.appName,
          appUserModelId: config.windowsAppUserModelId,
          guid: config.windowsGuid,
          iconPath: config.windowsIconPath,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          config.onOpen?.call(response.payload),
    );
    await _androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        config.androidChannelId,
        config.androidChannelName,
        description: config.androidChannelDescription,
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _initialize();
    if (!_android) return true;
    return await _androidPlugin?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async {
    if (!isSupported) return;
    await _initialize();
    for (var i = 0; i < config.maxReminders; i++) {
      await _plugin.cancel(id: config.firstId + i);
    }
    final now = DateTime.now();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        config.androidChannelId,
        config.androidChannelName,
        channelDescription: config.androidChannelDescription,
      ),
      windows: const WindowsNotificationDetails(),
    );
    final upcoming = reminders.where((r) => r.at.isAfter(now)).toList();
    for (var i = 0; i < upcoming.length && i < config.maxReminders; i++) {
      final reminder = upcoming[i];
      await _plugin.zonedSchedule(
        id: config.firstId + i,
        title: reminder.title,
        body: reminder.body,
        payload: reminder.payload,
        // An exact instant: the local day and time were resolved already.
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
        notificationDetails: details,
        // No exact-alarm permission: a reminder may come a few minutes late.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
