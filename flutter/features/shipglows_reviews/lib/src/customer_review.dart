import 'dart:math';

import 'package:flutter/foundation.dart';

/// What a review is mainly about, so the team can sort them.
enum ReviewTopic {
  praise,
  idea,
  problem,
  other;

  /// [other] for an unknown or missing name: a newer app version may send
  /// a topic this one does not know.
  static ReviewTopic parse(Object? name) =>
      values.where((topic) => topic.name == name).firstOrNull ?? other;
}

/// Where the running copy of the app came from, as far as the device says.
enum InstallSource {
  googlePlay,
  appStore,
  testFlight,
  microsoftStore,

  /// The app's own installer or APK (`shipglows_updater` releases).
  direct,
  web,
  unknown;

  static InstallSource parse(Object? name) =>
      values.where((source) => source.name == name).firstOrNull ?? unknown;
}

/// A store where people can rate the app.
enum ReviewStore {
  googlePlay,
  appStore,
  microsoftStore;

  static ReviewStore? tryParse(Object? name) =>
      values.where((store) => store.name == name).firstOrNull;
}

/// Read on the device when the review is written, sent with it so the team
/// knows which version and system it is about. Nothing that identifies the
/// person: no device id, no IP, no account unless the app gives one.
@immutable
class ReviewContext {
  const ReviewContext({
    required this.appId,
    required this.platform,
    this.appVersion = '',
    this.buildNumber = '',
    this.locale = '',
    this.installSource = InstallSource.unknown,
  });

  /// The app's stable id (`commandglows`), the same on every platform.
  final String appId;

  /// `android`, `ios`, `macos`, `windows`, `linux` or `web`.
  final String platform;

  /// `1.4.2`; empty when unknown.
  final String appVersion;

  /// `45`; empty when unknown.
  final String buildNumber;

  /// BCP 47 tag of the app's locale (`fr-FR`).
  final String locale;
  final InstallSource installSource;

  Map<String, Object?> toJson() => {
    'appId': appId,
    'platform': platform,
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'locale': locale,
    'installSource': installSource.name,
  };

  static ReviewContext fromJson(Map<String, Object?> json) => ReviewContext(
    appId: _string(json['appId']),
    platform: _string(json['platform']),
    appVersion: _string(json['appVersion']),
    buildNumber: _string(json['buildNumber']),
    locale: _string(json['locale']),
    installSource: InstallSource.parse(json['installSource']),
  );

  @override
  bool operator ==(Object other) =>
      other is ReviewContext &&
      other.appId == appId &&
      other.platform == platform &&
      other.appVersion == appVersion &&
      other.buildNumber == buildNumber &&
      other.locale == locale &&
      other.installSource == installSource;

  @override
  int get hashCode => Object.hash(
    appId,
    platform,
    appVersion,
    buildNumber,
    locale,
    installSource,
  );
}

/// What the person fills in the review form, before it is sent.
@immutable
class ReviewDraft {
  const ReviewDraft({
    this.rating,
    this.topic = ReviewTopic.other,
    this.comment = '',
    this.email = '',
    this.publishConsent = false,
    this.publicName = '',
  });

  /// Longest message kept; the form counts down to it.
  static const maxCommentLength = 2000;

  /// Longest display name kept.
  static const maxPublicNameLength = 60;

  /// 1 to 5 stars, or `null` for a message without a rating.
  final int? rating;
  final ReviewTopic topic;
  final String comment;

  /// Where the team may answer; empty when the person gave none.
  final String email;

  /// The person agrees that the review is published as a testimonial (the
  /// app's site, its store page). Without it the review stays private.
  final bool publishConsent;

  /// The name shown under a published testimonial; empty keeps it anonymous.
  final String publicName;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool get hasRating => rating != null;
  bool get hasComment => comment.trim().isNotEmpty;

  /// An empty address is fine; a typed one must look like an address.
  bool get emailIsValid =>
      email.trim().isEmpty || _email.hasMatch(email.trim());

  /// A rating or a message, a well-formed address, a rating in range.
  bool get isValid =>
      (hasRating || hasComment) &&
      emailIsValid &&
      (rating == null || (rating! >= 1 && rating! <= 5));

