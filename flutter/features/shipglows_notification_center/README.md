# shipglows_notification_center

The notification center: the latest lasting notifications (a new replay, a
comment, a reminder), read or unread, distinct from the passing messages of
`shipglows_feedback`. Depends on `shipglows_feedback`, `shipglows_icons`
and `shipglows_theme`, plus `flutter_local_notifications` and `timezone`
for the daily reminders; stores nothing itself.

- `NotificationStore` is the port the app plugs in, like the settings
  storage: `watch()` (newest first, again on every change), `refresh()`
  after an error, `markRead`, `markAllRead(ids)`, `delete`, `deleteAll(ids)`
  with `canDelete` / `canDeleteAll`, and `hasMore` / `loadMore()` for older
  pages (the longer list comes back through `watch()`).
  `CallbackNotificationStore` wraps an existing client (without `delete`
  the delete buttons and « Delete all » are hidden; without `deleteAll` it
  deletes one by one; without `loadMore` the list is one page);
  `MemoryNotificationStore` for tests, demos and device-only logs.
- `NotificationItem(id, title, body, createdAt, read, icon, kind,
  source, count, payload)`: the app maps its own record to it and gets it
  back in `payload` on « open »; `kind` (a `FeedbackKind`) tints the icon;
  `source` (an account, a channel) shows over the title; `count` stands for
  a live counter row (« 12 new »).
- `NotificationCenterController(store:)`: list, loading, error,
  `unreadCount`; read and delete show at once and come back when the store
  fails; `retry()`. Filters `unreadOnly` and `source` (`sources` lists
  them); `unreadCount` ignores the filters (the badge), the global actions
  work on the `items` shown. `hasMore`, `loadingMore` and `loadMore()`
  (one page at a time, until the store's next list). One per screen or
  panel, disposed with it.
- `NotificationCenterView(controller:, onOpen:, leadingBuilder:)`: the
  body: rows with the type's icon in a tinted circle (or the app's
  thumbnail through `leadingBuilder`, given the icon as fallback), the
  title bold when unread, the body, « 3 min ago » refreshed every minute
  (the medium date after four weeks, `formatDate:`), an unread dot, a
  44 px delete button. Over the list « 3 unread » / « All caught up »,
  announced on change. Opening marks read first. Empty state (`empty`,
  `emptyDescription`), `FeedbackErrorState` when loading fails (an inline
  error over a list already shown). `showToolbar: true` puts the summary
  and the actions over the list, for a panel without an app bar;
  `showFilters` (on by default) adds « Unread only » and, with several
  sources, one chip per source (from the CommunityGlows center). While
  the store `hasMore`, the list ends with a loader (`loadingMore` text)
  that asks for the next page once scrolled into view; a failure reaches
  `onError:` as `NotificationOperation.loadMore`.
- `NotificationCenterActions(controller:)`: « Mark all as read » and, when
  the store can, « Delete all » in a menu, confirmed (`confirm:` for the
  app's own dialog). Failed actions show an error message with « Copy
  details »; `onError:` (on the view and the actions) hears every failure
  for the app's log, the background read mark of an opened one included.
- `NotificationBadge(count:, child:)` (hidden at 0, « 99+ ») and
  `NotificationBellButton(count:, onPressed:)`, read « Notifications, 3
  unread notifications ».
- `FeedbackHistory()..attach()`: a store of the in-app messages already
  shown (`FeedbackLog` of `shipglows_feedback`), errors unread, their
  details as the body: a « Recent messages » center to see again an error
  that went by too fast.
- Texts: `NotificationStrings.en`, `.fr` (from the app locale), `copyWith`,
  `NotificationStringsScope` for the whole app.

```dart
final controller = NotificationCenterController(
  store: CallbackNotificationStore(
    watch: () => api.notifications().map((rows) => [
      for (final row in rows)
        NotificationItem(id: row.id, title: row.title,
            createdAt: row.createdAt, read: row.read, payload: row),
    ]),
    markRead: api.markRead,
    markAllRead: (_) => api.markAllRead(),
  ),
);

Scaffold(
  appBar: AppBar(actions: [NotificationCenterActions(controller: controller)]),
  body: NotificationCenterView(
    controller: controller,
    onOpen: (item) => open(item.payload! as Row),
  ),
);
```

### Daily reminders

System notifications (a Windows toast, an Android notification) at the
times the person chose, even while the app is closed. Off by default. Used by
DreamGlows (settings « Rappels »).

- `DailyReminderPlan(enabled:, times:)`: one to three `ReminderTime`s a
  day, sorted, the same every day; `withTime`, `withoutTime`, `replacing`;
  `toJson` / `fromJson` for the app's settings. No streak and no catching
  up: a missed reminder is gone. `upcoming(from, days:)` lists the next
  ones in local time, computed per calendar day (daylight saving never
  shifts them).
- `ReminderScheduler`: `isSupported`, `requestPermission()`,
  `replaceAll(reminders)`. `LocalReminderScheduler(LocalReminderConfig(…))`
  over `flutter_local_notifications` on Windows and Android (elsewhere
  unsupported); `MemoryReminderScheduler` for tests. Windows cannot repeat
  a notification, so each one is planned on its own over the next days
  (7 by default) and planned again at every launch. It owns ids `firstId`
  to `firstId + maxReminders - 1` only. On Android the alarms are inexact
  (no exact-alarm permission): a reminder may come a few minutes late.
- `DailyReminders(scheduler:, load:, save:, content:)`: `start()` once the
  app runs, `update(plan)` from the settings. Turning reminders on asks
  the system first (Android 13+); a refusal leaves them off with
  `permissionDenied`. `content(time)` gives title, body and payload.
- `DailyReminderSettings(reminders:, strings: ReminderStrings.fr)`: a
  switch, the times as chips (tap to change with the time picker, × to
  remove the extra ones), « Add a time » while under three.
- The app declares, once: for Windows, an `appUserModelId` and a GUID of
  its own (registered for the current user, no MSIX needed); for Android,
  core library desugaring in `build.gradle.kts`
  (`isCoreLibraryDesugaringEnabled = true`, `coreLibraryDesugaring(
  "com.android.tools:desugar_jdk_libs:2.1.5")`) and, in the manifest,
  `RECEIVE_BOOT_COMPLETED` with the plugin's `ScheduledNotificationReceiver`
  and `ScheduledNotificationBootReceiver` (see the plugin's README).

```dart
final reminders = DailyReminders(
  scheduler: LocalReminderScheduler(const LocalReminderConfig(
    appName: 'DreamGlows',
    windowsAppUserModelId: 'ShipGlows.DreamGlows',
    windowsGuid: '…',
    androidChannelId: 'dreamglows_reminders',
    androidChannelName: 'Rappels',
  )),
  load: settings.loadReminders,
  save: settings.saveReminders,
  content: (time) => (title: 'DreamGlows', body: 'Ton prochain pas ?', payload: null),
)..start();

DailyReminderSettings(reminders: reminders, strings: ReminderStrings.fr);
```
