# shipglows_ai

OpenRouter client for ShipGlows Flutter apps, the same on Android, iOS,
macOS, Windows, Linux and the web. One key from the user reaches every
model OpenRouter lists (Anthropic, OpenAI, Google, Mistral, open models).

1. **Asking.** `complete` for one answer, `stream` for the answer as it is
   written, `AiRequest.transform` for the usual text action: one
   instruction applied to a text.
2. **Choosing a model.** `models()` reads the catalogue (no key needed),
   with prices and context length. `fallbackModels` lets OpenRouter switch
   when the first model is down.
3. **Checking the key.** `checkKey()` says whether the key works and how
   much credit is left under its limit.
4. **Keeping the key.** An `OpenRouterKeyStore` the app picks: the system
   keychain, memory, or the app's own storage.

## Setup

```dart
final ai = OpenRouterClient(
  keyStore: const SecureOpenRouterKeyStore(),
  appTitle: 'CommandGlows',
  appUrl: 'https://www.commandglows.com',
);

final answer = await ai.complete(
  AiRequest.transform(
    model: 'anthropic/claude-haiku-5.5',
    fallbackModels: ['openai/gpt-5.5-mini'],
    instruction: 'Corrige les fautes. Renvoie seulement le texte corrigé.',
    text: selection,
  ),
);

await for (final piece in ai.stream(request)) {
  buffer.write(piece);
}
```

`appTitle` and `appUrl` name the app on the user's OpenRouter dashboard
(`X-Title`, `HTTP-Referer`).

## Key stores

| Store | Where the key lives | For |
| --- | --- | --- |
| `SecureOpenRouterKeyStore(storageKey:)` | system keychain via `flutter_secure_storage` (Keychain, Android Keystore, Windows Credential Manager, libsecret; browser storage on the web) | apps |
| `MemoryOpenRouterKeyStore(key)` | memory only | tests, a key typed for one session |
| `CallbackOpenRouterKeyStore(read:, write:, clear:)` | the app's own storage | a settings store, a key held by the app's backend |

The client reads the store before every request: a key changed in the
settings applies at once. Keys are trimmed; writing an empty key clears the
store. A keychain that cannot be read counts as no key.

## Errors

Every failure is a sealed `AiException` with a French `message` ready for
the user, the HTTP `statusCode` and OpenRouter's `providerMessage` (for
logs only: it can quote the request). `retryable` says whether sending
again later may work. Nothing is retried by the client.

| Exception | When | Retryable |
| --- | --- | --- |
| `AiMissingKey` | no key in the store; OpenRouter is not called | no |
| `AiInvalidKey` | 401 | no |
| `AiInsufficientCredits` | 402 | no |
| `AiRefused` | 403, moderation | no |
| `AiBadRequest` | other 4xx (unknown model, too long) | no |
| `AiRateLimited` | 429, with `retryAfter` | yes |
| `AiProviderUnavailable` | 408, 5xx, an `error` body with status 200, an error in the middle of a stream | yes |
| `AiTimeout` | no answer within `timeout` (60 s; the first byte for `stream`) | yes |
| `AiNetworkFailure` | no network, DNS, TLS | yes |
| `AiBadResponse` | an answer that is not the expected JSON | no |

## Privacy

The key goes only to `baseUrl` (OpenRouter) in the `Authorization` header
and is never logged. The package keeps no prompt, answer or history.

## Tests

`flutter test` runs against a mocked HTTP client; no key, no network.
