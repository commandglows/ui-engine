/// OpenRouter client for ShipGlows Flutter apps.
///
/// Android, iOS, macOS, Windows, Linux and the web.
///
/// - [OpenRouterClient]: [OpenRouterClient.complete] (one answer),
///   [OpenRouterClient.stream] (the answer as it is written),
///   [OpenRouterClient.transformText] (one instruction applied to a text),
///   [OpenRouterClient.models] (the catalogue, no key needed),
///   [OpenRouterClient.checkKey] (is this key valid, how much is left) and
///   [OpenRouterClient.activity] (start and end of each call).
/// - [OpenRouterKeyStore]: where the user's key lives. [SecureOpenRouterKeyStore]
///   (the system keychain), [MemoryOpenRouterKeyStore] (tests, a key typed
///   for one session), [CallbackOpenRouterKeyStore] (the app's own storage).
/// - [AiRequest], [AiMessage], [AiCompletion], [AiUsage], [AiModel],
///   [OpenRouterKeyInfo]: what goes in and out, as plain values.
/// - [AiRequest.preview] ([AiPreview]), [AiRoute] (a per-call route) and
///   [AiContext] (who and how), with [AiActivity] for the call lifecycle.
/// - [AiException]: every failure, sealed, with a French message.
library;

export 'src/ai_exception.dart';
export 'src/ai_models.dart';
export 'src/openrouter_client.dart';
export 'src/openrouter_key_store.dart';
