import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';

void main() {
  testWidgets('앱이 뜨고 가짜 대화가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    // 제목
    expect(find.text('AI Chat — 실습 1'), findsOneWidget);

    // 할 일 1 — 목록이 그려진다
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('오늘 뭐 배워?'), findsOneWidget);

    // 할 일 3 — 입력창과 전송 버튼이 있다
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);

    // 할 일 4 — 대화가 있으면 빈 상태 문구는 안 보인다
    expect(find.text('무엇이든 물어보세요'), findsNothing);
  });

  testWidgets('말풍선이 좌우로 나뉜다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    final userAlign = tester.widget<Align>(
      find.ancestor(of: find.text('오늘 뭐 배워?'), matching: find.byType(Align)).first,
    );
    final aiAlign = tester.widget<Align>(
      find
          .ancestor(
            of: find.text('AI 챗봇에 움직이는 응답을 붙입니다.'),
            matching: find.byType(Align),
          )
          .first,
    );

    expect(userAlign.alignment, Alignment.centerRight);
    expect(aiAlign.alignment, Alignment.centerLeft);
  });

  testWidgets('글을 보내면 목록에 추가되고 입력창이 비워진다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    await tester.enterText(find.byType(TextField), '안녕하세요');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // 말풍선에 하나만 있고, 입력창에는 남아 있지 않다
    expect(find.text('안녕하세요'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('공백만 있으면 보내지 않는다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatPage(initialMessages: [])),
    );

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('무엇이든 물어보세요'), findsOneWidget);
  });

  testWidgets('목록이 비면 빈 상태 문구가 보이고, 보내면 사라진다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatPage(initialMessages: [])),
    );

    expect(find.text('무엇이든 물어보세요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '첫 질문');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(find.text('무엇이든 물어보세요'), findsNothing);
    expect(find.text('첫 질문'), findsOneWidget);
  });

  testWidgets('키보드가 올라와도 입력창이 가려지지 않는다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    // 키보드 높이 300을 흉내 낸다
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    addTearDown(tester.view.reset);
    await tester.pump();

    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final keyboardTop = screenHeight - 300 * 3 / tester.view.devicePixelRatio;
    final fieldBottom = tester.getRect(find.byType(TextField)).bottom;

    expect(fieldBottom, lessThanOrEqualTo(keyboardTop));
  });
}
