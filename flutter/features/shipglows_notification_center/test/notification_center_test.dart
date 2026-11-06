import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';
import 'package:shipglows_notification_center/shipglows_notification_center.dart';

final _now = DateTime(2026, 10, 25, 12);

NotificationItem _item(String id, {bool read = false, int minutes = 5}) =>
    NotificationItem(
      id: id,
      title: 'Title $id',
      createdAt: _now.subtract(Duration(minutes: minutes)),
      read: read,
    );

Future<NotificationCenterController> _pump(
  WidgetTester tester,
  NotificationStore store,
) async {
  final controller = NotificationCenterController(store: store);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NotificationCenterView(
          controller: controller,
          now: () => _now,
          showToolbar: true,
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  testWidgets('lists the notifications with how long ago and the count', (
    tester,
  ) async {
    final store = MemoryNotificationStore(
      initial: [_item('a'), _item('b', read: true, minutes: 90)],
    );
    final controller = await _pump(tester, store);

    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('5 min ago'), findsOneWidget);
    expect(find.text('1 h ago'), findsOneWidget);
    expect(find.text('1 unread'), findsOneWidget);
    expect(controller.unreadCount, 1);
  });

  testWidgets('mark all as read clears the count', (tester) async {
    final store = MemoryNotificationStore(initial: [_item('a'), _item('b')]);
    final controller = await _pump(tester, store);

    await tester.tap(find.text('Mark all as read'));
    await tester.pump();

    expect(controller.unreadCount, 0);
    expect(find.text('All caught up'), findsOneWidget);
    expect(store.items.every((it) => it.read), isTrue);
  });

  testWidgets('a failed mark all as read comes back unread', (tester) async {
    final store = MemoryNotificationStore(initial: [_item('a')])
      ..failWith = StateError('offline');
    final controller = await _pump(tester, store);

    await tester.tap(find.text('Mark all as read'));
    await tester.pump();

    expect(controller.unreadCount, 1);
    expect(find.text('Could not mark as read'), findsOneWidget);
  });

  testWidgets('delete all asks first', (tester) async {
    final store = MemoryNotificationStore(initial: [_item('a'), _item('b')]);
    await _pump(tester, store);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all').last);
    await tester.pumpAndSettle();
    expect(find.text('Delete all notifications?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete all'));
    await tester.pumpAndSettle();

    expect(store.items, isEmpty);
    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('without delete, no delete buttons and no menu', (tester) async {
    final store = CallbackNotificationStore(
      watch: () => Stream.value([_item('a')]),
      markRead: (_) async {},
      markAllRead: (_) async {},
    );
    await _pump(tester, store);

    expect(find.byTooltip('Delete'), findsNothing);
    expect(find.byTooltip('More actions'), findsNothing);
  });

  testWidgets('a load error shows the error state', (tester) async {
    final store = CallbackNotificationStore(
      watch: () => Stream.error(StateError('down')),
      markRead: (_) async {},
      markAllRead: (_) async {},
    );
    await _pump(tester, store);

    expect(find.text('Could not load the notifications'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  test('the feedback history keeps the messages shown', () {
    final history = FeedbackHistory()..attach();
    addTearDown(history.close);

    FeedbackLog.record(
      FeedbackRecord(
        message: 'Could not save',
        kind: FeedbackKind.error,
        shownAt: _now,
      ),
    );
    FeedbackLog.record(
      FeedbackRecord(message: 'Saved', kind: FeedbackKind.success, shownAt: _now),
    );

    expect(history.items.map((it) => it.title), contains('Could not save'));
    expect(history.items.where((it) => !it.read).single.title, 'Could not save');
  });
}
