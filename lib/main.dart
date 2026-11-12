import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'services/mock_chat_service.dart';
import 'models/chat_reply.dart';

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
  const ChatMessage({required this.text, required this.isUser, this.reply});

  final String text;
  final bool isUser;
  final ChatReply? reply;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.initialMessages = const []});

  final List<ChatMessage> initialMessages;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final List<ChatMessage> _messages = List.of(widget.initialMessages);
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  MockChatService _chatService = MockChatService();
  final Map<ChatReply, Timer> _timers = {};
  ChatError? _simulation;

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final reply = ChatReply(text, _simulation);
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messages.add(ChatMessage(text: '', isUser: false, reply: reply));
      // 시뮬레이션은 다음 메시지 한 번에만 적용한다.
      _simulation = null;
    });
    _controller.clear();
    _scrollToLatest();
    _schedule(reply, const Duration(milliseconds: 1500), simulate: true);
  }

  void _schedule(ChatReply reply, Duration delay, {required bool simulate}) {
    _timers.remove(reply)?.cancel();
    _timers[reply] = Timer(delay, () {
      _timers.remove(reply);
      if (!mounted) return;
      final failure = simulate ? reply.simulatedError : null;
      if (failure == ChatError.rateLimited && reply.automaticRetries < 2) {
        final seconds = 1 << reply.automaticRetries;
        setState(() {
          reply.error = failure;
          reply.automaticRetries++;
        });
        _schedule(reply, Duration(seconds: seconds), simulate: true);
        _scrollToLatest();
        return;
      }
      setState(() {
        try {
          if (failure != null) {
            reply.error = failure;
            reply.status = ReplyStatus.error;
          } else {
            reply.text = _chatService.reply(reply.prompt);
            reply.error = null;
            reply.status = ReplyStatus.success;
          }
        } catch (_) {
          reply.error = ChatError.server;
          reply.status = ReplyStatus.error;
        }
      });
      _scrollToLatest();
    });
  }

  void _retry(ChatReply reply) {
    if (reply.status != ReplyStatus.error) return;
    setState(() {
      reply.status = ReplyStatus.loading;
      reply.error = null;
      reply.automaticRetries = 0;
    });
    // 수동 재시도에서는 개발용 오류를 해제해 복구를 확인한다.
    _schedule(reply, const Duration(milliseconds: 1500), simulate: false);
    _scrollToLatest();
  }

  void _reset() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    setState(() {
      _messages.clear();
      _controller.clear();
      _simulation = null;
      _chatService = MockChatService();
    });
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('AI Chat — 실습 1'),
        actions: [
          PopupMenuButton<ChatError?>(
            tooltip: '개발용 오류 시뮬레이션',
            icon: const Icon(Icons.bug_report_outlined),
            onSelected: (value) => setState(() => _simulation = value),
            itemBuilder: (context) => [
              PopupMenuItem<ChatError?>(onTap: () => setState(() => _simulation = null), child: const Text('일반 채팅 (오류 해제)')),
              for (final error in ChatError.values)
                PopupMenuItem(value: error, child: Text('다음 메시지: ${error.code} 오류')),
            ],
          ),
          IconButton(
            tooltip: '대화 초기화',
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 40),
                            SizedBox(height: 16),
                            Text('무엇이든 물어보세요'),
                            SizedBox(height: 8),
                            Text('메시지를 보내 대화를 시작해 보세요.'),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      findChildIndexCallback: (key) {
                        final index = _messages.indexWhere((message) => ObjectKey(message) == key);
                        return index < 0 ? null : _messages.length - 1 - index;
                      },
                      itemBuilder: (context, index) {
                        final message = _messages[_messages.length - 1 - index];
                        return KeyedSubtree(
                          key: ObjectKey(message),
                          child: message.reply == null
                              ? _Bubble(message: message)
                              : _ReplyBubble(reply: message.reply!, onRetry: () => _retry(message.reply!)),
                        );
                      },
                    ),
            ),
            if (_simulation != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('개발용: 다음 메시지에 ${_simulation!.code} 오류를 1회 시뮬레이션합니다.'),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        labelText: '메시지',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, child) => IconButton.filled(
                      tooltip: '메시지 전송',
                      onPressed: value.text.trim().isEmpty ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
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

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: message.isUser ? colors.primaryContainer : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: message.isUser ? colors.onPrimaryContainer : colors.onSurface),
        ),
      ),
    );
  }
}

class _ReplyBubble extends StatelessWidget {
  const _ReplyBubble({required this.reply, required this.onRetry});
  final ChatReply reply;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (reply.status) {
        ReplyStatus.success => _Bubble(
            key: const ValueKey('success'),
            message: ChatMessage(text: reply.text, isUser: false),
          ),
        ReplyStatus.loading => Align(
            key: const ValueKey('loading'),
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TypingDots(),
                  if (reply.automaticRetries > 0)
                    Text('429: 자동 재시도 ${reply.automaticRetries}/2 · ${1 << (reply.automaticRetries - 1)}초 대기'),
                ],
              ),
            ),
          ),
        ReplyStatus.error => Align(
            key: const ValueKey('error'),
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${reply.error!.code}: ${reply.error!.message}', style: TextStyle(color: colors.onErrorContainer)),
                  TextButton(onPressed: onRetry, child: const Text('다시 시도')),
                ],
              ),
            ),
          ),
      },
    );
  }
}

/// 응답 대기 중 세 점이 차례로 위아래로 움직인다.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = 0;
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'AI가 응답을 작성하고 있습니다',
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final wave = math.sin((_animation.value * 2 * math.pi) - index * 0.8);
              return Transform.translate(
                offset: Offset(0, -4.0 * math.max(0.0, wave)),
                child: Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(color: colors.onSurfaceVariant, shape: BoxShape.circle),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
