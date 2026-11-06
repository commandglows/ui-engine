class OpenRouterCredentialStatus {
  const OpenRouterCredentialStatus({
    required this.provider,
    required this.configured,
    required this.validationStatus,
    this.maskedSecret,
    this.lastValidatedAt,
    this.updatedAt,
  });

  final String provider;
  final bool configured;
  final String validationStatus;
  final String? maskedSecret;
  final DateTime? lastValidatedAt;
  final DateTime? updatedAt;

  bool get isValid => validationStatus == 'valid';
  bool get isInvalid => validationStatus == 'invalid';
  bool get isMissing => validationStatus == 'missing';

  factory OpenRouterCredentialStatus.fromJson(Map<String, dynamic> json) {
    return OpenRouterCredentialStatus(
      provider: (json['provider'] ?? 'openrouter').toString(),
      configured: json['configured'] as bool? ?? false,
      validationStatus: (json['validationStatus'] ?? 'unknown').toString(),
      maskedSecret: json['maskedSecret'] as String?,
      lastValidatedAt: _parseDateTime(json['lastValidatedAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class OpenRouterCredentialValidationResult {
  const OpenRouterCredentialValidationResult({
    required this.provider,
    required this.valid,
    required this.validationStatus,
    this.message,
  });

  final String provider;
  final bool valid;
  final String validationStatus;
  final String? message;

  factory OpenRouterCredentialValidationResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return OpenRouterCredentialValidationResult(
      provider: (json['provider'] ?? 'openrouter').toString(),
      valid: json['valid'] as bool? ?? false,
      validationStatus: (json['validationStatus'] ?? 'unknown').toString(),
      message: json['message']?.toString(),
    );
  }
}
