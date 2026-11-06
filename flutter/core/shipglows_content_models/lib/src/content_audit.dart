class AuditActor {
  final String actorType;
  final String actorId;
  final String actorLabel;
  final Map<String, dynamic>? actorMetadata;

  const AuditActor({
    required this.actorType,
    required this.actorId,
    required this.actorLabel,
    this.actorMetadata,
  });

  factory AuditActor.fromJson(Map<String, dynamic> json) {
    return AuditActor(
      actorType: (json['actor_type'] ?? 'unknown').toString(),
      actorId: (json['actor_id'] ?? json['changed_by'] ?? json['edited_by'] ?? 'unknown')
          .toString(),
      actorLabel: (json['actor_label'] ?? json['actor_id'] ?? json['changed_by'] ?? json['edited_by'] ?? 'unknown')
          .toString(),
      actorMetadata: json['actor_metadata'] is Map<String, dynamic>
          ? json['actor_metadata'] as Map<String, dynamic>
          : null,
    );
  }
}

class ContentStatusChange {
  final String id;
  final String contentId;
  final String fromStatus;
  final String toStatus;
  final String changedBy;
  final AuditActor actor;
  final String? reason;
  final DateTime timestamp;

  const ContentStatusChange({
    required this.id,
    required this.contentId,
    required this.fromStatus,
    required this.toStatus,
    required this.changedBy,
    required this.actor,
    required this.timestamp,
    this.reason,
  });

  factory ContentStatusChange.fromJson(Map<String, dynamic> json) {
    return ContentStatusChange(
      id: json['id'].toString(),
      contentId: json['content_id'].toString(),
      fromStatus: json['from_status'].toString(),
      toStatus: json['to_status'].toString(),
      changedBy: (json['changed_by'] ?? json['actor_id']).toString(),
      actor: AuditActor.fromJson(json),
      reason: json['reason']?.toString(),
      timestamp: DateTime.parse(json['timestamp'].toString()),
    );
  }
}

class ContentEditEvent {
  final String id;
  final String contentId;
  final String editedBy;
  final AuditActor actor;
  final String? editNote;
  final int previousVersion;
  final int newVersion;
  final DateTime createdAt;

  const ContentEditEvent({
    required this.id,
    required this.contentId,
    required this.editedBy,
    required this.actor,
    required this.previousVersion,
    required this.newVersion,
    required this.createdAt,
    this.editNote,
  });

  factory ContentEditEvent.fromJson(Map<String, dynamic> json) {
    return ContentEditEvent(
      id: json['id'].toString(),
      contentId: json['content_id'].toString(),
      editedBy: (json['edited_by'] ?? json['actor_id']).toString(),
      actor: AuditActor.fromJson(json),
      editNote: json['edit_note']?.toString(),
      previousVersion: (json['previous_version'] as num?)?.toInt() ?? 0,
      newVersion: (json['new_version'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}

class ContentAuditTrail {
  final List<ContentStatusChange> transitions;
  final List<ContentEditEvent> edits;

  const ContentAuditTrail({
    required this.transitions,
    required this.edits,
  });

  bool get isEmpty => transitions.isEmpty && edits.isEmpty;
}
