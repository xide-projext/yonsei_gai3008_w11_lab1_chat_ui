import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lab1_chat_ui/main.dart';
import 'package:lab1_chat_ui/models/chat_reply.dart';

Future<void> selectError(WidgetTester tester, ChatError error) async {
  await tester.tap(find.byTooltip('개발용 오류 시뮬레이션'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('다음 메시지: ${error.code} 오류'));
  await tester.pumpAndSettle();
}

Future<void> send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byTooltip('메시지 전송'));
  await tester.pump();
}

Future<void> finishReply(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  for (final error in ChatError.values) {
    testWidgets('${error.code}: 오류 표시, 새 전송, 중복 없는 재시도', (tester) async {
      await tester.pumpWidget(const ChatLabApp());
      await selectError(tester, error);
      await send(tester, 'Flutter란?');
      await finishReply(tester);
      if (error == ChatError.rateLimited) {
        expect(find.textContaining('자동 재시도 1/2'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(find.textContaining('자동 재시도 2/2'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('${error.code}: ${error.message}'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      await send(tester, '안녕하세요');
      await finishReply(tester);
      expect(find.textContaining(RegExp('안녕하세요!|반가워요!')), findsOneWidget);
      await tester.ensureVisible(find.text('다시 시도'));
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      expect(find.byType(TypingDots), findsOneWidget);
      await finishReply(tester);
      expect(find.text('다시 시도'), findsNothing);
      expect(find.text('Flutter란?'), findsOneWidget);
      expect(find.textContaining(RegExp('Flutter는|Flutter는 Dart')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('429는 1초와 2초 뒤 두 번만 자동 재시도한다', (tester) async {
    await tester.pumpWidget(const ChatLabApp());
    await selectError(tester, ChatError.rateLimited);
    await send(tester, 'Dart란?');
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.textContaining('자동 재시도 1/2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.textContaining('자동 재시도 1/2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('자동 재시도 2/2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.text('다시 시도'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('다시 시도'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(TypingDots), findsNothing);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('초기화는 대기 중 작업과 오류 및 주제 기억을 지운다', (tester) async {
    await tester.pumpWidget(const ChatLabApp());
    await selectError(tester, ChatError.rateLimited);
    await send(tester, 'Flutter란?');
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.byTooltip('대화 초기화'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('무엇이든 물어보세요'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
    await send(tester, '예시를 보여줘');
    await finishReply(tester);
    expect(find.textContaining(RegExp('어떤 주제|구체적으로')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('시뮬레이션을 해제하면 오류 없이 일반 응답한다', (tester) async {
    await tester.pumpWidget(const ChatLabApp());
    await selectError(tester, ChatError.server);
    await tester.tap(find.byTooltip('개발용 오류 시뮬레이션'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일반 채팅 (오류 해제)'));
    await tester.pumpAndSettle();
    await send(tester, '안녕하세요');
    await finishReply(tester);
    expect(find.text('다시 시도'), findsNothing);
    expect(find.textContaining(RegExp('안녕하세요!|반가워요!')), findsOneWidget);
  });
}
