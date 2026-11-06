class CreatorProfile {
  final String id;
  final String userId;
  final String? projectId;
  final String? displayName;
  final Map<String, dynamic>? voice;
  final Map<String, dynamic>? positioning;
  final List<String> values;
  final String? currentChapterId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreatorProfile({
    required this.id,
    required this.userId,
    this.projectId,
    this.displayName,
    this.voice,
    this.positioning,
    this.values = const [],
    this.currentChapterId,
    required this.createdAt,
    required this.updatedAt,
  });

  CreatorProfile copyWith({
    String? id,
    String? userId,
    String? projectId,
    String? displayName,
    Map<String, dynamic>? voice,
    bool clearVoice = false,
    Map<String, dynamic>? positioning,
    bool clearPositioning = false,
    List<String>? values,
    String? currentChapterId,
  }) {
    return CreatorProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      displayName: displayName ?? this.displayName,
      voice: clearVoice ? null : (voice ?? this.voice),
      positioning: clearPositioning ? null : (positioning ?? this.positioning),
      values: values ?? this.values,
      currentChapterId: currentChapterId ?? this.currentChapterId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory CreatorProfile.fromJson(Map<String, dynamic> json) {
    return CreatorProfile(
      id: json['id'] as String,
      userId: json['userId'] as String,
      projectId: json['projectId'] as String?,
      displayName: json['displayName'] as String?,
      voice: json['voice'] as Map<String, dynamic>?,
      positioning: json['positioning'] as Map<String, dynamic>?,
      values: (json['values'] as List<dynamic>?)?.cast<String>() ?? const [],
      currentChapterId: json['currentChapterId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'projectId': projectId,
      'displayName': displayName,
      'voice': voice,
      'positioning': positioning,
      'values': values,
      'currentChapterId': currentChapterId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
