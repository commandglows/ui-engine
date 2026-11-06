class Persona {
  final String? id;
  final String name;
  final String? avatar;
  final int confidence;
  final PersonaDemographics? demographics;
  final List<String> painPoints;
  final List<String> goals;
  final PersonaLanguage? language;
  final PersonaContentPrefs? contentPreferences;

  const Persona({
    this.id,
    required this.name,
    this.avatar,
    this.confidence = 0,
    this.demographics,
    this.painPoints = const [],
    this.goals = const [],
    this.language,
    this.contentPreferences,
  });

  Persona copyWith({
    String? id,
    String? name,
    String? avatar,
    int? confidence,
    PersonaDemographics? demographics,
    List<String>? painPoints,
    List<String>? goals,
    PersonaLanguage? language,
    PersonaContentPrefs? contentPreferences,
  }) {
    return Persona(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      confidence: confidence ?? this.confidence,
      demographics: demographics ?? this.demographics,
      painPoints: painPoints ?? this.painPoints,
      goals: goals ?? this.goals,
      language: language ?? this.language,
      contentPreferences: contentPreferences ?? this.contentPreferences,
    );
  }

  factory Persona.fromJson(Map<String, dynamic> json) => Persona(
        id: json['id'] as String?,
        name: json['name'] as String,
        avatar: json['avatar'] as String?,
        confidence: json['confidence'] as int? ?? 0,
        demographics: json['demographics'] != null
            ? PersonaDemographics.fromJson(
                json['demographics'] as Map<String, dynamic>)
            : null,
        painPoints: (json['pain_points'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        goals: (json['goals'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        language: json['language'] != null
            ? PersonaLanguage.fromJson(
                json['language'] as Map<String, dynamic>)
            : null,
        contentPreferences: json['content_preferences'] != null
            ? PersonaContentPrefs.fromJson(
                json['content_preferences'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'avatar': avatar,
        'confidence': confidence,
        'demographics': demographics?.toJson(),
        'pain_points': painPoints,
        'goals': goals,
        'language': language?.toJson(),
        'content_preferences': contentPreferences?.toJson(),
      };

  static Persona empty() => const Persona(
        name: '',
        painPoints: ['', ''],
        goals: ['', ''],
      );
}

class PersonaDemographics {
  final String? role;
  final String? industry;
  final String? ageRange;
  final String? experienceLevel;

  const PersonaDemographics({
    this.role,
    this.industry,
    this.ageRange,
    this.experienceLevel,
  });

  factory PersonaDemographics.fromJson(Map<String, dynamic> json) =>
      PersonaDemographics(
        role: json['role'] as String?,
        industry: json['industry'] as String?,
        ageRange: json['age_range'] as String?,
        experienceLevel: json['experience_level'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'industry': industry,
        'age_range': ageRange,
        'experience_level': experienceLevel,
      };
}

class PersonaLanguage {
  final List<String> vocabulary;
  final List<String> objections;
  final Map<String, List<String>> triggers;

  const PersonaLanguage({
    this.vocabulary = const [],
    this.objections = const [],
    this.triggers = const {},
  });

  factory PersonaLanguage.fromJson(Map<String, dynamic> json) =>
      PersonaLanguage(
        vocabulary: (json['vocabulary'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        objections: (json['objections'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        triggers: (json['triggers'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(
                  k, (v as List<dynamic>).map((e) => e as String).toList()),
            ) ??
            {},
      );

  Map<String, dynamic> toJson() => {
        'vocabulary': vocabulary,
        'objections': objections,
        'triggers': triggers,
      };
}

class PersonaContentPrefs {
  final List<String> formats;
  final List<String> channels;
  final String? frequency;

  const PersonaContentPrefs({
    this.formats = const [],
    this.channels = const [],
    this.frequency,
  });

  factory PersonaContentPrefs.fromJson(Map<String, dynamic> json) =>
      PersonaContentPrefs(
        formats: (json['formats'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        channels: (json['channels'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        frequency: json['frequency'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'formats': formats,
        'channels': channels,
        'frequency': frequency,
      };
}
