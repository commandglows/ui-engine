/// The signed-in Clerk user and the tokens of its OAuth session.
class ClerkSession {
  const ClerkSession({
    required this.subject,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    this.refreshToken,
    this.idToken,
    this.email,
    this.name,
  });

  factory ClerkSession.fromJson(Map<String, dynamic> json) => ClerkSession(
    subject: json['subject'] as String,
    accessToken: json['accessToken'] as String,
    accessTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(
      json['accessTokenExpiresAt'] as int,
      isUtc: true,
    ),
    refreshToken: json['refreshToken'] as String?,
    idToken: json['idToken'] as String?,
    email: json['email'] as String?,
    name: json['name'] as String?,
  );

  /// The Clerk user id (`user_…`), stable for this product's Clerk app.
  final String subject;
  final String accessToken;
  final DateTime accessTokenExpiresAt;

  /// Clerk refresh tokens do not expire; revoked on sign-out.
  final String? refreshToken;
  final String? idToken;
  final String? email;
  final String? name;

  /// Fresh for at least [margin] more.
  bool isAccessTokenFresh(
    DateTime now, {
    Duration margin = const Duration(minutes: 2),
  }) => now.toUtc().add(margin).isBefore(accessTokenExpiresAt);

  ClerkSession copyWith({
    String? accessToken,
    DateTime? accessTokenExpiresAt,
    String? refreshToken,
    String? idToken,
  }) => ClerkSession(
    subject: subject,
    accessToken: accessToken ?? this.accessToken,
    accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
    refreshToken: refreshToken ?? this.refreshToken,
    idToken: idToken ?? this.idToken,
    email: email,
    name: name,
  );

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'accessToken': accessToken,
    'accessTokenExpiresAt': accessTokenExpiresAt.millisecondsSinceEpoch,
    'refreshToken': refreshToken,
    'idToken': idToken,
    'email': email,
    'name': name,
  };
}
