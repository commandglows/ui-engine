import 'package:flutter/widgets.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';

/// One notification as the center shows it. The app maps its own record
/// (a server row, a local event) to it and keeps that record in [payload]
/// for « open ».
@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.createdAt,
    this.body,
    this.read = false,
    this.icon,
    this.kind,
    this.source,
    this.count,
    this.payload,
  });

  /// Stable identity, the one the store marks read and deletes.
  final String id;
  final String title;

  /// Second line, shortened on screen, read in full by a screen reader.
  final String? body;
  final DateTime createdAt;
  final bool read;

  /// Icon of its type (new replay, comment, reminder); the bell by default.
  final IconData? icon;

  /// Tints the icon with the kind's color: an error, a success. Neutral
  /// (the accent) when null.
  final FeedbackKind? kind;

  /// Where it comes from (an account, a channel, a project): shown over
  /// the title and offered as a filter when there are several.
  final String? source;

  /// A live counter the row stands for (« 12 new messages »), shown at the
  /// end of the row.
  final int? count;

  /// The app's own record, handed back by « open ».
  final Object? payload;

  NotificationItem copyWith({bool? read}) => NotificationItem(
    id: id,
    title: title,
    createdAt: createdAt,
    body: body,
    read: read ?? this.read,
    icon: icon,
    kind: kind,
    source: source,
    count: count,
    payload: payload,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationItem &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.createdAt == createdAt &&
      other.read == read &&
      other.icon == icon &&
      other.kind == kind &&
      other.source == source &&
      other.count == count &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    body,
    createdAt,
    read,
    icon,
    kind,
    source,
    count,
    payload,
  );
}