  ReviewDraft copyWith({
    int? Function()? rating,
    ReviewTopic? topic,
    String? comment,
    String? email,
    bool? publishConsent,
    String? publicName,
  }) => ReviewDraft(
    rating: rating == null ? this.rating : rating(),
    topic: topic ?? this.topic,
    comment: comment ?? this.comment,
    email: email ?? this.email,
    publishConsent: publishConsent ?? this.publishConsent,
    publicName: publicName ?? this.publicName,
  );
}

/// A review as the backend receives it. Plain JSON (`toJson`), so a Convex
/// mutation, a Firestore document or a REST body takes it as it is.
///
/// [id] is made on the device: a review sent twice (a retry after a lost
/// answer) carries the same id, and the backend keeps one.
@immutable
class CustomerReview {
  const CustomerReview({
    required this.id,
    required this.createdAt,
    required this.context,
    this.rating,
    this.topic = ReviewTopic.other,
    this.comment = '',
    this.email,
    this.publishConsent = false,
    this.publicName,
    this.accountId,
  });

  /// [draft] trimmed and cut to its limits, the name dropped without consent.
  factory CustomerReview.fromDraft(
    ReviewDraft draft, {
    required ReviewContext context,
    required DateTime createdAt,
    String? accountId,
    Random? random,
  }) {
    final comment = draft.comment.trim();
    final email = draft.email.trim();
    final name = draft.publicName.trim();
    return CustomerReview(
      id: newReviewId(random),
      createdAt: createdAt.toUtc(),
      context: context,
      rating: draft.rating,
      topic: draft.topic,
      comment: comment.length > ReviewDraft.maxCommentLength
          ? comment.substring(0, ReviewDraft.maxCommentLength)
          : comment,
      email: email.isEmpty ? null : email,
      publishConsent: draft.publishConsent,
      publicName: !draft.publishConsent || name.isEmpty
          ? null
          : name.length > ReviewDraft.maxPublicNameLength
          ? name.substring(0, ReviewDraft.maxPublicNameLength)
          : name,
      accountId: accountId,
    );
  }

  final String id;

  /// UTC; sent as milliseconds since the epoch.
  final DateTime createdAt;
  final ReviewContext context;
  final int? rating;
  final ReviewTopic topic;
  final String comment;
  final String? email;
  final bool publishConsent;
  final String? publicName;

  /// The signed-in account, when the app gives one
  /// ([ShipglowsReviews.accountId]).
  final String? accountId;

  /// Absent values are left out rather than sent as `null` (Convex
  /// `v.optional` refuses `null`).
  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'rating': ?rating,
    'topic': topic.name,
    'comment': comment,
    'email': ?email,
    'publishConsent': publishConsent,
    'publicName': ?publicName,
    'accountId': ?accountId,
    ...context.toJson(),
  };

  /// `null` when [json] has no id or date: a damaged outbox entry is
  /// dropped rather than sent wrong.
  static CustomerReview? tryFromJson(Map<String, Object?> json) {
    final id = json['id'];
    final createdAt = json['createdAt'];
    if (id is! String || id.isEmpty || createdAt is! num) return null;
    final rating = json['rating'];
    return CustomerReview(
      id: id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAt.toInt(),
        isUtc: true,
      ),
      context: ReviewContext.fromJson(json),
      rating: rating is num && rating >= 1 && rating <= 5
          ? rating.toInt()
          : null,
      topic: ReviewTopic.parse(json['topic']),
      comment: _string(json['comment']),
      email: _optional(json['email']),
      publishConsent: json['publishConsent'] == true,
      publicName: _optional(json['publicName']),
      accountId: _optional(json['accountId']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CustomerReview &&
      other.id == id &&
      other.createdAt == createdAt &&
      other.context == context &&
      other.rating == rating &&
      other.topic == topic &&
      other.comment == comment &&
      other.email == email &&
      other.publishConsent == publishConsent &&
      other.publicName == publicName &&
      other.accountId == accountId;

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    context,
    rating,
    topic,
    comment,
    email,
    publishConsent,
    publicName,
    accountId,
  );
}

/// 32 hex characters (128 random bits).
String newReviewId([Random? random]) {
  final source = random ?? Random.secure();
  return List.generate(
    16,
    (_) => source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String _string(Object? value) => value is String ? value : '';

String? _optional(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
