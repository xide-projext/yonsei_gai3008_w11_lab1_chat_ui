import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';

void main() {
  testWidgets('앱은 빈 상태와 하단 입력창으로 시작한다', (tester) async {
    await tester.pumpWidget(const ChatLabApp());
    expect(find.text('무엇이든 물어보세요'), findsOneWidget);
    expect(find.text('오늘 뭐 배워?'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).resizeToAvoidBottomInset, isTrue);
  });

  testWidgets('빈 상태에서 전송하면 타이핑 후 모의 응답이 나타난다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ChatPage(initialMessages: []),
    ));
    expect(find.text('무엇이든 물어보세요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  안녕하세요  ');
    await tester.tap(find.byTooltip('메시지 전송'));
    await tester.pump();
    expect(find.text('안녕하세요'), findsOneWidget);
    expect(find.text('무엇이든 물어보세요'), findsNothing);
    expect(find.byType(TypingDots), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(tester.widget<IconButton>(find.byTooltip('메시지 전송')).onPressed, isNull);
    final firstDot = find.descendant(of: find.byType(TypingDots), matching: find.byType(Transform)).first;
    final before = tester.getTopLeft(firstDot);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(firstDot), isNot(before));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.byType(TypingDots), findsNothing);
    expect(find.textContaining(RegExp('안녕하세요!|반가워요!')), findsOneWidget);
  });

  testWidgets('연속 전송에서 로컬 서비스가 최근 주제를 기억한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatPage(initialMessages: [])));
    for (final question in ['Flutter가 뭐야?', '예시를 보여줘']) {
      await tester.enterText(find.byType(TextField), question);
      await tester.tap(find.byTooltip('메시지 전송'));
      await tester.pump();
      expect(find.byType(TypingDots), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(TypingDots), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(TypingDots), findsNothing);
    }
    expect(find.textContaining(RegExp('Flutter의 간단한 화면 예시|Flutter에서는 Row')), findsOneWidget);
  });

  testWidgets('공백은 무시하고 키보드 전송을 지원한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatPage(initialMessages: [])));
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(find.byType(TypingDots), findsNothing);
    await tester.enterText(find.byType(TextField), '질문');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(find.text('질문'), findsOneWidget);
    // 응답 전에 화면을 닫아도 타이머와 애니메이션이 정리된다.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('이전 대화를 읽다가 보내면 최신 메시지로 이동한다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ChatPage(
      initialMessages: List.generate(40, (i) => ChatMessage(text: '대화 $i', isUser: i.isEven)),
    )));
    await tester.drag(find.byType(ListView), const Offset(0, 700));
    await tester.pumpAndSettle();
    final controller = tester.widget<ListView>(find.byType(ListView)).controller!;
    expect(controller.offset, greaterThan(0));
    await tester.enterText(find.byType(TextField), '새 메시지');
    await tester.tap(find.byTooltip('메시지 전송'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.offset, closeTo(0, 0.1));
    expect(find.text('새 메시지'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 0.1));
  });
}
