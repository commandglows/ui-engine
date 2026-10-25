import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notification_item.dart';
import 'notification_store.dart';

/// The action that failed, for `NotificationCenterView.onError`.
enum NotificationOperation { markRead, markAllRead, delete, deleteAll }

/// The center's state over a [NotificationStore]: the list, loading and
/// error, the unread count. Actions show at once (read, gone) and come back
/// when the store fails; the store's next list confirms them.
///
/// Create it once per screen or panel and [dispose] it; [unreadCount] also
/// feeds a [NotificationBadge] while it lives.
class NotificationCenterController extends ChangeNotifier {
  NotificationCenterController({required this.store}) {
    _listen();
  }

  final NotificationStore store;

  StreamSubscription<List<NotificationItem>>? _subscription;
  bool _streamDone = false;
  List<NotificationItem>? _snapshot;
  Object? _error;
  StackTrace? _stackTrace;
  final Set<String> _pendingRead = {};
  final Set<String> _pendingDeleted = {};
  bool _unreadOnly = false;
  String? _source;
  bool _markingAllRead = false;
  bool _deletingAll = false;
  bool _disposed = false;

  void _listen() {
    _streamDone = false;
    _subscription = store.watch().listen(
      _onList,
      onError: (Object error, StackTrace stackTrace) {
        _error = error;
        _stackTrace = stackTrace;
        _notify();
      },
      onDone: () => _streamDone = true,
    );
  }

  void _onList(List<NotificationItem> list) {
    _snapshot = list;
    _error = null;
    _stackTrace = null;
    final byId = {for (final item in list) item.id: item};
    _pendingRead.removeWhere((id) => byId[id]?.read ?? true);
    _pendingDeleted.removeWhere((id) => !byId.containsKey(id));
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Every notification, newest first, with the actions in flight applied,
  /// before the filters.
  List<NotificationItem> get allItems => [
    for (final item in _snapshot ?? const <NotificationItem>[])
      if (!_pendingDeleted.contains(item.id))
        _pendingRead.contains(item.id) && !item.read
            ? item.copyWith(read: true)
            : item,
  ];

  /// The notifications shown: [allItems] through [unreadOnly] and
  /// [source]. The global actions work on these.
  List<NotificationItem> get items => [
    for (final item in allItems)
      if ((!_unreadOnly || !item.read) &&
          (_source == null || item.source == _source))
        item,
  ];

  /// Shows the unread ones only.
  bool get unreadOnly => _unreadOnly;
  set unreadOnly(bool value) {
    if (value == _unreadOnly) return;
    _unreadOnly = value;
    _notify();
  }

  /// Shows one source only; null for all.
  String? get source => _source;
  set source(String? value) {
    if (value == _source) return;
    _source = value;
    _notify();
  }

  /// The sources of [allItems], in order of first appearance.
  List<String> get sources => [
    ...{
      for (final item in allItems)
        if (item.source case final source?) source,
    },
  ];

  /// No list yet and no error.
  bool get isLoading => _snapshot == null && _error == null;

  /// Whether a list came at least once.
  bool get hasLoaded => _snapshot != null;

  /// The last load error, cleared by the next list.
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;

  /// Unread among [allItems], whatever the filters: the badge's count.
  int get unreadCount => allItems.where((item) => !item.read).length;

  /// Unread among the [items] shown.
  int get shownUnreadCount => items.where((item) => !item.read).length;

  bool get markingAllRead => _markingAllRead;
  bool get deletingAll => _deletingAll;

  bool get canDelete => store.canDelete;
  bool get canDeleteAll => store.canDeleteAll;

  /// Clears the error and loads again.
  Future<void> retry() async {
    _error = null;
    _stackTrace = null;
    _notify();
    if (_streamDone) {
      await _subscription?.cancel();
      _listen();
    }
    await store.refresh();
  }

  /// Marks [id] read; does nothing when it already is.
  Future<void> markRead(String id) async {
    final item = allItems.where((it) => it.id == id).firstOrNull;
    if (item == null || item.read) return;
    _pendingRead.add(id);
    _notify();
    try {
      await store.markRead(id);
    } catch (_) {
      _pendingRead.remove(id);
      _notify();
      rethrow;
    }
  }

  /// Marks read every unread notification shown.
  Future<void> markAllRead() async {
    final ids = [
      for (final item in items)
        if (!item.read) item.id,
    ];
    if (ids.isEmpty || _markingAllRead) return;
    _markingAllRead = true;
    _pendingRead.addAll(ids);
    _notify();
    try {
      await store.markAllRead(ids);
    } catch (_) {
      _pendingRead.removeAll(ids);
      rethrow;
    } finally {
      _markingAllRead = false;
      _notify();
    }
  }

  Future<void> delete(String id) async {
    _pendingDeleted.add(id);
    _notify();
    try {
      await store.delete(id);
    } catch (_) {
      _pendingDeleted.remove(id);
      _notify();
      rethrow;
    }
  }

  /// Deletes every notification shown.
  Future<void> deleteAll() async {
    final ids = [for (final item in items) item.id];
    if (ids.isEmpty || _deletingAll) return;
    _deletingAll = true;
    _pendingDeleted.addAll(ids);
    _notify();
    try {
      await store.deleteAll(ids);
    } catch (_) {
      _pendingDeleted.removeAll(ids);
      rethrow;
    } finally {
      _deletingAll = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
