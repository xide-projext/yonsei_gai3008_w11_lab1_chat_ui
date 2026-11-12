import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

/// 프록시·AI 호출에서 생긴 실패. [status]는 HTTP 코드, timeout·네트워크는 null.
class AiException implements Exception {
  const AiException(this.status, [this.detail]);

  /// 30초 안에 답이 없을 때.
  const AiException.timeout() : this(null, 'timeout');

  final int? status;
  final String? detail;

  bool get isTimeout => detail == 'timeout';

  /// 화면에 보여 줄 문구 (1.11 · 부록 A.4). 팀 전체가 같은 문구를 쓴다.
  String get userMessage => switch (status) {
        401 || 403 => '키/권한을 확인해 주세요',
        429 => '잠시 후 다시 시도해 주세요',
        final int s when s >= 500 => '응답을 받지 못했습니다',
        _ when isTimeout => '응답이 너무 늦어요. 네트워크를 확인해 주세요',
        _ => '네트워크를 확인해 주세요',
      };

  @override
  String toString() => 'AiException(status: $status, detail: $detail)';
}

/// 앱이 아는 AI는 이 인터페이스뿐이다. 키는 앱에 없다 (1.6).
abstract class AiClient {
  /// [history]는 이번 질문 직전까지의 대화(오류 말풍선 제외).
  Future<String> chat(String text, {List<ChatMessage> history = const []});

  void close() {}

  /// --dart-define으로 고른다.
  ///   MOCK=true          → 서버 없이 [MockAiClient]
  ///   AI_BASE_URL=...    → 프록시 주소 직접 지정
  factory AiClient.fromEnvironment() {
    const mock = bool.fromEnvironment('MOCK');
    if (mock) return MockAiClient();
    const override = String.fromEnvironment('AI_BASE_URL');
    return ProxyAiClient(
      baseUrl: override.isNotEmpty ? override : ProxyAiClient.defaultBaseUrl,
    );
  }
}

/// 앱 → 프록시(w12/ai, :8787) → AI API.
class ProxyAiClient implements AiClient {
  ProxyAiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
    this.backoff = const [Duration(seconds: 1), Duration(seconds: 2)],
  }) : _http = httpClient ?? http.Client();

  /// 앱은 localhost:8787만 안다. Android 에뮬레이터에서는 10.0.2.2가 호스트 PC다.
  static String get defaultBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8787';
    }
    return 'http://localhost:8787';
  }

  final String baseUrl;
  final Duration timeout;

  /// 429일 때 기다릴 시간 — 지수 백오프 1s → 2s (1.11-5).
  final List<Duration> backoff;
  final http.Client _http;

  @override
  Future<String> chat(
    String text, {
    List<ChatMessage> history = const [],
  }) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _once(text, history);
      } on AiException catch (e) {
        final canRetry = e.status == 429 && attempt < backoff.length;
        if (!canRetry) rethrow;
        await Future<void>.delayed(backoff[attempt]);
      }
    }
  }

  Future<String> _once(String text, List<ChatMessage> history) async {
    final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$baseUrl/api/chat'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': text,
              'messages': [
                for (final m in history)
                  {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
                {'role': 'user', 'content': text},
              ],
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException.timeout();
    } catch (e) {
      throw AiException(null, e.toString());
    }

    if (res.statusCode != 200) throw AiException(res.statusCode, res.body);

    final answer = _extractText(utf8.decode(res.bodyBytes));
    if (answer == null || answer.trim().isEmpty) {
      throw const AiException(500, 'empty answer');
    }
    return answer.trim();
  }

  /// 프록시 응답 형태가 조금 달라도 읽을 수 있게 흔한 키를 차례로 본다.
  static String? _extractText(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      return body; // 평문 응답
    }
    if (json is String) return json;
    if (json is! Map) return null;
    for (final key in const ['reply', 'answer', 'text', 'content', 'output']) {
      final v = json[key];
      if (v is String) return v;
    }
    final message = json['message'];
    if (message is String) return message;
    if (message is Map && message['content'] is String) {
      return message['content'] as String;
    }
    final choices = json['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final m = first['message'];
        if (m is Map && m['content'] is String) return m['content'] as String;
        if (first['text'] is String) return first['text'] as String;
      }
    }
    return null;
  }

  @override
  void close() => _http.close();
}

/// 서버 없이 상태·애니메이션을 시험하는 가짜 AI.
///
/// 프록시의 FORCE_STATUS · SLOW_MS와 같은 시험을 앱 안에서 할 수 있다.
///   /401 /429 /500  → 해당 오류
///   /timeout        → 시간 초과
///   /slow           → 4초 뒤 답
class MockAiClient implements AiClient {
  MockAiClient({this.delay = const Duration(milliseconds: 1200)});

  final Duration delay;

  /// 같은 실패 명령을 두 번째 보낼 때(= 다시 시도)는 성공시킨다.
  final Set<String> _failedOnce = {};

  @override
  Future<String> chat(
    String text, {
    List<ChatMessage> history = const [],
  }) async {
    final cmd = text.trim().toLowerCase();
    final slow = cmd == '/slow';
    await Future<void>.delayed(slow ? delay * 3 : delay);

    final forced = switch (cmd) {
      '/401' => const AiException(401),
      '/429' => const AiException(429),
      '/500' => const AiException(500),
      '/timeout' => const AiException.timeout(),
      _ => null,
    };
    if (forced != null) {
      if (_failedOnce.add(cmd)) throw forced;
      _failedOnce.remove(cmd);
      return '다시 시도에 성공했습니다. ($cmd 시험 통과)';
    }

    if (text.contains('타이핑') || text.contains('점')) {
      return '응답이 1초를 넘으면 앱이 멈춘 것처럼 보이기 때문입니다. '
          '그래서 점 3개로 생각 중임을 보여 줘요.';
    }
    if (text.contains('오류') || text.contains('에러')) {
      return '말풍선으로 남기고, 그 안에 다시 시도 버튼을 둡니다. '
          '/401, /429, /500, /timeout 을 보내 시험해 보세요.';
    }
    if (text.contains('배워') || text.contains('오늘')) {
      return '오늘은 AI 챗봇에 움직이는 응답을 붙입니다. '
          '보내기·기다리기·도착·실패를 상태로 나눠요.';
    }
    return '(MOCK) "$text" 를 받았어요. 실제 답은 프록시(w12/ai)를 켜면 옵니다.';
  }

  @override
  void close() {}
}
