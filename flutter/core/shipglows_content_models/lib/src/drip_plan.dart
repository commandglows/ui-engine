class DripPlan {
  const DripPlan({
    required this.id,
    required this.userId,
    this.projectId,
    required this.name,
    required this.status,
    this.cadenceConfig = const {},
    this.clusterStrategy = const {},
    this.ssgConfig = const {},
    this.gscConfig,
    this.totalItems = 0,
    this.startedAt,
    this.completedAt,
    this.lastDripAt,
    this.nextDripAt,
    this.scheduleJobId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String? projectId;
  final String name;
  final String status;
  final Map<String, dynamic> cadenceConfig;
  final Map<String, dynamic> clusterStrategy;
  final Map<String, dynamic> ssgConfig;
  final Map<String, dynamic>? gscConfig;
  final int totalItems;
  final String? startedAt;
  final String? completedAt;
  final String? lastDripAt;
  final String? nextDripAt;
  final String? scheduleJobId;
  final String? createdAt;
  final String? updatedAt;

  // ─── Computed helpers ────────────────────────────

  String get cadenceMode => cadenceConfig['mode'] as String? ?? 'fixed';
  int get itemsPerDay => cadenceConfig['items_per_day'] as int? ?? 3;
  String get startDate => cadenceConfig['start_date'] as String? ?? '';
  String get clusterMode => clusterStrategy['mode'] as String? ?? 'directory';
  String get ssgFramework => ssgConfig['framework'] as String? ?? 'astro';
  String get rebuildMethod => ssgConfig['rebuild_method'] as String? ?? 'manual';

  bool get isDraft => status == 'draft';
  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isTerminal => isCompleted || isCancelled;

  factory DripPlan.fromJson(Map<String, dynamic> json) {
    return DripPlan(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      projectId: json['project_id'] as String?,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      cadenceConfig: _asMap(json['cadence_config']),
      clusterStrategy: _asMap(json['cluster_strategy']),
      ssgConfig: _asMap(json['ssg_config']),
      gscConfig: json['gsc_config'] != null ? _asMap(json['gsc_config']) : null,
      totalItems: json['total_items'] as int? ?? 0,
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
      lastDripAt: json['last_drip_at'] as String?,
      nextDripAt: json['next_drip_at'] as String?,
      scheduleJobId: json['schedule_job_id'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  DripPlan copyWith({
    String? id,
    String? userId,
    String? projectId,
    String? name,
    String? status,
    Map<String, dynamic>? cadenceConfig,
    Map<String, dynamic>? clusterStrategy,
    Map<String, dynamic>? ssgConfig,
    Map<String, dynamic>? gscConfig,
    int? totalItems,
    String? startedAt,
    String? completedAt,
    String? lastDripAt,
    String? nextDripAt,
    String? scheduleJobId,
    String? createdAt,
    String? updatedAt,
  }) {
    return DripPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      status: status ?? this.status,
      cadenceConfig: cadenceConfig ?? this.cadenceConfig,
      clusterStrategy: clusterStrategy ?? this.clusterStrategy,
      ssgConfig: ssgConfig ?? this.ssgConfig,
      gscConfig: gscConfig ?? this.gscConfig,
      totalItems: totalItems ?? this.totalItems,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      lastDripAt: lastDripAt ?? this.lastDripAt,
      nextDripAt: nextDripAt ?? this.nextDripAt,
      scheduleJobId: scheduleJobId ?? this.scheduleJobId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'project_id': projectId,
      'name': name,
      'status': status,
      'cadence_config': cadenceConfig,
      'cluster_strategy': clusterStrategy,
      'ssg_config': ssgConfig,
      'gsc_config': gscConfig,
      'total_items': totalItems,
      'started_at': startedAt,
      'completed_at': completedAt,
      'last_drip_at': lastDripAt,
      'next_drip_at': nextDripAt,
      'schedule_job_id': scheduleJobId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }
}

class DripStats {
  const DripStats({
    this.totalItems = 0,
    this.byStatus = const {},
    this.clusters = const [],
  });

  final int totalItems;
  final Map<String, int> byStatus;
  final List<DripClusterStat> clusters;

  int get published => byStatus['published'] ?? 0;
  int get scheduled => byStatus['scheduled'] ?? 0;
  int get approved => byStatus['approved'] ?? 0;
  double get progressPercent =>
      totalItems > 0 ? published / totalItems : 0.0;

  factory DripStats.fromJson(Map<String, dynamic> json) {
    final byStatus = <String, int>{};
    final raw = json['by_status'];
    if (raw is Map) {
      for (final e in raw.entries) {
        byStatus[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
      }
    }

    final clusters = <DripClusterStat>[];
    final rawClusters = json['clusters'];
    if (rawClusters is List) {
      for (final c in rawClusters) {
        if (c is Map<String, dynamic>) {
          clusters.add(DripClusterStat.fromJson(c));
        }
      }
    }

    return DripStats(
      totalItems: json['total_items'] as int? ?? 0,
      byStatus: byStatus,
      clusters: clusters,
    );
  }
}

class DripClusterStat {
  const DripClusterStat({
    required this.name,
    this.total = 0,
    this.byStatus = const {},
  });

  final String name;
  final int total;
  final Map<String, int> byStatus;

  int get published => byStatus['published'] ?? 0;
  bool get isComplete => published >= total && total > 0;

  factory DripClusterStat.fromJson(Map<String, dynamic> json) {
    final byStatus = <String, int>{};
    final raw = json['by_status'];
    if (raw is Map) {
      for (final e in raw.entries) {
        byStatus[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    return DripClusterStat(
      name: json['name'] as String? ?? 'unknown',
      total: json['total'] as int? ?? 0,
      byStatus: byStatus,
    );
  }
}
