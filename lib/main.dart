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

/// 실습용 가짜 대화 — API를 붙이기 전까지 이 목록으로 화면을 만든다.
const List<ChatMessage> _fakeMessages = [
  ChatMessage(text: '오늘 뭐 배워?', isUser: true),
  ChatMessage(text: 'AI 챗봇에 움직이는 응답을 붙입니다.', isUser: false),
  ChatMessage(text: '타이핑 점은 왜 필요해요?', isUser: true),
  ChatMessage(
    text: '응답이 1초를 넘으면 앱이 멈춘 것처럼 보이기 때문입니다.',
    isUser: false,
  ),
];

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.initialMessages = _fakeMessages});

  /// 처음에 보여 줄 대화. 테스트에서 빈 목록([])을 넣어 빈 상태를 확인한다.
  final List<ChatMessage> initialMessages;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  /// 화면에 그릴 대화 목록.
  /// initialMessages를 복사해서 쓰므로 add() 해도 원본은 바뀌지 않는다.
  late final List<ChatMessage> _messages = List.of(widget.initialMessages);

  /// 입력창의 글자를 읽고 지우는 역할.
  final TextEditingController _controller = TextEditingController();

  /// 전송 버튼이나 Enter를 눌렀을 때 실행된다.
  void _send() {
    // 앞뒤 공백을 지운 뒤, 비어 있으면 아무것도 하지 않는다.
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });

    _controller.clear();
  }

  @override
  void dispose() {
    // State가 사라질 때 컨트롤러도 정리한다. (메모리 누수 방지)
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 할 일 5 — 키보드가 입력창을 가리지 않게
      //    · Scaffold의 resizeToAvoidBottomInset은 기본값이 true다.
      //      키보드가 올라오면 body 높이가 "키보드 위까지"로 줄어들기 때문에
      //      Column 맨 아래에 있는 입력창이 자동으로 키보드 위로 올라온다.
      //      (그래서 따로 옵션을 켤 필요가 없다)
      //    · body를 SafeArea로 감싸 홈 인디케이터와 노치 영역을 피한다.
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
              child: Stack(
                children: [
                  // ───────────────────────────────────────────────────
                  // ✅ 할 일 1 — 완료된 부분 (그대로 유지)
                  // ───────────────────────────────────────────────────
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

                  // ───────────────────────────────────────────────────
                  // ✅ 할 일 4 — 빈 상태
                  //    목록이 비었을 때만 Stack 위에 안내 문구를 겹쳐 띄운다.
                  //    메시지가 생기면 if가 거짓이 되어 문구가 사라진다.
                  // ───────────────────────────────────────────────────
                  if (_messages.isEmpty)
                    Center(
                      child: Text(
                        '무엇이든 물어보세요',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ─────────────────────────────────────────────────────────
            // ✅ 할 일 3 — 입력창 (TextField + 전송 버튼)
            //    · Row 안에서 TextField를 Expanded로 감싸 남은 공간을 채운다.
            //    · Enter(textInputAction.send)와 버튼 모두 _send()를 호출한다.
            // ─────────────────────────────────────────────────────────
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
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    tooltip: '전송',
                    icon: const Icon(Icons.send),
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
/// ✅ 할 일 2 — 말풍선 2종 (사용자 오른쪽 / AI 왼쪽)
///
/// · Align으로 isUser면 오른쪽, 아니면 왼쪽에 붙인다.
/// · Container의 margin/padding/BoxDecoration으로 말풍선 모양을 만든다.
/// · constraints(maxWidth: 420)로 너비를 제한해 긴 글은 자동 줄바꿈된다.
/// · 색은 Theme.of(context).colorScheme에서 꺼내 다크 모드에서도 안전하다.
/// ───────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Align(
      // 사용자면 오른쪽, AI면 왼쪽에 붙인다.
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        // maxWidth를 잡아 두면 긴 글은 자동으로 줄바꿈된다.
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          // 사용자와 AI의 배경색을 다르게 한다.
          color: isUser
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

