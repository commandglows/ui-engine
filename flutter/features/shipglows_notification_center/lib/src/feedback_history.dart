import 'package:shipglows_feedback/shipglows_feedback.dart';

import 'notification_item.dart';
import 'notification_store.dart';

/// The in-app messages already shown (`shipglows_feedback`), newest first,
/// to see again an error that went by too fast: a [NotificationStore] for a
/// « Recent messages » [NotificationCenterView]. Kept in memory for the
/// session, at most [capacity].
///
/// Messages arrive read (they were on screen) unless their kind is in
/// [unreadKinds]: errors by default, so a badge can tell one was missed.
/// The details of an error become the notification's body.
class FeedbackHistory extends MemoryNotificationStore {
  FeedbackHistory({
    super.capacity,
    this.unreadKinds = const {FeedbackKind.error},
    this.kinds = const {
      FeedbackKind.info,
      FeedbackKind.success,
      FeedbackKind.warning,
      FeedbackKind.error,
    },
  });

  /// Kinds that arrive unread.
  final Set<FeedbackKind> unreadKinds;

  /// Kinds kept; the others are ignored.
  final Set<FeedbackKind> kinds;

  int _next = 0;
  bool _attached = false;

  /// Starts recording [FeedbackLog]; again does nothing.
  void attach() {
    if (_attached) return;
    _attached = true;
    FeedbackLog.addListener(_record);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    FeedbackLog.removeListener(_record);
  }

  void _record(FeedbackRecord record) {
    if (!kinds.contains(record.kind)) return;
    add(
      NotificationItem(
        id: 'feedback-${_next++}',
        title: record.message,
        body: record.details,
        createdAt: record.shownAt,
        read: !unreadKinds.contains(record.kind),
        icon: record.kind.icon,
        kind: record.kind,
        payload: record,
      ),
    );
  }

  @override
  Future<void> close() {
    detach();
    return super.close();
  }
}
