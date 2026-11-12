import 'dart:async';

import 'package:flutter/material.dart';

void main() => runApp(const ChatLabApp());

class ChatLabApp extends StatelessWidget {
  const ChatLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat — 실습 1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6FE4)),
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

/// 대화 한 줄. 서버 없이 화면만 만들기 위한 최소 모델.
class ChatMessage {
  const ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

// ─────────────────────────────────────────────────────────────────
// 실습 ④ — 오류와 재시도
//
// 아직 프록시(w12/ai)를 붙이지 않았으므로, 실제 AiClient 대신
// FakeAiClient로 서버 응답을 흉내 낸다. 앱바의 🐞 메뉴에서
// 정상 / 401 / 429 / 500 / timeout 중 하나를 골라 오류를 일부러 만든다.
// (프록시를 붙이면 FakeAiClient만 진짜 AiClient로 바꾸면 된다.)
// ─────────────────────────────────────────────────────────────────

/// 서버가 돌려줄 수 있는 결과 — 시험용으로 고른다.
enum FakeMode { ok, unauthorized401, rateLimit429, server500, timeout }

extension FakeModeLabel on FakeMode {
  String get label => switch (this) {
        FakeMode.ok => '정상 응답',
        FakeMode.unauthorized401 => '401 키/권한 오류',
        FakeMode.rateLimit429 => '429 요청 너무 많음',
        FakeMode.server500 => '500 서버 오류',
        FakeMode.timeout => '시간 초과 (timeout)',
      };
}

/// HTTP 오류 하나 — 상태 코드만 들고 다닌다.
class AiException implements Exception {
  const AiException(this.status);

  final int status;
}

/// 프록시 대신 쓰는 가짜 AI. 1초 기다린 뒤 답하거나 오류를 던진다.
class FakeAiClient {
  FakeMode mode = FakeMode.ok;

  Future<String> chat(String text) async {
    await Future.delayed(const Duration(seconds: 1));
    switch (mode) {
      case FakeMode.ok:
        return '"$text"에 대한 AI의 답입니다.';
      case FakeMode.unauthorized401:
        throw const AiException(401);
      case FakeMode.rateLimit429:
        throw const AiException(429);
      case FakeMode.server500:
        throw const AiException(500);
      case FakeMode.timeout:
        // 실제로는 30초를 기다리지만, 시연을 위해 바로 시간 초과를 낸다.
        throw TimeoutException('응답 없음', const Duration(seconds: 30));
    }
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  /// 대화 목록 — 처음엔 비어 있어서 빈 상태 문구가 보인다.
  final List<ChatMessage> _messages = [];

  /// 입력창의 글자를 읽고 지우는 컨트롤러.
  final _controller = TextEditingController();

  final _ai = FakeAiClient();

  /// 지금 AI 답을 기다리는 중인가 — 연타 방지.
  bool _sending = false;

  /// ④-1 오류 상태 하나 — null이면 오류 없음. 401·429·500·timeout 모두 여기로.
  String? _error;

  /// ④-3 재시도할 때 다시 보낼 마지막 메시지.
  String? _lastText;

  /// 입력한 글을 내 말풍선으로 추가하고 AI에게 보낸다.
  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return; // 빈 글·연타는 보내지 않는다
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _controller.clear();
    _ask(text);
  }

  /// ④-3 다시 시도 — 마지막 메시지를 다시 보낸다 (말풍선은 새로 만들지 않는다).
  void _retry() {
    final text = _lastText;
    if (text == null || _sending) return;
    _ask(text);
  }

  /// AI에게 묻고, 답이면 AI 말풍선 / 오류면 오류 상태로 바꾼다.
  Future<void> _ask(String text) async {
    setState(() {
      _lastText = text;
      _sending = true;
      _error = null;
    });
    try {
      final answer = await _chatWithBackoff(text);
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage(text: answer, isUser: false)));
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e.status));
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _error = '네트워크를 확인해 주세요');
    } finally {
      // 성공이든 실패든 입력 잠금을 푼다 — 오류 뒤에도 입력이 된다.
      if (mounted) setState(() => _sending = false);
    }
  }

  /// ④-5 429면 지수 백오프: 1초 → 2초 기다렸다가 다시 시도한다.
  Future<String> _chatWithBackoff(String text) async {
    const delays = [Duration(seconds: 1), Duration(seconds: 2)];
    for (var attempt = 0;; attempt++) {
      try {
        return await _ai.chat(text).timeout(const Duration(seconds: 30));
      } on AiException catch (e) {
        if (e.status != 429 || attempt >= delays.length) rethrow;
        await Future.delayed(delays[attempt]);
      }
    }
  }

  /// ④-1 상태 코드 → 사용자에게 보여 줄 문구.
  String _messageFor(int status) => switch (status) {
        401 => '키/권한을 확인해 주세요',
        429 => '잠시 후 다시 시도해 주세요',
        500 => '응답을 받지 못했습니다',
        _ => '네트워크를 확인해 주세요',
      };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduce Motion(애니메이션 줄이기)이 켜져 있으면 전환을 즉시 보여 준다.
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      // ✅ 할 일 5 — 키보드가 올라오면 body가 줄어들어 입력창이 위로 밀린다.
      //    SafeArea는 홈 인디케이터·노치를 피한다.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('AI Chat — 실습 1'),
        actions: [
          // 시험용: 서버가 어떤 결과를 돌려줄지 고른다.
          PopupMenuButton<FakeMode>(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: '서버 응답 바꾸기 (시험용)',
            initialValue: _ai.mode,
            onSelected: (mode) => setState(() => _ai.mode = mode),
            itemBuilder: (_) => [
              for (final mode in FakeMode.values)
                PopupMenuItem(value: mode, child: Text(mode.label)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ✅ 할 일 1 — ListView.builder + reverse: true (최신이 아래)
            // ✅ 할 일 4 — 빈 상태: Stack으로 목록 위에 안내 문구를 겹친다
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          _messages[_messages.length - 1 - index];
                      return _Bubble(message: message);
                    },
                  ),
                  if (_messages.isEmpty)
                    Center(
                      child: Text(
                        '무엇이든 물어보세요',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                ],
              ),
            ),

            // 기다리는 동안 보여 주는 표시 (실습 ③에서 점 3개 애니메이션으로 바꿀 자리)
            if (_sending)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('AI가 답을 쓰는 중…'),
                ),
              ),

            // ✅ 실습 ④-2·4 — 오류 말풍선 + 다시 시도, AnimatedSwitcher로 전환
            //    SnackBar처럼 사라지지 않고 화면에 남는다.
            AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: _error == null
                  ? const SizedBox.shrink(key: ValueKey('no-error'))
                  : _ErrorBubble(
                      key: ValueKey(_error),
                      message: _error!,
                      onRetry: _sending ? null : _retry,
                    ),
            ),

            // ✅ 할 일 3 — 입력창: TextField(늘어나는 칸) + 전송 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    // 기다리는 동안은 버튼을 잠가 연타해도 한 번만 보낸다.
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 실습 ④ — 오류 말풍선. 문구와 "다시 시도" 버튼을 보여 준다.
class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

/// ✅ 할 일 2 — 말풍선 2종 (사용자 오른쪽 / AI 왼쪽)
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isUser
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(message.text),
      ),
    );
  }
}
