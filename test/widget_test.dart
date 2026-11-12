import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';
import 'package:lab1_chat_ui/models/chat_message.dart';
import 'package:lab1_chat_ui/pages/chat_page.dart';
import 'package:lab1_chat_ui/services/ai_client.dart';
import 'package:lab1_chat_ui/widgets/bubble.dart';
import 'package:lab1_chat_ui/widgets/typing_dots.dart';

/// 테스트가 답을 줄 시점을 직접 정하는 가짜 AI.
class FakeAi implements AiClient {
  final calls = <String>[];
  final pending = <Completer<String>>[];

  @override
  Future<String> chat(String text, {List<ChatMessage> history = const []}) {
    calls.add(text);
    final c = Completer<String>();
    pending.add(c);
    return c.future;
  }

  void reply(String text) => pending.removeAt(0).complete(text);
  void fail(AiException e) => pending.removeAt(0).completeError(e);

  @override
  void close() {}
}

Future<FakeAi> pumpChat(WidgetTester tester, {bool reduceMotion = false}) async {
  final ai = FakeAi();
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(ChatLabApp(home: ChatPage(client: ai)));
  return ai;
}

/// 점 3개는 계속 움직이므로 pumpAndSettle 대신 충분한 시간만 흘린다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(); // 전송 버튼이 켜지는 프레임
  await tester.tap(find.byTooltip('보내기'));
  await tester.pump();
}

