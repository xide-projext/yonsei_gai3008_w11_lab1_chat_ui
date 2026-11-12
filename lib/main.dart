import 'package:flutter/material.dart';

void main() => runApp(const ChatLabApp());

const _seed = Color(0xFF2F6FE4);

class ChatLabApp extends StatelessWidget {
  const ChatLabApp({super.key});

  ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
    useMaterial3: true,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat — 실습 1',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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
  final List<ChatMessage> _messages = [
    const ChatMessage(text: '오늘 뭐 배워?', isUser: true),
    const ChatMessage(text: 'AI 챗봇에 움직이는 응답을 붙입니다.', isUser: false),
    const ChatMessage(text: '타이핑 점은 왜 필요해요?', isUser: true),
    const ChatMessage(text: '응답이 1초를 넘으면 앱이 멈춘 것처럼 보이기 때문입니다.', isUser: false),
  ];

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _fill(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // ✅ 할 일 5 — 키보드가 올라오면 body가 줄어들어 입력창이 가려지지 않는다.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            const _AiAvatar(radius: 18),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Chat — 실습 1',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '온라인',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colorScheme.outlineVariant),
        ),
      ),
      body: SafeArea(
        // 넓은 화면(웹·태블릿)에서도 대화가 가운데 모이도록 폭을 제한한다.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                // ✅ 할 일 1 — ListView.builder + reverse: true (최신이 아래)
                // ✅ 할 일 4 — 목록이 비면 Stack 위에 빈 상태를 띄운다.
                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final i = _messages.length - 1 - index;
                          final message = _messages[i];
                          // 같은 사람이 연달아 보내면 간격을 좁히고 아바타는 마지막에만.
                          final next = i + 1 < _messages.length
                              ? _messages[i + 1]
                              : null;
                          final prev = i > 0 ? _messages[i - 1] : null;
                          return _Bubble(
                            message: message,
                            isLastInGroup: next?.isUser != message.isUser,
                            isFirstInGroup: prev?.isUser != message.isUser,
                          );
                        },
                      ),
                      if (_messages.isEmpty) _EmptyState(onSuggestion: _fill),
                    ],
                  ),
                ),

                // ✅ 할 일 3 — 입력창 (TextField + 전송 버튼)
                _InputBar(
                  controller: _controller,
                  focusNode: _focusNode,
                  onSend: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar({this.radius = 14});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.tertiary],
        ),
      ),
      child: Icon(
        Icons.auto_awesome,
        size: radius,
        color: colorScheme.onPrimary,
      ),
    );
  }
}

/// ✅ 할 일 2 — 말풍선 2종 (사용자 오른쪽 / AI 왼쪽)
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });

  final ChatMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    const big = Radius.circular(20);
    const small = Radius.circular(6);
    // 말꼬리 쪽 모서리는 작게, 그룹 첫 말풍선의 위쪽만 둥글게.
    final radius = BorderRadius.only(
      topLeft: !isUser && !isFirstInGroup ? small : big,
      topRight: isUser && !isFirstInGroup ? small : big,
      bottomLeft: !isUser ? small : big,
      bottomRight: isUser ? small : big,
    );

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? colorScheme.primary : colorScheme.surfaceContainerHigh,
        borderRadius: radius,
      ),
      child: Text(
        message.text,
        style: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        isFirstInGroup ? 10 : 2,
        12,
        isLastInGroup ? 2 : 0,
      ),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            // 아바타 자리는 항상 비워 두어 말풍선 왼쪽 선을 맞춘다.
            isLastInGroup ? const _AiAvatar() : const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Padding(
              padding: EdgeInsets.only(
                left: isUser ? 48 : 0,
                right: isUser ? 0 : 48,
              ),
              child: bubble,
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ 할 일 4 — 빈 상태
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  static const _suggestions = [
    'Flutter 위젯이 뭐예요?',
    '오늘 실습 요약해 줘',
    'reverse: true는 왜 써요?',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _AiAvatar(radius: 32),
            const SizedBox(height: 16),
            Text(
              '무엇이든 물어보세요',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '아래 예시를 눌러 바로 시작할 수 있어요',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _suggestions)
                  ActionChip(label: Text(s), onPressed: () => onSuggestion(s)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ 할 일 3 — 입력창
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요',
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
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
          // 입력이 있을 때만 전송 버튼이 활성화된다.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canSend = value.text.trim().isNotEmpty;
              return IconButton.filled(
                onPressed: canSend ? onSend : null,
                icon: const Icon(Icons.send),
                tooltip: '보내기',
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              );
            },
          ),
        ],
      ),
    );
  }
}
