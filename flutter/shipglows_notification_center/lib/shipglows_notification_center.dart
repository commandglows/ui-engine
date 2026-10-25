/// The notification center of the ShipGlows Flutter apps: the latest
/// lasting notifications (a new replay, a comment, a reminder), read or
/// unread, open, delete, « Mark all as read », « Delete all ». Not the
/// passing in-app messages of `shipglows_feedback`, though it can keep a
/// history of them.
///
/// - [NotificationStore]: where they live, plugged in by the app (backend,
///   local database); [CallbackNotificationStore] over an existing client,
///   [MemoryNotificationStore] for tests and demos.
/// - [NotificationCenterController]: list, loading, error, unread count,
///   actions shown at once and undone when the store fails.
/// - [NotificationCenterView]: the screen or panel body; [NotificationTile]
///   one row; [NotificationCenterActions] the app bar actions.
/// - [NotificationBadge] and [NotificationBellButton]: the unread count.
/// - [FeedbackHistory]: the in-app messages already shown, as a store.
/// - [NotificationStrings] and [NotificationStringsScope]: the app's texts.
library;

export 'src/feedback_history.dart';
export 'src/notification_badge.dart';
export 'src/notification_center_view.dart';
export 'src/notification_controller.dart';
export 'src/notification_item.dart';
export 'src/notification_store.dart';
export 'src/strings.dart';
