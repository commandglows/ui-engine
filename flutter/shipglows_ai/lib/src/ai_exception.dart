/// Every failure of the client. [message] is French, ready for the user.
sealed class AiException implements Exception {
  const AiException(this.message, {this.statusCode, this.providerMessage});

  final String message;

  /// The HTTP status, when there was an answer.
  final int? statusCode;

  /// OpenRouter's own text, for logs. Never shown as is: it can quote the
  /// request.
  final String? providerMessage;

  /// True when sending the same request later may work.
  bool get retryable => false;

  @override
  String toString() =>
      '$runtimeType${statusCode == null ? '' : ' ($statusCode)'}: $message';
}

/// No key in the store: the user has to enter one.
final class AiMissingKey extends AiException {
  const AiMissingKey() : super('Ajoute ta clé OpenRouter dans les réglages.');
}

/// 401: the key is wrong, revoked or expired.
final class AiInvalidKey extends AiException {
  const AiInvalidKey({super.providerMessage})
    : super('Clé OpenRouter refusée. Vérifie-la dans les réglages.',
          statusCode: 401);
}

/// 402: no credit left on the account or on this key.
final class AiInsufficientCredits extends AiException {
  const AiInsufficientCredits({super.providerMessage})
    : super('Crédit OpenRouter épuisé. Recharge ton compte ou change de clé.',
          statusCode: 402);
}

/// 403: the model's moderation refused the input.
final class AiRefused extends AiException {
  const AiRefused({super.providerMessage})
    : super('Le modèle a refusé ce texte.', statusCode: 403);
}

/// 400, 404, 413…: the request itself is wrong (unknown model, too long).
final class AiBadRequest extends AiException {
  const AiBadRequest({required int statusCode, super.providerMessage})
    : super('Requête refusée par OpenRouter.', statusCode: statusCode);
}

/// 429: too many requests. [retryAfter] when OpenRouter says how long.
final class AiRateLimited extends AiException {
  const AiRateLimited({this.retryAfter, super.providerMessage})
    : super('Trop de requêtes. Réessaie dans un instant.', statusCode: 429);

  final Duration? retryAfter;

  @override
  bool get retryable => true;
}

/// 408, 5xx, or an error in the middle of a stream: the model or its
/// provider is down for now.
final class AiProviderUnavailable extends AiException {
  const AiProviderUnavailable({super.statusCode, super.providerMessage})
    : super('Le modèle ne répond pas. Réessaie ou choisis-en un autre.');

  @override
  bool get retryable => true;
}

/// No answer in time.
final class AiTimeout extends AiException {
  const AiTimeout() : super('OpenRouter ne répond pas à temps.');

  @override
  bool get retryable => true;
}

/// No network, DNS or TLS failure.
final class AiNetworkFailure extends AiException {
  const AiNetworkFailure({super.providerMessage})
    : super('Connexion impossible à OpenRouter.');

  @override
  bool get retryable => true;
}

/// An answer the client cannot read.
final class AiBadResponse extends AiException {
  const AiBadResponse({super.statusCode, super.providerMessage})
    : super('Réponse illisible d’OpenRouter.');
}
