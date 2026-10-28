import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shipglows_ai/shipglows_ai.dart';

OpenRouterClient _client(
  MockClientHandler handler, {
  String? key = 'sk-or-test',
}) => OpenRouterClient(
  keyStore: MemoryOpenRouterKeyStore(key),
  appTitle: 'CommandGlows',
  appUrl: 'https://www.commandglows.com',
  httpClient: MockClient(handler),
);

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('complete sends the request and reads the answer', () async {
    late http.Request sent;
    final client = _client((request) async {
      sent = request;
      return _json({
        'id': 'gen-1',
        'model': 'openai/gpt-5.5-mini',
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'Bonjour.'},
            'finish_reason': 'stop',
          },
        ],
        'usage': {'prompt_tokens': 12, 'completion_tokens': 3, 'cost': 0.0001},
      });
    });

    final answer = await client.complete(
      AiRequest.transform(
        model: 'anthropic/claude-haiku-5.5',
        fallbackModels: ['openai/gpt-5.5-mini'],
        instruction: 'Corrige.',
        text: 'bonjour',
        temperature: 0.2,
      ),
    );

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'https://openrouter.ai/api/v1/chat/completions');
    expect(sent.headers['Authorization'], 'Bearer sk-or-test');
    expect(sent.headers['X-Title'], 'CommandGlows');
    expect(sent.headers['HTTP-Referer'], 'https://www.commandglows.com');
    expect(jsonDecode(sent.body), {
      'model': 'anthropic/claude-haiku-5.5',
      'models': ['anthropic/claude-haiku-5.5', 'openai/gpt-5.5-mini'],
      'messages': [
        {'role': 'system', 'content': 'Corrige.'},
        {'role': 'user', 'content': 'bonjour'},
      ],
      'temperature': 0.2,
    });
    expect(answer.text, 'Bonjour.');
    expect(answer.model, 'openai/gpt-5.5-mini');
    expect(answer.finishReason, 'stop');
    expect(answer.usage?.totalTokens, 15);
    expect(answer.usage?.cost, 0.0001);
    expect(answer.id, 'gen-1');
  });

  test('no key raises AiMissingKey without calling OpenRouter', () async {
    var called = false;
    final client = _client((_) async {
      called = true;
      return _json({});
    }, key: '  ');
    await expectLater(
      client.complete(
        const AiRequest(model: 'm', messages: [AiMessage.user('x')]),
      ),
      throwsA(isA<AiMissingKey>()),
    );
    expect(called, isFalse);
  });

  test('HTTP errors map to typed exceptions', () async {
    Future<Object?> failure(int status, [Map<String, String>? headers]) async {
      final client = _client(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': status, 'message': 'provider text'},
          }),
          status,
          headers: headers ?? const {},
        ),
      );
      try {
        await client.complete(
          const AiRequest(model: 'm', messages: [AiMessage.user('x')]),
        );
      } on AiException catch (error) {
        return error;
      }
      return null;
    }

    expect(await failure(401), isA<AiInvalidKey>());
    expect(await failure(402), isA<AiInsufficientCredits>());
    expect(await failure(403), isA<AiRefused>());
    expect(await failure(400), isA<AiBadRequest>());
    expect(await failure(503), isA<AiProviderUnavailable>());
    final limited = await failure(429, {'retry-after': '7'}) as AiRateLimited;
    expect(limited.retryAfter, const Duration(seconds: 7));
    expect(limited.retryable, isTrue);
    expect(limited.providerMessage, 'provider text');
  });

  test('an error body with status 200 is still an error', () async {
    final client = _client(
      (_) async => _json({
        'error': {'code': 502, 'message': 'upstream down'},
      }),
    );
    await expectLater(
      client.complete(
        const AiRequest(model: 'm', messages: [AiMessage.user('x')]),
      ),
      throwsA(isA<AiProviderUnavailable>()),
    );
  });

  test('stream yields deltas and skips keep-alive comments', () async {
    final client = OpenRouterClient(
      keyStore: MemoryOpenRouterKeyStore('k'),
      appTitle: 'CommandGlows',
      httpClient: MockClient.streaming((request, _) async {
        expect(jsonDecode((request as http.Request).body)['stream'], isTrue);
        String chunk(String text) => 'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': text},
            },
          ],
        })}\n\n';
        return http.StreamedResponse(
          Stream.fromIterable([
            ': OPENROUTER PROCESSING\n\n',
            chunk('Bon'),
            chunk('jour'),
            'data: [DONE]\n\n',
          ].map(utf8.encode)),
          200,
        );
      }),
    );
    expect(await client.stream(
      const AiRequest(model: 'm', messages: [AiMessage.user('x')]),
    ).toList(), ['Bon', 'jour']);
  });

  test('an error in the middle of a stream is raised', () async {
    final client = OpenRouterClient(
      keyStore: MemoryOpenRouterKeyStore('k'),
      appTitle: 'CommandGlows',
      httpClient: MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.fromIterable([
            'data: ${jsonEncode({
              'error': {'code': 'server_error', 'message': 'cut'},
            })}\n\n',
          ].map(utf8.encode)),
          200,
        ),
      ),
    );
    await expectLater(
      client
          .stream(const AiRequest(model: 'm', messages: [AiMessage.user('x')]))
          .toList(),
      throwsA(isA<AiProviderUnavailable>()),
    );
  });

  test('models needs no key and reads prices', () async {
    late http.Request sent;
    final client = _client((request) async {
      sent = request;
      return _json({
        'data': [
          {
            'id': 'meta/llama-5:free',
            'name': 'Llama 5 (free)',
            'context_length': 128000,
            'pricing': {'prompt': '0', 'completion': '0'},
          },
          {'name': 'no id'},
        ],
      });
    }, key: null);
    final models = await client.models();
    expect(sent.headers.containsKey('Authorization'), isFalse);
    expect(models, hasLength(1));
    expect(models.single.free, isTrue);
    expect(models.single.contextLength, 128000);
  });

  test('checkKey reads the key information', () async {
    final client = _client(
      (_) async => _json({
        'data': {
          'label': 'sk-or-v1-abc...',
          'limit': 10,
          'limit_remaining': 7.5,
          'usage': 2.5,
          'is_free_tier': false,
        },
      }),
    );
    final info = await client.checkKey();
    expect(info.limitRemaining, 7.5);
    expect(info.usage, 2.5);
    expect(info.freeTier, isFalse);
  });

  test('key stores trim and clear', () async {
    final memory = MemoryOpenRouterKeyStore();
    await memory.write('  sk-or-1  ');
    expect(await memory.read(), 'sk-or-1');
    await memory.write('');
    expect(await memory.read(), isNull);

    String? saved;
    final callback = CallbackOpenRouterKeyStore(
      read: () async => saved,
      write: (key) async => saved = key,
      clear: () async => saved = null,
    );
    await callback.write(' sk-or-2 ');
    expect(saved, 'sk-or-2');
    await callback.write('   ');
    expect(saved, isNull);
  });

  test('transformText sends one instruction and returns the trimmed text', () async {
    late http.Request sent;
    final client = _client((request) async {
      sent = request;
      return _json({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': '  Bonjour.\n'},
            'finish_reason': 'stop',
          },
        ],
      });
    });

    final text = await client.transformText(
      model: 'anthropic/claude-haiku-5.5',
      instruction: 'Corrige.',
      text: 'bonjour',
    );

    expect(text, 'Bonjour.');
    expect(jsonDecode(sent.body)['messages'], [
      {'role': 'system', 'content': 'Corrige.'},
      {'role': 'user', 'content': 'bonjour'},
    ]);
  });

  test('a filled context goes first, as a system message', () async {
    late http.Request sent;
    final client = _client((request) async {
      sent = request;
      return _json({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'ok'},
          },
        ],
      });
    });

    await client.transformText(
      model: 'anthropic/claude-haiku-5.5',
      instruction: 'Corrige.',
      text: 'bonjour',
      context: const AiContext(who: ' Diane ', how: 'Bref.'),
    );

    expect(jsonDecode(sent.body)['messages'], [
      {'role': 'system', 'content': 'Diane\n\nResponse style: Bref.'},
      {'role': 'system', 'content': 'Corrige.'},
      {'role': 'user', 'content': 'bonjour'},
    ]);
  });

  test('an empty context adds no message', () {
    const empty = AiContext(who: '  ', how: '');
    expect(empty.isEmpty, isTrue);
    expect(empty.toMessage(), isNull);
    final request = AiRequest.transform(
      model: 'm',
      instruction: 'Corrige.',
      text: 'x',
      context: empty,
    );
    expect(request.messages, hasLength(2));
  });

  test('a filled context becomes one system message in the right format', () {
    expect(
      const AiContext(who: ' Diane ', how: 'Bref.').toMessage(),
      const AiMessage.system('Diane\n\nResponse style: Bref.'),
    );
    expect(
      const AiContext(how: 'Bref.').toMessage(),
      const AiMessage.system('Response style: Bref.'),
    );
  });

  test('preview returns what would be sent, without a call or a key', () {
    // Synchronous and on the request itself: there is no client, key store
    // or HTTP call involved, so nothing can be sent or read.
    final request = AiRequest.transform(
      model: 'anthropic/claude-haiku-5.5',
      fallbackModels: ['openai/gpt-5.5-mini'],
      instruction: 'Corrige.',
      text: 'bonjour',
      context: const AiContext(who: 'Rédactrice'),
    );

    final preview = request.preview();

    expect(preview.model, 'anthropic/claude-haiku-5.5');
    expect(preview.fallbackModels, ['openai/gpt-5.5-mini']);
    expect(preview.messages.first, const AiMessage.system('Rédactrice'));
    expect(
      [for (final message in preview.messages) message.toJson()],
      request.toJson()['messages'],
    );
  });

  test('withRoute returns a new request and leaves the original alone', () {
    final original = AiRequest.transform(
      model: 'anthropic/claude-haiku-5.5',
      fallbackModels: ['openai/gpt-5.5-mini'],
      instruction: 'Corrige.',
      text: 'bonjour',
    );

    final routed = original.withRoute(
      const AiRoute(
        model: 'google/gemini-test',
        fallbackModels: ['mistral/test'],
        context: AiContext(who: 'Diane', how: 'Court.'),
      ),
    );

    expect(identical(routed, original), isFalse);
    expect(original.model, 'anthropic/claude-haiku-5.5');
    expect(original.fallbackModels, ['openai/gpt-5.5-mini']);
    expect(original.messages, hasLength(2));
    expect(routed.model, 'google/gemini-test');
    expect(routed.fallbackModels, ['mistral/test']);
    expect(routed.messages, [
      const AiMessage.system('Diane\n\nResponse style: Court.'),
      const AiMessage.system('Corrige.'),
      const AiMessage.user('bonjour'),
    ]);
    expect(original.withRoute(const AiRoute()).model, original.model);
  });

  test('activity reports Working then Done', () async {
    final client = _client(
      (_) async => _json({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'ok'},
            'finish_reason': 'length',
          },
        ],
      }),
    );
    final events = <AiActivity>[];
    final subscription = client.activity.listen(events.add);

    final answer = await client.complete(
      const AiRequest(model: 'm', messages: [AiMessage.user('x')]),
    );
    await subscription.cancel();

    expect(answer.truncated, isTrue);
    expect(events, hasLength(2));
    expect(events.first, isA<AiWorking>());
    expect(events.last, isA<AiDone>());
    expect((events.last as AiDone).truncated, isTrue);
    expect(events.last.id, events.first.id);
  });

  test('activity reports Failed on a 401 and the error is still raised', () async {
    final client = _client(
      (_) async => _json({'error': {'message': 'bad key'}}, 401),
    );
    final events = <AiActivity>[];
    final subscription = client.activity.listen(events.add);

    await expectLater(
      client.complete(
        const AiRequest(model: 'm', messages: [AiMessage.user('x')]),
      ),
      throwsA(isA<AiInvalidKey>()),
    );
    await subscription.cancel();

    expect(events, hasLength(2));
    expect(events.first, isA<AiWorking>());
    expect(events.last, isA<AiFailed>());
    expect((events.last as AiFailed).error, isA<AiInvalidKey>());
  });

  test('an unexpected error ends the call as AiBadResponse and is rethrown', () async {
    // `model` is a number: the `as String?` cast throws a TypeError, which is
    // not an AiException.
    final client = _client(
      (_) async => _json({
        'model': 42,
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'ok'},
          },
        ],
      }),
    );
    final events = <AiActivity>[];
    final subscription = client.activity.listen(events.add);

    await expectLater(
      client.complete(
        const AiRequest(model: 'm', messages: [AiMessage.user('x')]),
      ),
      throwsA(isA<TypeError>()),
    );
    await subscription.cancel();

    expect(events, hasLength(2));
    expect(events.first, isA<AiWorking>());
    expect(events.last, isA<AiFailed>());
    expect((events.last as AiFailed).error, isA<AiBadResponse>());
  });
}
