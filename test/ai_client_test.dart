import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lab1_chat_ui/services/ai_client.dart';

ProxyAiClient client(MockClientHandler handler, {Duration? timeout}) =>
    ProxyAiClient(
      baseUrl: 'http://localhost:8787',
      httpClient: MockClient(handler),
      timeout: timeout ?? const Duration(seconds: 30),
      backoff: const [Duration(milliseconds: 1), Duration(milliseconds: 2)],
    );

void main() {
  test('200 — /api/chat에 질문을 보내고 reply를 읽는다', () async {
    late Map<String, dynamic> sent;
    final ai = client((req) async {
      expect(req.url.toString(), 'http://localhost:8787/api/chat');
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'reply': '안녕하세요'}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    expect(await ai.chat('안녕'), '안녕하세요');
    expect(sent['message'], '안녕');
  });

  test('응답 형태가 달라도 읽는다 (text · OpenAI choices · 평문)', () async {
    for (final body in [
      jsonEncode({'text': 'a'}),
      jsonEncode({
        'choices': [
          {'message': {'content': 'a'}}
        ]
      }),
      'a',
    ]) {
      final ai = client((_) async => http.Response(body, 200));
      expect(await ai.chat('q'), 'a');
    }
  });

  test('429면 1s → 2s 백오프로 두 번 더 시도한다', () async {
    var n = 0;
    final ai = client((_) async {
      n++;
      return n < 3 ? http.Response('', 429) : http.Response('{"reply":"ok"}', 200);
    });
    expect(await ai.chat('q'), 'ok');
    expect(n, 3);
  });

  test('429가 계속되면 포기하고 오류를 낸다', () async {
    var n = 0;
    final ai = client((_) async {
      n++;
      return http.Response('', 429);
    });
    await expectLater(
      ai.chat('q'),
      throwsA(isA<AiException>().having((e) => e.status, 'status', 429)),
    );
    expect(n, 3);
  });

  test('401은 재시도하지 않는다', () async {
    var n = 0;
    final ai = client((_) async {
      n++;
      return http.Response('', 401);
    });
    await expectLater(
      ai.chat('q'),
      throwsA(isA<AiException>()
          .having((e) => e.userMessage, 'msg', '키/권한을 확인해 주세요')),
    );
    expect(n, 1);
  });

  test('timeout은 AiException.timeout', () async {
    final ai = client(
      (_) => Future.delayed(
          const Duration(milliseconds: 200), () => http.Response('', 200)),
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      ai.chat('q'),
      throwsA(isA<AiException>().having((e) => e.isTimeout, 'timeout', true)),
    );
  });

  test('MockAiClient — /500은 한 번 실패하고 다시 시도에 성공한다', () async {
    final ai = MockAiClient(delay: Duration.zero);
    await expectLater(ai.chat('/500'), throwsA(isA<AiException>()));
    expect(await ai.chat('/500'), contains('성공'));
  });
}
