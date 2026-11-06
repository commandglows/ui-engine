enum FeedbackEntryType { text, audio }

enum FeedbackEntryStatus { newEntry, reviewed }

enum FeedbackAdminStatusFilter { all, unread, reviewed }

enum FeedbackAdminTypeFilter { all, text, audio }

class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.type,
    required this.platform,
    required this.locale,
    required this.createdAt,
    required this.status,
    this.message,
    this.audioStorageId,
    this.audioUrl,
    this.durationMs,
    this.userId,
    this.userEmail,
  });

  final String id;
  final FeedbackEntryType type;
  final String? message;
  final String? audioStorageId;
  final String? audioUrl;
  final int? durationMs;
  final String platform;
  final String locale;
  final String? userId;
  final String? userEmail;
  final DateTime createdAt;
  final FeedbackEntryStatus status;

  bool get isAudio => type == FeedbackEntryType.audio;
  bool get isText => type == FeedbackEntryType.text;

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) {
    return FeedbackEntry(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: _feedbackEntryTypeFromString(
        json['type']?.toString() ?? json['entry_type']?.toString(),
      ),
      message: json['message']?.toString(),
      audioStorageId:
          json['audioStorageId']?.toString() ??
          json['audio_storage_id']?.toString(),
      audioUrl: json['audioUrl']?.toString() ?? json['audio_url']?.toString(),
      durationMs: _asInt(json['durationMs'] ?? json['duration_ms']),
      platform: (json['platform'] ?? 'unknown').toString(),
      locale: (json['locale'] ?? 'und').toString(),
      userId: json['userId']?.toString() ?? json['user_id']?.toString(),
      userEmail:
          json['userEmail']?.toString() ?? json['user_email']?.toString(),
      createdAt: _asDateTime(json['createdAt'] ?? json['created_at']),
      status: _feedbackEntryStatusFromString(
        json['status']?.toString() ?? json['entry_status']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'message': message,
      'audioStorageId': audioStorageId,
      'audioUrl': audioUrl,
      'durationMs': durationMs,
      'platform': platform,
      'locale': locale,
      'userId': userId,
      'userEmail': userEmail,
      'createdAt': createdAt.toIso8601String(),
      'status': status == FeedbackEntryStatus.newEntry ? 'new' : 'reviewed',
    };
  }
}

class FeedbackUploadTarget {
  const FeedbackUploadTarget({
    required this.uploadUrl,
    this.storageId,
    this.method = 'PUT',
    this.headers = const <String, String>{},
  });

  final String uploadUrl;
  final String? storageId;
  final String method;
  final Map<String, String> headers;

  factory FeedbackUploadTarget.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      rawHeaders.forEach((key, value) {
        if (key != null && value != null) {
          headers[key.toString()] = value.toString();
        }
      });
    }

    return FeedbackUploadTarget(
      uploadUrl:
          (json['uploadUrl'] ?? json['upload_url'] ?? '').toString(),
      storageId:
          json['storageId']?.toString() ?? json['storage_id']?.toString(),
      method: (json['method'] ?? 'PUT').toString().toUpperCase(),
      headers: headers,
    );
  }
}

class LocalFeedbackSubmission {
  const LocalFeedbackSubmission({
    required this.id,
    required this.type,
    required this.createdAt,
    this.messagePreview,
    this.durationMs,
  });

  final String id;
  final FeedbackEntryType type;
  final DateTime createdAt;
  final String? messagePreview;
  final int? durationMs;

  factory LocalFeedbackSubmission.fromJson(Map<String, dynamic> json) {
    return LocalFeedbackSubmission(
      id: (json['id'] ?? '').toString(),
      type: _feedbackEntryTypeFromString(json['type']?.toString()),
      createdAt: _asDateTime(json['createdAt']),
      messagePreview: json['messagePreview']?.toString(),
      durationMs: _asInt(json['durationMs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'messagePreview': messagePreview,
      'durationMs': durationMs,
    };
  }
}

class FeedbackAdminQuery {
  const FeedbackAdminQuery({
    this.status = FeedbackAdminStatusFilter.all,
    this.type = FeedbackAdminTypeFilter.all,
  });

  final FeedbackAdminStatusFilter status;
  final FeedbackAdminTypeFilter type;

  String? get statusParam => switch (status) {
    FeedbackAdminStatusFilter.all => null,
    FeedbackAdminStatusFilter.unread => 'new',
    FeedbackAdminStatusFilter.reviewed => 'reviewed',
  };

  String? get typeParam => switch (type) {
    FeedbackAdminTypeFilter.all => null,
    FeedbackAdminTypeFilter.text => 'text',
    FeedbackAdminTypeFilter.audio => 'audio',
  };

  @override
  bool operator ==(Object other) {
    return other is FeedbackAdminQuery &&
        other.status == status &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(status, type);
}

FeedbackEntryType _feedbackEntryTypeFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'audio':
      return FeedbackEntryType.audio;
    case 'text':
    default:
      return FeedbackEntryType.text;
  }
}

FeedbackEntryStatus _feedbackEntryStatusFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'reviewed':
      return FeedbackEntryStatus.reviewed;
    case 'new':
    default:
      return FeedbackEntryStatus.newEntry;
  }
}

DateTime _asDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
