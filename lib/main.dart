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
/// 채팅 메시지 목록과 사용자 입력을 관리한다.
  final _controller = TextEditingController();
  final List<ChatMessage> _messages = [
  ChatMessage(text: 'Hello!', isUser: true),
  ChatMessage(text: 'Hi! How can I help?', isUser: false),
  ];


  void _send() {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true),
      );
    });

    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('AI Chat — 실습 1'),
      ),
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
                    const Center(
                      child: Text(
                        '무엇이든 물어보세요',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
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
            // TODO 3 — 입력창 (TextField + 전송 버튼)
            // TIP:
            //  · final _controller = TextEditingController(); 를 State에 둔다.
            //  · Row(children: [Expanded(TextField(...)), IconButton.filled(...)])
            //  · TextField(textInputAction: TextInputAction.send,
            //             onSubmitted: (_) => _send())
            //  · 보낼 때 _controller.clear() 하고 setState로 목록에 추가한다.
            //  · dispose()에서 _controller.dispose()를 잊지 않는다.
            // ─────────────────────────────────────────────────────────
            
Padding(
  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
  child: Row(
    children: [
      Expanded(
        child: TextField(
          controller: _controller,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(
            hintText: '메시지를 입력하세요...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      IconButton.filled(
        onPressed: _send,
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
    final colors = Theme.of(context).colorScheme;

    return Align(
      alignment: message.isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: message.isUser
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(message.text),
      ),
    );
  }
}

/// TODO 3이 끝나면 지운다. 지금은 입력창 자리를 보여 주는 표시일 뿐이다.

