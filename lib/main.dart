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

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  /// 실습용 가짜 대화 — API를 붙이기 전까지 이 목록으로 화면을 만든다.
  /// (const가 아니라 growable 리스트여야 나중에 _send()에서 add할 수 있다.)
  final List<ChatMessage> _messages = [
    const ChatMessage(text: '오늘 뭐 배워?', isUser: true),
    const ChatMessage(text: 'AI 챗봇에 움직이는 응답을 붙입니다.', isUser: false),
    const ChatMessage(text: '타이핑 점은 왜 필요해요?', isUser: true),
    const ChatMessage(text: '응답이 1초를 넘으면 앱이 멈춘 것처럼 보이기 때문입니다.', isUser: false),
  ];

  /// AI가 응답을 만드는 중인가? true인 동안 목록 맨 아래에 점 3개 말풍선이 뜬다.
  bool _sending = false;

  /// 입력창의 글자를 들고 있는 컨트롤러. dispose()에서 반드시 정리한다.
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 보내기 — 지금은 서버가 없으니 2초 뒤 가짜 답변을 넣는다.
  /// 12주차에 await Future.delayed(...) 자리가 실제 API 호출로 바뀐다.
  Future<void> _send() async {
    if (_sending) return; // 응답 전에 또 보내는 것 방지
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _sending = true; // ← 타이핑 말풍선 등장
    });

    await Future<void>.delayed(const Duration(seconds: 2));

    // await 뒤에는 위젯이 이미 사라졌을 수 있다. setState 전에 반드시 확인.
    if (!mounted) return;
    setState(() {
      _sending = false;
      _messages.add(
        const ChatMessage(
          text: '점 3개는 "응답 준비 중" 신호입니다. 실제 응답은 다음 실습에서 API로 붙입니다.',
          isUser: false,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // ✅ 할 일 5 — 키보드가 입력창을 가리지 않게
      //   resizeToAvoidBottomInset은 기본값이 true라 body가 키보드 높이만큼 줄어든다.
      //   SafeArea가 홈 인디케이터/노치를 피한다. (별도 설정 불필요)
      appBar: AppBar(title: const Text('AI Chat — 실습 1')),
      body: SafeArea(
        child: Column(
          children: [
            // ─────────────────────────────────────────────────────────
            // ✅ 할 일 1 — 완료된 부분
            //    ListView.builder + reverse: true
            //    · reverse:true면 index 0이 화면 맨 아래(최신)다.
            //    · 그래서 _messages[length - 1 - i]로 거꾸로 꺼낸다.
            // ─────────────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                // 응답을 기다리는 동안 타이핑 말풍선 한 칸이 맨 아래에 붙는다.
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  // reverse:true에서 index 0이 화면 맨 아래다.
                  if (_sending && index == 0) return const _TypingBubble();

                  // 타이핑 말풍선이 한 칸 차지하므로 그만큼 밀어서 꺼낸다.
                  final offset = _sending ? 1 : 0;
                  final message =
                      _messages[_messages.length - 1 - (index - offset)];
                  return _Bubble(message: message);
                },
              ),
            ),

            // ─────────────────────────────────────────────────────────
            // TODO 4 — 빈 상태
            // TIP: ListView를 Stack으로 감싸고, 목록이 비었을 때만
            //      Center(child: Text('무엇이든 물어보세요'))를 위에 띄운다.
            //      지금은 목록에 가짜 대화가 있어 빈 상태가 보이지 않는다.
            //      _messages를 비우고 확인해 보자.
            // ─────────────────────────────────────────────────────────

            // ─────────────────────────────────────────────────────────
            // ✅ 할 일 3 — 입력창 (TextField + 전송 버튼)
            // ─────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4, // 여러 줄 입력 시 최대 4줄까지 늘어난다
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: '무엇이든 물어보세요',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    // 응답 대기 중에는 잠가서 중복 전송을 막는다.
                    onPressed: _sending ? null : _send,
                    tooltip: '보내기',
                    icon: const Icon(Icons.arrow_upward),
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

/// ───────────────────────────────────────────────────────────────
/// TODO 2 — 말풍선 2종 (사용자 오른쪽 / AI 왼쪽)
///
/// 지금은 글자만 보이는 상자다. 다음을 채워 넣자.
///
/// TIP:
///  · Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft)
///  · Container(
///      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
///      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
///      constraints: BoxConstraints(maxWidth: 420),
///      decoration: BoxDecoration(
///        color: isUser ? colorScheme.primaryContainer
///                      : colorScheme.surfaceContainerHighest,
///        borderRadius: BorderRadius.circular(14),
///      ),
///    )
///  · 색은 Theme.of(context).colorScheme에서 꺼내면 다크 모드에서도 안전하다.
///  · 긴 글은 자동으로 줄바꿈된다. maxWidth만 잡아 주면 된다.
/// ───────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(message.text),
    );
  }
}

/// ───────────────────────────────────────────────────────────────
/// 타이핑 중 말풍선 — AI가 응답을 만드는 동안 점이 늘었다 줄었다 한다.
///
/// _sending == true인 동안에만 목록에 붙는다. ListView에서 빠지면 위젯이
/// 사라지므로 AnimationController도 자동으로 dispose된다(ticker 누수 없음).
///
/// 컨트롤러 하나로 두 가지를 동시에 만든다.
///  · 개수 : 1개 → 2개 → 3개 → 1개 … (1.2초에 3단계)
///  · 크기 : 방금 나타난 점만 살짝 튀어 오르며 커진다
/// ───────────────────────────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: 'AI가 입력 중입니다',
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              // 0 ~ 3을 3등분: 0단계=1개, 1단계=2개, 2단계=3개
              final phase = _controller.value * 3;
              final count = phase.floor() % 3 + 1;
              final t = phase - phase.floor(); // 0 ~ 1, 단계 내 진행도

              return AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < count; i++)
                      Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                        child: _TypingDot(
                          color: scheme.onSurfaceVariant,
                          // 마지막 점만 0.5 → 1.1 → 1.0 으로 튀어 오른다.
                          scale: i == count - 1
                              ? 0.5 + 0.6 * Curves.easeOutBack.transform(t)
                              : 1,
                          opacity: i == count - 1 ? 0.35 + 0.65 * t : 1,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot({
    required this.color,
    required this.scale,
    required this.opacity,
  });

  final Color color;
  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    // Transform.scale / Opacity는 페인트 단계에서만 적용된다.
    // → 점이 커졌다 작아져도 말풍선 레이아웃(AnimatedSize)은 흔들리지 않는다.
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0).toDouble(),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
