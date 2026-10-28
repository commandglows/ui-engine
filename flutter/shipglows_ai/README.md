# shipglows_ai

OpenRouter client for ShipGlows Flutter apps, the same on Android, iOS,
macOS, Windows, Linux and the web. One key from the user reaches every
model OpenRouter lists (Anthropic, OpenAI, Google, Mistral, open models).

1. **Asking.** `complete` for one answer, `stream` for the answer as it is
   written, `transformText` for the usual text action: one instruction
   applied to a text, answer trimmed.
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

final request = AiRequest.transform(
  model: 'anthropic/claude-haiku-5.5',
  fallbackModels: ['openai/gpt-5.5-mini'],
  instruction: 'Corrige les fautes. Renvoie seulement le texte corrigé.',
  text: selection,
);

final answer = await ai.complete(request);

await for (final piece in ai.stream(request)) {
  buffer.write(piece);
}
```

`appTitle` and `appUrl` name the app on the user's OpenRouter dashboard
(`X-Title`, `HTTP-Referer`).

## Transforming a selection

```dart
final fixed = await ai.transformText(
  model: 'anthropic/claude-haiku-5.5',
  instruction: 'Fix the spelling. Return only the corrected text.',
  text: selection,
  route: const AiRoute(model: 'openai/gpt-5.5-mini'), // this call only
);
```

`route` and `context` apply to this call only.

## Preview before sending

```dart
final preview = request.preview(); // no network call, no key read
print(preview); // the model, the fallbacks and the messages toJson would send
```

## Routes for one call

`AiRoute` replaces the model, the fallbacks, or adds a context for one call.
`request.withRoute(route)` returns a new request; the original is never
modified. A null field keeps the request's value.

```dart
final routed = request.withRoute(
  const AiRoute(model: 'google/gemini-test', context: AiContext(how: 'Short.')),
);
```

## Who and how

`AiContext(who:, how:)` becomes the first system message, before the
instruction. Blank fields count as absent; with both blank, nothing is added.

```dart
const context = AiContext(
  who: 'A support agent for a Flutter app',
  how: 'Warm, two sentences at most.',
);
```

## Activity

`ai.activity` reports each call: an `AiWorking(id)` first, then `AiDone(id,
truncated:)` or `AiFailed(id, error)`. Failures are still thrown to the
caller. It is a broadcast stream: an event emitted with no listener is lost.

```dart
ai.activity.listen((event) {
  switch (event) {
    case AiWorking(:final id):
      showBusy(id);
    case AiDone(:final id):
      hideBusy(id);
    case AiFailed(:final id, :final error):
      hideBusy(id);
      showError(error.message);
  }
});
```

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

Every expected failure is a sealed `AiException` with a French `message` ready for
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
| `AiProviderUnavailable` | 408, 5xx, an `error` body with a 5xx or no `code`, an error in the middle of a stream | yes |
| `AiTimeout` | no answer within `timeout` (60 s; the first byte for `stream`) | yes |
| `AiNetworkFailure` | no network, DNS, TLS | yes |
| `AiBadResponse` | an answer that is not the expected JSON, or a field of the wrong type (an unexpected error, not an `AiException`: it is rethrown as it is) | no |

An `error` body inside a 200 answer (or a stream) gets the class of its `code`:
401, 402, 403 and 429 give the same class as the HTTP status; 400 and other 4xx
give `AiBadRequest`; 408, 5xx or no code give `AiProviderUnavailable`.

## Privacy

The key goes only to `baseUrl` (OpenRouter) in the `Authorization` header
and is never logged. The package keeps no prompt, answer or history.

## Tests

`flutter test` runs against a mocked HTTP client; no key, no network.
