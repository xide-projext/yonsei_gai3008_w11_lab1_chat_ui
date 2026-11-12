import 'package:flutter/material.dart';

import 'pages/chat_page.dart';

void main() => runApp(const ChatLabApp());

class ChatLabApp extends StatelessWidget {
  const ChatLabApp({super.key, this.home});

  /// 테스트에서 가짜 AI를 넣은 ChatPage를 줄 수 있다.
  final Widget? home;

  static const _seed = Color(0xFF2F6FE4);

  /// 번들 한글 폰트 (pubspec.yaml) — 웹에서 처음 입력할 때 □가 보이지 않게.
  static const _font = 'NotoSansKR';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        fontFamily: _font,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
        fontFamily: _font,
        useMaterial3: true,
      ),
      home: home ?? const ChatPage(),
    );
  }
}