void main() {
  testWidgets('빈 상태 문구와 입력창이 보이고, 빈 입력은 전송할 수 없다', (tester) async {
    await pumpChat(tester);

    expect(find.text('무엇이든 물어보세요'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('입력 대기'), findsOneWidget);

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull, reason: '빈 입력이면 전송 버튼이 꺼진다');
  });

  testWidgets('전송 → sending → typing(점 3개) → done(답 삽입) → idle',
      (tester) async {
    final ai = await pumpChat(tester);

    await send(tester, '오늘 뭐 배워?');
    // 내 메시지가 목록에 들어가고(삽입 시작), 입력이 잠긴다
    expect(find.text('오늘 뭐 배워?', skipOffstage: false), findsOneWidget);
    expect(find.text('보내는 중…'), findsOneWidget);
    expect(find.text('무엇이든 물어보세요'), findsNothing);

    // 삽입 250ms가 끝나면 목록 안에 점 3개 칸
    await tester.pump(Motion.insert);
    await settle(tester);
    expect(find.byType(TypingDots), findsOneWidget);
    expect(find.text('AI가 답을 쓰는 중…'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AnimatedList), matching: find.byType(TypingDots)),
      findsOneWidget,
      reason: '점은 목록 밖이 아니라 목록 안의 한 칸이다',
    );

    // 연타해도 한 번만 전송
    await send(tester, '또 보내기');
    expect(ai.calls, ['오늘 뭐 배워?']);

    ai.reply('움직이는 응답을 붙입니다.');
    await settle(tester);
    expect(find.byType(TypingDots), findsNothing);
    expect(find.text('움직이는 응답을 붙입니다.'), findsOneWidget);
    expect(find.text('답이 도착했어요'), findsOneWidget);

    // done은 잠시 뒤 idle로 돌아간다
    await tester.pump(Motion.doneHold);
    await settle(tester);
    expect(find.text('입력 대기'), findsOneWidget);
    expect(find.text('답이 도착했어요'), findsNothing);
  });

  testWidgets('점 → 답으로 바뀔 때 목록이 아래로 튀지 않는다', (tester) async {
    final ai = await pumpChat(tester);
    await send(tester, '질문');
    await tester.pump(Motion.insert);
    await settle(tester);
    expect(find.byType(TypingDots), findsOneWidget);

    double top() => tester.getRect(find.text('질문')).top;
    var prev = top();
    ai.reply('여러 줄짜리 답입니다.\n둘째 줄\n셋째 줄');
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final now = top();
      // reverse 목록에서 위의 말풍선은 위로만 밀려야 한다(아래로 내려가면 튄 것).
      expect(now, lessThanOrEqualTo(prev + 0.5), reason: '프레임 $i에서 아래로 튐');
      prev = now;
    }
    expect(find.text('여러 줄짜리 답입니다.\n둘째 줄\n셋째 줄'), findsOneWidget);
  });

  testWidgets('답이 바로 와도 점은 최소 400ms 보인다 (깜빡임 방지)', (tester) async {
    final ai = await pumpChat(tester);
    await send(tester, '질문');
    await tester.pump(Motion.insert); // 점 칸 삽입 시작 (t=0)
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50)); // t=100
    expect(find.byType(TypingDots), findsOneWidget);

    ai.reply('빠른 답'); // 점이 나온 지 100ms 만에 답 도착
    await tester.pump(const Duration(milliseconds: 100)); // t=200 < 400
    expect(find.byType(TypingDots), findsOneWidget);
    expect(find.text('빠른 답'), findsNothing);

    await tester.pump(Motion.minDots);
    await settle(tester);
    expect(find.byType(TypingDots), findsNothing);
    expect(find.text('빠른 답'), findsOneWidget);
  });

  testWidgets('오류는 말풍선으로 남고, 다시 시도가 마지막 질문을 다시 보낸다',
      (tester) async {
    final ai = await pumpChat(tester);

    await send(tester, '안녕');
    await settle(tester);
    ai.fail(const AiException(500));
    await tester.pumpAndSettle();

    expect(find.text('응답을 받지 못했습니다'), findsNWidgets(2)); // 말풍선 + 오류 줄
    expect(find.text('다시 시도'), findsNWidgets(2));

    final errorBubble = find.ancestor(
      of: find.text('응답을 받지 못했습니다').first,
      matching: find.byType(Bubble),
    );
    final h0 = tester.getSize(errorBubble).height;

    await tester.tap(find.text('다시 시도').first);
    await tester.pump();
    // 사라지기 시작한 첫 프레임에도 버튼이 남아 있어 높이가 그대로다.
    expect(tester.getSize(errorBubble).height, h0);
    await settle(tester);
    expect(ai.calls, ['안녕', '안녕']);
    expect(find.text('안녕'), findsOneWidget, reason: '내 말풍선은 다시 추가하지 않는다');
    expect(find.text('응답을 받지 못했습니다'), findsNothing);

    ai.reply('반가워요');
    await tester.pumpAndSettle();
    expect(find.text('반가워요'), findsOneWidget);

    // 오류 뒤에도 입력이 된다
    await send(tester, '다음 질문');
    expect(ai.calls.last, '다음 질문');
    ai.reply('ok');
    await tester.pumpAndSettle();
  });

  testWidgets('401 · 429 · timeout 문구', (tester) async {
    expect(const AiException(401).userMessage, '키/권한을 확인해 주세요');
    expect(const AiException(429).userMessage, '잠시 후 다시 시도해 주세요');
    expect(const AiException(503).userMessage, '응답을 받지 못했습니다');
    expect(const AiException.timeout().userMessage, contains('네트워크'));
    expect(const AiException(null).userMessage, '네트워크를 확인해 주세요');
  });

  testWidgets('Reduce Motion이면 움직임 없이 즉시 표시된다', (tester) async {
    final ai = await pumpChat(tester, reduceMotion: true);

    await send(tester, '질문');
    await tester.pump(); // 타이머 0ms
    expect(find.byType(TypingDots), findsOneWidget);
    expect(find.text('답을 작성하는 중'), findsOneWidget, reason: '정보는 유지');

    ai.reply('즉시 답');
    await tester.pump(Motion.minDots); // 점 최소 표시 시간
    await tester.pump();
    // 애니메이션 없이 바로 제 크기로 보인다 — 삽입 0ms
    expect(find.text('즉시 답'), findsOneWidget);
    expect(tester.getSize(find.text('즉시 답')).height, greaterThan(0));
    expect(find.byType(TypingDots), findsNothing);
  });
}
