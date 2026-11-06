class AIRuntimeModeAvailability {
  const AIRuntimeModeAvailability({
    required this.mode,
    required this.enabled,
    this.reasonCode,
    this.message,
  });

  final String mode;
  final bool enabled;
  final String? reasonCode;
  final String? message;

  factory AIRuntimeModeAvailability.fromJson(Map<String, dynamic> json) {
    return AIRuntimeModeAvailability(
      mode: (json['mode'] ?? 'byok').toString(),
      enabled: json['enabled'] as bool? ?? false,
      reasonCode: (json['reasonCode'] ?? json['reason_code'])?.toString(),
      message: json['message']?.toString(),
    );
  }
}

class AIRuntimeByokProviderStatus {
  const AIRuntimeByokProviderStatus({
    this.supported = true,
    this.configured = false,
    this.maskedSecret,
    this.validationStatus = 'unknown',
    this.canValidate = false,
  });

  final bool supported;
  final bool configured;
  final String? maskedSecret;
  final String validationStatus;
  final bool canValidate;

  factory AIRuntimeByokProviderStatus.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return AIRuntimeByokProviderStatus(
      supported: data['supported'] as bool? ?? true,
      configured: data['configured'] as bool? ?? false,
      maskedSecret: (data['maskedSecret'] ?? data['masked_secret'])?.toString(),
      validationStatus:
          (data['validationStatus'] ?? data['validation_status'] ?? 'unknown')
              .toString(),
      canValidate: data['canValidate'] as bool? ?? false,
    );
  }
}

class AIRuntimePlatformProviderStatus {
  const AIRuntimePlatformProviderStatus({
    this.supported = true,
    this.configured = false,
    this.available = false,
    this.reasonCode,
  });

  final bool supported;
  final bool configured;
  final bool available;
  final String? reasonCode;

  factory AIRuntimePlatformProviderStatus.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return AIRuntimePlatformProviderStatus(
      supported: data['supported'] as bool? ?? true,
      configured: data['configured'] as bool? ?? false,
      available: data['available'] as bool? ?? false,
      reasonCode: (data['reasonCode'] ?? data['reason_code'])?.toString(),
    );
  }
}

class AIRuntimeProviderStatus {
  const AIRuntimeProviderStatus({
    required this.provider,
    required this.kind,
    this.usedBy = const <String>[],
    this.byok = const AIRuntimeByokProviderStatus(),
    this.platform = const AIRuntimePlatformProviderStatus(),
  });

  final String provider;
  final String kind;
  final List<String> usedBy;
  final AIRuntimeByokProviderStatus byok;
  final AIRuntimePlatformProviderStatus platform;

  factory AIRuntimeProviderStatus.fromJson(Map<String, dynamic> json) {
    final usedByRaw = json['usedBy'] ?? json['used_by'];
    return AIRuntimeProviderStatus(
      provider: (json['provider'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      usedBy: usedByRaw is List
          ? usedByRaw.map((entry) => entry.toString()).toList()
          : const <String>[],
      byok: AIRuntimeByokProviderStatus.fromJson(
        json['byok'] as Map<String, dynamic>?,
      ),
      platform: AIRuntimePlatformProviderStatus.fromJson(
        json['platform'] as Map<String, dynamic>?,
      ),
    );
  }
}

class AIRuntimeSettings {
  const AIRuntimeSettings({
    required this.mode,
    this.availableModes = const <AIRuntimeModeAvailability>[],
    this.providers = const <AIRuntimeProviderStatus>[],
  });

  final String mode;
  final List<AIRuntimeModeAvailability> availableModes;
  final List<AIRuntimeProviderStatus> providers;

  factory AIRuntimeSettings.fromJson(Map<String, dynamic> json) {
    final modesRaw = json['availableModes'] ?? json['available_modes'];
    final providersRaw = json['providers'];
    return AIRuntimeSettings(
      mode: (json['mode'] ?? 'byok').toString(),
      availableModes: modesRaw is List
          ? modesRaw
                .whereType<Map>()
                .map(
                  (entry) => AIRuntimeModeAvailability.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .toList()
          : const <AIRuntimeModeAvailability>[],
      providers: providersRaw is List
          ? providersRaw
                .whereType<Map>()
                .map(
                  (entry) => AIRuntimeProviderStatus.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .toList()
          : const <AIRuntimeProviderStatus>[],
    );
  }

  AIRuntimeModeAvailability? modeAvailability(String mode) {
    for (final candidate in availableModes) {
      if (candidate.mode == mode) {
        return candidate;
      }
    }
    return null;
  }

  static AIRuntimeSettings fallback() {
    return const AIRuntimeSettings(
      mode: 'byok',
      availableModes: <AIRuntimeModeAvailability>[
        AIRuntimeModeAvailability(mode: 'byok', enabled: true),
        AIRuntimeModeAvailability(mode: 'platform', enabled: false),
      ],
      providers: <AIRuntimeProviderStatus>[
        AIRuntimeProviderStatus(provider: 'openrouter', kind: 'llm'),
        AIRuntimeProviderStatus(provider: 'exa', kind: 'search'),
        AIRuntimeProviderStatus(provider: 'firecrawl', kind: 'crawler'),
      ],
    );
  }
}

class AIProviderCredentialStatus {
  const AIProviderCredentialStatus({
    required this.provider,
    this.configured = false,
    this.maskedSecret,
    this.validationStatus = 'unknown',
    this.lastValidatedAt,
    this.updatedAt,
  });

  final String provider;
  final bool configured;
  final String? maskedSecret;
  final String validationStatus;
  final DateTime? lastValidatedAt;
  final DateTime? updatedAt;

  factory AIProviderCredentialStatus.fromJson(Map<String, dynamic> json) {
    return AIProviderCredentialStatus(
      provider: (json['provider'] ?? '').toString(),
      configured: json['configured'] as bool? ?? false,
      maskedSecret: (json['maskedSecret'] ?? json['masked_secret'])?.toString(),
      validationStatus:
          (json['validationStatus'] ?? json['validation_status'] ?? 'unknown')
              .toString(),
      lastValidatedAt: _parseDateTime(
        json['lastValidatedAt'] ?? json['last_validated_at'],
      ),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class AIRuntimeErrorEnvelope {
  const AIRuntimeErrorEnvelope({
    required this.kind,
    required this.code,
    this.provider,
    this.mode,
    this.message,
  });

  final String kind;
  final String code;
  final String? provider;
  final String? mode;
  final String? message;

  factory AIRuntimeErrorEnvelope.fromJson(Map<String, dynamic> json) {
    return AIRuntimeErrorEnvelope(
      kind: (json['kind'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      provider: json['provider']?.toString(),
      mode: json['mode']?.toString(),
      message: json['message']?.toString(),
    );
  }
}
