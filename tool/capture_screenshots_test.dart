// 포트폴리오 "전/후 캡처"용 스크린샷 생성기 (일반 `flutter test`에는 포함되지 않는다).
//
//   flutter test tool/capture_screenshots_test.dart --update-goldens
//
// 실제 앱 위젯을 Flutter 렌더러로 그려 docs/screenshots/after_*.png 로 저장한다.
// 서버 없이 상태를 재현하려고 가짜 AI를 쓴다.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';
import 'package:lab1_chat_ui/models/chat_message.dart';
import 'package:lab1_chat_ui/pages/chat_page.dart';
import 'package:lab1_chat_ui/services/ai_client.dart';

class _ScriptedAi implements AiClient {
  final _pending = <Completer<String>>[];

  @override
  Future<String> chat(String text, {List<ChatMessage> history = const []}) {
    final c = Completer<String>();
    _pending.add(c);
    return c.future;
  }

  void reply(String text) => _pending.removeAt(0).complete(text);
  void fail(AiException e) => _pending.removeAt(0).completeError(e);

  @override
  void close() {}
}

/// 테스트 기본 폰트(Ahem: 네모)를 실제 폰트로 바꾼다.
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final bytes = File(p).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  await load('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
  const kr = [
    'assets/fonts/NotoSansKR-Regular.otf',
    'assets/fonts/NotoSansKR-Bold.otf',
  ];
  await load('NotoSansKR', kr);
  await load('Roboto', kr);
}

void main() {
  const frame = ValueKey('frame');

  Future<void> shot(WidgetTester tester, String name) => expectLater(
        find.byKey(frame),
        matchesGoldenFile('../docs/screenshots/$name.png'),
      );

  Future<void> wait(WidgetTester tester, [int ms = 700]) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byTooltip('보내기'));
    await tester.pump();
  }

  testWidgets('after', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(390 * 2, 760 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final ai = _ScriptedAi();
    await tester.pumpWidget(RepaintBoundary(
      key: frame,
      child: ChatLabApp(home: ChatPage(client: ai)),
    ));
    await tester.pump();
    await shot(tester, 'after_1_empty');

    // 전송 → 점 3개 (typing)
    await type(tester, '오늘 뭐 배워?');
    await wait(tester, Motion.insert.inMilliseconds + 450);
    await shot(tester, 'after_2_typing');

    // 답 도착 → 대화
    ai.reply('오늘은 AI 챗봇에 움직이는 응답을 붙입니다. '
        '보내기·기다리기·도착·실패를 상태로 나눠요.');
    await wait(tester);
    await type(tester, '타이핑 점은 왜 필요해요?');
    await wait(tester);
    ai.reply('응답이 1초를 넘으면 앱이 멈춘 것처럼 보이기 때문입니다. '
        '그래서 점 3개로 생각 중임을 보여 줘요.');
    await wait(tester);
    await shot(tester, 'after_3_answer');

    // 오류 → 오류 말풍선 + 다시 시도
    await wait(tester, Motion.doneHold.inMilliseconds);
    await type(tester, '오류는 어떻게 보여 줘요?');
    await wait(tester);
    ai.fail(const AiException(500));
    await wait(tester);
    await shot(tester, 'after_4_error');
  });
}
