import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';

void main() {
  testWidgets('앱이 뜨고 가짜 대화가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    // 제목
    expect(find.text('AI Chat — 실습 1'), findsOneWidget);

    // 할 일 1이 끝났다면 목록이 그려진다
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('오늘 뭐 배워?'), findsOneWidget);

    // 할 일 3이 끝났다면 입력창이 있다
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('전송하면 내 말풍선이 추가되고 입력창이 비워진다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    await tester.enterText(find.byType(TextField), '테스트 메시지');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('테스트 메시지'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );

    // 공백만 입력하면 아무것도 추가되지 않는다
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('목록이 비면 빈 상태 문구가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatPage(initialMessages: [])),
    );

    expect(find.text('무엇이든 물어보세요'), findsOneWidget);

    // 첫 메시지를 보내면 빈 상태가 사라진다
    await tester.enterText(find.byType(TextField), '안녕하세요');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('무엇이든 물어보세요'), findsNothing);
    expect(find.text('안녕하세요'), findsOneWidget);
  });

  testWidgets('키보드가 올라와도 입력창이 가려지지 않는다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    // 키보드가 화면 아래 300pt(논리 픽셀)를 차지한다고 가정
    const keyboardHeight = 300.0;
    // viewInsets는 물리 픽셀 단위라서 devicePixelRatio를 곱해 준다
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboardHeight * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final keyboardTop = screenHeight - keyboardHeight;

    final inputRect = tester.getRect(find.byType(TextField));
    expect(inputRect.bottom, lessThanOrEqualTo(keyboardTop));
  });
}
